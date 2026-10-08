# frozen_string_literal: true

require "json"
require "fileutils"
require "minitest/autorun"
require "open3"
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

  def test_stable_runner_remote_payload_has_valid_zsh_syntax_when_available
    zsh_directory = ENV.fetch("PATH", "").split(File::PATH_SEPARATOR).find do |directory|
      File.executable?(File.join(directory, "zsh"))
    end
    zsh = File.join(zsh_directory, "zsh") if zsh_directory
    skip "zsh unavailable in this environment" unless zsh

    helper = File.read(File.join(ROOT, "scripts", "stable-runner", "ssh_runner_build.sh"))
    payload = helper.match(/<<'REMOTE_SCRIPT'\n(.*?)\nREMOTE_SCRIPT/m)
    refute_nil payload

    stdout, stderr, status = Open3.capture3(zsh, "-n", "-c", payload[1])
    assert status.success?, [stdout, stderr].reject(&:empty?).join("\n")
  end

  def test_stable_runner_pins_local_control_scripts_to_the_exact_commit_before_ssh
    helper = File.read(File.join(ROOT, "scripts", "stable-runner", "ssh_runner_build.sh"))
    pin_function = helper.index("verify_committed_control_file()")
    helper_pin = helper.index("verify_committed_control_file scripts/stable-runner/ssh_runner_build.sh")
    preflight_pin = helper.index("verify_committed_control_file scripts/stable-runner/ssh_runner_preflight.sh")
    waiter_pin = helper.index("verify_committed_control_file scripts/stable-runner/wait_for_asc_build.rb")
    ssh_preflight = helper.index('"$script_dir/ssh_runner_preflight.sh" "$profile_path"')
    first_ssh = helper.index('ssh -o LogLevel=QUIET "$ssh_host"')

    refute_nil pin_function
    refute_nil helper_pin
    refute_nil preflight_pin
    refute_nil waiter_pin
    refute_nil ssh_preflight
    refute_nil first_ssh
    assert_includes helper, 'git -C "$repo_path" show "${canonical_commit}:$relative_path" 2>/dev/null | cmp -s - "$local_path"'
    assert_includes helper, 'script_path=${0:A}'
    assert_operator pin_function, :<, helper_pin
    assert_operator helper_pin, :<, preflight_pin
    assert_operator preflight_pin, :<, waiter_pin
    assert_operator waiter_pin, :<, ssh_preflight
    assert_operator ssh_preflight, :<, first_ssh
  end

  def test_private_signing_metadata_is_loaded_from_json_and_fails_closed_on_invalid_paths
    helper = File.read(File.join(ROOT, "scripts", "stable-runner", "ssh_runner_build.sh"))
    assert_includes helper, "validate_ios_signing_metadata.py"
    assert_includes helper, %q{keychain_path=$(jq -r '.keychainPath // empty' "$signing_metadata")}
    assert_includes helper, %q{password_file=$(jq -r '.passwordFile // empty' "$signing_metadata")}
    refute_includes helper, %q{print -r -- "$signing_metadata" | jq}
    assert_includes helper, "keychain_unlocked=0"
    assert_includes helper, "if (( keychain_unlocked == 1 )) && [[ -n \"$keychain_path\" ]]; then"

    validator = File.join(ROOT, "scripts", "stable-runner", "validate_ios_signing_metadata.py")
    bundle_id = "com.michaelwilliams.forzadvisor"

    Dir.mktmpdir("forzadvisor-signing-fixture") do |home|
      metadata_directory = File.join(home, ".codex", "release-runners")
      secrets_directory = File.join(home, ".codex", "secrets")
      keychain_directory = File.join(home, "Library", "Keychains")
      FileUtils.mkdir_p([metadata_directory, secrets_directory, keychain_directory])
      metadata_path = File.join(metadata_directory, "signing.json")
      keychain_path = File.join(keychain_directory, "release.keychain-db")
      password_path = File.join(secrets_directory, "keychain-password")
      File.write(keychain_path, "test-only keychain fixture")
      File.write(password_path, "test-only password fixture")
      File.chmod(0o600, keychain_path)
      File.chmod(0o600, password_path)

      fixture = {
        "keychainPath" => keychain_path,
        "passwordFile" => password_path,
        "platforms" => {
          "iOS" => {
            "certificateId" => "fixture-certificate",
            "certificateType" => "DISTRIBUTION",
            "certificateExpirationDate" => "2099-12-31T23:59:59Z",
            "profiles" => {
              bundle_id => {
                "profileId" => "fixture-profile",
                "profileName" => "Fixture App Store Profile",
                "profileUuid" => "00000000-0000-4000-8000-000000000089",
                "profileType" => "IOS_APP_STORE",
                "profileState" => "ACTIVE",
                "profileExpirationDate" => "2099-12-31T23:59:59Z"
              }
            }
          }
        }
      }
      File.write(metadata_path, JSON.pretty_generate(fixture))
      File.chmod(0o600, metadata_path)

      command = [
        "python3", validator,
        "--metadata-relative", ".codex/release-runners/signing.json",
        "--bundle-id", bundle_id,
        "--platform", "iOS"
      ]
      stdout, stderr, status = Open3.capture3({ "HOME" => home }, *command)
      assert status.success?, stderr
      assert_empty stdout
      assert_empty stderr

      jq_stdout, jq_stderr, jq_status = Open3.capture3(
        "jq", "-r", ".keychainPath // empty", metadata_path
      )
      assert jq_status.success?, jq_stderr
      assert_equal keychain_path, jq_stdout.strip
      _path_stdout, _path_stderr, path_as_json_status = Open3.capture3(
        "jq", "-r", ".keychainPath // empty", stdin_data: metadata_path
      )
      refute path_as_json_status.success?, "a pathname passed as JSON must fail closed"

      File.write(metadata_path, metadata_path + "\n")
      _stdout, invalid_stderr, invalid_status = Open3.capture3({ "HOME" => home }, *command)
      refute invalid_status.success?
      assert_equal "signing metadata validation failed\n", invalid_stderr

      escaped_keychain = File.join(home, "outside", "release.keychain-db")
      FileUtils.mkdir_p(File.dirname(escaped_keychain))
      File.write(escaped_keychain, "test-only outside keychain fixture")
      File.chmod(0o600, escaped_keychain)
      fixture["keychainPath"] = escaped_keychain
      File.write(metadata_path, JSON.pretty_generate(fixture))
      _stdout, escaped_keychain_stderr, escaped_keychain_status = Open3.capture3({ "HOME" => home }, *command)
      refute escaped_keychain_status.success?
      assert_equal "signing metadata validation failed\n", escaped_keychain_stderr

      fixture["keychainPath"] = keychain_path
      fixture["passwordFile"] = File.join(home, "outside", "password")
      FileUtils.mkdir_p(File.dirname(fixture["passwordFile"]))
      File.write(fixture["passwordFile"], "test-only outside password fixture")
      File.chmod(0o600, fixture["passwordFile"])
      File.write(metadata_path, JSON.pretty_generate(fixture))
      _stdout, escaped_password_stderr, escaped_password_status = Open3.capture3({ "HOME" => home }, *command)
      refute escaped_password_status.success?
      assert_equal "signing metadata validation failed\n", escaped_password_stderr

      fixture["passwordFile"] = password_path
      keychain_root_backup = File.join(home, "Library", "Keychains-original")
      FileUtils.mv(keychain_directory, keychain_root_backup)
      FileUtils.ln_s(keychain_root_backup, keychain_directory)
      File.write(metadata_path, JSON.pretty_generate(fixture))
      _stdout, linked_keychain_root_stderr, linked_keychain_root_status = Open3.capture3({ "HOME" => home }, *command)
      refute linked_keychain_root_status.success?
      assert_equal "signing metadata validation failed\n", linked_keychain_root_stderr
      FileUtils.rm_f(keychain_directory)
      FileUtils.mv(keychain_root_backup, keychain_directory)

      metadata_root_backup = File.join(home, ".codex", "release-runners-original")
      FileUtils.mv(metadata_directory, metadata_root_backup)
      FileUtils.ln_s(metadata_root_backup, metadata_directory)
      _stdout, linked_metadata_root_stderr, linked_metadata_root_status = Open3.capture3({ "HOME" => home }, *command)
      refute linked_metadata_root_status.success?
      assert_equal "signing metadata validation failed\n", linked_metadata_root_stderr
    end
  end

  def test_stable_runner_workspace_allocator_rejects_symlink_and_traversal_paths
    helper = File.read(File.join(ROOT, "scripts", "stable-runner", "ssh_runner_build.sh"))
    assert_includes helper, 'git -C "$repo_path" show "${canonical_commit}:scripts/stable-runner/allocate_remote_task.py"'
    assert_includes helper, 'python3 "$task_dir/scripts/stable-runner/allocate_remote_task.py" validate'
    allocator = File.join(ROOT, "scripts", "stable-runner", "allocate_remote_task.py")
    python = <<~PYTHON
      import importlib.util
      import shutil
      import sys
      import tempfile
      from pathlib import Path

      spec = importlib.util.spec_from_file_location("workspace_allocator", sys.argv[1])
      module = importlib.util.module_from_spec(spec)
      spec.loader.exec_module(module)
      base = Path(sys.argv[2]).resolve(strict=True)
      root, task = module.allocate_remote_task(str(base / "valid-workspace"), "ForzAdvisor", "abcdef012345", base)
      assert root == base / "valid-workspace"
      assert task.parent == root and task.is_dir()
      shutil.rmtree(task)

      outside = Path(tempfile.mkdtemp(prefix="forzadvisor-outside-", dir=base.parent))
      link = base / "workspace-link"
      link.symlink_to(outside, target_is_directory=True)

      def rejected(path):
          try:
              module.allocate_remote_task(str(path), "ForzAdvisor", "abcdef012345", base)
          except module.UnsafeWorkspaceError:
              return True
          return False

      assert rejected(link / "task")
      assert rejected(base / "traversal" / ".." / "escape")
      assert not list(outside.iterdir())
      outside.rmdir()
    PYTHON

    Dir.mktmpdir("forzadvisor-workspace-test") do |temp_root|
      stdout, stderr, status = Open3.capture3({ "PYTHONDONTWRITEBYTECODE" => "1" }, "python3", "-c", python, allocator, temp_root)
      assert status.success?, [stdout, stderr].reject(&:empty?).join("\n")
      assert_empty stdout
      assert_empty stderr
    end
  end

  def test_archive_lock_is_preserved_when_sensitive_cleanup_fails
    helper = File.read(File.join(ROOT, "scripts", "stable-runner", "ssh_runner_build.sh"))
    payload = helper.match(/<<'REMOTE_SCRIPT'\n(.*?)\nREMOTE_SCRIPT/m)
    refute_nil payload
    assert_includes payload[1], 'rm -rf -- "$credential_dir" || cleanup_failed=1'
    assert_includes payload[1], 'restore_keychain_context || cleanup_failed=1'
    assert_includes payload[1], 'release_archive_lock_if_clean "$cleanup_failed" "$lock_owned" "$release_lock" "$workspace_root" || lock_release_status=$?'

    lock_function = payload[1].match(/^release_archive_lock_if_clean\(\) \{\n.*?^\}/m)
    cleanup_function = payload[1].match(/^cleanup_remote\(\) \{\n.*?^\}/m)
    refute_nil lock_function
    refute_nil cleanup_function
    zsh = ENV.fetch("PATH", "").split(File::PATH_SEPARATOR).map { |directory| File.join(directory, "zsh") }.find { |path| File.executable?(path) }
    skip "zsh unavailable in this environment" unless zsh

    Dir.mktmpdir("forzadvisor-archive-lock-test") do |workspace_root|
      ["credential-directory removal failure", "keychain-context restoration failure"].each do |failure_case|
        task_dir = File.join(workspace_root, "ForzAdvisor-abcdef012345-task")
        lock_path = File.join(workspace_root, ".archive-upload.lock")
        credential_dir = File.join(task_dir, ".credentials-test")
        FileUtils.mkdir_p([lock_path, credential_dir])
        File.write(File.join(lock_path, "owner"), "a" * 40)
        File.write(File.join(credential_dir, "private-test-file"), "test only")
        setup = if failure_case.start_with?("credential")
          'rm() { return 1; }; original_keychains_captured=0; keychain_path=""'
        else
          'restore_keychain_context() { return 1; }; original_keychains_captured=1; keychain_path=""; credential_dir=""'
        end
        command = [lock_function[0], cleanup_function[0], setup,
                   'task_dir="$1"; workspace_root="$2"; release_lock="$workspace_root/.archive-upload.lock"; lock_owned=1; true; cleanup_remote'].join("\n")
        _stdout, _stderr, status = Open3.capture3(zsh, "-c", command, "lock-cleanup-test", task_dir, workspace_root)
        assert_equal 1, status.exitstatus, failure_case
        assert File.directory?(lock_path), failure_case
        assert File.file?(File.join(lock_path, "owner")), failure_case
        if failure_case.start_with?("credential")
          assert File.directory?(credential_dir), failure_case
        end
        FileUtils.rm_rf(task_dir)
        FileUtils.rm_rf(lock_path)
      end
    end
  end

  def test_repository_release_config_records_verification_only_ci_and_stable_runner
    assert_equal "89", @config.fetch("release", "source_build_number")
    assert_equal "87", @config.fetch("release", "current_app_store_build_number")
    assert_equal "release-1.41.2-testflight-89-6", @config.fetch("repository", "release_ref")
    assert_equal "FREE", @config.fetch("release", "price", "model")
    assert_equal "EXPLICIT_HUMAN_APPROVAL", @config.fetch("release", "submission_policy")
    assert_equal "AFTER_APPROVAL", @config.fetch("release", "app_store_release_type")
    assert_equal false, @config.fetch("release", "privacy", "tracking")
    assert_equal 2, @config.fetch("schema_version")
    assert_equal "GITHUB_ACTIONS", @config.fetch("ci", "provider")
    assert_equal "VERIFICATION_ONLY", @config.fetch("ci", "authority")
    assert_equal ".github/workflows/release-verify.yml", @config.fetch("ci", "verify_workflow")
    assert_equal "26.6.2", @config.fetch("ci", "runner_os_version")
    assert_equal "25G83", @config.fetch("ci", "runner_os_build")
    refute @config.fetch("ci").key?("release_candidate_workflow")
    refute @config.fetch("ci").key?("release_candidate_mode")
    assert_equal "stable-xcode-26.3-intel", @config.fetch("stable_runner", "profile")
    assert_equal "17C529", @config.fetch("stable_runner", "xcode_build")
    assert_equal "24G830", @config.fetch("stable_runner", "macos_build")
    assert_equal "26.2", @config.fetch("stable_runner", "sdk_versions", "iOS")
    assert_equal ["arm64"], @config.fetch("stable_runner", "architectures", "iOS")
    assert_equal "manual", @config.fetch("stable_runner", "signing", "mode")
    refute @config.fetch("stable_runner", "signing").key?("certificate_id")
    refute @config.fetch("stable_runner", "signing").key?("profile_id")
    refute @config.fetch("stable_runner", "signing").key?("profile_name")
    assert_equal false, @config.fetch("stable_runner", "export", "test_flight_internal_testing_only")
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

    assert_includes workflow, "runs-on: macos-26"
    assert_includes workflow, 'RELEASE_SHA: ${{ inputs.release_sha }}'
    assert_includes workflow, 'test "$(git rev-parse HEAD)" = "$RELEASE_SHA"'
    assert_includes workflow, 'if [[ "$GITHUB_REF" != "refs/tags/$RELEASE_REF" ]]; then'
    assert_includes workflow, 'if [[ "$GITHUB_SHA" != "$RELEASE_SHA" ]]; then'
    assert_includes workflow, 'test "$(sw_vers -productVersion)" = "26.6.2"'
    assert_includes workflow, 'test "$(sw_vers -buildVersion)" = "25G83"'
    assert_includes workflow, 'test "$(xcodebuild -version | tail -1)" = "Build version 17F113"'
    assert_includes workflow, "-destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5'"
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
    with_config do |data, path|
      data["stable_runner"]["export"]["test_flight_internal_testing_only"] = true
      File.write(path, JSON.generate(data))
      assert_raises(ForzAdvisorRelease::ConfigurationError) { ForzAdvisorRelease::Config.new(path) }
    end
    with_config do |data, path|
      data["stable_runner"]["signing"]["mode"] = "unreviewed"
      File.write(path, JSON.generate(data))
      assert_raises(ForzAdvisorRelease::ConfigurationError) { ForzAdvisorRelease::Config.new(path) }
    end
    with_config do |data, path|
      data["stable_runner"]["signing"]["profile_name"] = "must remain private"
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
    assert_equal "89", result.dig("checks", "project", "evidence", "source_build_number")
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

    assert_equal "1.41.2", result["marketing_version"]
    assert_equal "89", result["source_build_number"]
    assert_equal "Manual", result["signing_style"]
    assert_equal %w[forzadvisorTests forzadvisorUITests], result["test_targets"]
    assert_equal ["forzadvisor.xcscheme", "forzadvisor Cloud.xcscheme"], result["schemes"]
  end

  def test_project_build_number_matches_the_proposed_release_build
    project = File.read(File.join(ROOT, "forzadvisor.xcodeproj", "project.pbxproj"))

    assert_equal 6, project.scan(/CURRENT_PROJECT_VERSION = #{@config.fetch("release", "source_build_number")};/).length
    refute_includes project, "CURRENT_PROJECT_VERSION = 87;"
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

  def test_release_declarations_require_price_rights_age_contact_and_approval_policy
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
    assert_includes workflow, 'if [[ "$GITHUB_REF" != "refs/tags/$RELEASE_REF" ]]; then'
    assert_includes workflow, 'if [[ "$GITHUB_SHA" != "$RELEASE_SHA" ]]; then'
    profile_test_index = workflow.index("python3 scripts/tests/test_ios_profile_verifier.py")
    clean_check_index = workflow.index("Require clean checkout after portable tests")
    status_after_tests_index = workflow.index("Checkout status after portable tests (runner HOME)")
    preflight_home_index = workflow.index('preflight_home="$(mktemp -d "$RUNNER_TEMP/forzadvisor-preflight-home.XXXXXX")"')
    isolated_home_status_index = workflow.index("Checkout status after temporary HOME setup (isolated HOME)")
    preflight_index = workflow.index('if ! HOME="$preflight_home" scripts/release preflight --ref "$RELEASE_REF"; then')
    refute_nil profile_test_index
    refute_nil clean_check_index
    refute_nil status_after_tests_index
    refute_nil preflight_home_index
    refute_nil isolated_home_status_index
    refute_nil preflight_index
    assert_operator profile_test_index, :<, clean_check_index
    assert_operator clean_check_index, :<, status_after_tests_index
    assert_operator status_after_tests_index, :<, preflight_home_index
    assert_operator preflight_home_index, :<, isolated_home_status_index
    assert_operator isolated_home_status_index, :<, preflight_index
    clean_check_end_index = workflow.index("      - name: Repository release preflight", clean_check_index)
    refute_nil clean_check_end_index
    clean_check_block = workflow[clean_check_index...clean_check_end_index]
    assert_includes clean_check_block, 'dirty_status="$(git status --porcelain --untracked-files=all)"'
    assert_includes clean_check_block, 'if [[ -n "$dirty_status" ]]; then'
    assert_includes clean_check_block, "exit 1"
    assert_includes clean_check_block, 'printf \'%s\\n\' "$dirty_status" >&2'
    assert_includes workflow, 'ln -s "$GITHUB_WORKSPACE" "$preflight_home/Agents/ForzAdvisor"'
    assert_includes workflow, 'git -C "$GITHUB_WORKSPACE" status --short --untracked-files=all'
    assert_includes workflow, 'HOME="$preflight_home" git -C "$GITHUB_WORKSPACE" status --short --untracked-files=all'
    assert_includes workflow, 'git status --porcelain --untracked-files=all'
    assert_includes workflow, 'Portable tests left the release checkout dirty:'
    assert_includes workflow, 'HOME="$preflight_home" scripts/release preflight --ref "$RELEASE_REF"'
    refute_includes workflow, 'ln -s "$GITHUB_WORKSPACE" "$HOME/Agents/ForzAdvisor"'
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
      api = FakeAPI.new(stable_upload_candidate_responses)
      coordinator = stable_coordinator(store: store, helper: helper, api: api, tag: tag, commit: commit)
      confirmation = coordinator.confirmation_token(commit)
      state = coordinator.start(ref: tag, verify_run_id: "42", upload: true, confirmation: confirmation)
      assert_equal "human_verification_pending", state["phase"]
      assert_equal candidate_build.fetch("id"), state["build_id"]
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
      api = FakeAPI.new(stable_upload_candidate_responses)
      coordinator = stable_coordinator(store: store, helper: helper, api: api, tag: tag, commit: commit)
      assert_raises(ForzAdvisorRelease::PreflightError) do
        coordinator.start(ref: tag, verify_run_id: "42", upload: true, confirmation: coordinator.confirmation_token(commit))
      end
      refute api.requests.any? { |request| request[0] == "POST" }
    end

    responses = stable_candidate_responses
    responses["/v1/apps/#{@config.fetch('app', 'id')}/builds"] = { "data" => [candidate_build, candidate_build.merge("id" => "other")] }
    responses["/v1/builds/other/preReleaseVersion"] = responses["/v1/builds/#{candidate_build.fetch("id")}/preReleaseVersion"]
    assert_raises(ForzAdvisorRelease::APIError) do
      ForzAdvisorRelease::UploadedBuildResolver.new(config: @config, api: FakeAPI.new(responses)).call(receipt: release_receipt(commit: commit))
    end

    group = @config.fetch("testflight", "internal_group", "id")
    external_group_responses = stable_candidate_responses
    external_group_responses["/v1/betaGroups/#{group}"]["data"]["attributes"]["isInternalGroup"] = false
    external_api = FakeAPI.new(external_group_responses)
    assert_raises(ForzAdvisorRelease::APIError) do
      ForzAdvisorRelease::TestFlightDistributor.new(config: @config, api: external_api).call(build_id: candidate_build.fetch("id"))
    end
    refute external_api.requests.any? { |request| request[0] == "POST" }
  end

  def test_candidate_start_rejects_existing_build_before_superseding_pending_candidate
    Dir.mktmpdir do |directory|
      store = ForzAdvisorRelease::StableStateStore.new(directory: directory)
      previous = store.save(stable_identity.merge(
        "schema_version" => 2,
        "ref" => "release-1.41.2-testflight-87-1",
        "commit" => "f" * 40,
        "source_build_number" => "87",
        "phase" => "human_verification_pending",
        "build_id" => "build-87",
        "release_receipt" => { "state" => "VALID", "build" => "87", "receipt_marker" => "preserve-exactly" }
      ))
      helper = FakeStableRunnerHelper.new(release_receipt(commit: "c" * 40))
      api = FakeAPI.new(stable_candidate_responses)
      coordinator = stable_coordinator(
        store: store,
        helper: helper,
        api: api,
        tag: @config.fetch("repository", "release_ref"),
        commit: "c" * 40
      )

      error = assert_raises(ForzAdvisorRelease::PreflightError) do
        coordinator.start(
          ref: @config.fetch("repository", "release_ref"),
          verify_run_id: "44",
          upload: true,
          confirmation: coordinator.confirmation_token("c" * 40)
        )
      end

      assert_match(/matching App Store Connect build already exists/, error.message)
      assert_equal previous, store.load
      assert_empty Dir.glob(File.join(directory, "history", "*.json"))
      assert_empty helper.calls
      refute api.requests.any? { |request| %w[POST PATCH].include?(request[0]) }
    end
  end

  def test_candidate_start_rejects_matching_build_on_a_later_app_store_page
    Dir.mktmpdir do |directory|
      store = ForzAdvisorRelease::StableStateStore.new(directory: directory)
      previous = store.save(stable_identity.merge(
        "schema_version" => 2,
        "ref" => "release-1.41.2-testflight-87-1",
        "commit" => "f" * 40,
        "source_build_number" => "87",
        "phase" => "human_verification_pending",
        "build_id" => "build-87",
        "release_receipt" => { "state" => "VALID", "build" => "87", "receipt_marker" => "preserve-exactly" }
      ))
      app = @config.fetch("app", "id")
      next_page = "https://api.appstoreconnect.apple.com/v1/apps/#{app}/builds?cursor=page-2"
      responses = stable_candidate_responses
      responses["/v1/apps/#{app}/builds"] = {
        "data" => Array.new(200) do |index|
          { "id" => "older-build-#{index}", "attributes" => { "version" => "87" } }
        end,
        "links" => { "next" => next_page }
      }
      responses[next_page] = { "data" => [candidate_build] }
      api = FakeAPI.new(responses)
      helper = FakeStableRunnerHelper.new(release_receipt(commit: "c" * 40))
      coordinator = stable_coordinator(
        store: store,
        helper: helper,
        api: api,
        tag: @config.fetch("repository", "release_ref"),
        commit: "c" * 40
      )

      error = assert_raises(ForzAdvisorRelease::PreflightError) do
        coordinator.start(
          ref: @config.fetch("repository", "release_ref"),
          verify_run_id: "46",
          upload: true,
          confirmation: coordinator.confirmation_token("c" * 40)
        )
      end

      assert_match(/matching App Store Connect build already exists/, error.message)
      assert_equal previous, store.load
      assert_empty Dir.glob(File.join(directory, "history", "*.json"))
      assert_empty helper.calls
      assert_includes api.requests, [next_page, {}]
      refute api.requests.any? { |request| %w[POST PATCH].include?(request[0]) }
    end
  end

  def test_candidate_block_rejects_while_upload_operation_is_active
    Dir.mktmpdir do |directory|
      store = ForzAdvisorRelease::StableStateStore.new(directory: directory)
      entered_upload = Queue.new
      finish_upload = Queue.new
      helper = Object.new
      helper.define_singleton_method(:upload) do |**_arguments|
        entered_upload << true
        finish_upload.pop
      end
      api = FakeAPI.new(stable_upload_candidate_responses)
      coordinator = stable_coordinator(
        store: store,
        helper: helper,
        api: api,
        tag: @config.fetch("repository", "release_ref"),
        commit: "c" * 40
      )
      upload_thread = Thread.new do
        coordinator.start(
          ref: @config.fetch("repository", "release_ref"),
          verify_run_id: "47",
          upload: true,
          confirmation: coordinator.confirmation_token("c" * 40)
        )
      end
      entered_upload.pop

      error = assert_raises(ForzAdvisorRelease::PreflightError) do
        coordinator.block_candidate(notes: "Transport outcome was ambiguous")
      end
      assert_match(/upload operation is still active/, error.message)
      assert_equal "upload_start_intent", store.load.fetch("phase")
      finish_upload << release_receipt(commit: "c" * 40)
      uploaded = upload_thread.value
      assert_equal "human_verification_pending", uploaded.fetch("phase")
      assert_equal "human_verification_pending", store.load.fetch("phase")
    end
  end

  def test_app_store_collection_rejects_incomplete_page_and_cross_origin_pagination
    app = @config.fetch("app", "id")
    path = "/v1/apps/#{app}/builds"
    missing_data = FakeAPI.new(path => {})
    assert_raises(ForzAdvisorRelease::APIError) do
      ForzAdvisorRelease::APICollection.fetch_all(api: missing_data, path: path, query: { "limit" => 200 })
    end

    credentials = Object.new
    credentials.define_singleton_method(:token) { "test-token" }
    transport = Object.new
    transport.define_singleton_method(:start) { |*| flunk("cross-origin pagination link must not receive the App Store Connect token") }
    client = ForzAdvisorRelease::APIClient.new(credentials: credentials, transport: transport)
    assert_raises(ForzAdvisorRelease::APIError) { client.get("https://attacker.example/v1/apps/#{app}/builds") }
  end

  def test_github_verified_resume_rejects_existing_build_before_upload_intent
    Dir.mktmpdir do |directory|
      store = ForzAdvisorRelease::StableStateStore.new(directory: directory)
      verified = store.save(stable_identity.merge(
        "schema_version" => 2,
        "phase" => "github_verified",
        "github_verification" => { "conclusion" => "success" }
      ))
      helper = FakeStableRunnerHelper.new(release_receipt)
      api = FakeAPI.new(stable_candidate_responses)
      coordinator = stable_coordinator(
        store: store,
        helper: helper,
        api: api,
        tag: stable_identity.fetch("ref"),
        commit: stable_identity.fetch("commit")
      )

      error = assert_raises(ForzAdvisorRelease::PreflightError) do
        coordinator.resume(
          upload: true,
          confirmation: coordinator.confirmation_token(stable_identity.fetch("commit"))
        )
      end

      assert_match(/matching App Store Connect build already exists/, error.message)
      assert_equal verified, store.load
      assert_empty helper.calls
      refute api.requests.any? { |request| %w[POST PATCH].include?(request[0]) }
    end
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
      coordinator = stable_coordinator(store: store, helper: helper, api: FakeAPI.new(stable_upload_candidate_responses), tag: stable_identity["ref"], commit: stable_identity["commit"])
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
      assert_includes ForzAdvisorRelease::Reporter.text(reconciled), "Build #{candidate_build.fetch("id")}: VALID"
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
      store.save(stable_identity.merge("schema_version" => 2, "source_build_number" => "79", "phase" => "human_blocked"))
      data = JSON.parse(File.read(CONFIG_PATH))
      data["release"]["source_build_number"] = "80"
      path = File.join(directory, "config.json")
      File.write(path, JSON.generate(data))
      config = ForzAdvisorRelease::Config.new(path)
      tag = "release-1.41.1-appstore-80"
      commit = "b" * 40
      github = ForzAdvisorRelease::GitHubVerificationEvidence.new(config: config, client: FakeGitHubClient.new(run: github_run(tag: tag, commit: commit), jobs: [github_job]))
      coordinator = ForzAdvisorRelease::StableRunnerCoordinator.new(config: config, git: FakeGitRepository.new(commit: commit), store: store, github_verification: github, helper: nil, api: nil)
      assert_raises(ForzAdvisorRelease::PreflightError) { coordinator.start(ref: tag, verify_run_id: "43", upload: false, confirmation: nil) }
      assert_equal "github_verified", store.load["phase"]
      assert_equal "80", store.load["source_build_number"]
      archives = Dir.glob(File.join(directory, "state", "history", "*.json"))
      assert_equal 1, archives.length
      assert_equal 0o600, File.stat(archives.first).mode & 0o777
      assert_raises(ForzAdvisorRelease::PreflightError) { coordinator.start(ref: tag, verify_run_id: "43", upload: false, confirmation: nil) }
      assert_equal 1, Dir.glob(File.join(directory, "state", "history", "*.json")).length
    end
  end

  def test_build_88_blocked_state_and_prior_receipt_are_archived_exactly_for_build_89
    Dir.mktmpdir do |directory|
      state_dir = File.join(directory, "state")
      store = ForzAdvisorRelease::StableStateStore.new(directory: state_dir)
      previous = stable_identity.merge(
        "ref" => "release-1.41.2-testflight-88-3",
        "commit" => "bcc3e6cf4ca77bf0c9c55c2a8143f09a4608a810",
        "source_build_number" => "88",
        "schema_version" => 2,
        "phase" => "human_blocked",
        "upload_intent_at" => "2026-10-08T21:27:56Z",
        "candidate_block" => { "kind" => "AMBIGUOUS_UPLOAD", "notes" => "exact build reconciled with no matching ASC candidate" },
        "superseded_pending_candidate" => {
          "transition" => "SUPERSEDED_PENDING",
          "previous_candidate" => {
            "phase" => "human_verification_pending",
            "source_build_number" => "87",
            "release_receipt" => { "state" => "VALID", "build" => "87", "receipt_marker" => "preserve-exactly" }
          }
        }
      )
      previous = store.save(previous)
      tag = @config.fetch("repository", "release_ref")
      commit = "d" * 40
      github = ForzAdvisorRelease::GitHubVerificationEvidence.new(config: @config, client: FakeGitHubClient.new(run: github_run(tag: tag, commit: commit), jobs: [github_job]))
      coordinator = ForzAdvisorRelease::StableRunnerCoordinator.new(config: @config, git: FakeGitRepository.new(commit: commit), store: store, github_verification: github, helper: nil, api: nil)

      assert_raises(ForzAdvisorRelease::PreflightError) do
        coordinator.start(ref: tag, verify_run_id: "89", upload: false, confirmation: nil)
      end

      archives = Dir.glob(File.join(state_dir, "history", "*.json"))
      assert_equal 1, archives.length
      assert_equal 0o600, File.stat(archives.first).mode & 0o777
      archived = JSON.parse(File.read(archives.first))
      assert_equal previous, archived
      assert_equal previous.dig("candidate_block"), archived.dig("candidate_block")
      assert_equal previous.dig("upload_intent_at"), archived.dig("upload_intent_at")
      assert_equal previous.dig("superseded_pending_candidate", "previous_candidate", "release_receipt"),
        archived.dig("superseded_pending_candidate", "previous_candidate", "release_receipt")
      refute archived.key?("release_receipt")
      before = File.binread(archives.first)
      assert_equal archives.first, store.archive(previous)
      assert_equal before, File.binread(archives.first)
      assert_equal 1, Dir.glob(File.join(state_dir, "history", "*.json")).length
      assert_equal "github_verified", store.load.fetch("phase")
      assert_equal "89", store.load.fetch("source_build_number")
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

  def test_pending_candidate_supersession_archives_build_87_before_build_89_without_inventing_human_result
    Dir.mktmpdir do |directory|
      store = ForzAdvisorRelease::StableStateStore.new(directory: File.join(directory, "state"))
      previous = stable_identity.merge(
        "config_fingerprint" => "e70cd2d84e94e491c5da2cc120d84b55f003f2cd0f194eb9907506a434150280",
        "ref" => "release-1.41.2-testflight-87-1",
        "commit" => "f3318c37dba4e745a31fda4e862468db75a11e16",
        "source_build_number" => "87",
        "schema_version" => 2,
        "phase" => "human_verification_pending",
        "build_id" => "54c5fe2d-bbd2-4287-83ac-40a76698e697",
        "release_receipt" => { "state" => "VALID", "build" => "87", "receipt_marker" => "preserve-exactly" }
      )
      previous = store.save(previous)
      candidate_commit = "c" * 40
      candidate_tag = @config.fetch("repository", "release_ref")
      helper = FakeStableRunnerHelper.new(release_receipt(commit: candidate_commit))
      api = FakeAPI.new(stable_upload_candidate_responses)
      github = stable_coordinator(store: store, helper: helper, api: api, tag: candidate_tag, commit: candidate_commit)
      active = github.start(
        ref: candidate_tag,
        verify_run_id: "43",
        upload: true,
        confirmation: github.confirmation_token(candidate_commit)
      )

      assert_equal 1, helper.calls.length
      assert_equal "build-89", active.fetch("build_id")
      assert_equal "human_verification_pending", active.fetch("phase")
      assert_equal 1, api.requests.count { |request| request[0] == "POST" }
      active = store.load
      assert_equal "human_verification_pending", active["phase"]
      assert_equal "89", active["source_build_number"]
      assert_equal candidate_commit, active["commit"]
      refute active.key?("human_verification")
      assert_equal candidate_commit, active.dig("release_receipt", "commit")
      supersession = active.fetch("superseded_pending_candidate")
      assert_equal "SUPERSEDED_PENDING", supersession.fetch("transition")
      assert_equal "human_verification_pending", supersession.dig("previous_candidate", "phase")
      assert_equal "87", supersession.dig("previous_candidate", "source_build_number")
      assert_equal "54c5fe2d-bbd2-4287-83ac-40a76698e697", supersession.dig("previous_candidate", "build_id")

      archives = Dir.glob(File.join(directory, "state", "history", "*.json"))
      assert_equal 1, archives.length
      assert_equal 0o600, File.stat(archives.first).mode & 0o777
      assert_equal Digest::SHA256.file(archives.first).hexdigest, supersession.fetch("archive_sha256")
      archived = JSON.parse(File.read(archives.first))
      assert_equal previous, archived
      assert_equal previous.fetch("release_receipt"), archived.fetch("release_receipt")
      assert_equal "human_verification_pending", archived.fetch("phase")
      refute archived.key?("human_verification")
    end
  end

  def test_pending_candidate_supersession_rejects_same_or_lower_build_without_archiving
    ["88", "89"].each do |previous_build|
      Dir.mktmpdir do |directory|
        store = ForzAdvisorRelease::StableStateStore.new(directory: directory)
        previous = store.save(stable_identity.merge(
          "schema_version" => 2,
          "ref" => "release-prior-build-#{previous_build}",
          "source_build_number" => previous_build,
          "phase" => "human_verification_pending",
          "release_receipt" => { "state" => "VALID", "build" => previous_build }
        ))
        coordinator = ForzAdvisorRelease::StableRunnerCoordinator.new(
          config: @config,
          git: FakeGitRepository.new(commit: "d" * 40),
          store: store,
          github_verification: ->(**) { flunk("GitHub evidence must not be read for a rejected rollover") },
          helper: nil,
          api: nil
        )

        assert_raises(ForzAdvisorRelease::PreflightError) do
          coordinator.start(ref: @config.fetch("repository", "release_ref"), verify_run_id: "44", upload: false, confirmation: nil)
        end
        assert_equal previous, store.load
        assert_empty Dir.glob(File.join(directory, "history", "*.json"))
      end
    end
  end

  def test_pending_candidate_supersession_requires_upload_confirmation_before_github_or_archive
    [
      { upload: false, confirmation: nil, message: /requires --upload/ },
      { upload: true, confirmation: "wrong", message: /does not match the exact release identity/ }
    ].each do |attempt|
      Dir.mktmpdir do |directory|
        store = ForzAdvisorRelease::StableStateStore.new(directory: directory)
        previous = store.save(stable_identity.merge(
          "schema_version" => 2,
          "ref" => "release-1.41.2-testflight-87-1",
          "commit" => "f" * 40,
          "source_build_number" => "87",
          "phase" => "human_verification_pending",
          "release_receipt" => { "state" => "VALID", "build" => "87" }
        ))
        coordinator = ForzAdvisorRelease::StableRunnerCoordinator.new(
          config: @config,
          git: FakeGitRepository.new(commit: "c" * 40),
          store: store,
          github_verification: ->(**) { flunk("GitHub evidence must not be read before upload authorization") },
          helper: nil,
          api: nil
        )

        error = assert_raises(ForzAdvisorRelease::PreflightError) do
          coordinator.start(
            ref: @config.fetch("repository", "release_ref"),
            verify_run_id: "45",
            upload: attempt.fetch(:upload),
            confirmation: attempt.fetch(:confirmation)
          )
        end
        assert_match(attempt.fetch(:message), error.message)
        assert_equal previous, store.load
        assert_empty Dir.glob(File.join(directory, "history", "*.json"))
      end
    end
  end

  def test_stable_state_transition_rejects_stale_compare_and_save
    Dir.mktmpdir do |directory|
      store = ForzAdvisorRelease::StableStateStore.new(directory: directory)
      original = store.save(stable_identity.merge("schema_version" => 2, "phase" => "human_verification_pending"))
      first = store.transition(expected_state: original) do |current, _archive_path|
        current.merge("phase" => "human_needs_fixes")
      end.fetch("state")

      assert_equal "human_needs_fixes", first.fetch("phase")
      error = assert_raises(ForzAdvisorRelease::PreflightError) do
        store.transition(expected_state: original) { |current, _archive_path| current.merge("phase" => "human_blocked") }
      end
      assert_match(/state changed/, error.message)
      assert_equal first, store.load
      assert_empty Dir.glob(File.join(directory, "history", "*.json"))
    end
  end

  def test_cli_active_state_mutations_use_locked_compare_and_save
    script = File.read(File.join(ROOT, "scripts", "release"))

    assert_includes script, 'store.transition(expected_state: active)'
    assert_includes script, 'store.transition(expected_state: state)'
    refute_match(/\bstore\.save\(/, script)
  end

  def test_human_result_records_accept_and_rejects_premature_or_unknown_results
    Dir.mktmpdir do |directory|
      store = ForzAdvisorRelease::StableStateStore.new(directory: directory)
      store.save(stable_identity.merge("schema_version" => 2, "phase" => "human_verification_pending", "build_id" => candidate_build.fetch("id")))
      coordinator = ForzAdvisorRelease::StableRunnerCoordinator.new(config: @config, git: nil, store: store, github_verification: nil, helper: nil, api: nil)
      state = coordinator.record_human_result(result: "ACCEPT", notes: "Matches expected results", evidence: "screenshot-1.png")
      assert_equal "human_accepted", state["phase"]
      assert_equal "ACCEPT", state.dig("human_verification", "result")
      assert_raises(ForzAdvisorRelease::PreflightError) { coordinator.record_human_result(result: "MAYBE", notes: "observed", evidence: "log") }
      store.save(stable_identity.merge("schema_version" => 2, "phase" => "candidate_ready"))
      assert_raises(ForzAdvisorRelease::PreflightError) { coordinator.record_human_result(result: "ACCEPT", notes: "observed", evidence: "log") }
    end
  end

  def test_human_result_compare_and_save_does_not_overwrite_a_concurrent_state_change
    Dir.mktmpdir do |directory|
      store = ForzAdvisorRelease::StableStateStore.new(directory: directory)
      store.save(stable_identity.merge(
        "schema_version" => 2,
        "phase" => "human_verification_pending",
        "build_id" => candidate_build.fetch("id")
      ))
      transition = store.method(:transition)
      concurrent_change_applied = false
      store.define_singleton_method(:transition) do |expected_state:, archive_expected: false, &mutation|
        unless concurrent_change_applied
          concurrent_change_applied = true
          transition.call(expected_state: expected_state) do |current, _archive_path|
            current.merge("phase" => "human_blocked", "candidate_block" => { "kind" => "concurrent-owner-action" })
          end
        end
        transition.call(expected_state: expected_state, archive_expected: archive_expected, &mutation)
      end
      coordinator = ForzAdvisorRelease::StableRunnerCoordinator.new(config: @config, git: nil, store: store, github_verification: nil, helper: nil, api: nil)

      error = assert_raises(ForzAdvisorRelease::PreflightError) do
        coordinator.record_human_result(result: "ACCEPT", notes: "Verified", evidence: "evidence-1")
      end

      assert_match(/state changed/, error.message)
      assert_equal "human_blocked", store.load.fetch("phase")
      assert_equal "concurrent-owner-action", store.load.dig("candidate_block", "kind")
      refute store.load.key?("human_verification")
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
      "wrong build" => proc { |responses| responses["/v1/builds/build"]["data"]["attributes"]["version"] = (@config.fetch("release", "source_build_number").to_i + 1).to_s },
      "wrong prerelease" => proc { |responses| responses["/v1/builds/build/preReleaseVersion"]["data"]["attributes"]["version"] = "1.41.1" },
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
      "/v1/apps/#{app_id}/builds" => { "data" => [{ "id" => "build-id", "attributes" => { "version" => @config.fetch("release", "current_app_store_build_number"), "processingState" => "VALID" } }] },
      "/v1/apps/#{app_id}/reviewSubmissions" => { "data" => [{ "id" => "submission-id", "attributes" => { "state" => "READY_FOR_REVIEW" } }] }
    }
    api = FakeAPI.new(responses)
    result = ForzAdvisorRelease::AppStoreStatus.new(config: @config, api: api).call

    assert_equal true, result["read_only"]
    assert_equal "89", result["source_build_number"]
    assert_equal @config.fetch("release", "current_app_store_build_number"), result.dig("build", "number")
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
    confirmation = "UPLOAD:IOS:#{@config.fetch('app', 'id')}:#{@config.fetch('app', 'bundle_id')}:1.41.1:#{@config.fetch('release', 'source_build_number')}:#{commit}"
    observed = helper.upload(commit: commit, app_id: @config.fetch("app", "id"), bundle_id: @config.fetch("app", "bundle_id"), version: "1.41.1", build: @config.fetch("release", "source_build_number"), confirmation: confirmation)
    assert_equal receipt, observed
    command = runner.calls.first.fetch(:command)
    assert_equal "/shared/ssh_runner_build.sh", command.first
    expected_build = @config.fetch("release", "source_build_number")
    %W[--platform iOS --archive --upload --expected-version 1.41.1 --expected-build #{expected_build} --confirm-upload].each do |argument|
      assert_includes command, argument
    end
    assert_includes command, confirmation
    assert_equal [ROOT, commit], command.last(2)

    missing = ForzAdvisorRelease::StableRunnerHelper.new(root: ROOT, runner: RecordingRunner.new("PASS only\n"), script: "/shared/helper")
    assert_raises(ForzAdvisorRelease::PreflightError) do
      missing.upload(commit: commit, app_id: "1", bundle_id: "example.app", version: "1.0.0", build: "1", confirmation: "token")
    end
  end

  def test_stable_runner_helper_defaults_to_the_versioned_repository_script
    commit = "a" * 40
    runner = RecordingRunner.new("RELEASE_RECEIPT #{JSON.generate(release_receipt(commit: commit))}\n")
    helper = ForzAdvisorRelease::StableRunnerHelper.new(root: ROOT, runner: runner)
    confirmation = "UPLOAD:IOS:#{@config.fetch('app', 'id')}:#{@config.fetch('app', 'bundle_id')}:1.41.2:89:#{commit}"
    helper.upload(commit: commit, app_id: @config.fetch("app", "id"), bundle_id: @config.fetch("app", "bundle_id"), version: "1.41.2", build: "89", confirmation: confirmation)
    assert_equal File.join(ROOT, "scripts", "stable-runner", "ssh_runner_build.sh"), runner.calls.first.fetch(:command).first
  end

  def test_versioned_runner_uses_private_manual_signing_metadata_and_verifies_archive_and_export
    helper = File.read(File.join(ROOT, "scripts", "stable-runner", "ssh_runner_build.sh"))
    assert_includes helper, "--validate-signing"
    assert_includes helper, "signing_metadata_path"
    assert_includes helper, "verify_ios_profile.py"
    assert_includes helper, "security find-identity -v -p codesigning"
    assert_includes helper, "codesign --display --extract-certificates"
    assert_includes helper, 'CODE_SIGN_IDENTITY="$signing_certificate_hash"'
    assert_includes helper, 'signingCertificate -string "$signing_certificate_hash"'
    refute_includes helper, "set-key-partition-list"
    refute_includes helper, 'unlock-keychain -p "$keychain_password"'
    assert_includes helper, "original_keychains_captured == 1"
    assert_includes helper, "XCODE_CODE_SIGNATURE_VERIFIED"
    assert_includes helper, 'PROVISIONING_PROFILE_SPECIFIER="$signing_profile_name"'
    assert_includes helper, "verify_manual_ios_component"
    assert_includes helper, "archive_sha256"
    assert_includes helper, "package_sha256"
    refute_match(/signing_profiles=.*committed_config/, helper)
    refute_match(/signing_certificate_id=.*committed_config/, helper)
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
      "archive_sha256" => "c" * 64,
      "package_sha256" => "b" * 64,
      "signing_verification" => "MANUAL_IOS_PROFILE_AND_SIGNER_VERIFIED",
      "asc_build_id" => candidate_build.fetch("id")
    }
  end

  def candidate_build
    {
      "id" => "build-#{@config.fetch("release", "source_build_number")}",
      "attributes" => {
        "version" => @config.fetch("release", "source_build_number"),
        "processingState" => "VALID",
        "buildAudienceType" => "APP_STORE_ELIGIBLE",
        "usesNonExemptEncryption" => false
      }
    }
  end

  def stable_upload_candidate_responses
    responses = stable_candidate_responses
    app = @config.fetch("app", "id")
    reads = 0
    responses["/v1/apps/#{app}/builds"] = proc do
      reads += 1
      { "data" => reads == 1 ? [] : [candidate_build] }
    end
    responses
  end

  def stable_candidate_responses
    app = @config.fetch("app", "id")
    group = @config.fetch("testflight", "internal_group", "id")
    group_reads = 0
    {
      "/v1/apps/#{app}/builds" => { "data" => [candidate_build] },
      "/v1/builds/#{candidate_build.fetch("id")}" => { "data" => candidate_build },
      "/v1/builds/#{candidate_build.fetch("id")}/app" => { "data" => { "id" => app } },
      "/v1/builds/#{candidate_build.fetch("id")}/preReleaseVersion" => { "data" => { "attributes" => { "version" => @config.fetch("release", "marketing_version"), "platform" => "IOS" } } },
      "/v1/betaGroups/#{group}" => { "data" => { "id" => group, "attributes" => { "name" => "Internal", "isInternalGroup" => true } } },
      "/v1/betaGroups/#{group}/app" => { "data" => { "id" => app } },
      "/v1/betaGroups/#{group}/builds" => proc { group_reads += 1; { "data" => group_reads == 1 ? [] : [{ "id" => candidate_build.fetch("id") }] } },
      ["POST", "/v1/betaGroups/#{group}/relationships/builds"] => {}
    }
  end

  def candidate_validation_responses(build_id)
    app = @config.fetch("app", "id")
    group = @config.fetch("testflight", "internal_group", "id")
    {
      "/v1/builds/#{build_id}" => { "data" => { "id" => build_id, "attributes" => { "version" => @config.fetch("release", "source_build_number"), "processingState" => "VALID", "buildAudienceType" => "APP_STORE_ELIGIBLE", "usesNonExemptEncryption" => false } } },
      "/v1/builds/#{build_id}/app" => { "data" => { "id" => app } },
      "/v1/builds/#{build_id}/preReleaseVersion" => { "data" => { "attributes" => { "version" => @config.fetch("release", "marketing_version"), "platform" => "IOS" } } },
      "/v1/betaGroups/#{group}" => { "data" => { "id" => group, "attributes" => { "name" => "Internal", "isInternalGroup" => true } } },
      "/v1/betaGroups/#{group}/app" => { "data" => { "id" => app } },
      "/v1/betaGroups/#{group}/builds" => { "data" => [{ "id" => build_id }] }
    }
  end

  def stable_coordinator(store:, helper:, api:, tag:, commit:)
    client = FakeGitHubClient.new(run: github_run(tag: tag, commit: commit), jobs: [github_job])
    ForzAdvisorRelease::StableRunnerCoordinator.new(
      config: @config,
      git: FakeGitRepository.new(commit: commit),
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
      "ref" => @config.fetch("repository", "release_ref"),
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
    version_attrs = { "platform" => "IOS", "versionString" => "1.41.2", "appStoreState" => "READY_FOR_REVIEW", "releaseType" => "AFTER_APPROVAL" }
    build_attrs = { "version" => @config.fetch("release", "source_build_number"), "processingState" => "VALID", "buildAudienceType" => "APP_STORE_ELIGIBLE", "usesNonExemptEncryption" => false }
    selected_attrs = build_attrs.merge("version" => @config.fetch("release", "current_app_store_build_number"))
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
