# ForzAdvisor Privacy Review Notes

Last updated: 2026-07-22

## Privacy Manifest

The app includes `forzadvisor/PrivacyInfo.xcprivacy`.

Declared required-reason APIs:

- `NSPrivacyAccessedAPICategoryUserDefaults` with reason `CA92.1`

Reason: SwiftUI `@AppStorage` stores app-only preferences such as the selected tune provider mode. The app does not read defaults written by other apps or the system.

Stock Catalog Contribution also uses an app-only UserDefaults-backed workspace for manually entered first-party FH5 and FH6 stock observations and received review entries. It is separate from Saved Tunes and the bundled production catalog. Every field requires exact-build, direct in-game, untouched-stock, and English-units-where-relevant attestation. Local save does not require reuse permission. Canonical manual export requires explicit tester authorship, deidentified reuse, catalog-curation, and future bundled redistribution permission; manual import requires separate confirmation of direct receipt and every right. Permission covers only tester-authored structured facts; it excludes screenshots, artwork, source prose, third-party databases, and tunes, and makes no endorsement, ownership, or licensing claim.

Declared collected data:

- `NSPrivacyCollectedDataTypeOtherUserContent`
- Purpose: `NSPrivacyCollectedDataTypePurposeAppFunctionality`
- Linked to user: false
- Used for tracking: false

Reason: optional Anthropic API mode can send reviewed car details, selected discipline, current tune details for adjustments, and player notes to Anthropic to generate or refine a tune. Screenshots and camera photos are processed on device and are not uploaded by the current app code.

The FH6 Community Research Partner invitation is static public copy shared only through a user-initiated system share sheet. It contains no FH6 TestFlight link, local progress or counts, car or tune values, notes, identifiers, fingerprints, receipts, JSON, source permalink, publisher, or local state. It adds no recruitment analytics, account, authentication, background network activity, or share-history recording. Evidence reuse, manual permission-bound Community Outcome export, direct receipt, and Community Outcome Review permissions remain separate explicit decisions. Community outcomes are not an accuracy or quality score and are not a recommendation. ForzAdvisor does not authenticate tester identity.

Every Stock Catalog Contribution field is attested as a direct in-game untouched-stock observation for an exact game build. Review states are limited to Received, Matching, Conflicting, and Excluded; they do not verify or approve a catalog entry and are not averaged or ranked. Contributions cannot automatically change a catalog, tune, ruleset, provider, or readiness state. The workflow stores no screenshots, OCR, notes, accounts, device identifiers, or location and performs no analytics, network request, or background upload. UUIDs and hashes bind bytes but do not authenticate identity. Local deletion cannot recall JSON already shared.

FH5 Research Lab observations are manually entered and stored locally in a separate saved-plan record. The workflow does not contact a tune provider or upload the observation. A complete Upgrade Lab observation locks capture to its exact game build, and only records matching the current saved plan and catalog revision are surfaced or shared. Deidentified structured JSON sharing is off by default and requires explicit per-record permission; its allow-list excludes screenshots, OCR, notes, tune identifiers, generated tune values, provider and ruleset data, Upgrade Lab part availability, device identifiers, location, analytics, and share destinations. The public content fingerprint covers only exported semantic fields and does not expose the local integrity fingerprint.

On a saved current FH5 build plan, contextual Copilot can open Upgrade Lab only after fresh persisted-plan equality, plan-only safety, and eligibility checks. The local route preserves the tune, thumbnail, and notes and does not share them. Candidate Trial, recorded-observation, and eligible Research Lab guidance suppress the action. It does not generate numeric settings, transact parts, claim PI, cost, or performance, call a provider or network, or bypass exact in-game availability.

FH5 Outcome Lab stores paired experiments locally in a separate saved-plan record only after matching Research Lab and complete Upgrade Lab evidence exist. Each record binds to the exact plan and menu fingerprints and includes one legal slider-step change, capture time, fixed A-B-B-A Horizon Test Track protocol, surface, input type, target symptom, comparative outcome, confirmations, and integrity identifiers.

Deidentified calibration reuse and JSON sharing are off by default for each experiment. With explicit per-record permission, the system share sheet can share an allow-listed JSON copy. It excludes the local experiment ID, saved tune ID and plan fingerprint, Research Lab record ID and content fingerprint, generated tune values, provider and ruleset data, lap times, telemetry, notes, screenshots, OCR, location, device identifiers, analytics, share destination, and public attribution. It retains a menu-measurement fingerprint to bind the observed controls. A separate public fingerprint covers only exported fields. There is no background experiment uploader or importer, and deleting the local record cannot recall a shared copy. Experiments cannot register a ruleset or unlock numeric FH5 tuning.

FH6 Validation Review imports exact ForzAdvisor Test Drive JSON only for an eligible matching saved setup after local confirmation of direct receipt and deidentified reuse permission. Imported entries are stored separately from locally authored validation records. The review reports controlled outcomes and conditions only and does not modify tunes, contact a provider, or promote the experimental ruleset.

FH6 Community Reference Comparisons store only tester-entered YouTube or Reddit source metadata, controlled A-B-B-A context, confirmations, comparative outcomes, attestations, and integrity fields for the exact current saved candidate. They do not collect source tune settings, parts, share codes, prose, media, metrics, telemetry, accounts, or device identifiers. Reuse/export is optional and off by default, sharing is manual, and the records cannot validate, rank, promote, or modify a tune.

FH6 Community Outcome Review accepts canonical permission-bound comparison JSON only after a fresh refetch matches the exact current saved candidate and the reviewer separately confirms direct receipt and structured-reuse permission. It stores canonical bytes and a bound local receipt in a separate optional queue. UUIDs and hashes bind bytes, not identity. Local-only, reviewed-only, and combined dimensions remain collection-only. Invalid, duplicate, conflicting, and replayed evidence is excluded or quarantined. Review imports no source tune values and cannot change tuning, rank or validate a candidate, promote a ruleset, look up a source, or upload in the background.

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
- FH5 Outcome Lab records remain local unless the user explicitly shares an eligible allow-listed JSON copy; the app has no background experiment uploader or importer, and records cannot promote themselves into a ruleset or numeric tune.
- Imported FH6 Validation Review entries remain local unless the user separately acts through another app or system share destination; ForzAdvisor has no background review uploader.
- FH6 Community Reference Comparison records remain local unless the user explicitly enables deidentified reuse and manually shares an allow-listed JSON copy. Community Outcome Review can manually import only that canonical allow-listed JSON into a separate local queue; ForzAdvisor performs no source lookup or background upload.

## Sources

- Apple privacy manifest overview: https://developer.apple.com/documentation/bundleresources/adding-a-privacy-manifest-to-your-app-or-third-party-sdk
- Apple required-reason API reference: https://developer.apple.com/documentation/bundleresources/app-privacy-configuration/nsprivacyaccessedapitypes/nsprivacyaccessedapitype
- Apple App Store privacy reference: https://developer.apple.com/help/app-store-connect/reference/app-information/app-privacy/
