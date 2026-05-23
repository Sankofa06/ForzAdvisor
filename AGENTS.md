# Repository Guidelines

## Project Structure & Module Organization

This repository is a small SwiftUI iOS app. The app source lives in `forzadvisor/`, with `forzadvisorApp.swift` as the app entry point and `ContentView.swift` as the initial root view. App icons, accent colors, and future image assets belong in `forzadvisor/Assets.xcassets/`. Planning and product notes live in `forzadvisorDocs/`, currently including the tuning app PRD. The Xcode project is `forzadvisor.xcodeproj/`; avoid hand-editing it unless you are adding files, targets, signing settings, or build configuration intentionally.

There are no test targets checked in yet. When adding tests, use conventional sibling targets such as `forzadvisorTests/` for unit tests and `forzadvisorUITests/` for UI tests.

## Build, Test, and Development Commands

- `open forzadvisor.xcodeproj` opens the app in Xcode for simulator development.
- `xcodebuild -list -project forzadvisor.xcodeproj` lists available schemes and targets. Run this before scripting builds because shared schemes are not currently committed.
- `xcodebuild -project forzadvisor.xcodeproj -scheme forzadvisor -destination 'platform=iOS Simulator,name=iPhone 17' build` builds the app from the command line once the `forzadvisor` scheme is available.
- `xcodebuild -project forzadvisor.xcodeproj -scheme forzadvisor -destination 'platform=iOS Simulator,name=iPhone 17' test` runs tests after test targets are added.

## Coding Style & Naming Conventions

Use Swift 5 and SwiftUI conventions. Indent with 4 spaces, keep views small, and extract reusable UI into dedicated `View` structs as screens grow. Name Swift types with `UpperCamelCase`, properties and functions with `lowerCamelCase`, and assets with descriptive names such as `garageBackground` or `tirePressureIcon`. Keep user-facing strings clear and localizable; avoid burying product copy in deeply nested view code.

## Testing Guidelines

Prefer focused XCTest coverage for tuning calculations, validation rules, and persistence once those features exist. Name test files after the unit under test, for example `TuningCalculatorTests.swift`, and name methods like `testRecommendedPressureAdjustsForOversteer()`. UI tests should cover critical setup flows rather than visual details.

## Commit & Pull Request Guidelines

The current history only contains `Initial Commit`, so use concise imperative commit subjects going forward, for example `Add baseline tuning form`. Keep each commit scoped to one logical change. Pull requests should include a short summary, test/build results, linked issue or task when applicable, and screenshots or simulator recordings for visible UI changes.

## Agent-Specific Instructions

Preserve existing uncommitted work. Do not rewrite the PRD or Xcode project settings unless the task requires it. Keep generated files, DerivedData, and local Xcode user state out of version control.

## Codex Completion And Release Default

For completed app-code work, default to this order so a TestFlight build is available while deeper validation continues:

1. Get a clean local Xcode build with zero errors and zero warnings. Treat warnings as blockers before committing.
2. Commit the completed task with a focused message.
3. Push the branch.
4. Upload to TestFlight when signing and App Store Connect configuration are available.
5. After the upload starts or finishes, run the relevant test suite and report results separately.

Do not keep cycling on sandboxed Xcode attempts. If Codex hits sandbox, SwiftPM cache, signing, or CoreSimulator infrastructure failures, use the local Xcode/TestFlight path or the external Xcode gate instead. Preserve unrelated user changes and stop before commit/push/upload only when scope, signing, secrets, or build cleanliness is ambiguous.
