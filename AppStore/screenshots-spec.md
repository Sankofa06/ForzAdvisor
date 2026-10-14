# ForzAdvisor screenshot specification

Canonical assets: six real Debug simulator app captures with deterministic local demonstration data, using the dark appearance. Original light and dark captures remain available in the capture output alongside their provenance. These images show the app; seeded content does not establish tuning validation or distribution of a release candidate.

Capture the actual Debug simulator app with its deterministic, local marketing seed. Both light and dark appearances must pass `MarketingScreenshotUITests`; each produces six `app.screenshot()` attachments. No remote generation, credentials, official game imagery, or personal data is needed.

```sh
python3 -m venv /tmp/forzadvisor-marketing-python
/tmp/forzadvisor-marketing-python/bin/python -m pip install Pillow==11.3.0
PATH="/tmp/forzadvisor-marketing-python/bin:$PATH" \
  scripts/capture_marketing_screenshots.sh /tmp/forzadvisor-marketing-capture [SIMULATOR_UDID]
```

Omit the optional `[SIMULATOR_UDID]` token to select an available iPhone 17 Pro Max or iPhone 16 Pro Max automatically. A supplied UDID must identify one of those devices. The script derives the checkout from its own location, requires a new output directory outside the checkout, and fails if Xcode or a qualifying simulator is unavailable.

The six dark captures are selected in `AppStore/screenshots/` and `release-config.json`, in this order. Original captures appear under `screenshots/raw/light/` and `screenshots/raw/dark/` in the capture output:

1. `01-your-local-garage.png`
2. `02-choose-your-input.png`
3. `03-confirm-your-car.png`
4. `04-choose-your-discipline.png`
5. `05-your-saved-plan.png`
6. `06-guidance-for-next-step.png`

Every file must be an opaque, portrait 1320 × 2868 PNG. The exporter copies the original XCTest PNG bytes without resizing, drawing, compositing, or other editing. It rejects missing or duplicate captures, invalid dimensions, transparency, unsafe paths, and incomplete or unsuccessful test summaries. Pillow 11.3.0 validates image decoding; it does not write the screenshots.

`provenance.json` records source revision, working-tree status and input hashes, Xcode version, simulator/runtime, test summary, original attachment names, and SHA-256 hashes. Preserve the result bundle, export manifest, logs, and provenance with the screenshots. A dirty local tree is explicitly identified; release acceptance requires evidence for the intended immutable revision.

Review both appearances for readable labels, clipping, keyboards, unintended dialogs, and truthful content. The saved plan is a representative local seed, not proof of a live AI response. The plan and guidance screens must preserve the app's evidence and prerequisite messaging; do not imply verified numeric settings when evidence is absent. Capture tests and image checks do not replace visual review.

The verification-only `Real marketing screenshots` workflow runs on pull requests and manual dispatch with Xcode 26.6. `marketing-screenshots-<sha>-attempt-<n>` contains PNGs, the attachment manifest, provenance when successful, and small diagnostics; `marketing-xcresult-<sha>-attempt-<n>` retains the full result bundle. Partial attachments from a failed run are diagnostic evidence only, never accepted marketing assets. A separate job performs a clean Release simulator build and the complete Debug `ReleaseVerify` plan, retaining small `app-verification-<sha>-attempt-<n>` diagnostics and a separate `app-verification-xcresult-<sha>-attempt-<n>` bundle. This PR evidence does not replace the immutable-tag release gate. The workflow does not archive, sign, upload to App Store Connect, or change canonical assets. For future refreshes, require successful capture and visual acceptance before replacing the selected dark canonical screenshots. Final candidate acceptance remains separate from screenshot capture.

Apple screenshot size reference: https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications/
