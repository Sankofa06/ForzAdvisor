# Release Readiness

## Current Status

Closer, but not release-ready from this loop alone. The previous SDK/runtime destination blocker is resolved, and a full-scheme-equivalent split gate has passed before: `build-for-testing` followed by `test-without-building` on the explicit iPhone 17 simulator ID with parallel testing disabled. The Manual Entry and result-view warning patches compile, and iteration 36's stable non-UI checkpoint passed app build, 58 unit tests, static frame-pattern search, and `git diff --check`. Iteration 32 tried the planned non-parallel focused UI smoke; it reached `Testing started` but hung during Xcode test-log finalization and produced a corrupted unreadable result bundle. Local UI automation is still blocked by XCTest/CoreSimulator Accessibility/finalization failures. Release readiness remains blocked until the UI smoke executes and the result bundle has zero runtime warnings, or the user explicitly accepts the local UI infrastructure blocker as a temporary exception.

Release checklist and metadata mirrors now match the project version/build: `1.1.5` build `8`. TestFlight and App Review remain gated on clean full validation and explicit human approval.

Support, App Store metadata, docs support, feedback-repo support, and TestFlight notes now use the current in-app `Guided Refinement` label instead of the older `Adjust Feel` wording.

## Known Release Assets Present

- App Store metadata
- Privacy policy and support docs
- Release notes
- Screenshot assets and screenshot plan
- Privacy manifest

## Blockers

- Prove the SwiftUI invalid-frame warning is fixed with a UI smoke run that actually executes.
- Rerun the split validation gate and require the UI smoke to execute, zero test failures, and zero runtime warnings.
- Use build plus unit tests as the stable local gate while UI Accessibility infrastructure is unhealthy.
- Decide whether the clean non-UI gate is enough for a temporary commit exception while the local UI Accessibility blocker remains below app code.
- Avoid repeating the same shell-based focused UI retry unless the local Xcode/simulator state changes; the latest non-parallel retry hung during Xcode log finalization.
- Keep release metadata/checklists synced to the current project version/build.
- Confirm signing/TestFlight configuration before upload.

## Manual UI Smoke Handoff

Use this checklist to clear the remaining UI runtime-warning blocker without repeating the unreliable shell-based UI automation path.

### Setup

- Run interactively from local Xcode/simulator, not from shell-based XCTest automation.
- Use the current release candidate app version/build: `1.1.5` build `8`.
- Record Xcode version, simulator device, iOS runtime, date/time, and whether the app was installed fresh or over an existing build.

### Flow To Exercise

1. Launch ForzAdvisor and confirm the app reaches the garage without crash or hang.
2. Start a new tune with Manual Entry.
3. Fill the required car details and exercise the class/drivetrain chip/form layout.
4. Select a discipline and generate a tune.
5. Reach the Tune Result screen and inspect the tune value rows.
6. Open Guided Refinement, choose one feedback option, and confirm an adjustment result/change row appears.
7. Save the tune.
8. Return to the garage and reopen the saved tune.

### Pass Criteria

- The full flow above completes without crash, hang, or navigation break.
- Xcode console/runtime output contains zero instances of `Invalid frame dimension (negative or non-finite)`.
- Xcode console/runtime output contains no new SwiftUI layout/runtime warnings.
- The manual tester records a pass with device, runtime, Xcode version, date/time, and any notable observations.

### Fail Criteria

- The invalid-frame warning appears at any point.
- A new SwiftUI runtime/layout warning appears.
- The app crashes, hangs, cannot complete manual entry, cannot show tune results, cannot produce a Guided Refinement adjustment row, cannot save, or cannot reopen the saved tune.

For a failed run, capture the exact screen, action, console warning text, device/runtime, and whether the warning appeared before or after Guided Refinement.

### Release Gate Decision

- If the checklist passes, rerun the stable non-UI gate, then commit the scoped work.
- If the checklist fails, fix the screen/step identified by the manual run before committing.
- If the checklist cannot be run because local UI infrastructure remains unavailable, the user must explicitly decide whether to allow a temporary commit exception based on the clean non-UI gate.

## Commit-Readiness Inventory

The dirty worktree is intentional factory output, but it should not be committed until the UI runtime-warning gate is cleared or explicitly waived.

### Intended Commit Groups

1. Provider transparency and fallback tracking:
   - Provider metadata models, provider status UI, fallback reasons, copied-tune provenance, Keychain read-failure handling, and provider-mode tests.
   - Representative files: `forzadvisor/Models/TuneClipboardFormatter.swift`, `forzadvisor/Models/TuningDomain+Provider.swift`, `forzadvisor/Services/CompositeTuneProvider.swift`, `forzadvisor/Services/KeychainStore.swift`, `forzadvisor/Services/TuneProviderMode.swift`, `forzadvisor/Views/SettingsView.swift`, `forzadvisorTests/TuneClipboardFormatterTests.swift`, `forzadvisorTests/TuneAPIModelTests.swift`, `forzadvisorTests/OnDeviceTuneProviderTests.swift`.
2. Workflow reliability:
   - OCR import and tune workflow controllers, stale async completion guards, cancellation behavior, isolated UI-test storage, and unit coverage.
   - Representative files: `forzadvisor/ContentView+Workflow.swift`, `forzadvisor/ContentView.swift`, `forzadvisor/Models/OCRConfirmation.swift`, `forzadvisor/Services/OCRService.swift`, `forzadvisor/Services/PhotoOCRImportController.swift`, `forzadvisor/Services/TuneWorkflowController.swift`, `forzadvisor/forzadvisorApp.swift`, `forzadvisorTests/PhotoOCRImportControllerTests.swift`, `forzadvisorTests/TuneWorkflowControllerTests.swift`, `forzadvisorUITests/ForzAdvisorUITests.swift`.
3. Manual entry, UI warning mitigation, and accessibility polish:
   - Manual-entry validation helpers, chip/layout changes, result/refinement row layout changes, Dynamic Type/VoiceOver polish, and manual-entry/OCR fallback coverage.
   - Representative files: `forzadvisor/Models/TuningDomain+ManualEntry.swift`, `forzadvisor/Views/ManualEntryView.swift`, `forzadvisor/Views/TuneResultView.swift`, `forzadvisor/Views/TuneSectionDisclosureView.swift`, `forzadvisorTests/OCRTextParserTests.swift`, `forzadvisorTests/TuningDomainTests.swift`.
4. Code-health splits and formula coverage:
   - Behavior-preserving extraction of domain/provider/feedback/manual-entry/API/driveline helpers plus formula invariant tests.
   - Representative files: `forzadvisor/Models/TuningDomain.swift`, `forzadvisor/Models/TuningDomain+Feedback.swift`, `forzadvisor/Services/TuneAPIModels.swift`, `forzadvisor/Services/TuneAPISections.swift`, `forzadvisor/Services/TuneAPIMerging.swift`, `forzadvisor/Services/TuneAPIRequests.swift`, `forzadvisor/Services/TuningKnowledgeBase.swift`, `forzadvisor/Services/TuningKnowledgeBase+Driveline.swift`, `forzadvisorTests/TuningKnowledgeBaseInvariantTests.swift`.
5. Release/support copy sync:
   - Support, App Store metadata, release checklist, release notes, and docs copy synced to current Guided Refinement wording and version/build state.
   - Representative files: `AppStore/`, `docs/support/index.md`, and `forzadvisorDocs/app-store/`.
6. Agent process memory:
   - `.agent/` planning, audit, implementation, verification, and release-readiness records.
   - Decide separately whether `.agent/` should be committed or kept as local automation memory.

### Exclusions And Risks

- Do not stage or commit DerivedData, local Xcode user state, simulator artifacts, result bundles, credentials, signing assets, or TestFlight/App Store submission artifacts.
- Do not push, upload to TestFlight, submit to App Review, create GitHub issues, or make public marketing claims without explicit approval.
- A single broad commit may be easier to review than splitting by group because several groups overlap in the same Swift files. If splitting, inspect each partial build carefully.
- Commit remains blocked by missing runtime console proof for `Invalid frame dimension (negative or non-finite)`, unless the user explicitly accepts the temporary local UI infrastructure exception.

### Evidence Already Available

- Iteration 36: `xcodebuild -list` passed; full `forzadvisorTests` passed 58/58 with zero runtime warnings; app build passed with no warning output; static risky-frame search was acceptable; `git diff --check` passed; no leftover ForzAdvisor Xcode/simulator processes remained.
- Iteration 37: manual interactive UI smoke checklist added as the exact evidence package for clearing the remaining runtime-warning blocker.

### Missing Evidence

- Manual or otherwise reliable UI-flow console proof that the manual-entry, tune-result, Guided Refinement, save, and reopen path emits zero `Invalid frame dimension (negative or non-finite)` warnings and no new SwiftUI runtime/layout warnings.

## Manual UI Smoke Evidence Log

Status: Not yet run. Fill this section after an interactive local Xcode/simulator run. Do not mark the runtime-warning blocker clear until all pass criteria are satisfied.

### Run Metadata

- Tester:
- Date:
- Local time:
- App version/build: `1.1.5` / `8`
- Xcode version:
- Simulator device:
- iOS runtime:
- Install type: fresh install / upgrade install / unknown

### Flow Result

- Overall result: pass / fail / incomplete
- App launched to garage without crash or hang: yes / no
- Manual Entry completed: yes / no
- Discipline selected: yes / no
- Tune generated and Tune Result screen reached: yes / no
- Guided Refinement adjustment row appeared: yes / no
- Tune saved: yes / no
- Saved tune reopened from garage: yes / no

### Console Evidence

- Search term: `Invalid frame dimension (negative or non-finite)`
- Search result: zero matches / matches found / not checked
- Other SwiftUI/runtime warnings observed: none / list below / not checked
- Warning excerpts:

```text

```

### Warning Location If Failed

- Screen or action where warning appeared:
- Before or after Guided Refinement:
- Reproduction notes:

### Notes And Decision

- Notes/anomalies:
- Release decision: clear blocker / fix app before commit / request temporary exception / inconclusive
- Follow-up owner:
