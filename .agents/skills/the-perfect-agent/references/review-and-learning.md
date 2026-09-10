# Review and learning

Read this reference for consequential acceptance, material repair, release-critical work, or memory promotion.

## Artifact identity and evidence

Name the review target with a commit, tree hash, file-hash manifest, rendered export, or equivalent snapshot. Record evidence as:

```text
Artifact identity:
Gate or signal:
Oracle and target:
Result: PASS | FAIL | UNVERIFIED | N/A
Direct evidence:
Observed by:
Invalidated by:
```

Old evidence remains history but cannot pass a gate after a material change invalidates it.

## Blind critic packet

Include only:

- original outcome, constraints, and authority;
- exact artifact access and identity;
- gates and quality bar;
- authoritative references;
- safe read-only verification methods.

Exclude builder rationale, suspected defects, self-assessment, intended answers, previous criticism, fix history, and case-specific persona memory.

Require per-gate verdicts with direct evidence, the strongest element to preserve, up to three ranked material findings, the smallest correction for each, personally observed versus supplied evidence, and residual uncertainty.

## Repair and convergence

Critic findings are proposals. Accept only findings with artifact-specific evidence and gate impact. Reject taste-only or scope-expanding feedback.

After a material repair:

1. refresh artifact identity;
2. invalidate affected evidence;
3. rerun the target and preservation gates;
4. use a different fresh acceptance critic.

Normal consequential work allows up to two material repair cycles. High-impact or release-critical work allows up to three. A ceiling never converts gaps into a pass.

Stop when authority or an oracle is unavailable, further effort is disproportionate, the same material failure survives distinct repairs, or progress stalls. Preserve exact residual signals.

## Memory promotion

Promote a lesson only when it is evidence-backed, reusable, non-sensitive, likely to change a future decision, and either repeated across cases or clearly causal in one high-impact incident.

Shared memory entry:

```text
ID and status:
Scope and trigger:
Observed outcome and evidence:
Reusable rule and exceptions:
Confidence and last verification:
Review, expiry, or retirement trigger:
```

Put cross-role lessons in `MEMORY.md`. Put durable role-specific lessons in the active persona memory. Enforce 25 durable shared entries, 10 working entries with 30-day expiry, and 10 lessons per persona with a 90-day inactivity review.

Automations may propose a candidate with evidence but cannot promote it. Delete stale entries rather than preserving an archive of old reasoning.
