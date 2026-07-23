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

Open Beta Validation Missions from the garage to see exact local testing tasks supported by your saved FH5 and FH6 setups. An empty garage offers one starter mission for each game. Eligible saved setups can offer Research Lab, Tire Lab, Upgrade Lab, or Record Test Drive missions, and completed or stale tasks disappear when you reopen the board.

The board does not upload progress or create evidence by itself. Share Beta Progress opens the iOS system share sheet with aggregate counts only and excludes car names, tune values, notes, identifiers, screenshots, and analytics.

### What is FH6 Validation Review?

Open an eligible saved exact-build FH6 tune and choose Open Validation Review under Accuracy Evidence. Paste an exact ForzAdvisor Test Drive JSON export for that setup. The app validates the canonical bytes, current game build and ruleset, verified shop availability, car, discipline, and applied settings before import.

Import requires confirmation of direct receipt and permission for deidentified structured reuse. UUIDs and hashes bind that local decision to the exact export but do not authenticate identity. Reviewed sessions stay in a separate local queue and report only Keep, Adjust, Reject, handling symptoms, course, surface, and input counts. They cannot change the tune or promote the experimental FH6 ruleset.

### What is FH5 Research Lab?

Research Lab appears on an eligible saved FH5 build plan for an untouched stock car from the reviewed catalog. In Horizon Test Track, use English units and record every expected tuning control as Adjustable, Shown locked, or Not shown. Enter slider bounds, step, and restored current values only when the control is adjustable.

The observation is raw first-party evidence, not a tune, and it does not enable numeric FH5 settings or contact a tuning provider. Deidentified structured JSON reuse is off by default and must be enabled for that record before sharing.

A complete Upgrade Lab observation locks Research Lab to the same exact game build. Saved observations appear and can be shared only while they match the current saved plan, catalog car, and catalog revision.

### What is FH5 Research Review?

On a matching saved FH5 catalog plan, paste an exact Research Lab JSON export into Research Review. The app validates the canonical record, requires confirmation of direct receipt and reuse permission, and stores it locally. It can label exact distinct sessions as replicated raw observations or show exact-value conflicts, but it never averages values, creates a ruleset, or enables numeric FH5 tuning.

### What is FH5 Outcome Lab?

After a matching Research Lab record and complete Upgrade Lab observation exist, Outcome Lab guides a fixed A-B-B-A Horizon Test Track experiment. Compare stock with one user-selected slider step while keeping route, conditions, assists, input, and every other setting unchanged, then restore the stock value.

The result remains calibration evidence. It does not generate a tune, collect lap times or telemetry, register a ruleset, or unlock numeric FH5 settings. Deidentified calibration reuse is off by default. When enabled before saving, the latest eligible record can be shared as allow-listed JSON through the iOS system share sheet. The copy omits the local experiment ID, saved tune ID and plan fingerprint, Research Lab record ID and content fingerprint, generated tune values, provider and ruleset data, device identifiers, location, analytics, and public attribution; it retains a menu-measurement fingerprint to bind the observed controls. There is no background experiment uploader or importer, and deleting the local record cannot recall a copy already shared.

### How do I delete a tune?

Open the garage, swipe left on a saved tune, and tap Delete.

### How do I remove my API key?

Open Settings, switch the provider to Anthropic API if needed, and tap Clear Key.

## Contact

Use the public support tracker at https://github.com/Sankofa06/ForzAdvisor/issues.

Do not include API keys, private screenshots, personal messages, private hostnames, private IP addresses, or other sensitive data in public support issues.

## Unofficial App Notice

ForzAdvisor is not affiliated with, endorsed by, or sponsored by Microsoft, Xbox, Turn 10 Studios, Playground Games, or the Forza franchise.
