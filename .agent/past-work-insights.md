# Past Work Insights

## Lessons

- The app evolved from a manual/offline MVP into a broader release candidate with OCR, SwiftData persistence, API/on-device provider modes, guided refinement, tests, App Store docs, and screenshots.
  - Source: `forzadvisorDocs/overnight-progress.md`, `AppStore/release-notes.md`
  - Confidence: High
  - Influence: Do not treat the PRD as current implementation state.

- Xcode/CoreSimulator has repeatedly been an environmental blocker, but prior successful validation used a concrete installed simulator outside the sandbox.
  - Source: `forzadvisorDocs/overnight-progress.md`
  - Confidence: High
  - Influence: Record validation blockers precisely and avoid cycling on broken local infrastructure.

- The repo favors small vertical slices with tests alongside behavior.
  - Source: `AGENTS.md`, existing `forzadvisorTests/`
  - Confidence: High
  - Influence: Pick a small, verifiable reliability or polish slice.

- Offline formula generation is the default and should remain dependable even when optional providers are unavailable.
  - Source: `CompositeTuneProvider.swift`, `SettingsView.swift`, release notes
  - Confidence: High
  - Influence: Strengthen fallback coverage without changing provider architecture.

## Needs User Confirmation

- Whether future loops should prioritize TestFlight release operations, deeper UI polish, provider transparency, or formula accuracy.
- Whether pushes/uploads are allowed after local Xcode licensing is resolved.
