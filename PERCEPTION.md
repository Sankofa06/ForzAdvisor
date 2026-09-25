# Current Perception

This file is the replace-in-place record for one active goal. It describes current intent and evidence; it is not authority, history, or durable memory.

## Active goal

- Status: active
- Refreshed: 2026-09-25
- Goal: consolidate the pending ForzAdvisor product and release work through a protected-main review, then deliver the reviewed app as an internal-only TestFlight build.
- Success: the exact merged source passes the repository and Apple verification gates, reaches App Store Connect state `VALID`, is associated with the existing Internal group, and has a numbered owner live-test plan.
- Constraints: the owner authorized internal TestFlight delivery for this code work. Preserve the existing app identity, team, and automatic signing policy. No App Review, public release, participant contact/recruitment, session recordings, or pilot execution. The FH6 research pilot remains gated on an exact existing build/access route, a rights-cleared identifiers-free fixture, and separate recruitment/consent approval. Preserve FH5 plan-only, roster/rights, offline-default, provider-disclosure, and accuracy-claim boundaries.

## Current evidence

- Successes: Issue 4's OCR evidence, measurement alternatives, conflict checks, and result actions are on the consolidation branch. The unique honest-first-tune and FH6 evidence-withholding changes are preserved. The stable runner pin is 24G830; the candidate export is internal-only and retains automatic signing. Existing build 87 is recorded as valid and associated with Internal; its owner live-test plan remains pending.
- Failures: earlier release candidates 79–86 failed or were rejected for the reasons recorded in their release history; those records remain intact.
- Open hypotheses: first-time users may confuse performance OCR with car identity entry; store speed language may need substantiation; the candidate trust-and-setup wedge has not been shown to be a competitive moat.
- Active signals: the new consolidated source has not yet completed its final static, Xcode, UI, and fresh independent review gates. The next build number and current App Store Connect state require a fresh lookup before allocation. The research pilot's exact install/access route, screenshot fixture, and recruitment/consent approvals remain blocked.
- Acceptance gates: (1) final source checks and ReleaseVerify; (2) focused UI/accessibility verification; (3) fresh independent review on the frozen PR artifact; (4) fresh App Store Connect build lookup and stable-runner preflight; (5) exact archive identity and `VALID` processing; (6) association to the configured Internal group; (7) owner live verification of every numbered scenario; (8) pilot inputs and approvals remain separate.
- Delivery target: protected-main pull request and an internal-only TestFlight build; no App Review or public release.
- Next action: finish source integration and verification, then allocate a build only after the live App Store Connect lookup.

## Refresh contract

- Keep one active goal and one current definition of success.
- Refresh after a material decision, success, failure, constraint change, or new evidence.
- Every observation needs a source/date or must be labeled as a hypothesis.
- Remove resolved signals instead of accumulating a historical log.
- Clear the active goal when completed; durable lessons are promoted separately through `MEMORY.md`.
- Never store secrets, raw transcripts, hidden reasoning, sensitive personal information, or private infrastructure identifiers.
