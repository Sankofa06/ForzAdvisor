# Current Perception

This file is the replace-in-place record for one active goal. It describes current intent and evidence; it is not authority, history, or durable memory.

## Active goal

- Status: active
- Refreshed: 2026-09-22
- Goal: Deliver the bounded ForzAdvisor improvements to an internal TestFlight build for owner playtesting.
- Success: exact verified source reaches an App Store Connect `VALID` build associated with the configured Internal group; owner then completes the live play plan.
- Constraints: repository rules remain controlling; external effects require separate authority. Implementation is complete and release candidates 79, 80, and 81 are retained as blocked evidence; no upload receipt exists. The owner authorized signing repair; an active ForzAdvisor App Store profile now exists on the runner, and build 82 is the next exact candidate.

## Current evidence

- Successes: five independent audits, synthesis, bounded implementation, fresh review, local release tests, ReleaseVerify for prior exact candidates, and local Release build 82 with warnings treated as errors all completed.
- Failures: stable-runner archive failed before receipt for candidates 79, 80, and 81; ASC read-only reconciliation found zero matching builds for each.
- Open hypotheses: the newly installed profile and private manual signing map will permit the build 82 stable archive and upload.
- Active signals: build 82 source and signing contract are ready for exact-tag verification and stable-runner delivery.
- Next decision: verify, archive, upload, wait for `VALID`, and associate only the configured Internal TestFlight group.

## Refresh contract

- Keep one active goal and one current definition of success.
- Refresh after a material decision, success, failure, constraint change, or new evidence.
- Every observation needs a source/date or must be labeled as a hypothesis.
- Remove resolved signals instead of accumulating a historical log.
- Clear the active goal when completed; durable lessons are promoted separately through `MEMORY.md`.
- Never store secrets, raw transcripts, hidden reasoning, sensitive personal information, or private infrastructure identifiers.
