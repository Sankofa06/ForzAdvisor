# ForzAdvisor Privacy Policy

Effective date: 2026-07-22

ForzAdvisor is an unofficial racing-game tuning assistant. This policy explains how the app handles information in the current iPhone release.

## Information Processed On Device

ForzAdvisor can process car details, tune settings, player notes, camera photos, imported screenshots, and saved tune history. By default, this information stays on your device and is used to generate, display, save, search, copy, share, and adjust tunes.

Camera photos and imported screenshots are processed on device with Apple's Vision OCR. If you save a tune after photo or screenshot entry, the app may save a small local thumbnail with that tune so you can recognize it later.

Beta Validation Missions are calculated on device from the eligibility and completion state of saved setups. Mission state is not separately persisted, uploaded, or measured with analytics. Opening a mission only routes you to an existing capture workflow; it does not create an evidence record or tuning claim.

## User-Initiated Sharing

On an eligible exact-build result, you can ask ForzAdvisor to prepare a verified build card locally and open the iOS system share sheet. The card includes the game, car identity, discipline, class and PI, drivetrain, observed game build, settings that passed local verification, and at most one tuning-control upgrade path.

The shared card excludes garage notes, photos, screenshots, OCR content, API keys, provider details, internal identifiers, timestamps, and evidence or source records. ForzAdvisor does not send the card until you choose a destination in the system share sheet, and the app does not operate that destination or record share history, destinations, or analytics.

From Beta Validation Missions, you can also open the iOS system share sheet with a progress summary containing only the number of saved setups, permission-bound evidence records, setups with exact upgrade paths, and currently available missions. It excludes car names, disciplines, tune values, notes, identifiers, screenshots, JSON, fingerprints, receipts, provider details, and ruleset details. Sharing is user-initiated, and ForzAdvisor does not record the destination or history.

For eligible saved exact-build tunes, you may also record one first-party test-drive session and explicitly opt in to deidentified benchmark reuse. The public JSON contains a submission UUID, creation timestamp, consent version, permission-receipt UUID, game and observed build with capture timestamp, allow-listed stock vehicle facts (including catalog ID, tire-compound ID and observed display name, and gear count), canonical shop availability, discipline, tune-generation timestamp, public ruleset versions, typed applied settings, controlled course type, surface, input type, run count, verdict, selected handling symptoms, confirmations, explicit unknowns and exclusions, and integrity fingerprints.

The public JSON does not contain the local record UUID, raw tune UUID, internal revision link, free-form track or location text, garage or tune notes, attachments, lap time, telemetry, assists, weather, location, device identifiers, provider details, ruleset provenance or source records, or public attribution.

Creating a validation record does not upload it. Sharing happens only when you choose the system share sheet, and ForzAdvisor keeps no share destination or history. You can delete the latest matching local record; deletion cannot recall a JSON file you already shared. The app makes no background-upload, receiver, or remote-revocation claim for these records.

On an eligible matching saved FH6 tune, Validation Review can locally import an exact ForzAdvisor validation JSON export after you confirm direct receipt from the driver and permission for deidentified structured reuse. The canonical JSON, integrity-binding fields, and local review time are stored in a separate on-device queue. UUIDs and hashes bind the reviewed bytes but do not authenticate identity.

Validation Review requires the current game build, stock vehicle facts, verified shop availability, discipline, public ruleset version, and applied settings to match the saved setup. It groups only observed verdicts, handling symptoms, course type, surface, and input. It does not calculate a quality ranking, modify tune settings, contact a provider, or promote the experimental ruleset. Invalid, conflicting, or replayed administrative records are excluded from reviewed outcome counts. Imported entries can be deleted locally.

For an eligible saved FH5 untouched-stock catalog plan, Research Lab can store a complete first-party observation of the tuning menu in a separate local record. The record includes the selected platform, exact game version, reviewed catalog car facts, any complete matching Upgrade Lab part availability, tire-compound display name, forward gear count, each expected control's adjustable, locked, or not-shown state, and any manually entered slider range, step, and current value allowed by that state. Creating this record does not call a tuning provider, create a numeric tune, or upload anything. The app only surfaces or shares an observation while it still matches the current saved plan and catalog revision; older records may remain local as history.

Deidentified structured reuse and JSON sharing are off by default for each FH5 observation. If you explicitly enable them before saving, the exported JSON uses an allow-list and excludes the local record and tune identifiers, screenshots, OCR, thumbnails, garage notes, discipline, generated tune values, catalog source URLs, provider and ruleset data, Upgrade Lab part availability, device identifiers, location, analytics, history, and share destination. Its public content fingerprint covers only those approved exported semantic fields and is separate from the local integrity fingerprint. Deleting the local observation cannot recall a JSON file already shared.

On a matching saved FH5 catalog plan, Research Review can locally import the exact allow-listed JSON after you confirm direct receipt from the observer and permission for deidentified structured reuse. The canonical JSON, integrity-binding fields, and local review time are stored in a separate on-device queue. UUIDs and hashes bind the exact reviewed bytes but do not authenticate identity. Review compares exact raw observations without averaging values, contacting a provider, creating a ruleset, or enabling numeric FH5 tuning. Imported review entries can be deleted locally.

For a matching saved FH5 plan with complete Research Lab and Upgrade Lab evidence, Outcome Lab can store one local paired-experiment record in a separate evidence queue. The record binds to the exact plan and menu-measurement fingerprints and includes platform, game build, allow-listed stock vehicle facts, tire name, gear count, one adjustable field's observed range/step/stock value, a one-step candidate value, surface, input type, target handling symptom, comparative outcome, the fixed A-B-B-A protocol, required confirmations, and random integrity identifiers. It excludes lap times, telemetry, free-form notes, screenshots, location, device identifiers, analytics, provider data, and public attribution. Optional deidentified calibration reuse is off by default, and this release does not upload or publicly export these records.

Outcome Lab evidence cannot approve a ruleset, change a saved plan, unlock numeric FH5 tuning, or set its own acceptance threshold. Deleting a local experiment removes only that local evidence record.

## Offline And On-Device Tuning

Offline formula tuning is the default and does not require an account, API key, or network request.

If Apple Foundation Models are available on your device, ForzAdvisor can use on-device model assistance for tune generation. That mode is designed to run on device and falls back to offline formulas when unavailable or unsuccessful.

## Optional Anthropic API Mode

If you choose API mode and save your own Anthropic API key, ForzAdvisor sends reviewed car details, selected discipline, current tune details for adjustments, and relevant player notes to Anthropic to generate or refine a tune. Screenshots and camera photos are not uploaded by ForzAdvisor in the current release.

Your Anthropic API key is stored in the iOS Keychain on your device. It is sent to Anthropic only as part of API requests you initiate through API mode.

## Tracking, Advertising, And Analytics

ForzAdvisor does not include advertising SDKs, does not include analytics SDKs, does not include custom crash-reporting SDKs, does not sell personal information, and does not track you across apps or websites.

## Data Controls

You can delete saved tunes, locally stored validation records, imported FH6 Validation Review entries, locally stored FH5 Research Lab observations, and imported FH5 Research Review entries in the app. You can clear the optional Anthropic API key in Settings. You can disable camera access in iOS Settings.

## Children

ForzAdvisor is not directed to children and does not knowingly collect personal information from children.

## Contact

For privacy questions, use the public support tracker at https://github.com/Sankofa06/ForzAdvisor/issues. Do not include API keys, private screenshots, personal messages, or other sensitive information in public issues.

## Unofficial App Notice

ForzAdvisor is not affiliated with, endorsed by, or sponsored by Microsoft, Xbox, Turn 10 Studios, Playground Games, or the Forza franchise.
