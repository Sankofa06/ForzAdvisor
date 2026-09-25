# FH6 First-Tune Pilot Protocol

**Status:** Preparation only. This document does not authorize recruiting, participant contact, installing or running the app, recording, App Store Connect access, or distributing a build.

**Pilot scope:** Six first-time ForzAdvisor users who play Forza Horizon 6 (FH6). Each person uses the same owner-provided, rights-cleared screenshot fixture to create and save one FH6 Road tune. The exercise is for diagnosing first-use comprehension and flow friction; it is not a tune-quality or population study.

## Purpose and hypotheses

Observe whether a new ForzAdvisor user can start an FH6 tune, locate and review OCR results from the supplied screenshot, supply or correct the car facts if needed, choose a discipline, understand the provider and privacy disclosure, explicitly start generation, save the result, and explain what the available settings do and do not establish.

The following are **hypotheses to investigate**, not findings:

- A first-time user may confuse car identity (year, make, model) with performance facts (weight, front-weight percentage, PI, class, and drivetrain), especially when choosing between photo/screenshot input and manual entry.
- A first-time user may not understand that each detected or entered value needs review before generation.
- A first-time user may confuse the expected provider route with the provider actually used, or misunderstand the local versus remote data boundary.
- A first-time user may interpret “available settings” as evidence that a tune is accurate or validated.

### Product facts to preserve

- New Tune offers photo, screenshot import, and manual entry. The photo/screenshot path uses on-device Vision OCR and asks the user to review values; manual entry separates Car and Performance fields. The app has no bundled car roster; people supply the car facts.
- FH6 can produce menu-order numeric settings using offline formulas. Projection checks local capability and range; unsupported values can be withheld.
- Offline formulas are the default. Apple on-device model assistance is optional and may be unavailable; the optional Anthropic API route requires a user-provided key and sends confirmed text details only when selected. Provider readiness or expected route does not substitute for the actual provider shown after generation.
- “Available” means a value can be entered in the game. It is not an accuracy score or validation result.
- FH5 is outside this pilot. FH5 remains a local, numeric-free build plan; do not switch the task to FH5 or imply FH5 numeric tuning is available.

Source evidence: `forzadvisor/Views/NewTuneStartView.swift:45-102`, `forzadvisor/Views/OCRConfirmationView.swift:62-78`, `forzadvisor/Views/ManualEntryView.swift:45-134`, `docs/specs/psychological-ux-cohesion.md:15-22`, `AppStore/metadata.md:21-33`, `docs/privacy/index.md:17-25`, `forzadvisor/Views/DisciplinePickerView.swift:45-92`, `forzadvisor/Views/TuneResultPresentation.swift:51-80`, `forzadvisor/Views/TuneAvailableSettingsSection.swift:10-15`, and `docs/fh5-numeric-readiness-policy.md:34-37`.

## Go/no-go gates: exact build, access, and screenshot fixture

**Current status: BLOCKED. Do not start a session until the owner confirms the exact existing installable binary/access route and provides the exact rights-cleared, identifiers-free screenshot fixture.** Local repository evidence conflicts: the project Debug and Release settings specify build 78 (`forzadvisor.xcodeproj/project.pbxproj:452-474`, `486-509`); App Store metadata lists build 77 (`AppStore/metadata.md:82-85`); the release record describes build 77 as invalid and build 78 as the later repair (`AppStore/releases/1.41.1.md:17-19`, `48-67`, `89-93`). These records do not establish which binary is presently installed or accessible. Do not infer the answer from the project setting or query App Store Connect as part of this protocol.

Before any test, have the owner fill and confirm this identity/access record from an existing artifact or installation:

- App name and bundle ID: `ForzAdvisor` / `com.michaelwilliams.forzadvisor`.
- Exact marketing version and build number shown by the installable binary.
- Immutable source commit or other artifact provenance that uniquely identifies that binary.
- Exact existing installation/access route and how the six participants can use it. No new build, upload, TestFlight distribution, App Store Connect lookup, or public release is part of this plan.
- Test device and iOS version, plus confirmation that the app opens to the intended first-use state.
- Before a session, confirm the FH6 generation preference is **Offline**, the expected data boundary is local-only, and no API key or remote-generation route will be used. Do not enter, inspect, or request an API key. If this safe route cannot be confirmed, do not start.
- Owner confirmation: `____________________`  Date: `____________`  Artifact/access evidence reference: `____________________`.

A mismatch, missing field, uncertain provenance, unavailable install route, unexpected API-key prompt, or remote route is a stop condition. This protocol does not include creating, building, signing, or distributing an app binary.

**Screenshot fixture is also a hard prerequisite.** Before any participant session, the owner must provide one exact screenshot fixture for all six participants and confirm that its use is rights-cleared for this pilot. The owner must verify that it contains no player/account identifiers or unrelated personal information and that the required FH6 car/performance facts are legible and sufficient for the task. Record only an opaque fixture reference and the owner’s clearance confirmation; do not copy the screenshot into research notes or this repository. Do not search for, generate, edit, capture, or substitute a game screenshot. If the exact fixture is not provided, rights clearance is uncertain, identifiers/unrelated personal information remain, or the required fields cannot be read, the pilot remains blocked.

- Fixture reference (no image content): `____________________`.
- Owner confirms same exact fixture for all six, rights-cleared, identifiers/personal data cleared, and required fields legible: `____________________`  Date: `____________`.

## Participants and separately gated recruitment

Recruit exactly six adults who:

- have played FH6 and can attempt the supplied screenshot-fixture task;
- have never used ForzAdvisor before; and
- can voluntarily consent to this short session.

Do not require or collect a gamer tag, account login, real car ownership, personal tuning history, or technical background. Participants use only the owner-provided fixture; do not ask for or accept screenshots from their personal game. Accommodate a participant’s preferred input or accessibility method where feasible; do not retain disability or health details.

**Recruitment is a separate approval gate.** No invitation, outreach, participant scheduling, or compensation offer is authorized by drafting this protocol. Before recruitment, the owner must separately approve the recruiting channel and wording, who may contact participants, any compensation, and the consent/notes handling process. Participant access must use only the owner-confirmed existing build route above.

## Consent and data minimization

Before the task, say that the session evaluates the app flow, not the participant; participation is voluntary; the participant may pause or stop at any time; and no audio, video, screen, or camera recording will be made. Explain that the app processes the screenshot on device and may retain a small local thumbnail with the saved tune. Ask permission to take brief, non-identifying notes. Do not begin unless they agree. If they withdraw, stop immediately and discard that session’s notes.

Do not enable analytics, screen capture, or recording. Do not collect names, contact details, account or device identifiers, gamer tags, copies of the screenshot, API keys, car identity/performance values from the fixture, or verbatim transcripts. Use session labels S1–S6 and note only: task completed or not, unaided or assisted, elapsed task time as descriptive context, OCR/review recovery codes, save completion, optional cleanup choice, blocker/recovery codes, and whether a critical misunderstanding occurred. The saved fixture-derived tune remains local unless the participant chooses the Garage removal action. The app may retain a small local screenshot thumbnail with that saved tune; do not promise that removal erases every app copy. Research staff keep no separate screenshot copies or session recordings. Keep the note sheet outside the repository, accessible only to the owner/research lead, and delete session-level notes after the six-session summary and any decision are complete; retain only anonymous aggregate counts and the short diagnosis needed for that decision.

## Neutral task script

Use the same opening and task wording for each participant and give them the exact owner-provided fixture. Do not explain the screens or tell them which buttons or fields to use.

> “Thanks for helping. We are evaluating this app flow, not you; there are no right or wrong answers. You can stop at any time. I’ll take brief notes, but I won’t record the session. Please use this screenshot to create and save a Road tune for FH6 in the app. Tell me when you think you’re finished. I’ll stay quiet while you work, then ask what you think the result means.”

Use the same owner-provided, rights-cleared fixture for all participants. The screenshot is the task input so the session exercises screenshot import, OCR review, and any recovery the participant chooses. Do not describe the fields or OCR output in advance. Do not retain its image or transcribe its values into research notes. This session does not measure tuning accuracy or establish FH6 tune quality.

If the participant asks for help, use only this neutral prompt once: “What would you try if I weren’t here?” Any directional hint makes the run assisted, not unaided. Do not suggest the correct path, interpret a label for them, or ask them to change the provider. Stop before any remote-generation attempt.

After they say they are done, ask these same neutral comprehension questions:

1. “What information did you use for the car identity, and what information did you use for performance?”
2. “What do you think ‘Available settings’ means?”
3. “Does this result prove the tune is accurate in FH6? What on this screen led you to that answer?”
4. “Which generation method and data route did you expect? Which method does the completed result say it actually used?”
5. “If, later, you chose the optional API method, what do you think would happen to the confirmed car details and the screenshot?”

Question 5 is hypothetical only. Keep the app on Offline, do not change provider settings, request or enter a key, or make a remote request. Do not supply the answer during the session.

## Observation and scoring rules

Observe without coaching and note only event codes and outcomes. Record task start/end time as descriptive context; duration is not a pass/fail criterion:

- whether the participant finds screenshot import, understands that OCR results need review/confirmation, and recovers from uncertain or missing values;
- attempts to put identity facts in performance fields or performance facts in identity fields, and whether the participant catches and recovers from it;
- hesitation, repeated navigation, field-validation messages, skipped required inputs, backtracking, and whether a neutral prompt was needed;
- whether the participant selects FH6 and Road, reviews the pre-generation provider/privacy disclosure, and deliberately starts generation;
- whether the result is complete, is saved to Garage, and the participant correctly distinguishes “available” from “validated”; and
- any provider/data-boundary expectation that differs from the route displayed after completion.

**Unaided completion:** the participant creates a complete FH6 Road tune from the supplied screenshot fixture and saves it to Garage without any directional facilitator hint or facilitator action. There is no time cutoff; elapsed time is descriptive context only. A neutral reminder of the task wording does not count as directional help, but is recorded. Successful output alone does not count if the participant has selected the wrong game, car identity, or discipline and does not correct it before finishing.

**Critical misunderstanding:** after the task and the neutral comprehension questions, the participant still expresses or acts on at least one of these beliefs: (a) available settings prove accuracy, validation, or guaranteed performance; (b) the app looked up their car in a bundled roster or does not require user-supplied car facts; (c) the optional API method is local-only, or the screenshot itself is sent remotely by ForzAdvisor when that route is selected; or (d) they completed the result for a different game/car than intended because they treated identity and performance facts as interchangeable. Record yes/no and one short, de-identified paraphrase only. A corrected field entry, hesitation, or recoverable validation error by itself is an ordinary blocker, not a critical misunderstanding. The participant must remain on Offline for the task; do not create an actual remote-route condition.

## Run sheet

1. **Before scheduling:** resolve the owner build/access gate and the separate recruitment gate. Confirm the exact existing binary and offline-only setup; otherwise stop here.
2. **At session start (about 3 minutes):** confirm eligibility and consent; assign S1–S6; read the script; provide the same owner-approved screenshot fixture. Do not collect identifying details.
3. **Task:** start at Garage and observe silently. Note start/end time as descriptive context, route, completion, blockers, recovery, save completion, and whether a neutral prompt was needed. The task has no time-based pass/fail cutoff. The participant must save the completed tune to Garage; do not continue into validation/research features.
4. **Comprehension:** ask the five fixed questions in order. Mark unaided completion and critical misunderstanding using the definitions above.
5. **Close:** thank the participant, answer any questions without reframing their task performance, and let them know no recording or separate research screenshot copy was made. Explain that the saved tune remains local and the app may retain its small local screenshot thumbnail. Ask whether they want to keep it or choose optional cleanup themselves. If they choose removal, describe the Garage swipe-to-Remove action, its six-second Undo window, and that leaving Garage commits a pending removal; do not remove it for them, assume the removal succeeded, or promise that all app data/copies are erased. Secure the minimal notes.
6. **After six sessions:** produce anonymous counts and a short diagnosis against the thresholds below. Do not publish participant-level notes or infer tune quality.

## Stop conditions

Stop before a participant session if the exact binary or access route is not owner-confirmed, the exact screenshot fixture is not provided and confirmed rights-cleared and identifiers/personal-data-free, any identity field is missing or inconsistent, the app is not in the safe Offline route, recruitment/consent has not been separately approved, or the binary cannot be installed without creating/distributing a new build.

Stop the task immediately if the participant withdraws, an API key or account is requested, a remote generation attempt is about to occur, unexpected data sharing appears, fixture contents reveal an identifier or unrelated personal data, the binary/version or screenshot fixture changes, the app crashes or loses the task, or continuing would require real personal/game data. Do not troubleshoot by changing providers or using a different build. If FH5 is selected, stop the numeric-tune task, record it as incomplete/out of scope, and do not imply that FH5 produces numeric settings.

## Directional interpretation only

- **Screen for further diagnosis only:** at least **5 of 6** participants complete unaided **and zero of six** have a critical misunderstanding. This is not proof of general usability, accuracy, safety, or tune quality.
- **Diagnose a recurring ordinary blocker:** the same ordinary blocker appears in at least **2 of 6** sessions. This justifies inspecting that specific flow; it does not establish prevalence.
- Any critical misunderstanding, even once, warrants reviewing that exact screen/wording before making claims that users understood it. Six sessions cannot estimate how common the issue is.
- Treat all counts as directional observations from this small convenience sample. Do not claim population-level results, statistical significance, competitive advantage, OCR accuracy, or FH6 tune-quality validation. Any product change requires separate evidence and the existing implementation/review gates.

## Source map

All references below are repository-relative and support the product facts and build gate in this protocol:

- Source choices, on-device OCR copy, and manual entry option: `forzadvisor/Views/NewTuneStartView.swift:45-102`.
- OCR review prompt and required-input explanation: `forzadvisor/Views/OCRConfirmationView.swift:62-78`.
- Separate Car and Performance sections; required/optional fields: `forzadvisor/Views/ManualEntryView.swift:45-134`.
- Intended end-to-end flow: `docs/specs/psychological-ux-cohesion.md:15-22`.
- No bundled roster; FH6 offline formulas; FH5 plan-only; optional provider modes: `AppStore/metadata.md:21-33`.
- Offline default, conditional Anthropic data path, optional on-device fallback: `docs/privacy/index.md:17-25`.
- Pre-generation provider/privacy details and explicit start: `forzadvisor/Views/DisciplinePickerView.swift:45-92`.
- Actual provider shown after completion: `forzadvisor/Views/TuneResultPresentation.swift:51-80`.
- Available settings are not accuracy/validation evidence: `forzadvisor/Views/TuneAvailableSettingsSection.swift:10-15`, `forzadvisor/Views/TuneResultPresentation.swift:31-47`.
- Saving is a separate local action: `forzadvisor/Views/TuneResultActionSections.swift:104-124`; screenshot OCR may leave a local thumbnail with a saved tune: `docs/privacy/index.md:9-15`.
- Participant-controlled Garage removal uses swipe-to-Remove with a six-second Undo window: `forzadvisor/Views/GarageHomeView.swift:87-110`, `132-160`.
- FH5 numeric output remains unavailable: `docs/fh5-numeric-readiness-policy.md:34-37`.
- Build identity discrepancy: `forzadvisor.xcodeproj/project.pbxproj:452-474`, `forzadvisor.xcodeproj/project.pbxproj:486-509`, `AppStore/metadata.md:82-85`, `AppStore/releases/1.41.1.md:17-19`, `AppStore/releases/1.41.1.md:48-67`, `AppStore/releases/1.41.1.md:89-93`.
