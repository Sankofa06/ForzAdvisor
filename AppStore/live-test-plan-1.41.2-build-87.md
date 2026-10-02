# Live Test Plan — ForzAdvisor 1.41.2 material improvements

App: ForzAdvisor
Version / build: 1.41.2 (87)
Commit: f3318c37dba4e745a31fda4e862468db75a11e16
TestFlight group: configured internal group 914040ee-a642-4a67-8339-36d4af66b3d3
Recommended device / OS: your enrolled iPhone on the current TestFlight-supported iOS; use an iPhone 17 Pro / iOS 26.5 equivalent if available
What changed: clearer readiness and available-setting states, truthful FH5 planner preflight, OCR unit normalization with retained source evidence, and review-before-persist refinement proposals
Risk focus: misleading “ready” claims, silent unit conversion, accidental refinement persistence, and regressions in the first-tune flow
Required setup: install build 87 from the existing internal TestFlight group; keep one disposable test tune available; have one in-game screenshot containing clearly labeled kW/Nm values if testing OCR
Known limitations: OCR quality depends on the screenshot; FH5 remains a local, plan-only build-planner path. Local simulator verification was interrupted by CoreSimulator infrastructure failures, so TestFlight device verification is the acceptance gate.
Correction path if a scenario fails: stop at the failed scenario, capture the screen and exact step, and reply with `NEEDS FIXES` or `BLOCKED`; do not delete a saved tune or continue through data loss.

## Scenarios

### 1. First-tune flow states readiness truthfully

Starting state: Fresh install or an empty Garage.
Steps:
1. Tap Start First Tune (or New Tune), choose Manual Entry, and enter a disposable car such as 1997 Mazda Miata, 2345 lb, 55% front weight, PI 750, S1, RWD.
2. Continue to Road, inspect Preferred method and Readiness, then generate the plan and scroll through the result and Available settings sections.
3. Save the result, return to the Garage, and reopen the saved tune.
Expected: The preflight identifies the actual local FH5 plan-only route. The result separates completion/readiness from the presence of numeric settings; when no usable numeric values exist it does not claim “Ready to use” and keeps the next in-game step explicit. Save status and reopening remain clear.
Evidence to capture: screenshots of the discipline preflight, result status, Available settings section, and reopened saved tune.

### 2. OCR preserves evidence and makes units explicit

Starting state: New Tune source selection, with an in-game screenshot that visibly labels power in kW and torque in Nm.
Steps:
1. Choose Import Screenshot, run on-device Vision OCR, and review every extracted field before continuing.
2. Confirm the values and inspect the confirmation/result copy for power and torque units; also try a unitless manual confirmation only if the flow offers one.
Expected: OCR/source evidence remains attributable to the imported screenshot. kW and Nm are converted to hp and lb-ft before the user accepts the values, while unitless manual values are not silently assigned a unit. The confirmation surface makes the accepted units obvious.
Evidence to capture: the OCR review screen, converted hp/lb-ft values, and any source/evidence disclosure.

## Regression Checks

### 3. Refinement is preview-first and persistence is deliberate

Starting state: A saved tune with eligible numeric settings and a completed result screen.
Steps:
1. Scroll to Saved refinement, choose one observed symptom, and review the generated proposal without applying it.
2. Verify Current and Proposed values, then tap Discard proposal; repeat once and tap Apply refinement, reopen the tune, inspect adjustment history, and use Undo while it is offered.
Expected: The proposal explicitly says the saved tune has not changed. Discard removes the proposal and leaves the saved tune/history unchanged. Apply persists only after explicit confirmation, records the adjustment, and offers the short undo window; reopening shows the correct persisted state.
Evidence to capture: preview-only proposal, unchanged state after discard, applied history, and undo/reopened result.

### 4. Launch, settings, Step Guide, and persistence remain usable

Starting state: Build 87 installed with at least one saved tune.
Steps:
1. Relaunch the app, open Settings, and inspect the provider card; return to Garage and open the Step Guide.
2. Verify Next step, What can I trust?, What is missing?, and Privacy are reachable; reopen the saved tune and scroll the result at the largest comfortable Dynamic Type size.
Expected: Relaunch preserves the Garage and saved tune without a crash or reset. Provider copy truthfully describes the local/offline path, Step Guide choices remain reachable, navigation and text remain legible at larger type, and the saved result still opens with its status/evidence sections intact.
Evidence to capture: Settings provider card, Step Guide choices, larger-type result, and reopened saved tune.

## Stop Conditions

- Stop on a crash, data loss, account or signing confusion, destructive migration, or privacy/security concern.
- Record the scenario, step, actual result, and evidence; do not continue through a destructive failure.

## Owner Response

The TestFlight build is ready. Run the numbered plan and reply by copying this block. Keep each Expected line as written and fill in Actual, Result, Evidence, and Notes.

```text
App: ForzAdvisor
Build: 1.41.2 (87)
Device / OS:

1. First-tune flow states readiness truthfully
Expected: The preflight identifies the actual local FH5 plan-only route. The result separates completion/readiness from the presence of numeric settings; when no usable numeric values exist it does not claim “Ready to use” and keeps the next in-game step explicit. Save status and reopening remain clear.
Actual:
Result: PASS | FAIL | BLOCKED
Evidence:
Notes:

2. OCR preserves evidence and makes units explicit
Expected: OCR/source evidence remains attributable to the imported screenshot. kW and Nm are converted to hp and lb-ft before the user accepts the values, while unitless manual values are not silently assigned a unit. The confirmation surface makes the accepted units obvious.
Actual:
Result: PASS | FAIL | BLOCKED
Evidence:
Notes:

3. Refinement is preview-first and persistence is deliberate
Expected: The proposal explicitly says the saved tune has not changed. Discard removes the proposal and leaves the saved tune/history unchanged. Apply persists only after explicit confirmation, records the adjustment, and offers the short undo window; reopening shows the correct persisted state.
Actual:
Result: PASS | FAIL | BLOCKED
Evidence:
Notes:

4. Launch, settings, Step Guide, and persistence remain usable
Expected: Relaunch preserves the Garage and saved tune without a crash or reset. Provider copy truthfully describes the local/offline path, Step Guide choices remain reachable, navigation and text remain legible at larger type, and the saved result still opens with its status/evidence sections intact.
Actual:
Result: PASS | FAIL | BLOCKED
Evidence:
Notes:

Overall result: ACCEPT | NEEDS FIXES | BLOCKED
Anything unexpected:
```
