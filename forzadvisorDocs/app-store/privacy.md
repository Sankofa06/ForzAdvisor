# ForzAdvisor Privacy Review Notes

Last updated: 2026-07-22

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

FH5 Research Lab observations are manually entered and stored locally in a separate saved-plan record. The workflow does not contact a tune provider or upload the observation. A complete Upgrade Lab observation locks capture to its exact game build, and only records matching the current saved plan and catalog revision are surfaced or shared. Deidentified structured JSON sharing is off by default and requires explicit per-record permission; its allow-list excludes screenshots, OCR, notes, tune identifiers, generated tune values, provider and ruleset data, Upgrade Lab part availability, device identifiers, location, analytics, and share destinations. The public content fingerprint covers only exported semantic fields and does not expose the local integrity fingerprint.

FH5 Outcome Lab stores paired experiments locally in a separate saved-plan record only after matching Research Lab and complete Upgrade Lab evidence exist. Each record binds to the exact plan and menu fingerprints and includes one legal slider-step change, fixed A-B-B-A Horizon Test Track protocol, surface, input type, target symptom, comparative outcome, confirmations, and integrity identifiers. It excludes lap times, telemetry, notes, screenshots, location, device identifiers, analytics, provider data, and public attribution. Optional deidentified calibration reuse is off by default, and the current release has no uploader or public export for these records. They cannot register a ruleset or unlock numeric FH5 tuning.

FH6 Validation Review imports exact ForzAdvisor Test Drive JSON only for an eligible matching saved setup after local confirmation of direct receipt and deidentified reuse permission. Imported entries are stored separately from locally authored validation records. The review reports controlled outcomes and conditions only and does not modify tunes, contact a provider, or promote the experimental ruleset.

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
- FH5 Research Lab records and exports are generated locally. The app has no background uploader, receiver, or remote-revocation mechanism for them.
- FH5 Outcome Lab records remain local in the current release and cannot promote themselves into a ruleset or numeric tune.
- Imported FH6 Validation Review entries remain local unless the user separately acts through another app or system share destination; ForzAdvisor has no background review uploader.

## Sources

- Apple privacy manifest overview: https://developer.apple.com/documentation/bundleresources/adding-a-privacy-manifest-to-your-app-or-third-party-sdk
- Apple required-reason API reference: https://developer.apple.com/documentation/bundleresources/app-privacy-configuration/nsprivacyaccessedapitypes/nsprivacyaccessedapitype
- Apple App Store privacy reference: https://developer.apple.com/help/app-store-connect/reference/app-information/app-privacy/
