# ForzAdvisor launch copy

Prepared 2026-10-14. Review drafts only: no posting, email delivery, submission, upload, or candidate release is represented here. Confirm the final candidate, verified screenshots, destination links, and release availability before use. No version or build is allocated by this package.

## Positioning

For iPhone racing-game players who want their car details and next setup in one place: ForzAdvisor turns a photo, screenshot, or manual entry into a reviewable setup workflow and a searchable local garage.

Headline: **Your car. Clear setup guidance.**

Short description: Start with your own car details, review the facts, and keep your next setup organized. FH5 creates local build plans; FH6 numeric output is experimental and evidence-gated.

Primary CTA: View ForzAdvisor on the App Store.

Link: https://apps.apple.com/us/app/forzadvisor/id6775224250

## Launch post — long

Your next setup starts with the car in front of you.

With ForzAdvisor for iPhone, take a performance-screen photo, import a screenshot, or enter your car details manually. Check the facts, choose your drive style, and save the result in your local garage. Search cars, styles, and notes, then sort your saved setups by car name or recent updates.

FH5 creates build plans without numeric tune values. FH6 guidance is experimental: numeric settings require the applicable evidence checks, and unsupported values stay withheld. Where verified settings permit refinement, preview changes before applying them.

Explore ForzAdvisor: https://apps.apple.com/us/app/forzadvisor/id6775224250

Unofficial companion; not affiliated with Microsoft, Xbox, Turn 10 Studios, Playground Games, or the Forza franchise.

## Social — short

Your car. Clear setup guidance. ForzAdvisor for iPhone starts with a photo, screenshot, or manual entry. Review your facts and organize your garage. FH5 is plan-only; FH6 numeric output is evidence-gated. https://apps.apple.com/us/app/forzadvisor/id6775224250

## Social — feature post

Find the setup you saved. Search ForzAdvisor’s Garage by car, style, or notes; filter by discipline; sort by car name or recent updates. FH5 stays plan-only, and FH6 numeric output depends on evidence checks.

https://apps.apple.com/us/app/forzadvisor/id6775224250

## Email draft

Subject: Your car. A clearer next setup.

Preview: Photo, screenshot, or manual entry—then review the facts.

Your car details deserve a useful home.

ForzAdvisor for iPhone helps you start a setup from your own performance-screen photo, screenshot, or manual entry. Review the values, choose your discipline, and save the result to your local garage. Search, filters, and sorting help you find it again.

FH5 creates local build plans with no numeric tune settings. FH6 numeric output is experimental and evidence-gated; unsupported values stay withheld. Eligible Guided Refinement changes can be previewed before applying them.

View ForzAdvisor on the App Store:
https://apps.apple.com/us/app/forzadvisor/id6775224250

ForzAdvisor is an unofficial companion and is not affiliated with the game’s creators or publishers.

## Screenshot captions — pending real capture review

1. Your next setup starts here — Photo, screenshot, or manual entry.
2. Check the facts first — Review your car details before generation.
3. Pick your drive style — Keep the discipline with your setup.
4. See what is supported — FH5 plans; evidence-gated FH6 values.
5. Keep your garage organized — Search, filter, and sort saved setups.
6. Review before you apply — Refinement only where verified settings permit it.

Use captions only on real candidate app captures showing the corresponding behavior. Existing mock-drawn assets are illustrative previews, not fresh captures. Seed names and player notes may demonstrate Garage behavior; seeded game observations, grants, verified status, or numeric settings must not suggest genuine validation. Omit the refinement shot unless genuine matching evidence makes the shown workflow eligible. An empty or withheld result is honest product behavior. Runtime/capture owners must confirm the final screens before these captions are paired with assets.

## Claim map

| Claim | Current source evidence | Boundary |
| --- | --- | --- |
| Photo, import, manual; review before generation | `forzadvisor/Views/NewTuneStartView.swift`, `forzadvisor/Views/OCRConfirmationView.swift`, `forzadvisor/Views/ManualEntryView.swift` | OCR accuracy is not promised. |
| On-device photo reading | `forzadvisor/Services/OCRService.swift`, `forzadvisor/Services/PhotoOCRImportController.swift` | Describes image reading, not optional API generation. |
| Four-step progress | `forzadvisor/ForzAdvisorWorkflowProgress.swift` and its screen call sites | Candidate source change; runtime validation pending. |
| Search cars/styles/notes, discipline filters, two sorts | `forzadvisor/Views/GarageHomeView.swift`, `forzadvisor/Views/GarageTuneSearch.swift` | Candidate source behavior; runtime validation pending. |
| FH5 local plan-only in every provider mode | `forzadvisor/Services/TuneProviderMode.swift`, `forzadvisor/Services/TuneOutputProjector.swift` | No numeric FH5 output is offered. |
| FH6 evidence gates and withheld values | `forzadvisor/Services/TuneOutputProjector.swift`, `forzadvisor/Services/TuneCapabilityResolver.swift` | No complete tune, performance, or validation promise. |
| Eligible refinement preview and reversible changes | `forzadvisor/Views/TuneRefinementSection.swift`, `forzadvisor/Services/TuneOutputProjector.swift` | Eligibility must pass; no universal availability claim. |
| Drive styles | `forzadvisor/Models/TuningDomain.swift` (`DrivingDiscipline`) | A choice does not establish validated numeric coverage. |
| Three input routes; no bundled roster in new-tune UI | `forzadvisor/Views/NewTuneStartView.swift` | No Choose a Car review route. |
| Offline default and optional provider modes | `forzadvisor/Services/TuneProviderMode.swift`, `forzadvisor/Views/ProviderPreflightView.swift` | No new pricing, privacy, or availability assertions. |

## Review and measurement

Before publication, confirm exact-candidate runtime verification and source revision, final real app screenshots, copy-to-screen agreement, and App Store availability. The package does not certify any of those gates. Metadata's existing version/build fields are informational and must be reconciled by the release owner against the selected candidate; this copy change does not allocate or verify them.

Use App Store Connect’s available aggregate product-page impressions, views, and downloads to evaluate the final listing. Compare equal date windows and record any simultaneous screenshot/copy change. No baseline, lift, attribution, or app analytics is claimed. Do not add tracking, send messages, or schedule posts as part of this draft package.
