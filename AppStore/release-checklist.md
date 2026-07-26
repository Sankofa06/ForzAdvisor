# ForzAdvisor Release Checklist

Last updated: 2026-07-25

Readiness: TestFlight candidate

Metadata, privacy/support pages, release notes, screenshot specifications, and marketing screenshots are maintained for the current `1.26.0` app state. The warning-free headless build and non-UI unit suite are the automated release gates. App Review submission and TestFlight upload remain gated on App Store Connect record checks and explicit approval for the exact build.

## Completed In Repository

- Bundle identifier is `com.michaelwilliams.forzadvisor`.
- Development team is set to `5RGU344VJR`.
- Installed display name is `ForzAdvisor`.
- Current project version is `1.26.0`.
- Current project build is `51`.
- Target device family is iPhone.
- The reviewed selectable catalog contains three FH5 cars and eight FH6 cars.
- App icon asset catalog contains default, dark, and tinted 1024px iOS icons with no alpha channel.
- Camera usage description is present.
- Privacy manifest is present at `forzadvisor/PrivacyInfo.xcprivacy`.
- Settings includes privacy behavior, app version, and unofficial-app disclosure.
- App Store metadata is present at `AppStore/metadata.md`.
- Release notes are present at `AppStore/release-notes.md`.
- Privacy policy and support pages are present under `AppStore/`, `docs/`, and `forzadvisorDocs/app-store/`.
- Marketing screenshot generation is present at `scripts/generate_marketing_screenshots.swift`.
- App Store screenshot outputs are stored in `AppStore/screenshots/`.

## Required App Store Connect Values

- Verify the App Store Connect app record for `com.michaelwilliams.forzadvisor`.
- Verify the public privacy URL resolves: `https://Sankofa06.github.io/ForzAdvisor/privacy/`.
- Verify the public support URL resolves: `https://Sankofa06.github.io/ForzAdvisor/support/`.
- Provide App Review contact name, phone number, and email.
- Confirm age rating answers.
- Confirm export compliance answers.
- Upload accepted App Store screenshots.
- Wait for TestFlight processing after quickflight upload.
- Submit for App Review only after explicit human approval.

## App Review Notes

- The app is an unofficial companion tool. Keep the disclaimer in metadata, support, privacy policy, screenshots, and Settings.
- Do not use official game logos or screenshots without legal clearance.
- Stock Catalog Contribution stores manually entered first-party FH5/FH6 stock observations in a separate UserDefaults-backed local workspace, not in Saved Tunes or the bundled catalog. Every field requires exact-build, direct in-game, untouched-stock, and English-units-where-relevant attestation. Local save needs no reuse grant; canonical manual export requires explicit tester authorship, deidentified reuse, catalog-curation, and future bundled redistribution permissions, and import requires separate direct-receipt and confirmation of every right. Permission excludes screenshots, artwork, source prose, third-party databases, and tunes and makes no endorsement, ownership, or licensing claim. Collection states are only Received, Matching, Conflicting, or Excluded—never verified, approved, averaged, or ranked. Contributions cannot automatically change a catalog, tune, ruleset, provider, or readiness state; store no screenshots, OCR, notes, accounts, device IDs, or location; and add no analytics, networking, or background upload. UUIDs and hashes do not authenticate identity, and local deletion cannot recall shared JSON.
- Stock Catalog Contribution exposes a dedicated toolbar Copilot with local deterministic phase-only guidance for exact untouched-stock identity, build, platform, every required fact and field attestation, personally read values, English units, untouched state, authorship, local storage, all four export rights, explicit canonical sharing, and received-record review. It cannot read draft fields, the selected game, contribution or review counts, pasted or exported JSON, permissions, payloads, identifiers, or fingerprints; use a model or network; retain a transcript; execute an action; approve a contribution; change the catalog; or activate tuning.
- FH5 catalog build planning stays local, does not use numeric formulas or the selected provider, and requires no account or API key.
- Exact alternative Upgrade Lab buy lists require one complete, permitted, one-decision-per-expected-part local observation matched to a known canonical FH5/FH6 build and a freshly derived stock projection. Stale, mixed, mismatched, missing, duplicate, already-installed, unknown, wrong-source, low-confidence, unpermitted, and tampered evidence fails closed. The main result, copied build plan, and Verified Build share card display only safe human-readable local source, game-build, and stock-snapshot capture attribution, not raw internal source IDs or private data. They make no PI, cost, credits, entitlement, performance, or purchase-order prediction. Legacy saves remain readable, but stale evidence can require rerunning Upgrade Lab.
- FH5 Research Review stores exact permission-bound JSON locally, does not authenticate observer identity, and cannot promote evidence into numeric tuning or production constraints.
- FH5 Outcome Lab stores exact-plan, one-variable A-B-B-A experiment evidence locally, requires stock restoration, and cannot register a ruleset or unlock numeric tuning. Generic calibration sharing remains a separate schema-v1 path. Replication-qualified generated candidate trials are explicitly experimental and regenerated against current persisted evidence. A reuse-permitted schema-v2 outcome can leave only after a separate per-share confirmation; import requires an exact locally regenerated candidate and direct-receipt permission, stays in a separate review queue, and cannot affect readiness or numeric output.
- FH6 Validation Review stores exact permission-bound Test Drive JSON in a separate local queue, requires the same eligible exact-build boundary as local Test Drive capture, and reports outcomes without modifying tunes or promoting the experimental ruleset.
- FH6 Community Reference Comparisons store only tester-entered source metadata and controlled A-B-B-A outcomes for the exact current saved candidate. They remain separate from validation, ranking, ground truth, and tune promotion; source settings, parts, share codes, prose, media, and metrics are never collected.
- FH6 Community Outcome Review accepts only canonical, permission-bound comparison exports that freshly match the exact persisted candidate. Imports stay in a separate local queue with deterministic duplicate handling, replay/conflict quarantine, individual deletion, and separate local/reviewed/combined collection-only reporting; they cannot change tuning or promote a ruleset.
- Contextual Copilot sequences eligible FH6 accuracy work through unfinished first-party labs, an exact Record Test Drive, and only then a Community Reference Comparison. Every action refetches and revalidates the persisted setup and carries no tune payload of its own.
- FH5 contextual Copilot offers **Open Upgrade Lab** only for the exact current saved build plan after persisted equality, plan-only safety, and eligibility checks. It preserves the tune, thumbnail, and notes; yields to Candidate Trial, recorded-observation, and eligible Research Lab guidance; and cannot generate numeric settings, transact parts, claim PI, cost, or performance, call a provider or network, or bypass exact in-game availability. FH6 sequencing is unchanged.
- Settings, Beta Missions, and the four evidence-review modals expose guidance-only Copilot through their existing navigation stacks. Modal contexts use strict committed-fact allow-lists, cannot execute workflow actions, and exclude credentials, draft evidence, tune values, notes, images, identifiers, and fingerprints.
- FH6 Tune Menu Lab stores a complete first-party stock-menu observation inside the regenerated local tune, replaces stale exact Tire Lab constraints, preserves same-build Upgrade Lab facts, and keeps locked, missing, malformed, mismatched, duplicate, out-of-range, and individual-gear values withheld. Formula-backed fields and Guided Refinement changes use the exact captured slider grid.
- Beta Validation Missions are derived locally from existing eligibility checks, create no records by themselves, and share aggregate counts only through a user-initiated system share sheet.
- FH5 Research Partners uses the exact public TestFlight URL `https://testflight.apple.com/join/ec1RxDV3`. Its separate invite contains no local counts, car values, IDs, fingerprints, or JSON; it states exact-plan/evidence and permission prerequisites, the collection-only numeric boundary, and the TestFlight Send Beta Feedback path.
- FH6 Community Research Partners provides a separate public-only, user-initiated invite for testers who already have the latest beta. The invite contains no FH6 TestFlight URL and no local progress, car or tune values, notes, IDs, fingerprints, receipts, JSON, source details, or local state. It describes the required first-party Record Test Drive for that exact current saved tune, fixed A-B-B-A comparison, explicit reuse permission, manual permission-bound Community Outcome export, matching Community Outcome Review handoff, collection-only boundary, Apple-controlled availability, and TestFlight Send Beta Feedback path without analytics or background networking. Community outcomes are not an accuracy or quality score and are not a recommendation; ForzAdvisor does not authenticate tester identity.
- FH6 offline formula tuning is the default numeric provider and requires no account or API key.
- Optional on-device model assistance and user-key Anthropic API mode apply to FH6 generation; reviewers can complete both catalog flows offline.
- Screenshots and camera photos are processed locally for OCR. Current code does not upload screenshot images.

## Local Package Verification

- Run `git diff --check`.
- Run a clean warning-free headless Xcode build using stable `/Applications/Xcode.app`.
- Run focused and full non-UI unit tests on one fixed headless simulator with parallel testing disabled.
- Do not run UI tests or focus Xcode, Simulator, or Device Hub unless explicitly required; use `simctl` screenshots for visual verification.

## Human-Approved Release Steps

- Do not upload any build until the local verification gates, version/build alignment, signing target, and credential checks pass.
- Run `xcode-versioning --write --asc require` only when App Store Connect configuration is available and release scope is approved.
- Re-run the clean build if versioning changes files.
- Commit final release changes only after validation is clean.
- Push only after explicit approval.
- Upload to TestFlight only after explicit approval.
- Run post-upload tests and report results separately.

## Sources Checked

- App Store Connect screenshot specifications: https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications/
- App Store Connect platform version information: https://developer.apple.com/help/app-store-connect/reference/app-information/platform-version-information/
- App Store Connect app privacy reference: https://developer.apple.com/help/app-store-connect/reference/app-information/app-privacy/
