# ForzAdvisor Release Checklist

Last updated: 2026-08-22

Highest state: **App Store candidate — READY_FOR_REVIEW, not submitted**

Canonical release configuration: `AppStore/release-config.json`

Automation guide: `AppStore/release-automation.md`

Privacy attestation: `AppStore/privacy-label.md`
Current evidence: `AppStore/releases/1.41.1.md`

## 1. Release definition

- [x] Marketing version is `1.41.1`.
- [x] Source build setting is `77`.
- [x] App Store Connect processed build is `5`; it is intentionally tracked separately from source build 77.
- [x] Bundle ID is `com.michaelwilliams.forzadvisor` and team is `5RGU344VJR`.
- [x] GitHub `origin` is the authoritative source for GitHub Actions and release tags.
- [x] Price is **Free**.
- [x] Release policy is **manual submission, automatic release after Apple approval**.
- [x] Content rights declares use of third-party content/references.
- [x] App Privacy answers were published and recorded in `AppStore/privacy-label.md`.
- [x] Age rating, export compliance, and review contact are complete in App Store Connect.
- [x] Submission remains a separate explicit human action.

## 2. Local package gate

- [x] Run `scripts/release preflight` from the canonical checkout after the release revision is committed and pushed.
- [x] Run focused tests for every release-automation or app change.
- [x] Run a clean Release build with zero source warnings and errors.
- [ ] Run `ReleaseVerify.xctestplan` with zero failures, skips, or expected failures.
- [x] Inspect the intended diff and run `git diff --check` plus a credential/secret scan.
- [x] Commit the viable state and push an immutable release commit or annotated tag.

## 3. GitHub Actions and local candidate gate

- [x] Dispatch `.github/workflows/release-verify.yml` for immutable tag `release-1.41.1-github-verify-4`; run `32553715007` passed the build and complete test plan.
- [x] Confirm GitHub Actions reports tagged source commit `798a5736a122cf52e494e46b09dd8316943b61a8`.
- [ ] Only after Verify succeeds, archive and upload that exact revision locally through Xcode.
- [ ] Require archive and upload to succeed.
- [ ] Wait for App Store Connect processing state `VALID` and App Store eligibility.
- [x] Record the GitHub run ID, source tag, source commit, and source build in the release record.
- [ ] Record the resulting App Store Connect build after local upload and processing.

## 4. Candidate gate

- [x] Six 1320x2868 screenshots exist in `AppStore/screenshots/`, have no alpha, and remain in the approved order.
- [x] Marketing, privacy, and support URLs are public.
- [x] Metadata and review notes reflect photo, screenshot, and manual entry rather than a bundled roster.
- [x] No login or test account is required.
- [x] The privacy manifest exists at `forzadvisor/PrivacyInfo.xcprivacy`.
- [x] `ITSAppUsesNonExemptEncryption` is `NO` for the app target.
- [x] Build 5 is attached to App Store version 1.41.1.
- [x] Review submission draft and item are `READY_FOR_REVIEW`.

Run the online App Store candidate preflight immediately before submission. It must verify the exact selected build, metadata, price schedule, public URLs, privacy attestation, content rights, age rating, review contact, export compliance, and release policy.

## 5. Explicit submission gate

- [ ] Report the exact App Store build and candidate state to the user.
- [ ] Obtain explicit approval to submit this build to App Review.
- [ ] Invoke the guarded submission command only with both submission flags documented in `AppStore/release-automation.md`.
- [ ] Confirm App Store Connect transitions to `WAITING_FOR_REVIEW` or report the exact returned state.
- [ ] Update `AppStore/releases/1.41.1.md`, commit the final evidence, and remove temporary state that is no longer needed.

## Safety invariants

- Never store credentials, JWTs, private keys, provisioning profiles, or secret values in the repository or release state.
- Never start Release Candidate before Verify succeeds for the same immutable revision.
- Never infer App Review approval from requests to build, test, upload, stage, or prepare.
- Never hardcode the uploaded App Store build from `CURRENT_PROJECT_VERSION`; observe and record it after processing.
- Never re-add roster resources, generators, or catalog claims without documented redistribution rights and a new legal review.
