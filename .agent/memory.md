# Project Memory

## Completed Work

- 2026-06-27 PDT: Ran iteration 20. Used Bernoulli's UI-smoke diagnosis to harden manual-entry input and Guided Refinement verification. Build passed, 53 focused unit tests passed, and the focused manual tune/save/reopen/refine UI smoke passed. Full scheme still failed during the UI runner phase with simulator launch denial and Xcode log-finalization hang.
- 2026-06-27 PDT: Ran iteration 19. Used Socrates for stale support/release copy inspection; synced support, docs, App Store metadata, and TestFlight notes from old `Adjust Feel` wording to the current in-app `Guided Refinement` label. Static copy searches and `git diff --check` pass. No Xcode run because this loop was doc-only.
- 2026-06-27 PDT: Ran iteration 18. Used Peirce for UI-test launch hardening review; added `-ui-testing` launch isolation, in-memory SwiftData for UI tests, volatile offline-provider override, garage-home readiness identifier, and less brittle UI smoke startup waits. App build and 53 focused unit tests pass; focused UI smoke still fails after launch and Xcode hangs while finalizing logs.
- 2026-06-27 PDT: Ran iteration 17. Tried a fresh temporary iPhone 17 simulator for the focused UI smoke; runner still launched then failed in-body, so UI automation remains blocked by local XCTest accessibility-service instability. Synced release checklist and metadata mirrors to project version 1.1.5 build 8 and removed stale Quickflight-ready claims. Static doc checks pass.
- 2026-06-27 PDT: Ran iteration 16. Recovered the UI runner past request-denied by booting/cleaning the iPhone 17 simulator, added manual-entry keyboard focus/dismissal, and polished result-row Dynamic Type/VoiceOver behavior. App build and unit tests pass; focused UI smoke now fails with an XCTest accessibility-service timeout while querying active applications.
- 2026-06-27 PDT: Ran iteration 21. Validation-only loop. Scheme/destination inspection passed; explicit-ID full scheme still used XCTest clones and failed one UI test with accessibility IPC timeout after 53 tests passed; non-parallel full scheme hung during log finalization/simctl diagnostics and produced a corrupted result bundle. No source changes or commit.
- 2026-06-28 PDT: Ran iteration 22. Validation-only split gate. `build-for-testing` passed; `test-without-building` passed 54/54 tests on explicit iPhone 17 with parallel testing disabled. Remaining blocker is a SwiftUI runtime warning: `Invalid frame dimension (negative or non-finite)`.
- 2026-06-28 PDT: Ran iteration 23. Patched Manual Entry class/drivetrain chips to avoid infinite-width labels in form rows after prior warning activity pointed to the manual-entry transition. Build-for-testing passed, but test-without-building failed before UI execution with `Timed out while preparing execution worker`; runtime-warning fix remains unverified. Subagent ranked guided-refinement/tune-result frames as strongest remaining suspects.
- 2026-06-28 PDT: Ran iteration 24. Patched result-view warning suspects: Guided Refinement now uses a vertical stack instead of an adaptive grid in a List row, and tune/adjustment value fill frames are only applied in accessibility layout branches. Build-for-testing passed, but test-without-building failed before UI execution with `Timed out while loading Accessibility`; runtime-warning fix remains unverified.
- 2026-06-28 PDT: Ran iteration 25. Created a fresh temporary iPhone 17 simulator and ran the focused UI smoke. The UI runner used a clone and failed before the app flow with `Failed to get list of active applications` / `XC_kAXXCAttributeFocusedApplications` timeout; Xcode then hung finalizing diagnostics. Temporary simulator cleanup succeeded. Warning patches remain unverified.
- 2026-06-28 PDT: Ran iteration 26. Stable non-UI validation checkpoint only: risky frame-pattern search stayed clean, app build passed, unit-only result bundle passed 53/53 with no runtime warnings, and `git diff --check` passed. No source changes or commit; UI warning cleanup remains unproven until a smoke reaches the app flow.
- 2026-06-28 PDT: Ran iteration 27. Added `TuningKnowledgeBaseInvariantTests` with matrix-style offline formula invariants across representative disciplines and drivetrains. Focused tests passed 3/3, full unit target passed 56/56 with no runtime warnings, app build passed, and `git diff --check` passed. No commit because the broader UI warning proof blocker remains.
- 2026-06-28 PDT: Ran iteration 28. Added provider provenance to copied full-tune text and focused formatter coverage for direct, fallback, and legacy provider cases. Formatter tests passed 4/4, full unit target passed 58/58 with no runtime warnings, app build passed, and `git diff --check` passed. No commit because the broader UI warning proof blocker remains.
- 2026-06-28 PDT: Ran iteration 29. Split final-drive and differential formulas into `TuningKnowledgeBase+Driveline.swift`, reducing `TuningKnowledgeBase.swift` to 278 lines without behavior changes. Formula invariant tests passed 3/3, full unit target passed 58/58 with no runtime warnings, app build passed, and `git diff --check` passed. No commit because the broader UI warning proof blocker remains.
- 2026-06-28 PDT: Ran iteration 30. Split guided-refinement feedback and adjustment result types into `TuningDomain+Feedback.swift`, reducing `TuningDomain.swift` to 454 lines without behavior changes. Focused feedback tests passed 3/3, full unit target passed 58/58 with no runtime warnings, app build passed, and `git diff --check` passed. No commit because the broader UI warning proof blocker remains.
- 2026-06-28 PDT: Ran iteration 31. Split provider provenance helper types into `TuningDomain+Provider.swift`, reducing `TuningDomain.swift` to 376 lines without behavior changes. Focused provider provenance tests passed 5/5, full unit target passed 58/58 with no runtime warnings, app build passed, and `git diff --check` passed. No commit because the broader UI warning proof blocker remains.
- 2026-06-28 PDT: Ran iteration 32. Performed the one planned non-parallel focused UI smoke retry for `testManualTuneCanBeSavedAndReopened`. The command reached `Testing started` but hung during Xcode test-log finalization, had to be terminated, and left a corrupted `.xcresult` without `Info.plist`; no app-flow or runtime-warning proof was available. Cleaned the corrupted generated bundle, confirmed no lingering Xcode/simulator diagnostic processes, and passed `git diff --check`. No commit because UI warning proof remains unavailable.
- 2026-06-28 PDT: Ran iteration 33. Split manual-entry draft and validation helper types into `TuningDomain+ManualEntry.swift`, reducing `TuningDomain.swift` to 225 lines and below the PRD's preferred 300-line target without behavior changes. Focused manual-entry/OCR fallback tests passed 3/3, full unit target passed 58/58 with no runtime warnings, app build passed, and `git diff --check` passed. No commit because the broader UI warning proof blocker remains.
- 2026-06-28 PDT: Ran iteration 34. Split API partial-response merge helpers into `TuneAPIMerging.swift`, reducing `TuneAPISections.swift` to 275 lines and below the PRD's preferred 300-line target without behavior changes. Focused partial-adjustment merge test passed 1/1, full unit target passed 58/58 with no runtime warnings, app build passed, and `git diff --check` passed. No commit because the broader UI warning proof blocker remains.
- 2026-06-28 PDT: Ran iteration 35. Split API request DTOs into `TuneAPIRequests.swift`, reducing `TuneAPIModels.swift` to 246 lines and below the PRD's preferred 300-line target without behavior changes. Focused `TuneAPIModelTests` passed 11/11 with no runtime warnings, DTO location checks passed, and `git diff --check` passed. Full unit target and app build could not be run because the environment rejected the needed Xcode command due the current usage-limit guard, so no commit was created.
- 2026-06-28 PDT: Ran iteration 36. Validation-only checkpoint for the iteration 35 API request DTO split. `xcodebuild -list` passed; full `forzadvisorTests` passed 58/58 with no runtime warnings; app build passed with no warning output; static risky-frame searches were acceptable; `git diff --check` passed; and no ForzAdvisor-specific Xcode/simulator processes remained. No commit because the broader UI warning proof blocker remains.
- 2026-06-28 PDT: Ran iteration 37. Release-readiness handoff loop. Added a manual interactive Xcode/simulator UI smoke checklist to `.agent/release-readiness.md` with setup, flow, pass/fail criteria, and release gate decision rules. Updated `.agent/next-actions.md` so future loops use that checklist instead of repeating unreliable shell-based UI smoke. No app source changes and no commit.
- 2026-06-28 PDT: Ran iteration 38. Commit-readiness inventory loop. Grouped the accumulated dirty worktree into provider transparency/fallback tracking, workflow reliability, manual-entry/UI-warning/accessibility polish, code-health splits/formula coverage, release/support copy sync, and optional `.agent` process memory. Recorded exclusions, available evidence, and missing UI runtime-warning proof. No app source changes and no commit.
- 2026-06-28 PDT: Ran iteration 39. Added a blank Manual UI Smoke Evidence Log to `.agent/release-readiness.md` so the future interactive UI smoke can record tester, environment, completed steps, console-warning search result, anomalies, and release decision. No manual run occurred, no app source changed, and no commit was created.
- 2026-06-28 PDT: Ran iteration 40. Blocker-only status loop. A read-only subagent confirmed no useful autonomous, non-cycling slice remains after the manual checklist, staging map, and evidence log. No app source changed and no commit was created; manual UI proof or an explicit temporary exception is required.
- 2026-06-27: Ran iteration 15. Used subagents for UI-runner diagnosis and workflow-race seam selection; added `TuneWorkflowController` plus unit coverage for stale generation partials/results, generation cancellation, stale adjustment results, and adjustment cancellation. App build and unit tests pass; UI test runner launch still fails before assertions.
- 2026-06-27: Ran iteration 14. Extracted photo OCR import handling into an injected controller and added unit coverage for cancellation, failure retry state, and latest-import-wins behavior. App build and unit tests pass; UI test runner launch still fails before assertions.
- 2026-06-27: Ran iteration 10. Added operation IDs and task cancellation for tune generation and guided adjustment; refetches saved tunes after adjustment awaits; app build and unit tests pass.
- 2026-06-27: Ran iteration 9. Added OCR/photo import operation cancellation guards, cooperative OCR cancellation checks, and provider cancellation rethrow before fallback. App build and unit tests pass; UI test runner launch still fails before assertions.
- 2026-06-27: Ran iteration 8 validation checkpoint. Xcode now sees eligible iOS 27.0 simulators; app build passed on iPhone 17; all unit tests passed. Full scheme/UI validation remains blocked because the UI test runner cannot launch on the simulator.
- 2026-06-27: Created `.agent` project memory, updated first-run empty garage copy, refreshed stale manual-entry header comments, and added API adjustment fallback test coverage. Build/test/commit blocked by local Xcode setup.
- 2026-06-27: Ran iteration 2. Added provider readiness/fallback status to Settings and synchronized API key save/clear state. Xcode first-launch setup now succeeds; build/test remains blocked by iOS 26.5 SDK vs iOS 27.0 simulator runtime mismatch.
- 2026-06-27: Ran iteration 3. Added on-device guided-refinement fallback coverage when the Apple model is unavailable. Production behavior unchanged.
- 2026-06-27: Ran iteration 4. Added saved-tune retune boundary coverage for exact and over-threshold weight/front-distribution edits. Production behavior unchanged.
- 2026-06-27: Ran iteration 5. Updated OCR processing copy to reinforce that image reading happens on device. Behavior unchanged.
- 2026-06-27: Ran iteration 6. Disabled Settings' destructive Clear Key action when there is no saved or typed key to clear.
- 2026-06-27: Ran iteration 7. Cleaned stale MVP/manual-only/local-only comments in tests, discipline picker, and tune provider boundary.
- SwiftUI workflow for garage, tune source, OCR review, manual entry, discipline selection, generation, tune display, saved edit, and guided refinement.
- SwiftData saved garage.
- Offline formula provider.
- Optional Anthropic API provider with Keychain API key storage.
- Optional on-device Foundation Models provider with fallback.
- Unit and UI test targets.
- App Store support, privacy, metadata, release notes, and screenshots.

## Do Not Repeat

- Do not treat the original PRD as the current implementation state without checking source and release notes.
- Do not cycle on sandboxed Xcode/CoreSimulator failures; record the blocker and use the local Xcode gate once available.
- Do not repeat the shell-based non-parallel focused UI smoke after iteration 32's test-log finalization hang unless the Xcode/CoreSimulator Accessibility stack changes or the user explicitly asks for another retry.
- Do not push, upload, or make App Store changes without explicit approval.

## Reusable Components

- `CompositeTuneProvider`
- `LocalSampleTuneProvider`
- `TuningKnowledgeBase` plus focused `+Tables`, `+Types`, and `+Driveline` extensions
- `ManualEntryDraft` and `ManualEntryValidationIssue` in `TuningDomain+ManualEntry.swift`
- `TuneFeedback` and `TuneAdjustment` in `TuningDomain+Feedback.swift`
- `TuneProviderInfo` and `TuneProviderFallbackReason` in `TuningDomain+Provider.swift`
- `TuneAPIMerging.swift` partial response merge helpers
- `TuneAPIRequests.swift` request payload DTOs
- `TuneClipboardFormatter`
- `SavedTuneEditDraft`
- `ForzAdvisorTheme`
- `ForzAdvisorScreenHeader`
- OCR confirmation draft and parser models

## Proven Patterns

- Small vertical slices with tests.
- Offline-first behavior with optional provider fallback.
- Confirmation before OCR-derived tuning.
- Menu-order tune rendering.

## Fragile Areas

- Xcode/CoreSimulator local environment. The previous SDK/runtime destination blocker is resolved and the focused UI smoke now passes, but full scheme testing can still fail when the cloned UI test runner is denied launch, then Xcode hangs while finalizing logs.
- Full-scheme direct validation can fail with XCTest clone/accessibility/finalization instability. The current stable release-gate workaround is split `build-for-testing` plus `test-without-building` on the explicit iPhone 17 simulator ID with parallel testing disabled.
- SwiftUI runtime warning `Invalid frame dimension (negative or non-finite)` is the current zero-warning blocker before commit/release readiness.
- UI runner can still fail at worker preparation even on the split gate. Do not interpret an empty runtime-warning list from a run where the UI smoke did not execute as a fixed warning.
- UI runner can also fail before app launch with `The test runner failed to initialize for UI testing. (Underlying Error: Timed out while loading Accessibility.)`
- Fresh temporary simulator validation can still fail below app code when XCTest Accessibility cannot fetch focused applications from the cloned runner destination.
- Optional provider fallback transparency.
- Larger Swift files near the PRD line-count target.
- Async workflow task cancellation has deterministic unit coverage for OCR import, generation, and guided adjustment, but it still needs UI/manual smoke once the UI runner launches reliably.

## Product Decisions

- Offline formulas are default.
- Screenshots are processed on device.
- BYO Anthropic key is optional.
- No App Store/TestFlight action without explicit approval.

## CEO-Level Decisions Needed

- Next priority: release/TestFlight, provider transparency, formula accuracy, UI polish, or community launch.
- Whether push/upload permissions are granted once validation passes.

## Deferred Ideas

- Provider fallback status UI.
- Add UI-level race tests for generation, guided adjustment, and OCR/import once the test runner supports it reliably.
- Manually verify largest Dynamic Type and VoiceOver result-row reading once simulator accessibility services are stable.
- Live community research and launch post drafts.
- More formula coverage by class/drivetrain/discipline.
- File splitting when behavior work naturally touches remaining large files.

## Next Best Loops

1. Run the manual interactive UI smoke checklist in `.agent/release-readiness.md` and fill in the Manual UI Smoke Evidence Log, or ask whether a temporary commit exception is acceptable for the local XCTest Accessibility/finalization blocker. No further autonomous non-cycling loop remains before this decision.
2. If commit is allowed after UI proof or exception, use the staging map in `.agent/release-readiness.md` and prefer one broad checkpoint commit unless a careful partial-stage build/test pass is available.
3. Keep stable non-UI gates green with app build, unit tests, static risky-frame search, and `git diff --check`.
4. If the manual UI smoke passes with no runtime warnings, rerun the stable non-UI gate and commit the scoped work.
5. Add deeper source-backed formula cases by class and edge-weight combinations when product accuracy is the selected slice.
6. Continue small behavior-preserving code-health slices only when they materially improve release readiness and remain covered by the stable non-UI gate.
