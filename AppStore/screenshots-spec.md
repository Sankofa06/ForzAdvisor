# ForzAdvisor Screenshot Specification - Version 1.0

Last updated: 2026-05-31

## Requirements

ForzAdvisor 1.0 is iPhone-only. App Store Connect accepts one to ten screenshots per localization in PNG, JPEG, or JPG format. Use the highest-resolution iPhone portrait screenshots available for the App Store upload set.

Apple's current screenshot reference includes these accepted 6.9-inch portrait sizes:

- `1260 x 2736`
- `1290 x 2796`
- `1320 x 2868`

Source: https://developer.apple.com/help/app-store-connect/reference/screenshot-specifications

## Upload Set

Use the six generated marketing screenshots in `AppStore/screenshots/`:

1. `01-build-a-tune-fast.png`
2. `02-photo-screenshot-or-manual.png`
3. `03-confirm-every-stat.png`
4. `04-tune-for-road-drift-drag.png`
5. `05-copy-complete-settings.png`
6. `06-refine-after-every-run.png`

Each image is `1320 x 2868` pixels, portrait, PNG, and designed for App Store Connect's iPhone 6.9-inch screenshot slot.

## Creative Direction

- Dark, high-contrast racing utility presentation.
- Large uppercase headline at top.
- Centered iPhone mockup with app UI content.
- Teal and warm orange accent geometry.
- No App Store frames, Apple UI chrome, or official game branding.

## Safe Sample Data Rules

- Do not include API keys, private hostnames, private IPs, personal messages, or unreleased customer data.
- Do not include Microsoft, Xbox, Turn 10, Playground Games, or Forza logos.
- Use representative car/tune details only.
- Keep the unofficial companion app disclosure in metadata and public pages.

## Regeneration

Run:

```sh
swift scripts/generate_marketing_screenshots.swift
```

The generator writes App Store-ready PNGs to `AppStore/screenshots/` and supporting preview artwork to `AppStore/marketing/`.
