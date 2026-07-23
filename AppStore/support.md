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

### What is FH5 Research Lab?

Research Lab appears on an eligible saved FH5 build plan for an untouched stock car from the reviewed catalog. In Horizon Test Track, use English units and record every expected tuning control as Adjustable, Shown locked, or Not shown. For adjustable controls, enter the minimum, maximum, step, and restored original current value.

The observation is raw first-party evidence, not a tune, and does not contact a tuning provider or enable numeric FH5 settings. A complete Upgrade Lab observation locks Research Lab to the same exact game build. Observations are shown and shareable only while they match the current saved plan, catalog car, and catalog revision.

### Can I share an FH5 Research Lab observation?

Structured JSON reuse and sharing are off by default for each observation. If you explicitly enable them, the saved plan can open the iOS share sheet for a deidentified allow-listed JSON record. Deleting the local record cannot recall a copy already shared.

### What is FH5 Research Review?

Open an eligible saved FH5 catalog plan and choose Research Review to paste an exact ForzAdvisor Research Lab JSON export. The app validates the full canonical record, requires you to confirm direct receipt and reuse permission, and keeps the permission-bound copy locally with that plan. UUIDs and hashes protect the reviewed bytes but do not prove identity.

Review labels one record as a single raw observation, exact repeated records from distinct capture sessions as replicated raw observations, and any exact-value disagreement as conflicting raw observations. It never averages values, creates a tuning ruleset, or unlocks numeric FH5 tuning.

### How do I delete a tune?

Open the garage, swipe left on a saved tune, and tap Delete.

### How do I remove my API key?

Open Settings, switch the provider to Anthropic API if needed, and tap Clear Key.

## Contact

Use the public support tracker at https://github.com/Sankofa06/ForzAdvisor/issues.

Do not include API keys, private screenshots, personal messages, private hostnames, private IP addresses, or other sensitive data in public support issues.

## Unofficial App Notice

ForzAdvisor is not affiliated with, endorsed by, or sponsored by Microsoft, Xbox, Turn 10 Studios, Playground Games, or the Forza franchise.
