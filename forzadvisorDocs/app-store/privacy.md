# ForzAdvisor Privacy Review Notes

Last updated: 2026-06-15

## Privacy Manifest

The app includes `forzadvisor/PrivacyInfo.xcprivacy`.

Declared required-reason APIs:

- `NSPrivacyAccessedAPICategoryUserDefaults` with reason `CA92.1`

Reason: SwiftUI `@AppStorage` stores app-only preferences such as the selected tune provider mode. The app does not read defaults written by other apps or the system.

Declared collected data:

- `NSPrivacyCollectedDataTypeOtherUserContent`
- Purpose: `NSPrivacyCollectedDataTypePurposeAppFunctionality`
- Linked to user: false
- Used for tracking: false

Reason: optional Anthropic API mode can send reviewed car details, selected discipline, current tune details for adjustments, and player notes to Anthropic to generate or refine a tune. Screenshots and camera photos are processed on device and are not uploaded by the current app code.

Tracking:

- `NSPrivacyTracking`: false
- `NSPrivacyTrackingDomains`: empty

## App Store Privacy Labels

Recommended App Store Connect answers for human review:

- Data collected: Other User Content
- Purpose: App Functionality
- Linked to user: No
- Used for tracking: No
- Tracking: No
- Third-party advertising: No
- Developer advertising or marketing: No
- Analytics: No
- Crash diagnostics: No custom crash reporting in this codebase

Do not mark photos/videos as collected for the current build unless the app changes to upload screenshots. Photo and camera images are used locally for OCR and optional local thumbnails.

## Permissions

- Camera: used only when the user taps Take Photo to capture a racing-game performance screen for OCR.
- Photos: accessed through the system photo picker for user-selected screenshot import.
- Network: used only in optional Anthropic API mode when the user saves an API key and selects that provider.
- Keychain: stores the optional Anthropic API key on device.

## Third Parties

- No embedded third-party SDKs are present in the repository.
- Optional remote tune generation calls Anthropic's API directly with the user's saved API key.
- Optional on-device model assistance uses Apple Foundation Models when available and falls back to offline formulas.

## Sources

- Apple privacy manifest overview: https://developer.apple.com/documentation/bundleresources/adding-a-privacy-manifest-to-your-app-or-third-party-sdk
- Apple required-reason API reference: https://developer.apple.com/documentation/bundleresources/app-privacy-configuration/nsprivacyaccessedapitypes/nsprivacyaccessedapitype
- Apple App Store privacy reference: https://developer.apple.com/help/app-store-connect/reference/app-information/app-privacy/
