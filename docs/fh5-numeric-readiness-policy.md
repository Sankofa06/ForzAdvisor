# FH5 Numeric Readiness Policy

Policy version: `fh5-numeric-readiness-v1`

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
