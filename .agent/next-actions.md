# Next Actions

## Selected Loop

Manual UI smoke handoff is the active release gate: await interactive/local Xcode UI proof or an explicit temporary commit exception.

## Tasks

1. Treat the Manual Entry and result-view warning patches as built and stable under non-UI validation, but still unverified by UI smoke.
2. Stop cycling local shell-based UI automation until XCTest Accessibility/finalization services recover, a local Xcode UI run can be performed interactively, or the user explicitly asks for another retry.
3. Keep the fallback validation gate green with app build, unit tests, static risky-frame search, and `git diff --check`.
4. Commit only after warning status is proven clean or the user explicitly accepts the local UI infrastructure blocker as a temporary commit exception.
5. Use the manual UI smoke checklist in `.agent/release-readiness.md` as the exact evidence package for clearing the runtime-warning blocker.

## Deferred

- Add UI-level OCR/import/manual-entry and workflow race coverage after the UI runner is healthy.
- Manual simulator verification for largest accessibility Dynamic Type and VoiceOver result-row reading.
- Add deeper formula cases for edge weights/classes after the new invariant matrix has settled.
- Audit current screenshot set against the latest app UI after UI automation or manual simulator capture is available.
- TestFlight upload and push after explicit approval.

## Latest Blocker Detail

- Iteration 40 confirmed with a read-only subagent that no materially useful autonomous, non-cycling slice remains. The next unlock requires human action: run the manual interactive UI smoke and fill in `.agent/release-readiness.md`, or explicitly grant a temporary commit exception.
- Iteration 39 added a blank Manual UI Smoke Evidence Log to `.agent/release-readiness.md`. Future interactive manual UI proof should be recorded there before clearing the runtime-warning blocker. `.agent/test-report.md` was intentionally left unchanged because no manual run has occurred.
- Iteration 38 recorded the commit-readiness diff inventory and staging map: intended groups are provider transparency/fallback tracking, workflow reliability, manual-entry/UI-warning/accessibility polish, code-health splits/formula coverage, release/support copy sync, and optional `.agent` process memory. Commit remains blocked by UI runtime-warning proof or explicit temporary exception.
- Iteration 37 converted the remaining UI runtime-warning blocker into a manual interactive UI smoke handoff checklist with exact setup, flow, pass/fail criteria, and release gate decision rules. No shell UI automation was run.
- Iteration 36 completed the pending full non-UI validation gate for the iteration 35 API request DTO split: project listing passed, full unit target passed 58/58 with no runtime warnings, app build passed with no warning output, static risky-frame checks were acceptable, `git diff --check` passed, and no ForzAdvisor-specific Xcode/simulator processes remained.
- Iteration 35 split API request DTOs out of `TuneAPIModels.swift`; focused `TuneAPIModelTests` passed with no runtime warnings, DTO location checks passed, and the full non-UI gate was completed in iteration 36.
- Iteration 34 split API partial-response merge helpers out of `TuneAPISections.swift`; stable non-UI gate passed with 58 unit tests and no runtime warnings.
- Iteration 33 split manual-entry draft and validation helper types out of `TuningDomain.swift`; stable non-UI gate passed with 58 unit tests and no runtime warnings.
- Iteration 32 performed the one planned non-parallel focused UI smoke retry. It reached `Testing started` but hung during Xcode test-log finalization, had to be terminated, and produced a corrupted `.xcresult` with no `Info.plist`; no app-flow or runtime-warning proof was available.
- Iteration 31 split provider provenance helper types out of `TuningDomain.swift`; stable non-UI gate passed with 58 unit tests and no runtime warnings.
- Iteration 30 split guided-refinement feedback types out of `TuningDomain.swift`; stable non-UI gate passed with 58 unit tests and no runtime warnings.
- Iteration 29 split driveline formulas out of `TuningKnowledgeBase.swift`; stable non-UI gate passed with 58 unit tests and no runtime warnings.
- Iteration 28 added provider provenance to copied full-tune text; stable non-UI gate passed with 58 unit tests and no runtime warnings.
- Iteration 27 added formula invariant tests; stable non-UI gate passed with 56 unit tests and no runtime warnings.
- Iteration 26 stable non-UI gate passed: app build clean, unit bundle passed 53/53 with no runtime warnings, static risky-frame search clean, and `git diff --check` passed.
- Iteration 25 fresh temporary simulator focused UI smoke failed before the app flow with `Failed to get list of active applications` / `XC_kAXXCAttributeFocusedApplications` timeout.
- Prior passing UI run had runtime warning: `Invalid frame dimension (negative or non-finite)`.
- Empty runtime-warning list from iteration 25 is inconclusive because the smoke did not reach the result/guided-refinement screens.
- No leftover Xcode validation processes after cleanup.

## Commit-Readiness Staging Map

- Primary recommendation: commit only after the manual UI smoke checklist passes, or after the user explicitly grants a temporary commit exception.
- Likely commit shape: one broad, intentionally described checkpoint commit may be safer than partial staging because provider transparency, workflow reliability, UI warning mitigation, and test changes overlap in shared Swift files.
- Optional split if needed: use the groups in `.agent/release-readiness.md` and rebuild/test after each partial stage.
- Treat `.agent/` as local process memory unless the user decides it should be tracked.
- When manual UI smoke is run, fill in the Manual UI Smoke Evidence Log in `.agent/release-readiness.md` before changing blocker status.
