# Code Health

## Findings

### Completed: outdated first-run and file header copy

- Evidence: earlier audit found `GarageHomeView` empty-state and file-header wording from the manual-only/OCR-pending phase.
- Files involved: `GarageHomeView.swift`, `ManualEntryView.swift`
- Benefit: user-visible clarity and lower maintainer confusion.
- Risk: low.
- Suggested change: completed with copy-only/source-comment updates.
- Verification: implemented; app build and unit tests pass. UI smoke remains blocked by runner launch failure.
- Safe to implement autonomously: completed.

### Async workflows need stale-completion guards

- Evidence: generation, adjustment, and OCR/import use untracked async work that can mutate navigation or processing state after the user leaves, retries, or starts another flow.
- Files involved: `ContentView+Workflow.swift`, `NewTuneStartView.swift`, `TuneResultView.swift`
- Benefit: prevents surprising navigation and stale OCR/import results.
- Risk: medium.
- Suggested change: completed with operation identity and task cancellation for OCR/import, generation, and guided adjustment.
- Verification: app build and unit tests pass; manual/UI race smoke remains blocked by runner launch failure.
- Safe to implement autonomously: completed.

### Shared car-entry form duplication

- Evidence: manual entry and saved-tune editing duplicate much of the car/performance form structure and optional-number text helpers.
- Files involved: `ManualEntryView.swift`, `SavedTuneEditView.swift`, `OCRConfirmationView.swift`
- Benefit: easier future validation and copy consistency.
- Risk: medium.
- Suggested change: extract shared row helpers only when touching form behavior.
- Verification: build/tests and manual form smoke.
- Safe to implement autonomously: later, not before the reliability guard.

### Completed: result-row accessibility polish

- Evidence: tune setting rows and adjustment change rows previously used dense horizontal layouts and relied on nested text/icon inference for VoiceOver.
- Files involved: `TuneSectionDisclosureView.swift`, `TuneResultView.swift`
- Benefit: better large Dynamic Type readability and clearer VoiceOver output for copyable tune settings and guided-adjustment changes.
- Risk: low-medium; rows grow taller at accessibility sizes.
- Suggested change: completed with accessibility-size vertical layouts, explicit labels/values/hints, and copy announcements.
- Verification: app build and focused unit tests pass. Manual VoiceOver/Dynamic Type smoke is still pending because simulator accessibility services currently time out during UI tests.
- Safe to implement autonomously: completed.

### Large but bounded files

- Evidence: several files are above 300 lines: `TuneResultView.swift`, `ContentView+Workflow.swift`, and `ForzaOCRKnowledgeBase.swift`. `TuningKnowledgeBase.swift` was reduced from 333 to 278 lines by moving driveline formulas into `TuningKnowledgeBase+Driveline.swift`; `TuningDomain.swift` was reduced from 581 to 225 lines by moving manual-entry draft helpers into `TuningDomain+ManualEntry.swift`, guided-refinement feedback types into `TuningDomain+Feedback.swift`, and provider provenance helpers into `TuningDomain+Provider.swift`; `TuneAPISections.swift` was reduced from 321 to 275 lines by moving partial-response merge helpers into `TuneAPIMerging.swift`; `TuneAPIModels.swift` was reduced from 311 to 246 lines by moving request payload DTOs into `TuneAPIRequests.swift`.
- Files involved: listed above, plus completed split files `TuningKnowledgeBase.swift`, `TuningKnowledgeBase+Driveline.swift`, `TuningDomain.swift`, `TuningDomain+ManualEntry.swift`, `TuningDomain+Feedback.swift`, `TuningDomain+Provider.swift`, `TuneAPISections.swift`, `TuneAPIMerging.swift`, `TuneAPIModels.swift`, and `TuneAPIRequests.swift`.
- Benefit: future maintainability.
- Risk: medium if refactored broadly without behavior need.
- Suggested change: defer broad splitting; split only when touching related behavior. Completed for `TuningKnowledgeBase.swift`, completed for `TuningDomain.swift` with focused manual-entry, feedback, and provider provenance splits, completed for `TuneAPISections.swift` with a focused partial-merge helper split, and completed for `TuneAPIModels.swift` with a focused request DTO split.
- Verification: formula invariant tests, focused manual-entry/OCR fallback tests, focused feedback tests, focused provider provenance tests, focused API merge tests, focused API model tests, full unit target, and app build pass for completed splits. Iteration 36 restored the stable non-UI gate after the earlier usage-limit blocker.
- Safe to implement autonomously: only when the split is mechanical and covered by focused tests.

### Provider fallback behavior is simple and repeated

- Evidence: `CompositeTuneProvider` repeats guard/do/catch fallback logic across generation and adjustment.
- Files involved: `CompositeTuneProvider.swift`
- Benefit: smaller provider code.
- Risk: low-medium; generic async abstraction could reduce readability.
- Suggested change: defer until coverage is stronger.
- Verification: provider tests.
- Safe to implement autonomously: later, not now.
