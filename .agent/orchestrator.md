# Orchestrator Intake

Date: 2026-06-27

## Mode

Mode A - Improve Existing App.

## Repo Purpose

ForzAdvisor is a SwiftUI iPhone app that helps Forza players create, save, copy, and refine vehicle tunes from photo/screenshot OCR or manual performance input. The current implementation is beyond the initial PRD: it includes SwiftData garage persistence, OCR confirmation, camera/photo/manual entry, offline formula generation, optional Anthropic API mode, optional on-device model mode, guided refinement, tests, App Store materials, and screenshot assets.

## Architecture And Targets

- App source: `forzadvisor/`
- SwiftUI coordinator: `ContentView.swift` and `ContentView+Workflow.swift`
- Views: `forzadvisor/Views/`
- Domain models: `forzadvisor/Models/`
- Tune providers and OCR/API/keychain services: `forzadvisor/Services/`
- Tests: `forzadvisorTests/` and `forzadvisorUITests/`
- Xcode project: `forzadvisor.xcodeproj`
- Shared scheme: `forzadvisor.xcscheme`

## Autonomy Defaults Used

- Loop count: recurring 30-minute factory heartbeat; each wakeup should complete one coherent slice when possible.
- Priority: reliability and product polish.
- Commits: allowed only after successful validation; withheld currently because UI test validation is not clean.
- Push/TestFlight/App Store: not allowed without explicit approval.
- GitHub issues: not attempted without explicit approval.
- Live community/web research: not used.
- Subagents: used for product, reliability, and code-health audits.

## Immediate Risks

- App build and unit tests pass, but the UI test runner is currently denied launch by the simulator before assertions run.
- Async generation, adjustment, and OCR/import tasks need stale-completion guards.
- Several app files are near the PRD's 350-line limit; no large refactor is warranted in this loop.
- Anthropic API mode silently falls back to offline formulas, which is reliable but could use stronger user-visible status in a future loop.
