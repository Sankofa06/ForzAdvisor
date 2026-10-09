# frozen_string_literal: true

require "minitest/autorun"
require "yaml"

class VerificationWorkflowContractTest < Minitest::Test
  ROOT = File.expand_path("../..", __dir__)
  WORKFLOW_PATH = File.join(ROOT, ".github", "workflows", "verification-ci.yml")
  RELEASE_WORKFLOW_PATH = File.join(ROOT, ".github", "workflows", "release-verify.yml")

  def setup
    @workflow = YAML.safe_load(File.read(WORKFLOW_PATH), aliases: false)
    @events = @workflow.fetch("on") { @workflow.fetch(true) }
    @jobs = @workflow.fetch("jobs")
    @release_workflow = YAML.safe_load(File.read(RELEASE_WORKFLOW_PATH), aliases: false)
  end

  def test_only_pr_static_and_manual_verification_triggers_exist
    assert_equal %w[pull_request workflow_dispatch].sort, @events.keys.map(&:to_s).sort
    assert_equal ["main"], @events.fetch("pull_request").fetch("branches")
    assert_equal %w[build-unit smoke full-regression],
                 @events.fetch("workflow_dispatch").fetch("inputs").fetch("lane").fetch("options")
  end

  def test_workflow_has_only_read_only_repository_permission
    assert_equal({ "contents" => "read" }, @workflow.fetch("permissions"))
  end

  def test_pull_request_lane_is_portable_and_does_not_build_the_app
    job = @jobs.fetch("static")

    assert_equal "ubuntu-latest", job.fetch("runs-on")
    assert_equal "github.event_name == 'pull_request'", job.fetch("if")
    steps = job.fetch("steps")
    checkout_index = steps.index { |step| step["name"] == "Check out source" }
    framework_index = steps.index { |step| step["run"].to_s.include?("bash scripts/validate-agent-framework.sh") }
    contract_index = steps.index { |step| step["run"].to_s.include?("ruby scripts/tests/verification_workflow_contract_test.rb") }
    refute_nil checkout_index
    refute_nil framework_index
    refute_nil contract_index
    assert_operator checkout_index, :<, framework_index
    assert_operator framework_index, :<, contract_index
    commands = steps.map { |step| step["run"].to_s }.join("\n")
    assert_includes commands, "bash scripts/validate-agent-framework.sh"
    assert_includes commands, "ruby scripts/tests/verification_workflow_contract_test.rb"
    refute_includes commands, "xcodebuild"
  end

  def test_manual_build_unit_lane_uses_documented_project_and_test_target
    job = @jobs.fetch("build-unit")
    commands = job.fetch("steps").map { |step| step["run"].to_s }.join("\n")

    assert_equal "macos-26", job.fetch("runs-on")
    assert_equal "github.event_name == 'workflow_dispatch' && inputs.lane == 'build-unit'", job.fetch("if")
    assert_includes commands, "-project forzadvisor.xcodeproj"
    assert_includes commands, "-scheme forzadvisor"
    assert_includes commands, "CODE_SIGNING_ALLOWED=NO build"
    assert_includes commands, "-only-testing:forzadvisorTests"
  end

  def test_manual_smoke_lane_selects_only_the_ui_test_target
    job = @jobs.fetch("smoke")
    commands = job.fetch("steps").map { |step| step["run"].to_s }.join("\n")

    assert_equal "github.event_name == 'workflow_dispatch' && inputs.lane == 'smoke'", job.fetch("if")
    assert_includes commands, "-only-testing:forzadvisorUITests"
    assert_includes commands, "-testPlan ReleaseVerify"
  end

  def test_manual_full_regression_runs_the_complete_releaseverify_plan
    job = @jobs.fetch("full-regression")
    commands = job.fetch("steps").map { |step| step["run"].to_s }.join("\n")

    assert_equal "github.event_name == 'workflow_dispatch' && inputs.lane == 'full-regression'", job.fetch("if")
    assert_includes commands, "-testPlan ReleaseVerify"
    assert_includes commands, "-resultBundlePath"
    assert_includes commands, "xcrun xcresulttool get test-results summary"
    assert_includes commands, ".skippedTests == 0"
    assert_includes commands, ".expectedFailures == 0"
    refute_includes commands, "-only-testing:"
    assert_includes commands, "SWIFT_TREAT_WARNINGS_AS_ERRORS=YES"
  end

  def test_verification_ci_manual_native_lanes_pin_ios_26_4_1_destinations
    commands = %w[build-unit smoke full-regression].flat_map do |name|
      @jobs.fetch(name).fetch("steps").map { |step| step["run"].to_s }
    end.join("\n")

    assert_equal 4, commands.scan(/-destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26\.4\.1'/).length
    refute_match(/OS=26\.5/, commands)
  end

  def test_release_verify_uses_supported_ios_26_5_simulator_and_full_passing_gate
    job = @release_workflow.fetch("jobs").fetch("verify")
    commands = job.fetch("steps").map { |step| step["run"].to_s }.join("\n")

    assert_equal "macos-26", job.fetch("runs-on")
    assert_equal "/Applications/Xcode_26.6.app/Contents/Developer", job.fetch("env").fetch("DEVELOPER_DIR")
    assert_includes commands, 'test "$(sw_vers -productVersion)" = "26.6.2"'
    assert_includes commands, 'test "$(sw_vers -buildVersion)" = "25G83"'
    assert_includes commands, 'test "$(xcodebuild -version | tail -1)" = "Build version 17F113"'
    assert_includes commands, "-testPlan ReleaseVerify"
    assert_includes commands, 'if [[ "$GITHUB_REF" != "refs/tags/$RELEASE_REF" ]]; then'
    assert_includes commands, 'if [[ "$GITHUB_SHA" != "$RELEASE_SHA" ]]; then'
    assert_includes commands, "-destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5'"
    assert_includes commands, "SWIFT_TREAT_WARNINGS_AS_ERRORS=YES"
    assert_includes commands, "GCC_TREAT_WARNINGS_AS_ERRORS=YES"
    assert_includes commands, "xcrun xcresulttool get test-results summary"
    assert_includes commands, ".totalTestCount > 0"
    assert_includes commands, ".failedTests == 0"
    assert_includes commands, ".skippedTests == 0"
    assert_includes commands, ".expectedFailures == 0"
    refute_includes commands, "-only-testing:"
  end

  def test_checkout_does_not_persist_credentials_and_workflow_has_no_secrets_or_release_steps
    checkout_steps = @jobs.values.flat_map { |job| job.fetch("steps") }
                           .select { |step| step["uses"].to_s.start_with?("actions/checkout@") }

    refute_empty checkout_steps
    checkout_steps.each do |step|
      assert_equal false, step.fetch("with").fetch("persist-credentials")
    end

    source = File.read(WORKFLOW_PATH)
    refute_match(/secrets\./i, source)
    refute_match(/exportArchive|uploadArchive|deploy-pages/i, source)
  end
end
