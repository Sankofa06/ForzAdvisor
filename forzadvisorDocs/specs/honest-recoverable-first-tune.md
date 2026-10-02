# Honest, Recoverable First Tune

Status: implemented for internal TestFlight review

## Intent

ForzAdvisor should help a Forza player move from captured car evidence to an understandable next action without claiming more certainty or game support than the current flow can establish. A first tune may be a numeric settings result, a build plan, or a recoverable setup that still needs evidence.

## Scope

- Keep OCR and manual entry fail-closed when a value is marked `Needs Check`.
- Accept horsepower and torque only when the captured unit is explicitly supported by the current canonical model (`hp`/`bhp` and `ft-lb`/`lb-ft`). Do not silently convert or reinterpret `kW`, `Nm`, or ambiguous values.
- Preserve a meaningful in-memory draft across Close -> Garage -> New Tune, while leaving a blank session blank.
- Keep FH5 generation as a local build-plan flow and describe the actual provider route rather than a preference or credential presence.
- Distinguish result availability from accuracy validation. A complete zero-setting FH6 result may be saved as `Setup`, but it cannot be copied as numeric settings or refined until settings are available.
- Expose selected class and drivetrain state through accessibility semantics, not color alone.

## Non-goals

This slice does not add new FH6 capture callbacks, change persistence schema, add unit conversion, redesign refinement history, alter credentials, or make claims about tuning accuracy that the evidence cannot support.

## Acceptance criteria

1. OCR confirmation excludes every value still marked `Needs Check` from the generation request.
2. Unsupported or ambiguous power/torque units do not become candidate hp/lb-ft values.
3. Meaningful draft facts, game, image, review state, and discipline survive the Garage/New Tune transition.
4. Zero-setting FH6 output is labeled as a setup, offers Save Setup/Edit, and withholds numeric copy/refine actions.
5. Positive results report the count of available settings without calling availability accuracy validation.
6. FH5 provider disclosure and output identify the local build-plan route.
7. Focused unit tests cover the above policies and the changed code builds warning-free for the tested configuration.

## Verification mapping

- OCR integrity: `OCRTextParserTests`
- Draft recovery: `TuneWorkflowSessionTests`
- Result action policy: `TuneResultPresentationTests`, `TuneClipboardFormatterTests`
- Provider/game disclosure: `TuneProviderDisclosureTests`, `DisciplineGenerationPresentationTests`
- Local runtime and release gates remain required before internal TestFlight delivery.
