# ForzAdvisor Privacy Policy

Effective date: 2026-07-22

ForzAdvisor is an unofficial racing-game tuning assistant. This policy explains how the app handles information in the current iPhone release.

## Information Processed On Device

ForzAdvisor can process car details, tune settings, player notes, camera photos, imported screenshots, and saved tune history. By default, this information stays on your device and is used to generate, display, save, search, copy, share, and adjust tunes.

Camera photos and imported screenshots are processed on device with Apple's Vision OCR. If you save a tune after photo or screenshot entry, the app may save a small local thumbnail with that tune so you can recognize it later.

## User-Initiated Sharing

On an eligible exact-build result, you can ask ForzAdvisor to prepare a verified build card locally and open the iOS system share sheet. The card includes the game, car identity, discipline, class and PI, drivetrain, observed game build, settings that passed local verification, and at most one tuning-control upgrade path.

The shared card excludes garage notes, photos, screenshots, OCR content, API keys, provider details, internal identifiers, timestamps, and evidence or source records. ForzAdvisor does not send the card until you choose a destination in the system share sheet, and the app does not operate that destination or record share history, destinations, or analytics.

For eligible saved exact-build tunes, you may also record one first-party test-drive session and explicitly opt in to deidentified benchmark reuse. The public JSON contains a submission UUID, creation timestamp, consent version, permission-receipt UUID, game and observed build with capture timestamp, allow-listed stock vehicle facts (including catalog ID, tire-compound ID and observed display name, and gear count), canonical shop availability, discipline, tune-generation timestamp, public ruleset versions, typed applied settings, controlled course type, surface, input type, run count, verdict, selected handling symptoms, confirmations, explicit unknowns and exclusions, and integrity fingerprints.

The public JSON does not contain the local record UUID, raw tune UUID, internal revision link, free-form track or location text, garage or tune notes, attachments, lap time, telemetry, assists, weather, location, device identifiers, provider details, ruleset provenance or source records, or public attribution.

Creating a validation record does not upload it. Sharing happens only when you choose the system share sheet, and ForzAdvisor keeps no share destination or history. You can delete the latest matching local record; deletion cannot recall a JSON file you already shared. The app makes no background-upload, receiver, or remote-revocation claim for these records.

## Offline And On-Device Tuning

Offline formula tuning is the default and does not require an account, API key, or network request.

If Apple Foundation Models are available on your device, ForzAdvisor can use on-device model assistance for tune generation. That mode is designed to run on device and falls back to offline formulas when unavailable or unsuccessful.

## Optional Anthropic API Mode

If you choose API mode and save your own Anthropic API key, ForzAdvisor sends reviewed car details, selected discipline, current tune details for adjustments, and relevant player notes to Anthropic to generate or refine a tune. Screenshots and camera photos are not uploaded by ForzAdvisor in the current release.

Your Anthropic API key is stored in the iOS Keychain on your device. It is sent to Anthropic only as part of API requests you initiate through API mode.

## Tracking, Advertising, And Analytics

ForzAdvisor does not include advertising SDKs, does not include analytics SDKs, does not include custom crash-reporting SDKs, does not sell personal information, and does not track you across apps or websites.

## Data Controls

You can delete saved tunes and locally stored validation records in the app. You can clear the optional Anthropic API key in Settings. You can disable camera access in iOS Settings.

## Children

ForzAdvisor is not directed to children and does not knowingly collect personal information from children.

## Contact

For privacy questions, use the public support tracker at https://github.com/Sankofa06/ForzAdvisor/issues. Do not include API keys, private screenshots, personal messages, or other sensitive information in public issues.

## Unofficial App Notice

ForzAdvisor is not affiliated with, endorsed by, or sponsored by Microsoft, Xbox, Turn 10 Studios, Playground Games, or the Forza franchise.
