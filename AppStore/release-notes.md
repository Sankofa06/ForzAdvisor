# Release Notes

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

Choose FH5 or FH6 directly when entering a car manually or reviewing a screenshot. Your selected game and reviewed values now stay intact if you return from tune-type selection.

## TestFlight Notes

Please test New Tune -> Enter Manually with both FH5 and FH6. Verify that each game's class and PI rules apply, then go Next and Back and confirm the selected game and values are preserved. If you import a screenshot, change the game during review and verify that Back from tune-type selection restores the edited review.

The searchable starter catalog remains available for both games with six community-crosschecked cars. Confirm catalog values in game and report discrepancies.

FH5 stock data is available, but offline FH5 tune generation remains intentionally unavailable until its separate ruleset is validated. FH6 offline formulas remain experimental; catalog provenance does not imply formula validation.

Offline formula tuning does not require an account or API key. Camera and photo import are optional. Screenshots are processed on device. Anthropic API mode requires the tester to provide their own API key in Settings.

## Reviewer Notes

No login is required. Reviewers can complete the catalog flow through New Tune -> Choose a Car -> select an FH6 car -> Use This Car -> Road -> Save. Manual entry, camera, and photo import remain available.

## Previous TestFlight Notes

### Version 1.1.1 (Build 4) - 2026-06-01

- Improved reliability, usability, and app polish.

### Version 1.1.0 (Build 3) - 2026-06-01

- Improved data management reliability for saved app content.
- Improved navigation and workspace status visibility.
