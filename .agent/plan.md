# Implementation Plan

## Iteration 10 - Generation And Adjustment Stale Completion Guards

### Chosen Slice

Complete the async stale-completion guard work for tune generation and guided adjustment.

### Included Tasks

1. Use a focused subagent to review the smallest generation/adjustment guard paths.
2. Add generation operation identity and task cancellation for partial, success, and error paths.
3. Add adjustment operation identity and task cancellation for success and error paths.
4. Avoid capturing `SavedTune` across provider awaits; re-fetch by ID before mutating SwiftData.
5. Scope the active feedback spinner to the saved tune currently being adjusted.

### Files Likely To Change

- `forzadvisor/ContentView.swift`
- `forzadvisor/ContentView+Workflow.swift`
- `.agent/implementation-log.md`
- `.agent/verification.md`
- `.agent/test-report.md`
- `.agent/memory.md`
- `.agent/next-actions.md`

### Verification Criteria

- App build passes on iPhone 17.
- Unit tests pass on iPhone 17.
- Diff remains scoped to async workflow reliability plus `.agent` memory.
- UI runner blocker remains recorded if still unresolved.

---

## Iteration 9 - OCR Cancellation And Provider Cancellation Reliability

### Chosen Slice

Reduce stale async completion risk without a broad workflow rewrite.

### Included Tasks

1. Retry UI validation on a booted concrete iPhone 17 simulator and record the result.
2. Prevent canceled remote/on-device provider requests from being converted into successful offline fallback tunes.
3. Add cancellation checks around Vision OCR parsing.
4. Track photo/OCR import with a task handle and operation ID so cancel, manual entry, retry, or view exit can ignore stale completions.
5. Add focused tests proving provider cancellation is rethrown instead of falling back.

### Files Likely To Change

- `forzadvisor/Services/CompositeTuneProvider.swift`
- `forzadvisor/Services/OCRService.swift`
- `forzadvisor/Views/NewTuneStartView.swift`
- `forzadvisorTests/OnDeviceTuneProviderTests.swift`
- `.agent/implementation-log.md`
- `.agent/verification.md`
- `.agent/test-report.md`
- `.agent/memory.md`
- `.agent/next-actions.md`

### Verification Criteria

- App build passes on iPhone 17.
- Unit tests pass, including provider cancellation tests.
- UI validation status is recorded honestly.
- Diff remains scoped to cancellation/fallback reliability plus `.agent` memory.

---

## Iteration 8 - Validation Checkpoint And Factory Audit Intake

### Chosen Slice

Resolve the stale validation blocker, rerun the available Xcode gates, and fold fresh subagent audit findings into the next-loop backlog.

### Included Tasks

1. Recheck Xcode scheme, simulator runtimes, and destinations.
2. Run a clean app build on iPhone 17.
3. Run unit tests separately from the UI smoke test to isolate app/test failures from simulator runner failures.
4. Use subagents for product, reliability, and code-health audits, then record the next highest-value slices.

### Files Likely To Change

- `.agent/plan.md`
- `.agent/implementation-log.md`
- `.agent/verification.md`
- `.agent/test-report.md`
- `.agent/memory.md`
- `.agent/findings.md`
- `.agent/product-audit.md`
- `.agent/reliability-audit.md`
- `.agent/code-health.md`
- `.agent/release-readiness.md`
- `.agent/next-actions.md`

### Verification Criteria

- `xcodebuild -list -project forzadvisor.xcodeproj` succeeds.
- `xcodebuild -showdestinations -project forzadvisor.xcodeproj -scheme forzadvisor` shows an eligible iPhone 17 simulator.
- `xcodebuild -project forzadvisor.xcodeproj -scheme forzadvisor -destination 'platform=iOS Simulator,name=iPhone 17' build` succeeds with zero app compile errors.
- `xcodebuild -project forzadvisor.xcodeproj -scheme forzadvisor -destination 'platform=iOS Simulator,name=iPhone 17' test -only-testing:forzadvisorTests` succeeds.
- Full scheme/UI test status is recorded honestly.

---

## Iteration 7 - Stale Comment Cleanup

### Chosen Slice

Remove outdated MVP/manual-only/provider comments that no longer match the app.

### Included Tasks

1. Update test header wording in `TuningDomainTests`.
2. Update discipline picker header wording to avoid implying only the local provider generates tunes.
3. Update tune provider header wording to reflect current offline/API/on-device provider architecture.

### Files Likely To Change

- `forzadvisorTests/TuningDomainTests.swift`
- `forzadvisor/Views/DisciplinePickerView.swift`
- `forzadvisor/Services/TuneProvider.swift`
- `.agent/implementation-log.md`
- `.agent/verification.md`
- `.agent/memory.md`

### Verification Criteria

- Static inspection confirms comment-only source changes.
- Final audit confirms seven iterations are recorded.

---

## Iteration 6 - API Key Clear Action Ergonomics

### Chosen Slice

Reduce Settings confusion by disabling the destructive clear action when there is nothing to clear.

### Included Tasks

1. Disable "Clear Key" when no key is saved and the field is empty.
2. Keep existing Keychain save/delete behavior unchanged.

### Files Likely To Change

- `forzadvisor/Views/SettingsView.swift`
- `.agent/implementation-log.md`
- `.agent/verification.md`
- `.agent/memory.md`

### Verification Criteria

- Static inspection confirms button enablement follows saved-key or typed-key state.
- Build/test remains blocked until Xcode platform/runtime mismatch is fixed.

---

## Iteration 5 - OCR Privacy Copy Polish

### Chosen Slice

Make screenshot/photo OCR privacy clearer during processing.

### Included Tasks

1. Update the photo-processing progress text to say the image is being read on device.
2. Avoid changing OCR behavior, permissions, or storage.

### Files Likely To Change

- `forzadvisor/Views/NewTuneStartView.swift`
- `.agent/implementation-log.md`
- `.agent/verification.md`
- `.agent/memory.md`

### Verification Criteria

- Static inspection confirms only copy changed.
- Build/test remains blocked until Xcode platform/runtime mismatch is fixed.

---

## Iteration 4 - Saved Retune Threshold Boundary Coverage

### Chosen Slice

Pin the PRD's "more than 2%" saved-tune retune threshold with focused tests.

### Included Tasks

1. Add boundary assertions for exactly 2% weight change and just over 2% weight change.
2. Add boundary assertions for exactly 2.0 front-weight-point change and just over 2.0.
3. Keep saved-tune behavior unchanged unless the test exposes a mismatch.

### Files Likely To Change

- `forzadvisorTests/TuningDomainTests.swift`
- `.agent/implementation-log.md`
- `.agent/verification.md`
- `.agent/memory.md`

### Verification Criteria

- Static inspection confirms the test checks both weight and front-distribution boundaries.
- Full execution remains blocked until Xcode platform/runtime mismatch is fixed.

---

## Iteration 3 - On-Device Adjustment Fallback Coverage

### Chosen Slice

Strengthen test coverage for on-device provider fallback during guided refinement.

### Included Tasks

1. Add a focused test proving on-device adjustment falls back to local formulas when the model is unavailable.
2. Reuse the existing unavailable on-device test double.
3. Keep production behavior unchanged.

### Files Likely To Change

- `forzadvisorTests/OnDeviceTuneProviderTests.swift`
- `.agent/implementation-log.md`
- `.agent/verification.md`
- `.agent/test-report.md`
- `.agent/memory.md`

### Verification Criteria

- Static inspection confirms the test uses `.onDeviceFoundationModel` and asserts a real adjustment diff.
- Build/test remains blocked until Xcode platform/runtime mismatch is fixed.

---

## Iteration 2 - Provider Status Transparency

### Chosen Slice

Make provider fallback state clearer in Settings without changing provider routing.

### Included Tasks

1. Add a concise provider status row in `SettingsView`.
2. Show when API mode is ready because a key is saved, or when it will fall back because no key is saved.
3. Keep on-device availability status visible and reuse the existing availability facade.

### Files Likely To Change

- `forzadvisor/Views/SettingsView.swift`
- `.agent/implementation-log.md`
- `.agent/verification.md`
- `.agent/test-report.md`
- `.agent/memory.md`

### Risks

- Avoid reading Keychain repeatedly in the SwiftUI body.
- Keep copy compact so Settings remains scannable.

### Verification Criteria

- Static inspection confirms provider status updates after save/clear.
- Xcode build/test attempted if local SDK/runtime mismatch is resolved; otherwise blocker recorded.

### Expected User-Visible Result

Settings tells the player whether the selected provider is ready or will use offline formulas.

---

## Iteration 1 - First-Run Clarity And Adjustment Fallback Coverage

## Chosen Slice

First-run clarity and adjustment fallback coverage.

## Included Tasks

1. Update `GarageHomeView` empty-state copy so first-run users see the current photo/screenshot/manual workflow.
2. Update stale `ManualEntryView` header comments to match current product state.
3. Add a `TuneAPIModelTests` test proving API-mode adjustment falls back to local formulas when no API key is configured.

## Files Likely To Change

- `forzadvisor/Views/GarageHomeView.swift`
- `forzadvisor/Views/ManualEntryView.swift`
- `forzadvisorTests/TuneAPIModelTests.swift`
- `.agent/implementation-log.md`
- `.agent/verification.md`
- `.agent/test-report.md`
- `.agent/memory.md`

## Reusable Components

- `CompositeTuneProvider`
- `LocalSampleTuneProvider`
- existing `KeychainStore(service:)` test isolation pattern

## Risks

- Xcode CLI and Apple git are blocked by unaccepted Xcode license agreements, so validation and commit may be blocked.
- Test additions cannot be confirmed until Xcode license is accepted.

## Rollback Notes

Revert the three source/test edits if the copy or coverage direction is unwanted. No model, persistence, signing, or project-file changes are planned.

## Verification Criteria

- Diff stays within selected files and `.agent` memory.
- `xcodebuild -list`/build/test attempted.
- If blocked, blocker is recorded with the exact reason.

## Expected User-Visible Result

New users see an empty garage prompt that matches the actual app workflow instead of implying manual entry is the only way to start.

---

## Iteration 15 - Tune Workflow Race Controller

### Chosen Slice

Add deterministic unit coverage for generation and guided-adjustment races without depending on the blocked UI test runner.

### Included Tasks

1. Use subagents to inspect the UI runner blocker and the next workflow-race test seam.
2. Extract tune generation/adjustment task identity, cancellation, stale callback guards, and active feedback state into a small `TuneWorkflowController`.
3. Keep SwiftData persistence, saved tune lookup/update, and screen transitions in `ContentView`.
4. Add queued-provider unit tests for latest-generation-wins, stale partial suppression, generation cancellation, latest-adjustment-wins, and adjustment cancellation.

### Files Likely To Change

- `forzadvisor/Services/TuneWorkflowController.swift`
- `forzadvisor/ContentView.swift`
- `forzadvisor/ContentView+Workflow.swift`
- `forzadvisor/Models/TuningDomain.swift`
- `forzadvisor/Services/TuneProviderMode.swift`
- `forzadvisorTests/TuneWorkflowControllerTests.swift`
- `.agent/implementation-log.md`
- `.agent/verification.md`
- `.agent/test-report.md`
- `.agent/memory.md`
- `.agent/next-actions.md`

### Risks

- Avoid over-extracting root workflow navigation or SwiftData behavior.
- Keep active guided-adjustment UI feedback behavior unchanged.
- Treat Swift concurrency warnings as blockers.

### Verification Criteria

- Clean app build with zero warnings.
- Focused unit suite passes.
- Diff whitespace check passes.
- Full UI test runner blocker remains documented rather than masked by project edits.

---

## Iteration 16 - Result Row Accessibility Polish

### Chosen Slice

Recover the UI test runner enough to get a real result, then improve Dynamic Type and VoiceOver behavior in tune result rows.

### Included Tasks

1. Try the clean simulator/runner recovery path for the existing UI test.
2. Improve tune setting copy rows so large accessibility text sizes stack cleanly instead of squeezing labels and values.
3. Add explicit VoiceOver labels/hints for tune setting copy rows, adjustment change rows, feedback buttons, provider status, and note rows where useful.
4. Add a small manual-entry keyboard dismissal affordance so decimal/number keyboards do not trap users or block the UI smoke path.
5. Keep visual behavior and tune data unchanged.

### Files Likely To Change

- `forzadvisor/Views/TuneSectionDisclosureView.swift`
- `forzadvisor/Views/TuneResultView.swift`
- `forzadvisor/Views/ManualEntryView.swift`
- `forzadvisorUITests/ForzAdvisorUITests.swift`
- `.agent/implementation-log.md`
- `.agent/verification.md`
- `.agent/test-report.md`
- `.agent/memory.md`
- `.agent/next-actions.md`

### Risks

- Avoid changing generated tune content, copy-to-clipboard text, or guided-refinement behavior.
- Do not add brittle UI automation while the UI test body failure is not yet diagnosed.
- Keep compact result rows readable at normal sizes.

### Verification Criteria

- Clean app build with zero warnings.
- Focused unit suite passes.
- Diff whitespace check passes.
- UI-runner recovery attempt is recorded with its new failure mode.

---

## Iteration 17 - Release Readiness Version Sync

### Chosen Slice

Perform a doc-only release-readiness cleanup that does not depend on UI automation, signing, pushing, TestFlight, or web research.

### Included Tasks

1. Confirm project version/build from `forzadvisor.xcodeproj/project.pbxproj`.
2. Update App Store metadata mirrors from `1.1.3` build `6` to `1.1.5` build `8`.
3. Update release checklist mirrors so they no longer claim Quickflight/TestFlight readiness while full UI validation is blocked.
4. Split local validation from later human-approved push/TestFlight steps.

### Files Likely To Change

- `AppStore/release-checklist.md`
- `forzadvisorDocs/app-store/release-checklist.md`
- `AppStore/metadata.md`
- `forzadvisorDocs/app-store/metadata.md`
- `.agent/implementation-log.md`
- `.agent/verification.md`
- `.agent/test-report.md`
- `.agent/memory.md`
- `.agent/next-actions.md`

### Risks

- Keep this slice doc-only.
- Do not claim TestFlight or App Review readiness until full validation is clean and human approval is explicit.
- Preserve mirrored docs consistently.

### Verification Criteria

- `rg` confirms no stale `1.1.3`, build `6`, or `Quickflight ready` text remains in the edited metadata/checklist mirrors.
- `git diff --check` passes.

---

## Iteration 18 - UI Test Launch Hardening

### Chosen Slice

Make UI smoke launches deterministic by isolating simulator state and waiting for app readiness before the first UI query.

### Included Tasks

1. Add a `-ui-testing` app launch mode.
2. Use an in-memory SwiftData container when UI testing is active.
3. Force the provider mode to offline formulas during UI tests.
4. Add a root garage-home accessibility identifier.
5. Update the UI smoke test to pass `-ui-testing`, wait for foreground state, and wait for home readiness before tapping `New Tune`.

### Files Likely To Change

- `forzadvisor/forzadvisorApp.swift`
- `forzadvisor/Views/GarageHomeView.swift`
- `forzadvisorUITests/ForzAdvisorUITests.swift`
- `.agent/implementation-log.md`
- `.agent/verification.md`
- `.agent/test-report.md`
- `.agent/memory.md`
- `.agent/next-actions.md`

### Risks

- Keep the production SwiftData container unchanged.
- Avoid introducing a persistent test-only flag outside `CommandLine.arguments`.
- Do not broaden UI test coverage while the local XCTest accessibility service remains unstable.

### Verification Criteria

- Clean app build with zero warnings.
- Focused unit suite passes.
- Focused UI smoke is retried once by simulator ID if the local simulator service is responsive.
- `git diff --check` passes.

---

## Iteration 19 - Guided Refinement Copy Sync

### Chosen Slice

Perform a doc-only support/release copy cleanup so external tester and App Store-facing materials use the current in-app `Guided Refinement` label instead of the older `Adjust Feel` wording.

### Included Tasks

1. Use a focused subagent to identify stale `Adjust Feel` and legacy feel-adjustment copy.
2. Update support mirrors to describe `Guided Refinement` consistently.
3. Update App Store metadata mirrors to describe guided refinement after track testing.
4. Update release notes so tester instructions match the current UI label.

### Files Likely To Change

- `AppStore/support.md`
- `forzadvisorDocs/app-store/support.md`
- `AppStore/FeedbackRepo/support.md`
- `docs/support/index.md`
- `AppStore/metadata.md`
- `forzadvisorDocs/app-store/metadata.md`
- `AppStore/release-notes.md`
- `.agent/implementation-log.md`
- `.agent/verification.md`
- `.agent/test-report.md`
- `.agent/memory.md`
- `.agent/next-actions.md`
- `.agent/release-readiness.md`

### Risks

- Keep the slice doc-only.
- Do not make new release-readiness or TestFlight claims.
- Preserve mirrored support and metadata copy consistently.
- Do not change in-app labels or behavior.

### Verification Criteria

- `rg -n "Adjust Feel|quick feel adjustments|How do I adjust a saved tune\\?" AppStore forzadvisorDocs docs .agent` shows only historical `.agent` notes or no current support/release stale copy.
- `rg -n "Guided Refinement" AppStore forzadvisorDocs docs forzadvisor/Views/TuneResultView.swift` confirms support/release copy matches the in-app label.
- `git diff --check` passes.

---

## Iteration 20 - Manual Entry UI Smoke Input Hardening

### Chosen Slice

Make the existing manual-entry UI smoke produce deterministic valid form input before it attempts to navigate to discipline selection.

### Included Tasks

1. Fold Bernoulli's UI-smoke diagnosis into the implementation plan.
2. Avoid trailing-zero numeric values in the UI smoke where the latest evidence showed `2300` becoming `230`.
3. Assert `manualEntryNextButton` is enabled after filling required fields and selecting class/drivetrain, before tapping it.
4. Add a stable accessibility identifier to adjustment change rows and wait for that row after Guided Refinement.
5. Preserve the existing manual tune, save, reopen, and Guided Refinement smoke path.

### Files Likely To Change

- `forzadvisorUITests/ForzAdvisorUITests.swift`
- `forzadvisor/Views/TuneResultView.swift`
- `.agent/implementation-log.md`
- `.agent/verification.md`
- `.agent/test-report.md`
- `.agent/memory.md`
- `.agent/next-actions.md`

### Risks

- Keep this as UI-test hardening only; do not change production validation or manual-entry behavior.
- Do not broaden the UI smoke while the simulator layer remains noisy.
- If UI automation still fails, capture whether the form reached an enabled `Next` state.

### Verification Criteria

- Clean app build with zero warnings.
- Focused unit suite passes if practical for this app-code worktree.
- Focused UI smoke is retried once by simulator ID.
- `git diff --check` passes.

---

## Iteration 21 - Full-Scheme Validation Recovery

### Chosen Slice

Recover a clean full validation path now that focused build, unit tests, and the focused UI smoke pass individually.

### Included Tasks

1. Inspect current Xcode scheme/destination behavior enough to avoid repeating the name-based cloned-runner failure blindly.
2. Try full scheme testing against the explicit iPhone 17 simulator ID that passed the focused UI smoke.
3. If needed, try a build-for-testing/test-without-building split against the same simulator ID.
4. Record whether the remaining blocker is app/test logic or CoreSimulator/XCTest runner infrastructure.

### Files Likely To Change

- `.agent/implementation-log.md`
- `.agent/verification.md`
- `.agent/test-report.md`
- `.agent/memory.md`
- `.agent/next-actions.md`
- `.agent/release-readiness.md`

### Risks

- Do not change app code without new app-side evidence.
- Do not keep cycling on simulator runner failures.
- Stop and clean up any stuck `xcodebuild` or `simctl diagnose` processes.

### Verification Criteria

- Full scheme test either passes or fails with a captured, specific blocker.
- `git diff --check` passes.
- No leftover `xcodebuild` or `simctl diagnose` processes remain.

---

## Iteration 22 - Split Xcode Validation Gate

### Chosen Slice

Separate Xcode's test packaging step from the XCTest/CoreSimulator execution step to classify the remaining full-scheme validation blocker without changing app source.

### Included Tasks

1. Confirm no stale Xcode validation processes are already running.
2. Run `build-for-testing` against the explicit iPhone 17 simulator ID with parallel testing disabled and a dedicated result bundle.
3. If packaging succeeds, run `test-without-building` against the same simulator ID with parallel testing disabled and a dedicated result bundle.
4. Inspect readable result bundles and record whether the remaining blocker is packaging, app/test execution, or CoreSimulator/XCTest infrastructure.

### Files Likely To Change

- `.agent/implementation-log.md`
- `.agent/verification.md`
- `.agent/test-report.md`
- `.agent/memory.md`
- `.agent/next-actions.md`
- `.agent/release-readiness.md`

### Risks

- Do not edit app code during this slice.
- Do not keep retrying full-scheme variants if CoreSimulator or `simctl diagnose` hangs again.
- Clean up any stuck `xcodebuild` or `simctl diagnose` process before ending the loop.

### Verification Criteria

- `build-for-testing` and `test-without-building` either pass or fail with captured, specific evidence.
- `git diff --check` passes.
- No leftover `xcodebuild` or `simctl diagnose` processes remain.

---

## Iteration 23 - Manual Entry Invalid Frame Warning

### Chosen Slice

Remove the SwiftUI invalid-frame runtime warning that appears when the UI smoke transitions from Tune Source into Manual Entry.

### Included Tasks

1. Inspect the result bundle and UI test activities to locate the warning boundary.
2. Use a read-only subagent scan for likely SwiftUI frame sources.
3. Patch only the smallest likely Manual Entry layout source.
4. Rerun the split validation gate and require 54/54 passing tests with zero runtime warnings before commit readiness.

### Files Likely To Change

- `forzadvisor/Views/ManualEntryView.swift`
- `.agent/implementation-log.md`
- `.agent/verification.md`
- `.agent/test-report.md`
- `.agent/memory.md`
- `.agent/next-actions.md`
- `.agent/release-readiness.md`

### Risks

- Preserve the same manual-entry choices and accessibility identifiers.
- Avoid broad form or navigation refactors.
- If the warning persists, record the remaining evidence rather than guessing across unrelated screens.

### Verification Criteria

- Split `build-for-testing` passes.
- Split `test-without-building` passes 54/54 tests with no runtime warnings.
- `git diff --check` passes.
- No leftover `xcodebuild` or `simctl diagnose` processes remain.

---

## Iteration 24 - Result View Invalid Frame Warning

### Chosen Slice

Patch the highest-confidence result-view layout sources for the SwiftUI `Invalid frame dimension (negative or non-finite)` runtime warning.

### Included Tasks

1. Keep the split validation gate from iteration 22 as the verification path.
2. Replace the guided-refinement adaptive grid inside a `List` row with a stable vertical button stack.
3. Remove shared conditional `nil`/`.infinity` frame modifiers from tune value and adjustment change helpers.
4. Record whether the UI smoke executes and whether runtime warnings are cleared.

### Files Likely To Change

- `forzadvisor/Views/TuneResultView.swift`
- `forzadvisor/Views/TuneSectionDisclosureView.swift`
- `.agent/implementation-log.md`
- `.agent/verification.md`
- `.agent/test-report.md`
- `.agent/memory.md`
- `.agent/next-actions.md`
- `.agent/release-readiness.md`

### Risks

- Preserve Guided Refinement button identifiers and behavior.
- Preserve accessibility-size row stacking.
- Avoid broad UI redesign or navigation changes.
- If XCTest fails before the UI smoke executes, treat warning status as unverified.

### Verification Criteria

- Split `build-for-testing` passes.
- Split `test-without-building` executes the UI smoke, passes 54/54 tests, and reports no runtime warnings.
- `git diff --check` passes.
- No ForzAdvisor-specific `xcodebuild` or `simctl diagnose` processes remain.

---

## Iteration 25 - Fresh Simulator UI Smoke Validation

### Chosen Slice

Recover UI smoke validation by running the focused manual tune/save/reopen/refine smoke on a fresh temporary simulator, then inspect runtime warnings.

### Included Tasks

1. Confirm no ForzAdvisor-specific Xcode validation process is already running.
2. Create and boot a temporary iPhone 17 simulator with the available iOS 27 runtime.
3. Run only `forzadvisorUITests/ForzAdvisorUITests/testManualTuneCanBeSavedAndReopened` on the temporary simulator with a dedicated result bundle.
4. Inspect the result bundle for pass/fail status and runtime warnings.
5. Delete the temporary simulator and record whether the warning patches are proven.

### Files Likely To Change

- `.agent/implementation-log.md`
- `.agent/verification.md`
- `.agent/test-report.md`
- `.agent/memory.md`
- `.agent/next-actions.md`
- `.agent/release-readiness.md`

### Risks

- Do not edit app source in this validation-only slice.
- If UI execution fails before the app smoke body, treat warning status as unverified.
- Do not leave temporary simulator devices or Xcode processes behind.

### Verification Criteria

- Focused UI smoke executes on the temporary simulator.
- Result bundle reports pass/fail and runtime warnings.
- `git diff --check` passes.
- Temporary simulator is deleted.
- No ForzAdvisor-specific `xcodebuild` or `simctl diagnose` processes remain.

---

## Iteration 26 - Stable Non-UI Validation Checkpoint

### Chosen Slice

Establish a clean non-UI validation checkpoint while local XCTest/CoreSimulator Accessibility prevents trustworthy UI automation.

### Included Tasks

1. Run static searches confirming the removed SwiftUI risky-frame patterns remain absent.
2. Run a clean Xcode app build on the explicit iPhone 17 simulator.
3. Run the unit test target only.
4. Use a read-only release-gate subagent sanity check.
5. Record that commit remains blocked unless UI warning status is proven clean or the user accepts the local UI infrastructure blocker as a temporary exception.

### Files Likely To Change

- `.agent/implementation-log.md`
- `.agent/verification.md`
- `.agent/test-report.md`
- `.agent/memory.md`
- `.agent/next-actions.md`
- `.agent/release-readiness.md`

### Risks

- Do not edit app source in this validation-only slice.
- Do not claim UI warning cleanup is proven from non-UI checks.
- Do not commit without a clean zero-warning gate or explicit user exception.

### Verification Criteria

- Static risky-frame search passes.
- Xcode build passes with no warnings in command output.
- Unit tests pass.
- `git diff --check` passes.
- No ForzAdvisor-specific `xcodebuild` or `simctl diagnose` processes remain.

---

## Iteration 27 - Offline Formula Invariant Coverage

### Chosen Slice

Improve confidence in the offline tuning formulas with table-driven invariant tests across representative discipline and drivetrain combinations.

### Included Tasks

1. Add test-only coverage for formula output ranges across representative cars and all disciplines/drivetrains.
2. Assert drivetrain-specific differential line shape so FWD, RWD, and AWD tunes expose only the relevant differential controls.
3. Assert broad discipline invariants for drag, drift, off-road, cross-country, touge, and road behavior without freezing every formula as brittle golden values.
4. Use the existing Xcode unit-test gate and stable non-UI validation path.

### Files Likely To Change

- `forzadvisorTests/TuningKnowledgeBaseInvariantTests.swift`
- `.agent/implementation-log.md`
- `.agent/verification.md`
- `.agent/test-report.md`
- `.agent/memory.md`
- `.agent/next-actions.md`
- `.agent/reliability-audit.md`

### Risks

- Do not change formula behavior in this slice.
- Avoid brittle exact-value assertions except for intentional discipline/drivetrain shape.
- Preserve the dirty worktree and do not overwrite prior changes in `TuningDomainTests.swift`.
- Commit remains blocked unless the broader zero-warning gate is satisfied or the user accepts the documented UI infrastructure exception.

### Verification Criteria

- Focused tuning-domain/unit tests pass.
- App build passes with no command-output warnings.
- `git diff --check` passes.
- No ForzAdvisor-specific Xcode or simulator diagnostic processes remain.

---

## Iteration 28 - Provider Provenance In Full Tune Export

### Chosen Slice

Make copied full-tune text carry the same provider provenance/fallback status shown on the result screen, so shared/exported tunes remain honest outside the app.

### Included Tasks

1. Add a compact provider line to `TuneClipboardFormatter.fullTuneText(for:playerNotes:)`.
2. Preserve legacy saved-tune compatibility by using the existing "Provider not recorded" wording when `providerInfo` is missing.
3. Add focused formatter tests for direct provider output, fallback output, and legacy output.
4. Use the stable non-UI Xcode gate.

### Files Likely To Change

- `forzadvisor/Models/TuneClipboardFormatter.swift`
- `forzadvisorTests/TuneClipboardFormatterTests.swift`
- `.agent/implementation-log.md`
- `.agent/verification.md`
- `.agent/test-report.md`
- `.agent/memory.md`
- `.agent/next-actions.md`
- `.agent/product-audit.md`

### Risks

- Do not change provider routing, generated tune values, pasteboard actions, or UI layout.
- Keep copied text scannable and compatible with existing saved tunes.
- Commit remains blocked unless the broader zero-warning gate is satisfied or the user accepts the documented UI infrastructure exception.

### Verification Criteria

- Focused `TuneClipboardFormatterTests` pass.
- Full unit target passes.
- App build passes with no command-output warnings.
- `git diff --check` passes.
- No ForzAdvisor-specific Xcode or simulator diagnostic processes remain.

---

## Iteration 29 - Tuning Knowledge Base Driveline Split

### Chosen Slice

Reduce `TuningKnowledgeBase.swift` below the PRD's preferred file-size threshold by moving driveline-specific offline formula functions into a sibling extension file.

### Included Tasks

1. Move `finalDrive(for:)` into `TuningKnowledgeBase+Driveline.swift`.
2. Move `differential(for:)` into `TuningKnowledgeBase+Driveline.swift`.
3. Preserve formulas exactly; do not tune values, rename public API, or change provider behavior.
4. Use existing formula invariant coverage plus the stable non-UI Xcode gate.

### Files Likely To Change

- `forzadvisor/Services/TuningKnowledgeBase.swift`
- `forzadvisor/Services/TuningKnowledgeBase+Driveline.swift`
- `.agent/implementation-log.md`
- `.agent/verification.md`
- `.agent/test-report.md`
- `.agent/memory.md`
- `.agent/code-health.md`

### Risks

- This is a mechanical split only; avoid formula cleanup in the same loop.
- The project uses filesystem-synchronized groups, so a new Swift source under `forzadvisor/Services/` should compile without hand-editing the Xcode project.
- Commit remains blocked unless the broader zero-warning gate is satisfied or the user accepts the documented UI infrastructure exception.

### Verification Criteria

- `TuningKnowledgeBase.swift` is below 300 lines after the move.
- Focused `TuningKnowledgeBaseInvariantTests` pass.
- Full unit target passes.
- App build passes with no command-output warnings.
- `git diff --check` passes.
- No ForzAdvisor-specific Xcode or simulator diagnostic processes remain.

---

## Iteration 30 - Guided Refinement Domain Split

### Chosen Slice

Reduce the large `TuningDomain.swift` file by moving guided-refinement feedback and adjustment domain types into a sibling source file.

### Included Tasks

1. Move `TuneAdjustment` into `TuningDomain+Feedback.swift`.
2. Move `TuneFeedback` into `TuningDomain+Feedback.swift`.
3. Move `TuneAdjustmentResult` and `TuneAdjustmentChange` into `TuningDomain+Feedback.swift`.
4. Preserve behavior exactly; do not change feedback labels, prompts, mapping, rationale, IDs, provider behavior, or UI.
5. Use existing focused feedback/adjustment tests plus the stable non-UI Xcode gate.

### Files Likely To Change

- `forzadvisor/Models/TuningDomain.swift`
- `forzadvisor/Models/TuningDomain+Feedback.swift`
- `.agent/implementation-log.md`
- `.agent/verification.md`
- `.agent/test-report.md`
- `.agent/memory.md`
- `.agent/code-health.md`
- `.agent/next-actions.md`

### Risks

- This is a mechanical split only; avoid copy, behavior, or API cleanup in the same loop.
- The project uses filesystem-synchronized groups, so a new Swift source under `forzadvisor/Models/` should compile without hand-editing the Xcode project.
- Commit remains blocked unless the broader zero-warning gate is satisfied or the user accepts the documented UI infrastructure exception.

### Verification Criteria

- `TuneFeedback` mapping tests pass.
- Guided adjustment provider/workflow tests still compile and pass through the full unit target.
- App build passes with no command-output warnings.
- `git diff --check` passes.
- No ForzAdvisor-specific Xcode or simulator diagnostic processes remain.

---

## Iteration 31 - Provider Provenance Domain Split

### Chosen Slice

Continue the behavior-preserving domain cleanup by moving provider provenance helper types out of `TuningDomain.swift` and into a focused sibling source file.

### Included Tasks

1. Move `TuneProviderInfo` into `TuningDomain+Provider.swift`.
2. Move `TuneProviderFallbackReason` into `TuningDomain+Provider.swift`.
3. Move `TuneResult.withProviderInfo(_:)` into `TuningDomain+Provider.swift`.
4. Keep `TuneResult`, `providerInfo`, coding keys, init, and legacy decoding in `TuningDomain.swift`.
5. Preserve provider status copy, symbols, raw values, routing, fallback behavior, and UI behavior exactly.
6. Use existing provider provenance and formatter tests plus the stable non-UI Xcode gate.

### Files Likely To Change

- `forzadvisor/Models/TuningDomain.swift`
- `forzadvisor/Models/TuningDomain+Provider.swift`
- `.agent/implementation-log.md`
- `.agent/verification.md`
- `.agent/test-report.md`
- `.agent/memory.md`
- `.agent/code-health.md`
- `.agent/next-actions.md`

### Risks

- This is a mechanical split only; avoid provider routing, text, or serialization changes.
- The project uses filesystem-synchronized groups, so a new Swift source under `forzadvisor/Models/` should compile without hand-editing the Xcode project.
- Commit remains blocked unless the broader zero-warning gate is satisfied or the user accepts the documented UI infrastructure exception.

### Verification Criteria

- Provider provenance type definitions exist only in `TuningDomain+Provider.swift`.
- Legacy `TuneResult` decoding without provider info still passes.
- Provider fallback/direct tests and full-tune formatter tests pass.
- Full unit target passes.
- App build passes with no command-output warnings.
- `git diff --check` passes.
- No ForzAdvisor-specific Xcode or simulator diagnostic processes remain.

---

## Iteration 32 - Non-Parallel Focused UI Smoke Retry

### Chosen Slice

Try one bounded UI validation retry that directly targets the current release blocker: prove whether the manual tune/save/reopen/guided-refinement smoke can reach the app flow without the prior SwiftUI invalid-frame runtime warning when parallel UI testing is disabled.

### Included Tasks

1. Run `xcodebuild -list -project forzadvisor.xcodeproj` before UI validation.
2. Run only `forzadvisorUITests/ForzAdvisorUITests/testManualTuneCanBeSavedAndReopened` on the explicit iPhone 17 simulator.
3. Add `-parallel-testing-enabled NO` and keep the run bounded to this single UI smoke.
4. Inspect the resulting `.xcresult` summary for pass/fail count and runtime warnings.
5. Run `git diff --check` and process cleanup checks afterward.

### Files Likely To Change

- `.agent/implementation-log.md`
- `.agent/verification.md`
- `.agent/test-report.md`
- `.agent/memory.md`
- `.agent/next-actions.md`
- `.agent/release-readiness.md`

### Risks

- The local XCTest/CoreSimulator Accessibility issue may still fail below app code before the smoke can prove anything.
- A passing smoke with empty runtime warnings would materially unblock the commit gate; a runner/accessibility failure remains infrastructure evidence, not app-flow proof.
- Do not change UI test code, app code, project settings, signing, privacy, or release metadata in this validation-only slice.

### Verification Criteria

- A meaningful app-flow proof requires the focused UI smoke to execute through the manual tune/save/reopen/guided-refinement path and the `.xcresult` runtime warnings list to be empty.
- If the UI runner fails before app launch or before the app flow, record it as infrastructure-blocked and do not infer that the warning is fixed.
- `git diff --check` passes after report updates.
- No ForzAdvisor-specific Xcode or simulator diagnostic processes remain.

---

## Iteration 33 - Manual Entry Domain Split

### Chosen Slice

Continue the behavior-preserving domain cleanup by moving manual-entry draft and validation helper types out of `TuningDomain.swift` and into a focused sibling source file.

### Included Tasks

1. Move `ManualEntryDraft` into `TuningDomain+ManualEntry.swift`.
2. Move `ManualEntryValidationIssue` into `TuningDomain+ManualEntry.swift`.
3. Keep shared base car/tune types, `ValidationIssue`, `TuneRequest`, `TuneResult`, `TuneSection`, `TuneLine`, `TuneNotes`, and `SampleTuningData` in `TuningDomain.swift`.
4. Preserve validation ranges, messages, optional-field handling, `confirmedCarInput()`, and `init(car:)` behavior exactly.
5. Use existing manual-entry/OCR fallback tests plus the stable non-UI Xcode gate.

### Files Likely To Change

- `forzadvisor/Models/TuningDomain.swift`
- `forzadvisor/Models/TuningDomain+ManualEntry.swift`
- `.agent/implementation-log.md`
- `.agent/verification.md`
- `.agent/test-report.md`
- `.agent/memory.md`
- `.agent/code-health.md`
- `.agent/next-actions.md`

### Risks

- This is a mechanical split only; avoid changing validation copy, ranges, UI, OCR fallback, saved-tune behavior, or project settings.
- The project uses filesystem-synchronized groups, so a new Swift source under `forzadvisor/Models/` should compile without hand-editing the Xcode project.
- Commit remains blocked unless the broader zero-warning gate is satisfied or the user accepts the documented UI infrastructure exception.

### Verification Criteria

- Manual-entry type definitions exist only in `TuningDomain+ManualEntry.swift`.
- `TuningDomain.swift` drops below the PRD's preferred 300-line target.
- Focused manual-entry and OCR fallback tests pass.
- Full unit target passes.
- App build passes with no command-output warnings.
- `git diff --check` passes.
- No ForzAdvisor-specific Xcode or simulator diagnostic processes remain.

---

## Iteration 34 - API Partial Merge Helper Split

### Chosen Slice

Continue the behavior-preserving service-layer cleanup by moving API partial-response merge helpers out of `TuneAPISections.swift` and into a focused sibling service file.

### Included Tasks

1. Move `extension Array where Element == TuneSection` into `TuneAPIMerging.swift`.
2. Move `extension Array where Element == TuneLine` into `TuneAPIMerging.swift`.
3. Move `TuneAPINotes.merging(into:)` into `TuneAPIMerging.swift`.
4. Keep API section DTOs and JSON-to-display-section conversion in `TuneAPISections.swift`.
5. Do not move `TuneResult.section(_:)`, `TuneSection.number(_:)`, `TuneLine.numericValue`, or `DrivingDiscipline.apiValue` in this slice.
6. Preserve merge order, replacement rules, notes fallback behavior, signatures, access levels, provider routing, UI behavior, and project settings exactly.

### Files Likely To Change

- `forzadvisor/Services/TuneAPISections.swift`
- `forzadvisor/Services/TuneAPIMerging.swift`
- `.agent/implementation-log.md`
- `.agent/verification.md`
- `.agent/test-report.md`
- `.agent/memory.md`
- `.agent/code-health.md`
- `.agent/next-actions.md`

### Risks

- This is a mechanical split only; avoid changing API DTO names, coding keys, conversion order, merge semantics, provider behavior, or UI.
- The project uses filesystem-synchronized groups, so a new Swift source under `forzadvisor/Services/` should compile without hand-editing the Xcode project.
- Commit remains blocked unless the broader zero-warning gate is satisfied or the user accepts the documented UI infrastructure exception.

### Verification Criteria

- Partial merge helpers exist only in `TuneAPIMerging.swift`.
- `TuneAPISections.swift` drops below the PRD's preferred 300-line target.
- Focused partial-adjustment merge test passes.
- Full unit target passes.
- App build passes with no command-output warnings.
- `git diff --check` passes.
- No ForzAdvisor-specific Xcode or simulator diagnostic processes remain.

---

## Iteration 35 - API Request DTO Split

### Chosen Slice

Continue the behavior-preserving API service cleanup by moving remote request-construction DTOs out of `TuneAPIModels.swift` and into a focused sibling service file.

### Included Tasks

1. Move `TuneAPIRequestPayload` into `TuneAPIRequests.swift`.
2. Move `TuneAPIAdjustmentPayload` into `TuneAPIRequests.swift`.
3. Move `TuneAPICar` into `TuneAPIRequests.swift`.
4. Keep `TuneAPIResponse`, `TuneAPITune`, response/result mapping, and section DTO references in `TuneAPIModels.swift`.
5. Preserve request action strings, coding keys, car payload mapping, `DrivingDiscipline.apiValue` usage, adjustment payload shape, signatures, access levels, provider routing, network behavior, and project settings exactly.

### Files Likely To Change

- `forzadvisor/Services/TuneAPIModels.swift`
- `forzadvisor/Services/TuneAPIRequests.swift`
- `.agent/implementation-log.md`
- `.agent/verification.md`
- `.agent/test-report.md`
- `.agent/memory.md`
- `.agent/code-health.md`
- `.agent/next-actions.md`

### Risks

- This is a mechanical split only; avoid changing API payload keys, request actions, response/result mapping, provider behavior, or UI.
- `TuneAPIRequests.swift` remains in the same module, so internal cross-file references to `TuneAPIResponse` and `DrivingDiscipline.apiValue` should compile.
- The project uses filesystem-synchronized groups, so a new Swift source under `forzadvisor/Services/` should compile without hand-editing the Xcode project.
- Commit remains blocked unless the broader zero-warning gate is satisfied or the user accepts the documented UI infrastructure exception.

### Verification Criteria

- Request DTO definitions exist only in `TuneAPIRequests.swift`.
- `TuneAPIModels.swift` drops below the PRD's preferred 300-line target.
- Focused `TuneAPIModelTests` pass.
- Full unit target passes.
- App build passes with no command-output warnings.
- `git diff --check` passes.
- No ForzAdvisor-specific Xcode or simulator diagnostic processes remain.

---

## Iteration 36 - Complete Pending Non-UI Validation Gate

### Chosen Slice

Complete the pending full non-UI validation gate for the iteration 35 API request DTO split after the prior loop's Xcode command was blocked by the environment usage-limit guard.

### Included Tasks

1. Use a read-only subagent to confirm whether this wakeup should remain validation-only.
2. Run `xcodebuild -list -project forzadvisor.xcodeproj` before scripted validation.
3. Run the full `forzadvisorTests` unit target on the explicit iPhone 17 simulator.
4. Inspect the readable result bundle summary for pass/fail count and runtime warnings when available.
5. Run the app build on the explicit iPhone 17 simulator.
6. Run `git diff --check` and final process cleanup checks.
7. Update `.agent` memory/report files with the validation result and any blocker.

### Files Likely To Change

- `.agent/plan.md`
- `.agent/implementation-log.md`
- `.agent/verification.md`
- `.agent/test-report.md`
- `.agent/memory.md`
- `.agent/code-health.md`
- `.agent/next-actions.md`

### Risks

- Xcode validation may still be rejected by the environment usage-limit guard; if so, do not attempt an indirect workaround.
- Full scheme/UI validation remains separately blocked by local XCTest/CoreSimulator Accessibility/finalization instability and is not part of this loop unless user direction changes.
- Commit remains blocked unless the full non-UI gate passes and the broader UI runtime-warning proof gate is satisfied or explicitly waived by the user.

### Verification Criteria

- `xcodebuild -list -project forzadvisor.xcodeproj` succeeds.
- Full `forzadvisorTests` passes with zero failures and no command-output warnings.
- App build passes with no command-output warnings.
- Result bundle inspection is recorded, including runtime warning status if readable.
- `git diff --check` passes.
- No ForzAdvisor-specific Xcode or simulator diagnostic processes remain.

---

## Iteration 37 - Manual UI Smoke Handoff Package

### Chosen Slice

Turn the remaining release blocker into a concrete manual interactive UI smoke checklist and acceptance gate instead of adding new app code or repeating unreliable shell-based UI automation.

### Included Tasks

1. Use a read-only subagent to confirm whether a release-readiness handoff is the safest next slice.
2. Add a manual UI smoke checklist to release-readiness notes with exact pass/fail criteria.
3. Update next actions so future loops do not repeat the same shell UI smoke and know what evidence clears the blocker.
4. Record this as a documentation/release-readiness loop in implementation, verification, test, and memory files.
5. Run static validation only: `git diff --check` and scope inspection.

### Files Likely To Change

- `.agent/plan.md`
- `.agent/release-readiness.md`
- `.agent/next-actions.md`
- `.agent/implementation-log.md`
- `.agent/verification.md`
- `.agent/test-report.md`
- `.agent/memory.md`

### Risks

- This loop does not prove the SwiftUI warning is fixed; it clarifies the manual evidence needed.
- Do not run another shell-based focused UI smoke unless the local Xcode/CoreSimulator Accessibility state changes or the user explicitly asks.
- Do not commit app work from this loop; it is release-gate documentation only.

### Verification Criteria

- Release-readiness notes include an interactive manual UI smoke checklist with exact acceptance criteria.
- Next actions clearly separate the green stable non-UI gate from the still-missing UI runtime-warning proof.
- Test report states that no Xcode shell UI validation was run in this loop and why.
- `git diff --check` passes.

---

## Iteration 38 - Commit-Readiness Diff Inventory

### Chosen Slice

Create a commit-readiness inventory and staging map for the accumulated factory work so the eventual commit can be reviewed intentionally once UI runtime-warning proof or an explicit temporary exception exists.

### Included Tasks

1. Use a read-only subagent to confirm this should be an inventory-only loop.
2. Inspect current tracked and untracked worktree paths.
3. Group the intended dirty worktree into reviewable commit/staging categories.
4. Record exclusions, risks, available evidence, and remaining blocker.
5. Update `.agent` memory and release-readiness notes; do not edit app source or run Xcode.
6. Run static validation only: `git diff --check` and `.agent` markdown whitespace checks.

### Files Likely To Change

- `.agent/plan.md`
- `.agent/release-readiness.md`
- `.agent/next-actions.md`
- `.agent/implementation-log.md`
- `.agent/verification.md`
- `.agent/test-report.md`
- `.agent/memory.md`

### Risks

- The inventory does not clear the UI runtime-warning blocker.
- Splitting the accumulated work into multiple commits may be risky because several feature groups overlap in the same Swift files.
- `.agent/` is currently untracked process memory; decide separately whether it should be committed with app changes.

### Verification Criteria

- Release-readiness notes include the intended commit groups, exclusions, and evidence.
- Next actions identify the manual UI proof or temporary exception required before commit.
- Test report explains why no Xcode validation was rerun.
- `git diff --check` passes.
- `.agent` markdown files touched in this loop have no trailing whitespace.

---

## Iteration 39 - Manual UI Smoke Evidence Log Template

### Chosen Slice

Add a structured fill-in evidence log for the manual interactive UI smoke so the runtime-warning gate can be cleared or failed with precise proof.

### Included Tasks

1. Use a read-only subagent to confirm whether an evidence template is useful and not redundant.
2. Add a fill-in Manual UI Smoke Evidence Log to `.agent/release-readiness.md`.
3. Update `.agent/next-actions.md` so future manual proof is recorded in that log.
4. Update `.agent/memory.md` with the iteration record.
5. Do not update `.agent/test-report.md` until an actual manual smoke run has results.
6. Run static validation only: `git diff --check` and `.agent` markdown whitespace checks.

### Files Likely To Change

- `.agent/plan.md`
- `.agent/release-readiness.md`
- `.agent/next-actions.md`
- `.agent/memory.md`

### Risks

- This template does not clear the UI runtime-warning blocker by itself.
- Avoid making the evidence log look like a passing result until a real manual run is completed.
- Do not rerun shell UI automation or Xcode validation in this documentation-only loop.

### Verification Criteria

- Release-readiness notes include blank fields for tester, environment, completed steps, console warning search, anomalies, and release decision.
- Next actions direct future manual runs to fill in the evidence log.
- Test report is left untouched until real results exist.
- `git diff --check` passes.
- `.agent` markdown files touched in this loop have no trailing whitespace.

---

## Iteration 40 - Blocker-Only Manual UI Gate Status

### Chosen Slice

Record that no further useful autonomous slice remains until the manual interactive UI smoke is run or the user grants an explicit temporary commit exception.

### Included Tasks

1. Use a read-only subagent to confirm whether another autonomous slice would be useful or redundant.
2. Record the blocker-only status in `.agent` memory and next actions.
3. Do not edit app source, tests, release copy, signing, privacy, project settings, or marketing assets.
4. Do not rerun shell UI automation.
5. Run static validation only: `git diff --check` and `.agent` markdown whitespace checks.

### Files Likely To Change

- `.agent/plan.md`
- `.agent/next-actions.md`
- `.agent/implementation-log.md`
- `.agent/verification.md`
- `.agent/test-report.md`
- `.agent/memory.md`

### Risks

- This loop intentionally makes no product progress; it prevents cycling while preserving the exact manual action needed.
- The UI runtime-warning blocker remains uncleared.

### Verification Criteria

- Next actions clearly state no further autonomous non-cycling slice remains.
- Release-readiness evidence template remains unchanged until a real manual run or explicit exception exists.
- `git diff --check` passes.
- `.agent` markdown files touched in this loop have no trailing whitespace.
