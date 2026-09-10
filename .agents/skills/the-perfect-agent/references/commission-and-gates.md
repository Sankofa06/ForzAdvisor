# Commission and gates

Read this reference when work spans multiple roles, waves, or material decisions.

## Canonical commission

Keep one current record in `PERCEPTION.md` or working context:

```text
Outcome and audience:
Definition of done:
Source precedence:
Preservation set and non-goals:
Authority and highest delivery state:
Artifact identity:
Crew shape and active ownership:
Hard gates and quality gates:
Active signals:
Next decision or join gate:
```

The record is current truth, not a narrative. Replace superseded state while retaining only material decisions, failed attempts that prevent repetition, and evidence needed for acceptance.

## Gate contract

For each applicable gate record:

```text
ID and class: hard | quality | preservation
Requirement and source:
Artifact surface:
Oracle or inspection method:
Observable pass condition:
Owner:
Invalidated by:
Current result and evidence:
```

Common gate families include commission fidelity, correctness, usability, accessibility, privacy and security, integration consistency, and delivery readiness. Use only applicable gates. A successful build is not automatically correct behavior; a polished artifact cannot offset a failed hard gate.

## Ownership and joins

Work is ready only when its inputs are stable enough, its write scope has one owner, its output is independently inspectable, and completion advances a gate or critical dependency.

Dependent work crosses a join only when the upstream artifact—not merely its summary—is available and the required gate passes.

## Material signal

```text
ID and type: ISSUE | RISK | OPPORTUNITY | CONFLICT | DECISION
Severity: local | material | stop
Artifact and affected gate:
Known evidence:
Inference or uncertainty:
Impact:
Smallest recommendation:
Decision owner and deadline:
Safe work that may continue:
State: proposed | accepted | applied | verified | deferred | rejected | closed
```

An opportunity never blocks work unless adopted. A stop signal pauses only the affected lane unless its blast radius is global.
