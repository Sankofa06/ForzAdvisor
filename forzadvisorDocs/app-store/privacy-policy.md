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

For an eligible saved FH5 untouched-stock catalog plan, Research Lab can store a complete first-party tuning-menu observation in a separate local record. It can include platform, exact game version, reviewed stock-car facts, complete matching Upgrade Lab availability, tire compound, forward gear count, control availability, and allowed manually entered slider values. The workflow does not call a tuning provider, create a numeric tune, or upload anything.

Deidentified structured reuse and JSON sharing are off by default for every FH5 observation. Its allow-listed export excludes local tune and record identifiers, screenshots, OCR, thumbnails, notes, discipline, generated tune values, catalog source URLs, provider and ruleset data, Upgrade Lab part availability, device identifiers, location, analytics, history, and share destination. Its public content fingerprint covers only approved exported semantic fields and is separate from local integrity. The app surfaces or shares an observation only while it matches the current saved plan and catalog revision. Local deletion cannot recall a JSON file already shared.

Research Review can store exact permission-bound FH5 observation JSON locally with a matching saved catalog plan after the reviewer confirms direct receipt and reuse permission. UUIDs and hashes bind the reviewed bytes but do not authenticate identity. The app reports exact raw repetition or conflict without averaging values, creating a ruleset, contacting a provider, or unlocking numeric FH5 tuning.

## Offline And On-Device Tuning

Offline formula tuning is the default and does not require an account, API key, or network request.

If Apple Foundation Models are available on your device, ForzAdvisor can use on-device model assistance for tune generation. That mode is designed to run on device and falls back to offline formulas when unavailable or unsuccessful.

## Optional Anthropic API Mode

If you choose API mode and save your own Anthropic API key, ForzAdvisor sends reviewed car details, selected discipline, current tune details for adjustments, and relevant player notes to Anthropic to generate or refine a tune. Screenshots and camera photos are not uploaded by ForzAdvisor in the current release.

Your Anthropic API key is stored in the iOS Keychain on your device. It is sent to Anthropic only as part of API requests you initiate through API mode.

## Tracking, Advertising, And Analytics

ForzAdvisor does not include advertising SDKs, does not include analytics SDKs, does not include custom crash-reporting SDKs, does not sell personal information, and does not track you across apps or websites.

## Data Controls

You can delete saved tunes and locally stored validation, FH5 Research Lab, or imported Research Review records in the app. You can clear the optional Anthropic API key in Settings. You can disable camera access in iOS Settings.

## Children

ForzAdvisor is not directed to children and does not knowingly collect personal information from children.

## Contact

For privacy questions, use the public support tracker at https://github.com/Sankofa06/ForzAdvisor/issues. Do not include API keys, private screenshots, personal messages, or other sensitive information in public issues.

## Unofficial App Notice

ForzAdvisor is not affiliated with, endorsed by, or sponsored by Microsoft, Xbox, Turn 10 Studios, Playground Games, or the Forza franchise.
