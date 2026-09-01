# Deterministic Release Workflow

## Problem and outcome

ForzAdvisor release preparation previously mixed repository validation, hosted
CI, archive authority, and App Store Connect discovery. The reconciled workflow
keeps every result tied to one immutable revision while separating independent
verification, stable Apple release production, TestFlight acceptance, staging,
and App Review submission.

The required current route is:

```text
local gates
→ immutable tag and exact SHA
→ GitHub Release Verify
→ stable-xcode-26.3-intel archive/export/upload
→ exact build VALID
→ Internal TestFlight group
→ numbered human live plan
→ ACCEPT
→ App Store version staging
→ separate App Review approval
```

## Requirements and acceptance criteria

1. A versioned, non-secret release configuration records app identity, canonical
   GitHub source, verification-only GitHub workflow, logical stable-runner profile
   and public toolchain facts, retained legacy Xcode Cloud identifiers, App Store
   identifiers, internal TestFlight group, public URLs, pricing, privacy,
   content-rights, age-rating, review-contact, metadata, and screenshot facts.
2. A dependency-light `scripts/release` validates the repository and App Store
   assets, proves a successful exact-tag/exact-SHA GitHub verification run,
   coordinates the stable SSH candidate, waits for the exact build to become
   `VALID`, associates the configured internal group, records human acceptance,
   and preserves only redacted private state outside the repository.
3. Local preflight rejects the wrong checkout, remote or revision mismatch,
   dirty release source, identity mismatch, incomplete schemes/test plan,
   metadata or screenshot errors, missing privacy/export declarations,
   unreachable public URLs, or incomplete attestations.
4. Focused tests, a warning-free Release build, the complete local
   `ReleaseVerify` plan, and runtime evidence pass before immutable handoff.
5. GitHub Actions verifies the exact immutable tag and SHA on its pinned
   fresh-machine toolchain. Its dispatch ref and run head branch are the same
   tag, warnings are errors, and the xcresult must contain tests with zero
   failures, skips, or expected failures. No current GitHub workflow can access
   release credentials, archive, export, or upload.
6. Only logical profile `stable-xcode-26.3-intel` may archive, export, or upload.
   The route rechecks its private profile, pinned public toolchain facts, signing
   prerequisites, exact committed configuration, archive identity, architectures,
   codesigning, embedded profiles, and warning policy before upload.
7. Upload intent is explicit and bound to platform, app ID, bundle ID, version,
   build, and exact commit. An existing matching App Store build or ambiguous
   state fails closed before upload.
8. TestFlight readiness requires the exact uploaded build to become `VALID`,
   retain App Store eligibility and export-compliance evidence, and be associated
   with the configured `Internal` group.
9. The generated numbered live plan prefills Expected results and records the
   owner's Actual result, `PASS | FAIL | BLOCKED`, evidence, and notes for every
   scenario. Only an overall `ACCEPT` permits App Store version staging.
10. App Store staging revalidates the exact accepted build, TestFlight
    association, config fingerprint, and all candidate metadata. App Review
    submission repeats those checks and remains a separate explicit command,
    acknowledgement, and identity-bound token after immediate human approval.
11. Every release writes a durable non-secret record containing revision,
    verification run, runner/toolchain evidence, source build, observed App Store
    build, processing and group state, live acceptance, staging state, and the
    highest delivery state reached.

## Non-goals

- Store credentials, tokens, signing keys, provisioning profiles, private runner
  connection details, keychain data, or personal review contact in the repository.
- Give GitHub Actions, the developer Mac's beta Xcode, or legacy Xcode Cloud
  current archive or upload authority.
- Automatically stage after upload, submit App Review, or publish the app.
- Infer a build number, human acceptance, or review approval from a prior state.
- Rewrite historical build-78 evidence to match the current runner policy.
- Introduce another repository mirror or couple local validation to one stale
  simulator UUID.

## Architecture and safety decisions

- GitHub `origin` and the canonical checkout under `~/Agents` are authoritative.
- XcodeBuildMCP owns local Apple-platform discovery and verification; raw
  `xcodebuild` is a documented fallback only.
- GitHub Actions owns exact-revision fresh-machine verification only.
- The global release helper and logical `stable-xcode-26.3-intel` profile own
  archive, export, upload, and archive identity evidence. Private connection and
  signing facts remain external.
- The repository coordinator is the only current route into that helper. It
  stores intent before mutation, supports status and phase-safe recovery,
  sanitizes failures, and never adopts legacy Xcode Cloud state.
- Candidate processing, internal TestFlight association, human acceptance, App
  Store staging, and App Review submission are separate monotonic phases.
- An interrupted or failed candidate retains its exact source and evidence.
  `github_verified` may resume only with renewed explicit upload authorization;
  `upload_start_intent` is read-only reconciled and blocked, never retransmitted.
  Correction uses a new commit and different version/build identity; terminal
  evidence is archived mode `0600` and never silently replaced.
- The App Privacy questionnaire remains a dated human-attested gate because the
  public API does not expose the complete questionnaire.
- Source build and observed App Store build remain separate facts.

## Verification mapping

- Release CLI tests cover strict configuration, hosted-upload rejection,
  immutable-ref and GitHub-run proof, state isolation, upload confirmation,
  runner observations, processing, group association, human acceptance, staging,
  redaction, idempotency, terminal history and rollover, interruption recovery,
  downstream identity drift, and identity-bound submission acknowledgement.
- Focused XCTest covers every app behavior changed by the candidate.
- `ReleaseVerify.xctestplan` proves local unit/UI integration with no skipped or
  expected-failure contracts.
- GitHub `Release Verify` proves fresh-machine behavior for the exact revision.
- Shared runner tests prove committed-config use, profile/toolchain matching,
  scoped credential handling, serialization, archive/codesign identity,
  fail-closed upload, sanitization, and safe retention/cleanup.
- App Store candidate preflight proves exact build, processing, pricing, privacy,
  metadata, review details, release policy, and draft consistency.
- Human live evidence proves the owner observed Expected versus Actual behavior
  on the exact internal TestFlight build.
- Negative workflow scans prove GitHub has no current archive/upload capability.

## Delivery and rollback

Release automation changes are ordinary Git changes and can be reverted without
changing an already uploaded or staged build. A failed gate is retained against
its exact revision. Source or acceptance failures require a new immutable commit
and build number followed by every invalidated gate. Removing, expiring, or
reassigning a distributed TestFlight build requires separate authority.

The active state progression is:

```text
Scoped → Implemented → Locally verified → GitHub verified
→ Stable archive/upload → VALID → Internal TestFlight
→ Human ACCEPT → Staged → App Review submitted → Released → Cleaned up
```

`Human NEEDS_FIXES`, `Human BLOCKED`, `Ambiguous upload BLOCKED`,
`App Review submitted`, and `Submission failed` are durable terminal records for
that version/build. A different version/build may begin only after the previous
terminal state is archived; no terminal result can be rewritten as acceptance.

Never report a higher state than the evidence actually reached.

## Task checklist

- [x] Preserve exact-revision GitHub verification.
- [x] Remove the GitHub-hosted candidate workflow from the current tree.
- [x] Add strict verification-only CI and stable-runner configuration.
- [x] Add and test the stable-runner candidate coordinator route.
- [x] Add explicit shared SSH upload support and exact-build processing checks.
- [x] Add internal-group association and human-result gates.
- [ ] Pass focused tests, static checks, repository and runner preflights, affected
  Xcode verification, secret scan, and independent High-Assurance criticism.
- [ ] Commit and push the immutable result before any candidate action.
