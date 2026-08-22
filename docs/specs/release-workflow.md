# Deterministic Release Workflow

## Problem and outcome

ForzAdvisor release preparation previously mixed repository validation, hosted CI setup, and App Store Connect discovery. Account-level omissions such as privacy publication and pricing surfaced only after the binary was ready. The outcome is one reproducible, non-secret workflow that fails early, keeps every hosted result tied to an immutable revision, and cannot submit to App Review without a separate human approval.

## Requirements and acceptance criteria

1. A versioned release configuration records app identity, GitHub source, GitHub Actions verification, retained legacy Xcode Cloud identifiers, public URLs, price, release policy, privacy attestation, content rights, age-rating status, review-contact status, and source-versus-ASC build identifiers.
2. A dependency-light `scripts/release` command validates the local repository and App Store assets, coordinates Verify before Release Candidate, and stores only redacted private state outside the repository.
3. Local preflight rejects the wrong checkout, remote revision mismatch, dirty release tree, identity mismatch, missing shared schemes/test plan, metadata errors, invalid screenshots, missing privacy/export declarations, unreachable public URLs, or incomplete release attestations.
4. The complete `ReleaseVerify` plan passes locally with zero failures or skipped tests before immutable handoff.
5. GitHub Actions Verify runs against the immutable tag, then local Xcode archives and uploads that exact revision; the candidate must produce a valid App Store build.
6. App Store staging records the exact ASC build and stops before submission by default. Submission requires an explicit command plus acknowledgement after the user approves it.
7. Each release has a durable record containing revision, cloud runs, source build, ASC build, metadata/privacy/pricing state, and the highest delivery state reached.

## Non-goals

- Store credentials, JWTs, signing keys, or provisioning profiles in the repository.
- Automatically publish the app or infer approval to submit for review.
- Introduce GitLab or another mirror as a release source.
- Couple local validation to one hard-coded simulator runtime.

## Architecture and safety decisions

- GitHub `origin` and the canonical checkout under `~/Agents` are authoritative.
- XcodeBuildMCP is preferred for local Apple-platform verification; `xcodebuild` is a documented fallback.
- GitHub Actions owns fresh-machine verification; local Xcode owns archive, signing, and upload.
- Release state is written with owner-only permissions beneath `~/.codex/state/forzadvisor-release/` and contains no credentials or tokens.
- The App Privacy questionnaire remains a human-attested gate because Apple does not expose the complete questionnaire through the public API.
- `source_build` is the Xcode project build setting; `app_store_build` is assigned/observed in App Store Connect and must never be assumed equal.

## Verification mapping

- Release CLI unit tests cover configuration, preflight failures, idempotency, cloud ordering, source-commit matching, redaction, and submission acknowledgement.
- Focused XCTest covers every former cloud-only skipped contract.
- `ReleaseVerify.xctestplan` proves local unit/UI integration.
- GitHub Actions Verify proves fresh-machine build/test behavior.
- Pages deployment smoke checks prove the marketing, privacy, and support routes return success.
- App Store candidate preflight proves pricing, privacy attestation, metadata, review details, release policy, and exact build selection before staging.

## Delivery and rollback

Release automation changes are ordinary Git changes and can be reverted without changing an already staged App Store version. A failed cloud run is terminal for that revision; fix locally, create a new immutable commit, and start a new run. App Review submission remains a separate approval gate.

## Task checklist

- [x] Add and test release configuration/coordinator.
- [x] Correct repository and release guidance.
- [x] Consolidate the release checklist.
- [x] Record privacy-label attestation and release 1.41.1 evidence.
- [x] Add deployed Pages smoke checks.
- [x] Remove cloud-only test skips without weakening the contracts.
- [ ] Pass focused tests, full local verification, secret scan, and independent critique.
- [ ] Commit/push the immutable result and run GitHub Actions Release Verify.
