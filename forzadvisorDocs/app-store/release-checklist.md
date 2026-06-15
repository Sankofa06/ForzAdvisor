# ForzAdvisor Release Checklist

Last updated: 2026-06-15

Readiness: Quickflight ready

The release branch has been fast-forwarded into `main`. Metadata, privacy/support pages, release notes, screenshot specifications, and marketing screenshots are prepared for the current `1.1.3` app state. The final TestFlight build number has been assigned by `xcode-versioning`.

## Completed In Repository

- Bundle identifier is `com.michaelwilliams.forzadvisor`.
- Development team is set to `5RGU344VJR`.
- Installed display name is `ForzAdvisor`.
- Current project version is `1.1.3`.
- Current project build is `6`.
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
- Offline formula tuning is the default and requires no account or API key.
- Optional on-device model assistance falls back to offline formulas when unavailable.
- Optional Anthropic API mode requires a user-supplied API key. Reviewers can complete the core flow offline without an API key.
- Screenshots and camera photos are processed locally for OCR. Current code does not upload screenshot images.

## Quickflight Verification Plan

- Run `git diff --check`.
- Run a clean warning-free Xcode build using Xcode beta.
- Run `xcode-versioning --write --asc require`.
- Re-run the clean build if versioning changes files.
- Commit final release changes on `main`.
- Push `main` to `origin`.
- Run `testflight`.
- Run post-upload tests and report results separately.

## Sources Checked

- App Store Connect screenshot specifications: https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications/
- App Store Connect platform version information: https://developer.apple.com/help/app-store-connect/reference/app-information/platform-version-information/
- App Store Connect app privacy reference: https://developer.apple.com/help/app-store-connect/reference/app-information/app-privacy/
