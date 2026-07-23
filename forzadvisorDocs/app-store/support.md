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

### What is FH5 Research Lab?

Research Lab appears on an eligible saved FH5 build plan for an untouched stock car from the reviewed catalog. In Horizon Test Track, use English units and record every expected tuning control as Adjustable, Shown locked, or Not shown. Enter slider bounds, step, and restored current values only when the control is adjustable.

The observation is raw first-party evidence, not a tune, and it does not enable numeric FH5 settings or contact a tuning provider. Deidentified structured JSON reuse is off by default and must be enabled for that record before sharing.

A complete Upgrade Lab observation locks Research Lab to the same exact game build. Saved observations appear and can be shared only while they match the current saved plan, catalog car, and catalog revision.

### What is FH5 Research Review?

On a matching saved FH5 catalog plan, paste an exact Research Lab JSON export into Research Review. The app validates the canonical record, requires confirmation of direct receipt and reuse permission, and stores it locally. It can label exact distinct sessions as replicated raw observations or show exact-value conflicts, but it never averages values, creates a ruleset, or enables numeric FH5 tuning.

### How do I delete a tune?

Open the garage, swipe left on a saved tune, and tap Delete.

### How do I remove my API key?

Open Settings, switch the provider to Anthropic API if needed, and tap Clear Key.

## Contact

Use the public support tracker at https://github.com/Sankofa06/ForzAdvisor/issues.

Do not include API keys, private screenshots, personal messages, private hostnames, private IP addresses, or other sensitive data in public support issues.

## Unofficial App Notice

ForzAdvisor is not affiliated with, endorsed by, or sponsored by Microsoft, Xbox, Turn 10 Studios, Playground Games, or the Forza franchise.
