# ForzAdvisor Release Checklist

Last updated: 2026-08-30

Canonical release configuration: `AppStore/release-config.json`

Automation guide: `AppStore/release-automation.md`

Privacy attestation: `AppStore/privacy-label.md`

Historical build-78 evidence: `AppStore/releases/1.41.1.md`

## Historical 1.41.1 build-78 record

The following completed facts describe the August 2026 build-78 repair. They are
historical evidence, not instructions for the current release path:

- [x] Marketing version was `1.41.1` and source build was `78`.
- [x] Build `77` was rejected with `ITMS-90111`; processed build `78` became
  `VALID` and App Store eligible.
- [x] GitHub `Release Verify` proved the exact build-78 tagged commit and passed
  the complete `ReleaseVerify` plan.
- [x] The then-current guarded GitHub candidate workflow archived and uploaded
  build `78` on stable hosted macOS, and the release record captured its run,
  toolchain, archive provenance, processing state, and App Store identifiers.
- [x] Build `78` was attached to App Store version `1.41.1`, explicitly approved
  for submission, and reached `WAITING_FOR_REVIEW`.

Do not rewrite this record to claim that the current SSH runner produced build
`78`. The historical workflow has been removed from the current tree; Git
history, Actions records, and `AppStore/releases/1.41.1.md` preserve its evidence.

## Current candidate definition

- [ ] Intended diff is isolated and the canonical repository, remote, branch,
  immutable tag, and exact commit are recorded.
- [ ] App, bundle, team, platform, marketing version, new build number, App Store
  Connect app, and configured `Internal` TestFlight group resolve unambiguously.
- [ ] Release config declares logical profile `stable-xcode-26.3-intel` and only
  public stable-runner toolchain/build facts; no endpoint or credential data is
  stored in the repository.
- [ ] Price, privacy attestation, content rights, age rating, review contact,
  export compliance, metadata, screenshots, public URLs, and release policy are
  current.
- [ ] App Review submission remains a separate explicit human action.

## Engineering verification gate

- [ ] Run `scripts/release preflight --ref main` from the canonical checkout;
  reserve the no-argument default for a checkout already at configured `release_ref`.
- [ ] Run focused tests for every release-automation or app change.
- [ ] Run a clean Release build with zero source warnings and errors.
- [ ] Run `ReleaseVerify.xctestplan` with zero failures, skips, or expected failures.
- [ ] Exercise changed user-visible flows, inspect logs, and retain screenshots or recordings.
- [ ] Inspect the intended diff and run `git diff --check` plus a credential/secret scan.
- [ ] Commit and push the viable state, create an immutable release tag, and rerun
  `scripts/release preflight --ref TAG`.

## GitHub verification-only gate

- [ ] Dispatch `.github/workflows/release-verify.yml` for the immutable tag and exact SHA.
- [ ] Confirm the run proves the tag, SHA, clean checkout, pinned verification
  toolchain, repository preflight, automation tests, warnings-as-errors, and a
  nonempty xcresult with zero failures, skips, or expected failures.
- [ ] Record the successful GitHub run ID and exact source commit.
- [ ] Confirm no GitHub workflow can access release credentials, archive, export,
  or upload an Apple candidate.

## Stable SSH candidate gate

- [ ] Invoke the global `release-apple-app` skill and rerun the shared SSH
  preflight for `stable-xcode-26.3-intel`.
- [ ] Report the exact app, platform, version/build, commit, destination group,
  and correction path before candidate work.
- [ ] Start `scripts/release candidate-start` with the exact tag, successful
  GitHub Verify run ID, explicit upload flag, and bound confirmation token.
- [ ] Confirm the coordinator rejects moved refs, mismatched verification,
  existing matching builds, identity drift, toolchain drift, missing signing,
  and ambiguous App Store state before upload.
- [ ] Require archive identity, architecture, codesigning, embedded-profile,
  Xcode-build, macOS-build, and warning-policy checks to pass.
- [ ] Wait for the exact uploaded build to reach `VALID`; transport acceptance is
  not sufficient.
- [ ] Confirm App Store eligibility and export compliance.
- [ ] Associate only the exact valid build with the configured `Internal`
  TestFlight group; do not stage the App Store version yet.
- [ ] Record the non-secret candidate receipt and report
  `TestFlight — human verification pending`.
- [ ] If interrupted at `github_verified`, resume only with `--upload` and the
  same bound confirmation. If `upload_start_intent` exists, use read-only
  `candidate-reconcile`, record `candidate-block --notes`, never retransmit, and
  require a different version/build for the next candidate.

## Human live-verification gate

- [ ] Generate a numbered plan from `~/.codex/templates/apple-live-test-plan.md`.
- [ ] Identify build, commit, device/OS, setup, changed-behavior scenarios,
  regression scenarios, Expected results, requested evidence, and stop conditions.
- [ ] Collect Actual, `PASS | FAIL | BLOCKED`, evidence, and notes for every scenario.
- [ ] Record one overall result with `scripts/release human-result`:
  `ACCEPT`, `NEEDS_FIXES`, or `BLOCKED`; retain evidence paths or summaries in
  required `--notes` and `--evidence` values.
- [ ] Confirm the first human result is immutable; an idempotent repeat must use
  exactly the same result, notes, and evidence.
- [ ] For `NEEDS_FIXES` or `BLOCKED`, stop staging and App Review, preserve the
  failed evidence, create a new commit/build number, and rerun invalidated gates.

## Staging gate after `ACCEPT`

- [ ] Confirm the stored human result is `ACCEPT` for the exact TestFlight build.
- [ ] Run `scripts/release asc-preflight --json` immediately before staging.
- [ ] Revalidate the exact build, metadata, price schedule, public URLs, privacy,
  content rights, age rating, review contact, export compliance, release timing,
  internal-group association, and review-draft consistency.
- [ ] Run `scripts/release stage` and confirm only the exact accepted build is selected.

## Explicit App Review gate

- [ ] Report the exact App Store build and staged candidate state to the user.
- [ ] Obtain explicit approval immediately before App Review submission.
- [ ] Invoke the guarded submission command only after both acknowledgement
  flags and the app/bundle/version/build/commit/submission-bound confirmation token.
- [ ] Confirm the returned review state and write a new permanent release record.

## Safety invariants

- Never store credentials, JWTs, private keys, provisioning profiles, private
  runner addresses, usernames, keychain paths, or secret values in the repository.
- Never archive or upload before GitHub Verify succeeds for the same immutable tag and SHA.
- Never use GitHub Actions, local beta Xcode, Xcode Cloud, or another runner as a
  release fallback without an explicit policy change and fresh verification.
- Never infer readiness from upload transport; require the exact build to be `VALID`.
- Never stage before recorded human `ACCEPT` for the exact build.
- Never overwrite `NEEDS_FIXES`, `BLOCKED`, or ambiguous-upload evidence; archive
  terminal state and use a different version/build identity.
- Never infer App Review approval from build, test, upload, TestFlight association,
  live acceptance, stage, or prepare requests.
- Never infer the observed App Store build from `CURRENT_PROJECT_VERSION`.
- Never hide or erase failed candidate evidence without separate authority.
- Never re-add roster resources, generators, or catalog claims without documented
  redistribution rights and a new legal review.
