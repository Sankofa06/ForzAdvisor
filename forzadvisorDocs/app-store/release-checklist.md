# ForzAdvisor 1.0 Release Checklist

Last updated: 2026-05-29

Readiness: Yellow

The local release package is prepared and an App Store-signed IPA export succeeded. App Store Connect upload, public URLs, and final App Review submission still require human-controlled account setup and approval.

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
- Settings includes privacy behavior, version, and unofficial-app disclosure.
- App Store metadata draft is present at `forzadvisorDocs/app-store/metadata.md`.
- Privacy notes are present at `forzadvisorDocs/app-store/privacy.md`.
- Privacy policy draft is present at `forzadvisorDocs/app-store/privacy-policy.md`.
- Support page draft is present at `forzadvisorDocs/app-store/support.md`.
- Screenshot plan is present at `forzadvisorDocs/app-store/screenshot-plan.md`.
- Initial release screenshots are present at `forzadvisorDocs/app-store/screenshots/`.
- iPhoneOS archive succeeded at `/tmp/ForzAdvisorArchives/ForzAdvisor-1.0.xcarchive`.
- Local App Store Connect export succeeded at `/tmp/ForzAdvisorExportLocal/forzadvisor.ipa` using Cloud Managed Apple Distribution signing.

## Still Required Before Submission

- Create or verify the App Store Connect app record for `com.michaelwilliams.forzadvisor`.
- Publish the privacy policy URL and replace `TODO_PUBLIC_PRIVACY_POLICY_URL`.
- Publish the support URL and replace `TODO_PUBLIC_SUPPORT_URL`.
- Provide App Review contact name, phone number, and email in App Store Connect.
- Confirm age rating answers in App Store Connect.
- Confirm export compliance answers in App Store Connect.
- Capture the remaining App Store screenshots beyond the initial home-screen evidence.
- Upload accepted App Store screenshots.
- Upload build `1.0 (1)` to TestFlight.
- Wait for App Store Connect processing.
- Submit for App Review only after human approval.

## App Review Risk Notes

- The app is an unofficial companion tool. Keep the disclaimer in metadata, support, privacy policy, and Settings.
- Do not use official game logos or screenshots unless legal clearance exists.
- Optional API mode requires a user-supplied Anthropic key. Reviewers can complete the core flow offline without an API key.
- Screenshots are processed locally. Current code does not upload screenshot images.

## Verification Log

- Release simulator build: passed on iPhone 17 with zero warnings.
- Unit and UI tests: passed with zero warnings.
- iPhoneOS archive: passed with zero warnings.
- Local App Store Connect export: passed. IPA: `/tmp/ForzAdvisorExportLocal/forzadvisor.ipa`; distribution summary shows Cloud Managed Apple Distribution signing, `beta-reports-active = true`, and `get-task-allow = false`.
- TestFlight upload: blocked by App Store Connect credentials/provider resolution. Xcode reported `exportArchive App Store Connect Credentials Error` and distribution logs showed `Unexpected nil property at path: 'Actor/relationships/providerId'`.

## Sources Checked

- App icon guidance: https://developer.apple.com/help/app-store-connect/manage-app-information/add-an-app-icon
- Screenshot requirements: https://developer.apple.com/help/app-store-connect/reference/screenshot-specifications
- App privacy requirements: https://developer.apple.com/help/app-store-connect/manage-app-information/manage-app-privacy
- Privacy manifest documentation: https://developer.apple.com/documentation/bundleresources/adding-a-privacy-manifest-to-your-app-or-third-party-sdk
- App submission flow: https://developer.apple.com/help/app-store-connect/manage-submissions-to-app-review/submit-an-app
