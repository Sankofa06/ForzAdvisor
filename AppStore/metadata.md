# ForzAdvisor App Store Metadata - Version 1.0

Last updated: 2026-05-31

## App Information

- App name: ForzAdvisor
- Bundle ID: com.michaelwilliams.forzadvisor
- SKU: forzadvisor-ios
- Version: 1.0
- Build: 1
- Primary category: Utilities
- Secondary category: Games
- Target devices: iPhone
- Copyright: 2026 Michael Williams

## Localized Metadata - en-US

- Name: ForzAdvisor
- Subtitle: Photo-to-tune racing setups
- Promotional text: Capture or enter car stats, pick a discipline, and get a drive-ready setup with offline formulas, saved garage history, and optional AI tuning.
- Keywords: racing,tuning,garage,drift,road,drag,setup,ocr,cars,advisor
- Support URL: https://blackslabpro.github.io/ForzAdvisor/support/
- Privacy Policy URL: https://blackslabpro.github.io/ForzAdvisor/privacy/
- Marketing URL: https://blackslabpro.github.io/ForzAdvisor/

## Description

ForzAdvisor is an unofficial tuning assistant for racing-game players who want faster setup decisions without losing control of the numbers.

Start with a photo, imported screenshot, or manual entry. Confirm the car's weight, front weight percentage, performance class, PI, and drivetrain, then choose a discipline like road, touge, drift, dirt, cross-country, or drag. ForzAdvisor returns a complete tune in menu order, including tires, gearing, alignment, springs, damping, aero, brakes, differential, and practical driving notes.

Save tunes to a local garage, search by car, filter by discipline, copy full setups, and make quick feel adjustments after testing on track.

ForzAdvisor runs offline by default using deterministic local formulas. Optional API mode lets advanced users connect their own Anthropic API key for AI-assisted tuning; screenshots stay on device and are not uploaded.

ForzAdvisor is not affiliated with, endorsed by, or sponsored by Microsoft, Xbox, Turn 10 Studios, Playground Games, or the Forza franchise.

## What's New

Version 1.0 introduces the full ForzAdvisor tuning workflow: photo and screenshot OCR, manual car entry, discipline-based tuning, saved garage history, copyable tune output, and optional AI-assisted tune generation with offline fallback.

## App Review Notes

No login or test account is required.

Suggested review path:

1. Launch the app.
2. Tap New Tune.
3. Tap Enter Manually.
4. Use the prefilled starter values or edit the car details.
5. Tap Next.
6. Choose any discipline.
7. Review the generated tune and tap Save.
8. Return to the garage and reopen the saved tune.

Camera access is optional and only used to photograph a racing-game performance screen for on-device OCR. Photo import uses the system photo picker. Offline formula tuning is the default provider. API mode is optional and only works if the reviewer enters their own Anthropic API key in Settings.

## Export Compliance Notes

The app uses Apple platform security, Keychain, URLSession over HTTPS, and system frameworks. It does not implement custom cryptography. Confirm the final App Store Connect export compliance answers before submission.

## Screenshot Shot List

Use the screenshot plan in `AppStore/screenshots-spec.md`.

Recommended order:

1. Build a Tune Fast
2. Photo, Screenshot, or Manual
3. Confirm Every Stat
4. Tune for Road, Drift, Drag
5. Copy Complete Settings
6. Refine After Every Run
