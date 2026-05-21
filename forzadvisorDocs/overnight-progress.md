# Overnight Progress

## 2026-05-20 02:21 PDT

- Built the first local MVP slice: garage home, manual entry, discipline picker, deterministic tune generation, and tune display in Forza tune-menu order.
- Added domain models for car inputs, discipline, drivetrain, validation issues, tune requests, sections, lines, notes, and sample data.
- Added `TuneProvider` plus `LocalSampleTuneProvider` so the app can generate complete tunes offline without API keys.
- Replaced the starter screen with a SwiftUI workflow and copyable tune values via the pasteboard.
- Files changed/added: `forzadvisor/ContentView.swift`, `forzadvisor/Models/TuningDomain.swift`, `forzadvisor/Services/TuneProvider.swift`, `forzadvisor/Views/GarageHomeView.swift`, `forzadvisor/Views/ManualEntryView.swift`, `forzadvisor/Views/DisciplinePickerView.swift`, `forzadvisor/Views/TuneResultView.swift`.
- Verification: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer /Applications/Xcode.app/Contents/Developer/usr/bin/xcodebuild -project forzadvisor.xcodeproj -scheme forzadvisor -destination 'generic/platform=iOS Simulator' build` succeeded.
- Tests: no test target exists yet, so no test command was run.
- Blockers/notes: CoreSimulator service emitted environment warnings during build discovery, but the generic simulator build completed successfully. `#Preview` macros were removed because this sandbox could not run Xcode's preview macro plugin reliably.
- Next best slice: add SwiftData-backed saved tune persistence and a small unit test target for validation/provider determinism.

## 2026-05-20 03:01 PDT

- Added SwiftData-backed garage persistence for generated tunes using `SavedTune`, with searchable metadata and encoded `TuneResult` payloads for detail display.
- Wired the root app to a `SavedTune` model container and changed the root flow to query, save, open, and delete persisted garage rows.
- Updated the garage list to keep search and discipline filtering while showing persisted discipline, class, PI, and drivetrain metadata.
- Files changed/added this run: `forzadvisor/Models/SavedTune.swift`, `forzadvisor/forzadvisorApp.swift`, `forzadvisor/ContentView.swift`, `forzadvisor/Views/GarageHomeView.swift`, `forzadvisorDocs/overnight-progress.md`.
- Verification: `/Applications/Xcode.app/Contents/Developer/usr/bin/xcodebuild -project forzadvisor.xcodeproj -scheme forzadvisor -destination 'generic/platform=iOS Simulator' build` succeeded after SwiftData isolation cleanup.
- Tests: no test target exists yet, so no test command was run.
- Blockers/notes: build still emits the existing run-destination/AppIntents metadata notices, but no app-code build failure blocked this slice.
- Next best slice: add a focused test target for validation and deterministic local tune generation, then scaffold OCR confirmation models around Vision.

## 2026-05-20 04:19 PDT

- Added a focused `forzadvisorTests` XCTest target to the existing Xcode project and attached it to the `forzadvisor` app target.
- Added validation and deterministic local-provider coverage in `forzadvisorTests/TuningDomainTests.swift`.
- Verified the tests cover starter input validity, invalid range reporting, tune-menu section order, and deterministic generated tune values.
- Updated the docs synchronized-group exception so `forzadvisorDocs/overnight-progress.md` stays out of the built app bundle.
- Files changed/added this run: `forzadvisor.xcodeproj/project.pbxproj`, `forzadvisorTests/TuningDomainTests.swift`, `forzadvisorDocs/overnight-progress.md`.
- Verification: `/Applications/Xcode.app/Contents/Developer/usr/bin/xcodebuild -project forzadvisor.xcodeproj -scheme forzadvisor -destination 'generic/platform=iOS Simulator' build` succeeded after the project cleanup.
- Tests: `/Applications/Xcode.app/Contents/Developer/usr/bin/xcodebuild -project forzadvisor.xcodeproj -scheme forzadvisor -destination 'platform=iOS Simulator,name=iPhone 17' test` succeeded; 4 `TuningDomainTests` tests passed.
- Blockers/notes: no app-code blockers. `simctl list devices available` briefly reported a CoreSimulator connection error, but `xcodebuild test` recovered by using an iPhone 17 clone.
- Next best slice: scaffold OCR result/confirmation models around Vision, then add the capture-to-confirm manual fallback route.

## 2026-05-20 05:52 PDT

- Added OCR confirmation draft domain types so Vision extraction can stay editable and confidence-aware before becoming a `CarInput`.
- Added `VisionCarInputOCRService`, a Vision-backed boundary that returns OCR text observations through the deterministic parser.
- Added parser coverage for required field extraction, comma-formatted pounds, kilogram conversion, low-confidence review flags, and confirmed-car validation.
- Fixed the weight parser after the first test run exposed `3,340 lb` being captured as `340`.
- Files changed/added this run: `forzadvisor/Models/OCRConfirmation.swift`, `forzadvisor/Services/OCRService.swift`, `forzadvisorTests/OCRTextParserTests.swift`, `forzadvisorDocs/overnight-progress.md`.
- Verification: `/Applications/Xcode.app/Contents/Developer/usr/bin/xcodebuild -project forzadvisor.xcodeproj -scheme forzadvisor -destination 'generic/platform=iOS Simulator' build` succeeded.
- Tests: `/Applications/Xcode.app/Contents/Developer/usr/bin/xcodebuild -project forzadvisor.xcodeproj -scheme forzadvisor -destination 'platform=iOS Simulator,name=iPhone 17' test` succeeded; 8 tests passed across `TuningDomainTests` and `OCRTextParserTests`.
- Blockers/notes: no app-code blockers. Test diagnostics still emitted a `simctl` path warning on one failed pre-fix run, but the final rerun succeeded on an iPhone 17 clone.
- Next best slice: add the photo import/capture entry and editable OCR confirmation screen, then route confirmed values into the existing discipline picker.

## 2026-05-20 07:27 PDT

- Added a New Tune source screen that lets the player import a performance screenshot from Photos or fall back to manual entry.
- Wired imported images through `VisionCarInputOCRService`, converting photo data to `CGImage` and routing the parsed `OCRConfirmationDraft` into review.
- Added an editable OCR confirmation screen with highlighted low-confidence/missing required fields, optional horsepower/torque fields, and validation-gated handoff into the existing discipline picker.
- Updated the root workflow so Home opens the source chooser, manual cancel returns there, and confirmed OCR values continue through tune generation.
- Files changed/added this run: `forzadvisor/ContentView.swift`, `forzadvisor/Views/NewTuneStartView.swift`, `forzadvisor/Views/OCRConfirmationView.swift`, `forzadvisorDocs/overnight-progress.md`.
- Verification: `/Applications/Xcode.app/Contents/Developer/usr/bin/xcodebuild -project forzadvisor.xcodeproj -scheme forzadvisor -destination 'generic/platform=iOS Simulator' build` succeeded.
- Tests: `/Applications/Xcode.app/Contents/Developer/usr/bin/xcodebuild -project forzadvisor.xcodeproj -scheme forzadvisor -destination 'platform=iOS Simulator,name=iPhone 17' test` succeeded; 8 tests passed across `TuningDomainTests` and `OCRTextParserTests`.
- Blockers/notes: no app-code blockers. This slice uses Photos import, not live camera capture, so it avoids camera permission and AVFoundation setup for now.
- Next best slice: add an AVFoundation/PHPicker capture wrapper or a lightweight saved-tune detail adjustment surface, depending on whether photo capture or feel adjustments should come next.
