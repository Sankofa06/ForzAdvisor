# ForzAdvisor 1.0 Release Checklist

Last updated: 2026-05-31

Readiness: Yellow

The local app record identifiers, metadata, privacy notes, support pages, and screenshot artwork are prepared. Final TestFlight upload and App Review submission still require human-controlled App Store Connect access.

## Completed In Repository

- App version is `1.0`.
- Build number is `1`.
- Bundle identifier is `com.michaelwilliams.forzadvisor`.
- Development team is set to `5RGU344VJR`.
- Installed display name is `ForzAdvisor`.
- Version 1.0 target device family is iPhone.
- App icon asset catalog contains default, dark, and tinted 1024px iOS icons with no alpha channel.
- Camera usage description is present.
- Privacy manifest is present at `forzadvisor/PrivacyInfo.xcprivacy`.
- App Store metadata is present at `AppStore/metadata.md`.
- Release notes are present at `AppStore/release-notes.md`.
- Privacy policy and support pages are present under `docs/privacy/` and `docs/support/`.
- Marketing screenshot generation is present at `scripts/generate_marketing_screenshots.swift`.
- App Store screenshot outputs are stored in `AppStore/screenshots/`.

## Required In App Store Connect

- Verify the App Store Connect app record for `com.michaelwilliams.forzadvisor`.
- Publish GitHub Pages and confirm these public URLs resolve:
  - `https://blackslabpro.github.io/ForzAdvisor/privacy/`
  - `https://blackslabpro.github.io/ForzAdvisor/support/`
- Provide App Review contact name, phone number, and email.
- Confirm age rating answers.
- Confirm export compliance answers.
- Upload accepted App Store screenshots.
- Upload build `1.0 (1)` to TestFlight using Xcode Organizer.
- Wait for App Store Connect processing.
- Submit for App Review only after explicit human approval.

## App Review Risk Notes

- The app is an unofficial companion tool. Keep the disclaimer in metadata, support, privacy policy, screenshots, and Settings.
- Do not use official game logos or screenshots without legal clearance.
- Optional API mode requires a user-supplied Anthropic key. Reviewers can complete the core flow offline without an API key.
- Screenshots are processed locally. Current code does not upload screenshot images.

## Verification Log

- `xcodebuild -list -project forzadvisor.xcodeproj`: pass with `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer`; sandbox logged CoreSimulator/provisioning warnings unrelated to scheme discovery.
- Generic iOS Debug build: passed outside the sandbox after sandboxed asset compilation failed on CoreSimulator access.
- Generic iOS Release build: passed outside the sandbox with `CODE_SIGNING_ALLOWED=NO`.
- Unit and UI tests: passed on `iPhone 17` simulator. Result bundle: `/Users/blackslabpro/Library/Developer/Xcode/DerivedData/forzadvisor-glcrjijmthmeomfxnbimvrtgzsuy/Logs/Test/Test-forzadvisor-2026.05.31_09-53-16--0700.xcresult`.
- Marketing screenshots: generated and verified at `1320 x 2868` PNG for all six App Store upload images.
- Local App Store Connect export from the prior release pass remains available at `/tmp/ForzAdvisorExportLocal/forzadvisor.ipa`.
- TestFlight upload remains assigned to Xcode Organizer because the prior command-line upload was blocked by App Store Connect account/provider resolution.

## Sources Checked

- App Store Connect screenshot specifications: https://developer.apple.com/help/app-store-connect/reference/screenshot-specifications
- App privacy details: https://developer.apple.com/help/app-store-connect/manage-app-information/manage-app-privacy
- Submit an app: https://developer.apple.com/help/app-store-connect/manage-submissions-to-app-review/submit-an-app
