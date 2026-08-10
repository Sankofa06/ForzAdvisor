# ForzAdvisor Privacy Review Notes

Last updated: 2026-08-09

## Current Release Boundary

- The app no longer includes the FH5/FH6 roster JSON files or the reviewed stock catalog.
- New tune inputs come from manual entry or a user-selected photo/screenshot.
- Photo and camera images are processed on device for OCR and are not uploaded.
- Offline formulas are the default.
- Optional Anthropic API mode can transmit confirmed car details, selected discipline, current tune details, and player notes when the user selects that provider.
- The app includes no advertising, analytics, or custom crash-reporting SDKs.
- Local records are shared only through explicit system share-sheet actions.

## Privacy Manifest

The app includes `forzadvisor/PrivacyInfo.xcprivacy`.

Review the manifest whenever required-reason API usage or third-party SDKs change. Apple requires covered APIs and approved reasons to be declared consistently with actual app behavior:

https://developer.apple.com/documentation/bundleresources/describing-use-of-required-reason-api

## App Store Privacy Answers

Apple defines collection as transmitting data off device in a way that lets the developer or a third-party partner access it beyond the time needed to service the request. Data processed only on device is not collected for the label:

https://developer.apple.com/app-store/app-privacy-details/

Conservative review recommendation for the current optional Anthropic mode:

- Data type: Other User Content
- Purpose: App Functionality
- Linked to user: No
- Used for tracking: No
- Tracking: No
- Advertising: No
- Analytics: No
- Custom crash diagnostics: No

Because Anthropic mode is optional but present, App Store Connect answers should cover that mode. Keep the answers accurate for the exact submitted binary and publish them before App Review submission.

## Permissions

- Camera: requested only when the user chooses Take Photo.
- Photos: selected through Apple's system picker.
- Network: used for optional Anthropic API mode and system-provided services.
- Keychain: stores the optional user-provided Anthropic API key.
- UserDefaults: stores app-only preferences and supported local workspace state.

## Manual App Store Connect Work

- Confirm the privacy policy URL.
- Complete and publish App Privacy answers.
- Recheck the Content Rights declaration separately from privacy.
- Do not describe the removed roster as licensed, official, bundled, or available.
