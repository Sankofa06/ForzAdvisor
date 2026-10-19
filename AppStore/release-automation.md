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

### Cloud planning pilot — disabled

`ruby scripts/release-daily` is a portable, offline planning pilot around the
existing coordinator. It cannot dispatch GitHub or native jobs, connect to the
runner or Apple, upload, associate testers, stage, or submit. No schedule is
installed. A future daily opportunity observes and proposes eligible work;
native execution remains a separately reviewed and authorized handoff.

Inspect one local annotated release tag against an explicit prior candidate SHA:

```sh
ruby scripts/release-daily --ref RELEASE_TAG --baseline EXACT_40_CHARACTER_SHA
```

The baseline must be an available ancestor. Choose the prior considered candidate
deliberately; a failed attempt must not silently become the successful-release
baseline. The planner reads configuration and changed paths from Git objects,
checks the configured remote, and binds app, bundle, platform, version/build,
tag, commit, configuration fingerprint, and stable profile into a candidate ID.
It rechecks the tag after reading. Unchanged candidates and changes limited to
Markdown in `docs/`, `forzadvisorDocs/`, `AppStore/`, or the root `README.md`
are skipped. Other paths conservatively require all gates.
Skipping applies only to new work without an active candidate snapshot; an
existing candidate still needs identity validation and ongoing observation.

For a disconnected simulation, provide private fixture observations and an
already provisioned, durable private state directory outside the checkout:

```sh
ruby scripts/release-daily --ref RELEASE_TAG --baseline EXACT_40_CHARACTER_SHA \
  --fixture /absolute/private/observations.json \
  --state-dir /absolute/private/pilot-fixture-state
```

The caller must establish the state directory's durability, including its parent
directory entry, before requesting a handoff. The directory must already exist
without group/world permissions. The planner fails closed if it is missing and
never creates state directories or ancestors; directory provisioning is outside
this pilot's scope.

The authoritative `StableStateStore` likewise requires an already durable,
private root at the existing controller's `FORZADVISOR_STABLE_RELEASE_STATE_DIR`.
Active-state, evidence, and history writes sync file contents before rename and
the containing directory afterward. History-directory creation syncs its parent.
A sync failure stops the operation; an upload intent left after rename remains
uncertain and must be reconciled rather than retried. The store never provisions
the state root or its ancestors.

Fixture JSON uses `kind: "fixture"` and the exact `candidate_id` from the first
command. `gates` maps every `DailyPilot::GATES` entry to `result: "PASS"` and
the exact `commit`; clean-build evidence also requires zero `warnings`.
The local release gate requires `summary` with a positive `tests` count and
zero `failures`, `skips`, `expected_failures`, and `warnings`. `github` supplies
`run_id`, raw `run`, and `jobs` to the existing exact-revision verifier.
These fixture declarations never satisfy an actual engineering or release gate.

`change_plan` binds `commit` and `baseline_commit` to a version-specific
`summary` and numbered `scenarios`, each with nonempty `steps` and `expected`.
The output carries the exact version/build/SHA, changed paths, regression checks,
stop conditions, per-scenario response fields, and overall human-result choices.
Missing expected behavior blocks a simulated handoff instead of inventing a
test plan. See the dependency-light suite's `with_daily_pilot` fixture builder.

Optional `stable_state` is a snapshot of the existing v2 coordinator state,
never the historical Xcode Cloud state. `apple` maps read-only API paths to
fixture responses, including collection pagination; `apple_observed_at` must
be within the previous 15 minutes. The planner reuses `UploadedBuildResolver`
and `CandidateBuildValidator`, requires the exact eligible `VALID` build and
current internal-group association, and rejects expired builds. A receipt by
itself cannot establish availability. Missing, stale, removed, or ambiguous
Apple observations keep the simulated build below install-ready.

The fixture outbox reserves one native handoff under a file lock and persists
intent before returning `would_dispatch_native`. It syncs the intent file and
the containing directory after rename while holding the lock. A directory-sync
failure stops readiness and retains the intent for reconciliation. Repetition returns
`reconcile_native_dispatch`; another candidate sees `native_slot_busy`.
There is no timeout-based takeover or automatic reset. An existing
`upload_start_intent` always requests read-only reconciliation, never another
upload. A matching snapshot is validated before unchanged/doc-only skipping and
new-candidate gate or test-plan checks. Missing new-candidate evidence cannot
hide an uncertain upload or imply that those gates passed. Even an absent Apple
build is not proof that an uncertain upload failed.
Reconcile and explicitly block through the existing coordinator, preserving its
receipt/history and requiring a new build identity where its policy requires it.
The runner's existing shared archive/upload lock remains authoritative.

Private portal consumers must distinguish `proposed`, `verified`, `uploaded`,
and `install_ready`, and keep work in PRs separate from release availability.
In this pilot, these transitions appear **only under `simulation`**.
The publishable `portal` projection always has `install_ready: false` and
`availability: "UNVERIFIED"`; `work_in_pr: null` means the PR connection is
unverified, not that there are no PRs. Do not copy simulated readiness to the
portal. No live portal integration or current-build availability is claimed.

#### Read-only observer adapter — unconnected

`scripts/lib/forzadvisor_release_observer.rb` supplies a stateless
`ReleaseObserver` around the existing validators. It does not select candidates,
allocate versions, persist a second release state, or dispatch work. Construct
it with `config: pilot.config` and `identity: pilot.identity` from
`DailyPilotSource#call`; no controller or state path is guessed.

Every reader is explicitly injected and receives `identity:`. Missing readers,
identity mismatches, transport failures, and stale observations produce blocker
codes without exposing raw errors or state. Reader envelopes require
`evidence_kind` (`fixture` or `live`) and the exact `candidate_id`:

| Adapter | Required observations |
|---|---|
| `gate_reader` | Exact `commit`, `config_fingerprint`, `baseline_commit`, all `gates`, `verify_run_id`, and candidate-specific `change_plan` |
| `github` | Existing `GitHubClient`-compatible `run` and `jobs` reads; checked by `GitHubVerificationEvidence` |
| `state_reader` | Fresh `observed_at` plus `state: null` for confirmed absence, or the authoritative v2 coordinator snapshot |
| `apple_reader` | Fresh `observed_at` plus the existing API client's `get` interface |
| `pr_reader` | Fresh `observed_at`, exact `repository`, and the GitHub `pull_requests` collection |

`ReleaseGateCollector` shares the pilot's gate and change-plan checks. It never
runs tests or manufactures attestations. An existing uncertain upload takes
precedence over collecting new gate/Apple evidence. Receipt checking uses the
coordinator's public, read-only `validate_candidate_receipt!` entry point.
Apple observation reuses the exact-build resolver and internal-group validator,
then requires a non-expired build. Readiness expires at the earlier of the build
expiration or 15 minutes after either controller or Apple observation. Controller
timestamps describe when authoritative state was read, not when it last changed;
missing, stale, future-dated, or malformed state blocks handoff. Configuration is
privately copied and deeply frozen at construction to preserve candidate identity
throughout observation. PR observations remain independent of release availability.

`ReleaseObserver#call` returns an allowlisted projection: immutable identity,
verified run identifier, curated version-specific plan, build/group/expiry facts,
blocker codes, and PR number/URL/head SHA/draft status. It omits raw snapshots,
receipt internals, notes, logs, review contact data, and PR bodies/titles.
Default `evidence_kind: :fixture` places computed states only in `simulation`;
the portal projection stays unverified. Explicit programmatic `:live` mode
requires matching live provenance on every injected envelope. This is an adapter
contract, not evidence that any live connection has been configured.

The CLI remains offline. No live clients are constructed automatically; no
publisher or schedule is included. The existing private portal destination and
controller connection details belong in private operational configuration,
outside the repository. `publication_enabled`, `schedule_enabled`, and
`native_execution_enabled` remain false in observer output.

Operational activation requires independent review, the existing exact-commit
full local and GitHub release gates, verification of the private portal and
durable state connections, and the existing stable profile, signing, ASC access,
internal-group membership, and per-candidate upload authorization. Keep signing
and runner connections external. This pilot adds no hosted-signing path or
credentials and does not alter the coordinator's release policy.

`AppStore/release-config.json` records non-secret release facts:

- App Store Connect app, bundle, team, version, review-draft, and review-item identifiers
- canonical GitHub checkout, remote, and immutable release ref
- marketing version `1.41.2`, proposed source build `89`, and current App Store
  build `87`
- Free pricing, explicit-human-approval submission policy, and `AFTER_APPROVAL` release timing
- published privacy-label declaration and human attestation date
- content-rights, age-rating, review-contact, and export-compliance attestations
- public marketing, privacy, and support URLs
- Xcode project, schemes, complete `ReleaseVerify` plan, and privacy manifest
- GitHub verification workflow and its public toolchain facts
- the logical stable-runner profile, public pinned toolchain facts, project,
  scheme, generic iOS destination, manual signing mode, warning policy, and an
  explicit App Store-eligible export policy with
  `testFlightInternalTestingOnly=false`
- intended internal TestFlight group
- metadata limits and exact screenshot order
- retained legacy Xcode Cloud identifiers marked `DISABLED_DO_NOT_USE`; this is
  repository policy only and does not change settings in Xcode Cloud

The active archive and upload path remains the configured stable SSH runner.
The Xcode Cloud identifiers are retained for audit history and cannot be used
as a fallback.

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

### Verification runtime contract

The exact-revision GitHub `Release Verify` workflow uses `macos-26`, macOS 26.6.2
build `25G83`, Xcode 26.6 build `17F113`, and the iPhone 17 Pro simulator on
iOS 26.5. The current [GitHub macOS 26 runner image inventory](https://github.com/actions/runner-images/blob/main/images/macos/macos-26-Readme.md)
lists that Xcode, the iOS 26.5 simulator runtime, and the iPhone 17 Pro device.
The workflow checks the host and Xcode versions and runs the complete
`ReleaseVerify` plan with warnings as errors and no test exclusions.

Local verification uses the installed iOS 26.5 iPhone 17 Pro destination selected
through XcodeBuildMCP. The ReleaseVerify plan does not pin a local Xcode version;
the local Xcode 27.0 installation is verification-only and never has archive or
upload authority. The manual `verification-ci.yml` smoke/regression lanes remain
on their separately installed iOS 26.4.1 destination.

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

The tracked scripts/stable-runner/ssh_runner_build.sh transfers the exact commit
to a task-owned remote directory, derives certificate/profile selectors only from
the existing private signing metadata for the exact shipping bundle set, and
uses the configured project/scheme/destination. It checks the selected active
App Store profile and its certificate against the existing valid distribution
identity, archives with source warnings as failures, and verifies each embedded
provisioning profile, signer identity, bundle/version/build, architectures,
Xcode build, and macOS build before export. It then rechecks the exported IPA
signature/profile and computes the package SHA-256 before upload from that same
task. Private endpoint, keychain, signing, and credential details must never
enter repository files or logs.

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

A pending TestFlight candidate may be superseded only by a different tag and
commit for the same app, bundle, and marketing version with a strictly higher
numeric source build. The old `human_verification_pending` state is archived
with its receipt unchanged at mode `0600`; the new state records
`SUPERSEDED_PENDING`, the prior identity, and the archive SHA-256. This does
not record or infer a human result for either build. Starting that supersession
requires the exact candidate tag's successful Release Verify run, `--upload`,
and the identity-bound upload confirmation token; without them the pending
state and receipt remain active and no archive is written.

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
behavior. Its `DISABLED_DO_NOT_USE` marker is repository policy only; it does
not modify Xcode Cloud settings. The coordinator rejects start, status, and
resume before Git, state, or API effects. These identifiers must not be used as
a fallback for a failed or unavailable stable runner.

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
