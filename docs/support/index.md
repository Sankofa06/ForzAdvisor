# ForzAdvisor Support

ForzAdvisor helps racing-game players generate, save, copy, and adjust tuning setups from confirmed car details.

Stock Catalog Contribution can prepare a canonical maintainer review packet from complete permission-bound reviewed observations after explicit confirmation. The user-initiated packet preserves exact FH5/FH6 build, platform, facts, and field observation screens; excludes raw contribution JSON and administrative IDs; quarantines replays and conflicts; and compares read-only with the bundled catalog. It never selects sources, verification status, catalog identity, or a winning value and cannot change the catalog or tuning.

If that packet contains one non-conflicting car that is still absent from the exact current catalog and is supported by at least two distinct permission-complete observations, Catalog Curation Preflight can prepare the next review artifact. You must explicitly choose the candidate, proposed ID, new revision, proposed status, and an identity source whose compatible license or explicit permission you independently reviewed. Every stock field is bound to all supporting first-party observation digests. Changing the packet, candidate, catalog, proposal, rights evidence, or confirmations invalidates the prepared copy.

Preflight rejects stale same-revision catalogs, existing normalized car identities, incomplete or foreign field evidence, unsafe rights records, tampering, and noncanonical JSON. It does not decide whether a license or permission is legally sufficient, verify the car, create a catalog entry, edit the bundle, or activate tuning. Share it manually only for a separate release review.

## Common Questions

### Do I need an account?

No. ForzAdvisor does not require a ForzAdvisor account.

### Do I need an API key?

No. Offline formula tuning is the default. On-device model assistance is optional when available. Anthropic API mode is optional for users who want to use their own Anthropic API key.

### Are screenshots uploaded?

No. Camera photos and imported screenshots are processed on device for OCR in the current release. They are not uploaded by ForzAdvisor.

### How do I start a tune?

Tap New Tune, then choose Take Photo, Import Screenshot, or Enter Manually. Confirm the detected or entered car details, choose a discipline, and review the generated tune.

### What happens after I save my first setup?

When a save succeeds from an empty garage, the exact saved result shows a local confirmation with **Continue with Copilot** and **Not Now**. Continue opens the existing contextual Copilot, which evaluates the current saved result and explains its next eligible step. The prompt is transient and one-shot: either choice, Done, opening Copilot another way, or leaving the result dismisses it. It creates no evidence, changes no tune, and adds no analytics or background networking.

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

When the exact current saved candidate still has at least one valid reuse-permitted Test Drive and one clean local or permission-bound reviewed Community Outcome, Validation Review can prepare a canonical Independent Review Packet. The packet includes only accepted public Test Drive and Community Outcome exports, exact candidate bindings, independently recomputable included counts, fixed privacy exclusions, and an integrity fingerprint. Preparation is local, sharing requires a separate system-share-sheet action, and any candidate or persisted evidence change invalidates the prepared copy.

The packet does not attest, enumerate, or validate omitted or quarantined local inputs. Hashes and UUIDs do not authenticate a tester or publisher, and the packet does not prove every externally reviewed comparison historically followed one specific Test Drive. It cannot establish accuracy, validation, ranking, endorsement, or promotion; change a tune; or update a provider or ruleset.

To inspect a packet someone shared with you, first save the exact current FH6 candidate, then open Validation Review and use Inspect Shared Review Packet. Paste the exact canonical JSON and choose Validate Shared Review Packet. The app creates a fresh read context on every tap, ignores pending in-memory changes, and matches the packet to persisted candidate state. You do not need enough local evidence to prepare your own packet.

Accepted inspection shows sender-declared Test Drive, sender-local Community Outcome, permission-bound reviewed Community Outcome, and total accepted-evidence counts; the car and catalog ID; short candidate-binding and packet-fingerprint prefixes; and the fixed no-accuracy, no-promotion, independent-human-review boundary. “Sender-local” describes how the sender built the packet, not evidence stored on your device. Pasted JSON, validation status, and the summary remain transient. Editing the paste, a validation failure, changing the candidate, choosing Clear, or dismissing the screen removes accepted state. Nothing is imported or saved.

Validation Review Copilot receives only the screen phase. It cannot see pasted JSON, accepted counts, permission identifiers, candidate bindings, packet fingerprints, or inspection status; call a model or network; retain a transcript; or validate, clear, import, save, apply, score, rank, or promote anything.

### What is an FH6 Community Reference Comparison?

On an eligible saved exact FH6 tune, choose Run Community Reference Comparison. Apply the exact ForzAdvisor candidate for A and one reference from a direct YouTube or Reddit permalink for B, then complete the fixed A-B-B-A sequence with the same route, conditions, assists, and input. Restore the ForzAdvisor candidate before saving or leaving.

The app requires a valid first-party Test Drive for the exact current candidate before it will open, create, or save a new comparison. If the last matching Test Drive is deleted, existing comparison history remains available but new comparisons stay blocked until another matching Test Drive is recorded. The displayed evidence-chain stage and counts describe collection order only; they do not establish accuracy, validation, ranking, recommendation, or promotion.

The app stores only source metadata, controlled context, run confirmations, and your comparative outcome. Do not enter community settings, parts, share codes, source prose, media, or metrics. The result is a comparative observation, not validation, ground truth, a ranking, or a promotion. Local storage is required; deidentified reuse and explicit JSON sharing are optional and off by default. There is no source lookup or background upload.

### What is FH6 Community Outcome Review?

Open Community Outcome Review from a saved tune's Community Reference Comparisons area, or from the separate Community Reference Comparisons subsection in FH6 Validation Review. Paste the exact canonical JSON shared from another ForzAdvisor comparison. The app validates every schema, protocol, privacy, source, attestation, and fingerprint field and independently matches the opaque candidate binding to the fresh current saved tune.

Direct receipt and deidentified structured-reuse permission are separate required confirmations. UUIDs and hashes bind that decision to exact bytes but do not authenticate identity. Local and reviewed outcomes are summarized separately and together by platform, outcome, course, surface, input, and candidate-deficiency symptom. Duplicates are ignored; administrative conflicts and replayed receipts or sessions are quarantined. The queue is local and deletable. Review imports no source settings, parts, share codes, prose, media, or metrics, and cannot change tuning, rank or validate a candidate, promote a ruleset, perform source lookup, or upload in the background.

### What is FH5 Research Lab?

Research Lab appears on an eligible saved FH5 build plan for an untouched stock car from the reviewed catalog. In Horizon Test Track, use English units and record every expected tuning control as Adjustable, Shown locked, or Not shown. For adjustable controls, enter the minimum, maximum, step, and original current value, then restore any slider you moved before saving.

The saved observation is raw first-party evidence, not a tune. It does not enable numeric FH5 tuning or call the selected tuning provider. Do not copy values from videos, posts, shared tunes, or share codes.

If the plan already contains a complete verified Upgrade Lab observation, Research Lab locks the game version to that exact build. Saved observations are shown and shareable only while they match the current saved plan, catalog car, and catalog revision.

### Can I share an FH5 Research Lab observation?

Structured JSON reuse and sharing are off by default for every observation. If you explicitly enable them, the saved plan can open the iOS share sheet for a deidentified allow-listed JSON record. Deleting the local record cannot recall a copy you already shared.

### What is FH5 Research Review?

Open an eligible saved FH5 catalog plan and choose Research Review to paste an exact ForzAdvisor Research Lab JSON export. The app validates the complete canonical record, requires confirmation of direct receipt and reuse permission, and keeps the permission-bound copy locally with that plan. UUIDs and hashes bind the reviewed bytes but do not authenticate identity.

One record remains a single raw observation. Exact repeats from distinct capture sessions are labeled replicated raw observations, while exact-value disagreements are labeled conflicting raw observations. Review never averages values, creates a ruleset, or unlocks numeric FH5 tuning.

### What is FH5 Outcome Lab?

Outcome Lab appears only after a matching FH5 Research Lab record and complete Upgrade Lab observation exist. It guides a fixed A-B-B-A Horizon Test Track experiment: stock, one user-selected slider step, the same one-step variant again, then stock again. The route, surface, conditions, assists, input device, and every other setting must stay unchanged, and the tested slider must be restored to stock before saving.

The local record stores the exact plan and Research Lab fingerprints, the one declared change, one target handling symptom, the comparative result, and required confirmations. It does not generate a tune, upload telemetry, collect lap times or free-form notes, register a ruleset, or unlock numeric FH5 settings. Deidentified reuse is off by default. Generic calibration retains its schema-v1 share. A generated Candidate Outcome requires reuse permission plus a separate confirmation for each manual system share. Candidate Outcome Review imports only canonical JSON that matches an independently regenerated local candidate and only after direct-receipt permission confirmation. Reviewed outcomes stay in a separate local queue, quarantine duplicates/conflicts/replays, and cannot affect readiness or numeric output. UUIDs and hashes bind bytes, not tester identity. The app performs no background upload, and local deletion cannot recall a shared copy.

### How do I delete a tune?

Open the garage, swipe left on a saved tune, and tap Delete.

### How do I remove my API key?

Open Settings, switch the provider to Anthropic API if needed, and tap Clear Key.

## Contact

Use the public support tracker at https://github.com/Sankofa06/ForzAdvisor/issues.

Do not include API keys, private screenshots, personal messages, private hostnames, private IP addresses, or other sensitive data in public support issues.

## Unofficial App Notice

ForzAdvisor is not affiliated with, endorsed by, or sponsored by Microsoft, Xbox, Turn 10 Studios, Playground Games, or the Forza franchise.
