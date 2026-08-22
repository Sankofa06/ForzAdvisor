# ForzAdvisor Release Automation

`scripts/release` is the repository-owned release coordinator. It turns the release declarations in
`AppStore/release-config.json` into deterministic checks without storing signing
keys, API keys, JWTs, or personal review-contact details in the repository.

Distribution remains owned by the two locked Xcode Cloud workflows. App Review
submission remains a separate human-approved, double-acknowledged action.

## Source of Truth

`AppStore/release-config.json` contains non-secret release facts:

- App Store Connect app, bundle, and team identifiers
- canonical GitHub checkout, remote, and release ref
- marketing version `1.41.1`
- source project build `77`
- currently staged App Store Connect build `5` (a new Release Candidate records
  its observed build number; it is not required to remain `5`)
- Free pricing, explicit-human-approval submission policy, and App Store
  `AFTER_APPROVAL` release timing
- the published privacy-label declaration and human attestation date
- content-rights, age-rating, and review-contact completion attestations
- public marketing, privacy, and support URLs
- Xcode project, schemes, test plan, and privacy manifest
- Verify and Release Candidate workflow identifiers
- exact App Store version, review-draft, and review-item identifiers
- metadata limits and the exact screenshot order

The two build numbers intentionally describe different systems. `77` is
`CURRENT_PROJECT_VERSION` in the source project. Xcode Cloud assigned build `5`
to the processed App Store Connect binary. Do not replace one with the other in
release evidence.

`current_app_store_build_number` is a read-only baseline for standalone status
and preflight. Release Candidate monitoring selects exactly one build produced by
that exact cloud run for this app, iOS marketing version, and App Store audience,
then records whatever build number Apple assigned (for example, `6`). Pre-stage
validation checks that candidate directly even if the version still selects the
older build; post-stage validation requires the relationship to select the new
candidate.

Review-contact values remain only in App Store Connect; the repository records
that the required contact is complete. App Store Connect credentials remain in
environment variables or `~/.codex/secrets/app-store-connect.env`:

```text
ASC_KEY_ID
ASC_ISSUER_ID
ASC_KEY_PATH
```

Override the credential-file location with
`FORZADVISOR_ASC_SECRETS_FILE`. Never put the credential file or private key in
the repository.

## Preflight

From the canonical checkout, run:

```sh
scripts/release preflight
```

The command fails unless all of these gates pass:

1. The checkout is `~/Agents/ForzAdvisor`, `origin` is the configured GitHub
   repository, the working tree is clean, and `HEAD` is the pushed configured
   branch or tag.
2. Marketing version, source build, team, bundle identifier, automatic signing,
   and `ITSAppUsesNonExemptEncryption=NO` match the release declaration.
3. Both shared schemes and `ReleaseVerify.xctestplan` exist; the local scheme
   uses that plan, both unit and UI targets are present, and neither scheme nor
   the plan skips tests.
4. Required metadata sections exist; App Name, Subtitle, Promotional Text,
   Description, and Keywords fit App Store limits; public URLs match the config.
5. The screenshot set exactly matches the declared order, every image is
   1320x2868, uses RGB or RGBA PNG encoding, and every pixel is opaque. An alpha
   channel containing only opaque pixels is accepted; grayscale is rejected.
6. The privacy manifest exists, records collected-data and tracking keys, and
   disables tracking. The published App Privacy answers and dated human
   attestation must also be recorded.
7. Free price, explicit submission approval, `AFTER_APPROVAL` release timing,
   content rights, age rating, review contact, and
   distinct source/App Store build numbers are recorded.
8. The deployed marketing, privacy, and support URLs return a successful HTTPS
   response.

For an immutable pushed tag at `HEAD`:

```sh
scripts/release preflight --ref release-1.41.1
```

The preflight has no dirty-tree bypass. Commit or preserve unrelated work before
using a checkout as a release source.

### Deterministic URL checks

Tests and disconnected validation can inject observed URL results rather than
silently skipping the URL gate:

```sh
scripts/release preflight --url-fixture /absolute/path/url-results.json
```

The fixture is a JSON object whose keys are the configured URLs and whose values
are HTTP status codes. Every configured URL must be present and successful:

```json
{
  "https://Sankofa06.github.io/ForzAdvisor/": 200,
  "https://Sankofa06.github.io/ForzAdvisor/privacy/": 200,
  "https://Sankofa06.github.io/ForzAdvisor/support/": 200
}
```

This is an injectable test mechanism, not proof that a deployment is currently
healthy. Use the default live checks for a real release.

## Local and Cloud Gates

Passing `scripts/release preflight` does not run or replace app tests. The release
sequence is:

1. Run the complete local `ReleaseVerify` test plan through the repository's
   supported Xcode verification tooling.
2. Commit and push the exact release state, create and push an immutable release
   tag at `HEAD`, then rerun `scripts/release preflight --ref TAG`.
3. Start the configured Xcode Cloud Verify workflow for that exact ref.
4. Confirm Verify reports the expected commit and succeeds.
5. Start Release Candidate for the same immutable ref.
6. Wait for tests, archive, upload, processing, and a `VALID` App Store build.
7. Confirm the Apple state with `scripts/release asc-preflight --json`.
8. Attach and stage the build only after that read-only Apple preflight passes.
9. Report the exact App Store build and ask for explicit approval.
10. Submit only after that approval, confirm `WAITING_FOR_REVIEW`, and write the
    permanent release record.

The durable cloud and staging commands are:

```sh
scripts/release cloud-start --ref release-1.41.1
scripts/release cloud-status
scripts/release cloud-resume
scripts/release stage
```

State is written outside the repository at
`~/.codex/state/forzadvisor-release/active.json` with owner-only permissions.
Starting a different tag while a nonterminal release is active fails closed.
When the prior release is terminal, its state is first preserved under the
owner-only `history/` directory before a new start intent is written.
`cloud-resume` will not start Release Candidate until Verify succeeds and reports
the recorded peeled tag commit. It re-resolves the pushed tag immediately before
both cloud starts. Branches—including `main`—are accepted only for local
preflight, never cloud delivery. Repeated staging queries and reuses the
TestFlight relationship, selected build, review draft, and review item. Every
external mutation has an owner-only intent/observation checkpoint.

Cloud start intent is persisted before the POST. After an interrupted start, the
coordinator adopts a run only when Apple exposes one unambiguous manual run with
the exact commit, the tag-reference identity persisted with the original start
request, and `clean=true`; a newly resolved reference cannot replace that
historical identity during recovery. If those observable
fields are unavailable it fails closed instead of creating or adopting a
possibly unrelated run.

Staging requires the configured iOS draft to contain exactly the configured
review item and the version/draft to remain `READY_FOR_REVIEW`; mixed drafts and
post-submission versions fail closed. Before any mutation, the selected build
must be absent, the exact cloud candidate, or the configured baseline build;
an unrelated selected build stops staging. Establish new non-secret version/draft/item
identities in App Store Connect and update the config before staging a later
release.

Xcode Cloud workflow starts and App Store staging are intentionally not hidden
inside local preflight. Their external effects should remain visible and tied to
the operator-approved immutable ref.

## Read-only Apple Status

With credentials available:

```sh
scripts/release asc-status
scripts/release asc-status --json
scripts/release asc-preflight --json
```

The command validates app name and bundle identity, then reports the configured
App Store version, expected build processing state, and review-submission states.
`asc-preflight` verifies app/build ownership, build validity and App Store
eligibility, selected build, exact repository name/subtitle/version metadata,
review notes and screenshot selection, and an effective manual price whose API
relationship points to the configured USA zero-price point (with the included
price point independently reporting a zero customer price),
content rights, age rating, review contact, export compliance, release timing,
privacy attestation, and review-draft consistency. It sends GET requests only,
persists typed evidence when release state exists, and is rerun immediately
before `stage`.

## Submission Safety

Submission remains separate and fails closed unless both acknowledgements are present:

```sh
scripts/release submit --submit --acknowledge-irreversible-app-review-submission
```

Never run it without explicit approval. Preflight, status, cloud, and `stage`
commands never submit App Review.

## Tests

Run the dependency-light Ruby test suite with:

```sh
ruby scripts/tests/forzadvisor_release_test.rb
```

The tests use only the Ruby standard library. Network results, Git commands, and
App Store responses are injected. They do not use credentials, call Apple, start
Xcode Cloud, modify App Store Connect, or submit the app.
