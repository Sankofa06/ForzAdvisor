# Main integration and repository cleanup — 2026-10-01

Status: source and local verification passed; main reconciliation and pruning pending. This is not a TestFlight delivery record.

## Commission and identity

The owner requested all outstanding PR/branch improvements preserved and merged/pushed to main, with stale repository state pruned. This authorizes main integration and removal of proven obsolete task branches; it does not authorize App Review or removal of release evidence.

- Canonical repository: `Sankofa06/ForzAdvisor`, checkout `~/Agents/ForzAdvisor`, remote `origin`.
- Starting main: `b840cb2e863924103fa8717ec2cbfe582eb28a9b`.
- Integration branch: `agent/astra-test-improvements`; frozen source `f9dd64f860a714706a633b5ee6e5bd52088a8b61`, 326-file manifest SHA-256 `0656f7bdc68bbe4d82a159d96ca01bcdbb124acf41dc9d9263fd3fbb2db963d5`.
- Project/scheme: `forzadvisor.xcodeproj`, shared `forzadvisor`, `ReleaseVerify.xctestplan`.
- Verification host/toolchain: coordination Mac, macOS 27.0 (`26A428`), Xcode 27.0 (`27A266a`), XcodeBuildMCP 2.7.0.
- Owned destination: iPhone 18 Pro, iOS 27.0 (`24A5370g`), simulator `47AA3926-F46A-433F-B983-90884251711F`.
- Evidence root: `/tmp/forzadvisor-main-integration-20261001`; recovery bundle and branch audit are retained outside the repository in Codex state under `forzadvisor-repo-cleanup-20261001`.
- Definition of done: verified source on main/origin/main; outstanding implementation PRs reconciled; no unique app work discarded; clean canonical checkout and no obsolete task branches/stash.

## Preservation

PR #5 head `064813d`, PR #6 head `b6291d8`, and prior PR #7 head `446da77` are preserved in merge ancestry. Main's pilot documents remain intact. The merge had one textual conflict, in the replace-in-place PERCEPTION record; automated source merges were separately inspected.

| Prior branch | Preservation evidence |
|---|---|
| `agent/4-capture-ui-coverage` | `a08103b` has an equivalent patch in the integrated history. |
| `agent/4-evidence-actions` | `c13de77` has an equivalent patch in the integrated history. |
| `agent/4-measurement-alternatives` | Both unique commits have equivalent patches. |
| `agent/4-readiness-ocr` | Both unique commits have equivalent patches. |
| `agent/4-tune-readiness-evidence` | Tip is an ancestor of the integration. |
| `agent/forzadvisor-consolidation-2026-09-25` | Tip is an ancestor of the integration. |
| `agent/forzadvisor-testflight-82` | Tip is an ancestor of the integration. |
| `agent/forzadvisor-improvements` | Remote tip is an ancestor. Unique local `2318c3c` hardening is preserved or superseded by issue #4's explicit conversion/confirmation policy; refinement-history cleanup and tests remain. |
| `agent/honest-recoverable-first-tune-20260921` | Unique draft recovery and FH5 disclosure were restored; other behavior survives. Build 79 references are superseded by build 87, and the newer automatic-signing contract supersedes the old explicit signing identity. |

Before cleanup, `git bundle create … --all` and `git bundle verify` preserved all refs, including the historical PERCEPTION-only stash. A separate stash patch and exact ref/branch inventory were saved. Release tags, screenshots, IDE user state, and Codex-managed internal refs are retained.

## Integration repairs and behavior

- Restore meaningful draft recovery through Garage → New Tune and FH5's actual local planning disclosure.
- Keep usable-output reprojection while preserving original pending-confirmation and missing-report restrictions, including sanitization, persistence, and reopening.
- Reject conflicting, unsupported, unitless, oversized, signed, or unsupported grouped OCR measurement readings rather than silently extracting a plausible number. Preserve observation boundaries when checking alternate OCR readings.
- Retain manual optional horsepower/torque edits through confirmation and manual fallback.
- Withhold legacy numeric rows while preserving stored tune data.
- Preserve evidence callbacks, workflow failure/cancellation tests, persistence cleanup, and reliable UI input helpers.

Existing assertions exposed the compilation/readiness/OCR integration failures; production behavior was corrected. New tests cover saved pending confirmations, split unit fragments, restored UI paths, numeric token integrity, conflicts within one observation, unlabeled alternatives, and separation of unrelated fields. The final parser matrix includes 80 observation-boundary permutations, 18 alternative-fragment cases, 48 screenshot-context placements, 26 context-residue/alternative cases, and 56 independent-field cases across separate/coalesced observations and both orders. No assertion was weakened to make the integration pass. The screenshot assertion was updated to require the actual FH6 withheld-evidence description, while retaining its condition-based wait.

## Verification ledger

| Gate | Tool or command | Target | Result | Evidence path | Warnings or gaps |
|---|---|---|---|---|---|
| Preservation | `git bundle verify`, ancestry, `git cherry`, source review | All task branches and stash | PASS | External recovery bundle; `branch-preservation.json` | Two older branches require semantic rather than byte-identical proof, documented above. |
| Deterministic checks | `scripts/validate-agent-framework.sh`, Ruby release tests, `git diff --check`, credential-pattern scan | Integrated source | PASS | `framework-final.log`, `release-tests-final.log` | 50 tests / 330 assertions; no failures/skips. |
| Focused unit tests | XcodeBuildMCP `test_sim`, selected 7 suites | `c4bae24` | PASS, 71 tests | `focused-fixed.xcresult` | Superseded by final full-suite gate. |
| Focused UI | XcodeBuildMCP `test_sim` | `fcb2175` | 2 passed; one selector failure repaired | `focused-ui.xcresult` | Draft and OCR entry passed. FH5 assertion was corrected to the actual combined accessibility label. |
| Broad unit gate | XcodeBuildMCP `test_sim`, only `forzadvisorTests` | `32e1f3b` | PASS, 610 tests | `all-unit.xcresult` | Superseded by final full-suite gate. |
| Final focused parser tests | XcodeBuildMCP `test_sim` | `f9dd64f` | PASS, 34 tests | `parser-coalesced.xcresult` | No failures, skips, compiler warnings, or errors. |
| Saved-boundary and readiness regressions | XcodeBuildMCP prepared tests | `43a5ce3` | PASS, 18 tests | `saved-pending.xcresult` | The same boundary/presentation code is retained in the final source. |
| Legacy rendered regression | XcodeBuildMCP prepared UI test | `43a5ce3` | PASS, 1 test; screenshot inspected | `legacy-rendered.xcresult`; `legacy-rendered-attachments/12D6368B-548D-4749-84D7-A58CA0F85996.png` | Stored sentinel remains in the fixture; normal numeric rows and expansion controls are absent. |
| Clean Release build | XcodeBuildMCP `build_sim`, `clean`, warnings as errors | `f9dd64f` | PASS | `release-build-coalesced.xcresult` and retained MCP build log | No compiler warnings/errors. Earlier builds are retained as superseded evidence. |
| Complete ReleaseVerify | XcodeBuildMCP CLI, serial full plan, warnings as errors | `f9dd64f` | PASS, 640 tests: 625 unit + 15 UI; zero failures/skips/expected failures | `release-verify-f9dd64f.xcresult`, `release-verify-f9dd64f-summary.json`, `release-verify-f9dd64f.log` | Seven pre-existing SwiftUI invalid-frame runtime warnings; one toolchain App Intents metadata-extraction warning. No source compiler warnings. The MCP CLI avoids the endpoint’s 300-second timeout. Superseded/interrupted evidence is retained. |
| Independent source acceptance | Fresh Astra xhigh reviewer | `f9dd64f` | PASS, four gates; no material blockers | `source-acceptance-f9dd64f.md` | Earlier reports found defects repaired in subsequent commits. |
| Main / PR reconciliation / pruning | Exact ref checks and GitHub PR state | Final published revision | PENDING | Final reconciliation pending | No force-push or release-tag deletion. |

## OCR preservation correction

Source review rejected the initial exhaustive grammar because ordinary car headings suppressed valid explicit measurements. The context repair preserves observation-bounded car/menu context and known performance fields while retaining strict consumption of measurement-owned fragments. A final correction establishes field ownership before numeric validation for coalesced observations. All 34 focused tests and the clean Release build pass on `f9dd64f`. The superseded `9863206` full run passed all 622 unit tests and one UI test before deliberate cancellation; the next UI test records “Testing was canceled.” This is not a complete passing gate.

## Runtime flow evidence

All 15 UI tests passed on the frozen source and owned simulator. The following flows were exercised; six saved screenshots were visually inspected. All paths below are relative to the evidence root.

1. Enter a manual draft, close it, return through Garage → New Tune, and resume the retained values.
2. Select FH5, change discipline and return, then inspect the local build-planner disclosure.
3. Generate a supported result, save it, reopen it, and inspect state and metadata actions.
4. Correct optional OCR horsepower and torque and retain them through confirmation and manual fallback.
5. Load a persisted legacy numeric fixture and withhold its numeric rows while retaining the stored fixture.
6. Invoke capture actions from both the result evidence section and the Evidence Hub.
7. Exercise Garage, New Tune, Settings, Step Guide, and result screenshot flows. Dark Mode and XXXL launch-argument effectiveness remains unverified despite passing flow assertions.

Inspected screenshots:

- Draft recovery: `final-attachments/32F15E1E-6080-44DD-929E-9260D916752A.png` retains Mazda.
- FH5 disclosure: `final-attachments/369E7ED5-4BB5-4647-9C65-0F4FBB9E9EFE.png` identifies the local build planner and no numeric tuning output.
- OCR correction: `final-attachments/AB8B00E1-4C0B-4E48-8BCB-417F3D64AEF4.png` shows 400 hp / 350 lb-ft in both confirmed input and fallback.
- Legacy rendering: `final-attachments/6768AEA8-8682-4320-A11D-0A52301F786E.png` withholds settings while preserving one stored fixture line.
- Mode-gap evidence: `final-attachments/1BF8E1A4-88EE-4CFB-AF48-3645B6B1785B.png` and `final-attachments/87954C18-A415-46D7-94FE-48A9A6446F22.png` do not establish the requested Dark Mode/XXXL configurations. The known argument-domain override remains disclosed.

The complete run lasted 961 seconds. Logs were inspected: seven `Invalid frame dimension (negative or non-finite)` runtime messages match the previously recorded manual/result-flow gap. The App Intents message reports skipped metadata extraction without an AppIntents dependency and is a toolchain diagnostic. The clean Release build itself had no warning or error lines.

The simulator lane was coordinated with the owner’s explicit authorization and released after completion; the owned device was confirmed Shutdown. No other task’s simulator/build resources were stopped or cleaned. Final summary, source fingerprint, review report, logs, and screenshots are also copied to persistent Codex recovery state under `forzadvisor-repo-cleanup-20261001/verified-evidence`.

## Release boundary and retained gaps

This record establishes integration and cleanup, not distribution readiness. The release coordinator still identifies TestFlight 1.41.2 (87) as the existing human-verification candidate. No new build number, release tag, archive, upload, group assignment, or App Review submission is part of this cleanup.

Release preflight correctly rejected a source revision that does not match the configured build-87 tag. Fresh exact-revision GitHub Release Verify, stable-runner release gates, and the owner result remain necessary for a later candidate. The prior ledger records pre-existing source-unattributed SwiftUI layout warnings and unproven dark/XXXL screenshot modes; these remain disclosed rather than being treated as clean release evidence.
