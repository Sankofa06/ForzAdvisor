# Functional Reliability Audit

## Summary

Core reliability is strong for a small SwiftUI app: default offline generation avoids network dependence, optional provider modes fall back to deterministic formulas, OCR is confirmation-gated, and saved tunes use SwiftData. The main async workflow staleness gap found by the audits has now been addressed for generation, guided adjustment, and OCR/import paths; the next reliability need is UI/manual race smoke once the UI runner launches reliably.

## Provider Integration Inventory

### Offline Formula Provider

- Provider: `LocalSampleTuneProvider`
- Interface: local async `TuneProvider`
- Payload: `TuneRequest`
- Response: `TuneResult` or `TuneAdjustmentResult`
- Auth: none
- Timeout/retry: none needed
- Failure modes: formula/domain bugs, invalid input
- Risk: low
- Recommended fix: initial matrix invariant coverage is complete; continue adding deeper source-backed edge cases for class, weight, and drivetrain combinations.

### Anthropic API Provider

- Provider: Anthropic Messages API
- Endpoint: `https://api.anthropic.com/v1/messages`
- Payload: JSON encoded request or adjustment payload inside a single user message.
- Response shape: text block containing JSON decoded into `TuneAPIResponse`.
- Auth: `x-api-key` loaded from Keychain.
- Timeout/retry: 10 second URLRequest timeout; no explicit retry.
- Failure modes: missing key, HTTP status, malformed text, decode failure, model deprecation.
- Current implementation risk: medium; fallback prevents user dead-end, but silent fallback can hide configuration problems.
- Recommended fix: future provider status surfaced in UI; this loop adds adjustment fallback test coverage.

### On-Device Foundation Model Provider

- Provider: Apple Foundation Models when available.
- Interface: `LanguageModelSession.streamResponse(...)`.
- Payload: compact prompt with local baseline.
- Response shape: guided generated `OnDeviceTuneResponse`.
- Auth: none.
- Timeout/retry: no explicit timeout.
- Failure modes: framework unavailable, model not ready, no complete response, streamed partial mismatch.
- Current implementation risk: medium due platform availability.
- Recommended fix: preserve fallback; future loop could add cancellation/status UX.

## Reliability Findings

- Async workflow tasks can complete stale.
  - Evidence: subagent audits found untracked `Task {}` blocks around generation, guided adjustment, and OCR/import completion.
  - Files: `ContentView+Workflow.swift`, `NewTuneStartView.swift`, `TuneResultView.swift`
  - Suggested change: completed for generation, guided adjustment, and OCR/photo import with operation IDs, task cancellation, stale guards, and cancellation-aware provider fallback.
  - Safe to implement autonomously: completed; needs UI/manual race smoke when runner is healthy.

- UI test runner launch currently blocks full scheme validation.
  - Evidence: full scheme and UI-only test both fail before app assertions because `forzadvisorUITests-Runner` is denied launch by the simulator.
  - Files: environment, `forzadvisorUITests/ForzAdvisorUITests.swift`
  - Suggested change: diagnose simulator/Xcode beta UI-test runner state; keep unit tests as a separate green gate until UI runner is fixed.
  - Safe to implement autonomously: partially; avoid destructive simulator resets without explicit approval.

- Adjustment fallback has less test coverage than generation fallback.
  - Evidence: tests cover API generation fallback and on-device generation fallback, but not API/on-device adjustment fallback.
  - Files: `TuneAPIModelTests.swift`, `OnDeviceTuneProviderTests.swift`
  - Suggested change: add focused tests for adjustment fallback.
  - Safe to implement autonomously: completed; unit tests pass.

- Keychain read failures are collapsed into missing-key state.
  - Evidence: `hasConfiguredAPIKey()` and Settings use `try?`/fallback false for read failures.
  - Files: `TuneAPIClient.swift`, `SettingsView.swift`
  - Suggested change: distinguish missing key from read failure in Settings/provider readiness.
  - Safe to implement autonomously: yes, with focused tests.
