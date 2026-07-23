# ForzAdvisor Privacy Policy

Effective date: 2026-07-22

Public URL: https://Sankofa06.github.io/ForzAdvisor/privacy/

ForzAdvisor is an unofficial racing-game tuning assistant. This policy explains how the app handles information in the current iPhone release.

## Information Processed On Device

ForzAdvisor can process car details, tune settings, player notes, camera photos, imported screenshots, and saved tune history. By default, this information stays on your device and is used to generate, display, save, search, copy, and adjust tunes.

Camera photos and imported screenshots are processed on device with Apple's Vision OCR. If you save a tune after photo or screenshot entry, the app may save a small local thumbnail with that tune so you can recognize it later.

Beta Validation Missions are calculated on device from the eligibility and completion state of saved setups. Mission state is not separately persisted, uploaded, or measured with analytics. Opening a mission only routes you to an existing capture workflow; it does not create an evidence record or tuning claim.

## User-Initiated Sharing

On eligible exact-build results, ForzAdvisor can prepare verified build cards and first-party validation JSON locally, then open the iOS system share sheet. Sharing occurs only after you choose a destination, and the app does not record share destinations or history.

From Beta Validation Missions, ForzAdvisor can prepare an aggregate progress summary containing only counts of saved setups, permission-bound evidence records, setups with exact upgrade paths, and currently available missions. It excludes car names, disciplines, tune values, notes, identifiers, screenshots, JSON, fingerprints, receipts, provider details, and ruleset details. Sharing is user-initiated through the iOS system share sheet.

Validation Review can store exact permission-bound FH6 Test Drive JSON locally with a matching eligible saved setup after the reviewer confirms direct receipt and deidentified reuse permission. UUIDs and hashes bind the reviewed bytes but do not authenticate identity. The separate queue reports only verdicts, handling symptoms, and controlled test conditions. It cannot change the tune, contact a provider, or promote the experimental FH6 ruleset.

For an eligible saved FH5 untouched-stock catalog plan, Research Lab can store a complete first-party tuning-menu observation in a separate local record. It can include platform, exact game version, reviewed stock-car facts, complete matching Upgrade Lab availability, tire compound, forward gear count, control availability, and allowed manually entered slider values. The workflow does not call a tuning provider, create a numeric tune, or upload anything.

Deidentified structured reuse and JSON sharing are off by default for every FH5 observation. Its allow-listed export excludes local tune and record identifiers, screenshots, OCR, thumbnails, notes, discipline, generated tune values, catalog source URLs, provider and ruleset data, Upgrade Lab part availability, device identifiers, location, analytics, history, and share destination. Its public content fingerprint covers only approved exported semantic fields and is separate from local integrity. The app surfaces or shares an observation only while it matches the current saved plan and catalog revision. Local deletion cannot recall a JSON file already shared.

Research Review can store exact permission-bound FH5 observation JSON locally with a matching saved catalog plan after the reviewer confirms direct receipt and reuse permission. UUIDs and hashes bind the reviewed bytes but do not authenticate identity. The app reports exact raw repetition or conflict without averaging values, creating a ruleset, contacting a provider, or unlocking numeric FH5 tuning.

Outcome Lab can store a local FH5 paired-experiment record after matching Research Lab and complete Upgrade Lab evidence exist. It binds to the exact saved plan and observed menu and records one legal slider-step change, capture time, the fixed A-B-B-A Horizon Test Track protocol, surface, input type, target symptom, comparative outcome, required confirmations, and integrity identifiers.

Deidentified calibration reuse and JSON sharing are off by default for each experiment. When explicitly enabled before saving, the system share sheet can share an allow-listed JSON copy that excludes the local experiment ID, saved tune ID and plan fingerprint, Research Lab record ID and content fingerprint, generated tune values, provider and ruleset data, lap times, telemetry, notes, screenshots, OCR, location, device identifiers, analytics, share destination, and public attribution. It retains a menu-measurement fingerprint to bind the observed controls. A separate public fingerprint covers only exported fields. The app has no background experiment uploader or importer. Local deletion cannot recall a shared copy. These records cannot register a ruleset or unlock numeric FH5 tuning.

## Offline And On-Device Tuning

Offline formula tuning is the default and does not require an account, API key, or network request.

If Apple Foundation Models are available on your device, ForzAdvisor can use on-device model assistance for tune generation. That mode is designed to run on device and falls back to offline formulas when unavailable or unsuccessful.

## Optional Anthropic API Mode

If you choose API mode and save your own Anthropic API key, ForzAdvisor sends reviewed car details, selected discipline, current tune details for adjustments, and relevant player notes to Anthropic to generate or refine a tune. Screenshots and camera photos are not uploaded by ForzAdvisor in the current release.

Your Anthropic API key is stored in the iOS Keychain on your device. It is sent to Anthropic only as part of API requests you initiate through API mode.

## Tracking, Advertising, And Analytics

ForzAdvisor does not include advertising SDKs, does not include analytics SDKs, does not include custom crash-reporting SDKs, does not sell personal information, and does not track you across apps or websites.

## Data Controls

You can delete saved tunes and locally stored validation, imported FH6 Validation Review, FH5 Research Lab, imported FH5 Research Review, or FH5 Outcome Lab records in the app. You can clear the optional Anthropic API key in Settings. You can disable camera access in iOS Settings.

## Children

ForzAdvisor is not directed to children and does not knowingly collect personal information from children.

## Contact

For privacy questions, use the public support tracker at https://github.com/Sankofa06/ForzAdvisor/issues. Do not include API keys, private screenshots, personal messages, or other sensitive information in public issues.

## Unofficial App Notice

ForzAdvisor is not affiliated with, endorsed by, or sponsored by Microsoft, Xbox, Turn 10 Studios, Playground Games, or the Forza franchise.
