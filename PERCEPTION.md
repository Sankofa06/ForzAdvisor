# Current Perception

This file is the replace-in-place record for one active goal. It describes current intent and evidence; it is not authority, history, or durable memory.

## Active goal

- Status: active
- Refreshed: 2026-10-08
- Goal: Complete the already-authorized ForzAdvisor 1.41.2 internal TestFlight build 89 through the pinned stable runner.
- Authority: Existing owner authorization covers the internal TestFlight upload and association with the configured Internal group. App Review, public release, new testers, new credentials, and broader access changes remain unauthorized.
- Source: Local main candidate for intended immutable tag release-1.41.2-testflight-89-3; publish only after independent review and exact-tag verification.
- Preservation: Keep app source and unrelated work intact; use only task-owned runner resources and do not disturb existing simulators or jobs.

## Current evidence

- Candidate release-1.41.2-testflight-89-2 at a58e980f549f6cc5b133e92361ab36c1c92b2359 was pushed to main and its immutable tag. The exact GitHub run 37854497819 was canceled while the full UI plan was running after a signing-helper defect was confirmed; its final test summary and evidence-upload steps were skipped. It is not a passing release gate.
- Earlier tag release-1.41.2-testflight-89-1 at 924546acd969f1044cfa93caeca44609b1574640 finished run 37852926045 with one UI failure, testManualGameSelectionSurvivesDisciplineRoundTrip, at XCUIElementTestSupport.swift:99 (expected Mia, received Mia). It is stale and is not evidence for the corrected helper or build 89.
- Exact-source Pro Release build for commit a58e980f549f6cc5b133e92361ab36c1c92b2359 passed with warnings-as-errors. Its separate existing-profile signing validation failed before archive/upload because keychain/password jq queries parsed the metadata pathname as JSON input. The Pro archive lock was absent afterward; the retained failed task is ForzAdvisor-a58e980f549f-u2tm6I, with no credential directory.
- A read-only check of the live build-88 coordinator state reports schema 2, phase human_blocked, build 88, tag release-1.41.2-testflight-88-3, mode 0600, and no top-level build-88 release receipt. Its nested prior-build receipt remains part of the state payload; the rollover regression test verifies the blocked state and nested receipt are archived unchanged. The live state must be archived, not rewritten, when build 89 starts.
- Two blind read-only reviews of the a58 snapshot passed the coordinator terminal rollover, upload-intent, and configured Internal-group controls. The signing review identified path-confinement and cleanup edge cases; the corrected helper validates the private metadata JSON, confines its metadata/keychain/password files under non-symlink trust roots, and only locks a keychain after this helper successfully unlocked it, without changing credential files or keychain ACLs.
- Portable fixtures cover valid JSON loading, malformed JSON, independently escaped keychain/password paths, and symlinked metadata/keychain trust roots. The correction must pass on the final committed source before tag publication.
- Prior native evidence: the candidate app and UI-test file hashes match the saved receipts; the result bundle itself is not a commit-stamped attestation. Preserve the XcodeBuildMCP discovery count mismatch (513 discovered vs 640 executed), seven invalid-frame runtime warnings in the full run, two in focused evidence, and the earlier first-run UI failure. Do not describe those as cleared by the passing retry.
- Build 89 has no upload-start intent. Do not persist the coordinator upload intent until local portable coverage, the fresh exact-source Release Verify run, fresh Pro preflight, exact-source Pro build, and existing-profile signing validation pass.
- Fresh read-only Pro lane preflight passed: pinned toolchain and existing signing metadata match, at least 15 GiB free, no active xcodebuild/xctest/Fabricon work, and no archive lock. No simulator was booted; inventory was left unchanged. Pro remains reserved for the pending ForzAdvisor source-bound build, signing validation, and archive, and must be rechecked before native work.
- The latest exact-source review identified lexical workspace-root validation and lock release after cleanup errors. The correction now uses an exact-commit allocator to canonicalize the configured root under the real system temp directory, reject symlinked path components before source transfer, revalidate the task after transfer, and retain the archive lock on any sensitive cleanup failure; portable tests cover these paths.

## Next gates

1. Re-run local helper syntax and portable regression tests, then inspect the final diff and exact source.
2. Have a fresh independent reviewer verify the committed candidate, exact source bundle, and manifest before publication.
3. After review, push main and immutable tag release-1.41.2-testflight-89-3; dispatch one final exact-tag Release Verify run.
4. After that run passes, rerun shared Pro preflight, exact-source warnings-as-errors build, and signing smoke serially. Then start the authorized archive/export/upload through the repository coordinator.
5. Wait for build 89 to become VALID and verify association only with the existing Internal group. Commit and push the final release receipt; do not stage or submit for App Review.
