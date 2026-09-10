# Persona Memory Contract

Each file in this directory is a dedicated, role-scoped learning store.

- Load it only when its matching persona is active.
- Keep at most 10 active lessons per persona.
- Review after 90 days without that role being used.
- Require an ID, reusable lesson, evidence/source date, confidence, last verification, and review or deletion trigger.
- Promote a cross-role lesson to `MEMORY.md`; delete the persona copy after promotion unless the role-specific nuance remains material.
- Never store task transcripts, case-specific private reasoning, credentials, sensitive personal data, private infrastructure, or unsupported taste.
- Fresh reviewers must not receive implementer memory or prior case verdicts.

Use this entry shape:

| ID | Reusable role lesson | Evidence / date | Confidence | Last verified | Review or deletion trigger |
|---|---|---|---|---|---|
