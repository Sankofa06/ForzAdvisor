# ForzAdvisor screenshot specification

Canonical assets: six real Debug simulator app captures with deterministic local demonstration data, using the dark appearance. Original light and dark captures remain available in the capture output alongside their provenance. These images show the app; seeded content does not establish tuning validation or distribution of a release candidate.

Capture the actual Debug simulator app with its deterministic, local marketing seed. Both light and dark appearances must pass `MarketingScreenshotUITests`; each produces six `app.screenshot()` attachments. No remote generation, credentials, official game imagery, or personal data is needed.

```sh
python3 -m venv /tmp/forzadvisor-marketing-python
/tmp/forzadvisor-marketing-python/bin/python -m pip install Pillow==11.3.0
PATH="/tmp/forzadvisor-marketing-python/bin:$PATH" \
  python3 "$HOME/.codex/scripts/simulator-pool.py" run \
  --role phone-large --repo "$PWD" --task "${CODEX_THREAD_ID:-manual}" --boot -- \
  bash scripts/capture_marketing_screenshots.sh /tmp/forzadvisor-marketing-capture
```

Capture requires a live shared-pool lease. The helper supplies and validates the simulator role, UDID, and exact Xcode destination; the script does not discover, boot, or shut down simulators. It derives the checkout from its own location, requires a new output directory outside the checkout, and fails before Xcode runs if the lease or required tools are unavailable.

The six dark captures are selected in `AppStore/screenshots/` and `release-config.json`, in this order. Original captures appear under `screenshots/raw/light/` and `screenshots/raw/dark/` in the capture output:

1. `01-your-local-garage.png`
2. `02-choose-your-input.png`
3. `03-confirm-your-car.png`
4. `04-choose-your-discipline.png`
5. `05-your-saved-plan.png`
6. `06-guidance-for-next-step.png`

Every file must be an opaque, portrait 1320 × 2868 PNG. The exporter copies the original XCTest PNG bytes without resizing, drawing, compositing, or other editing. It rejects missing or duplicate captures, invalid dimensions, transparency, unsafe paths, and incomplete or unsuccessful test summaries. Pillow 11.3.0 validates image decoding; it does not write the screenshots.

`provenance.json` records source revision and tree, working-tree status and input hashes, Xcode version, the leased simulator role/UDID/exact destination, test summary, original attachment names, and SHA-256 hashes. Preserve the result bundle, export manifest, logs, and provenance with the screenshots. A dirty local tree is explicitly identified; release acceptance requires evidence for the intended immutable revision.

Review both appearances for readable labels, clipping, keyboards, unintended dialogs, and truthful content. The saved plan is a representative local seed, not proof of a live AI response. The plan and guidance screens must preserve the app's evidence and prerequisite messaging; do not imply verified numeric settings when evidence is absent. Capture tests and image checks do not replace visual review.

The verification-only `Marketing screenshot tooling` workflow runs on pull requests and manual dispatch. Its hosted job tests the exporter and the capture lease contract; it does not launch a simulator or produce screenshot artifacts because real capture requires the host's shared simulator pool. A separate job performs a clean Release simulator build and the complete Debug `ReleaseVerify` plan, retaining small `app-verification-<sha>-attempt-<n>` diagnostics and a separate `app-verification-xcresult-<sha>-attempt-<n>` bundle. This PR evidence does not replace the immutable-tag release gate. The workflow does not archive, sign, upload to App Store Connect, or change canonical assets. For future refreshes, require successful host-pool capture and visual acceptance before replacing the selected dark canonical screenshots. Final candidate acceptance remains separate from screenshot capture.

Apple screenshot size reference: https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications/
