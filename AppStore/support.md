# ForzAdvisor Support

ForzAdvisor helps racing-game players generate, save, copy, and adjust tuning setups from car details they confirm.

The current app does not include a bundled car roster or reviewed stock catalog. Each new tune starts from information you provide.

## Common Questions

### Do I need an account?

No. ForzAdvisor does not require an account.

### Do I need an API key?

No. Offline formula tuning is the default. Apple on-device model assistance is optional when available. Anthropic API mode is optional and uses an API key you provide.

### How do I start a tune?

Tap New Tune, then choose:

- Take Photo to capture your own performance screen;
- Import Screenshot to select your own image through the system picker; or
- Enter Manually to type the car and performance details.

Confirm every detected or entered value, choose a discipline, and review the result.

### Where is the car catalog?

The bundled FH5/FH6 roster and reviewed stock catalog were removed. Use photo, screenshot, or manual entry instead.

### Are screenshots uploaded?

No. Camera photos and imported screenshots are processed on device with Apple Vision OCR. If you save the resulting tune, the app may keep a small local thumbnail on your device.

Optional Anthropic API mode sends confirmed text details and notes, not the source image.

### What does FH5 produce?

FH5 manual entry creates a local build plan without numeric tuning settings. Numeric FH5 tuning remains unavailable until a separately validated ruleset exists.

### What does FH6 produce?

FH6 can generate menu-order numeric settings using offline formulas. Unsupported or out-of-range settings are withheld instead of guessed.

### How do I copy or refine a setup?

Open a generated or saved setup to copy eligible lines or the full setup. Use Guided Refinement after a run to request handling changes supported by the current result.

### How do I delete a tune?

In the garage, swipe left on a saved tune and tap Delete.

### How do I remove my API key?

Open Settings, select Anthropic API mode if needed, and tap Clear Key.

### How do I control camera or photo access?

You can use manual entry without camera or photo access. Camera permission can be changed in iOS Settings. Screenshot import uses Apple's system photo picker.

### How do I report a problem?

Use the public support tracker:

https://github.com/Sankofa06/ForzAdvisor/issues

Include the app version, game selection, input method, discipline, and the step that failed. Do not include API keys, private screenshots, personal messages, private hostnames, private IP addresses, or other sensitive information.

## Unofficial App Notice

ForzAdvisor is not affiliated with, endorsed by, or sponsored by Microsoft, Xbox, Turn 10 Studios, Playground Games, or the Forza franchise.
