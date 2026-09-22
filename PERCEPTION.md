# Current Perception

This file is the replace-in-place record for one active goal. It describes current intent and evidence; it is not authority, history, or durable memory.

## Active goal

- Status: active
- Refreshed: 2026-09-22
- Goal: Deliver the bounded ForzAdvisor improvements to an internal TestFlight build for owner playtesting.
- Success: exact verified source reaches an App Store Connect `VALID` build associated with the configured Internal group; owner then completes the live play plan.
- Constraints: repository rules remain controlling; external effects require separate authority. Implementation is complete and release candidates 79, 80, 81, 82, 83, 84, 85, and 86 are retained as blocked evidence; no upload receipt exists. The owner authorized signing repair; the active ForzAdvisor App Store profile is installed on the runner. The current App Store version 1.41.1 is closed for new build submissions, so a new marketing-version identity is required before another candidate.

## Current evidence

- Successes: five independent audits, synthesis, bounded implementation, fresh review, local release tests, ReleaseVerify for prior exact candidates, and local Release build 82 with warnings treated as errors all completed; the runner now reaches the app compile after signing repair.
- Failures: stable-runner archive failed before receipt for candidates 79, 80, 81, 82, 83, 84, and 85; ASC read-only reconciliation found zero matching builds for each. Candidate 82 exposed a FoundationModels macro API mismatch; candidate 83’s signed archive passed; candidate 84 exposed macOS contract drift; candidate 85 exposed the missing internal-TestFlight-only export declaration; candidate 86 reached Apple upload but Apple rejected the closed 1.41.1 pre-release train.
- Open hypotheses: after the owner selects the next App Store marketing version, the same verified source can be delivered as a fresh internal TestFlight candidate.
- Active signals: signing repair, internal-only export policy, and build 86 upload evidence are complete; next work is blocked only on the new marketing-version decision and corresponding App Store version.
- Next decision: owner selects the next marketing version before another version/build identity is created.

## Refresh contract

- Keep one active goal and one current definition of success.
- Refresh after a material decision, success, failure, constraint change, or new evidence.
- Every observation needs a source/date or must be labeled as a hypothesis.
- Remove resolved signals instead of accumulating a historical log.
- Clear the active goal when completed; durable lessons are promoted separately through `MEMORY.md`.
- Never store secrets, raw transcripts, hidden reasoning, sensitive personal information, or private infrastructure identifiers.
