# ForzAdvisor Stable Release Reconciliation

## Commission

- Outcome: preserve GitHub Actions as exact-revision verification while making the logical `stable-xcode-26.3-intel` SSH profile the only archive/export/upload authority for ForzAdvisor; the physical host remains private configuration.
- Inspectable deliverables: reconciled release configuration, coordinator and validation logic, tests, disabled hosted-upload path, shared deterministic SSH archive/upload support, and current release documentation.
- Source precedence: current user request and global release policy; root `AGENTS.md`; `AppStore/release-config.json`; repository tests and coordinator; release documentation; historical release records.
- Crew mode: Full, because repository contract and shared SSH delivery support are separate evidence outputs that must integrate.
- Assurance: High Assurance because the change controls signing and external release behavior.
- Delivery target: locally verified code and documentation only.
- Authorized external actions: read-only runner and repository preflights. No commit, push, workflow dispatch, build-number allocation, archive, export, upload, TestFlight association, App Store mutation, or App Review action.

## Preservation Set

- Existing ForzAdvisor app behavior, release identity, immutable-tag checks, complete `ReleaseVerify` plan, App Store metadata, screenshots, TestFlight internal-group identity, and explicit App Review approval gate.
- Existing user changes in root `AGENTS.md`.
- Historical Xcode Cloud and GitHub-hosted release evidence under `AppStore/releases/`; history remains history and must not be rewritten as current policy.
- Private runner endpoints, credentials, signing metadata, keychain details, and keys remain outside the repository and out of logs.

## Gates

| Gate | Class | Observable pass condition |
|---|---|---|
| G1 | hard | GitHub `release-verify.yml` remains an immutable-ref, complete `ReleaseVerify` test oracle and has no archive/upload authority |
| G2 | hard | GitHub `release-candidate.yml` cannot access release credentials, archive, export, or upload |
| G3 | hard | Repository config declares only logical/public stable-runner facts required by the shared SSH preflight and exact-commit build helper |
| G4 | hard | Coordinator and config validation reject hosted upload and expose a deterministic SSH candidate route without weakening immutable-ref or green-verify prerequisites |
| G5 | hard | Shared SSH helper fails closed on profile/toolchain/archive identity and performs upload only with an explicit upload flag and exact version/build |
| G6 | hard | Candidate processing requires the exact uploaded build to become `VALID` before internal-group association or readiness claims |
| G7 | preservation | Existing App Store staging and explicit App Review submission guards remain intact |
| G8 | quality | Release guide, checklist, config, tests, workflows, and agent guidance describe one consistent current path; historical records remain clearly historical |
| G9 | hard | Focused Ruby tests, syntax/config checks, release preflights, and affected regression checks pass on one frozen artifact |
| G10 | hard | Two blind critics with non-overlapping security/authority and correctness/operability lenses accept the frozen artifact; material repairs receive a different fresh acceptance critic |

## Ownership

- Lead: sole editor of this record, shared contracts, integration, and final delivery.
- Architecture auditor: read-only repository release-state and migration contract.
- Shared-helper auditor: read-only SSH helper and upload safety design.
- Test/operations auditor: read-only test, workflow, documentation, and preservation map.
- Builders: assigned only after the contract freezes; no overlapping write scopes.
- Critics: fresh, read-only, and blind to builder rationale.

## Artifact Ledger

- v0: current tree with hosted Xcode 26.6 candidate upload encoded in config, workflow, coordinator validation, tests, checklist, and release guide; stable-runner preflight passes, repository SSH archive preflight fails only for missing `stableRunner` declaration.
- `CON-001`: current root guidance requires Silver Surfer, while repository executable contracts require GitHub-hosted upload.
- `DEC-001`: GitHub remains verification-only; Silver Surfer owns archive/export/upload; historical release records remain immutable evidence.
- `DEC-002`: current GitHub-hosted `release-candidate.yml` is removed rather than left as an inert second release path; GitHub environment/secrets are not mutated by this commission.
- `DEC-003`: active config advances to schema v2 with verification-only `ci` facts and a non-secret snake-case `stable_runner` contract. Legacy Xcode Cloud identifiers remain explicitly historical and its state file is never adopted by the new route.
- `DEC-004`: extend the existing shared `ssh_runner_build.sh` with an explicit upload mode rather than handing a remote archive path to a second process. Default build and archive-only behavior remain non-uploading.
- `DEC-005`: upload confirmation token binds platform, App Store app ID, bundle ID, marketing version, build, and exact commit. The helper reads config from that commit, rejects an existing matching ASC build before upload, waits for the new exact build to become `VALID`, and returns a non-secret receipt.
- `DEC-006`: ForzAdvisor proves an exact-tag/exact-SHA successful GitHub Verify run before calling the shared helper. Internal TestFlight association is separated from App Store version/review-draft staging, and staging requires recorded human `ACCEPT`.
- `RISK-001`: existing legacy release state is stale and unbound. The stable-runner route uses a distinct schema-v2 state file and does not mutate or adopt the legacy state.
- `RISK-002`: shared helper hardening must include committed-config use, repo/private profile equality, task-scoped credential copies, serialized runner ownership, complete archive identity/codesign checks, sanitized errors, and safe cleanup/retention.

## Status

- State: ACCEPTED v2.
- Artifact digest: `c1a22395ff73fdc061a0eff0d54d1441a4dad731ee9c8ca6633f289e4755f2c0`. The digest is the SHA-256 of the sorted per-file SHA-256 manifest for the repository release contract, verification-only GitHub workflow, shared release skill/runtime/tests, and the explicit deletion marker for `.github/workflows/release-candidate.yml`; this record is excluded to avoid a self-referential digest.
- v1 assurance result: both required blind critics reproduced `dd75f462a91b66d1034ee6d6925ae0e7cda6faa8715dcafb3517b71b2d67fe2b` and required repairs. Accepted signals were a GitHub dispatch/proof contradiction, missing warnings/xcresult enforcement, one-shot and interrupted state dead ends, mutable human results, insufficient downstream identity/group/build revalidation, missing durable history, unbound App Review approval, and a physical host name in repository guidance.
- v2 repair evidence: dispatch is tag-bound; GitHub treats source warnings as failures and requires a nonempty xcresult with zero failures, skips, or expected failures; stable state has immutable private terminal history and different-build rollover; `github_verified` has explicit resume, while ambiguous upload has read-only reconciliation plus an evidence-preserving block and never retransmits; human results require notes/evidence and cannot be overwritten; build/version/platform/export/group/config identity is revalidated for staging and submission; App Review requires an exact bound token; physical host facts are absent from repository-facing artifacts.
- Repository test evidence: `ruby -w scripts/tests/forzadvisor_release_test.rb` passes 50 tests / 322 assertions; Ruby syntax, JSON and workflow YAML parsing, `git diff --check`, CLI/static path scans, and historical-file preservation checks pass.
- Shared-helper evidence: waiter passes 5 tests / 24 assertions; SSH build guard and committed-config fixture passes; SSH preflight redaction/no-unlock fixture passes; outer and embedded remote zsh syntax and Ruby syntax pass.
- Live read-only evidence: shared SSH-mode release preflight passes the pinned `stable-xcode-26.3-intel` profile, public toolchain facts, three public URLs, credentials-file invariants, signing readiness, and passwordless runner reachability with zero failures. The only notice is the intentionally dirty local worktree.
- Xcode evidence: XcodeBuildMCP discovered `forzadvisor.xcodeproj`, shared scheme `forzadvisor`, and an available iPhone 17 Pro destination; the final warning-clean Release simulator build passed in 3.1 seconds. Build log: `~/Library/Developer/XcodeBuildMCP/workspaces/i-would-like-to-establish-a-3443a8343086/logs/build_sim_2026-08-31T01-45-02-982Z_pid82060_3e5c8de3.log`.
- Preservation evidence: GitHub `Release Verify` remains verification-only and now closes the warning/runtime-result gap; `AppStore/releases/**` is unchanged; root `AGENTS.md` keeps the inherited common workflow while exposing only the logical runner profile; no credentials or private runner facts were added to the repository.
- Expected local limitation: repository `scripts/release preflight --ref main` correctly refuses this uncommitted worktree. A clean immutable commit is required before that gate can pass; no bypass was added.
- External-action evidence: no commit, push, workflow dispatch, build-number allocation, archive, export, upload, TestFlight association, App Store mutation, or App Review action occurred.
- Final acceptance: a different fresh read-only critic reproduced the v2 digest and passed every locally inspectable gate. Clean exact-tag preflight, exact-tag GitHub execution, archive, upload, TestFlight association, staging, and App Review remain intentionally unrun external gates.
- Task cleanup: removed the task-owned 213 MB DerivedData directory and temporary manifest after acceptance. The Data volume then reported 49 GiB available; only 213 MB is attributable to this cleanup because other system storage changed concurrently.
- Next join gate: create a clean immutable commit with a different build identity, then run repository preflight and GitHub verification before any stable-runner candidate action.
