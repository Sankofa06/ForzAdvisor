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

## Repository-Local Agent Framework

`AGENTS.md` is this repository's controlling governance. `PERCEPTION.md` holds one replace-in-place active goal and current evidence; `MEMORY.md` holds curated shared lessons; `PERSONA-*.md` and matching `memory/personas/*.md` files hold bounded role contracts and role-scoped lessons; `.agents/skills/the-perfect-agent/` is the framework's one repository-owned skill.

- At task start, read `PERCEPTION.md`; treat any relevant active commission as current intent below user and repository authority. Retrieve only relevant `MEMORY.md` entries and revalidate them.
- Work solo by default. Activate the local `the-perfect-agent` skill only for an explicit workforce request, genuinely cross-system, release-critical, or high-consequence work, or when independent acceptance is the defining need.
- When a persona is assigned, load only that persona and its matching memory. A fresh reviewer must not receive builder rationale, prior criticism, or case-specific memory.
- Refresh `PERCEPTION.md` in place after material goal, evidence, scope, success, or failure changes and clear it at close. Promote memory only when evidence-backed, reusable, scoped, and non-sensitive; delete stale entries.
- These files and skills never widen authority. Implementation, local commit, push or pull request, phone delivery, App Review, and public release remain distinct repository-governed states.

The local skill supplies the framework's role and evidence contracts. The global `full-workforce` requirement above remains controlling where applicable; use the local contracts within that workflow rather than creating competing commissions. All current repository development, verification, release, and authority rules remain controlling, including standing delivery authorization. Framework state and personas do not override them.

Run `scripts/validate-agent-framework.sh` after changing these framework files. This adoption uses The Perfect Agent v1 from commit `1f5ea0b`; the repository-specific validator checks the adopted files without imposing the upstream project's website or publication requirements. The upstream MIT license is retained in `.agents/skills/the-perfect-agent/LICENSE`.
