# ForzAdvisor Support

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

Open Beta Validation Missions from the garage to see the next local testing tasks supported by your saved FH5 and FH6 setups. An empty garage offers one starter mission for each game. Eligible saved setups can offer Research Lab, Outcome Lab, Tire Lab, Upgrade Lab, or Record Test Drive missions, and completed or stale tasks disappear when you reopen the board.

The mission board does not upload progress or create evidence by itself. Share Beta Progress opens the iOS system share sheet with aggregate counts only and excludes car names, tune values, notes, identifiers, screenshots, and analytics.

### How do I join or invite an FH5 Research Partner?

In Beta Validation Missions, open FH5 Research Partners. You can open the capped public TestFlight group at https://testflight.apple.com/join/ec1RxDV3 or share a public-only invitation. It contains no local counts, car values, identifiers, fingerprints, or Candidate Outcome JSON.

Partners need FH5 and an iPhone with iOS 17 or later. Apple controls external beta availability; after approval, install the latest beta, coordinate the same FH5 game build and untouched stock catalog car, save the exact plan, and complete Upgrade Lab plus required Research evidence. Candidate Outcome JSON still requires explicit reuse/share and direct-receipt permission. Reviewed outcomes are collection-only and cannot unlock numeric FH5 tuning; IDs and hashes do not authenticate identity.

Send feedback through TestFlight's Send Beta Feedback with the car, game build, input, surface, and exact unclear or unexpectedly rejected step. Do not include private JSON or identifiers.

### What is FH5 Outcome Lab?

After a matching Research Lab record and complete Upgrade Lab observation exist, Outcome Lab guides a fixed A-B-B-A Horizon Test Track experiment. You compare stock with one user-selected slider step while keeping the route, conditions, assists, input, and every other setting unchanged, then restore the stock value.

The result remains calibration evidence. It does not generate a tune, collect lap times or telemetry, register a ruleset, or unlock numeric FH5 settings. Deidentified reuse is off by default. Generic calibration retains its schema-v1 share. A generated Candidate Outcome also requires a separate confirmation for each manual share. Candidate Outcome Review accepts it only after this device regenerates the exact candidate and you confirm direct receipt and reuse permission. Reviewed outcomes stay in a separate local queue and cannot affect readiness or numeric output. UUIDs and hashes bind bytes, not tester identity. There is no background upload, and deleting local evidence cannot recall a shared copy.

### How do I delete a tune?

Open the garage, swipe left on a saved tune, and tap Delete.

### How do I remove my API key?

Open Settings, switch the provider to Anthropic API if needed, and tap Clear Key.

## Contact

Use the public support tracker at https://github.com/Sankofa06/ForzAdvisor/issues.

Do not include API keys, private screenshots, personal messages, private hostnames, private IP addresses, or other sensitive data in public support issues.

## Unofficial App Notice

ForzAdvisor is not affiliated with, endorsed by, or sponsored by Microsoft, Xbox, Turn 10 Studios, Playground Games, or the Forza franchise.
