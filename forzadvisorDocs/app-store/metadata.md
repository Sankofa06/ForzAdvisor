# ForzAdvisor App Store Metadata

Last updated: 2026-08-09

## App Name

ForzAdvisor

## Subtitle

Photo-to-tune racing setups

## Promotional Text

Turn your own performance-screen photo, screenshot, or manually entered car details into a clear, menu-order racing setup.

## Description

ForzAdvisor is an unofficial racing-game tuning companion for players who want faster setup decisions without losing control of the numbers.

Start a tune from a photo, import a screenshot, or enter the car and performance details manually. Review every detected or entered value before generation, then choose road, drift, drag, dirt, cross-country, or touge.

ForzAdvisor does not include a bundled car roster. You provide the car identity and performance values used for each setup.

For FH6, ForzAdvisor can generate menu-order numeric settings using offline formulas. Experimental settings are projected through local capability and range checks, and unsupported values are withheld instead of guessed.

For FH5, ForzAdvisor creates a local build plan without numeric tuning settings. Numeric FH5 tuning remains unavailable until a separately validated ruleset exists.

Save setups in a local garage, search by car, filter by discipline, copy eligible settings or plans, and use Guided Refinement after a run. Contextual Copilot provides deterministic workflow guidance using allow-listed local context.

ForzAdvisor runs offline by default. Camera photos and imported screenshots are processed on device with Apple Vision OCR. Optional Apple on-device model assistance can help when available. Optional API mode lets advanced users provide their own Anthropic API key; confirmed car details, the selected discipline, current tune details, and player notes are sent only when that mode is selected.

No account is required. The app includes no advertising or analytics SDKs.

ForzAdvisor is not affiliated with, endorsed by, or sponsored by Microsoft, Xbox, Turn 10 Studios, Playground Games, or the Forza franchise.

## Categories

- Primary category: Utilities
- Secondary category: Games
- Target devices: iPhone

## Keywords

racing,tuning,garage,drift,road,drag,setup,ocr,cars,advisor

## Privacy Policy

- Privacy Policy URL: https://Sankofa06.github.io/ForzAdvisor/privacy/
- User Privacy Choices URL: https://Sankofa06.github.io/ForzAdvisor/privacy/

## Support URL

https://Sankofa06.github.io/ForzAdvisor/support/

## App Review Notes

No login, test account, or API key is required.

This build does not bundle a car catalog or roster. It also contains no official game logos, vehicle artwork, or copied game screenshots. Users enter car details themselves or select a photo or screenshot from their own device for on-device OCR.

Suggested review path:

1. Launch the app.
2. Tap New Tune.
3. Tap Enter Manually.
4. Choose FH6 and enter a fictional car identity plus valid weight, front-weight percentage, PI, class, and drivetrain values.
5. Tap Next.
6. Choose Road.
7. Review the generated menu-order setup.
8. Save it to the local garage.
9. Reopen the saved setup to test copy and Guided Refinement.

A second path is New Tune -> Import Screenshot. The system photo picker is used, OCR runs on device, and every detected value must be confirmed before tuning.

FH5 manual entry produces a provider-independent local build plan without numeric tuning settings. FH6 can use offline formulas by default. Optional Apple on-device model assistance and user-key Anthropic API mode apply only when selected in Settings.

Camera permission is optional and requested only after the reviewer chooses Take Photo. Photo import uses the system picker. No account is required.

## App Information

- Bundle ID: com.michaelwilliams.forzadvisor
- SKU: forzadvisor-ios
- Current project version: 1.40.8
- Current project build: 75
- Copyright: 2026 Michael Williams
- Marketing URL: https://Sankofa06.github.io/ForzAdvisor/

## What's New Copy

Bundled car rosters have been removed.

Start every tune from your own photo, screenshot, or manually entered car details. Empty-garage starter missions now open manual entry directly.

## Export Compliance Notes

The app uses Apple platform security, Keychain, URLSession over HTTPS, and system frameworks. It does not implement custom cryptography. Confirm the final App Store Connect export compliance answers before App Review submission.

## Screenshot Shot List

Use the screenshot plan in `AppStore/screenshots-spec.md`.

Recommended order:

1. Start Tunes Faster
2. Scan, Import, or Type
3. Confirm Every Stat
4. Pick the Drive Style
5. Copy Menu-Order Settings
6. Refine After Every Run
