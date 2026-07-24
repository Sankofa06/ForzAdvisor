# FH5 Clean-Room Directional Experiment v1

Algorithm ID: `fh5.clean-room-directional-v1`

This algorithm produces one candidate-bound Outcome Lab artifact for controlled
testing. It does not produce a tune, mutate a saved plan, authorize numeric
output, or claim that the candidate improves performance.

## Supported hypothesis

For an untouched stock FH5 catalog car whose driver reports `pushesWide`, test
front tire pressure exactly one observed slider step below its restored stock
value. The hypothesis is deliberately narrow: changing one control by one step
may provide evidence about the reported symptom under the fixed A-B-B-A
protocol.

No other symptom, control, direction, or multi-step change is implemented.

## Required evidence

Generation fails closed unless all of the following hold:

- the current result exactly equals its saved FH5 catalog-origin, plan-only
  revision;
- the latest matching first-party Research Lab record is structurally valid,
  personally read from the game, untouched stock, restored, and locally
  permitted;
- Upgrade Lab has a complete availability decision for every supported
  tuning-control part;
- two independent canonical, permission-bound review exports pass the real
  ingestion and review evaluator and agree on the exact platform, game build,
  car, tire compound, gear count, and measurement fingerprint, with no
  conflicting, invalid, quarantined, or replayed evidence (a caller-created
  summary report is never accepted as authority);
- front tire pressure is adjustable and has a finite PSI minimum, maximum,
  positive step, and restored current value on the observed slider lattice;
- one step lower remains inside that observed range; and
- a valid clean-room registration is present in the caller-provided trusted
  registry.

The evaluator alone creates the opaque exact-replication proof. The generator
accepts raw reviewed inputs and cannot consume a freely constructed aggregate.

The artifact fingerprint binds the algorithm and source manifest, policy,
saved-plan revision, Research record, measurement fingerprint, car and test
context, field, range, step, baseline, candidate, unit, input, surface, and
target symptom.

## Isolation and rights boundary

The implementation is first-party clean-room logic derived only from
permission-bound local menu observations and the declared directional
hypothesis. Public YouTube or Reddit numeric values are not inputs and must not
be copied into the implementation, fixtures, training data, or committed
benchmarks without explicit creator permission or a verified compatible
license.

Public tunes may be evaluated later as black-box outcome references: install
the public tune in-game, run a predeclared paired protocol, and retain only
permission-safe opaque source identifiers and outcome measurements. Popularity,
likes, rank, or resemblance to a public number are not evidence of accuracy.

Artifact creation builds only the shared context, one-step change, and candidate
binding. It does not create a completed experiment record or manufacture
A-B-B-A, authorship, or restoration attestations; those are required later from
the actual experiment capture.

The production registry is intentionally empty. An exact-evidence,
candidate-only experimental UI can lock and display this hypothesis for the
fixed A-B-B-A protocol, then persist the completed outcome locally as a
schema-v2 record. With reuse permission and a separate per-share confirmation,
the app can create a deidentified Candidate Outcome export whose association
fingerprint contains only the registered algorithm/source/policy and exact
public experiment semantics. A recipient must independently regenerate that
exact candidate before adding the canonical bytes to a separate local review
queue. Generic user-selected Outcome Lab calibration remains a separate
schema-v1 flow. Imported outcomes are collection-only: no provider, projector,
`TuneResult`, clipboard, production registry, readiness authorization, or
numeric-output route consumes them. Promotion requires a separate reviewed
activation change.
