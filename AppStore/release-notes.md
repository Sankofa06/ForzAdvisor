# Release Notes

## Version 1.4.0 (Build 24) - 2026-07-23

- Added local Beta Validation Missions that turn eligible saved FH5 and FH6 setups into exact next testing steps.
- Missions recheck the existing Research Lab, Tire Lab, Upgrade Lab, and Record Test Drive safety boundaries before opening a workflow.
- Added an optional aggregate progress share containing counts only, with no car names, tune values, notes, identifiers, screenshots, or analytics.

## Version 1.3.0 (Build 23) - 2026-07-23

- Added plan-scoped FH5 Research Review for exact permission-bound Research Lab JSON, stored separately from local author observations.
- Added fail-closed canonical validation, payload bounds, fingerprint binding, replay quarantine, and exact build, platform, catalog, car, tire, drivetrain, and gear grouping.
- Reports only single, replicated, or conflicting raw observations and never averages values, creates a ruleset, contacts a provider, or enables numeric FH5 tuning.

## Version 1.2.1 (Build 22) - 2026-07-22

- Added FH5 Research Lab for complete, manually entered first-party observations of an untouched stock car's tuning menu, stored separately from the plan without contacting a tuning provider.
- Added off-by-default permission for deidentified structured observation reuse and deterministic JSON sharing, while keeping the record explicitly evidence-only.
- Bound observations to the current saved catalog plan and exact matching Upgrade Lab game build so stale evidence cannot surface or be shared.

## Version 1.2.0 (Build 21) - 2026-07-22

- Added a provider-independent local FH5 build planner for untouched stock cars selected from the reviewed catalog.
- Added Upgrade Lab verification and up to three exact tuning-control purchase paths using only parts the player confirms are offered in their game build.
- Kept numeric FH5 tuning, guided refinement, verified tune sharing, and test-drive validation unavailable until a separate FH5 ruleset is validated.
- Hardened saved-tune compatibility so legacy or malformed FH5 results cannot expose stale numeric settings, while valid legacy FH6 tunes remain unchanged.

## Version 1.1.16 (Build 20) - 2026-07-22

- Added Record Test Drive for eligible saved FH6 exact-stock tunes, with structured session conditions, verdicts, and handling feedback.
- Added explicit, off-by-default permission for deidentified benchmark reuse plus deterministic JSON sharing through the system share sheet.
- Bound validation records to the current verified tune revision, exact local tire and upgrade evidence, observed game build, and current FH6 ruleset.
- Kept records local unless shared and excluded free-form track text, notes, screenshots, telemetry, device data, provider details, and internal tune identifiers.

## Version 1.1.15 (Build 19) - 2026-07-22

- Tire Lab now records the stock car's forward gear count alongside the exact FH6 tire-pressure ranges, compound, and observed game build.
- Gear count starts blank, accepts localized whole-number input, excludes reverse, and blocks verification instead of guessing when the value is missing or invalid.
- Older tire observations remain readable but must be re-verified before they can supply the newly versioned gear-count evidence.

## Version 1.1.14 (Build 18) - 2026-07-22

- Added a privacy-safe Share verified build action for exact observed game builds with at least one freshly verified setting.
- Shared cards are rechecked before export and include only the game, car, tune context, canonical verified settings, and at most one exact tuning-control path.
- Excluded garage notes, screenshots, provider details, evidence records, identifiers, timestamps, and withheld values; sharing remains user-initiated through the iOS system share sheet with no share analytics or history.

## Version 1.1.13 (Build 17) - 2026-07-22

- Added a Contextual Copilot that is available throughout the tuning workflow and explains the safest next step for the current screen.
- Added local, deterministic answers for trust, missing verification, and privacy without sending Copilot questions to a model or network service.
- Kept Copilot guidance fail-closed: it summarizes verified status and eligibility without reading unsaved form edits, exposing raw tune values, or inventing parts, prices, PI, or performance claims.

## Version 1.1.12 (Build 16) - 2026-07-22

- Added a local Upgrade Lab for FH5 and FH6 stock catalog cars that records which tuning-control parts the exact in-game upgrade shop offers.
- Added up to three exact alternative tuning-control buy lists using only user-verified parts, with game-build checks and no invented PI, credit, entitlement, or performance claims.
- Preserved verified tire observations and upgrade availability in either Tune Lab order, including saved-tune reopen and copyable build plans.

## Version 1.1.11 (Build 15) - 2026-07-22

- Added an FH6 Tune Lab that records exact stock tire-pressure slider ranges locally and regenerates the tune against them.
- Added tune coverage and build-plan guidance while withholding generated values that do not pass capability, range, and provenance checks.

## Version 1.1.10 (Build 14) - 2026-07-22

- Added an explicit FH5/FH6 selector to manual entry and screenshot review.
- Preserved the selected game and reviewed OCR values when returning from tune-type selection.
- Removed a defensive crash path from discipline-specific alignment generation without changing existing tune values.

## Version 1.1.9 (Build 13) - 2026-07-22

- Added a searchable starter catalog for Forza Horizon 5 and Forza Horizon 6 with reviewed stock values for six cars.
- Added source links, catalog revision details, and clear verification status before tuning and after reopening a saved tune.
- Preserved catalog origin when values are edited while clearly labeling modified data.
- Added the internal capability foundation for future exact upgrade requirements without guessing unavailable parts.

## Version 1.1.8 (Build 12) - 2026-07-21

- Added the game-aware tuning foundation for Forza Horizon 5 and Forza Horizon 6, including their distinct PI class bands.
- Added D and R class support while preserving X-class saved tunes and legacy garage data.
- Prevented FH5 requests from silently using the existing FH6 offline formulas until a separately validated FH5 ruleset is available.

## Version 1.1.7 (Build 11) - 2026-07-21

- Expanded app compatibility to iOS 17 and later while preserving the offline-first tuning workflow.
- Kept optional on-device generation safely isolated to supported iOS versions, with clearer fallback status on older devices.

## Version 1.1.6 (Build 10) - 2026-07-16

- Made manual entry safer with blank required fields, clearer validation, keyboard controls, and easier class and drivetrain selection.
- Improved photo and screenshot OCR reliability with cancellation, retry, and stale-result safeguards while keeping image processing on device.
- Added clearer provider and fallback status plus more accessible, copy-friendly tune results.
- Fixed localized decimal handling so manual input and guided tuning adjustments remain accurate across regions.
- Made the PI field easier to tap during manual entry.

## Version 1.1.5 (Build 8) - 2026-06-25

- Added guided tuning refinement: describe what happened on a run, then get bounded tune changes with explanations for each adjusted setting.
- Improved garage rows and pre-generation setup summaries so saved tunes and input details are easier to scan.

## Version 1.1.3 (Build 6) - 2026-06-15

- Refined the full tune workflow from photo, screenshot, or manual entry through discipline selection and generated tune review.
- Added a saved garage experience with search, discipline filters, editable saved tunes, and copyable menu-order setup sections.
- Added offline-first tuning with optional on-device model assistance and optional Anthropic API mode for users who provide their own key.
- Improved setup, provider configuration, settings flows, and saved-content reliability.
- Added App Store-ready privacy, support, metadata, screenshot, and marketing materials for the TestFlight release path.

## App Store What's New

Beta Validation Missions now turn your saved FH5 and FH6 setups into exact local testing steps for Research Lab, Tire Lab, Upgrade Lab, and Record Test Drive. Share aggregate beta progress only when you choose, without exposing car names, tune values, notes, identifiers, or screenshots.

## TestFlight Notes

From the garage, open Beta Validation Missions with an empty garage and confirm it offers one starter mission for FH5 and one for FH6. Save an FH5 plan or FH6 tune, reopen the mission board, and confirm it replaces the matching starter with only the eligible Research Lab, Tire Lab, Upgrade Lab, or Record Test Drive actions.

Open a saved-setup mission and confirm it enters the existing capture workflow for that exact setup. Complete the workflow, then reopen Beta Validation Missions and confirm the completed mission disappears. If a setup changes or is deleted while the board is open, the stale mission must fail safely instead of opening the wrong setup.

Use Share Beta Progress and confirm the preview contains only aggregate counts and the ForzAdvisor marketing link. It must not contain car names, disciplines, tune settings, notes, screenshots, tune or evidence identifiers, provider details, or analytics.

Please also test New Tune -> Choose a Car -> select an FH5 catalog car -> Use This Car -> choose a discipline. Confirm the result is clearly labeled Build Plan, contains no numeric tuning settings, and offers Upgrade Lab without contacting the selected model or API provider.

Save the plan, open FH5 Research Lab, and confirm every expected control requires Adjustable, Shown locked, or Not shown. For Adjustable, enter the observed minimum, maximum, step, and restored current value. Confirm incomplete or contradictory observations cannot save, reuse/JSON sharing starts off, and returning to the plan does not expose numeric FH5 tune settings.

In Upgrade Lab, enter the exact FH5 game build, confirm the untouched stock car, and mark every listed part Offered or Not offered. When all parts are offered, confirm the rebuilt plan shows three deterministic alternatives and that Copy build plan includes only the exact verified paths. Save, reopen, and confirm the same paths remain available.

Please also confirm manual, OCR, edited-catalog, and otherwise unverified FH5 inputs still refuse numeric generation. Existing FH6 catalog, manual, Tire Lab, refinement, sharing, and Record Test Drive workflows should behave unchanged.

The starter catalog contains six community-crosschecked cars across both games. Confirm catalog values and upgrade availability in game and report discrepancies. FH6 formulas remain experimental; catalog provenance does not validate formula accuracy.

Offline use requires no account or API key. FH5 build plans and Research Lab observations stay local unless the user explicitly shares an eligible deidentified JSON record. Camera and photo import are optional, screenshots are processed on device, and Anthropic API mode requires the tester to provide their own key for FH6.

## Reviewer Notes

No login is required. Beta Validation Missions is always visible in the garage and derives its current list locally from eligible saved setups. Empty garages receive FH5 and FH6 starter missions. Saved setups may receive Research Lab, Tire Lab, Upgrade Lab, or Record Test Drive missions only when their existing workflow eligibility passes. The board does not create evidence or tuning claims, and its optional progress share contains aggregate counts only.

To review the FH5 flow, choose New Tune -> Choose a Car -> Forza Horizon 5 -> select a car -> Use This Car -> Road, then save the plan. The app creates a local build plan with no numeric tuning values and offers Research Lab for first-party stock-menu evidence plus Upgrade Lab for user-confirmed purchase paths. For numeric tuning, select an FH6 car instead. Manual entry, camera, and photo import remain available.

## Previous TestFlight Notes

### Version 1.1.1 (Build 4) - 2026-06-01

- Improved reliability, usability, and app polish.

### Version 1.1.0 (Build 3) - 2026-06-01

- Improved data management reliability for saved app content.
- Improved navigation and workspace status visibility.
