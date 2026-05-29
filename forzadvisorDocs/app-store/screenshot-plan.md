# ForzAdvisor Screenshot Plan - Version 1.0

Last updated: 2026-05-29

## Requirements

The app target is iPhone-only for version 1.0. App Store Connect requires one to ten screenshots per supported localization. Use PNG or JPEG.

Preferred capture target:

- iPhone 6.9-inch display class, portrait
- Use the exact pixel size produced by the simulator/device and verify it is accepted by App Store Connect.

Apple's current screenshot reference lists accepted iPhone sizes and allows highest-resolution screenshots to scale down when the UI is the same across device sizes.

Source: https://developer.apple.com/help/app-store-connect/reference/screenshot-specifications

## Shot List

1. Garage home
   - Empty or seeded garage
   - Show the New Tune entry
   - Caption idea: "Start a setup in seconds"

2. Tune source
   - Show Take Photo, Import Screenshot, and Enter Manually
   - Caption idea: "Use a photo, screenshot, or manual entry"

3. Manual entry or OCR review
   - Show editable car stats
   - Caption idea: "Confirm every value before tuning"

4. Discipline picker
   - Show Road, Touge, Drift, Dirt, Cross-Country, Drag
   - Caption idea: "Pick the behavior you want"

5. Tune result
   - Show tune sections and Copy full tune
   - Caption idea: "Copy complete menu-order settings"

6. Saved tune adjustment
   - Save a tune, reopen it, and show feel adjustment controls
   - Caption idea: "Save setups and adjust after track time"

## Capture Notes

- Capture with real app UI, not mockups.
- Use seeded test data only if the saved garage state is hard to reach manually.
- Keep status bars clean and avoid showing real API keys.
- Do not show a Microsoft, Xbox, Turn 10, Playground Games, or Forza logo unless explicit legal approval exists.

## Captured Evidence

- `forzadvisorDocs/app-store/screenshots/20260528-205632-home-empty-garage.png` - iPhone 17, 1206 x 2622.
- `forzadvisorDocs/app-store/screenshots/20260528-205745-iphone-17-pro-max-home-empty-garage.png` - iPhone 17 Pro Max, 1320 x 2868.

The remaining shot-list screens still need capture after UI navigation is available through Xcode, XCUITest screenshot export, or manual Simulator capture.
