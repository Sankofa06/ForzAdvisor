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

After reviewing received contributions, you can explicitly confirm independent source review and prepare a canonical maintainer review packet. The packet keeps exact FH5/FH6 build, platform, facts, field observation screens, permission scope, and a read-only comparison with the bundled catalog. It omits raw contribution JSON and administrative IDs, excludes replayed records, and keeps conflicting variants quarantined together. It does not choose a source, verification status, catalog ID, revision, entry, or winning value and cannot update the catalog or tuning. Sharing remains a separate system-share-sheet action.

Use the toolbar Copilot for local, deterministic guidance about exact untouched-stock identity, build and platform; every required fact and per-field source attestation; personally read values, English units, untouched state, authorship, local storage, all four export rights, explicit canonical sharing, and received-record review. Copilot receives only the contribution phase. It cannot read draft fields, the selected game, contribution or review counts, pasted or exported JSON, permissions, payloads, identifiers, or fingerprints; call a model or network; keep a transcript; or perform an action. It never approves a contribution, changes the catalog, or activates tuning.

### How do I copy a tune?

Open a generated or saved tune and tap Copy full tune. Individual tune lines can also be copied from their section rows.

### How do I use Guided Refinement?

Open a saved tune and use Guided Refinement to request changes such as more rotation, more stability, softer, stiffer, more top speed, or more acceleration.

### What are Beta Validation Missions?

Open Beta Validation Missions from the garage to see the next local testing tasks supported by your saved FH5 and FH6 setups. An empty garage offers one starter mission for each game. Eligible saved setups can offer Research Lab, Tire Lab, Upgrade Lab, Record Test Drive, or an FH6 Community Reference Comparison mission, and completed or stale tasks disappear when you reopen the board.

The mission board does not upload progress or create evidence by itself. Share Beta Progress opens the iOS system share sheet with aggregate counts only and excludes car names, tune values, notes, identifiers, screenshots, and analytics.

### How do I join or invite an FH5 Research Partner?

In Beta Validation Missions, open FH5 Research Partners. You can open the capped public TestFlight group at https://testflight.apple.com/join/ec1RxDV3 or share a public-only invitation. The invitation contains no local progress counts, car values, identifiers, fingerprints, or Candidate Outcome JSON.

Partners need FH5 and an iPhone with iOS 17 or later. Apple controls external beta availability; after approval, install the latest TestFlight beta, coordinate the same FH5 game build and untouched stock catalog car, save the exact plan, and complete Upgrade Lab plus the required Research evidence. Candidate Outcome JSON may be used only with explicit deidentified reuse/share permission and confirmed direct receipt. Reviewed outcomes are collection-only and cannot unlock numeric FH5 tuning; UUIDs and hashes do not authenticate tester identity.

Use TestFlight's Send Beta Feedback and include the car, FH5 game build, input, surface, and exact step that was unclear or unexpectedly rejected. Do not include private JSON or identifiers in an invitation or feedback report.

### How do I invite an FH6 Community Research Partner?

In Beta Validation Missions, share the FH6 Community Research Partners invitation with an FH6 player who already has the latest ForzAdvisor beta. This FH6 invitation contains no TestFlight link. Apple controls external beta availability, and the invitation does not guarantee access.

The partner must save an eligible exact FH6 tune, complete a first-party Record Test Drive for that exact current saved tune, and only then run the fixed Community Reference A-B-B-A comparison under constant conditions. Deidentified structured reuse must be explicitly permitted before the tester manually shares the canonical permission-bound Community Outcome export. The receiver opens Community Outcome Review for the matching exact current saved tune and separately confirms direct receipt and reuse permission.

The invitation contains no local progress, car or tune values, notes, identifiers, fingerprints, receipts, JSON, source permalink, publisher, or local state. Sharing is user initiated and adds no analytics or background network activity. Outcomes remain collection-only and cannot validate a tune, establish ground truth, rank a source, promote a candidate or ruleset, or change tuning. Community outcomes are not an accuracy or quality score and are not a recommendation. ForzAdvisor does not authenticate tester identity. Use TestFlight's Send Beta Feedback without attaching private JSON or identifiers.

### What is FH6 Validation Review?

Open an eligible saved exact-build FH6 tune and choose Open Validation Review under Accuracy Evidence. Paste an exact ForzAdvisor Test Drive JSON export for that setup. The app validates the canonical bytes, current game build and ruleset, verified shop availability, car, discipline, and applied settings before it can be imported.

Import also requires you to confirm direct receipt from the driver and permission for deidentified structured reuse. UUIDs and hashes bind that local decision to the exact export but do not authenticate identity. Reviewed sessions stay in a separate local queue and show only Keep, Adjust, Reject, handling symptoms, course, surface, and input counts. They do not change the tune or promote the experimental FH6 ruleset.

### What is an FH6 Community Reference Comparison?

On an eligible saved exact FH6 tune, choose Run Community Reference Comparison. Apply the exact ForzAdvisor candidate for A and one reference from a direct YouTube or Reddit permalink for B, then complete the fixed A-B-B-A sequence with the same route, conditions, assists, and input. Restore the ForzAdvisor candidate before saving or leaving.

The app requires a valid first-party Test Drive for the exact current candidate before it will open, create, or save a new comparison. If the last matching Test Drive is deleted, existing comparison history remains available but new comparisons stay blocked until another matching Test Drive is recorded. The displayed evidence-chain stage and counts describe collection order only; they do not establish accuracy, validation, ranking, recommendation, or promotion.

The app stores only source metadata, controlled context, run confirmations, and your comparative outcome. Do not enter community settings, parts, share codes, source prose, media, or metrics. The result is a comparative observation, not validation, ground truth, a ranking, or a promotion. Local storage is required; deidentified reuse and explicit JSON sharing are optional and off by default. There is no source lookup or background upload.

### What is FH6 Community Outcome Review?

Open Community Outcome Review from a saved tune's Community Reference Comparisons area, or from the separate Community Reference Comparisons subsection in FH6 Validation Review. Paste the exact canonical JSON shared from another ForzAdvisor comparison. The app validates every schema, protocol, privacy, source, attestation, and fingerprint field and independently matches the opaque candidate binding to the fresh current saved tune.

Direct receipt and deidentified structured-reuse permission are separate required confirmations. UUIDs and hashes bind that decision to exact bytes but do not authenticate identity. Local and reviewed outcomes are summarized separately and together by platform, outcome, course, surface, input, and candidate-deficiency symptom. Duplicates are ignored; administrative conflicts and replayed receipts or sessions are quarantined. The queue is local and deletable. Review imports no source settings, parts, share codes, prose, media, or metrics, and cannot change tuning, rank or validate a candidate, promote a ruleset, perform source lookup, or upload in the background.

### What is FH5 Research Lab?

Research Lab appears on an eligible saved FH5 build plan for an untouched stock car from the reviewed catalog. In Horizon Test Track, use English units and record every expected tuning control as Adjustable, Shown locked, or Not shown. For adjustable controls, enter the minimum, maximum, step, and restored original current value.

The observation is raw first-party evidence, not a tune, and does not contact a tuning provider or enable numeric FH5 settings. A complete Upgrade Lab observation locks Research Lab to the same exact game build. Observations are shown and shareable only while they match the current saved plan, catalog car, and catalog revision.

### Can Copilot open FH5 Upgrade Lab?

On a saved current FH5 build plan, Copilot can offer one-tap **Open Upgrade Lab** only after it freshly matches the persisted plan, confirms plan-only safety, and rechecks Upgrade Lab eligibility. It preserves the saved tune, thumbnail, and notes. Candidate Trial, recorded-observation, or eligible Research Lab guidance takes priority.

This action does not generate numeric FH5 settings; select, buy, or install parts; predict PI, credits, or performance; call a provider or network; or bypass exact in-game availability.

### When does Upgrade Lab show exact alternative buy lists?

Upgrade Lab shows exact alternatives only when one complete, permitted local observation contains exactly one decision for every expected part, matches a known canonical FH5 or FH6 game build, and matches a freshly derived stock projection. It fails closed if evidence is stale, mixed across captures, mismatched, missing, duplicated, already installed, unknown, from the wrong source, low confidence, unpermitted, or tampered. Rerun Upgrade Lab against the current untouched-stock car when older evidence is no longer eligible.

The main result, copied build plan, and Verified Build share card show a safe human-readable local source, FH5 or FH6 build, and stock-snapshot capture time. They do not expose raw internal source IDs or private data and do not predict PI, cost, credits, entitlement, performance, or purchase order. Existing saves remain readable even when their stale evidence can no longer produce exact alternatives.

### Can I share an FH5 Research Lab observation?

Structured JSON reuse and sharing are off by default for each observation. If you explicitly enable them, the saved plan can open the iOS share sheet for a deidentified allow-listed JSON record. Deleting the local record cannot recall a copy already shared.

### What is FH5 Research Review?

Open an eligible saved FH5 catalog plan and choose Research Review to paste an exact ForzAdvisor Research Lab JSON export. The app validates the full canonical record, requires you to confirm direct receipt and reuse permission, and keeps the permission-bound copy locally with that plan. UUIDs and hashes protect the reviewed bytes but do not prove identity.

Review labels one record as a single raw observation, exact repeated records from distinct capture sessions as replicated raw observations, and any exact-value disagreement as conflicting raw observations. It never averages values, creates a tuning ruleset, or unlocks numeric FH5 tuning.

### What is FH5 Outcome Lab?

Outcome Lab appears only after a matching FH5 Research Lab record and complete Upgrade Lab observation exist. It guides a fixed A-B-B-A Horizon Test Track experiment: stock, one user-selected slider step, the same one-step variant again, then stock again. Route, conditions, assists, input, and every other setting must stay unchanged, and the tested slider must be restored to stock before saving.

The record remains calibration evidence. It stores no lap times, telemetry, screenshots, location, or free-form notes; it does not register a ruleset or unlock numeric FH5 tuning. Deidentified reuse is off by default. Generic calibration retains its schema-v1 share. A generated Candidate Outcome requires reuse permission plus a separate confirmation for each manual system share. Candidate Outcome Review imports only canonical JSON that matches an independently regenerated local candidate and only after direct-receipt permission confirmation. Reviewed outcomes stay in a separate local queue, quarantine duplicates/conflicts/replays, and cannot affect readiness or numeric output. UUIDs and hashes bind bytes, not tester identity. There is no background upload, and deleting local evidence cannot recall a shared copy.

### How do I delete a tune?

Open the garage, swipe left on a saved tune, and tap Delete.

### How do I remove my API key?

Open Settings, switch the provider to Anthropic API if needed, and tap Clear Key.

## Contact

Use the public support tracker at https://github.com/Sankofa06/ForzAdvisor/issues.

Do not include API keys, private screenshots, personal messages, private hostnames, private IP addresses, or other sensitive data in public support issues.

## Unofficial App Notice

ForzAdvisor is not affiliated with, endorsed by, or sponsored by Microsoft, Xbox, Turn 10 Studios, Playground Games, or the Forza franchise.
