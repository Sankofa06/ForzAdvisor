# frozen_string_literal: true

require "json"
require "minitest/autorun"
require "tmpdir"
require "zlib"
require_relative "../lib/forzadvisor_release"

class FakeGitRepository
  attr_accessor :error

  def assert_release_state!(_config, ref: nil, require_tag: false)
    raise error if error
    kind = require_tag ? "tag" : "branch"
    { "commit" => "a" * 40, "peeled_tag_commit" => (kind == "tag" ? "a" * 40 : nil), "ref" => ref || "main", "ref_kind" => kind, "remote" => "origin" }
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

class ForzAdvisorReleaseTest < Minitest::Test
  ROOT = File.expand_path("../..", __dir__)
  CONFIG_PATH = File.join(ROOT, "AppStore", "release-config.json")

  def setup
    @config = ForzAdvisorRelease::Config.new(CONFIG_PATH)
  end

  def test_repository_release_config_records_source_and_current_app_store_builds
    assert_equal "78", @config.fetch("release", "source_build_number")
    assert_equal "78", @config.fetch("release", "current_app_store_build_number")
    assert_equal "FREE", @config.fetch("release", "price", "model")
    assert_equal "EXPLICIT_HUMAN_APPROVAL", @config.fetch("release", "submission_policy")
    assert_equal "AFTER_APPROVAL", @config.fetch("release", "app_store_release_type")
    assert_equal false, @config.fetch("release", "privacy", "tracking")
    assert_equal "GITHUB_ACTIONS", @config.fetch("ci", "provider")
    assert_equal ".github/workflows/release-verify.yml", @config.fetch("ci", "verify_workflow")
    assert_equal ".github/workflows/release-candidate.yml", @config.fetch("ci", "release_candidate_workflow")
    assert_equal "GITHUB_HOSTED_UPLOAD", @config.fetch("ci", "release_candidate_mode")
  end

  def test_hosted_candidate_workflow_rejects_beta_hosts_and_wrong_builds
    workflow = File.read(File.join(ROOT, ".github", "workflows", "release-candidate.yml"))

    assert_includes workflow, "runs-on: macos-26"
    assert_includes workflow, "DEVELOPER_DIR: /Applications/Xcode_26.6.app/Contents/Developer"
    assert_includes workflow, 'test "$(sw_vers -productVersion)" = "26.5.2"'
    assert_includes workflow, 'test "$(sw_vers -buildVersion)" = "25F84"'
    assert_includes workflow, 'test "$build_machine" = "25F84"'
    assert_includes workflow, 'CFBundleVersion\' "$app_info")" = "78"'
    assert_includes workflow, 'DTXcodeBuild\' "$app_info")" = "17F113"'
    assert_includes workflow, "environment: app-store-release"
    assert_includes workflow, "ASC_PRIVATE_KEY: \u0024{{ secrets.ASC_PRIVATE_KEY }}"
    assert_includes workflow, "destination -string upload"
    refute_includes workflow, "AuthKey_US3X9C5DR5"
  end

  def test_verify_workflow_pins_exact_commit_and_stable_toolchain
    workflow = File.read(File.join(ROOT, ".github", "workflows", "release-verify.yml"))

    assert_includes workflow, 'RELEASE_SHA: ${{ inputs.release_sha }}'
    assert_includes workflow, 'test "$(git rev-parse HEAD)" = "$RELEASE_SHA"'
    assert_includes workflow, 'test "$(sw_vers -productVersion)" = "26.5.2"'
    assert_includes workflow, 'test "$(sw_vers -buildVersion)" = "25F84"'
    assert_includes workflow, 'test "$(xcodebuild -version | tail -1)" = "Build version 17F113"'
  end

  def test_config_rejects_unapproved_ci_or_hosted_distribution_mode
    with_config do |data, path|
      data["ci"]["provider"] = "UNTRUSTED_CI"
      File.write(path, JSON.generate(data))
      assert_raises(ForzAdvisorRelease::ConfigurationError) { ForzAdvisorRelease::Config.new(path) }
    end
    with_config do |data, path|
      data["ci"]["release_candidate_mode"] = "UNSUPPORTED"
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
      data["xcode_cloud"]["product_id"] = "not-a-uuid"
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
    assert_raises(ForzAdvisorRelease::PreflightError) { ForzAdvisorRelease::SubmissionGuard.authorize!(submit: false, acknowledge_irreversible_app_review_submission: false) }
    assert_raises(ForzAdvisorRelease::PreflightError) { ForzAdvisorRelease::SubmissionGuard.authorize!(submit: true, acknowledge_irreversible_app_review_submission: false) }
    assert_raises(ForzAdvisorRelease::PreflightError) { ForzAdvisorRelease::SubmissionGuard.authorize!(submit: false, acknowledge_irreversible_app_review_submission: true) }
    assert ForzAdvisorRelease::SubmissionGuard.authorize!(submit: true, acknowledge_irreversible_app_review_submission: true)
  end

  def test_cloud_coordinator_orders_verify_before_candidate_and_checks_commit
    git = FakeGitRepository.new
    refs = { "data" => [{ "id" => "ref", "attributes" => { "kind" => "TAG", "canonicalName" => "refs/tags/release-1.41.1" } }] }
    responses = {
      "/v1/scmRepositories/#{@config.fetch('xcode_cloud', 'repository_id')}/gitReferences" => refs,
      "/v1/ciWorkflows/#{@config.fetch('xcode_cloud', 'workflows', 'verify', 'id')}/buildRuns" => { "data" => [] },
      "/v1/ciWorkflows/#{@config.fetch('xcode_cloud', 'workflows', 'release_candidate', 'id')}/buildRuns" => { "data" => [] },
      ["POST", "/v1/ciBuildRuns"] => { "data" => { "id" => "run" } },
      "/v1/ciBuildRuns/run" => { "data" => { "attributes" => { "executionProgress" => "COMPLETE", "completionStatus" => "SUCCEEDED", "sourceCommit" => "a" * 40 } } }
    }
    Dir.mktmpdir do |directory|
      api = FakeAPI.new(responses)
      coordinator = ForzAdvisorRelease::CloudCoordinator.new(config: @config, api: api, git: git, store: ForzAdvisorRelease::StateStore.new(directory: directory))
      started = coordinator.start(ref: "release-1.41.1")
      assert_equal "verify_running", started["phase"]
      assert_equal "78", started["source_build_number"]
      assert_equal "FREE", started.dig("price", "model")
      assert_equal "candidate_running", coordinator.resume["phase"]
      assert_equal 2, api.requests.count { |item| item[0] == "POST" }
      assert_equal 0o600, File.stat(File.join(directory, "active.json")).mode & 0o777
    end
  end

  def test_cloud_start_reconciles_run_created_after_persisted_intent_without_duplicate_post
    tag = "release-1.41.1"
    refs = { "data" => [{ "id" => "ref", "attributes" => { "kind" => "TAG", "canonicalName" => "refs/tags/#{tag}" } }] }
    workflow = @config.fetch("xcode_cloud", "workflows", "verify", "id")
    recovered = { "id" => "accepted-run", "attributes" => { "createdDate" => "2026-08-22T02:00:01Z", "startReason" => "MANUAL", "sourceCommit" => "a" * 40, "executionProgress" => "COMPLETE", "completionStatus" => "FAILED" } }
    responses = {
      "/v1/scmRepositories/#{@config.fetch('xcode_cloud', 'repository_id')}/gitReferences" => refs,
      "/v1/ciWorkflows/#{workflow}/buildRuns" => { "data" => [recovered] },
      "/v1/ciBuildRuns/accepted-run" => { "data" => { "attributes" => { "sourceCommit" => "a" * 40, "executionProgress" => "COMPLETE", "completionStatus" => "FAILED" } } }
    }
    Dir.mktmpdir do |directory|
      store = ForzAdvisorRelease::StateStore.new(directory: directory)
      store.save("commit" => "a" * 40, "peeled_tag_commit" => "a" * 40, "ref" => tag, "ref_kind" => "tag", "remote" => "origin", "phase" => "verify_start_intent", "verify_start_intent_at" => "2026-08-22T02:00:00Z", "verify_start_request" => { "reference_id" => "ref", "clean" => true })
      api = FakeAPI.new(responses)
      coordinator = ForzAdvisorRelease::CloudCoordinator.new(config: @config, api: api, git: FakeGitRepository.new, store: store)
      assert_raises(ForzAdvisorRelease::APIError) { coordinator.start(ref: tag) }
      refute api.requests.any? { |item| item[0] == "POST" }
      recovered["attributes"]["clean"] = true
      recovered["relationships"] = { "sourceBranchOrTag" => { "data" => { "id" => "ref" } } }
      state = coordinator.start(ref: tag)
      assert_equal "accepted-run", state["verify_run_id"]
      refute api.requests.any? { |item| item[0] == "POST" }
      assert_equal "verify_failed", ForzAdvisorRelease::CloudCoordinator.new(config: @config, api: api, git: FakeGitRepository.new, store: store).status["phase"]
    end
  end

  def test_cloud_recovery_uses_persisted_start_reference_not_freshly_resolved_reference
    tag = "release-1.41.1"
    workflow = @config.fetch("xcode_cloud", "workflows", "verify", "id")
    recovered = { "id" => "accepted-run", "attributes" => { "createdDate" => "2026-08-22T02:00:01Z", "startReason" => "MANUAL", "sourceCommit" => "a" * 40, "clean" => true }, "relationships" => { "sourceBranchOrTag" => { "data" => { "id" => "fresh-ref" } } } }
    responses = {
      "/v1/scmRepositories/#{@config.fetch('xcode_cloud', 'repository_id')}/gitReferences" => { "data" => [{ "id" => "fresh-ref", "attributes" => { "kind" => "TAG", "canonicalName" => "refs/tags/#{tag}" } }] },
      "/v1/ciWorkflows/#{workflow}/buildRuns" => { "data" => [recovered] }
    }
    Dir.mktmpdir do |directory|
      store = ForzAdvisorRelease::StateStore.new(directory: directory)
      store.save("commit" => "a" * 40, "peeled_tag_commit" => "a" * 40, "ref" => tag, "ref_kind" => "tag", "remote" => "origin", "phase" => "verify_start_intent", "verify_start_intent_at" => "2026-08-22T02:00:00Z", "verify_start_request" => { "reference_id" => "persisted-ref", "clean" => true })
      api = FakeAPI.new(responses)
      assert_raises(ForzAdvisorRelease::APIError) do
        ForzAdvisorRelease::CloudCoordinator.new(config: @config, api: api, git: FakeGitRepository.new, store: store).start(ref: tag)
      end
      refute api.requests.any? { |item| item[0] == "POST" }
    end
  end

  def test_cloud_start_rejects_a_different_active_release_and_archives_only_terminal_state
    refs = { "data" => [{ "id" => "ref", "attributes" => { "kind" => "TAG", "canonicalName" => "refs/tags/release-1.41.1" } }] }
    workflow = @config.fetch("xcode_cloud", "workflows", "verify", "id")
    responses = {
      "/v1/scmRepositories/#{@config.fetch('xcode_cloud', 'repository_id')}/gitReferences" => refs,
      "/v1/ciWorkflows/#{workflow}/buildRuns" => { "data" => [] },
      ["POST", "/v1/ciBuildRuns"] => { "data" => { "id" => "new-run" } }
    }
    Dir.mktmpdir do |directory|
      store = ForzAdvisorRelease::StateStore.new(directory: directory)
      store.save("commit" => "b" * 40, "ref" => "release-old", "phase" => "verify_running")
      api = FakeAPI.new(responses)
      coordinator = ForzAdvisorRelease::CloudCoordinator.new(config: @config, api: api, git: FakeGitRepository.new, store: store)
      assert_raises(ForzAdvisorRelease::PreflightError) { coordinator.start(ref: "release-1.41.1") }
      refute api.requests.any? { |item| item[0] == "POST" }

      store.save("commit" => "b" * 40, "ref" => "release-old", "phase" => "verify_failed")
      assert_equal "verify_running", coordinator.start(ref: "release-1.41.1")["phase"]
      archives = Dir.glob(File.join(directory, "history", "*.json"))
      assert_equal 1, archives.length
      assert_equal "release-old", JSON.parse(File.read(archives.first))["ref"]
      assert_equal 0o600, File.stat(archives.first).mode & 0o777
    end
  end

  def test_release_candidate_discovers_new_build_number_from_exact_run
    app = @config.fetch("app", "id")
    responses = {
      "/v1/ciBuildRuns/candidate" => { "data" => { "attributes" => { "executionProgress" => "COMPLETE", "completionStatus" => "SUCCEEDED", "sourceCommit" => "a" * 40 } } },
      "/v1/ciBuildRuns/candidate/builds" => { "data" => [{ "id" => "build-6" }] },
      "/v1/builds/build-6" => { "data" => { "id" => "build-6", "attributes" => { "version" => "6", "processingState" => "VALID", "buildAudienceType" => "APP_STORE_ELIGIBLE" } } },
      "/v1/builds/build-6/app" => { "data" => { "id" => app } },
      "/v1/builds/build-6/preReleaseVersion" => { "data" => { "attributes" => { "version" => "1.41.1", "platform" => "IOS" } } }
    }
    Dir.mktmpdir do |directory|
      store = ForzAdvisorRelease::StateStore.new(directory: directory)
      store.save("phase" => "candidate_running", "candidate_run_id" => "candidate", "commit" => "a" * 40)
      state = ForzAdvisorRelease::CloudCoordinator.new(config: @config, api: FakeAPI.new(responses), git: FakeGitRepository.new, store: store).resume
      assert_equal "candidate_ready", state["phase"]
      assert_equal "6", state["app_store_build_number"]
      assert_equal "build-6", state["build_id"]
    end
  end

  def test_candidate_staging_reuses_attached_build_draft_and_item
    app = @config.fetch("app", "id")
    draft = @config.fetch("app_store", "review_submission_id")
    version = @config.fetch("app_store", "version_id")
    item = @config.fetch("app_store", "review_submission_item_id")
    responses = {
      "/v1/betaGroups/#{@config.fetch('testflight', 'internal_group', 'id')}/builds" => { "data" => [{ "id" => "build" }] },
      "/v1/apps/#{app}/appStoreVersions" => { "data" => [{ "id" => version }] },
      "/v1/builds/build" => { "data" => { "id" => "build", "attributes" => { "processingState" => "VALID", "buildAudienceType" => "APP_STORE_ELIGIBLE" } } },
      "/v1/builds/build/app" => { "data" => { "id" => app } },
      "/v1/appStoreVersions/#{version}/build" => { "data" => { "id" => "build" } },
      "/v1/apps/#{app}/reviewSubmissions" => { "data" => [{ "id" => draft, "attributes" => { "state" => "READY_FOR_REVIEW", "platform" => "IOS" } }] },
      "/v1/reviewSubmissions/#{draft}/items" => { "data" => [{ "id" => item, "relationships" => { "appStoreVersion" => { "data" => { "id" => version } } } }] }
    }
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
    assert_match(/neither the configured baseline nor the cloud candidate/, error.message)
    refute unrelated_api.requests.any? { |request| request[0] == "POST" || request[0] == "PATCH" }
  end

  def test_candidate_staging_checkpoints_and_observes_each_external_mutation
    app = @config.fetch("app", "id")
    draft = @config.fetch("app_store", "review_submission_id")
    version = @config.fetch("app_store", "version_id")
    item = @config.fetch("app_store", "review_submission_item_id")
    group = @config.fetch("testflight", "internal_group", "id")
    group_reads = 0
    build_reads = 0
    responses = {
      "/v1/betaGroups/#{group}/builds" => proc { group_reads += 1; { "data" => group_reads == 1 ? [] : [{ "id" => "build" }] } },
      ["POST", "/v1/betaGroups/#{group}/relationships/builds"] => {},
      "/v1/apps/#{app}/appStoreVersions" => { "data" => [{ "id" => version }] },
      "/v1/builds/build" => { "data" => { "id" => "build", "attributes" => { "processingState" => "VALID", "buildAudienceType" => "APP_STORE_ELIGIBLE" } } },
      "/v1/builds/build/app" => { "data" => { "id" => app } },
      "/v1/appStoreVersions/#{version}/build" => proc { build_reads += 1; { "data" => build_reads == 1 ? nil : { "id" => "build" } } },
      ["PATCH", "/v1/appStoreVersions/#{version}/relationships/build"] => {},
      "/v1/apps/#{app}/reviewSubmissions" => { "data" => [{ "id" => draft, "attributes" => { "state" => "READY_FOR_REVIEW", "platform" => "IOS" } }] },
      "/v1/reviewSubmissions/#{draft}/items" => { "data" => [{ "id" => item, "relationships" => { "appStoreVersion" => { "data" => { "id" => version } } } }] }
    }
    events = []
    result = ForzAdvisorRelease::CandidateStager.new(config: @config, api: FakeAPI.new(responses), checkpoint: proc { |event, evidence| events << [event, evidence] }).call(build_id: "build")
    assert_equal "staged", result["phase"]
    assert_equal %w[testflight_attach_intent testflight_attached build_attach_intent build_attached], events.map(&:first)
  end

  def test_candidate_staging_fails_closed_when_mutation_cannot_be_observed
    app = @config.fetch("app", "id")
    draft = @config.fetch("app_store", "review_submission_id")
    version = @config.fetch("app_store", "version_id")
    item = @config.fetch("app_store", "review_submission_item_id")
    group = @config.fetch("testflight", "internal_group", "id")
    responses = {
      "/v1/apps/#{app}/appStoreVersions" => { "data" => [{ "id" => version }] },
      "/v1/builds/build" => { "data" => { "id" => "build", "attributes" => { "processingState" => "VALID", "buildAudienceType" => "APP_STORE_ELIGIBLE" } } },
      "/v1/builds/build/app" => { "data" => { "id" => app } },
      "/v1/apps/#{app}/reviewSubmissions" => { "data" => [{ "id" => draft, "attributes" => { "state" => "READY_FOR_REVIEW", "platform" => "IOS" } }] },
      "/v1/reviewSubmissions/#{draft}/items" => { "data" => [{ "id" => item, "relationships" => { "appStoreVersion" => { "data" => { "id" => version } } } }] },
      "/v1/appStoreVersions/#{version}/build" => { "data" => nil },
      "/v1/betaGroups/#{group}/builds" => { "data" => [] },
      ["POST", "/v1/betaGroups/#{group}/relationships/builds"] => {}
    }
    events = []
    error = assert_raises(ForzAdvisorRelease::APIError) do
      ForzAdvisorRelease::CandidateStager.new(config: @config, api: FakeAPI.new(responses), checkpoint: proc { |event, _| events << event }).call(build_id: "build")
    end
    assert_match(/not observed/, error.message)
    assert_equal ["testflight_attach_intent"], events
  end

  def test_submission_reconciles_already_submitted_state_without_patch
    api = FakeAPI.new("/v1/reviewSubmissions/draft" => { "data" => { "attributes" => { "state" => "WAITING_FOR_REVIEW" } } })
    result = ForzAdvisorRelease::CandidateStager.new(config: @config, api: api).submit(submission_id: "draft", submit: true, acknowledge: true)
    assert_equal "app_review_submitted", result["phase"]
    refute api.requests.any? { |item| item[0] == "PATCH" }
  end

  def test_submission_refuses_terminal_or_ambiguous_state_without_patch
    failed_api = FakeAPI.new("/v1/reviewSubmissions/draft" => { "data" => { "attributes" => { "state" => "CANCELED" } } })
    assert_equal "submission_failed", ForzAdvisorRelease::CandidateStager.new(config: @config, api: failed_api).submit(submission_id: "draft", submit: true, acknowledge: true)["phase"]
    refute failed_api.requests.any? { |item| item[0] == "PATCH" }

    ambiguous_api = FakeAPI.new("/v1/reviewSubmissions/draft" => { "data" => { "attributes" => { "state" => "SUBMITTING" } } })
    assert_raises(ForzAdvisorRelease::PreflightError) { ForzAdvisorRelease::CandidateStager.new(config: @config, api: ambiguous_api).submit(submission_id: "draft", submit: true, acknowledge: true) }
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
    assert_match(/neither the configured baseline nor the cloud candidate/, selected_error.message)
    responses["/v1/appStoreVersions/#{version}/build"] = responses["/v1/builds/build-id"]

    responses["/v1/builds/build-id/app"] = { "data" => { "id" => "another-app" } }
    error = assert_raises(ForzAdvisorRelease::PreflightError) { ForzAdvisorRelease::AppStorePreflight.new(config: @config, api: FakeAPI.new(responses)).call(expected_build_id: "build-id") }
    assert_match(/another app/, error.message)
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

  def test_cli_submission_is_separate_and_double_guarded
    cli = File.read(File.join(ROOT, "scripts", "release"))
    library = File.read(File.join(ROOT, "scripts", "lib", "forzadvisor_release.rb"))

    assert_includes cli, "--submit"
    assert_includes cli, "--acknowledge-irreversible-app-review-submission"
    assert_includes library, "SubmissionGuard.authorize!"
  end

  private

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
    build_attrs = { "version" => "6", "processingState" => "VALID", "buildAudienceType" => "APP_STORE_ELIGIBLE", "usesNonExemptEncryption" => false }
    selected_attrs = build_attrs.merge("version" => "78")
    screenshot_names = @config.fetch("screenshots", "ordered_files")
    {
      "/v1/apps/#{app}" => { "data" => { "id" => app, "attributes" => { "name" => "ForzAdvisor", "bundleId" => "com.michaelwilliams.forzadvisor", "contentRightsDeclaration" => "USES_THIRD_PARTY_CONTENT" } } },
      "/v1/apps/#{app}/appStoreVersions" => { "data" => [{ "id" => version }] },
      "/v1/appStoreVersions/#{version}" => { "data" => { "id" => version, "attributes" => version_attrs } },
      "/v1/appStoreVersions/#{version}/build" => { "data" => { "id" => "old-build", "attributes" => selected_attrs } },
      "/v1/builds/build-id" => { "data" => { "id" => "build-id", "attributes" => build_attrs } },
      "/v1/builds/build-id/app" => { "data" => { "id" => app } },
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
    }
  end
end
