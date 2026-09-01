# frozen_string_literal: true

require "json"
require "minitest/autorun"
require "tmpdir"
require "zlib"
require_relative "../lib/forzadvisor_release"

class FakeGitRepository
  attr_accessor :error, :commit

  def initialize(commit: "a" * 40)
    @commit = commit
  end

  def assert_release_state!(_config, ref: nil, require_tag: false)
    raise error if error
    kind = require_tag ? "tag" : "branch"
    { "commit" => commit, "peeled_tag_commit" => (kind == "tag" ? commit : nil), "ref" => ref || "main", "ref_kind" => kind, "remote" => "origin" }
  end
end

class FakeURLChecker
  attr_reader :urls

  def initialize(status: 200)
    @status = status
    @urls = []
  end

  def call(url)
    urls << url
    raise ForzAdvisorRelease::PreflightError, "HTTP #{@status}" unless (200..299).cover?(@status)
    { "url" => url, "status" => @status }
  end
end

class FakeAPI
  attr_reader :requests

  def initialize(responses)
    @responses = responses
    @requests = []
  end

  def get(path, query = {})
    requests << [path, query]
    value = @responses.fetch(path)
    value.respond_to?(:call) ? value.call(path, query) : value
  end
  def post(path, body)
    requests << ["POST", path, body]
    value = @responses.fetch(["POST", path])
    value.respond_to?(:call) ? value.call(path, body) : value
  end
  def patch(path, body)
    requests << ["PATCH", path, body]
    value = @responses.fetch(["PATCH", path], {})
    value.respond_to?(:call) ? value.call(path, body) : value
  end
end

class FakeRunner
  def initialize(responses)
    @responses = responses
  end

  def call(*command, chdir:)
    @responses.fetch(command) { raise "unexpected command #{command.inspect} in #{chdir}" }
  end
end

class FakeGitHubClient
  def initialize(run:, jobs:)
    @run = run
    @jobs = jobs
  end
  def run(_run_id)
    @run
  end
  def jobs(_run_id)
    @jobs
  end
end

class FakeStableRunnerHelper
  attr_reader :calls

  def initialize(receipt)
    @receipt = receipt
    @calls = []
  end

  def upload(**arguments)
    @calls << arguments
    @receipt
  end
end

class RecordingRunner
  attr_reader :calls

  def initialize(output)
    @output = output
    @calls = []
  end

  def call(*command, chdir:)
    calls << { command: command, chdir: chdir }
    @output
  end
end

class ForzAdvisorReleaseTest < Minitest::Test
  ROOT = File.expand_path("../..", __dir__)
  CONFIG_PATH = File.join(ROOT, "AppStore", "release-config.json")

  def setup
    @config = ForzAdvisorRelease::Config.new(CONFIG_PATH)
  end

  def test_repository_release_config_records_verification_only_ci_and_stable_runner
    assert_equal "78", @config.fetch("release", "source_build_number")
    assert_equal "78", @config.fetch("release", "current_app_store_build_number")
    assert_equal "FREE", @config.fetch("release", "price", "model")
    assert_equal "EXPLICIT_HUMAN_APPROVAL", @config.fetch("release", "submission_policy")
    assert_equal "AFTER_APPROVAL", @config.fetch("release", "app_store_release_type")
    assert_equal false, @config.fetch("release", "privacy", "tracking")
    assert_equal 2, @config.fetch("schema_version")
    assert_equal "GITHUB_ACTIONS", @config.fetch("ci", "provider")
    assert_equal "VERIFICATION_ONLY", @config.fetch("ci", "authority")
    assert_equal ".github/workflows/release-verify.yml", @config.fetch("ci", "verify_workflow")
    refute @config.fetch("ci").key?("release_candidate_workflow")
    refute @config.fetch("ci").key?("release_candidate_mode")
    assert_equal "stable-xcode-26.3-intel", @config.fetch("stable_runner", "profile")
    assert_equal "17C529", @config.fetch("stable_runner", "xcode_build")
    assert_equal "24G720", @config.fetch("stable_runner", "macos_build")
    assert_equal "26.2", @config.fetch("stable_runner", "sdk_versions", "iOS")
    assert_equal ["arm64"], @config.fetch("stable_runner", "architectures", "iOS")
    assert_equal "automatic", @config.fetch("stable_runner", "signing", "mode")
  end

  def test_hosted_candidate_workflow_is_absent_and_github_is_verification_only
    refute File.exist?(File.join(ROOT, ".github", "workflows", "release-candidate.yml"))
    workflows = Dir[File.join(ROOT, ".github", "workflows", "*.yml")].map { |path| File.read(path) }.join("\n")
    refute_includes workflows, "ASC_PRIVATE_KEY"
    refute_includes workflows, "xcodebuild -exportArchive"
    refute_includes workflows, "destination -string upload"
  end

  def test_verify_workflow_pins_exact_commit_and_stable_toolchain
    workflow = File.read(File.join(ROOT, ".github", "workflows", "release-verify.yml"))

    assert_includes workflow, 'RELEASE_SHA: ${{ inputs.release_sha }}'
    assert_includes workflow, 'test "$(git rev-parse HEAD)" = "$RELEASE_SHA"'
    assert_includes workflow, 'test "$(sw_vers -productVersion)" = "26.5.2"'
    assert_includes workflow, 'test "$(sw_vers -buildVersion)" = "25F84"'
    assert_includes workflow, 'test "$(xcodebuild -version | tail -1)" = "Build version 17F113"'
  end

  def test_config_rejects_unapproved_ci_or_stable_runner_contract
    with_config do |data, path|
      data["ci"]["provider"] = "UNTRUSTED_CI"
      File.write(path, JSON.generate(data))
      assert_raises(ForzAdvisorRelease::ConfigurationError) { ForzAdvisorRelease::Config.new(path) }
    end
    with_config do |data, path|
      data["ci"]["authority"] = "UPLOAD"
      File.write(path, JSON.generate(data))
      assert_raises(ForzAdvisorRelease::ConfigurationError) { ForzAdvisorRelease::Config.new(path) }
    end
    with_config do |data, path|
      data["stable_runner"]["profile"] = "untrusted-runner"
      File.write(path, JSON.generate(data))
      assert_raises(ForzAdvisorRelease::ConfigurationError) { ForzAdvisorRelease::Config.new(path) }
    end
    with_config do |data, path|
      data["stable_runner"]["export"]["manage_app_version_and_build_number"] = true
      File.write(path, JSON.generate(data))
      assert_raises(ForzAdvisorRelease::ConfigurationError) { ForzAdvisorRelease::Config.new(path) }
    end
  end

  def test_config_rejects_release_policy_that_can_publish_without_approval
    with_config do |data, path|
      data["release"]["submission_policy"] = "AUTOMATIC"
      File.write(path, JSON.generate(data))
      error = assert_raises(ForzAdvisorRelease::ConfigurationError) { ForzAdvisorRelease::Config.new(path) }
      assert_match(/require approval/, error.message)
    end
  end

  def test_config_rejects_unknown_content_rights_and_malformed_domains
    with_config do |data, path|
      data["release"]["content_rights"] = "MAYBE"
      File.write(path, JSON.generate(data))
      assert_raises(ForzAdvisorRelease::ConfigurationError) { ForzAdvisorRelease::Config.new(path) }
    end
    with_config do |data, path|
      data["legacy_xcode_cloud"]["product_id"] = "not-a-uuid"
      File.write(path, JSON.generate(data))
      assert_raises(ForzAdvisorRelease::ConfigurationError) { ForzAdvisorRelease::Config.new(path) }
    end
    with_config do |data, path|
      data["screenshots"]["ordered_files"] << data["screenshots"]["ordered_files"].first
      File.write(path, JSON.generate(data))
      assert_raises(ForzAdvisorRelease::ConfigurationError) { ForzAdvisorRelease::Config.new(path) }
    end
    with_config do |data, path|
      data["release"]["unexpected"] = true
      File.write(path, JSON.generate(data))
      assert_raises(ForzAdvisorRelease::ConfigurationError) { ForzAdvisorRelease::Config.new(path) }
    end
    with_config do |data, path|
      data["release"]["privacy"]["published_in_app_store_connect"] = "true"
      File.write(path, JSON.generate(data))
      assert_raises(ForzAdvisorRelease::ConfigurationError) { ForzAdvisorRelease::Config.new(path) }
    end
  end

  def test_full_preflight_passes_current_repository_artifacts_with_injected_urls_and_git
    urls = FakeURLChecker.new
    result = ForzAdvisorRelease::Preflight.new(
      root: ROOT,
      config: @config,
      url_checker: urls,
      git: FakeGitRepository.new
    ).run

    assert_equal true, result["ready"]
    assert_equal ForzAdvisorRelease::Preflight::CHECKS.sort, result["checks"].keys.sort
    assert result["checks"].values.all? { |check| check["passed"] }
    assert_equal @config.fetch("public_urls").values.sort, urls.urls.sort
    assert_equal "78", result.dig("checks", "project", "evidence", "source_build_number")
    assert_equal 6, result.dig("checks", "screenshots", "evidence", "count")
  end

  def test_preflight_aggregates_independent_failures
    git = FakeGitRepository.new
    git.error = ForzAdvisorRelease::PreflightError.new("working tree has uncommitted changes")
    result_error = assert_raises(ForzAdvisorRelease::PreflightError) do
      ForzAdvisorRelease::Preflight.new(
        root: ROOT,
        config: @config,
        url_checker: FakeURLChecker.new(status: 404),
        git: git
      ).run
    end

    assert_equal false, result_error.result["ready"]
    assert_equal false, result_error.result.dig("checks", "repository", "passed")
    assert_equal false, result_error.result.dig("checks", "public_urls", "passed")
    assert_match(/uncommitted changes/, result_error.message)
    assert_match(/HTTP 404/, result_error.message)
  end

  def test_project_inspector_checks_versions_signing_schemes_and_both_test_targets
    result = ForzAdvisorRelease::ProjectInspector.new(root: ROOT, config: @config).call

    assert_equal "1.41.1", result["marketing_version"]
    assert_equal "78", result["source_build_number"]
    assert_equal %w[forzadvisorTests forzadvisorUITests], result["test_targets"]
    assert_equal ["forzadvisor.xcscheme", "forzadvisor Cloud.xcscheme"], result["schemes"]
  end

  def test_metadata_inspector_enforces_store_limits_and_public_url_consistency
    result = ForzAdvisorRelease::MetadataInspector.new(root: ROOT, config: @config).call

    assert_operator result.dig("lengths", "App Name"), :<=, 30
    assert_operator result.dig("lengths", "Subtitle"), :<=, 30
    assert_operator result.dig("lengths", "Description"), :<=, 4000
    assert_operator result.dig("lengths", "Keywords"), :<=, 100
  end

  def test_screenshot_inspector_confirms_order_dimensions_and_actual_pixel_opacity
    result = ForzAdvisorRelease::ScreenshotInspector.new(root: ROOT, config: @config).call

    assert_equal @config.fetch("screenshots", "ordered_files"), result["files"].map { |item| item["file"] }
    assert result["files"].all? { |item| item["width"] == 1320 && item["height"] == 2868 && item["opaque"] }
  end

  def test_png_inspector_detects_transparent_pixels_not_just_an_alpha_channel
    Dir.mktmpdir do |directory|
      opaque_path = File.join(directory, "opaque.png")
      transparent_path = File.join(directory, "transparent.png")
      write_rgba_png(opaque_path, 2, 1, [[1, 2, 3, 255], [4, 5, 6, 255]])
      write_rgba_png(transparent_path, 2, 1, [[1, 2, 3, 255], [4, 5, 6, 0]])

      assert_equal true, ForzAdvisorRelease::PNGInspector.call(opaque_path)["opaque"]
      assert_equal false, ForzAdvisorRelease::PNGInspector.call(transparent_path)["opaque"]
    end
  end

  def test_png_inspector_rejects_grayscale_screenshots
    Dir.mktmpdir do |directory|
      path = File.join(directory, "gray.png")
      raw = "\x00\x7f".b
      header = [1, 1, 8, 0, 0, 0, 0].pack("NNCCCCC")
      File.binwrite(path, "\x89PNG\r\n\x1a\n".b + png_chunk("IHDR", header) + png_chunk("IDAT", Zlib::Deflate.deflate(raw)) + png_chunk("IEND", ""))
      assert_raises(ForzAdvisorRelease::PreflightError) { ForzAdvisorRelease::PNGInspector.call(path) }
    end
  end

  def test_no_skip_gate_rejects_scheme_and_test_plan_skips
    assert_raises(ForzAdvisorRelease::PreflightError) { ForzAdvisorRelease::ProjectInspector.assert_no_skips!(scheme_texts: { "Cloud" => "<SkippedTests></SkippedTests>" }, plan: {}) }
    assert_raises(ForzAdvisorRelease::PreflightError) { ForzAdvisorRelease::ProjectInspector.assert_no_skips!(scheme_texts: { "Cloud" => "<Scheme/>" }, plan: { "skipEnabled" => true }) }
    assert_raises(ForzAdvisorRelease::PreflightError) { ForzAdvisorRelease::ProjectInspector.assert_no_skips!(scheme_texts: { "Cloud" => "<SelectedTests></SelectedTests>" }, plan: {}) }
    assert_raises(ForzAdvisorRelease::PreflightError) { ForzAdvisorRelease::ProjectInspector.assert_no_skips!(scheme_texts: { "Cloud" => "<Scheme/>" }, plan: { "testTargets" => [{ "enabled" => false }] }) }
  end

  def test_privacy_inspector_requires_manifest_and_human_publication_attestation
    result = ForzAdvisorRelease::PrivacyInspector.new(root: ROOT, config: @config).call

    assert_equal true, result["published"]
    assert_equal false, result["tracking"]
    assert_equal "2026-08-21", result["attested_on"]
  end

  def test_privacy_inspector_rejects_manifest_label_drift
    Dir.mktmpdir do |directory|
      manifest = File.read(File.join(ROOT, @config.fetch("xcode", "privacy_manifest")))
      manifest.sub!("NSPrivacyCollectedDataTypeGameplayContent", "NSPrivacyCollectedDataTypeEmailAddress")
      relative = "PrivacyInfo.xcprivacy"
      File.write(File.join(directory, relative), manifest)
      data = JSON.parse(File.read(CONFIG_PATH))
      data["xcode"]["privacy_manifest"] = relative
      config_path = File.join(directory, "config.json")
      File.write(config_path, JSON.generate(data))
      config = ForzAdvisorRelease::Config.new(config_path)
      error = assert_raises(ForzAdvisorRelease::PreflightError) { ForzAdvisorRelease::PrivacyInspector.new(root: directory, config: config).call }
      assert_match(/types drift/, error.message)
    end
  end

  def test_release_declarations_require_price_rights_age_contact_and_manual_policy
    result = ForzAdvisorRelease::ReleaseDeclarationInspector.new(@config).call

    assert_equal "FREE", result["price"]
    assert_equal "USES_THIRD_PARTY_CONTENT", result["content_rights"]
    assert_equal true, result["age_rating_recorded"]
    assert_equal true, result["review_contact_recorded"]
  end

  def test_submission_guard_requires_two_independent_acknowledgements
    guard = { confirmation: "exact", expected_confirmation: "exact" }
    assert_raises(ForzAdvisorRelease::PreflightError) { ForzAdvisorRelease::SubmissionGuard.authorize!(submit: false, acknowledge_irreversible_app_review_submission: false, **guard) }
    assert_raises(ForzAdvisorRelease::PreflightError) { ForzAdvisorRelease::SubmissionGuard.authorize!(submit: true, acknowledge_irreversible_app_review_submission: false, **guard) }
    assert_raises(ForzAdvisorRelease::PreflightError) { ForzAdvisorRelease::SubmissionGuard.authorize!(submit: false, acknowledge_irreversible_app_review_submission: true, **guard) }
    assert_raises(ForzAdvisorRelease::PreflightError) { ForzAdvisorRelease::SubmissionGuard.authorize!(submit: true, acknowledge_irreversible_app_review_submission: true, confirmation: "wrong", expected_confirmation: "exact") }
    assert ForzAdvisorRelease::SubmissionGuard.authorize!(submit: true, acknowledge_irreversible_app_review_submission: true, **guard)
  end

  def test_github_verification_evidence_requires_exact_tag_sha_workflow_and_job
    tag = "release-1.41.1-appstore-78"
    commit = "a" * 40
    run = github_run(tag: tag, commit: commit)
    client = FakeGitHubClient.new(run: run, jobs: [github_job])
    evidence = ForzAdvisorRelease::GitHubVerificationEvidence.new(config: @config, client: client).call(run_id: "42", ref: tag, commit: commit)
    assert_equal commit, evidence["commit"]
    assert_equal ".github/workflows/release-verify.yml", evidence["workflow_path"]
    assert_equal "success", evidence["conclusion"]

    run["head_branch"] = "main"
    assert_raises(ForzAdvisorRelease::PreflightError) do
      ForzAdvisorRelease::GitHubVerificationEvidence.new(config: @config, client: client).call(run_id: "42", ref: tag, commit: commit)
    end
    run["head_branch"] = tag
    failed_job = github_job.merge("conclusion" => "failure")
    assert_raises(ForzAdvisorRelease::PreflightError) do
      ForzAdvisorRelease::GitHubVerificationEvidence.new(config: @config, client: FakeGitHubClient.new(run: run, jobs: [failed_job])).call(run_id: "42", ref: tag, commit: commit)
    end
  end

  def test_release_verify_workflow_is_dispatch_tag_bound_warning_strict_and_rejects_incomplete_xcresult
    workflow = File.read(File.join(ROOT, ".github", "workflows", "release-verify.yml"))
    assert_includes workflow, "workflow_dispatch:"
    assert_includes workflow, "run-name: Verify ${{ inputs.release_ref }}"
    assert_includes workflow, "ref: ${{ inputs.release_sha }}"
    assert_includes workflow, "SWIFT_TREAT_WARNINGS_AS_ERRORS=YES"
    assert_includes workflow, "GCC_TREAT_WARNINGS_AS_ERRORS=YES"
    assert_includes workflow, "xcresulttool get test-results summary"
    assert_includes workflow, ".totalTestCount > 0"
    assert_includes workflow, ".failedTests == 0"
    assert_includes workflow, ".skippedTests == 0"
    assert_includes workflow, ".expectedFailures == 0"
    refute_match(/^\s+pull_request:/, workflow)
  end

  def test_legacy_cloud_coordinator_remains_testable_but_is_not_exposed_by_cli
    tag = "release-legacy"
    repository_id = @config.fetch("legacy_xcode_cloud", "repository_id")
    workflow_id = @config.fetch("legacy_xcode_cloud", "workflows", "verify", "id")
    responses = {
      "/v1/scmRepositories/#{repository_id}/gitReferences" => { "data" => [{ "id" => "legacy-ref", "attributes" => { "kind" => "TAG", "canonicalName" => "refs/tags/#{tag}" } }] },
      "/v1/ciWorkflows/#{workflow_id}/buildRuns" => { "data" => [] },
      ["POST", "/v1/ciBuildRuns"] => { "data" => { "id" => "legacy-run" } }
    }
    Dir.mktmpdir do |directory|
      coordinator = ForzAdvisorRelease::CloudCoordinator.new(
        config: @config,
        api: FakeAPI.new(responses),
        git: FakeGitRepository.new,
        store: ForzAdvisorRelease::StateStore.new(directory: directory)
      )
      state = coordinator.start(ref: tag)
      assert_equal "verify_running", state["phase"]
      assert_equal "legacy-run", state["verify_run_id"]
    end
  end

  def test_stable_runner_coordinator_persists_intent_before_exact_upload_and_attaches_only_testflight
    tag = "release-1.41.1-appstore-78"
    commit = "a" * 40
    Dir.mktmpdir do |directory|
      store = ForzAdvisorRelease::StableStateStore.new(directory: directory)
      helper = FakeStableRunnerHelper.new(release_receipt(commit: commit))
      helper.define_singleton_method(:upload) do |**arguments|
        raise "intent not persisted" unless store.load["phase"] == "upload_start_intent"
        @calls << arguments
        @receipt
      end
      api = FakeAPI.new(stable_candidate_responses)
      coordinator = stable_coordinator(store: store, helper: helper, api: api, tag: tag, commit: commit)
      confirmation = coordinator.confirmation_token(commit)
      state = coordinator.start(ref: tag, verify_run_id: "42", upload: true, confirmation: confirmation)
      assert_equal "human_verification_pending", state["phase"]
      assert_equal "build-78", state["build_id"]
      assert_equal 1, helper.calls.length
      assert_equal confirmation, helper.calls.first[:confirmation]
      assert_equal commit, helper.calls.first[:commit]
      assert_equal 1, api.requests.count { |request| request[0] == "POST" }
      refute api.requests.any? { |request| request[0] == "PATCH" }
      assert_equal "testflight_attached", state.dig("testflight_checkpoint", "event")
      assert_equal 0o600, File.stat(File.join(directory, "active-v2.json")).mode & 0o777
    end
  end

  def test_stable_runner_coordinator_rejects_wrong_receipt_and_ambiguous_builds
    tag = "release-1.41.1-appstore-78"
    commit = "a" * 40
    Dir.mktmpdir do |directory|
      store = ForzAdvisorRelease::StableStateStore.new(directory: directory)
      receipt = release_receipt(commit: commit).merge("xcode_build" => "wrong")
      helper = FakeStableRunnerHelper.new(receipt)
      api = FakeAPI.new(stable_candidate_responses)
      coordinator = stable_coordinator(store: store, helper: helper, api: api, tag: tag, commit: commit)
      assert_raises(ForzAdvisorRelease::PreflightError) do
        coordinator.start(ref: tag, verify_run_id: "42", upload: true, confirmation: coordinator.confirmation_token(commit))
      end
      refute api.requests.any? { |request| request[0] == "POST" }
    end

    responses = stable_candidate_responses
    responses["/v1/apps/#{@config.fetch('app', 'id')}/builds"] = { "data" => [candidate_build, candidate_build.merge("id" => "other")] }
    responses["/v1/builds/other/preReleaseVersion"] = responses["/v1/builds/build-78/preReleaseVersion"]
    assert_raises(ForzAdvisorRelease::APIError) do
      ForzAdvisorRelease::UploadedBuildResolver.new(config: @config, api: FakeAPI.new(responses)).call(receipt: release_receipt(commit: commit))
    end

    group = @config.fetch("testflight", "internal_group", "id")
    external_group_responses = stable_candidate_responses
    external_group_responses["/v1/betaGroups/#{group}"]["data"]["attributes"]["isInternalGroup"] = false
    external_api = FakeAPI.new(external_group_responses)
    assert_raises(ForzAdvisorRelease::APIError) do
      ForzAdvisorRelease::TestFlightDistributor.new(config: @config, api: external_api).call(build_id: "build-78")
    end
    refute external_api.requests.any? { |request| request[0] == "POST" }
  end

  def test_stable_state_is_separate_from_legacy_and_fails_closed_after_ambiguous_intent
    Dir.mktmpdir do |directory|
      legacy = ForzAdvisorRelease::StateStore.new(directory: File.join(directory, "legacy"))
      legacy.save("phase" => "staged", "build_id" => "old")
      stable = ForzAdvisorRelease::StableStateStore.new(directory: File.join(directory, "stable"))
      refute stable.active?
      stable.save(stable_identity.merge("schema_version" => 2, "phase" => "upload_start_intent"))
      coordinator = ForzAdvisorRelease::StableRunnerCoordinator.new(config: @config, git: FakeGitRepository.new, store: stable, github_verification: nil, helper: nil, api: nil)
      assert_raises(ForzAdvisorRelease::PreflightError) { coordinator.resume }
      assert_equal "old", legacy.load["build_id"]
    end
  end

  def test_github_verified_resume_is_explicit_and_upload_intent_never_retransmits
    Dir.mktmpdir do |directory|
      store = ForzAdvisorRelease::StableStateStore.new(directory: directory)
      store.save(stable_identity.merge("schema_version" => 2, "phase" => "github_verified", "github_verification" => { "conclusion" => "success" }))
      helper = FakeStableRunnerHelper.new(release_receipt)
      coordinator = stable_coordinator(store: store, helper: helper, api: FakeAPI.new(stable_candidate_responses), tag: stable_identity["ref"], commit: stable_identity["commit"])
      assert_raises(ForzAdvisorRelease::PreflightError) { coordinator.resume }
      assert_empty helper.calls
      state = coordinator.resume(upload: true, confirmation: coordinator.confirmation_token(stable_identity["commit"]))
      assert_equal "human_verification_pending", state["phase"]
      assert_equal 1, helper.calls.length

      store.save(stable_identity.merge("schema_version" => 2, "phase" => "upload_start_intent"))
      assert_raises(ForzAdvisorRelease::PreflightError) { coordinator.resume(upload: true, confirmation: coordinator.confirmation_token(stable_identity["commit"])) }
      assert_equal 1, helper.calls.length
    end
  end

  def test_ambiguous_candidate_reconciliation_is_read_only_and_block_requires_notes
    Dir.mktmpdir do |directory|
      store = ForzAdvisorRelease::StableStateStore.new(directory: directory)
      store.save(stable_identity.merge("schema_version" => 2, "phase" => "upload_start_intent"))
      api = FakeAPI.new(stable_candidate_responses)
      helper = FakeStableRunnerHelper.new(release_receipt)
      coordinator = ForzAdvisorRelease::StableRunnerCoordinator.new(config: @config, git: nil, store: store, github_verification: nil, helper: helper, api: api)
      reconciled = coordinator.reconcile
      assert_equal true, reconciled.dig("reconciliation", "read_only")
      assert_equal 1, reconciled.dig("reconciliation", "matching_build_count")
      assert_includes ForzAdvisorRelease::Reporter.text(reconciled), "Build build-78: VALID"
      refute api.requests.any? { |request| %w[POST PATCH].include?(request[0]) }
      assert_empty helper.calls
      assert_equal "upload_start_intent", store.load["phase"]
      assert_raises(ForzAdvisorRelease::PreflightError) { coordinator.block_candidate(notes: " ") }
      blocked = coordinator.block_candidate(notes: "Transport ended without a receipt")
      assert_equal "human_blocked", blocked["phase"]
      assert_equal "AMBIGUOUS_UPLOAD", blocked.dig("candidate_block", "kind")
    end
  end

  def test_terminal_history_is_immutable_private_and_same_build_cannot_roll_over
    Dir.mktmpdir do |directory|
      store = ForzAdvisorRelease::StableStateStore.new(directory: directory)
      terminal = stable_identity.merge("schema_version" => 2, "phase" => "human_needs_fixes", "human_verification" => { "result" => "NEEDS_FIXES" })
      store.save(terminal)
      archived = store.archive(store.load)
      assert_equal 0o600, File.stat(archived).mode & 0o777
      assert_equal File.read(archived), File.read(store.archive(store.load))
      coordinator = stable_coordinator(store: store, helper: FakeStableRunnerHelper.new(release_receipt), api: FakeAPI.new(stable_candidate_responses), tag: stable_identity["ref"], commit: stable_identity["commit"])
      assert_raises(ForzAdvisorRelease::PreflightError) do
        coordinator.start(ref: stable_identity["ref"], verify_run_id: "42", upload: true, confirmation: coordinator.confirmation_token(stable_identity["commit"]))
      end
      assert_equal 1, Dir.glob(File.join(directory, "history", "*.json")).length
    end
  end

  def test_terminal_rollover_archives_once_and_establishes_new_github_verified_identity
    Dir.mktmpdir do |directory|
      store = ForzAdvisorRelease::StableStateStore.new(directory: File.join(directory, "state"))
      store.save(stable_identity.merge("schema_version" => 2, "phase" => "human_blocked"))
      data = JSON.parse(File.read(CONFIG_PATH))
      data["release"]["source_build_number"] = "79"
      path = File.join(directory, "config.json")
      File.write(path, JSON.generate(data))
      config = ForzAdvisorRelease::Config.new(path)
      tag = "release-1.41.1-appstore-79"
      commit = "b" * 40
      github = ForzAdvisorRelease::GitHubVerificationEvidence.new(config: config, client: FakeGitHubClient.new(run: github_run(tag: tag, commit: commit), jobs: [github_job]))
      coordinator = ForzAdvisorRelease::StableRunnerCoordinator.new(config: config, git: FakeGitRepository.new(commit: commit), store: store, github_verification: github, helper: nil, api: nil)
      assert_raises(ForzAdvisorRelease::PreflightError) { coordinator.start(ref: tag, verify_run_id: "43", upload: false, confirmation: nil) }
      assert_equal "github_verified", store.load["phase"]
      assert_equal "79", store.load["source_build_number"]
      archives = Dir.glob(File.join(directory, "state", "history", "*.json"))
      assert_equal 1, archives.length
      assert_equal 0o600, File.stat(archives.first).mode & 0o777
      assert_raises(ForzAdvisorRelease::PreflightError) { coordinator.start(ref: tag, verify_run_id: "43", upload: false, confirmation: nil) }
      assert_equal 1, Dir.glob(File.join(directory, "state", "history", "*.json")).length
    end
  end

  def test_terminal_rollover_rejects_same_build_even_when_commit_changes
    Dir.mktmpdir do |directory|
      store = ForzAdvisorRelease::StableStateStore.new(directory: directory)
      store.save(stable_identity.merge("schema_version" => 2, "phase" => "human_needs_fixes"))
      tag = "release-retry-same-build"
      commit = "b" * 40
      github = ForzAdvisorRelease::GitHubVerificationEvidence.new(config: @config, client: FakeGitHubClient.new(run: github_run(tag: tag, commit: commit), jobs: [github_job]))
      coordinator = ForzAdvisorRelease::StableRunnerCoordinator.new(config: @config, git: FakeGitRepository.new(commit: commit), store: store, github_verification: github, helper: nil, api: nil)
      error = assert_raises(ForzAdvisorRelease::PreflightError) { coordinator.start(ref: tag, verify_run_id: "43", upload: false, confirmation: nil) }
      assert_match(/new version\/build identity/, error.message)
      assert_empty Dir.glob(File.join(directory, "history", "*.json"))
    end
  end

  def test_human_result_records_accept_and_rejects_premature_or_unknown_results
    Dir.mktmpdir do |directory|
      store = ForzAdvisorRelease::StableStateStore.new(directory: directory)
      store.save(stable_identity.merge("schema_version" => 2, "phase" => "human_verification_pending", "build_id" => "build-78"))
      coordinator = ForzAdvisorRelease::StableRunnerCoordinator.new(config: @config, git: nil, store: store, github_verification: nil, helper: nil, api: nil)
      state = coordinator.record_human_result(result: "ACCEPT", notes: "Matches expected results", evidence: "screenshot-1.png")
      assert_equal "human_accepted", state["phase"]
      assert_equal "ACCEPT", state.dig("human_verification", "result")
      assert_raises(ForzAdvisorRelease::PreflightError) { coordinator.record_human_result(result: "MAYBE", notes: "observed", evidence: "log") }
      store.save(stable_identity.merge("schema_version" => 2, "phase" => "candidate_ready"))
      assert_raises(ForzAdvisorRelease::PreflightError) { coordinator.record_human_result(result: "ACCEPT", notes: "observed", evidence: "log") }
    end
  end

  def test_human_result_requires_notes_and_evidence_is_idempotent_and_cannot_be_overwritten
    Dir.mktmpdir do |directory|
      store = ForzAdvisorRelease::StableStateStore.new(directory: directory)
      store.save(stable_identity.merge("schema_version" => 2, "phase" => "human_verification_pending"))
      coordinator = ForzAdvisorRelease::StableRunnerCoordinator.new(config: @config, git: nil, store: store, github_verification: nil, helper: nil, api: nil)
      assert_raises(ForzAdvisorRelease::PreflightError) { coordinator.record_human_result(result: "ACCEPT", notes: "", evidence: "screen") }
      assert_raises(ForzAdvisorRelease::PreflightError) { coordinator.record_human_result(result: "ACCEPT", notes: "works", evidence: "") }
      first = coordinator.record_human_result(result: "NEEDS_FIXES", notes: "Lap button stalls", evidence: "video-42")
      identical = coordinator.record_human_result(result: "NEEDS_FIXES", notes: "Lap button stalls", evidence: "video-42")
      assert_equal first, identical
      assert_raises(ForzAdvisorRelease::PreflightError) { coordinator.record_human_result(result: "ACCEPT", notes: "now works", evidence: "video-43") }
    end
  end

  def test_state_config_identity_drift_is_exposed_and_fails_closed
    Dir.mktmpdir do |directory|
      store = ForzAdvisorRelease::StableStateStore.new(directory: directory)
      store.save(stable_identity.merge("schema_version" => 2, "phase" => "human_accepted"))
      data = JSON.parse(File.read(CONFIG_PATH))
      data["repository"]["release_ref"] = "release-drift"
      path = File.join(directory, "drifted-config.json")
      File.write(path, JSON.generate(data))
      drifted = ForzAdvisorRelease::Config.new(path)
      coordinator = ForzAdvisorRelease::StableRunnerCoordinator.new(config: drifted, git: nil, store: store, github_verification: nil, helper: nil, api: nil)
      error = assert_raises(ForzAdvisorRelease::PreflightError) { coordinator.validate_state_identity! }
      assert_match(/config_fingerprint/, error.message)
    end
  end

  def test_candidate_staging_reuses_attached_build_draft_and_item
    app = @config.fetch("app", "id")
    draft = @config.fetch("app_store", "review_submission_id")
    version = @config.fetch("app_store", "version_id")
    item = @config.fetch("app_store", "review_submission_item_id")
    responses = candidate_validation_responses("build").merge(
      "/v1/apps/#{app}/appStoreVersions" => { "data" => [{ "id" => version }] },
      "/v1/appStoreVersions/#{version}/build" => { "data" => { "id" => "build" } },
      "/v1/apps/#{app}/reviewSubmissions" => { "data" => [{ "id" => draft, "attributes" => { "state" => "READY_FOR_REVIEW", "platform" => "IOS" } }] },
      "/v1/reviewSubmissions/#{draft}/items" => { "data" => [{ "id" => item, "relationships" => { "appStoreVersion" => { "data" => { "id" => version } } } }] }
    )
    api = FakeAPI.new(responses)
    result = ForzAdvisorRelease::CandidateStager.new(config: @config, api: api).call(build_id: "build")
    assert_equal "staged", result["phase"]
    refute api.requests.any? { |item| item[0] == "POST" || item[0] == "PATCH" }

    responses["/v1/reviewSubmissions/#{draft}/items"] = { "data" => [{ "id" => "wrong-review-item", "relationships" => { "appStoreVersion" => { "data" => { "id" => version } } } }] }
    assert_raises(ForzAdvisorRelease::APIError) do
      ForzAdvisorRelease::CandidateStager.new(config: @config, api: FakeAPI.new(responses)).call(build_id: "build")
    end

    responses["/v1/reviewSubmissions/#{draft}/items"] = { "data" => [{ "id" => item, "relationships" => { "appStoreVersion" => { "data" => { "id" => version } } } }] }
    responses["/v1/appStoreVersions/#{version}/build"] = { "data" => { "id" => "unrelated-build", "attributes" => { "version" => "99" } } }
    unrelated_api = FakeAPI.new(responses)
    error = assert_raises(ForzAdvisorRelease::APIError) do
      ForzAdvisorRelease::CandidateStager.new(config: @config, api: unrelated_api).call(build_id: "build")
    end
    assert_match(/neither the configured baseline nor the exact candidate/, error.message)
    refute unrelated_api.requests.any? { |request| request[0] == "POST" || request[0] == "PATCH" }
  end

  def test_candidate_staging_checkpoints_and_observes_each_external_mutation
    app = @config.fetch("app", "id")
    draft = @config.fetch("app_store", "review_submission_id")
    version = @config.fetch("app_store", "version_id")
    item = @config.fetch("app_store", "review_submission_item_id")
    group = @config.fetch("testflight", "internal_group", "id")
    build_reads = 0
    responses = candidate_validation_responses("build").merge(
      "/v1/betaGroups/#{group}/builds" => { "data" => [{ "id" => "build" }] },
      "/v1/apps/#{app}/appStoreVersions" => { "data" => [{ "id" => version }] },
      "/v1/appStoreVersions/#{version}/build" => proc { build_reads += 1; { "data" => build_reads == 1 ? nil : { "id" => "build" } } },
      ["PATCH", "/v1/appStoreVersions/#{version}/relationships/build"] => {},
      "/v1/apps/#{app}/reviewSubmissions" => { "data" => [{ "id" => draft, "attributes" => { "state" => "READY_FOR_REVIEW", "platform" => "IOS" } }] },
      "/v1/reviewSubmissions/#{draft}/items" => { "data" => [{ "id" => item, "relationships" => { "appStoreVersion" => { "data" => { "id" => version } } } }] }
    )
    events = []
    result = ForzAdvisorRelease::CandidateStager.new(config: @config, api: FakeAPI.new(responses), checkpoint: proc { |event, evidence| events << [event, evidence] }).call(build_id: "build")
    assert_equal "staged", result["phase"]
    assert_equal %w[build_attach_intent build_attached], events.map(&:first)
  end

  def test_candidate_staging_fails_closed_when_mutation_cannot_be_observed
    app = @config.fetch("app", "id")
    draft = @config.fetch("app_store", "review_submission_id")
    version = @config.fetch("app_store", "version_id")
    item = @config.fetch("app_store", "review_submission_item_id")
    group = @config.fetch("testflight", "internal_group", "id")
    responses = candidate_validation_responses("build").merge(
      "/v1/apps/#{app}/appStoreVersions" => { "data" => [{ "id" => version }] },
      "/v1/apps/#{app}/reviewSubmissions" => { "data" => [{ "id" => draft, "attributes" => { "state" => "READY_FOR_REVIEW", "platform" => "IOS" } }] },
      "/v1/reviewSubmissions/#{draft}/items" => { "data" => [{ "id" => item, "relationships" => { "appStoreVersion" => { "data" => { "id" => version } } } }] },
      "/v1/appStoreVersions/#{version}/build" => { "data" => nil },
      "/v1/betaGroups/#{group}/builds" => { "data" => [{ "id" => "build" }] },
      ["PATCH", "/v1/appStoreVersions/#{version}/relationships/build"] => {}
    )
    events = []
    error = assert_raises(ForzAdvisorRelease::APIError) do
      ForzAdvisorRelease::CandidateStager.new(config: @config, api: FakeAPI.new(responses), checkpoint: proc { |event, _| events << event }).call(build_id: "build")
    end
    assert_match(/not observed/, error.message)
    assert_equal ["build_attach_intent"], events
  end

  def test_candidate_validation_rejects_removed_group_wrong_build_prerelease_platform_and_export_value
    group = @config.fetch("testflight", "internal_group", "id")
    mutations = {
      "wrong build" => proc { |responses| responses["/v1/builds/build"]["data"]["attributes"]["version"] = "79" },
      "wrong prerelease" => proc { |responses| responses["/v1/builds/build/preReleaseVersion"]["data"]["attributes"]["version"] = "1.41.2" },
      "wrong platform" => proc { |responses| responses["/v1/builds/build/preReleaseVersion"]["data"]["attributes"]["platform"] = "MAC_OS" },
      "missing export compliance" => proc { |responses| responses["/v1/builds/build"]["data"]["attributes"].delete("usesNonExemptEncryption") },
      "wrong export compliance" => proc { |responses| responses["/v1/builds/build"]["data"]["attributes"]["usesNonExemptEncryption"] = true },
      "removed group association" => proc { |responses| responses["/v1/betaGroups/#{group}/builds"] = { "data" => [] } }
    }
    mutations.each do |name, mutation|
      responses = candidate_validation_responses("build")
      mutation.call(responses)
      error = assert_raises(ForzAdvisorRelease::APIError, name) do
        ForzAdvisorRelease::CandidateBuildValidator.new(config: @config, api: FakeAPI.new(responses)).call(build_id: "build", require_testflight_association: true)
      end
      refute_empty error.message
    end
  end

  def test_submission_reconciles_already_submitted_state_without_patch
    api = FakeAPI.new("/v1/reviewSubmissions/draft" => { "data" => { "attributes" => { "state" => "WAITING_FOR_REVIEW" } } })
    result = ForzAdvisorRelease::CandidateStager.new(config: @config, api: api).submit(submission_id: "draft", submit: true, acknowledge: true, confirmation: "exact", expected_confirmation: "exact")
    assert_equal "app_review_submitted", result["phase"]
    refute api.requests.any? { |item| item[0] == "PATCH" }
  end

  def test_submission_resubmits_unresolved_issues_after_item_is_resolved
    reads = 0
    api = FakeAPI.new(
      "/v1/reviewSubmissions/draft" => proc do
        reads += 1
        { "data" => { "attributes" => { "state" => reads == 1 ? "UNRESOLVED_ISSUES" : "WAITING_FOR_REVIEW" } } }
      end,
      ["PATCH", "/v1/reviewSubmissions/draft"] => {}
    )

    result = ForzAdvisorRelease::CandidateStager.new(config: @config, api: api)
      .submit(submission_id: "draft", submit: true, acknowledge: true, confirmation: "exact", expected_confirmation: "exact")

    assert_equal "app_review_submitted", result["phase"]
    assert_equal "WAITING_FOR_REVIEW", result["submission_state"]
    assert api.requests.any? { |item| item[0] == "PATCH" }
  end

  def test_submission_refuses_terminal_or_ambiguous_state_without_patch
    failed_api = FakeAPI.new("/v1/reviewSubmissions/draft" => { "data" => { "attributes" => { "state" => "CANCELED" } } })
    assert_equal "submission_failed", ForzAdvisorRelease::CandidateStager.new(config: @config, api: failed_api).submit(submission_id: "draft", submit: true, acknowledge: true, confirmation: "exact", expected_confirmation: "exact")["phase"]
    refute failed_api.requests.any? { |item| item[0] == "PATCH" }

    ambiguous_api = FakeAPI.new("/v1/reviewSubmissions/draft" => { "data" => { "attributes" => { "state" => "SUBMITTING" } } })
    assert_raises(ForzAdvisorRelease::PreflightError) { ForzAdvisorRelease::CandidateStager.new(config: @config, api: ambiguous_api).submit(submission_id: "draft", submit: true, acknowledge: true, confirmation: "exact", expected_confirmation: "exact") }
    refute ambiguous_api.requests.any? { |item| item[0] == "PATCH" }
  end

  def test_fixture_url_checker_is_deterministic_and_rejects_missing_or_failed_urls
    Dir.mktmpdir do |directory|
      path = File.join(directory, "urls.json")
      File.write(path, JSON.generate("https://example.com/" => 200, "https://example.com/fail" => 404))
      checker = ForzAdvisorRelease::FixtureURLChecker.new(path)

      assert_equal true, checker.call("https://example.com/")["fixture"]
      assert_raises(ForzAdvisorRelease::PreflightError) { checker.call("https://example.com/fail") }
      assert_raises(ForzAdvisorRelease::PreflightError) { checker.call("https://missing.example/") }
    end
  end

  def test_git_repository_accepts_only_clean_pushed_configured_branch
    Dir.mktmpdir do |directory|
      config = config_for_root(directory)
      responses = {
        ["git", "remote", "get-url", "origin"] => "https://github.com/Sankofa06/ForzAdvisor.git\n",
        ["git", "status", "--porcelain"] => "",
        ["git", "rev-parse", "HEAD^{commit}"] => "#{'a' * 40}\n",
        ["git", "branch", "--show-current"] => "main\n",
        ["git", "tag", "--list", "main"] => "",
        ["git", "ls-remote", "--heads", "origin", "refs/heads/main"] => "#{'a' * 40}\trefs/heads/main\n"
      }
      result = ForzAdvisorRelease::GitRepository.new(directory, runner: FakeRunner.new(responses)).assert_release_state!(config)

      assert_equal "branch", result["ref_kind"]
      assert_equal "a" * 40, result["commit"]
      assert_raises(ForzAdvisorRelease::PreflightError) do
        ForzAdvisorRelease::GitRepository.new(directory, runner: FakeRunner.new(responses)).assert_release_state!(config, require_tag: true)
      end
    end
  end

  def test_git_repository_accepts_pushed_tag_at_head
    Dir.mktmpdir do |directory|
      config = config_for_root(directory)
      sha = "b" * 40
      responses = {
        ["git", "remote", "get-url", "origin"] => "https://github.com/Sankofa06/ForzAdvisor.git\n",
        ["git", "status", "--porcelain"] => "",
        ["git", "rev-parse", "HEAD^{commit}"] => "#{sha}\n",
        ["git", "branch", "--show-current"] => "main\n",
        ["git", "tag", "--list", "release-1.41.1"] => "release-1.41.1\n",
        ["git", "rev-list", "-n", "1", "refs/tags/release-1.41.1"] => "#{sha}\n",
        ["git", "ls-remote", "--tags", "origin", "refs/tags/release-1.41.1", "refs/tags/release-1.41.1^{}"] => "#{sha}\trefs/tags/release-1.41.1\n"
      }
      result = ForzAdvisorRelease::GitRepository.new(directory, runner: FakeRunner.new(responses)).assert_release_state!(config, ref: "release-1.41.1")

      assert_equal "tag", result["ref_kind"]
      assert_equal sha, result["commit"]
      assert_equal sha, result["peeled_tag_commit"]
    end
  end

  def test_git_repository_rejects_dirty_tree
    Dir.mktmpdir do |directory|
      config = config_for_root(directory)
      responses = {
        ["git", "remote", "get-url", "origin"] => "https://github.com/Sankofa06/ForzAdvisor.git\n",
        ["git", "status", "--porcelain"] => " M file\n"
      }
      error = assert_raises(ForzAdvisorRelease::PreflightError) do
        ForzAdvisorRelease::GitRepository.new(directory, runner: FakeRunner.new(responses)).assert_release_state!(config)
      end
      assert_match(/uncommitted changes/, error.message)
    end
  end

  def test_app_store_status_is_read_only_and_reports_source_and_current_builds
    app_id = @config.fetch("app", "id")
    responses = {
      "/v1/apps/#{app_id}" => { "data" => { "id" => app_id, "attributes" => { "name" => "ForzAdvisor", "bundleId" => "com.michaelwilliams.forzadvisor" } } },
      "/v1/apps/#{app_id}/appStoreVersions" => { "data" => [{ "id" => "version-id", "attributes" => { "appStoreState" => "READY_FOR_REVIEW" } }] },
      "/v1/apps/#{app_id}/builds" => { "data" => [{ "id" => "build-id", "attributes" => { "version" => "78", "processingState" => "VALID" } }] },
      "/v1/apps/#{app_id}/reviewSubmissions" => { "data" => [{ "id" => "submission-id", "attributes" => { "state" => "READY_FOR_REVIEW" } }] }
    }
    api = FakeAPI.new(responses)
    result = ForzAdvisorRelease::AppStoreStatus.new(config: @config, api: api).call

    assert_equal true, result["read_only"]
    assert_equal "78", result["source_build_number"]
    assert_equal "78", result.dig("build", "number")
    assert_equal "READY_FOR_REVIEW", result.dig("version", "state")
    assert_equal 4, api.requests.length
  end

  def test_app_store_preflight_emits_typed_candidate_evidence_and_rejects_wrong_build_owner
    responses = asc_preflight_responses
    result = ForzAdvisorRelease::AppStorePreflight.new(config: @config, api: FakeAPI.new(responses)).call(expected_build_id: "build-id")
    assert_equal true, result["ready"]
    assert_equal "build-id", result["build_id"]
    assert_equal "APP_STORE_ELIGIBLE", result["build_audience"]
    assert_equal 6, result["screenshot_count"]
    assert_equal "FREE", result["price_model"]
    assert_equal @config.fetch("release", "price", "manual_price_id"), result["manual_price_id"]
    assert_equal @config.fetch("release", "price", "price_point_id"), result["price_point_id"]
    assert_raises(ForzAdvisorRelease::PreflightError) { ForzAdvisorRelease::AppStorePreflight.new(config: @config, api: FakeAPI.new(responses)).call(expected_build_id: "build-id", require_selected_build: true) }
    responses["/v1/appStoreVersions/#{@config.fetch('app_store', 'version_id')}/build"] = responses["/v1/builds/build-id"]
    assert ForzAdvisorRelease::AppStorePreflight.new(config: @config, api: FakeAPI.new(responses)).call(expected_build_id: "build-id", require_selected_build: true)["ready"]

    draft = @config.fetch("app_store", "review_submission_id")
    version = @config.fetch("app_store", "version_id")
    responses["/v1/reviewSubmissions/#{draft}/items"]["data"][0]["id"] = "wrong-review-item"
    assert_raises(ForzAdvisorRelease::PreflightError) do
      ForzAdvisorRelease::AppStorePreflight.new(config: @config, api: FakeAPI.new(responses)).call(expected_build_id: "build-id", require_stageable: true)
    end
    responses["/v1/reviewSubmissions/#{draft}/items"]["data"][0]["id"] = @config.fetch("app_store", "review_submission_item_id")

    responses["/v1/appStoreVersions/#{version}/build"] = { "data" => { "id" => "unrelated-build", "attributes" => { "version" => "99" } } }
    selected_error = assert_raises(ForzAdvisorRelease::PreflightError) do
      ForzAdvisorRelease::AppStorePreflight.new(config: @config, api: FakeAPI.new(responses)).call(expected_build_id: "build-id")
    end
    assert_match(/neither the configured baseline nor the exact candidate/, selected_error.message)
    responses["/v1/appStoreVersions/#{version}/build"] = responses["/v1/builds/build-id"]

    responses["/v1/builds/build-id/app"] = { "data" => { "id" => "another-app" } }
    error = assert_raises(ForzAdvisorRelease::PreflightError) { ForzAdvisorRelease::AppStorePreflight.new(config: @config, api: FakeAPI.new(responses)).call(expected_build_id: "build-id") }
    assert_match(/identity mismatch/, error.message)
  end

  def test_app_store_preflight_requires_manual_price_relationship_and_current_effectivity
    responses = asc_preflight_responses
    app = @config.fetch("app", "id")
    endpoint = "/v1/appPriceSchedules/#{app}/manualPrices"
    manual_price = responses.fetch(endpoint).fetch("data").first
    configured_point = @config.fetch("release", "price", "price_point_id")

    manual_price["relationships"]["appPricePoint"]["data"]["id"] = "unrelated-price-point"
    relationship_error = assert_raises(ForzAdvisorRelease::PreflightError) do
      ForzAdvisorRelease::AppStorePreflight.new(config: @config, api: FakeAPI.new(responses), today: Date.new(2026, 8, 21)).call(expected_build_id: "build-id")
    end
    assert_match(/does not reference the configured Free price point/, relationship_error.message)

    manual_price["relationships"]["appPricePoint"]["data"]["id"] = configured_point
    manual_price["attributes"]["startDate"] = "2026-08-22"
    future_error = assert_raises(ForzAdvisorRelease::PreflightError) do
      ForzAdvisorRelease::AppStorePreflight.new(config: @config, api: FakeAPI.new(responses), today: Date.new(2026, 8, 21)).call(expected_build_id: "build-id")
    end
    assert_match(/not effective today/, future_error.message)

    manual_price["attributes"]["startDate"] = nil
    manual_price["attributes"]["endDate"] = "2026-08-20"
    expired_error = assert_raises(ForzAdvisorRelease::PreflightError) do
      ForzAdvisorRelease::AppStorePreflight.new(config: @config, api: FakeAPI.new(responses), today: Date.new(2026, 8, 21)).call(expected_build_id: "build-id")
    end
    assert_match(/not effective today/, expired_error.message)
  end

  def test_redactor_removes_bearer_tokens_environment_values_and_jwts
    text = "Bearer secret ASC_KEY_ID=ABC eyJheader.payload.signature"
    redacted = ForzAdvisorRelease::Redactor.call(text)

    refute_includes redacted, "secret"
    refute_includes redacted, "ABC"
    refute_includes redacted, "eyJheader"
  end

  def test_stable_runner_helper_uses_exact_upload_contract_and_parses_only_receipt_line
    commit = "a" * 40
    receipt = release_receipt(commit: commit)
    runner = RecordingRunner.new("PASS archive validated\nRELEASE_RECEIPT #{JSON.generate(receipt)}\n")
    helper = ForzAdvisorRelease::StableRunnerHelper.new(root: ROOT, runner: runner, script: "/shared/ssh_runner_build.sh")
    confirmation = "UPLOAD:IOS:#{@config.fetch('app', 'id')}:#{@config.fetch('app', 'bundle_id')}:1.41.1:78:#{commit}"
    observed = helper.upload(commit: commit, app_id: @config.fetch("app", "id"), bundle_id: @config.fetch("app", "bundle_id"), version: "1.41.1", build: "78", confirmation: confirmation)
    assert_equal receipt, observed
    command = runner.calls.first.fetch(:command)
    assert_equal "/shared/ssh_runner_build.sh", command.first
    %w[--platform iOS --archive --upload --expected-version 1.41.1 --expected-build 78 --confirm-upload].each do |argument|
      assert_includes command, argument
    end
    assert_includes command, confirmation
    assert_equal [ROOT, commit], command.last(2)

    missing = ForzAdvisorRelease::StableRunnerHelper.new(root: ROOT, runner: RecordingRunner.new("PASS only\n"), script: "/shared/helper")
    assert_raises(ForzAdvisorRelease::PreflightError) do
      missing.upload(commit: commit, app_id: "1", bundle_id: "example.app", version: "1.0.0", build: "1", confirmation: "token")
    end
  end

  def test_cli_submission_is_separate_and_double_guarded
    cli = File.read(File.join(ROOT, "scripts", "release"))
    library = File.read(File.join(ROOT, "scripts", "lib", "forzadvisor_release.rb"))

    assert_includes cli, "--submit"
    assert_includes cli, "--acknowledge-irreversible-app-review-submission"
    assert_includes cli, "--confirm-submit"
    assert_includes cli, "candidate-start"
    assert_includes cli, "candidate-status"
    assert_includes cli, "candidate-resume"
    assert_includes cli, "candidate-reconcile"
    assert_includes cli, "candidate-block"
    assert_includes cli, "human-result"
    assert_includes cli, "human ACCEPT is required before staging"
    assert_operator cli.index("require_selected_build: true, require_testflight_association: true"), :<, cli.index('"phase" => "submission_intent"')
    refute_includes cli, "cloud-start"
    assert_includes library, "SubmissionGuard.authorize!"
  end

  def test_submission_confirmation_token_binds_app_bundle_version_build_commit_and_submission
    state = stable_identity.merge("schema_version" => 2, "phase" => "staged", "review_submission_id" => "submission-1")
    coordinator = ForzAdvisorRelease::StableRunnerCoordinator.new(config: @config, git: nil, store: nil, github_verification: nil, helper: nil, api: nil)
    assert_equal ["SUBMIT", "IOS", state["app_id"], state["bundle_id"], state["marketing_version"], state["source_build_number"], state["commit"], "submission-1"].join(":"), coordinator.submission_confirmation_token(state)
  end

  private

  def github_run(tag:, commit:)
    {
      "repository" => { "full_name" => "Sankofa06/ForzAdvisor" },
      "path" => ".github/workflows/release-verify.yml",
      "event" => "workflow_dispatch",
      "display_title" => "Verify #{tag}",
      "head_branch" => tag,
      "head_sha" => commit,
      "status" => "completed",
      "conclusion" => "success"
    }
  end

  def github_job
    { "id" => 99, "name" => "Xcode 26.6 ReleaseVerify", "status" => "completed", "conclusion" => "success" }
  end

  def release_receipt(commit: "a" * 40)
    {
      "schema_version" => 1,
      "state" => "VALID",
      "app_id" => @config.fetch("app", "id"),
      "platform" => "IOS",
      "bundle_id" => @config.fetch("app", "bundle_id"),
      "marketing_version" => @config.fetch("release", "marketing_version"),
      "build" => @config.fetch("release", "source_build_number"),
      "commit" => commit,
      "runner_profile" => @config.fetch("stable_runner", "profile"),
      "xcode_build" => @config.fetch("stable_runner", "xcode_build"),
      "macos_build" => @config.fetch("stable_runner", "macos_build"),
      "sdk_version" => @config.fetch("stable_runner", "sdk_versions", "iOS"),
      "package_sha256" => "b" * 64,
      "asc_build_id" => "build-78"
    }
  end

  def candidate_build
    {
      "id" => "build-78",
      "attributes" => {
        "version" => "78",
        "processingState" => "VALID",
        "buildAudienceType" => "APP_STORE_ELIGIBLE",
        "usesNonExemptEncryption" => false
      }
    }
  end

  def stable_candidate_responses
    app = @config.fetch("app", "id")
    group = @config.fetch("testflight", "internal_group", "id")
    group_reads = 0
    {
      "/v1/apps/#{app}/builds" => { "data" => [candidate_build] },
      "/v1/builds/build-78" => { "data" => candidate_build },
      "/v1/builds/build-78/app" => { "data" => { "id" => app } },
      "/v1/builds/build-78/preReleaseVersion" => { "data" => { "attributes" => { "version" => "1.41.1", "platform" => "IOS" } } },
      "/v1/betaGroups/#{group}" => { "data" => { "id" => group, "attributes" => { "name" => "Internal", "isInternalGroup" => true } } },
      "/v1/betaGroups/#{group}/app" => { "data" => { "id" => app } },
      "/v1/betaGroups/#{group}/builds" => proc { group_reads += 1; { "data" => group_reads == 1 ? [] : [{ "id" => "build-78" }] } },
      ["POST", "/v1/betaGroups/#{group}/relationships/builds"] => {}
    }
  end

  def candidate_validation_responses(build_id)
    app = @config.fetch("app", "id")
    group = @config.fetch("testflight", "internal_group", "id")
    {
      "/v1/builds/#{build_id}" => { "data" => { "id" => build_id, "attributes" => { "version" => "78", "processingState" => "VALID", "buildAudienceType" => "APP_STORE_ELIGIBLE", "usesNonExemptEncryption" => false } } },
      "/v1/builds/#{build_id}/app" => { "data" => { "id" => app } },
      "/v1/builds/#{build_id}/preReleaseVersion" => { "data" => { "attributes" => { "version" => "1.41.1", "platform" => "IOS" } } },
      "/v1/betaGroups/#{group}" => { "data" => { "id" => group, "attributes" => { "name" => "Internal", "isInternalGroup" => true } } },
      "/v1/betaGroups/#{group}/app" => { "data" => { "id" => app } },
      "/v1/betaGroups/#{group}/builds" => { "data" => [{ "id" => build_id }] }
    }
  end

  def stable_coordinator(store:, helper:, api:, tag:, commit:)
    client = FakeGitHubClient.new(run: github_run(tag: tag, commit: commit), jobs: [github_job])
    ForzAdvisorRelease::StableRunnerCoordinator.new(
      config: @config,
      git: FakeGitRepository.new,
      store: store,
      github_verification: ForzAdvisorRelease::GitHubVerificationEvidence.new(config: @config, client: client),
      helper: helper,
      api: api
    )
  end

  def stable_identity
    {
      "app_id" => @config.fetch("app", "id"),
      "bundle_id" => @config.fetch("app", "bundle_id"),
      "marketing_version" => @config.fetch("release", "marketing_version"),
      "source_build_number" => @config.fetch("release", "source_build_number"),
      "stable_runner_profile" => @config.fetch("stable_runner", "profile"),
      "config_fingerprint" => @config.fingerprint,
      "ref" => "release-1.41.1-appstore-78",
      "commit" => "a" * 40
    }
  end

  def with_config
    Dir.mktmpdir do |directory|
      data = JSON.parse(File.read(CONFIG_PATH))
      path = File.join(directory, "config.json")
      yield data, path
    end
  end

  def config_for_root(root)
    data = JSON.parse(File.read(CONFIG_PATH))
    data["repository"]["canonical_root"] = root
    data["repository"]["release_ref"] = "main"
    path = File.join(root, "config.json")
    File.write(path, JSON.generate(data))
    ForzAdvisorRelease::Config.new(path)
  end

  def write_rgba_png(path, width, height, pixels)
    raw = pixels.each_slice(width).map { |row| "\x00".b + row.flatten.pack("C*") }.join
    signature = "\x89PNG\r\n\x1a\n".b
    header = [width, height, 8, 6, 0, 0, 0].pack("NNCCCCC")
    File.binwrite(path, signature + png_chunk("IHDR", header) + png_chunk("IDAT", Zlib::Deflate.deflate(raw)) + png_chunk("IEND", ""))
  end

  def png_chunk(type, body)
    [body.bytesize].pack("N") + type + body + [Zlib.crc32(type + body)].pack("N")
  end

  def asc_preflight_responses
    app = @config.fetch("app", "id")
    metadata = ForzAdvisorRelease::MetadataInspector.sections(File.join(ROOT, @config.fetch("metadata", "path")))
    version = @config.fetch("app_store", "version_id")
    draft = @config.fetch("app_store", "review_submission_id")
    item = @config.fetch("app_store", "review_submission_item_id")
    version_attrs = { "platform" => "IOS", "versionString" => "1.41.1", "appStoreState" => "READY_FOR_REVIEW", "releaseType" => "AFTER_APPROVAL" }
    build_attrs = { "version" => "78", "processingState" => "VALID", "buildAudienceType" => "APP_STORE_ELIGIBLE", "usesNonExemptEncryption" => false }
    selected_attrs = build_attrs.merge("version" => "78")
    screenshot_names = @config.fetch("screenshots", "ordered_files")
    candidate_validation_responses("build-id").merge(
      "/v1/apps/#{app}" => { "data" => { "id" => app, "attributes" => { "name" => "ForzAdvisor", "bundleId" => "com.michaelwilliams.forzadvisor", "contentRightsDeclaration" => "USES_THIRD_PARTY_CONTENT" } } },
      "/v1/apps/#{app}/appStoreVersions" => { "data" => [{ "id" => version }] },
      "/v1/appStoreVersions/#{version}" => { "data" => { "id" => version, "attributes" => version_attrs } },
      "/v1/appStoreVersions/#{version}/build" => { "data" => { "id" => "old-build", "attributes" => selected_attrs } },
      "/v1/builds/build-id" => { "data" => { "id" => "build-id", "attributes" => build_attrs } },
      "/v1/appStoreVersions/#{version}/appStoreVersionLocalizations" => { "data" => [{ "id" => "loc", "attributes" => { "locale" => "en-US", "description" => metadata.fetch("Description"), "keywords" => metadata.fetch("Keywords"), "promotionalText" => metadata.fetch("Promotional Text"), "marketingUrl" => @config.fetch("public_urls", "marketing"), "supportUrl" => @config.fetch("public_urls", "support") } }] },
      "/v1/appStoreVersionLocalizations/loc/appScreenshotSets" => { "data" => [{ "id" => "set" }] },
      "/v1/appScreenshotSets/set/appScreenshots" => { "data" => screenshot_names.map { |name| { "attributes" => { "fileName" => name, "imageAsset" => { "width" => 1320, "height" => 2868 }, "assetDeliveryState" => { "state" => "COMPLETE" } } } } },
      "/v1/appPriceSchedules/#{app}/manualPrices" => {
        "data" => [{
          "type" => "appPrices",
          "id" => @config.fetch("release", "price", "manual_price_id"),
          "attributes" => { "manual" => true, "startDate" => nil, "endDate" => nil },
          "relationships" => { "appPricePoint" => { "data" => { "type" => "appPricePoints", "id" => @config.fetch("release", "price", "price_point_id") } } }
        }],
        "included" => [{ "type" => "appPricePoints", "id" => @config.fetch("release", "price", "price_point_id"), "attributes" => { "customerPrice" => "0.0" } }]
      },
      "/v1/apps/#{app}/appPricePoints" => { "data" => [{ "id" => @config.fetch("release", "price", "price_point_id"), "attributes" => { "customerPrice" => "0.0" } }] },
      "/v1/appPriceSchedules/#{app}/baseTerritory" => { "data" => { "id" => "USA" } },
      "/v1/apps/#{app}/appInfos" => { "data" => [{ "id" => "info", "attributes" => { "appStoreAgeRating" => "FOUR_PLUS" } }] },
      "/v1/appInfos/info/appInfoLocalizations" => { "data" => [{ "attributes" => { "locale" => "en-US", "name" => metadata.fetch("App Name"), "subtitle" => metadata.fetch("Subtitle"), "privacyPolicyUrl" => @config.fetch("public_urls", "privacy"), "privacyChoicesUrl" => @config.fetch("public_urls", "privacy") } }] },
      "/v1/appStoreVersions/#{version}/appStoreReviewDetail" => { "data" => { "attributes" => { "contactFirstName" => "A", "contactLastName" => "B", "contactPhone" => "1", "contactEmail" => "a@example.com", "notes" => metadata.fetch("App Review Notes") } } },
      "/v1/apps/#{app}/reviewSubmissions" => { "data" => [{ "id" => draft, "attributes" => { "platform" => "IOS", "state" => "READY_FOR_REVIEW" } }] },
      "/v1/reviewSubmissions/#{draft}/items" => { "data" => [{ "id" => item, "attributes" => { "state" => "READY_FOR_REVIEW" }, "relationships" => { "appStoreVersion" => { "data" => { "id" => version } } } }] }
    )
  end
end
