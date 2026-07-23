# ForzAdvisor Support

Public URL: https://Sankofa06.github.io/ForzAdvisor/support/

ForzAdvisor helps racing-game players generate, save, copy, and adjust tuning setups from confirmed car details.

## Common Questions

### Do I need an account?

No. ForzAdvisor does not require a ForzAdvisor account.

### Do I need an API key?

No. Offline formula tuning is the default. On-device model assistance is optional when available. Anthropic API mode is optional for users who want to use their own Anthropic API key.

### Are screenshots uploaded?

No. Camera photos and imported screenshots are processed on device for OCR in the current release. They are not uploaded by ForzAdvisor.

### How do I start a tune?

Tap New Tune, then choose Take Photo, Import Screenshot, or Enter Manually. Confirm the detected or entered car details, choose a discipline, and review the generated tune.

### How do I copy a tune?

Open a generated or saved tune and tap Copy full tune. Individual tune lines can also be copied from their section rows.

### How do I use Guided Refinement?

Open a saved tune and use Guided Refinement to request changes such as more rotation, more stability, softer, stiffer, more top speed, or more acceleration.

### What are Beta Validation Missions?

Open Beta Validation Missions from the garage to see the next local testing tasks supported by your saved FH5 and FH6 setups. An empty garage offers one starter mission for each game. Eligible saved setups can offer Research Lab, Tire Lab, Upgrade Lab, or Record Test Drive missions, and completed or stale tasks disappear when you reopen the board.

The mission board does not upload progress or create evidence by itself. Share Beta Progress opens the iOS system share sheet with aggregate counts only and excludes car names, tune values, notes, identifiers, screenshots, and analytics.

### What is FH6 Validation Review?

Open an eligible saved exact-build FH6 tune and choose Open Validation Review under Accuracy Evidence. Paste an exact ForzAdvisor Test Drive JSON export for that setup. The app validates the canonical bytes, current game build and ruleset, verified shop availability, car, discipline, and applied settings before it can be imported.

Import also requires you to confirm direct receipt from the driver and permission for deidentified structured reuse. UUIDs and hashes bind that local decision to the exact export but do not authenticate identity. Reviewed sessions stay in a separate local queue and show only Keep, Adjust, Reject, handling symptoms, course, surface, and input counts. They do not change the tune or promote the experimental FH6 ruleset.

### What is FH5 Research Lab?

Research Lab appears on an eligible saved FH5 build plan for an untouched stock car from the reviewed catalog. In Horizon Test Track, use English units and record every expected tuning control as Adjustable, Shown locked, or Not shown. For adjustable controls, enter the minimum, maximum, step, and restored original current value.

The observation is raw first-party evidence, not a tune, and does not contact a tuning provider or enable numeric FH5 settings. A complete Upgrade Lab observation locks Research Lab to the same exact game build. Observations are shown and shareable only while they match the current saved plan, catalog car, and catalog revision.

### Can I share an FH5 Research Lab observation?

Structured JSON reuse and sharing are off by default for each observation. If you explicitly enable them, the saved plan can open the iOS share sheet for a deidentified allow-listed JSON record. Deleting the local record cannot recall a copy already shared.

### What is FH5 Research Review?

Open an eligible saved FH5 catalog plan and choose Research Review to paste an exact ForzAdvisor Research Lab JSON export. The app validates the full canonical record, requires you to confirm direct receipt and reuse permission, and keeps the permission-bound copy locally with that plan. UUIDs and hashes protect the reviewed bytes but do not prove identity.

Review labels one record as a single raw observation, exact repeated records from distinct capture sessions as replicated raw observations, and any exact-value disagreement as conflicting raw observations. It never averages values, creates a tuning ruleset, or unlocks numeric FH5 tuning.

### What is FH5 Outcome Lab?

Outcome Lab appears only after a matching FH5 Research Lab record and complete Upgrade Lab observation exist. It guides a fixed A-B-B-A Horizon Test Track experiment: stock, one user-selected slider step, the same one-step variant again, then stock again. Route, conditions, assists, input, and every other setting must stay unchanged, and the tested slider must be restored to stock before saving.

The record remains local calibration evidence. It stores no lap times, telemetry, screenshots, location, or free-form notes; it does not register a ruleset or unlock numeric FH5 tuning. Optional deidentified calibration reuse is off by default.

### How do I delete a tune?

Open the garage, swipe left on a saved tune, and tap Delete.

### How do I remove my API key?

Open Settings, switch the provider to Anthropic API if needed, and tap Clear Key.

## Contact

Use the public support tracker at https://github.com/Sankofa06/ForzAdvisor/issues.

Do not include API keys, private screenshots, personal messages, private hostnames, private IP addresses, or other sensitive data in public support issues.

## Unofficial App Notice

ForzAdvisor is not affiliated with, endorsed by, or sponsored by Microsoft, Xbox, Turn 10 Studios, Playground Games, or the Forza franchise.
