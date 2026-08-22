# App Privacy Label Attestation

Last human verification: 2026-08-21

This file records the answers published in App Store Connect for ForzAdvisor 1.41.1. It is non-secret release evidence, not a substitute for reviewing the app's actual data flows before each release.

## Published answers

- Does this app collect data? **Yes**
- Data types: **Gameplay Content** and **Other User Content**
- Purpose for each declared type: **App Functionality**
- Linked to the user's identity: **Yes**
- Used for tracking: **No**

## Operational interpretation

ForzAdvisor stores user-entered gameplay details, notes, tunes, thumbnails, and optional validation content locally. Optional Anthropic API mode sends confirmed text details and relevant notes to Anthropic only when the user selects that provider; source photos and screenshots are not sent by ForzAdvisor. The app has no advertising or analytics SDK and does not track users across apps or websites.

## Release gate

Before each release, a human must compare these answers with the current binary, `forzadvisor/PrivacyInfo.xcprivacy`, `AppStore/privacy-policy.md`, dependencies, and every network path. Record the verification date in the release record. Any new SDK, server, analytics, advertising, account, sharing, or remote-processing behavior invalidates this attestation until reviewed and republished in App Store Connect.
