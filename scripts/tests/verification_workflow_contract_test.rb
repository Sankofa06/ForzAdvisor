# frozen_string_literal: true

require "minitest/autorun"
require "open3"
require "yaml"

class VerificationWorkflowContractTest < Minitest::Test
  ROOT = File.expand_path("../..", __dir__)
  WORKFLOW_PATH = File.join(ROOT, ".github", "workflows", "verification-ci.yml")
  RESPONSIVE_WORKFLOW_PATH = File.join(ROOT, ".github", "workflows", "landing-page-responsive-audit.yml")
  RELEASE_WORKFLOW_PATH = File.join(ROOT, ".github", "workflows", "release-verify.yml")

  def setup
    @workflow = YAML.safe_load(File.read(WORKFLOW_PATH), aliases: false)
    @events = @workflow.fetch("on") { @workflow.fetch(true) }
    @jobs = @workflow.fetch("jobs")
    @responsive_workflow = YAML.safe_load(File.read(RESPONSIVE_WORKFLOW_PATH), aliases: false)
    @release_workflow = YAML.safe_load(File.read(RELEASE_WORKFLOW_PATH), aliases: false)
  end

  def test_responsive_workflow_covers_inputs_runs_exact_tree_audit_and_retains_results
    events = @responsive_workflow.fetch("on") { @responsive_workflow.fetch(true) }
    paths = events.fetch("pull_request").fetch("paths")

    assert_includes paths, "landing-page/**"
    assert_includes paths, "scripts/tests/landing-page-responsive-audit.html"
    assert_includes paths, "scripts/tests/run_landing_page_responsive_audit.py"
    assert_includes paths, "scripts/tests/verification_workflow_contract_test.rb"
    assert_includes paths, ".github/workflows/landing-page-responsive-audit.yml"

    job = @responsive_workflow.fetch("jobs").fetch("audit")
    assert_equal "ubuntu-24.04", job.fetch("runs-on")
    steps = job.fetch("steps")
    checkout = steps.find { |step| step["uses"].to_s.start_with?("actions/checkout@") }
    assert_equal "${{ github.event.pull_request.head.sha || github.sha }}",
                 checkout.fetch("with").fetch("ref")

    audit = steps.find { |step| step["name"] == "Run browser-backed responsive audit" }
    refute_nil audit
    assert_includes audit.fetch("run"), "scripts/tests/run_landing_page_responsive_audit.py"
    assert_includes audit.fetch("run"), "git rev-parse HEAD"
    assert_includes audit.fetch("run"), "git rev-parse HEAD^{tree}"
    refute_includes job.fetch("steps").map { |step| step["run"].to_s }.join("\n"), "xcodebuild"

    upload = steps.find { |step| step["name"] == "Retain machine-readable viewport results" }
    refute_nil upload
    assert_equal "always()", upload.fetch("if")
    assert_equal "actions/upload-artifact@043fb46d1a93c77aae656e7c1c64a875d1fc6a0a",
                 upload.fetch("uses").split(" ").first
    assert_includes upload.fetch("with").fetch("path"), "landing-page-responsive-audit.json"
    assert_match(/landing-page-responsive-audit-.*github\.run_attempt/, upload.fetch("with").fetch("name"))
  end

  def test_responsive_audit_measures_and_retains_headline_geometry
    fixture = File.read(File.join(ROOT, "scripts", "tests", "landing-page-responsive-audit.html"))
    runner = File.read(File.join(ROOT, "scripts", "tests", "run_landing_page_responsive_audit.py"))

    assert_includes fixture, "expectedHeadlineLines = 3"
    assert_includes fixture, "geometryTolerance = 0.5"
    assert_includes fixture, "doc.querySelector('.hero-copy h1')"
    assert_includes fixture, "headlineLineBounds"
    assert_includes fixture, "headlineOverflowX"
    assert_includes fixture, "headlineOverflowY"
    assert_includes fixture, "headlineClipBounds"
    assert_includes fixture, "headlineAncestorCount"
    assert_includes fixture, "headlineLineCount"
    assert_includes fixture, "headlineWithinHeroCopy"
    assert_includes fixture, "headlineWithinViewport"
    assert_includes fixture, "headlineClipAncestors"
    assert_includes fixture, "headlineClipped"
    assert_includes fixture, "headlineTextOutgrowsElement"
    assert_includes fixture, "headlineFits"
    assert_includes fixture, "pageWidth > viewportWidth"
    assert_includes runner, "EXPECTED_HEADLINE_LINES = 3"
    assert_includes runner, "EXPECTED_HEADLINE_ANCESTORS"
    assert_includes runner, "GEOMETRY_TOLERANCE = 0.5"
    assert_includes runner, "headlineLineBounds"
    assert_includes runner, "headlineLineCount"
    assert_includes runner, "headlineClipAncestors"
    assert_includes runner, "headlineAncestorCount"
    assert_includes runner, "rects_overlap(input_bounds, output_bounds)"
    assert_includes runner, "rect_exceeds_axis"
    assert_includes runner, "headlineClipped"
    refute_includes runner, "headline text is clipped by its own bounds."
    assert_includes runner, "headlineFits"
  end

  def test_headline_validator_checks_measured_geometry_and_preserves_visible_overdraw
    runner_path = File.join(ROOT, "scripts", "tests", "run_landing_page_responsive_audit.py")
    python = <<~PYTHON
      from copy import deepcopy
      import runpy
      import sys

      validate = runpy.run_path(sys.argv[1])["validate_audit"]
      revision = "a" * 40
      tree = "b" * 40
      widths = [320, 390, 768, 1440]
      line_bounds = [
          {"left": 8, "top": top, "right": 180, "bottom": top + 30}
          for top in (12, 52, 92)
      ]
      viewports = []
      for width in widths:
          clip_bounds = {"left": 8, "top": 8, "right": width - 8, "bottom": 132}
          hero_copy_bounds = {"left": 8, "top": 0, "right": width - 8, "bottom": 180}
          outer_bounds = {"left": 0, "top": 0, "right": width, "bottom": 1200}
          ancestors = [
              {"element": "h1", "overflowX": "visible", "overflowY": "visible",
               "axes": [], "bounds": deepcopy(clip_bounds)},
              {"element": "div.hero-copy", "overflowX": "visible", "overflowY": "visible",
               "axes": [], "bounds": deepcopy(hero_copy_bounds)},
              {"element": "section.hero.shell", "overflowX": "visible", "overflowY": "visible",
               "axes": [], "bounds": deepcopy(outer_bounds)},
              {"element": "main#main", "overflowX": "visible", "overflowY": "visible",
               "axes": [], "bounds": deepcopy(outer_bounds)},
              {"element": "body", "overflowX": "visible", "overflowY": "visible",
               "axes": [], "bounds": deepcopy(outer_bounds)},
              {"element": "html", "overflowX": "visible", "overflowY": "visible",
               "axes": [], "bounds": deepcopy(outer_bounds)},
          ]
          viewports.append({
              "viewportWidth": width,
              "viewportHeight": 400,
              "documentWidth": width,
              "horizontalOverflow": False,
              "input": {"left": 24, "top": 48, "right": 84, "bottom": 88},
              "output": {"left": width - 84, "top": 48, "right": width - 24, "bottom": 88},
              "calloutsOverlap": False,
              "heroCopyBounds": hero_copy_bounds,
              "headlineBounds": deepcopy(clip_bounds),
              "headlineClipBounds": deepcopy(clip_bounds),
              "headlineOverflowX": "visible",
              "headlineOverflowY": "visible",
              "headlineLineBounds": deepcopy(line_bounds),
              "headlineWithinHeroCopy": True,
              "headlineWithinViewport": True,
              "headlineAncestorCount": len(ancestors),
              "headlineClipAncestors": ancestors,
              "headlineClipped": False,
              "headlineTextOutgrowsElement": False,
              "headlineLineCount": 3,
              "headlineScrollWidth": width - 16,
              "headlineClientWidth": width - 16,
              "headlineScrollHeight": 124,
              "headlineClientHeight": 124,
              "headlineFits": True,
          })
      report = {
          "result": "PASS",
          "sourceRevision": revision,
          "sourceTree": tree,
          "errors": [],
          "viewports": viewports,
      }
      assert validate("PASS", report, revision, tree) == []

      visible_overdraw = deepcopy(report)
      visible_sample = visible_overdraw["viewports"][0]
      visible_sample["headlineLineBounds"][0]["top"] = 4
      visible_sample["headlineLineBounds"][2]["bottom"] = 136
      visible_sample["headlineScrollHeight"] = 140
      visible_sample["headlineTextOutgrowsElement"] = True
      assert validate("PASS", visible_overdraw, revision, tree) == []

      visible_horizontal_overdraw = deepcopy(report)
      horizontal_sample = visible_horizontal_overdraw["viewports"][0]
      horizontal_sample["headlineBounds"]["right"] = 170
      horizontal_sample["headlineClipBounds"]["right"] = 170
      horizontal_sample["headlineClipAncestors"][0]["bounds"]["right"] = 170
      horizontal_sample["headlineScrollWidth"] = 172
      horizontal_sample["headlineClientWidth"] = 162
      horizontal_sample["headlineTextOutgrowsElement"] = True
      assert validate("PASS", visible_horizontal_overdraw, revision, tree) == []

      tolerance_boundary_escape = deepcopy(report)
      tolerance_sample = tolerance_boundary_escape["viewports"][0]
      tolerance_sample["headlineLineBounds"][0]["left"] = 7.5
      assert validate("PASS", tolerance_boundary_escape, revision, tree) == []

      over_tolerance_escape = deepcopy(report)
      over_tolerance_sample = over_tolerance_escape["viewports"][0]
      over_tolerance_sample["headlineLineBounds"][0]["left"] = 7.4999
      over_tolerance_sample["headlineTextOutgrowsElement"] = True
      assert any("headline line escapes .hero-copy" in error
                 for error in validate("PASS", over_tolerance_escape, revision, tree))

      empty_line = deepcopy(report)
      empty_line["viewports"][0]["headlineLineBounds"][0]["right"] = 8
      assert any("headline line geometry is invalid or empty" in error
                 for error in validate("PASS", empty_line, revision, tree))

      wrapped = deepcopy(report)
      wrapped_sample = wrapped["viewports"][0]
      wrapped_sample["headlineLineCount"] = 4
      wrapped_sample["headlineLineBounds"].append(
          {"left": 8, "top": 132, "right": 180, "bottom": 162}
      )
      assert any("320px headline wraps to 4 lines" in error
                 for error in validate("PASS", wrapped, revision, tree))

      clipped = deepcopy(report)
      clipped_sample = clipped["viewports"][1]
      section_clip = clipped_sample["headlineClipAncestors"][2]
      section_clip["overflowY"] = "hidden"
      section_clip["axes"] = ["y"]
      section_clip["bounds"]["bottom"] = 120
      clipped_sample["headlineLineBounds"][2]["bottom"] = 122
      clipped_sample["headlineClipped"] = True
      clipped_sample["headlineFits"] = False
      assert any("390px headline text is clipped by a CSS overflow ancestor" in error
                 for error in validate("PASS", clipped, revision, tree))

      horizontal_clip = deepcopy(report)
      horizontal_sample = horizontal_clip["viewports"][2]
      section_clip = horizontal_sample["headlineClipAncestors"][2]
      section_clip["overflowX"] = "hidden"
      section_clip["axes"] = ["x"]
      section_clip["bounds"]["right"] = 759
      horizontal_sample["headlineLineBounds"][0]["right"] = 760
      horizontal_sample["headlineClipped"] = True
      horizontal_sample["headlineFits"] = False
      assert any("768px headline text is clipped by a CSS overflow ancestor" in error
                 for error in validate("PASS", horizontal_clip, revision, tree))

      omitted_clip = deepcopy(report)
      omitted_sample = omitted_clip["viewports"][0]
      section_clip = omitted_sample["headlineClipAncestors"][2]
      section_clip["overflowY"] = "hidden"
      section_clip["axes"] = ["y"]
      section_clip["bounds"]["bottom"] = 120
      omitted_sample["headlineLineBounds"][2]["bottom"] = 122
      omitted_sample["headlineClipAncestors"] = [omitted_sample["headlineClipAncestors"][0]]
      omitted_sample["headlineAncestorCount"] = 1
      omitted_sample["headlineClipped"] = False
      assert any("overflow-ancestor path is incomplete" in error
                 for error in validate("PASS", omitted_clip, revision, tree))

      contradictory_clip = deepcopy(report)
      contradictory_sample = contradictory_clip["viewports"][2]
      section_clip = contradictory_sample["headlineClipAncestors"][2]
      section_clip["overflowY"] = "hidden"
      section_clip["bounds"]["bottom"] = 120
      contradictory_sample["headlineLineBounds"][2]["bottom"] = 122
      contradictory_sample["headlineClipped"] = False
      assert any("overflow styles contradict" in error or
                 "clipping axes contradict" in error or
                 "clipping result contradicts" in error
                 for error in validate("PASS", contradictory_clip, revision, tree))

      hero_escape = deepcopy(report)
      hero_sample = hero_escape["viewports"][2]
      hero_sample["headlineLineBounds"][0]["left"] = 7
      assert any("headline line escapes .hero-copy" in error
                 for error in validate("PASS", hero_escape, revision, tree))

      viewport_escape = deepcopy(report)
      viewport_sample = viewport_escape["viewports"][3]
      viewport_sample["heroCopyBounds"]["right"] = 1442
      viewport_sample["headlineLineBounds"][0]["right"] = 1441
      viewport_sample["headlineTextOutgrowsElement"] = True
      assert any("headline line escapes the viewport" in error
                 for error in validate("PASS", viewport_escape, revision, tree))

      overflow = deepcopy(report)
      overflow["viewports"][0]["documentWidth"] = 321
      assert any("320px viewport has horizontal overflow" in error
                 for error in validate("PASS", overflow, revision, tree))

      overlap = deepcopy(report)
      overlap_sample = overlap["viewports"][1]
      overlap_sample["input"] = {"left": 24, "top": 48, "right": 100, "bottom": 90}
      overlap_sample["output"] = {"left": 80, "top": 60, "right": 140, "bottom": 100}
      assert any("callout-overlap flag contradicts measured rectangles" in error
                 for error in validate("PASS", overlap, revision, tree))
    PYTHON
    stdout, stderr, status = Open3.capture3("python3", "-c", python, runner_path)

    assert status.success?, "Synthetic headline validator cases failed.\n#{stdout}\n#{stderr}"
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
