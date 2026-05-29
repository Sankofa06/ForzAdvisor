# ForzAdvisor Privacy Review Notes

Last updated: 2026-05-29

## Privacy Manifest

The app includes `forzadvisor/PrivacyInfo.xcprivacy`.

Declared required-reason APIs:

- `NSPrivacyAccessedAPICategoryUserDefaults` with reason `CA92.1`

Reason: SwiftUI `@AppStorage` stores app-only user preferences such as the selected tune provider mode. The app does not read defaults written by other apps or the system.

Declared collected data:

- `NSPrivacyCollectedDataTypeOtherUserContent`
- Purpose: `NSPrivacyCollectedDataTypePurposeAppFunctionality`
- Linked to user: false
- Used for tracking: false

Reason: optional API mode can send confirmed car details, selected discipline, and player notes to Anthropic to generate or adjust a tune. Screenshots are processed on device and are not uploaded by the current app code.

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
- Network: used only in optional API mode when the user saves an Anthropic API key and selects API as the tune provider.
- Keychain: stores the optional Anthropic API key on device.

## Third Parties

- No embedded third-party SDKs are present in the repository.
- Optional remote tune generation calls Anthropic's API directly with the user's saved API key.

## Sources

- Apple privacy manifest overview: https://developer.apple.com/documentation/bundleresources/adding-a-privacy-manifest-to-your-app-or-third-party-sdk
- Apple required-reason API reference: https://developer.apple.com/documentation/bundleresources/app-privacy-configuration/nsprivacyaccessedapitypes/nsprivacyaccessedapitype
- Apple App Store privacy details: https://developer.apple.com/app-store/app-privacy-details/

