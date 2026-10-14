# ForzAdvisor marketing screenshots

Status: **capture needed**. Use real app screenshots only. The former Swift mockup generator is retired and exits with an error; existing canonical PNGs are historical mockups awaiting replacement after review.

Run `scripts/capture_marketing_screenshots.sh --help` on a Mac with Xcode for capture instructions. The pipeline runs only `MarketingScreenshotUITests` with deterministic local seed data, validates all six screens in light and dark appearances at 1320 × 2868, and exports unmodified opaque PNG bytes into a new external artifact directory. It never overwrites `AppStore/screenshots/` or release configuration.

See [the screenshot specification](../screenshots-spec.md) for filenames, dependencies, provenance, visual acceptance, and the verification-only GitHub Actions workflow. No successful simulator capture is claimed by these instructions. Review seeded saved-plan and guidance screens against their evidence and prerequisite messaging before approving marketing use.
