# Release Notes

## Version 1.1.1 (Build 4) - 2026-06-01

- Improved reliability, usability, and app polish.

## Version 1.1.0 (Build 3) - 2026-06-01

- Improved data management reliability for saved app content.
- Improved navigation and workspace status visibility.

## Shipflight 2026-05-31

- Branch: `codex/app-store-ready-1.0`
- Build number bumped for TestFlight upload.
- Changed files:
- ` M AppStore/metadata.md`
- ` M AppStore/privacy-policy.md`
- ` M AppStore/release-checklist.md`
- ` M AppStore/support.md`
- ` M docs/privacy/index.md`
- ` M docs/support/index.md`
- ` M forzadvisor.xcodeproj/project.pbxproj`

### Recent commits

- f01ba98 Prepare ForzAdvisor App Store release
- 28c772b Prepare App Store release package
- 0cb07e2 Add copyable tune sections
- c5d1ea8 Add on-device tuning provider
- ac5d979 Remove legacy OCR parser



Last updated: 2026-05-31

## App Store What's New - Version 1.0

ForzAdvisor 1.0 introduces a complete racing setup workflow: photo and screenshot OCR, manual car entry, discipline-based tuning, saved garage history, copyable tune output, and optional AI-assisted tune generation with offline fallback.

## TestFlight Notes

This first TestFlight build is ready for end-to-end tuning feedback. Please verify that manual entry, discipline selection, generated tune sections, saving, reopening, copying, and feel adjustments all work as expected.

Camera and photo import are optional. Screenshot OCR runs on device. API mode requires the tester to provide their own Anthropic API key; offline formula tuning is the default path and does not require an account.

## Reviewer Notes

No login is required. Reviewers can complete the core app flow through New Tune -> Enter Manually -> Next -> select any discipline -> Save.
