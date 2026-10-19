# frozen_string_literal: true

require "tempfile"
require_relative "forzadvisor_release"

module ForzAdvisorRelease
  # Separate fixture outbox: never reads or changes the stable runner's state.
  class DailyPilotSlot
    def initialize(directory)
      @directory = File.expand_path(directory)
    end

    def claim(candidate_id)
      raise PreflightError, "fixture state directory cannot be a symlink" if File.symlink?(@directory)
      unless File.directory?(@directory)
        raise PreflightError, "fixture state directory must already exist and be durably provisioned"
      end
      raise PreflightError, "fixture state directory must be private" unless File.stat(@directory).mode & 0o077 == 0
      File.open(File.join(@directory, "dispatch.lock"), File::RDWR | File::CREAT, 0o600) do |lock|
        return "native_slot_busy" unless lock.flock(File::LOCK_EX | File::LOCK_NB)
        path = File.join(@directory, "dispatch.json")
        if File.exist?(path)
          current = JSON.parse(File.read(path))
          raise PreflightError, "invalid fixture dispatch state" unless current["kind"] == "fixture_dispatch_intent"
          return current["candidate_id"] == candidate_id ? "reconcile_native_dispatch" : "native_slot_busy"
        end
        Tempfile.create(["dispatch-", ".json"], @directory) do |file|
          file.chmod(0o600)
          file.write(JSON.generate("kind" => "fixture_dispatch_intent", "candidate_id" => candidate_id))
          file.flush
          file.fsync
          begin
            File.rename(file.path, path)
            File.open(@directory, File::RDONLY) { |directory| directory.fsync }
          rescue SystemCallError, IOError
            raise PreflightError, "fixture dispatch intent durability is uncertain; reconcile before retry"
          end
        end
        "would_dispatch_native"
      end
    end
  end

  class DailyPilot
    GATES = %w[repository_preflight focused_tests clean_release_build local_release_verify changed_flow_evidence diff_review diff_check secret_scan pushed_release_tag].freeze
    DOCUMENTATION = %r{\A(?:README\.md|docs/.*\.md|forzadvisorDocs/.*\.md|AppStore/.*\.md)\z}
    attr_reader :candidate_id, :identity, :config

    def self.gate_blockers(gates, commit:)
      GATES.reject do |gate|
        evidence = gates.is_a?(Hash) ? gates[gate] : nil
        summary = evidence.is_a?(Hash) ? evidence["summary"] : nil
        complete = summary.is_a?(Hash) && summary["tests"].is_a?(Integer) && summary["tests"].positive? &&
          %w[failures skips expected_failures warnings].all? { |key| summary[key] == 0 }
        evidence.is_a?(Hash) && evidence["result"] == "PASS" && evidence["commit"] == commit &&
          (gate != "clean_release_build" || evidence["warnings"] == 0) && (gate != "local_release_verify" || complete)
      end
    end

    def self.valid_change_plan?(plan, commit:, baseline:)
      plan.is_a?(Hash) && plan["commit"] == commit && plan["baseline_commit"] == baseline &&
        plan["summary"].is_a?(String) && !plan["summary"].strip.empty? && plan["scenarios"].is_a?(Array) && !plan["scenarios"].empty? &&
        plan["scenarios"].all? { |item| item.is_a?(Hash) && item["steps"].is_a?(Array) && !item["steps"].empty? && item["steps"].all? { |step| step.is_a?(String) && !step.strip.empty? } && item["expected"].is_a?(String) && !item["expected"].strip.empty? }
    end

    def initialize(config:, ref:, commit:, baseline:, paths:)
      raise PreflightError, "pilot requires exact commit and baseline SHAs" unless [commit, baseline].all? { |sha| sha.to_s.match?(/\A[0-9a-f]{40}\z/) }
      raise PreflightError, "pilot requires a release tag" unless ref.to_s.match?(/\Arelease-[A-Za-z0-9._-]+\z/)
      @config = config
      @paths = paths.map { |path| path.dup.freeze }.sort.uniq.freeze
      @baseline = baseline.dup.freeze
      @identity = {
        "repository" => config.fetch("repository", "remote_url"), "platform" => "IOS",
        "app_id" => config.fetch("app", "id"), "bundle_id" => config.fetch("app", "bundle_id"),
        "marketing_version" => config.fetch("release", "marketing_version"), "source_build_number" => config.fetch("release", "source_build_number"),
        "stable_runner_profile" => config.fetch("stable_runner", "profile"), "config_fingerprint" => config.fingerprint,
        "ref" => ref, "commit" => commit
      }.transform_values { |value| value.dup.freeze }.freeze
      @candidate_id = Digest::SHA256.hexdigest(JSON.generate(@identity.sort.to_h)).freeze
    end

    def call(fixture: nil, state_directory: nil, now: Time.now.utc)
      portal = { "candidate_id" => candidate_id, "identity" => @identity, "stage" => "proposed", "install_ready" => false, "availability" => "UNVERIFIED" }
      portal["work_in_pr"] = nil # A missing portal/PR connection is not an empty PR list.
      result = { "schema_version" => 1, "dry_run" => true, "schedule_enabled" => false, "native_execution_enabled" => false, "portal" => portal }
      simulation = portal.merge("baseline_commit" => @baseline, "changed_paths" => @paths, "next_action" => "supply_fixture", "blockers" => [])
      result["simulation"] = simulation
      if fixture && (!fixture.is_a?(Hash) || fixture["kind"] != "fixture" || fixture["candidate_id"] != candidate_id)
        raise PreflightError, "fixture does not match the immutable candidate"
      end
      state = fixture && fixture["stable_state"]
      if fixture && fixture.key?("stable_state")
        raise PreflightError, "invalid fixture section: stable_state" unless state.is_a?(Hash)
        validate_stable_snapshot!(state)
        if state["phase"] == "upload_start_intent"
          simulation.merge!("next_action" => "reconcile_upload_read_only", "blockers" => ["unresolved_upload_intent"])
          return result
        end
      end
      if !state && (@paths.empty? || @paths.all? { |path| path.match?(DOCUMENTATION) })
        portal["stage"] = "skipped"
        return result.merge("simulation" => simulation.merge("stage" => "skipped", "next_action" => (@paths.empty? ? "unchanged" : "documentation_only")))
      end
      return result unless fixture
      %w[gates github change_plan apple].each do |key|
        raise PreflightError, "invalid fixture section: #{key}" if fixture.key?(key) && !fixture[key].is_a?(Hash)
      end
      blockers = self.class.gate_blockers(fixture["gates"], commit: @identity["commit"])
      begin
        github = fixture.fetch("github", {})
        client = Struct.new(:response, :job_list) { def run(_id); response; end; def jobs(_id); job_list; end }.new(github["run"], github["jobs"])
        GitHubVerificationEvidence.new(config: @config, client: client).call(run_id: github["run_id"], ref: @identity["ref"], commit: @identity["commit"])
      rescue Error, NoMethodError, TypeError
        blockers << "github_release_verify"
      end
      plan = fixture.fetch("change_plan", {})
      scenarios = plan["scenarios"]
      unless self.class.valid_change_plan?(plan, commit: @identity["commit"], baseline: @baseline)
        blockers << "version_specific_test_plan"
      end
      simulation.merge!("blockers" => blockers, "next_action" => "complete_repository_gates")
      return result unless blockers.empty?
      simulation.merge!("stage" => "verified", "next_action" => "supply_private_fixture_state_directory",
        "test_plan" => { "identity" => @identity, "baseline_commit" => @baseline, "changed_paths" => @paths,
          "summary" => plan["summary"], "scenarios" => scenarios.each_with_index.map { |item, index| item.slice("steps", "expected").merge("number" => index + 1) },
          "regression" => ["Launch and navigation", "Existing saved data and persistence"],
          "response_fields" => %w[Actual Result Evidence Notes], "overall_result" => %w[ACCEPT NEEDS_FIXES BLOCKED],
          "stop_conditions" => ["Crash", "Data loss", "Privacy or signing concern"] })
      unless state
        simulation["next_action"] = DailyPilotSlot.new(state_directory).claim(candidate_id) if state_directory
        return result
      end
      simulation["next_action"] = case state["phase"]
      when "github_verified" then "await_explicit_candidate_upload_authorization"
      when "upload_valid", "candidate_ready", "testflight_attach_intent", "human_verification_pending", "human_accepted"
        observe_uploaded(simulation, fixture, state, now)
      else "blocked_candidate_requires_human_review"
      end
      result
    end

    private

    def validate_stable_snapshot!(state)
      coordinator = StableRunnerCoordinator.new(config: @config, git: nil, store: nil, github_verification: nil, helper: nil, api: nil)
      coordinator.validate_state_identity!(state)
      raise PreflightError, "stable snapshot does not match candidate tag/commit" unless state["schema_version"] == 2 && %w[ref commit].all? { |key| state[key] == @identity[key] }
    end

    def observe_uploaded(simulation, fixture, state, now)
      receipt = state.fetch("release_receipt", {})
      expected = @identity.slice("app_id", "bundle_id", "marketing_version", "commit", "platform").merge(
        "schema_version" => 1, "build" => @identity["source_build_number"], "runner_profile" => @identity["stable_runner_profile"], "state" => "VALID",
        "xcode_build" => @config.fetch("stable_runner", "xcode_build"), "macos_build" => @config.fetch("stable_runner", "macos_build"),
        "sdk_version" => @config.fetch("stable_runner", "sdk_versions", "iOS"), "signing_verification" => "MANUAL_IOS_PROFILE_AND_SIGNER_VERIFIED")
      unless expected.all? { |key, value| receipt[key] == value } && %w[archive_sha256 package_sha256].all? { |key| receipt[key].to_s.match?(/\A[0-9a-f]{64}\z/) } && !receipt["asc_build_id"].to_s.empty?
        raise PreflightError, "receipt does not match candidate"
      end
      simulation["stage"] = "uploaded"
      observed_at = begin
        Time.iso8601(fixture.fetch("apple_observed_at", ""))
      rescue ArgumentError, TypeError
        nil
      end
      return "refresh_apple_read_only" unless observed_at && (0..900).cover?(now - observed_at)
      api = Struct.new(:responses) do
        def get(path, _query = {})
          responses.fetch(path) { raise APIError, "missing Apple fixture observation" }
        end
      end.new(fixture.fetch("apple", {}))
      begin
        UploadedBuildResolver.new(config: @config, api: api).call(receipt: receipt)
        build_id = receipt.fetch("asc_build_id")
        CandidateBuildValidator.new(config: @config, api: api).call(build_id: build_id, require_testflight_association: true)
        attributes = api.get("/v1/builds/#{build_id}").fetch("data").fetch("attributes")
        raise APIError, "build expiration is unverified" unless attributes["expired"] == false && Time.iso8601(attributes.fetch("expirationDate")) > now
        simulation.merge!("stage" => "install_ready", "install_ready" => true, "availability" => "FIXTURE_ONLY", "build_id" => build_id)
        "await_human_live_verification"
      rescue Error, KeyError, ArgumentError
        simulation["blockers"] << "current_apple_build_and_internal_group"
        "refresh_apple_read_only"
      end
    end
  end

  class DailyPilotSource
    def initialize(root:, runner: CommandRunner.new)
      @root, @runner = root, runner
    end

    def call(ref:, baseline:)
      raise PreflightError, "invalid immutable pilot source" unless ref.to_s.match?(/\Arelease-[A-Za-z0-9._-]+\z/) && baseline.to_s.match?(/\A[0-9a-f]{40}\z/)
      tag = "refs/tags/#{ref}"
      raise PreflightError, "pilot requires an annotated tag" unless git("cat-file", "-t", tag).strip == "tag"
      commit = git("rev-parse", "#{tag}^{commit}").strip
      git("merge-base", "--is-ancestor", baseline, commit)
      config = Tempfile.create(["forzadvisor-pilot-", ".json"]) do |file|
        file.write(git("show", "#{commit}:AppStore/release-config.json"))
        file.flush
        Config.new(file.path)
      end
      unless git("remote", "get-url", "origin").strip.sub(/\.git\z/, "") == config.fetch("repository", "remote_url").sub(/\.git\z/, "")
        raise PreflightError, "pilot repository does not match release configuration"
      end
      paths = git("diff", "--no-renames", "--name-only", "-z", baseline, commit, "--").split("\0")
      raise PreflightError, "candidate tag moved during planning" unless git("rev-parse", "#{tag}^{commit}").strip == commit
      DailyPilot.new(config: config, ref: ref, commit: commit, baseline: baseline, paths: paths)
    end

    private

    def git(*arguments)
      @runner.call("git", *arguments, chdir: @root)
    end
  end
end
