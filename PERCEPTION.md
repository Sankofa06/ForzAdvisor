# Current Perception

This file is the replace-in-place record for one active goal. It describes current intent and evidence; it is not authority, history, or durable memory.

## Active goal

- Status: active
- Refreshed: 2026-09-22
- Goal: Deliver the bounded ForzAdvisor improvements to an internal TestFlight build for owner playtesting.
- Success: exact verified source reaches an App Store Connect `VALID` build associated with the configured Internal group; owner then completes the live play plan.
- Constraints: repository rules remain controlling; external effects require separate authority. Implementation is complete and release candidates 79, 80, 81, and 82 are retained as blocked evidence; no upload receipt exists. The owner authorized signing repair; the active ForzAdvisor App Store profile is installed on the runner, and build 83 is the next exact candidate.

## Current evidence

- Successes: five independent audits, synthesis, bounded implementation, fresh review, local release tests, ReleaseVerify for prior exact candidates, and local Release build 82 with warnings treated as errors all completed; the runner now reaches the app compile after signing repair.
- Failures: stable-runner archive failed before receipt for candidates 79, 80, 81, and 82; ASC read-only reconciliation found zero matching builds for each. Candidate 82 exposed a FoundationModels macro API mismatch on the pinned Xcode 26.3 runner.
- Open hypotheses: removing the newer `@Generable` macro argument will let the pinned Xcode 26.3 runner compile the exact app while preserving structured generation.
- Active signals: build 83 source and signing contract are ready for exact-tag verification and stable-runner delivery after the compatibility fix.
- Next decision: verify, archive, upload, wait for `VALID`, and associate only the configured Internal TestFlight group.

## Refresh contract

- Keep one active goal and one current definition of success.
- Refresh after a material decision, success, failure, constraint change, or new evidence.
- Every observation needs a source/date or must be labeled as a hypothesis.
- Remove resolved signals instead of accumulating a historical log.
- Clear the active goal when completed; durable lessons are promoted separately through `MEMORY.md`.
- Never store secrets, raw transcripts, hidden reasoning, sensitive personal information, or private infrastructure identifiers.
