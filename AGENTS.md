# Repository Guidelines

## Required Common Workforce

This repository inherits the global `Common Workforce and Assurance Workflow` from `~/.codex/AGENTS.md`. Invoke the global `full-workforce` skill for explicit workforce requests and qualifying cross-system or release-critical Program work. The skill coordinates agents but does not widen this repository's authority or release boundaries.

## Required Swift App Workflow

This repository inherits the global `Common Xcode Project Workflow` from `~/.codex/AGENTS.md`. For any task that plans, builds, changes, audits, tests, runs, or delivers this Xcode app, invoke the global `develop-swift-app` skill first. Follow its spec-driven lifecycle and verification/delivery gates. This file supplies repository-specific constraints and takes precedence where it is more specific.

## Project Structure & Module Organization

The canonical checkout is `/Users/blacbook-pro/Agents/ForzAdvisor`; the authoritative remote is GitHub `origin` at `https://github.com/Sankofa06/ForzAdvisor.git`. Do not release from the iCloud mirror or introduce GitLab as a second source of truth. The app source lives in `forzadvisor/`, with unit tests in `forzadvisorTests/` and UI tests in `forzadvisorUITests/`. App Store material lives in `AppStore/`; `forzadvisorDocs/app-store/` is legacy documentation and must point to canonical `AppStore/` files rather than duplicate them. The Xcode project is `forzadvisor.xcodeproj/`; avoid hand-editing it unless the task intentionally changes targets, signing, or build configuration.

## Build, Test, and Development Commands

- Prefer XcodeBuildMCP for local build, test, simulator, signing, and archive operations when it is available.
- `open forzadvisor.xcodeproj` opens the app in Xcode for simulator development.
- `xcodebuild -list -project forzadvisor.xcodeproj` is the fallback discovery command. The shared `forzadvisor` and `forzadvisor Cloud` schemes are committed.
- `ReleaseVerify.xctestplan` is the complete local release gate. Do not distribute a commit until this gate and GitHub Actions Release Verify are green.
- `scripts/release preflight` validates release configuration and local App Store assets without App Store Connect credentials. See `AppStore/release-automation.md` for the full workflow.

## Coding Style & Naming Conventions

Use Swift 5 and SwiftUI conventions. Indent with 4 spaces, keep views small, and extract reusable UI into dedicated `View` structs as screens grow. Name Swift types with `UpperCamelCase`, properties and functions with `lowerCamelCase`, and assets with descriptive names such as `garageBackground` or `tirePressureIcon`. Keep user-facing strings clear and localizable; avoid burying product copy in deeply nested view code.

## Testing Guidelines

Use the existing XCTest conventions. Prefer focused tests for tuning calculations, validation rules, persistence, release contracts, and critical setup flows. Source-contract tests must not depend on host-checkout paths from a simulator process; use behavior assertions or test-bundle fixtures so the same suite runs locally and in GitHub Actions. Long-form UI tests must scroll controls into a hittable state instead of assuming a particular viewport.

## Commit & Pull Request Guidelines

Use concise imperative commit subjects and keep each commit scoped to one logical change. Pull requests should include a short summary, test/build results, linked issue or task when applicable, and screenshots or simulator recordings for visible UI changes. Release cloud runs must resolve to an immutable pushed commit or annotated release tag.

## Agent-Specific Instructions

Preserve existing uncommitted work. Do not rewrite the PRD or Xcode project settings unless the task requires it. Keep generated files, DerivedData, and local Xcode user state out of version control.

## Codex Completion And Release Default

Use the release configuration and coordinator documented in `AppStore/release-automation.md`. The required order is:

1. Complete the non-secret release configuration, privacy attestation, price, content-rights declaration, age-rating status, review contact status, and release policy.
2. Run focused tests, a clean local build, and the complete local `ReleaseVerify` gate with no failures, skips, or source warnings.
3. Review the diff and secret scan, then commit and push an immutable release commit or tag.
4. Require GitHub Actions Release Verify to pass for that exact revision.
5. Only then archive/upload the exact revision through the logical `stable-xcode-26.3-intel` profile and wait for a `VALID`, App Store-eligible build. Physical host selection remains private runner configuration.
6. Run the App Store Connect candidate preflight, attach the exact ASC build, and stage a review draft.
7. Report the ASC build number and obtain explicit human approval before App Review submission. Submission and public release are never implicit.

Credentials remain in environment variables or the external App Store Connect secrets file; never commit or print them. Treat TestFlight as reversible beta delivery. If local simulator infrastructure fails after one owned retry, preserve diagnostics and use the immutable GitHub Actions run as the fresh-machine authority; do not weaken assertions or upload an unverified commit.

Any release document or workflow that selects a GitHub-hosted macOS archive with Xcode 26.6 conflicts with the global stable-runner policy and must not be used for archive or upload. Reconcile that path to the logical `stable-xcode-26.3-intel` profile before the default TestFlight loop may proceed; GitHub Actions may remain a verification oracle for the exact revision.
