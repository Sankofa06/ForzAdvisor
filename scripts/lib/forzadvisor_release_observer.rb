# frozen_string_literal: true

require_relative "forzadvisor_release_pilot"

module ForzAdvisorRelease
  # Reads controller attestations; never runs tests or supplies missing evidence.
  class ReleaseGateCollector
    def initialize(config:, reader: nil, github: nil, evidence_kind: :fixture)
      @config, @reader, @github, @kind = config, reader, github, evidence_kind.to_s
    end

    def call(identity:, candidate_id:)
      result = { "verified" => false, "blockers" => [] }
      return result.merge("blockers" => ["controller_gate_observer_unconfigured"]) unless @reader
      record = @reader.call(identity: identity)
      unless record.is_a?(Hash) && record["evidence_kind"] == @kind && record["candidate_id"] == candidate_id &&
          record["commit"] == identity["commit"] && record["config_fingerprint"] == identity["config_fingerprint"]
        return result.merge("blockers" => ["controller_gate_identity_mismatch"])
      end
      result["blockers"] = DailyPilot.gate_blockers(record["gates"], commit: identity["commit"])
      baseline = record["baseline_commit"]
      plan = record["change_plan"]
      if baseline.is_a?(String) && baseline.match?(/\A[0-9a-f]{40}\z/) && DailyPilot.valid_change_plan?(plan, commit: identity["commit"], baseline: baseline)
        result["test_plan"] = plan.slice("commit", "baseline_commit", "summary").merge(
          "scenarios" => plan["scenarios"].each_with_index.map { |item, index| item.slice("steps", "expected").merge("number" => index + 1) })
      else
        result["blockers"] << "version_specific_test_plan"
      end
      if @github
        begin
          proof = GitHubVerificationEvidence.new(config: @config, client: @github).call(run_id: record["verify_run_id"], ref: identity["ref"], commit: identity["commit"])
          result["github_run_id"] = proof.fetch("run_id")
        rescue StandardError
          result["blockers"] << "github_release_verify"
        end
      else
        result["blockers"] << "github_observer_unconfigured"
      end
      result["verified"] = result["blockers"].empty?
      result
    rescue StandardError
      { "verified" => false, "blockers" => ["controller_gate_evidence_unavailable"] }
    end
  end

  # Stateless observation and projection only. All connections must be injected.
  class ReleaseObserver
    RECEIPT_PHASES = %w[upload_valid candidate_ready testflight_attach_intent human_verification_pending human_accepted staged app_review_submitted].freeze

    def initialize(config:, identity:, gate_reader: nil, github: nil, state_reader: nil, apple_reader: nil, pr_reader: nil, evidence_kind: :fixture)
      raise PreflightError, "unknown observer evidence kind" unless %i[fixture live].include?(evidence_kind)
      pilot = DailyPilot.new(config: config, ref: identity.fetch("ref"), commit: identity.fetch("commit"), baseline: identity.fetch("commit"), paths: [])
      raise PreflightError, "observer source identity mismatch" unless identity == pilot.identity
      @identity, @candidate_id, @config, @kind = pilot.identity, pilot.candidate_id, config, evidence_kind.to_s
      @state_reader, @apple_reader, @pr_reader = state_reader, apple_reader, pr_reader
      @gates = ReleaseGateCollector.new(config: config, reader: gate_reader, github: github, evidence_kind: evidence_kind)
      @coordinator = StableRunnerCoordinator.new(config: config, git: nil, store: nil, github_verification: nil, helper: nil, api: nil)
      @repository = URI(config.fetch("repository", "remote_url")).path.delete_prefix("/").sub(/\.git\z/, "")
    end

    def call(now: nil)
      record = base_record(now || Time.now.utc)
      state_envelope = read_envelope(@state_reader, record["blockers"], "controller_state_observer")
      state = state_envelope && state_envelope.fetch("state")
      if state
        @coordinator.validate_state_identity!(state)
        unless state["schema_version"] == 2 && %w[ref commit].all? { |key| state[key] == @identity[key] }
          raise PreflightError, "candidate state identity mismatch"
        end
        if state["phase"] == "upload_start_intent"
          record.merge!("next_action" => "reconcile_upload_read_only", "blockers" => ["unresolved_upload_intent"])
          return render(record, now)
        end
      end
      gates = @gates.call(identity: @identity, candidate_id: @candidate_id)
      record["blockers"].concat(gates["blockers"])
      record["stage"] = "verified" if gates["verified"]
      record.merge!(gates.slice("test_plan", "github_run_id"))
      if state && RECEIPT_PHASES.include?(state["phase"])
        @coordinator.validate_candidate_receipt!(state)
        record["stage"] = "uploaded"
        observe_apple(record, state, gates["verified"], now)
      elsif state && state["phase"] != "github_verified"
        record["blockers"] << "candidate_requires_human_review"
        record["next_action"] = "blocked_candidate_requires_human_review"
      elsif gates["verified"]
        record["next_action"] = "await_authorized_existing_coordinator_handoff"
      end
      render(record, now)
    rescue StandardError
      record ||= base_record(now || Time.now.utc)
      record.merge!("install_ready" => false, "availability" => "UNVERIFIED", "next_action" => "refresh_controller_evidence_read_only")
      record["blockers"] << "controller_state_or_receipt_unverified"
      render(record, now)
    end

    private

    def base_record(now)
      { "candidate_id" => @candidate_id, "identity" => @identity, "stage" => "proposed", "install_ready" => false,
        "availability" => "UNVERIFIED", "checked_at" => now.utc.iso8601, "work_in_pr" => nil, "pr_blockers" => [],
        "blockers" => [], "next_action" => "complete_repository_gates" }
    end

    def read_envelope(reader, blockers, lane)
      unless reader
        blockers << "#{lane}_unconfigured"
        return nil
      end
      record = reader.call(identity: @identity)
      unless record.is_a?(Hash) && record["evidence_kind"] == @kind && record["candidate_id"] == @candidate_id
        raise PreflightError, "observation provenance mismatch"
      end
      record
    rescue StandardError
      blockers << "#{lane}_unverified"
      nil
    end

    def fresh_time(value, now)
      time = Time.iso8601(value)
      raise PreflightError, "observation is stale or future dated" unless (0..900).cover?((now || Time.now.utc) - time)
      time
    end

    def observe_apple(record, state, gates_verified, now)
      record["next_action"] = "refresh_apple_read_only"
      envelope = read_envelope(@apple_reader, record["blockers"], "apple_observer")
      return unless envelope
      observed_at = fresh_time(envelope.fetch("observed_at"), now)
      # Expose GET only, even when the existing injected client also supports writes.
      api = Struct.new(:client) { def get(path, query = {}); client.get(path, query); end }.new(envelope.fetch("api"))
      receipt = state.fetch("release_receipt")
      UploadedBuildResolver.new(config: @config, api: api).call(receipt: receipt)
      build = CandidateBuildValidator.new(config: @config, api: api).call(build_id: receipt.fetch("asc_build_id"), require_testflight_association: true)
      expires_at = Time.iso8601(build.fetch("expiration_date"))
      completed_at = now || Time.now.utc
      fresh_time(envelope["observed_at"], completed_at)
      raise PreflightError, "build is expired or expiration is unverified" unless build["expired"] == false && expires_at > completed_at
      record["apple"] = build.slice("build_id", "build_number", "marketing_version", "platform", "processing_state", "testflight_group_id", "testflight_associated", "expired", "expiration_date")
      record["apple"]["observed_at"] = observed_at.utc.iso8601
      return unless gates_verified && record["blockers"].empty?
      record.merge!("stage" => "install_ready", "install_ready" => true, "availability" => (@kind == "live" ? "VERIFIED" : "FIXTURE_ONLY"),
        "valid_until" => [observed_at + 900, expires_at].min.utc.iso8601, "next_action" => "await_human_live_verification")
    rescue StandardError
      record["blockers"] << "current_apple_build_and_internal_group"
    end

    def observe_prs(record, now)
      envelope = read_envelope(@pr_reader, record["pr_blockers"], "pull_request_observer")
      return unless envelope
      fresh_time(envelope.fetch("observed_at"), now)
      raise PreflightError, "PR repository mismatch" unless envelope["repository"] == @repository
      record["work_in_pr"] = envelope.fetch("pull_requests").map do |pr|
        number, sha = pr.fetch("number"), pr.fetch("head").fetch("sha")
        url = "https://github.com/#{@repository}/pull/#{number}"
        unless number.is_a?(Integer) && number.positive? && sha.match?(/\A[0-9a-f]{40}\z/) && pr["html_url"] == url && pr["state"] == "open" && [true, false].include?(pr["draft"])
          raise PreflightError, "PR identity mismatch"
        end
        { "number" => number, "url" => url, "head_sha" => sha, "draft" => pr["draft"] }
      end
    rescue StandardError
      record["work_in_pr"] = nil
      record["pr_blockers"] << "pull_request_evidence_unverified"
    end

    def render(record, now)
      observe_prs(record, now)
      result = { "schema_version" => 1, "read_only" => true, "schedule_enabled" => false, "native_execution_enabled" => false, "publication_enabled" => false }
      if @kind == "fixture"
        result.merge("portal" => base_record(now || Time.now.utc).merge("blockers" => ["fixture_only"]), "simulation" => record)
      else
        result.merge("portal" => record)
      end
    end
  end
end
