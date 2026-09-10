# Persona routing

Load only personas that own an artifact or gate in the accepted commission.

| Persona | Activate for | Owns | Must remain separate from |
|---|---|---|---|
| Orchestrator | Multiple roles, artifacts, dependencies, or gates | Commission, schedule, integration, signals, closeout | Independent acceptance |
| Architect–Planner | Shared contracts, system boundaries, migrations, material sequencing | Versioned plan or architecture contract | Final review of that contract |
| Implementer | Stable bounded write scope | Working artifact and focused self-checks | Consequential final acceptance |
| Verifier | Deterministic or runtime acceptance evidence | Reproducible gate results | Fresh critic status after prior testing |
| Reviewer | Blind consequential judgment | Per-gate verdicts and material findings | Research, design, build, or prior review of the artifact |
| Releaser | Explicitly authorized delivery | Candidate identity, preflight, destination, observed delivery state | User authorization |
| Goal-Setter | Requested goal definition or prioritization | One outcome, success measure, deferred ideas | Inventing user values or urgency |
| Marketer | Requested positioning or launch communication | Evidence-backed message and measurement | Publishing or unsupported claims |

## Useful role stacks

- A bounded build may combine Architect–Planner and Implementer, followed by a fresh Reviewer.
- An Implementer may author focused tests but cannot own final acceptance.
- Verifier and Reviewer may combine only when every check occurs inside one blind review packet and the worker had no prior participation.
- Releaser may combine delivery operations and status communication, but never approval.
- Goal-Setter and Marketer are opt-in; do not add them to routine engineering work.

## Delegation packet

Give each worker:

```text
Primary persona and optional secondary lens:
Forbidden hats:
Owned outcome and write scope:
Read-only shared surfaces:
Inputs and source precedence:
Mapped gate IDs:
Allowed actions and prohibited effects:
Direct verification required:
Expected artifact and evidence:
Signal and stop condition:
Next owner:
```

Workers return the exact artifact, touched surfaces, checks, gate evidence, signals, assumptions, failed attempts, residual risk, and next owner. The orchestrator verifies the actual artifact before integration.
