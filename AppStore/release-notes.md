# Release Notes

## Version 1.20.0 (Build 45) - 2026-07-25

- Adds a direct Copilot handoff to Record Test Drive for eligible saved FH6 tunes.
- Guides accuracy work in order: finish first-party labs, record an exact Test Drive, then run a community comparison.
- Rechecks the persisted tune, notes, thumbnail, and exact evidence counts before every Copilot handoff so stale actions fail safely.

## Version 1.19.0 (Build 44) - 2026-07-25

- Adds Community Outcome Review for permission-bound FH6 comparison exports that match the exact current saved candidate.
- Keeps imported observations in a separate local queue with deterministic duplicate handling, conflict quarantine, and individual deletion.
- Reports local, reviewed, and combined collection-only breakdowns without importing reference tune values, changing a tune, or promoting a ruleset.

## Version 1.18.0 (Build 43) - 2026-07-25

- Adds guided FH6 community reference comparisons for exact saved tunes using a fixed A-B-B-A drive protocol.
- Surfaces the next eligible comparison through Saved Tune, Validation Review, Beta Missions, and contextual Copilot.
- Keeps comparison records local by default, with optional explicit sharing that excludes source tune settings, parts, share codes, text, media, and metrics.
- Treats every outcome as a comparative observation—not validation, ground truth, ranking, or tune promotion.

## Version 1.17.0 (Build 42) - 2026-07-25

- Adds a privacy-safe foundation for comparing an exact generated FH6 tune against a YouTube or Reddit reference with a fixed A-B-B-A drive protocol.
- Keeps community tune settings, parts, share codes, source text, and generated tune details out of public trial exports.
- Binds each reusable tester-authored outcome to the exact car, build, ruleset, and applied candidate through opaque integrity fingerprints.

## Version 1.16.0 (Build 41) - 2026-07-25

- Turns an empty garage into a clear first-win path through the reviewed FH6 catalog.
- Explains the three steps to generate and save a first tune while keeping unknown controls withheld until verified.
- Rechecks live garage and mission state before opening the starter path.

## Version 1.15.0 (Build 40) - 2026-07-25

- Adds a clear manual-entry path for cars that are not yet in the reviewed catalog.
- Preserves the selected FH5 or FH6 game while keeping manually entered stock values clearly unverified.

## Version 1.14.0 (Build 39) - 2026-07-25

- Shows Copilot's contextual next step immediately whenever it opens, without requiring a second prompt.
- Refreshes the guidance when the tuning context changes while keeping every recommended action user-initiated.

## Version 1.13.0 (Build 38) - 2026-07-25

- Makes Copilot's FH6 next-step guidance actionable with direct handoffs to Tune Menu Lab, Tire Lab, or Upgrade Lab.
- Rechecks the live result and current lab eligibility when tapped, so stale or changed recommendations fail safely.
- Keeps FH5 advice guidance-only and preserves the current tune, saved setup, thumbnail, and notes during valid handoffs.

## Version 1.12.1 (Build 37) - 2026-07-25

- Uses exact Tune Menu Lab ranges and slider steps for every formula-backed FH6 tuning control, not only tire pressure.
- Keeps locked, missing, duplicate, out-of-range, and individual-gear settings withheld instead of clamping or inventing values.
- Keeps Guided Refinement changes aligned to the same captured in-game grid while preserving legacy Tire Lab tunes.

## Version 1.12.0 (Build 36) - 2026-07-24

- Added FH6 Tune Menu Lab for untouched catalog cars, with exact first-party capture of adjustable, locked, and unavailable controls.
- Regenerates the tune against the observed game build, tire compound, gear count, slider ranges, steps, and current values while keeping missing or mismatched settings withheld.
- Added contextual Copilot guidance and a Beta Validation Mission for completing the exact stock tuning-menu check.

## Version 1.11.0 (Build 35) - 2026-07-23

- Expanded the reviewed selectable FH6 stock-car catalog from three to eight cars with official roster identity and class/PI plus community-cross-checked stock specifications.

## Version 1.10.1 (Build 34) - 2026-07-23

- Added an FH5 Research Partners handoff in Beta Validation Missions with a public TestFlight link and a privacy-safe invite that explains exact-plan prerequisites, permission boundaries, Apple-controlled beta availability, and the TestFlight feedback path.

## Version 1.10.0 (Build 33) - 2026-07-23

- Added explicit, deidentified sharing for reuse-permitted FH5 Candidate Outcomes, with a separate per-share confirmation and no background upload.
- Added strict local Candidate Outcome Review: canonical JSON, code-owned registration validation, exact locally regenerated candidate matching, direct-receipt permission, replay/conflict quarantine, and deletion.
- Added a collection-only local-plus-reviewed summary that cannot register or promote a ruleset, authorize readiness, create a `TuneResult`, or unlock/copy numeric FH5 settings.

## Version 1.9.0 (Build 32) - 2026-07-23

- Added an experimental FH5 Candidate Trial for exact saved plans whose permission-bound Research observations independently agree.
- Locks one clean-room front-tire-pressure hypothesis to the selected input and surface, shows the exact stock-versus-variant A-B-B-A protocol, and revalidates current saved evidence before accepting an outcome.
- Stores candidate-bound outcomes locally with non-exportable schema-v2 records, local evaluation progress, Beta Mission routing, and contextual Copilot guidance.
- Keeps the production FH5 registry empty: no candidate can become a tune, enter a provider or projector, appear in plan output, or unlock numeric FH5 settings.

## Version 1.8.3 (Build 31) - 2026-07-23

- Added the first registry-gated FH5 clean-room candidate generator for controlled testing: one legal front-tire-pressure step lower when an untouched stock car pushes wide.
- Requires the exact saved plan, complete Upgrade Lab evidence, and two canonical permission-bound Research observations that independently agree on the same stock menu measurements.
- Produces only a candidate-bound experimental artifact. The production registry remains empty, and no FH5 numeric tune, provider, UI, sharing, or output route is enabled.

## Version 1.8.2 (Build 30) - 2026-07-23

- Added a local schema-v2 contract that binds controlled FH5 outcomes to one exact registry-backed generated-candidate artifact while preserving existing schema-v1 Outcome Lab records and exports.
- Added a deterministic evaluator for the declared 10/8/0/2/two-UTC-day experimental threshold, with fail-closed checks for malformed evidence and record, submission, permission-receipt, content, or semantic replay.
- Kept candidate generation, candidate-bound collection, public schema-v2 export, the production registry, and every FH5 numeric output route unavailable in release builds.

## Version 1.8.1 (Build 29) - 2026-07-23

- Added a closed, code-owned FH5 experimental algorithm registration contract that binds one exact ruleset to explicitly permitted source manifests and their deterministic fingerprint.
- Declared the only supported experimental outcome threshold: 10 exact experiments, at least 8 candidate-preferred outcomes, no stock-preferred outcomes, no more than 2 nondecisive outcomes, at least 2 UTC test days, and reuse permission on every record.
- Kept the production FH5 registry empty and all numeric routes locked. This build adds no evaluator, numeric generator, or promotion path.

## Version 1.8.0 (Build 28) - 2026-07-23

- Added user-initiated sharing for FH5 Outcome Lab experiments only when deidentified calibration reuse was explicitly enabled before saving.
- Added a deterministic, allow-listed JSON record with a separate public semantic fingerprint while excluding the local experiment ID, saved tune ID and plan fingerprint, Research Lab record ID and content fingerprint, generated tune values, provider and ruleset data, notes, screenshots, telemetry, device identifiers, location, analytics, share destination, and public attribution.
- Kept the production FH5 ruleset registry empty: exported experiments remain calibration evidence only and cannot be imported, promote a ruleset, or unlock numeric FH5 tuning.

## Version 1.7.0 (Build 27) - 2026-07-23

- Added FH5 Outcome Lab for a fixed A-B-B-A Horizon Test Track experiment that compares stock with one user-selected legal slider step.
- Bound each local experiment to the exact saved plan, matching Research Lab measurements, complete Upgrade Lab evidence, one target symptom, and required restoration and first-party confirmations.
- Replaced the future outcome-evidence Boolean with a typed, code-owned policy report. Experiments remain calibration evidence only and cannot register a ruleset or unlock numeric FH5 tuning.

## Version 1.6.0 (Build 26) - 2026-07-23

- Added an FH5 numeric-readiness checklist that shows the exact stock, Research Lab, Upgrade Lab, replication, rights, and controlled-outcome gates still required.
- Bound replicated menu evidence to the local first-party measurements and kept conflicting observations, self-labelled rulesets, and installed-part contexts fail-closed.
- FH5 manual, OCR, edited, missing-snapshot, and legacy requests now return a safe local plan-only result without calling a model, API, or numeric provider.

## Version 1.5.0 (Build 25) - 2026-07-23

- Added FH6 Validation Review for exact ForzAdvisor Test Drive JSON tied to the current saved build, ruleset, discipline, and applied settings.
- Added explicit direct-receipt and deidentified-reuse confirmation, deterministic duplicate handling, and quarantine for conflicting submissions or reused receipts.
- Review reports only Keep, Adjust, Reject, handling symptoms, and test conditions. It cannot score quality, change a tune, or promote the experimental FH6 ruleset.

## Version 1.4.0 (Build 24) - 2026-07-23

- Added local Beta Validation Missions that turn eligible saved FH5 and FH6 setups into exact next testing steps.
- Missions recheck the existing Research Lab, Tire Lab, Upgrade Lab, and Record Test Drive safety boundaries before opening a workflow.
- Added an optional aggregate progress share containing counts only, with no car names, tune values, notes, identifiers, screenshots, or analytics.

## Version 1.3.0 (Build 23) - 2026-07-23

- Added plan-scoped FH5 Research Review for exact permission-bound Research Lab JSON, stored separately from local author observations.
- Added fail-closed canonical validation, payload bounds, fingerprint binding, replay quarantine, and exact build, platform, catalog, car, tire, drivetrain, and gear grouping.
- Reports only single, replicated, or conflicting raw observations and never averages values, creates a ruleset, contacts a provider, or enables numeric FH5 tuning.

## Version 1.2.1 (Build 22) - 2026-07-22

- Added FH5 Research Lab for complete, manually entered first-party observations of an untouched stock car's tuning menu, stored separately from the plan without contacting a tuning provider.
- Added off-by-default permission for deidentified structured observation reuse and deterministic JSON sharing, while keeping the record explicitly evidence-only.
- Bound observations to the current saved catalog plan and exact matching Upgrade Lab game build so stale evidence cannot surface or be shared.

## Version 1.2.0 (Build 21) - 2026-07-22

- Added a provider-independent local FH5 build planner for untouched stock cars selected from the reviewed catalog.
- Added Upgrade Lab verification and up to three exact tuning-control purchase paths using only parts the player confirms are offered in their game build.
- Kept numeric FH5 tuning, guided refinement, verified tune sharing, and test-drive validation unavailable until a separate FH5 ruleset is validated.
- Hardened saved-tune compatibility so legacy or malformed FH5 results cannot expose stale numeric settings, while valid legacy FH6 tunes remain unchanged.

## Version 1.1.16 (Build 20) - 2026-07-22

- Added Record Test Drive for eligible saved FH6 exact-stock tunes, with structured session conditions, verdicts, and handling feedback.
- Added explicit, off-by-default permission for deidentified benchmark reuse plus deterministic JSON sharing through the system share sheet.
- Bound validation records to the current verified tune revision, exact local tire and upgrade evidence, observed game build, and current FH6 ruleset.
- Kept records local unless shared and excluded free-form track text, notes, screenshots, telemetry, device data, provider details, and internal tune identifiers.

## Version 1.1.15 (Build 19) - 2026-07-22

- Tire Lab now records the stock car's forward gear count alongside the exact FH6 tire-pressure ranges, compound, and observed game build.
- Gear count starts blank, accepts localized whole-number input, excludes reverse, and blocks verification instead of guessing when the value is missing or invalid.
- Older tire observations remain readable but must be re-verified before they can supply the newly versioned gear-count evidence.

## Version 1.1.14 (Build 18) - 2026-07-22

- Added a privacy-safe Share verified build action for exact observed game builds with at least one freshly verified setting.
- Shared cards are rechecked before export and include only the game, car, tune context, canonical verified settings, and at most one exact tuning-control path.
- Excluded garage notes, screenshots, provider details, evidence records, identifiers, timestamps, and withheld values; sharing remains user-initiated through the iOS system share sheet with no share analytics or history.

## Version 1.1.13 (Build 17) - 2026-07-22

- Added a Contextual Copilot that is available throughout the tuning workflow and explains the safest next step for the current screen.
- Added local, deterministic answers for trust, missing verification, and privacy without sending Copilot questions to a model or network service.
- Kept Copilot guidance fail-closed: it summarizes verified status and eligibility without reading unsaved form edits, exposing raw tune values, or inventing parts, prices, PI, or performance claims.

## Version 1.1.12 (Build 16) - 2026-07-22

- Added a local Upgrade Lab for FH5 and FH6 stock catalog cars that records which tuning-control parts the exact in-game upgrade shop offers.
- Added up to three exact alternative tuning-control buy lists using only user-verified parts, with game-build checks and no invented PI, credit, entitlement, or performance claims.
- Preserved verified tire observations and upgrade availability in either Tune Lab order, including saved-tune reopen and copyable build plans.

## Version 1.1.11 (Build 15) - 2026-07-22

- Added an FH6 Tune Lab that records exact stock tire-pressure slider ranges locally and regenerates the tune against them.
- Added tune coverage and build-plan guidance while withholding generated values that do not pass capability, range, and provenance checks.

## Version 1.1.10 (Build 14) - 2026-07-22

- Added an explicit FH5/FH6 selector to manual entry and screenshot review.
- Preserved the selected game and reviewed OCR values when returning from tune-type selection.
- Removed a defensive crash path from discipline-specific alignment generation without changing existing tune values.

## Version 1.1.9 (Build 13) - 2026-07-22

- Added a searchable starter catalog for Forza Horizon 5 and Forza Horizon 6 with reviewed stock values for six cars.
- Added source links, catalog revision details, and clear verification status before tuning and after reopening a saved tune.
- Preserved catalog origin when values are edited while clearly labeling modified data.
- Added the internal capability foundation for future exact upgrade requirements without guessing unavailable parts.

## Version 1.1.8 (Build 12) - 2026-07-21

- Added the game-aware tuning foundation for Forza Horizon 5 and Forza Horizon 6, including their distinct PI class bands.
- Added D and R class support while preserving X-class saved tunes and legacy garage data.
- Prevented FH5 requests from silently using the existing FH6 offline formulas until a separately validated FH5 ruleset is available.

## Version 1.1.7 (Build 11) - 2026-07-21

- Expanded app compatibility to iOS 17 and later while preserving the offline-first tuning workflow.
- Kept optional on-device generation safely isolated to supported iOS versions, with clearer fallback status on older devices.

## Version 1.1.6 (Build 10) - 2026-07-16

- Made manual entry safer with blank required fields, clearer validation, keyboard controls, and easier class and drivetrain selection.
- Improved photo and screenshot OCR reliability with cancellation, retry, and stale-result safeguards while keeping image processing on device.
- Added clearer provider and fallback status plus more accessible, copy-friendly tune results.
- Fixed localized decimal handling so manual input and guided tuning adjustments remain accurate across regions.
- Made the PI field easier to tap during manual entry.

## Version 1.1.5 (Build 8) - 2026-06-25

- Added guided tuning refinement: describe what happened on a run, then get bounded tune changes with explanations for each adjusted setting.
- Improved garage rows and pre-generation setup summaries so saved tunes and input details are easier to scan.

## Version 1.1.3 (Build 6) - 2026-06-15

- Refined the full tune workflow from photo, screenshot, or manual entry through discipline selection and generated tune review.
- Added a saved garage experience with search, discipline filters, editable saved tunes, and copyable menu-order setup sections.
- Added offline-first tuning with optional on-device model assistance and optional Anthropic API mode for users who provide their own key.
- Improved setup, provider configuration, settings flows, and saved-content reliability.
- Added App Store-ready privacy, support, metadata, screenshot, and marketing materials for the TestFlight release path.

## App Store What's New

FH6 tunes now use the exact ranges and slider steps captured in Tune Menu Lab across every supported tuning control. Guided Refinement stays on that same in-game grid, while locked, missing, out-of-range, duplicate, and individual-gear settings remain safely withheld.

## TestFlight Notes

Choose an untouched FH6 catalog car, complete Upgrade Lab and Tune Menu Lab for the same exact game build, then regenerate the tune. Confirm every formula-backed adjustable control lands on the exact observed slider step.

Locked, missing, duplicate, out-of-range, and individual-gear settings must stay withheld. Save the tune, use Guided Refinement, and confirm changed values remain aligned to the captured grid.

Legacy Tire Lab tunes should still reopen and validate, but a legacy tire-only ruleset must never validate non-tire settings. Existing FH5 plan-only, Research, Outcome, and Candidate workflows should remain unchanged.

## Reviewer Notes

No login is required. On an eligible saved exact-build FH6 tune, Accuracy Evidence includes Validation Review. It imports only exact ForzAdvisor Test Drive JSON matching that setup after a local direct-receipt and reuse-permission confirmation. Imported entries stay in a separate local queue, report outcome counts and conditions only, and cannot modify settings or promote the experimental ruleset.

Beta Validation Missions is always visible in the garage and derives its current list locally from eligible saved setups. Empty garages receive FH5 and FH6 starter missions. Saved setups may receive Research Lab, Outcome Lab, Tire Lab, Upgrade Lab, or Record Test Drive missions only when their existing workflow eligibility passes. The board does not create evidence or tuning claims, and its optional progress share contains aggregate counts only.

To review the FH5 flow, choose New Tune -> Choose a Car -> Forza Horizon 5 -> select a car -> Use This Car -> Road, then save the plan. The app creates a local build plan with no numeric tuning values and offers Research Lab for first-party stock-menu evidence plus Upgrade Lab for user-confirmed purchase paths. After both are complete, Outcome Lab can record a one-step paired experiment and, only with explicit per-record reuse permission, share an allow-listed JSON copy without promoting it into a tune. For numeric tuning, select an FH6 car instead. Manual entry, camera, and photo import remain available.

## Previous TestFlight Notes

### Version 1.1.1 (Build 4) - 2026-06-01

- Improved reliability, usability, and app polish.

### Version 1.1.0 (Build 3) - 2026-06-01

- Improved data management reliability for saved app content.
- Improved navigation and workspace status visibility.
