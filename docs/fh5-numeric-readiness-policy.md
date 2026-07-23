# FH5 Numeric Readiness Policy

Policy version: `fh5-numeric-readiness-v2`

FH5 numeric tuning is a separate product capability from FH5 build planning and
Research Lab. It remains unavailable until every gate below is machine-checkable
for the exact car and game context.

1. The request uses an untouched reviewed catalog car and current plan revision.
2. Research Lab contains a valid first-party observation of the exact menu.
3. Upgrade Lab contains a decision for every supported tuning-control part on
   the same game build.
4. At least two distinct permission-bound Research sessions agree exactly on
   platform, build, car, tire, gears, and menu measurements. Conflicts are never
   averaged.
5. The exact FH5 algorithm version and its permitted provenance appear in a
   code-owned trusted registry. A payload cannot approve itself by claiming
   `experimental` or `validated`.
6. Permission-bound, controlled Horizon Test Track outcomes satisfy a declared
   versioned policy for the exact ruleset and applied settings.

Research evidence establishes menu availability, slider range, step, and
restored stock position. It does not establish handling quality, optimality, or
performance improvement.

`Experimental` means a registered ruleset may be tested only in its declared
exact context and must expose uncertainty and rollback instructions.

`Validated` is reserved for a future ruleset that passes its predeclared
controlled-outcome policy and independent review. Agreement with public tunes
alone is not validation, and public Reddit or YouTube values are not reusable
without compatible rights or explicit permission.

Until a registry entry and outcome policy exist, all FH5 requests remain
provider-independent, numeric-free build plans. Manual, OCR, edited, legacy,
missing-snapshot, and malformed inputs must fail closed to that same plan-only
result.

## Registration and experimental threshold

The app now declares a closed, code-owned experimental algorithm identifier and
the registration contract a future implementation must satisfy. A valid
registration binds that identifier to:

- one exact FH5 ruleset reference with `experimental` status;
- canonical source manifests whose use permission is explicitly `permitted`;
- matching provenance IDs and a SHA-256 fingerprint computed from those source
  manifests by app code; and
- the supported controlled-outcome policy version.

Readiness resolves the registration from the internal algorithm identifier. It
does not accept a decoded ruleset descriptor as authority. The production
registry remains empty, so the rights gate cannot pass in this release.

The only supported experimental threshold is
`fh5-controlled-outcome-experimental-v1`:

- at least 10 unique, exact candidate-bound experiments;
- at least 8 `variantPreferred` outcomes;
- zero `baselinePreferred` outcomes;
- at most 2 combined `noClearDifference` or `inconclusive` outcomes;
- experiments recorded on at least 2 distinct UTC dates; and
- explicit deidentified reuse permission on every counted record.

This threshold is a conservative experimental smoke gate, not scientific
validation. A future evaluator must fail closed on collisions or replay across
submission ID, permission receipt ID, and semantic fingerprint. Every counted
record must match the exact algorithm, ruleset reference, source-manifest
fingerprint, policy version, generated candidate fingerprint, plan, measured
menu, field, direction, value, test context, and protocol.

No evaluator, production registration, FH5 numeric generator, or activation
route exists yet. Even a test-injected valid registration can complete only the
rights gate; controlled outcomes remain blocked, and the provider and output
projector continue to strip every FH5 numeric setting.

## Paired experiment collection

Outcome Lab may collect local calibration evidence before a promotion policy
exists. Its versioned `fh5-abba-one-step-v1` protocol:

- binds to the exact current saved plan and matching Research Lab measurements;
- changes exactly one control recorded as Adjustable by exactly one observed
  slider step;
- fixes the run order to stock A, variant B, variant B, stock A on Horizon Test
  Track;
- requires the route, surface, conditions, assists, input, and every other
  setting to remain unchanged;
- records one target symptom and a comparative outcome only; and
- requires the stock value to be restored before the record is saved.

These records are evidence, not tune recommendations. They cannot register a
ruleset, set their own acceptance threshold, pass the controlled-outcome gate,
or make numeric FH5 output available.

Deidentified calibration reuse is optional and off by default for each record.
When explicitly permitted before saving, the app may create a user-initiated,
allow-listed JSON export with a public semantic fingerprint. The export omits
the local experiment ID, saved tune ID and plan fingerprint, Research Lab
record ID and content fingerprint, generated tune values, provider and ruleset
data, notes, screenshots, telemetry, device identifiers, location, analytics,
share destination, and public attribution. It retains the menu-measurement
fingerprint that binds the observed controls. Exporting a record does not make
it promotion-eligible: schema-v1 experiments have no app-assigned candidate
binding and remain calibration evidence only.
