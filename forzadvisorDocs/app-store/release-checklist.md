# ForzAdvisor Release Checklist

Last updated: 2026-07-25

Readiness: TestFlight candidate

Metadata, privacy/support pages, release notes, screenshot specifications, and marketing screenshots are maintained for the current `1.20.0` app state. The warning-free headless build and non-UI unit suite are the automated release gates. App Review submission and TestFlight upload remain gated on App Store Connect record checks and explicit approval for the exact build.

## Completed In Repository

- Bundle identifier is `com.michaelwilliams.forzadvisor`.
- Development team is set to `5RGU344VJR`.
- Installed display name is `ForzAdvisor`.
- Current project version is `1.20.0`.
- Current project build is `45`.
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

## Required App Store Connect Values

- Verify the App Store Connect app record for `com.michaelwilliams.forzadvisor`.
- Verify the public privacy URL resolves: `https://Sankofa06.github.io/ForzAdvisor/privacy/`.
- Verify the public support URL resolves: `https://Sankofa06.github.io/ForzAdvisor/support/`.
- Provide App Review contact name, phone number, and email.
- Confirm age rating answers.
- Confirm export compliance answers.
- Upload accepted App Store screenshots.
- Wait for TestFlight processing after quickflight upload.
- Submit for App Review only after explicit human approval.

## App Review Notes

- The app is an unofficial companion tool. Keep the disclaimer in metadata, support, privacy policy, screenshots, and Settings.
- Do not use official game logos or screenshots without legal clearance.
- FH5 catalog build planning stays local, does not use numeric formulas or the selected provider, and requires no account or API key.
- FH5 Research Review stores exact permission-bound JSON locally, does not authenticate observer identity, and cannot promote evidence into numeric tuning or production constraints.
- FH5 Outcome Lab stores exact-plan, one-variable A-B-B-A experiment evidence locally, requires stock restoration, and cannot register a ruleset or unlock numeric tuning. Sharing is off by default and only an explicitly permitted allow-listed JSON copy can leave through the user-initiated system share sheet; there is no background experiment uploader or importer.
- FH6 Validation Review stores exact permission-bound Test Drive JSON in a separate local queue, requires the same eligible exact-build boundary as local Test Drive capture, and reports outcomes without modifying tunes or promoting the experimental ruleset.
- FH6 Community Reference Comparisons store only tester-entered source metadata and controlled A-B-B-A outcomes for the exact current saved candidate. They remain separate from validation, ranking, ground truth, and tune promotion; source settings, parts, share codes, prose, media, and metrics are never collected.
- FH6 Community Outcome Review accepts only canonical, permission-bound comparison exports that freshly match the exact persisted candidate. Imports stay in a separate local queue with deterministic duplicate handling, replay/conflict quarantine, individual deletion, and separate local/reviewed/combined collection-only reporting; they cannot change tuning or promote a ruleset.
- Contextual Copilot sequences eligible FH6 accuracy work through unfinished first-party labs, an exact Record Test Drive, and only then a Community Reference Comparison. Every action refetches and revalidates the persisted setup and carries no tune payload of its own.
- Beta Validation Missions are derived locally from existing eligibility checks, create no records by themselves, and share aggregate counts only through a user-initiated system share sheet.
- FH6 offline formula tuning is the default numeric provider and requires no account or API key.
- Optional on-device model assistance and user-key Anthropic API mode apply to FH6 generation; reviewers can complete both catalog flows offline.
- Screenshots and camera photos are processed locally for OCR. Current code does not upload screenshot images.

## Local Package Verification

- Run `git diff --check`.
- Run a clean warning-free headless Xcode build using stable `/Applications/Xcode.app`.
- Run focused and full non-UI unit tests on one fixed headless simulator with parallel testing disabled.
- Do not run UI tests or focus Xcode, Simulator, or Device Hub unless explicitly required; use `simctl` screenshots for visual verification.

## Human-Approved Release Steps

- Do not upload any build until the local verification gates, version/build alignment, signing target, and credential checks pass.
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
