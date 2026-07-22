# Release Notes

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

Choose a car from a new FH5/FH6 starter catalog and begin with reviewed stock values. Every catalog entry shows its verification status and sources, and saved tunes retain their catalog origin—even when you edit the values before tuning.

## TestFlight Notes

Please test New Tune -> Choose a Car with both FH5 and FH6. Verify search, stock values, source links, Edit Values and Cancel, discipline selection, generated-tune provenance, saving, and reopening from the Garage. The first catalog contains six community-crosschecked cars; confirm values in game and report discrepancies.

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
