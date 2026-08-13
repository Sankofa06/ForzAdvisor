# Findings

## Highest-Value Candidates

1. Guard async workflow completion.
   - Impact: high
   - Risk: medium
   - Effort: medium
   - Release value: high
   - Evidence: subagent audits found untracked `Task {}` workflows can update navigation or OCR state after the user leaves, retries, or starts another flow.

2. Resolve UI test runner launch failure.
   - Impact: high
   - Risk: environment-dependent
   - Effort: unknown
   - Release value: high
   - Evidence: app build and unit tests pass, but full scheme/UI test fails because `forzadvisorUITests-Runner` is denied launch by the simulator.

3. Replace or gate manual-entry starter sample data. Completed in iteration 11.
   - Impact: high
   - Risk: medium
   - Effort: medium
   - Release value: high
   - Evidence: manual entry now uses `ManualEntryDraft.empty`; OCR fallback preserves parsed values and leaves missing required values blank.

4. Surface actual provider provenance/fallback on results. Completed in iteration 12.
   - Impact: medium-high
   - Risk: medium
   - Effort: medium
   - Release value: high
   - Evidence: `TuneResult.providerInfo` records requested/actual provider and fallback reason; `TuneResultView` shows provider status; focused unit tests pass.

5. Tune result accessibility polish.
   - Impact: medium
   - Risk: low-medium
   - Effort: medium
   - Release value: medium
   - Evidence: tune value rows and adjustment rows may be cramped under large Dynamic Type and lack explicit copy/action accessibility wording.

## Earlier Candidates

1. First-run clarity and adjustment fallback coverage.
   - Impact: medium
   - Risk: low
   - Effort: low
   - Release value: medium

2. Provider fallback transparency in the UI.
   - Impact: medium-high
   - Risk: medium
   - Effort: medium
   - Release value: high

3. Split large files around current ownership boundaries.
   - Impact: medium
   - Risk: medium
   - Effort: medium
   - Release value: low

4. Rerun clean build/tests and prepare TestFlight.
   - Impact: high
   - Risk: environment/signing dependent
   - Effort: unknown until Xcode license is resolved
   - Release value: high

## Chosen Slice

First-run clarity and adjustment fallback coverage.

## Iteration 2 Chosen Slice

Provider status transparency in Settings.

## Iteration 8 Chosen Slice

Validation checkpoint and factory audit intake.
