# ForzAdvisor marketing screenshots

The canonical six screenshots in `AppStore/screenshots/` are real Debug simulator app captures with deterministic local demonstration data. The dark appearance is selected for the listing; original light and dark captures remain in the capture output with their manifests and provenance. Seed data is restricted to Debug simulator marketing capture and is not validation evidence. Production starts with user-owned data.

Run `scripts/capture_marketing_screenshots.sh --help` on a Mac with Xcode for future capture instructions. The pipeline runs only `MarketingScreenshotUITests`, validates all six screens in light and dark appearances at 1320 × 2868, and exports unmodified opaque PNG bytes into a new external artifact directory. It never overwrites `AppStore/screenshots/` or release configuration.

See [the screenshot specification](../screenshots-spec.md) for the canonical filename order, dependencies, provenance, visual review, and the verification-only GitHub Actions workflow. Preserve the saved-plan and Step Guide evidence and prerequisite messages. Captures do not establish a live model response, verified numeric tuning, candidate distribution, or release approval.
