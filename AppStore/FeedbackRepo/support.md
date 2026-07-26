# ForzAdvisor Support

ForzAdvisor helps racing-game players generate, save, copy, and adjust tuning setups from confirmed car details.

## Common Questions

### How do Stock Catalog Contributions work?

Stock Catalog Contribution stores manually entered first-party FH5 or FH6 stock observations in a separate local UserDefaults-backed workspace, not in Saved Tunes or the bundled catalog. Every identity and stock field requires direct in-game, untouched-stock confirmation for an exact game build and English units where relevant.

Local save does not require reuse permission. Canonical JSON export requires explicit authorship, deidentified reuse, catalog-curation, and future bundled redistribution permission. Import is manual and requires the receiver to separately confirm direct receipt and every right. Permission covers only tester-authored structured facts; it excludes screenshots, artwork, source prose, third-party databases, and tunes, and makes no endorsement, ownership, or licensing claim. Review labels records only as Received, Matching, Conflicting, or Excluded; it never verifies, approves, averages, ranks, or automatically changes a catalog, tune, ruleset, provider, or readiness state.

The workflow stores no screenshots, OCR, notes, accounts, device identifiers, or location and adds no analytics, network request, or background upload. UUIDs and hashes bind bytes but do not authenticate identity. Local deletion cannot recall JSON already shared.

Catalog Addition Review can turn an exact prepared curation preflight into a deterministic schema-v2 full-catalog proposal after explicit maintainer decisions and fresh validation against the current bundled 11-car catalog. It is transient and artifact-only: it cannot establish legal sufficiency, edit the bundle, activate tuning, or add a live car. Sharing and any later resource change are separate manual actions.

The contribution workspace toolbar includes a dedicated Copilot for local, deterministic guidance about exact untouched-stock identity, build and platform; every required fact and per-field source attestation; personally read values, English units, untouched state, authorship, local storage, all four export rights, explicit canonical sharing, and received-record review. It receives only the contribution phase. It cannot inspect draft fields, the selected game, contribution or review counts, pasted or exported JSON, permissions, payloads, identifiers, or fingerprints; call a model or network; retain a transcript; or execute an action. It never approves a contribution, changes the catalog, or activates tuning.

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

Open Beta Validation Missions from the garage to see the next local testing tasks supported by your saved FH5 and FH6 setups. An empty garage offers one starter mission for each game. Eligible saved setups can offer Research Lab, Outcome Lab, Tire Lab, Upgrade Lab, Record Test Drive, or an FH6 Community Reference Comparison mission, and completed or stale tasks disappear when you reopen the board.

The mission board does not upload progress or create evidence by itself. Share Beta Progress opens the iOS system share sheet with aggregate counts only and excludes car names, tune values, notes, identifiers, screenshots, and analytics.

### How do I join or invite an FH5 Research Partner?

In Beta Validation Missions, open FH5 Research Partners. You can open the capped public TestFlight group at https://testflight.apple.com/join/ec1RxDV3 or share a public-only invitation. It contains no local counts, car values, identifiers, fingerprints, or Candidate Outcome JSON.

Partners need FH5 and an iPhone with iOS 17 or later. Apple controls external beta availability; after approval, install the latest beta, coordinate the same FH5 game build and untouched stock catalog car, save the exact plan, and complete Upgrade Lab plus required Research evidence. Candidate Outcome JSON still requires explicit reuse/share and direct-receipt permission. Reviewed outcomes are collection-only and cannot unlock numeric FH5 tuning; IDs and hashes do not authenticate identity.

Send feedback through TestFlight's Send Beta Feedback with the car, game build, input, surface, and exact unclear or unexpectedly rejected step. Do not include private JSON or identifiers.

### How do I invite an FH6 Community Research Partner?

In Beta Validation Missions, share the FH6 Community Research Partners invitation with a player who already has the latest ForzAdvisor beta. This FH6 invitation contains no TestFlight link. Apple controls beta availability, and the invitation does not guarantee access.

Partners save an eligible exact FH6 tune, complete Record Test Drive for that exact current saved tune first, then run the fixed Community Reference A-B-B-A comparison. Explicit reuse permission is required before a manual canonical permission-bound Community Outcome export; the receiver uses Community Outcome Review for the matching exact current saved tune and separately confirms direct receipt and reuse permission. The public-only invitation includes no local progress, car or tune values, notes, IDs, fingerprints, receipts, JSON, source permalink, publisher, or local state. It adds no analytics or background network activity. Outcomes are collection-only, never validation, ground truth, ranking, promotion, or a tuning change. Community outcomes are not an accuracy or quality score and are not a recommendation. ForzAdvisor does not authenticate tester identity.

### What is FH5 Outcome Lab?

After a matching Research Lab record and complete Upgrade Lab observation exist, Outcome Lab guides a fixed A-B-B-A Horizon Test Track experiment. You compare stock with one user-selected slider step while keeping the route, conditions, assists, input, and every other setting unchanged, then restore the stock value.

The result remains calibration evidence. It does not generate a tune, collect lap times or telemetry, register a ruleset, or unlock numeric FH5 settings. Deidentified reuse is off by default. Generic calibration retains its schema-v1 share. A generated Candidate Outcome also requires a separate confirmation for each manual share. Candidate Outcome Review accepts it only after this device regenerates the exact candidate and you confirm direct receipt and reuse permission. Reviewed outcomes stay in a separate local queue and cannot affect readiness or numeric output. UUIDs and hashes bind bytes, not tester identity. There is no background upload, and deleting local evidence cannot recall a shared copy.

### What is an FH6 Community Reference Comparison?

On an eligible saved exact FH6 tune, apply the ForzAdvisor candidate as A and one direct YouTube or Reddit reference as B, then complete the fixed A-B-B-A protocol under constant conditions and restore A. The app stores metadata and your comparative observation, never community settings, parts, share codes, source prose/media, metrics, telemetry, accounts, or device identifiers. It is not validation, ground truth, a ranking, or promotion. Reuse and explicit JSON sharing are optional and off by default; there is no source lookup or background upload.

### What is FH6 Community Outcome Review?

Open the separate review from a saved tune's Community Reference Comparisons area or FH6 Validation Review. It accepts only canonical permission-bound comparison JSON for the fresh exact saved candidate. Direct receipt and structured-reuse permission require separate confirmations; hashes and UUIDs bind bytes, not identity. Local and reviewed outcome counts remain collection-only. Duplicates are ignored, conflicts and receipt/session replays are quarantined, and reviewed entries can be deleted. Review never imports source settings, parts, share codes, prose, media, or metrics; changes tuning; creates validation, ranking, or promotion; looks up a source; or uploads in the background.

### Can Copilot open FH5 Upgrade Lab?

On a saved current FH5 build plan, Copilot can offer one-tap **Open FH5 Research Lab** only after fresh persisted-plan equality, plan-only Research eligibility, and confirmation that no matching observation exists. Candidate Trial and recorded-observation states stay action-free. When Research is ineligible, **Open Upgrade Lab** remains a lower-priority fallback after a fresh eligibility check. Both routes preserve the tune, thumbnail, and notes and fail closed for stale, unsafe, or corrupt evidence. They cannot generate numeric settings, transact parts, predict PI, cost, or performance, call a provider or network, or bypass exact in-game availability.

### When does Upgrade Lab show exact alternative buy lists?

Exact alternatives require one complete, permitted local observation with exactly one decision per expected part, a known canonical FH5 or FH6 build, and a freshly derived matching stock projection. Stale, mixed, mismatched, missing, duplicate, already-installed, unknown, wrong-source, low-confidence, unpermitted, or tampered evidence fails closed. Rerun Upgrade Lab against the current untouched-stock car if older evidence is no longer eligible.

The main result, copied build plan, and Verified Build share card show a safe human-readable local source, game build, and stock-snapshot capture time. They expose no raw internal source IDs or private data and make no PI, cost, credits, entitlement, performance, or purchase-order prediction. Existing saves remain readable.

### How do I delete a tune?

Open the garage, swipe left on a saved tune, and tap Delete.

### How do I remove my API key?

Open Settings, switch the provider to Anthropic API if needed, and tap Clear Key.

## Contact

Use the public support tracker at https://github.com/Sankofa06/ForzAdvisor/issues.

Do not include API keys, private screenshots, personal messages, private hostnames, private IP addresses, or other sensitive data in public support issues.

## Unofficial App Notice

ForzAdvisor is not affiliated with, endorsed by, or sponsored by Microsoft, Xbox, Turn 10 Studios, Playground Games, or the Forza franchise.
