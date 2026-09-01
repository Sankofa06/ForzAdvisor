# ForzAdvisor Release Automation

`scripts/release` is the repository-owned release coordinator. It turns the
non-secret declarations in `AppStore/release-config.json` into deterministic
checks and a fail-closed delivery state machine. Signing material, App Store
Connect credentials, private runner connection details, and personal review
contact information remain outside the repository.

The current authority split is deliberate:

| Concern | Authority |
|---|---|
| Local discovery, focused tests, and simulator evidence | XcodeBuildMCP and repository checks |
| Exact-revision fresh-machine verification | GitHub Actions `Release Verify` |
| Archive, export, and upload | Logical SSH profile `stable-xcode-26.3-intel` |
| Processing and internal TestFlight association | Repository coordinator after the exact build is `VALID` |
| Live acceptance | Owner response against the generated numbered test plan |
| App Store version staging | Repository coordinator after recorded `ACCEPT` |
| App Review submission | Separate explicit human approval and guarded command |

GitHub Actions is verification-only. No current workflow can receive release
credentials or exercise archive, export, or upload authority.
The beta candidate must be produced from the exact verified commit by the
configured stable SSH runner; never archive or upload with the beta Xcode on the
developer Mac.

## Source of Truth

`AppStore/release-config.json` records non-secret release facts:

- App Store Connect app, bundle, team, version, review-draft, and review-item identifiers
- canonical GitHub checkout, remote, and immutable release ref
- marketing version `1.41.1`, source build `78`, and current App Store build `78`
- Free pricing, explicit-human-approval submission policy, and `AFTER_APPROVAL` release timing
- published privacy-label declaration and human attestation date
- content-rights, age-rating, review-contact, and export-compliance attestations
- public marketing, privacy, and support URLs
- Xcode project, schemes, complete `ReleaseVerify` plan, and privacy manifest
- GitHub verification workflow and its public toolchain facts
- the logical stable-runner profile, public pinned toolchain facts, project,
  scheme, generic iOS destination, signing mode, and warning policy
- intended internal TestFlight group
- metadata limits and exact screenshot order
- retained legacy Xcode Cloud identifiers, which are historical and are not the
  active archive or upload path

The source build and observed App Store Connect build are different facts even
when their values match. Never infer an uploaded build number from
`CURRENT_PROJECT_VERSION`. Candidate monitoring must select exactly one build
for this app, platform, marketing version, and audience, then record the build
returned by App Store Connect.

## Repository Preflight

From the canonical checkout, run:

```sh
scripts/release preflight --ref main
```

This read-only command fails unless the canonical repository, remote, source
identity, project settings, shared schemes, complete test plan, metadata,
screenshots, privacy declaration, pricing, public URLs, and release attestations
match the configuration. It does not run app tests, contact the release runner,
allocate a build number, archive, upload, associate testers, stage a version, or
submit App Review.

Omitting `--ref` uses the configured `repository.release_ref`. That default is
appropriate only when the checkout is already at that configured immutable
release ref; it is intentionally not a shortcut for validating current `main`.

For the immutable pushed release tag at `HEAD`, run:

```sh
scripts/release preflight --ref RELEASE_TAG
```

There is no dirty-tree bypass. A candidate must come from a clean, pushed,
immutable tag whose peeled commit is the exact intended source.

For deterministic tests or disconnected validation, URL observations may be
injected explicitly:

```sh
scripts/release preflight --url-fixture /absolute/path/url-results.json
```

Fixture results are test inputs, not current deployment evidence. Use live URL
checks for an actual candidate.

## Current TestFlight Candidate Route

### 1. Complete engineering verification

Before immutable handoff:

1. Run focused tests for the change.
2. Run a clean Release build with source warnings treated as failures.
3. Run the complete local `ReleaseVerify` plan with no failures, skips, or
   expected failures.
4. Exercise changed user-visible flows in Simulator or on a device, inspect
   logs, and retain screenshots or recordings.
5. Review the intended diff, run `git diff --check`, and perform the repository
   secret scan.
6. Commit and push only the viable release write set, create an immutable
   release tag, and rerun repository preflight for that tag.

All evidence must identify the same commit. A material source change invalidates
affected downstream evidence and requires a new commit and build number.

### 2. Run GitHub exact-revision verification

Dispatch and monitor the verification-only workflow:

```sh
gh workflow run .github/workflows/release-verify.yml \
  --ref RELEASE_TAG \
  -f release_ref=RELEASE_TAG \
  -f release_sha=EXACT_40_CHARACTER_COMMIT_SHA
gh run list --workflow .github/workflows/release-verify.yml
gh run watch RUN_ID --exit-status
```

The workflow-dispatch ref, `release_ref` input, run `head_branch`, immutable tag,
and exact SHA must all identify the same candidate. The successful run must also
prove a clean checkout, the expected GitHub verification toolchain, repository
preflight, release automation tests, warnings-as-errors, and an xcresult summary
with a nonzero test count and zero failures, skips, or expected failures. Record
its run ID. A successful GitHub run authorizes no archive or upload by itself.

### 3. Start the stable-runner candidate

Immediately before candidate work, invoke the global `release-apple-app` skill,
report the exact app, platform, version/build, commit, destination group, and
correction path, and rerun the shared SSH preflight for logical profile
`stable-xcode-26.3-intel`.

Start only after the exact GitHub run is successful:

```sh
scripts/release candidate-start \
  --ref RELEASE_TAG \
  --verify-run-id RUN_ID \
  --upload \
  --confirm-upload BOUND_CONFIRMATION_TOKEN
```

The confirmation token binds the platform, App Store app ID, bundle ID,
marketing version, build number, exact commit, and upload intent. Construct it
from the already reported identity using this exact non-secret format:

```text
UPLOAD:IOS:APP_ID:BUNDLE_ID:MARKETING_VERSION:BUILD_NUMBER:EXACT_40_CHARACTER_COMMIT_SHA
```

The coordinator must reject a moved tag, mismatched GitHub run, dirty or
unpushed source, configuration not read from the exact commit, runner-profile
or toolchain drift, an existing matching App Store build, missing signing
prerequisites, or an ambiguous identity before upload.

The shared runner route transfers the exact commit to a task-owned remote
directory, archives with the configured project/scheme/destination, treats
source warnings as failures, verifies bundle/version/build/architectures,
codesigning and embedded profiles, Xcode build, and macOS build, then exports and
uploads from that same task. Private endpoint, keychain, signing, and credential
details must never enter repository files or logs.

If interruption occurs while the state is only `github_verified`, resume with
the same explicit upload authorization and exact token:

```sh
scripts/release candidate-status
scripts/release candidate-resume \
  --upload \
  --confirm-upload BOUND_CONFIRMATION_TOKEN
```

If `upload_start_intent` was persisted, never resume or retransmit. Reconcile
the exact App Store build read-only, then retain the outcome as blocked with a
specific evidence note:

```sh
scripts/release candidate-reconcile --json
scripts/release candidate-block --notes "AMBIGUOUS_UPLOAD_EVIDENCE_AND_NEXT_STEP"
```

The blocked state is immutable evidence. A later candidate may roll over only
after the configuration uses a different marketing version or build number; the
old state is archived mode `0600` outside the repository before the new state is
created.

Upload transport success is not readiness. The coordinator must wait for the
exact new build to become `VALID`, verify App Store eligibility and export
compliance, associate it only with the configured `Internal` TestFlight group,
and report:

```text
TestFlight — human verification pending
```

Internal TestFlight association is not App Store version staging and cannot
submit the app for review.

### 4. Complete human live verification

Generate the numbered plan from
`~/.codex/templates/apple-live-test-plan.md`. It must identify the exact build,
commit, device/OS setup, changed-behavior scenarios, regression scenarios,
Expected results, evidence requests, and stop conditions.

For every scenario the owner supplies:

```text
Actual:
Result: PASS | FAIL | BLOCKED
Evidence:
Notes:
```

Record the overall result explicitly:

```sh
scripts/release human-result --result ACCEPT --notes "SUMMARY" --evidence "EVIDENCE_PATHS"
scripts/release human-result --result NEEDS_FIXES --notes "SUMMARY" --evidence "EVIDENCE_PATHS"
scripts/release human-result --result BLOCKED --notes "SUMMARY" --evidence "EVIDENCE_PATHS"
```

The first result is immutable and may only be repeated idempotently with the
same notes and evidence. `NEEDS_FIXES` or `BLOCKED` stops staging and App Review.
Preserve the failed build and commit identity, correct the issue with a new
commit and build number, and rerun every invalidated gate. Do not hide, expire,
remove, or reassign the failed build without separate authority.

### 5. Stage only after `ACCEPT`

After human acceptance, rerun the read-only App Store candidate preflight, then
stage the exact accepted build:

```sh
scripts/release asc-preflight --json
scripts/release stage
```

Staging must fail closed unless the stored candidate is `VALID`, belongs to the
configured app/version/platform, is associated with the configured internal
group, and has a recorded human `ACCEPT`. It must also revalidate pricing,
metadata, screenshots, privacy, content rights, age rating, review contact,
export compliance, release timing, and review-draft consistency.

### 6. Submit App Review only after separate approval

Report the exact staged build and obtain explicit user approval immediately
before submission. Construct the non-secret confirmation token from the exact
staged state:

```text
SUBMIT:IOS:APP_ID:BUNDLE_ID:MARKETING_VERSION:BUILD_NUMBER:EXACT_40_CHARACTER_COMMIT_SHA:REVIEW_SUBMISSION_ID
```

Only then may the guarded command run:

```sh
scripts/release submit \
  --submit \
  --acknowledge-irreversible-app-review-submission \
  --confirm-submit BOUND_SUBMISSION_TOKEN
```

Candidate creation, upload, TestFlight association, live acceptance, and staging
never imply App Review approval or public release.

Immediately before the PATCH, the coordinator revalidates the stored config
fingerprint, exact selected build and TestFlight association, App Store version,
sole configured review item, metadata, and draft identity. Terminal failed or
submitted candidates are archived outside the repository before a different
version/build identity may start; history is never silently overwritten.

## Historical Xcode Cloud Coordinator

The former `cloud-start`, `cloud-status`, and `cloud-resume` commands and the
`legacy_xcode_cloud` configuration describe retained historical Xcode Cloud
behavior. They are not exposed by the current delivery route and must not be
used as a fallback for a failed or unavailable stable runner.

Historical state is stored outside the repository under
`~/.codex/state/forzadvisor-release/`. It remains separate from current
stable-runner candidate state and must never be adopted, rewritten, or inferred
as evidence for a new candidate. Historical workflow IDs and release records are
preserved so earlier runs remain auditable.

## Verification of Release Automation Changes

Run the dependency-light suite with:

```sh
ruby scripts/tests/forzadvisor_release_test.rb
```

The suite uses injected network, Git, GitHub, runner, and App Store observations.
It must not access credentials, dispatch workflows, contact the private runner,
archive, upload, associate a TestFlight group, stage, or submit App Review.
