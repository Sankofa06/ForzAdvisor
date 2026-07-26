# ForzAdvisor Support

Public URL: https://Sankofa06.github.io/ForzAdvisor/support/

ForzAdvisor helps racing-game players generate, save, copy, and adjust tuning setups from confirmed car details.

## Common Questions

### Do I need an account?

No. ForzAdvisor does not require a ForzAdvisor account.

### Do I need an API key?

No. Offline formula tuning is the default. On-device model assistance is optional when available. Anthropic API mode is optional for users who want to use their own Anthropic API key.

### Are screenshots uploaded?

No. Camera photos and imported screenshots are processed on device for OCR in the current release. They are not uploaded by ForzAdvisor.

### How do I start a tune?

Tap New Tune, then choose Take Photo, Import Screenshot, or Enter Manually. Confirm the detected or entered car details, choose a discipline, and review the generated tune.

### How do Stock Catalog Contributions work?

Stock Catalog Contribution lets you manually record first-party FH5 or FH6 stock facts from an exact game build. It requires a direct in-game, untouched-stock attestation for every identity and stock field, plus English units where relevant. Records stay in a separate local UserDefaults-backed workspace; they are not Saved Tunes, do not edit the bundled catalog, and do not become tuning inputs.

You can save a local observation without granting reuse. Canonical JSON export is available only after you explicitly confirm authorship and permit deidentified reuse, catalog curation, and future bundled redistribution of the structured facts. Sharing and importing are manual. A receiver must separately confirm direct receipt and every right before adding the record to the local review collection. The permission covers only tester-authored structured facts; it excludes screenshots, artwork, source prose, third-party databases, and tunes, and makes no endorsement, ownership, or licensing claim.

Review uses only Received, Matching, Conflicting, or Excluded collection states. It never verifies or approves a catalog entry, averages or ranks observations, or changes the bundled catalog, a tune, ruleset, provider, or readiness state. The workspace contains no screenshots, OCR, notes, accounts, device identifiers, or location, and ForzAdvisor adds no analytics, network request, or background upload. UUIDs and hashes bind structured bytes but do not authenticate identity. You can delete a local observation or reviewed entry, but deletion cannot recall JSON already shared.

### How do I copy a tune?

Open a generated or saved tune and tap Copy full tune. Individual tune lines can also be copied from their section rows.

### How do I use Guided Refinement?

Open a saved tune and use Guided Refinement to request changes such as more rotation, more stability, softer, stiffer, more top speed, or more acceleration.

### What are Beta Validation Missions?

Open Beta Validation Missions from the garage to see exact local testing tasks supported by your saved FH5 and FH6 setups. An empty garage offers one starter mission for each game. Eligible saved setups can offer Research Lab, Tire Lab, Upgrade Lab, Record Test Drive, or an FH6 Community Reference Comparison mission, and completed or stale tasks disappear when you reopen the board.

The board does not upload progress or create evidence by itself. Share Beta Progress opens the iOS system share sheet with aggregate counts only and excludes car names, tune values, notes, identifiers, screenshots, and analytics.

### How do I invite an FH6 Community Research Partner?

In Beta Validation Missions, share the FH6 Community Research Partners invitation with an FH6 player who already has the latest ForzAdvisor beta. This FH6 invitation contains no TestFlight link. Apple controls external beta availability, and the invitation does not guarantee access.

The partner must save an eligible exact FH6 tune, complete a first-party Record Test Drive for that exact current saved tune, and only then run the fixed Community Reference A-B-B-A comparison under constant conditions. Deidentified structured reuse must be explicitly permitted before the tester manually shares the canonical permission-bound Community Outcome export. The receiver opens Community Outcome Review for the matching exact current saved tune and separately confirms direct receipt and reuse permission.

The invitation contains no local progress, car or tune values, notes, identifiers, fingerprints, receipts, JSON, source permalink, publisher, or local state. Sharing is user initiated and adds no analytics or background network activity. Outcomes remain collection-only and cannot validate a tune, establish ground truth, rank a source, promote a candidate or ruleset, or change tuning. Community outcomes are not an accuracy or quality score and are not a recommendation. ForzAdvisor does not authenticate tester identity. Use TestFlight's Send Beta Feedback without attaching private JSON or identifiers.

### What is FH6 Validation Review?

Open an eligible saved exact-build FH6 tune and choose Open Validation Review under Accuracy Evidence. Paste an exact ForzAdvisor Test Drive JSON export for that setup. The app validates the canonical bytes, current game build and ruleset, verified shop availability, car, discipline, and applied settings before import.

Import requires confirmation of direct receipt and permission for deidentified structured reuse. UUIDs and hashes bind that local decision to the exact export but do not authenticate identity. Reviewed sessions stay in a separate local queue and report only Keep, Adjust, Reject, handling symptoms, course, surface, and input counts. They cannot change the tune or promote the experimental FH6 ruleset.

### What is an FH6 Community Reference Comparison?

On an eligible saved exact FH6 tune, choose Run Community Reference Comparison. Apply the exact ForzAdvisor candidate for A and one reference from a direct YouTube or Reddit permalink for B, then complete the fixed A-B-B-A sequence under the same route, conditions, assists, and input. Restore the ForzAdvisor candidate before saving or leaving.

The app stores only source metadata, controlled context, run confirmations, and your comparative outcome. Do not enter community settings, parts, share codes, source prose, media, or metrics. The result is a comparative observation, not validation, ground truth, a ranking, or a promotion. Local storage is required; deidentified reuse and explicit JSON sharing are optional and off by default. There is no source lookup or background upload.

### What is FH6 Community Outcome Review?

Open this separate review from a saved tune's Community Reference Comparisons area or from FH6 Validation Review. Paste exact canonical comparison JSON. Before showing an exact-current success, the app freshly refetches the saved tune and independently matches its opaque candidate binding. Direct receipt and deidentified structured-reuse permission require separate confirmations.

The screen reports clearly separate Local, Reviewed, and Combined collection-only counts for platform, outcome, course, surface, input, and candidate-deficiency symptoms. Same-semantic copies are deduplicated with local evidence preferred. Conflicting submissions, permission-receipt replays, and divergent outcomes reused as the same session are quarantined. Reviewed entries can be deleted. Review never imports source tune settings, parts, share codes, prose, media, or metrics; changes tuning; creates validation, ranking, or promotion; looks up a source; or uploads in the background. UUIDs and hashes bind bytes, not identity.

### What is FH5 Research Lab?

Research Lab appears on an eligible saved FH5 build plan for an untouched stock car from the reviewed catalog. In Horizon Test Track, use English units and record every expected tuning control as Adjustable, Shown locked, or Not shown. Enter slider bounds, step, and restored current values only when the control is adjustable.

The observation is raw first-party evidence, not a tune, and it does not enable numeric FH5 settings or contact a tuning provider. Deidentified structured JSON reuse is off by default and must be enabled for that record before sharing.

A complete Upgrade Lab observation locks Research Lab to the same exact game build. Saved observations appear and can be shared only while they match the current saved plan, catalog car, and catalog revision.

### Can Copilot open FH5 Upgrade Lab?

On a saved current FH5 build plan, Copilot can offer one-tap **Open Upgrade Lab** only after it freshly matches the persisted plan, confirms plan-only safety, and rechecks Upgrade Lab eligibility. It preserves the saved tune, thumbnail, and notes. Candidate Trial, recorded-observation, or eligible Research Lab guidance takes priority.

This action does not generate numeric FH5 settings; select, buy, or install parts; predict PI, credits, or performance; call a provider or network; or bypass exact in-game availability.

### What is FH5 Research Review?

On a matching saved FH5 catalog plan, paste an exact Research Lab JSON export into Research Review. The app validates the canonical record, requires confirmation of direct receipt and reuse permission, and stores it locally. It can label exact distinct sessions as replicated raw observations or show exact-value conflicts, but it never averages values, creates a ruleset, or enables numeric FH5 tuning.

### What is FH5 Outcome Lab?

After a matching Research Lab record and complete Upgrade Lab observation exist, Outcome Lab guides a fixed A-B-B-A Horizon Test Track experiment. Compare stock with one user-selected slider step while keeping route, conditions, assists, input, and every other setting unchanged, then restore the stock value.

The result remains calibration evidence. It does not generate a tune, collect lap times or telemetry, register a ruleset, or unlock numeric FH5 settings. Deidentified calibration reuse is off by default. When enabled before saving, the latest eligible record can be shared as allow-listed JSON through the iOS system share sheet. The copy omits the local experiment ID, saved tune ID and plan fingerprint, Research Lab record ID and content fingerprint, generated tune values, provider and ruleset data, device identifiers, location, analytics, and public attribution; it retains a menu-measurement fingerprint to bind the observed controls. There is no background experiment uploader or importer, and deleting the local record cannot recall a copy already shared.

### How do I delete a tune?

Open the garage, swipe left on a saved tune, and tap Delete.

### How do I remove my API key?

Open Settings, switch the provider to Anthropic API if needed, and tap Clear Key.

## Contact

Use the public support tracker at https://github.com/Sankofa06/ForzAdvisor/issues.

Do not include API keys, private screenshots, personal messages, private hostnames, private IP addresses, or other sensitive data in public support issues.

## Unofficial App Notice

ForzAdvisor is not affiliated with, endorsed by, or sponsored by Microsoft, Xbox, Turn 10 Studios, Playground Games, or the Forza franchise.
