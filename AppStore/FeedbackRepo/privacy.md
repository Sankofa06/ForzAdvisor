# ForzAdvisor Privacy Policy

Effective date: 2026-07-23

ForzAdvisor is an unofficial racing-game tuning assistant. This policy explains how the app handles information in the current iPhone release.

## Information Processed On Device

ForzAdvisor can process car details, tune settings, player notes, camera photos, imported screenshots, and saved tune history. By default, this information stays on your device and is used to generate, display, save, search, copy, and adjust tunes.

Camera photos and imported screenshots are processed on device with Apple's Vision OCR. If you save a tune after photo or screenshot entry, the app may save a small local thumbnail with that tune so you can recognize it later.

Beta Validation Missions are calculated on device from the eligibility and completion state of saved setups. Mission state is not separately persisted, uploaded, or measured with analytics. Opening a mission only routes you to an existing capture workflow; it does not create an evidence record or tuning claim.

FH5 Outcome Lab can store a local paired-experiment record after matching Research Lab and Upgrade Lab evidence exists. The record binds to the exact saved plan and observed menu, changes one adjustable control by one observed step in a fixed A-B-B-A Horizon Test Track protocol, and stores a target handling symptom, comparative outcome, surface, input type, required confirmations, and integrity identifiers. It excludes lap times, telemetry, notes, screenshots, location, device identifiers, analytics, provider data, and public attribution. Optional deidentified calibration reuse is off by default, and the current release does not upload or publicly export these records. They cannot create a ruleset or unlock numeric FH5 tuning.

## User-Initiated Beta Progress Sharing

From Beta Validation Missions, you can open the iOS system share sheet with a progress summary containing only the number of saved setups, permission-bound evidence records, setups with exact upgrade paths, and currently available missions. It excludes car names, disciplines, tune values, notes, identifiers, screenshots, JSON, fingerprints, receipts, provider details, and ruleset details. Sharing is user-initiated, and ForzAdvisor does not record the destination or history.

## Offline And On-Device Tuning

Offline formula tuning is the default and does not require an account, API key, or network request.

If Apple Foundation Models are available on your device, ForzAdvisor can use on-device model assistance for tune generation. That mode is designed to run on device and falls back to offline formulas when unavailable or unsuccessful.

## Optional Anthropic API Mode

If you choose API mode and save your own Anthropic API key, ForzAdvisor sends reviewed car details, selected discipline, current tune details for adjustments, and relevant player notes to Anthropic to generate or refine a tune. Screenshots and camera photos are not uploaded by ForzAdvisor in the current release.

Your Anthropic API key is stored in the iOS Keychain on your device. It is sent to Anthropic only as part of API requests you initiate through API mode.

## Tracking, Advertising, And Analytics

ForzAdvisor does not include advertising SDKs, does not include analytics SDKs, does not include custom crash-reporting SDKs, does not sell personal information, and does not track you across apps or websites.

## Data Controls

You can delete saved tunes and local FH5 Outcome Lab experiments in the app. You can clear the optional Anthropic API key in Settings. You can disable camera access in iOS Settings.

## Children

ForzAdvisor is not directed to children and does not knowingly collect personal information from children.

## Contact

For privacy questions, use the public support tracker at https://github.com/Sankofa06/ForzAdvisor/issues. Do not include API keys, private screenshots, personal messages, or other sensitive information in public issues.

## Unofficial App Notice

ForzAdvisor is not affiliated with, endorsed by, or sponsored by Microsoft, Xbox, Turn 10 Studios, Playground Games, or the Forza franchise.
