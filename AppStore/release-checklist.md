# ForzAdvisor Release Checklist

Last updated: 2026-07-22

Readiness: TestFlight candidate

Metadata, privacy/support pages, release notes, screenshot specifications, and marketing screenshots are maintained for the current `1.2.1` app state. The warning-free headless build and non-UI unit suite are the automated release gates. App Review submission remains gated on App Store Connect record checks and explicit human approval; TestFlight upload is explicitly approved.

## Completed In Repository

- Bundle identifier is `com.michaelwilliams.forzadvisor`.
- Development team is set to `5RGU344VJR`.
- Installed display name is `ForzAdvisor`.
- Current project version is `1.2.1`.
- Current project build is `22`.
- Target device family is iPhone.
- App icon asset catalog contains default, dark, and tinted 1024px iOS icons with no alpha channel.
- Camera usage description is present.
- Privacy manifest is present at `forzadvisor/PrivacyInfo.xcprivacy`.
- Settings includes privacy behavior, app version, and unofficial-app disclosure.
- App Store metadata is present at `AppStore/metadata.md`.
- Release notes are present at `AppStore/release-notes.md`.
- Privacy policy and support pages are present under `AppStore/`, `docs/`, and `forzadvisorDocs/app-store/`.
- Marketing screenshot generation is present at `scripts/generate_marketing_screenshots.swift`.
- App Store screenshot outputs are stored in `AppStore/screenshots/`.

## Required In App Store Connect

- Verify the App Store Connect app record for `com.michaelwilliams.forzadvisor`.
- Verify the public privacy URL resolves: `https://Sankofa06.github.io/ForzAdvisor/privacy/`.
- Verify the public support URL resolves: `https://Sankofa06.github.io/ForzAdvisor/support/`.
- Provide App Review contact name, phone number, and email.
- Confirm age rating answers.
- Confirm export compliance answers.
- Upload accepted App Store screenshots.
- Wait for TestFlight processing after quickflight upload.
- Submit for App Review only after explicit human approval.

## App Review Risk Notes

- The app is an unofficial companion tool. Keep the disclaimer in metadata, support, privacy policy, screenshots, and Settings.
- Do not use official game logos or screenshots without legal clearance.
- FH5 catalog build planning stays local, does not use numeric formulas or the selected provider, and requires no account or API key.
- FH6 offline formula tuning is the default numeric provider and requires no account or API key.
- Optional on-device model assistance and user-key Anthropic API mode apply to FH6 generation; reviewers can complete both catalog flows offline.
- Screenshots and camera photos are processed locally for OCR. Current code does not upload screenshot images.

## Local Verification Plan

- Run `git diff --check`.
- Run a clean warning-free headless Xcode build using stable `/Applications/Xcode.app`.
- Run focused and full non-UI unit tests on one fixed headless simulator with parallel testing disabled.
- Do not run UI tests or focus Xcode, Simulator, or Device Hub unless explicitly required; use `simctl` screenshots for visual verification.

## Human-Approved Release Steps

- Run `xcode-versioning --write --asc require` only when App Store Connect configuration is available and release scope is approved.
- Re-run the clean build if versioning changes files.
- Commit final release changes only after validation is clean.
- Push only after explicit approval.
- Upload to TestFlight only after explicit approval.
- Run post-upload tests and report results separately.

## Sources Checked

- App Store Connect screenshot specifications: https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications/
- App Store Connect platform version information: https://developer.apple.com/help/app-store-connect/reference/app-information/platform-version-information/
- App Store Connect app privacy reference: https://developer.apple.com/help/app-store-connect/reference/app-information/app-privacy/
