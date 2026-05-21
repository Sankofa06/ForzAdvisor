# Forza Horizon 6 Tuning App — Product Requirements Document

**Owner:** Michael Williams
**Status:** Draft v1
**Target platform:** iOS (iPhone), Swift 6 / SwiftUI
**Target ship:** end of build week
**Architecture summary:** Native iOS shell + Vision (on-device OCR) + Anthropic API (reasoning layer that owns the tuning formulas) + Core Data / SwiftData (local garage). Clean Swift (VIP) architecture with easy to read folder structure and file names. No files should be more than 350 lines, as files approach 200 lines use +extensions to split out feature functionality. Comments at the top of each file should be well maintained and explain what the file does and what other files/functions it talks to and/or talks to it. Unit tests should be created and maintained alongside every function that gets created. As UI and UX elements get implemented or modified, UI tests should be maintained. XCode Tools ARE PREFERRED TO USE. XCODE TOOLS ARE AVAILABLE AND PREFERRED TO USE. things like running tests, building, getting errors and using the issue navigator to get warnings/issues is a requirement.

-----

## 1. Problem

Forza Horizon 6 (FH6) ships with a deep tuning menu — 30+ sliders across nine categories — and most players either run stock tunes or copy random forum setups that don’t fit their car’s actual weight, weight distribution, or build class. The existing community tools (ForzaTune Pro, forza.guide) are good but generic calculators: they don’t read screenshots, don’t save your garage, and don’t explain *why* the numbers are what they are. Players want a fast, opinionated, conversational tuning assistant that lives on their phone next to the console or PC.

## 2. Goal

Ship a one-screen-deep iOS app that:

1. Takes several photos of the FH6 in-game Performance / Upgrade panels.
1. Extracts the required inputs (weight, front weight %, PI / class, drivetrain and other metadata).
1. Creates a record of the cars stats to be the "base" model that can be mutated or returned to default to reapply new tunes
1. Asks the user which discipline (road / touge / drift / dirt / cross-country / drag).
1. Returns a set of complete, drive-ready tune in tune-menu order based on performance class.
1. Lets the user save it to a local garage and revisit / tweak later.

Reasoning is done server-side by the Anthropic or Codex API or Codex API. The Swift app is a thin client: OCR, image handling, garage persistence, UI, and prompt orchestration. **THE TUNING FORMULAS CAN BE USED AS AN ALTERNATE NATIVE CALCULATION USING ALL OF THE DETAILS FROM FORZA.GUIDE** 

## 3. Non-goals (v1)

- Android, iPad, macOS, watchOS. iPhone only.
- Multiplayer / cloud sync / accounts. Everything is local.
- Sharing tunes via a community feed.
- FH5, Motorsport, or any other Forza title. FH6-specific physics only.
- Tune validation against in-game telemetry (no controller / console integration).
- In-app purchases. v1 is either free or a flat paid app — not a freemium ladder.

## 4. Users & primary scenarios

**Primary user:** FH6 player, 16–40, plays on console or PC, has a phone in their hand or pocket while tuning. They’ve already upgraded the car and are sitting on the Tune screen.

**Scenario A — fresh tune from a photo (the hero flow):**
Player opens the app, taps “New Tune,” takes a photo of the Performance panel on their TV / monitor, confirms the four extracted values, picks “Touge,” gets the tune ~3 seconds later, types the numbers into FH6 as they appear on screen.

**Scenario B — manual entry:**
Same flow but the player taps “Enter manually” and types weight / front % / PI / drivetrain. Useful when they’re not near the screen or the photo’s bad.

**Scenario C — garage lookup:**
Player opens the app a week later, taps “Garage,” picks their `2019 Toyota Supra — Touge` tune, sees the numbers again, optionally requests a “more rotation” tweak.

**Scenario D — feel adjustment after track time:**
Player has driven the tune and the car pushes wide. They open the saved tune, tap “More rotation,” and get back amended ARB / spring / diff values without rebuilding from scratch.

## 5. Feature scope (v1)

### 5.1 Photo capture & OCR

- Use `AVFoundation` for camera, or `PHPicker` for library import.
- Run on-device OCR with `VNRecognizeTextRequest` (Apple Vision framework). Free, fast, no network.
- Extract candidate values for: weight (lb or kg), front weight %, PI number + class letter (C/B/A/S1/S2/X), drivetrain string (RWD/FWD/AWD), and optionally power (hp), torque (ft-lb), top speed.
- Present the extracted values in a confirmation screen with editable fields. **Never auto-submit OCR results** — the player edits and confirms.
- If a value can’t be confidently extracted, the field is empty and required.

**OCR confidence handling:** Vision returns confidence scores per recognized string. If confidence on any required field is below 0.6, highlight the field in yellow and ask the user to verify. Drivetrain (RWD/FWD/AWD) is a closed set — snap OCR output to nearest match.

### 5.2 Manual entry mode

Standard SwiftUI form: weight (numeric, lb/kg toggle), front % (0–100 slider + numeric), PI (numeric 100–999), class (segmented control), drivetrain (segmented control).

### 5.3 Discipline picker

Six options: Road, Touge, Drift, Dirt/Rally, Cross-Country, Drag. Big tap targets. Touge gets a subtle highlight (“FH6’s signature discipline”) since the player base skews that way.

### 5.4 Tune generation

- POST the structured inputs + discipline to the Anthropic API with the FH6 tuning system prompt (the existing SKILL.md + formulas.md, included as a bundled resource and inlined into the system prompt).
- Use `claude-sonnet-4-6` (or whatever’s current — make the model name a config constant).
- Expect structured output. Use the API’s JSON mode / tool-use to force a strict schema (see §6).
- Show a spinner with the player’s car name + discipline (“Tuning your 2019 Supra for Touge…”). Target round-trip under 4 seconds.

### 5.5 Tune display

The standard output format from the SKILL — tires, gearing, alignment, ARBs, springs, dampers, aero, brakes, differential, notes. Each section is a collapsible card. Big monospace numbers. One-tap to copy a value to clipboard (useful when typing into FH6 on PC).

### 5.6 Garage (local persistence)

- SwiftData (iOS 17+) or Core Data fallback.
- Each saved tune stores: car name (player-typed), year, make, model, the four inputs, discipline, full tune output JSON, created/updated timestamps, optional notes field, optional thumbnail of the original photo.
- List view sorted by most-recent. Search by car name. Filter by discipline.
- Delete with swipe. No undo in v1.

### 5.7 Feel adjustments

Three buttons on every saved tune: **More rotation / More stability**, **Softer / Stiffer**, **More top speed / More acceleration**. Each tap sends a follow-up API call with the previous tune + the requested adjustment, and the API returns only the changed lines (per the SKILL spec). Display as a diff against the previous tune.

### 5.8 Re-tune nudge

If the user edits a saved tune’s weight or front % by more than 2%, surface a banner: “Weight distribution shifted significantly — re-tune from scratch?” One tap to regenerate.

## 6. API contract

The Swift client sends a single message per tune request. The system prompt is the bundled SKILL + formulas reference. The user message is a structured JSON blob.

**Request payload (user message):**

```json
{
  "action": "generate_tune",
  "car": {
    "year": 2019,
    "make": "Toyota",
    "model": "Supra",
    "weight_lb": 3340,
    "front_weight_pct": 53,
    "pi": 750,
    "class": "S1",
    "drivetrain": "RWD",
    "peak_hp": 480,
    "peak_torque_ftlb": 410
  },
  "discipline": "touge",
  "notes": null
}
```

**Required response schema (enforce via tool-use or JSON mode):**

```json
{
  "tune": {
    "tires": { "front_psi": 29.0, "rear_psi": 28.5 },
    "gearing": { "final_drive": 4.05, "gears": null },
    "alignment": {
      "front_camber": -2.5, "rear_camber": -1.5,
      "front_toe": 0.0, "rear_toe": 0.0, "caster": 5.5
    },
    "arbs": { "front": 28.1, "rear": 19.2 },
    "springs": {
      "front_rate": 524, "rear_rate": 464,
      "front_ride_height": 4.5, "rear_ride_height": 4.7
    },
    "damping": {
      "front_rebound": 6.6, "rear_rebound": 6.2,
      "front_bump": 4.3, "rear_bump": 4.0
    },
    "aero": { "front_lb": 180, "rear_lb": 210 },
    "brakes": { "balance_pct": 50, "pressure_pct": 100 },
    "differential": {
      "accel_pct": 55, "decel_pct": 30,
      "front_accel_pct": null, "front_decel_pct": null,
      "rear_accel_pct": null, "rear_decel_pct": null,
      "center_balance_rear_pct": null
    }
  },
  "notes": {
    "bias": "neutral with light rotation",
    "if_pushes_wide": "Soften rear ARB by 2",
    "if_snaps_on_lift": "Stiffen rear spring by 30 lb/in",
    "retune_trigger": "Re-tune if weight distribution shifts more than 2%"
  }
}
```

Fields irrelevant to the drivetrain (e.g. center_balance on a RWD car) are `null`. The Swift renderer skips null sections.

**Adjustment request (follow-up):**

```json
{
  "action": "adjust_tune",
  "previous_tune": { ... full prior response ... },
  "adjustment": "more_rotation"  // or more_stability / softer / stiffer / more_top_speed / more_acceleration
}
```

Response is the same schema, with only the changed numeric fields populated and everything else null. The Swift layer merges.

## 7. Architecture

```
┌─────────────────────────────────────────────────┐
│  SwiftUI views (Camera, Confirm, Discipline,    │
│                Tune, Garage, Adjust)            │
└──────────────┬──────────────────────────────────┘
               │
       ┌───────▼────────┐    ┌─────────────────┐
       │  ViewModels    │◄──►│  SwiftData store │
       │  (@Observable) │    │  (Garage)        │
       └───────┬────────┘    └─────────────────┘
               │
   ┌───────────┼────────────┐
   ▼           ▼            ▼
 OCRService  TuneAPIClient  KeychainStore
 (Vision)    (URLSession)   (API key)
```

**Modules:**

- `OCRService`: wraps Vision, returns `OCRResult` with confidences.
- `TuneAPIClient`: `async` methods `generateTune(input:)` and `adjustTune(previous:adjustment:)`. Owns the Anthropic API endpoint, bundled system prompt, retry logic, timeout (10s).
- `GarageStore`: SwiftData container, CRUD on `SavedTune` model.
- `KeychainStore`: stores the API key — see §8.

## 8. API key handling

**This is the one thing most likely to bite you.** Options:

1. **User brings their own key.** Settings screen → paste Anthropic key → stored in iOS Keychain. Zero backend, zero cost to you, but most users won’t know what an API key is. Suitable if the audience is tech-leaning Forza players.
1. **Your key, proxied through your backend.** You run a tiny proxy (Cloudflare Worker, Vercel function) that adds the key server-side. Protects your key from extraction. You pay for usage. Suitable if you want a polished consumer app.
1. **Your key bundled in the app.** Don’t. It will be extracted from the IPA within hours of release.

**Recommendation for v1:** option 1 (BYO key) if you’re shipping fast this week. Add a clear onboarding screen with a link to console.anthropic.com. Migrate to option 2 if the app gets traction.

## 9. UX flow

```
Launch
  └── if garage empty → onboarding (3 cards: photo, discipline, garage)
        else → Home (garage list + big "New Tune" FAB)
              │
              └── New Tune
                    ├── Photo  ─→ Vision OCR ─→ Confirm Inputs ─┐
                    └── Manual ──────────────→ Enter Inputs ────┤
                                                                │
                                                                ▼
                                                          Pick Discipline
                                                                │
                                                                ▼
                                                          API call (spinner)
                                                                │
                                                                ▼
                                                          Tune Display
                                                          ├── Save to Garage
                                                          ├── Adjust (Balance/Stiffness/Speed)
                                                          └── Copy values
```

Five screens total: Home, Capture, Confirm, Discipline, Tune. Garage detail reuses the Tune screen.

## 10. Why the formulas live in the API prompt, and in Swift

Three reasons:

1. **The formulas will change.** FH6 patches, community knowledge evolves, you’ll want to update touge multipliers next month. Updating a server-hosted prompt is instant; updating native Swift logic requires App Store review.
1. **The SKILL is already written and tested.** It encodes nuance (FH6 quirks, brake bias direction, AWD understeer compensation) that’s tedious to translate to Swift and easy to get subtly wrong.
1. **The LLM handles the long tail.** Weird input combinations (RWD at C-class, ultra-low weight builds) get sensible answers because the model can reason; a pure formula engine in Swift would clamp them awkwardly.

The trade-off is latency (3–4s per tune vs instant) and cost (~$0.01–0.03 per tune at current Sonnet pricing). Both acceptable. Native forza.guide available as a viable option. Not just a fallback.

## 11. Risks & mitigations

|Risk                                 |Likelihood         |Impact                   |Mitigation                                                         |
|-------------------------------------|-------------------|-------------------------|-------------------------------------------------------------------|
|OCR misreads PI or weight by a digit |High               |Tune is wrong            |Mandatory confirm screen; never skip                               |
|API outage / timeout                 |Medium             |App is dead in the water |Show clear error, offer retry, cache last tune locally             |
|User pastes wrong API key            |Medium             |Confusing failure        |Validate key on save with a 1-token ping                           |
|Anthropic deprecates the model string|Medium             |Future breakage          |Model name is a remote config value (or shipped via app update)    |
|LLM returns malformed JSON           |Low (with tool-use)|Crash or empty tune      |Strict JSON schema validation; show “couldn’t generate, retry”     |
|User’s screenshot is dark / blurry   |High               |OCR fails                |Fall back to manual entry with one tap                             |
|FH6 UI changes in a future patch     |Medium             |OCR field positions shift|OCR is field-agnostic (regex over recognized strings), so resilient|


## 14. Open questions and answers

- Lb vs kg display preference — auto-detect by locale, or explicit setting? Lb is fine for now
- Should the tune display screen show all sections at once (long scroll) or only the active one (tabs)? Long scroll wins for v1 — players need to type values sequentially anyway. long scroll is fine for each car. 
- Do you want a “share as image” export? Easy to add (SwiftUI `ImageRenderer`), but not strictly required. No
- Token budget per request — set a hard cap (e.g. 2000 output tokens) to keep latency and cost predictable? Yes, model shouldnt have to think to hard. Could add an option to cross compare with forza.guide and get the ULTIMATE ANSWER. 
- Codex vs Anthropic: If you wire the client behind a `TuneProvider` protocol, swapping is a config change. Worth doing on day 1.

-----

**End of PRD.**
