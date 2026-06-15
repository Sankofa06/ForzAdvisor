# ForzAdvisor Screenshot Specification

Last updated: 2026-06-15

## Required App Store Set

ForzAdvisor is currently prepared as an iPhone app. App Store Connect accepts one to ten screenshots per localization in PNG, JPEG, or JPG format. Apple's current screenshot reference lists `1320 x 2868` portrait as an accepted 6.9-inch iPhone screenshot size, matching the generated upload set.

Source: https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications/

## Suggested Upload Order

Use the six generated marketing screenshots in `AppStore/screenshots/`:

1. `01-build-a-tune-fast.png` - Start Tunes Faster
2. `02-photo-screenshot-or-manual.png` - Scan, Import, or Type
3. `03-confirm-every-stat.png` - Confirm Every Stat
4. `04-tune-for-road-drift-drag.png` - Pick the Drive Style
5. `05-copy-complete-settings.png` - Copy Menu-Order Settings
6. `06-refine-after-every-run.png` - Refine After Every Run

Each image is `1320 x 2868` pixels, portrait, PNG, and designed for the iPhone 6.9-inch screenshot slot.

## Production Notes

Regenerate the screenshot set with:

```sh
swift scripts/generate_marketing_screenshots.swift
```

The generator writes App Store upload images to `AppStore/screenshots/` and supporting marketing notes to `AppStore/marketing/`.

## Creative Direction

- Lead with the actual app workflow rather than a generic racing graphic.
- Use short, high-contrast headlines that fit comfortably on iPhone App Store previews.
- Keep the device mockup large enough to inspect the relevant UI state.
- Use a restrained racing utility palette with teal, orange, gold, green, blue, and graphite accents.
- Keep the copy focused on outcomes: start faster, confirm values, choose discipline, copy settings, refine after testing.

## Visual QA

- Confirm every generated image is `1320 x 2868`.
- Confirm the headline, phone mockup, row text, and footer do not overlap.
- Confirm text is readable at App Store thumbnail scale.
- Confirm the screenshot set tells a sequential story from starting a tune through refining a saved tune.
- Confirm the final upload folder contains only the six intended PNG files.

## Safe Sample Data

No secrets, API keys, private hostnames, private IP addresses, personal messages, unreleased customer data, or private support conversations may appear in screenshots.

Use representative car and tune details only. Do not show Microsoft, Xbox, Turn 10, Playground Games, Forza logos, or official game UI. Keep the unofficial companion app disclosure in metadata, public pages, and Settings.

## What Not To Show

- Real API keys or placeholder strings that resemble keys.
- Real user notes, personal names, or private messages.
- Official game logos, storefront badges, or platform marks.
- Apple device chrome beyond the generated neutral phone mockup.
- Claims that depend on App Review approval or unverified remote service behavior.
