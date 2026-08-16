# Psychological UX Cohesion

Status: Proposed for product approval. No implementation is authorized by this spec yet.

## 1. Problem And Outcome

ForzAdvisor is careful about privacy and evidence integrity, but the current UI sometimes hides the primary task, combines selection with consequential actions, shows blocked states without explanations, or removes recovery after destructive actions. Shared workflow, theme, provider, and evidence code is also concentrated in oversized files, making parallel UI changes risky.

The outcome is a cohesive, autonomy-supporting app in which people can understand what will happen before commitment, preserve work, recover from mistakes, distinguish available settings from validation evidence, and complete the primary tuning flow before encountering optional research work.

## 2. Users And Primary Flow

Primary user: an FH5 or FH6 player who wants a safe, understandable setup while moving between an iPhone and the game.

Canonical flow:

1. Start from Garage.
2. Choose photo, screenshot, or manual entry.
3. Confirm or correct car facts.
4. Select a discipline, review provider/privacy consequences, and explicitly start generation.
5. Apply or copy available settings, save the result, and optionally refine it.
6. Optionally contribute validation or research evidence.

## 3. Current Behavior And Evidence

- A clean simulator build succeeded on 2026-08-15 for bundle `com.michaelwilliams.forzadvisor`.
- Accepted screenshots are in `.codex/audits/psychological-ux-2026-08-15/screenshots/`.
- Empty Garage search obscures primary content in portrait and landscape.
- Garage first-win copy promises a reviewed FH6 catalog, while current release documents and source-contract tests require the catalog to remain removed.
- OCR continuation can be disabled without naming the invalid field; user review does not clear immutable confidence warnings.
- Tapping a discipline immediately starts generation and can initiate provider work before explicit confirmation.
- Generation cancellation exists in the controller but is not consistently exposed in UI.
- Tune values and apply actions appear after optional validation/research content.
- Guided refinement mutates the saved tune before the user reviews the proposed changes.
- The first-save Step Guide handoff inherits the result's scroll position and is partially hidden behind the navigation toolbar.
- Test Drive storage currently requires reusable-benchmark consent even for a local record.
- Settings does not clearly separate preferred provider, expected fallback, and actual provider.
- Copilot is a deterministic four-intent local guide but visually resembles a general AI assistant.
- Shared light-mode accent/status colors are likely below 4.5:1 for normal text and require runtime verification.
- `TuneResultView.swift`, root workflow files, and several evidence/review files exceed the PRD's 350-line limit.

Screenshot evidence now covers empty and populated Garage, source selection, pristine and completed manual entry, discipline selection, the top and lower Tune Result states, the first-save handoff, Beta Missions, offline and API Settings, and Step Guide plus one nested response. Captures use the dedicated iPhone 17 simulator in light mode at default text size; VoiceOver, larger Dynamic Type sizes, dark mode beyond the earlier Garage baseline, and camera/OCR success and failure states remain verification requirements.

## 4. Proposed Product Decisions

The complete set below was approved for implementation on 2026-08-15.

- Keep the bundled catalog and roster removed. Align first-win, New Tune, routes, tests, and release copy with photo, screenshot, and manual entry. Catalog restoration is a separate rights/legal scope.
- Rename user-facing Copilot to **Step Guide**. Expose exactly four deterministic choices, no free-form field, no network, and no transcript.
- Show exactly one Step Guide entry per surface. Garage uses one labeled toolbar action; other screens use the same position in compact form. Remove the duplicate Garage body row.
- Remove Touge's unique "Signature" endorsement. All disciplines have equal hierarchy and no preselection.
- Separate discipline selection from generation. A dedicated CTA starts work after provider/privacy consequences are visible.
- Canceling a new generation returns to Discipline with the selection and draft intact. Canceling a saved re-tune returns to Edit with the full unsaved draft and leaves the saved tune unchanged.
- Any change to weight, front-weight percentage, PI, class, or drivetrain requires **Re-tune & Save**. Identity and notes changes use **Save Changes**.
- Guided refinement becomes proposal -> preview -> Apply or Discard -> six-second Undo after Apply. Provider completion alone never changes SwiftData.
- Garage removal is staged for six seconds with Undo. SwiftData is mutated only when the window expires, another removal is staged, or Garage is left.
- Validation and research are explicitly optional. No streaks, urgency, fabricated progress, public ranking, or accuracy claims are added.
- A test drive can be saved locally with reusable-evidence permission off. Reuse authorization is a separate, optional, later-revocable decision.
- Exact local-only observations may advance the local evidence chain but cannot be exported, aggregated, imported as permission-bound evidence, or included in review packets until authorized.
- Persist factual validation capture drafts locally for recovery. Never persist consent, authorship, attestation, or shared JSON fields. Delete a draft on successful completion or explicit Discard. New Tune drafts remain memory-only.
- Observational fields have no unverified default. Remove the FH5 six-gear default unless it comes from exact compatible evidence.
- Settings calls the choice **Preferred generation method** and distinguishes expected route/fallback from the result's actual provider.
- Stored API-key state means **Stored on this device - not tested**. Settings never rehydrates an existing secret into view state. This scope adds no network key test.

## 5. Requirements And Acceptance Criteria

### Shared Foundation

- SF-01: Normal text meets 4.5:1 and large text/control boundaries meet 3:1 in light and dark appearances.
- SF-02: Shared selection, status, validation, transient feedback, and undo controls use text/shape/icon in addition to color and have 44-point targets.
- SF-03: Every touched or new source/test file is below 350 lines; target under 250 lines for view composition.
- SF-04: Root workflow, theme, provider disclosure, validation domain, and release documents each have one owner.

### Garage

- G-01: Empty Garage shows no search/filter and no control obscures the first-tune CTA in portrait, landscape, or accessibility text sizes.
- G-02: First-win copy and route offer only supported photo, screenshot, and manual paths.
- G-03: Each saved tune appears once; no duplicate Recent row and no nested horizontal row scrolling.
- G-04: Inline search and an accessible discipline picker produce accurate no-result states and recovery actions.
- G-05: Removal is staged with six-second Undo, atomic commit, rollback on save failure, and VoiceOver announcements.
- G-06: Optional testing is subordinate to New Tune and labeled optional.

### New Tune And Input

- NI-01: Photo is visually primary while screenshot and manual remain immediately available without pressure or hidden alternatives.
- NI-02: OCR progress/error/retry is visible near the top and cancellation does not abandon the whole New Tune flow.
- NI-03: Invalid OCR/manual continuation names, focuses, and announces the first unresolved field.
- NI-04: Pristine Manual Entry shows guidance, not a wall of errors; touched or submitted invalid fields show inline recovery.
- NI-05: OCR uses actionable review states (Needs Check, Confirmed, Corrected), not raw confidence-as-accuracy percentages.
- NI-06: Confirmation can display the retained local source image and relevant Vision region; absent/corrupt image data never blocks valid form review.
- NI-07: Back preserves meaningful in-memory work and Tune Source offers Resume; destructive replacement/discard is explicit.

### Discipline And Generation

- DG-01: Tapping a discipline only selects it and performs zero provider/network calls.
- DG-02: A separate CTA starts `Generate FH6 Tune` or `Create FH5 Build Plan` with game-correct vocabulary.
- DG-03: Provider location, data boundary, and fallback are visible before start.
- DG-04: Working, partial, failed, canceled, and completed states use truthful phases with no fake percentage or ETA.
- DG-05: Cancel is visible from start through final transition; stale callbacks cannot alter the return destination.
- DG-06: Failure stays in context with exact retry and change/back actions; raw provider responses and secrets are never rendered.

### Tune Result And Saved Edit

- TR-01: Order is status -> Apply/Copy and Save -> available settings -> saved refinement -> notes -> optional Validation & Research.
- TR-02: Partial output is clearly incomplete and non-copyable; copy/save/stream feedback is visible and announced.
- TR-03: Saved status is content, not a disabled command.
- TR-04: Refinement generation does not mutate persistence; preview shows every old/new value and rationale before Apply.
- TR-05: Apply and Undo revalidate the exact persisted baseline/candidate and roll back safely on failure.
- TR-06: Saved edit uses one action based on impact; re-tune failure preserves the draft and prior saved tune.
- TR-07: `Available settings` never implies accuracy validation; no synthesized confidence score is added.

### Validation And Beta Missions

- VB-01: Every research step is visibly optional and grouped per saved setup with at most one recommended next optional step.
- VB-02: Local-only Test Drive save does not require reuse permission and cannot produce export/share/packet data.
- VB-03: Reuse authorization binds to the immutable observation fingerprint and can be granted or revoked for future export.
- VB-04: Validation drafts persist factual fields only, are revision/build/capture-bound, and fail closed when stale or corrupt.
- VB-05: Long forms show real required-field progress, next incomplete field, inline errors, Resume, Save & Exit, and Discard Draft.
- VB-06: No observational field is silently preselected or prefilled without a visible verified source.
- VB-07: Mission-origin success/back/stale handling returns to a refreshed board with specific local/reuse outcome copy.
- VB-08: Validation Review separates Import, Reviewed Sessions, Local Queue, and Independent Review Files; deletion is recoverable/confirmed.
- VB-09: Existing exact-match, replay, quarantine, authorship, and permission validation remains fail closed.

### Settings And Step Guide

- SG-01: Provider choices are accessible vertical cards with preference, readiness, fallback, and privacy summary.
- SG-02: Settings and Discipline consume one provider disclosure model; Result uses actual `TuneProviderInfo`.
- SG-03: Settings performs presence-only key queries and never displays, announces, logs, or copies a stored secret.
- SG-04: Replacing/clearing a key requires explicit confirmation; failures preserve the prior credential.
- SG-05: Privacy copy exactly matches generation/refinement payload allow-lists and explains that a remote attempt may precede local fallback.
- SG-06: Step Guide presents exactly four choices and an up-front local/deterministic/no-transcript boundary.
- SG-07: A stale/rejected Step Guide action leaves the sheet open, removes the invalid action, and explains/announces the change.
- SG-08: Exactly one actionable Step Guide entry exists per surface.

## 6. Non-Goals

- No change to tuning formulas, provider routing order, evidence integrity policy, public API contracts, accounts, cloud sync, analytics, or App Store public release.
- No general AI chat, arbitrary Step Guide questions, automatic API-key test, confidence score, streak, countdown, confetti, urgency, or public ranking.
- No catalog/roster restoration without documented redistribution rights and a separate legal/product spec.
- No persistence of New Tune drafts or pasted external validation JSON.

## 7. Architecture And Ownership

Immutable foundation order:

```text
T1 Theme/Foundation
  -> S1 Settings Contracts
    -> R1 Root Workflow/Foundation
      -> V1 Validation Public Contract
        -> UX_PARALLEL_BASE
```

Final ownership:

- Theme/Foundation: `ForzAdvisorTheme.swift`, shared visual/accessibility primitives, contrast tests.
- Settings contracts/UI: provider disclosure, Keychain capabilities, Settings, Step Guide domain/sheet.
- Root Workflow/Foundation: `ContentView*`, workflow/session state, toolbar placement/routing, generation/refinement task lifecycle, catalog route cleanup, root adapters.
- Validation: `SavedTune` persistence-model changes, evidence schema/drafts, mission domain/views, capture/review/import/packet screens, evidence summary contract.
- Result: Tune Result composition, apply/copy/settings/refinement UI, saved edit, read-only evidence hub shell/adapters.
- Garage, New Tune, Discipline: their view-specific files and focused tests only.
- Integration/Release: canonical spec, monolithic UI-test cleanup, project/scheme, public docs, commit/push/cloud/TestFlight.

No parallel view branch may edit a shared foundation file or create a duplicate shared contract.

## 8. Test Plan

Each acceptance criterion maps to focused unit/state tests plus a view-specific UI test where user-visible behavior is involved.

Required buckets:

- domain and validation: OCR review, form validation, browse criteria, refinement stale checks, local/reusable evidence filtering;
- state/navigation: draft/back/cancel/retry, provider session snapshot, mission-origin return, Step Guide stale action;
- persistence/migration: Garage delayed removal, refinement Apply/Undo rollback, validation schema v1/v2 and draft store;
- privacy/security: payload allow-lists, no secret read in Settings, no local-only evidence export;
- UI/accessibility: portrait/landscape, light/dark, Accessibility Dynamic Type, VoiceOver order/status, 44-point targets, Increase Contrast;
- localization-sensitive terminology: FH5 Build Plan, FH6 Tune, Available/Withheld Settings, Optional Validation & Research;
- release identity: bundle, scheme, branch, remote, signing, App Store Connect record, version/build.

## 9. Implementation And Merge Plan

After approval:

1. Create and verify T1, S1, R1, and V1 sequentially; each lands as an immutable zero-warning commit.
2. Create all Sol Medium view worktrees from the exact `UX_PARALLEL_BASE` commit.
3. Run Garage, New Tune, Discipline, Settings UI, Validation, and Result slices in parallel with disjoint file allowlists.
4. Merge into `ux/integration` in this order: Validation, Settings UI, New Tune, Discipline, Garage, Result, integration/spec/docs cleanup.
5. A final Sol Medium integrator owns root cleanup, terminology, UI-test reconciliation, full verification, and release handoff.

Known textual conflicts are removed by ownership. Zero merge conflicts cannot be guaranteed because SwiftUI type checking, hidden file-private dependencies, migration compatibility, test fixtures, signing, and external CI can fail independently.

## 10. Delivery And Rollback

Delivery gate:

1. focused and full local tests;
2. clean local Xcode build with zero errors and zero warnings;
3. simulator critical-flow, visual, and accessibility review;
4. diff, secrets, migration, version, signing, branch, and remote audit;
5. immutable integration commit and push;
6. Xcode Cloud Verify green;
7. release archive/workflow green;
8. internal TestFlight delivery;
9. report exact commit and build.

App Review is a separate explicit approval.

Rollback is commit-based for non-persistent view slices. Validation schema v2 is the main rollback boundary: prefer additive, backward-readable storage; if an older build cannot reopen a v2-written store, the release becomes roll-forward-only and requires explicit approval before TestFlight. Never roll back by deleting a local user store.

## 11. Task Checklist

- [x] User approves the proposed product decisions and full scope.
- [x] T1 Theme/Foundation lands green.
- [x] S1 Settings Contracts lands green.
- [ ] R1 Root Workflow/Foundation lands green.
- [x] V1 Validation Public Contract and migration fixtures land green.
- [ ] Six Sol Medium view slices land green from one immutable base.
- [ ] Integration acceptance criteria and terminology pass.
- [ ] Local build/test/accessibility gates are green with zero warnings.
- [ ] Immutable integration commit is pushed.
- [ ] Xcode Cloud Verify and release workflows are green.
- [ ] Internal TestFlight build is delivered.

## 12. Research Basis

Recommendations prioritize repository behavior and Apple platform guidance, supported by research on cognitive load, autonomy, reversibility, uncertainty, and ethical choice architecture. Choice overload, Hick's law, goal-gradient, and confidence-display findings are treated as context-dependent rather than universal laws. No dark patterns, coercive engagement loops, or fabricated certainty are included.
