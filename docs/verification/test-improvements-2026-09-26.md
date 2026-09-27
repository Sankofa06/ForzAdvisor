# Tune workflow tests and compiler fix — 2026-09-26

Current outcome: compiler repair implemented and scoped local verification complete. All 585 unit tests and all three selected UI cases have passing results, with the final result UI case passing after its documented targeted correction. Debug and clean Release builds pass without compiler warnings. An existing SwiftUI layout runtime warning remains unresolved; full release verification and TestFlight are not claimed.

## Work contract

- Repository: `Sankofa06/ForzAdvisor`, canonical checkout, task branch `agent/astra-test-improvements` (started on `main`).
- Base commit: `b840cb2e863924103fa8717ec2cbfe582eb28a9b`; clean at intake.
- Goal: protect workflow recovery and lifecycle behavior with direct XCTest assertions; follow-up owner instruction “Fix it!” authorizes resolving the app compiler blocker.
- Definition of done: focused new/existing workflow suites pass, the app and test targets compile with source warnings treated as errors, and evidence identifies the tested source.
- Lane: Quick fix, in three reviewable slices (workflow tests, compiler repair, test harness cleanup). Delivery follows the repository’s TestFlight gates because the follow-up touches app source; App Review remains separately gated.
- Model: session runtime reported `gpt-6-astra`, `xhigh`, as requested.
- Write set: new `TuneWorkflowFailureTests.swift`; `ContentView.swift` compiler repair; removal of `NewTuneStartViewCatalogEntryContractTests.swift` with behavior coverage moved to `ForzAdvisorUISourceFlowTests.swift`; cleanup in `FH5ControlledExperimentPersistenceTests.swift` and `FH6ValidationReviewTests.swift`; form-entry synchronization in `XCUIElementTestSupport.swift` / `TuneResultUITests.swift` and a condition-based render wait in `ScreenshotEvidenceUITests.swift`; `scripts/validate-agent-framework.sh` pipe handling; `PERCEPTION.md`; this ledger. Project settings, versions, and release state are unchanged.
- Deferred: broader test refactoring and product behavior changes. No user-facing behavior is intended to change.

## Regression contracts

The existing suite covers stale results and explicit cancellation. The new suite adds:

1. A current network failure returns the exact generation session, including source and provider context, after clearing busy state.
2. A thrown save callback reports the original error once and permits immediate retry with the same session.
3. Both `CancellationError` and `URLError.cancelled` finish generation and adjustment silently, without leaving busy state or active feedback behind.
4. Ordinary adjustment failures and thrown save callbacks clear feedback before reporting the original error.
5. Provider-supplied explanations survive; only missing explanations receive the requested feedback's rationale. Cancelling another saved tune leaves the active adjustment intact.
6. A successful callback can start a replacement request without the old request's cleanup clearing the new session.

Tests use a local immediate provider, explicit callback expectations, and observed busy-to-idle transitions. They do not access a network or real persistence, sleep to guess when work has finished, or inspect source text. Save failures are injected at the controller's throwing callback boundary; database behavior remains covered by existing persistence suites.

## Initial test-only verification (retained failure evidence)

Evidence root: `/tmp/forzadvisor-test-improvements-20260926` (owned by this task).
Execution host: local coordination Mac, arm64; macOS 27.0 (26A428). Primary Xcode 27.0 (27A266a); alternate Xcode 27.0 beta (27A5209h).
Project: `forzadvisor.xcodeproj`; shared scheme: `forzadvisor`; plan: `ReleaseVerify`.
Selected destination: ForzAdvisor ReleaseVerify 20260921, iOS 27.0 simulator.
User-visible behavior changed: none.

Source fingerprint (SHA-256 over sorted repository-relative file names, NUL, file bytes, NUL for app, tests, Xcode project, and test plan): `2633ca4ee91dcdfd44cdecb60af28e4698164f3e4170f8d6d50331701eb042e6`. File manifest: `source-manifest.sha256`. New test file SHA-256: `624a5a6a13488e9910ecfd62efa72261dc27b3b0f351d900b293a0e0d14808fa`. Documentation is excluded from the executable-source fingerprint.

| Gate | Tool or command | Target | Result | Evidence path | Warnings or gaps |
|---|---|---|---|---|---|
| Source preservation | `git status --porcelain=v1`, `git log -1` | Canonical checkout | PASS: clean intake | `initial-status.txt` | No existing edits |
| Deterministic tests | `ruby scripts/tests/forzadvisor_release_test.rb` | Release coordinator | PASS: 50 tests, 322 assertions | `release-tests.log` | No failures, errors, or skips |
| Framework validation | `scripts/validate-agent-framework.sh` | Framework state | PASS, including closeout | `framework.log` | No failures |
| Xcode build | XcodeBuildMCP `build_sim(buildForTesting: true)` | App and test targets | BLOCKED | `build.xcresult`, `build.log` | Unchanged `ContentView.swift:1417` exceeds compiler type-checking limit; new test file compiles without diagnostics |
| Compiler time-budget retry | Same MCP build, `OTHER_SWIFT_FLAGS=$(inherited) -Xfrontend -solver-expression-time-threshold=120` | Same source | BLOCKED: same error | `build-retry.xcresult`, `build-retry.log` | Increasing the time budget did not resolve the failure |
| Alternate toolchain | XcodeBuildMCP CLI `simulator build --build-for-testing`, explicit alternate `DEVELOPER_DIR` | Same source, Xcode 27A5209h | BLOCKED: same error | `build-alternate-xcode.xcresult`, `build-alternate-xcode.log`, `build-alternate-xcode-full.log` | Unmodified compiler budgets; new test file compiles without diagnostics; asset catalog reports missing device traits |
| Focused tests | Planned XcodeBuildMCP `test_sim` | `TuneWorkflowFailureTests`, `TuneWorkflowControllerTests`, `TuneWorkflowSessionTests` | NOT RUN: app test host cannot build | None | No runtime pass claimed; another project also occupied the simulator test lane |
| Broader regression | Planned XcodeBuildMCP `test_sim` | Unit suite | NOT RUN: same build blocker | None | Complete `ReleaseVerify` and cloud checks not run |
| UI / release | Not applicable | Unchanged app | Not run | None | No UI change, archive, upload, commit, or push |

All three builds used `SWIFT_TREAT_WARNINGS_AS_ERRORS=YES` and `GCC_TREAT_WARNINGS_AS_ERRORS=YES`; no Swift source warnings were reported. The alternate beta asset compiler also warned: `Could not get trait set for device iPhone19,3 with version 27.0`. That toolchain/runtime compatibility warning is retained in the full log; the alternate build is not a passing gate. The new file reached Swift compilation in both toolchains. Compilation alone does not verify its runtime assertions. At this initial test-only stage, app source, project settings, and test plan were byte-identical to the base commit.

Initial outcome: **Implemented; Xcode verification blocked**. The owner then requested the compiler fix below. These earlier build failures are retained; their source fingerprint does not describe the repaired artifact.

Cleanup: no simulator was booted or created. Task-owned Derived Data was removed; diagnostic result bundles, build logs, and source hashes remain in the evidence root for follow-up.


## Compiler repair and current verification

The failing `TuneResultView` constructor made Swift infer many large closures in one expression. Nine existing save, edit, capture, research, test-drive, and feedback callbacks now have explicitly typed local bindings. Their guards, eligibility conditions, captured values, and actions are preserved. A one-off whitespace-normalized expression comparison confirms preservation of the eight larger extracted handlers; the feedback closure was reviewed in the diff. No compiler-budget overrides are part of the fix.

Compiler-repair source fingerprint before subsequent test cleanup: `327ecd31e732650b2bb5cd3df0e2742623d392eb41c49ef0480339b5b24caea5`, calculated using the same algorithm above. Evidence root: `/tmp/forzadvisor-compiler-fix-20260926`; `source-manifest.sha256` lists the exact app, test, project, and plan files. Same repository/base/host/toolchain; Debug test products and the clean Release build use Xcode 27A266a. Runtime destination: task-owned **ForzAdvisor CompilerFix 20260926**, iPhone 18 Pro, iOS 27.0.

| Gate | Tool or command | Target | Result | Evidence path | Warnings or gaps |
|---|---|---|---|---|---|
| Preservation review | `git diff`, callback expression comparison | Nine extracted callbacks and prior test file | PASS | `callback-preservation.txt`, `source-manifest.sha256` | Pure eligibility checks retain their inputs; callback bodies are unchanged |
| Deterministic tests | `ruby scripts/tests/forzadvisor_release_test.rb` | Release coordinator | PASS: 50 tests, 322 assertions | `release-tests.log` | Zero failures/errors/skips |
| Initial narrow fix | XcodeBuildMCP build for testing | Feedback-only extraction | FAILED: solver limit moved to experiment callback | `build.xcresult`, `build.log` | Superseded by the final extraction |
| Debug app and test build | XcodeBuildMCP CLI `simulator build --build-for-testing` | `forzadvisor`, Debug | PASS, 18.3 seconds | `build-split.xcresult`, `build-split-full.log`, `tests.xctestproducts` | Normal compiler budgets; both Swift and C warnings treated as errors; no warnings |
| Clean Release build | XcodeBuildMCP CLI `simulator build --configuration Release` with new Derived Data | `forzadvisor`, Release | PASS, 54.8 seconds | `release-build.xcresult`, `release-build-full.log` | Normal compiler budgets; warnings as errors; no warnings |
| Workflow tests | XcodeBuildMCP prepared test products, three `-only-testing` filters | 21 tests in the three workflow suites | PASS: 21 passed, no failures/skips | `focused-tests.xcresult`, `focused-summary.json` | Includes all ten new tests |
| Unit regression before cleanup | XcodeBuildMCP prepared test products, `-only-testing:forzadvisorTests` | Complete unit target | PASS: 585 tests, zero failures/skips | `unit-final.xcresult`, `unit-final-full.log`, `unit-final-summary.json` | SwiftUI reflection warnings removed; raw log exposed temporary-store cleanup errors, addressed below |
| Focused UI | XcodeBuildMCP prepared test products, three UI filters | Source entry, result save/edit, manual flow screenshots | FAILED: one passed, two failed | `ui-tests.xcresult`, `ui-tests-full.log`, `ui-attachments/` | Source-screen assertions passed; burst typing lost characters in the other two tests |
| Stable-runner preflight | Shared `ssh_runner_preflight.sh` | `stable-xcode-26.3-intel` | PASS | `runner-preflight.log` | Identity, toolchain, credentials-file invariants, and signing identity checked; no archive/upload |
| Repository release preflight | `scripts/release preflight --ref main` | Local source | BLOCKED: expected uncommitted-source gate | `preflight-errors.log` | All other preflight checks produced no errors; rerun on immutable source before delivery |

The MCP build endpoint twice reported missing scheme despite successful session-default readback, before invoking Xcode. The documented XcodeBuildMCP CLI with explicit project/scheme/destination supplied the equivalent build verifier; raw `xcodebuild` was not used for these builds. Runtime results and final cleanup are recorded below. Light unit tests ran on a task-owned simulator; UI execution waited for the other project’s active UI batch to finish.

The pinned release toolchain was rechecked against Apple’s [current SDK minimums](https://developer.apple.com/news/upcoming-requirements/?id=04282026a) and [submission timeline](https://developer.apple.com/app-store/submitting/) on 2026-09-26: iOS 26 SDK remains the current minimum, with iOS 27 SDK required starting April 2027. The configured iOS 26.2 SDK meets that current minimum. Runner capacity probe found approximately 16.8 GiB free and no active Xcode builds; recheck immediately before archive work.


## Test harness cleanup and final gates

The original source-screen contract test recursively reflected an unmounted SwiftUI view, emitting two State/PhotosPickerItem warnings. Its meaningful checks now run against real accessibility buttons and labels in `ForzAdvisorUITests.testTuneSourceOffersOnlySupportedEntries`. The unit count changes from 586 to 585; no product contract assertion is dropped, and the unsupported internal-property-name reflection assertion is removed.

The 585-test run exposed asynchronous CoreData errors after two disk-backed persistence tests deleted their stores while deliberate corruption remained pending. The affected contexts now disable autosave and defer rollback before temporary-directory removal. Explicit save/reopen/delete and corruption assertions remain intact. This is test fixture cleanup, not an app persistence change.

The initial three-case UI batch passed the source-screen contract, but two existing manual flows failed. The screenshot case expected `55` and read `5`; the result test's failure hierarchy recorded year `197`, make `Mz`, model `Ma`, and PI `70` after whole-string input. Form validation correctly refused to continue. The common input helper now waits for each typed character to appear, failing immediately on a mismatch without retyping or repairing values. The result test uses this helper, scrolls controls into the interaction viewport, and explicitly waits for navigation. Screenshot rendering waits for the actual disclaimer instead of an inverted half-second timer.

The initial UI run also emitted two `Invalid frame dimension (negative or non-finite)` SwiftUI runtime warnings when opening the unchanged Manual Entry screen. The warning has no source location; source review found no negative frame arithmetic in that screen. Its origin has not been established. The iOS 27 runtime separately emitted duplicate private JetEngine/JetAsset class and CoreUI device-trait diagnostics. These are retained; the failed run is not a clean gate.

Combined-run source fingerprint: `602112c45b4f1b0bf125e7f82ac98bf1f88e93fdf470cb70eff44ef7c92bff3c`; manifest: `verified-source-manifest.sha256`. The final UI helper build passed in 3.5 seconds with no compiler warnings (`build-ui-repair.xcresult`, `build-ui-repair-full.log`). The intermediate persistence cleanup build passed in 31.9 seconds (`build-cleanup.xcresult`, `build-cleanup-full.log`). The prior 585-unit run before persistence cleanup used fingerprint `b142fb1afd1a7e2b259a926e133703467665099259c9ed1a9e3e08f2100b8dd2` (`pre-cleanup-source-manifest.sha256`). App/project sources are unchanged since the clean Release build; only tests changed afterward. The combined run completed with 587 passes and one failure: all 585 unit tests and the source/screenshot UI cases passed; the result UI case required its original scroll-to-create step for the lazy generation button. That step is restored, and the affected UI test passed its final rerun. Earlier results retain their identities and are not silently replaced.

### Final verification record

Final app/test source fingerprint: `35fd074a61b553491c385e65ac3d25a00a284e69154062307dd36efaf88a9892` (`final-source-manifest.sha256`). The final change after the combined run is only the scroll-to-create step in `TuneResultUITests.swift`. `narrow-retry-preservation.txt` confirms that the app, project, all unit tests, shared UI helper, source-screen test, and screenshot-flow test are byte-identical to their passing versions. `release-source-preservation.txt` confirms all 204 app/project files match the clean Release build. Unaffected passing gates are retained; the affected result UI case is rerun on the final build.

| Gate | Tool or command | Target | Result | Evidence path | Warnings or gaps |
|---|---|---|---|---|---|
| Final Debug build | XcodeBuildMCP CLI `simulator build --build-for-testing`, warning-as-error flags | App and all test targets | PASS, 2.0 seconds | `build-final-ui.xcresult`, `build-final-ui-full.log` | No compiler warnings |
| Full unit regression | XcodeBuildMCP CLI prepared products, `-only-testing:forzadvisorTests`, serial | 585 unit tests | PASS: 585 passed, zero failures/skips | `verification.xcresult`, `verification-full.log`, `verification-summary.json` | No CoreData cleanup errors or unmounted State warnings remain |
| Source-screen UI | Same batch, source-screen test filter | Supported entry buttons and absent unsupported claims | PASS, 19.104 seconds | `verification.xcresult` | No warning in this case |
| Manual workflow UI | Same batch, screenshot-flow filter | Form entry, generation, saving, Evidence Hub | PASS, 174.487 seconds | `verification.xcresult`, `screenshots/` | One existing SwiftUI layout warning on entry, source unknown |
| Result UI prior attempt | Same batch, result metadata test filter | Result/save/edit flow | FAILED before result: lazy generation button not created | `verification.xcresult`, `verification-full.log` | Scroll-before-existence step restored; failure retained |
| Affected UI retry | XcodeBuildMCP CLI `simulator test`, final prepared products, one result UI filter | Result/save/edit flow | PASS: one test, 151.719 seconds (200.2 seconds including setup) | `result-ui-final.xcresult`, `result-ui-final-full.log`, `result-ui-final-summary.json` | Same existing SwiftUI layout warning; zero failures/skips/expected failures |
| Framework validator | `scripts/validate-agent-framework.sh`, three consecutive final runs | Repository framework | PASS | `framework-final-1.log` through `framework-final-3.log` | Fixed pre-existing SIGPIPE false failures; required authority marker restored |
| Diff and secret review | `git diff --check`; scoped credential/private-key pattern scan | Intended write set | PASS | `secret-scan.txt` | Local uncommitted changes; no release/version edits |

Runtime destination: task-owned iPhone 18 Pro, iOS 27.0, UUID `DE6758B1-C03D-4DB4-A91D-7BA8995CA3F1`. Runtime calls used `-parallel-testing-enabled NO`. The combined and final UI runs allow 600 seconds per case for full screenshot flows; assertions still have short condition-based waits. Exact CLI argument objects are retained in `verification-arguments.json` and `result-ui-final-arguments.json`. XcodeBuildMCP owns test execution; `xcresulttool` is used only for summary/attachment inspection.

Numbered runtime flow and retained screenshots:

1. Launch an empty garage (`screenshots/01-empty-garage-light.png`).
2. Open the supported tune-source choices (`screenshots/02-new-tune-source-light.png`).
3. Enter a complete manual fixture and verify exact values (`screenshots/03-manual-entry-validation-ready-light.png`).
4. Choose Road and inspect provider preflight (`screenshots/04-discipline-provider-preflight-light.png`).
5. Generate and display the result (`screenshots/05-result-top-light.png`).
6. Inspect the settings availability disclaimer (`screenshots/06-result-available-settings-light.png`).
7. Inspect the optional evidence explanation (`screenshots/07-result-evidence-summary-light.png`).
8. Save and open Evidence Hub (`screenshots/08-evidence-hub-light.png`).

The source choices, filled form, result, and Evidence Hub screenshots were visually inspected. Logs were inspected separately. These UI cases verify workflow and test-fixture reliability; they do not assert real-world numeric tuning accuracy or replace human acceptance.


## Delivery gate

**TestFlight blocked.** Read-only status found an existing coordinator candidate 1.41.2 (87), commit `f3318c37dba4e745a31fda4e862468db75a11e16`, at `human_verification_pending`. This checkout's release configuration is 1.41.1 (78); the coordinator reports `stable-runner state identity mismatch: marketing_version`. That pending candidate cannot be rolled over automatically. Its state is preserved; no version/build allocation, commit, push, archive, upload, or tester reassignment occurred.

The published 1.41.1 (78) was separately confirmed `VALID` / `READY_FOR_SALE`; it is not the pending beta. Evidence: `asc-status.json`, `candidate-status-error.log`. Complete local `ReleaseVerify` and GitHub Actions for an immutable revision remain required before any later distribution; neither is claimed by the proportional local gates here. The next delivery decision is the owner's acceptance/fix/block verdict for existing build 87, followed by reconciliation with the intended source/version.


## Closeout

- Highest delivery state: implemented and scoped local verification complete, with the existing runtime warning disclosed. No cloud verification or distribution performed.
- Source remains uncommitted on `agent/astra-test-improvements`, based on `b840cb2e863924103fa8717ec2cbfe582eb28a9b`. No commit, push, PR, version change, or external release mutation.
- Framework validation, final diff check, source-fingerprint preservation, and changed-file secret pattern review pass.
- Removed the task-owned simulator, both Derived Data directories, and all five prepared test-product bundles. Evidence roots retain result bundles, complete logs, source manifests, failed-attempt diagnostics, and eight named screenshots. `cleanup.txt` records the exact owned resources removed. No other project's simulator, checkout, or build resources were changed.
- Remaining release gates: owner verdict on the existing 1.41.2 (87) candidate; reconcile source/version; resolve or establish the origin of the SwiftUI layout warning; complete local `ReleaseVerify`; commit/push an immutable revision; exact-revision GitHub Actions; stable-runner delivery. No App Review authority granted.


The closeout validator initially rejected the shortened authority marker, which was restored verbatim, and exposed a pre-existing pipeline race. With `pipefail`, `sed | grep -q` returned pipeline statuses `141 0` even though the name/description matched. The three frontmatter checks now consume the complete pipe with stdout redirected to `/dev/null`; their patterns and acceptance rules are unchanged. Three consecutive full validator runs passed. This tooling-only change does not affect app/test binaries. Final validator SHA-256: `b39cc588b3aa460d640329261d3c6819b1e868b1dd3198b2934828beeed6f0fe` (`framework-validator-sha256.txt`).


## Explicit commit, push, and TestFlight request

The owner subsequently requested commit, push, and TestFlight delivery if needed. The release contract remains ForzAdvisor / `com.michaelwilliams.forzadvisor` / team `5RGU344VJR`, iOS, configured `Internal` group, and logical archive profile `stable-xcode-26.3-intel`. App Review is not authorized. This branch retains the verified source; the existing 1.41.2 (87) candidate comes from another branch and must not be represented as containing this patch. Publish these scoped changes first, then revalidate the existing candidate and all release gates before any new build allocation or upload.
