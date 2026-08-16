# ForzAdvisor Release Checklist

Last updated: 2026-08-16

Readiness: TestFlight candidate

The current release removes the bundled FH5/FH6 car rosters and reviewed stock catalog. New tunes start from a user-selected photo, screenshot, or manual entry.

## Completed In Repository

- Bundle identifier is `com.michaelwilliams.forzadvisor`.
- Development team is set to `5RGU344VJR`.
- Installed display name is `ForzAdvisor`.
- Current project version is `1.41.1`.
- Current project build is `77`.
- Target device family is iPhone.
- The three bundled roster/catalog JSON resources are removed.
- The two roster-generation scripts are removed.
- New Tune no longer presents a catalog or roster.
- Settings no longer exposes catalog-contribution tooling.
- Empty-garage validation missions route to manual entry.
- Photo, screenshot OCR, and manual entry remain available.
- App icon assets contain default, dark, and tinted 1024px icons without alpha.
- Camera usage description is present.
- Privacy manifest is present at `forzadvisor/PrivacyInfo.xcprivacy`.
- App Store metadata, release notes, privacy policy, support copy, screenshot specifications, and six accepted-size marketing screenshots are present.
- `ReleaseVerify.xctestplan` runs the complete supported unit and UI targets serially without skips or expected failures.
- Local ReleaseVerify evidence at commit `02e50b2519ea83d8f889a51d500efeb758f7bead`: 570 unit tests and 10 UI tests passed with zero failures or skips; dark mode, Accessibility XXXL, and Increase Contrast captures were inspected.

## Local Package Verification

- Run a clean `ReleaseVerify` simulator build with zero source warnings and zero errors.
- Run the complete `ReleaseVerify` unit and UI targets serially with zero failures, skips, or expected failures.
- Archive and export with App Store signing.
- Push the immutable release commit and require Xcode Cloud Verify to pass before distribution.
- Upload build 77 through the release workflow and wait for App Store Connect processing.

## Screenshots

- Six 1320x2868 marketing screenshots are stored in `AppStore/screenshots/`.
- They show photo, screenshot, manual-entry, discipline, result, and refinement workflows.
- They do not show the removed catalog or claim access to a bundled roster.

## Required App Store Connect Values

- Attach processed build 77 to App Store version 1.41.1.
- Replace the prior roster-oriented description, promotional text, What's New copy, and review notes with `AppStore/metadata.md`.
- Keep the six marketing screenshots in their existing order; they show photo, screenshot, and manual-entry workflows rather than the removed catalog.
- Verify the public privacy URL resolves: https://Sankofa06.github.io/ForzAdvisor/privacy/
- Verify the public support URL resolves: https://Sankofa06.github.io/ForzAdvisor/support/
- Complete App Privacy answers in App Store Connect.
- Review the Content Rights declaration for the remaining compatibility references and user-imported screenshots. Do not claim rights to the removed roster.
- Confirm age rating and export compliance answers.
- Submit for App Review only after explicit human approval.

## App Review Notes

- No login, test account, or API key is required.
- The binary contains no bundled car roster, reviewed stock catalog, official game logos, vehicle artwork, or copied game screenshots.
- Users supply car details manually or choose their own photo/screenshot for on-device OCR.
- Reviewers can test the complete FH6 flow with fictional manual-entry data.
- FH5 manual entry produces a local build plan without numeric tuning values.
- Optional API mode requires the user's own Anthropic API key; offline mode is the default.

## Release Safety

- Do not upload any build that still contains the deleted roster resources or obsolete catalog claims.
- Keep App Review submission as a separate explicit human action.
- Do not re-add roster resources, generators, or catalog claims without documented redistribution rights and a new legal review.
- Keep signing keys and App Store Connect credentials out of the repository.
- Leave the previously approved untracked `.agent/` and `docs/refs/` folders untouched.
