# Evidence Authorization Cleanup Retry

## Problem and outcome

Deleting one validation evidence record can remove the record successfully but
fail while removing its authorization state. The user is told cleanup is
pending, but only whole-tune purge and recovery-draft cleanup currently retry at
startup. Individual evidence cleanup must be durable and retry automatically.

## Requirements and acceptance criteria

- Persist a cleanup task, scoped by saved-tune ID and exact evidence
  fingerprint, before deleting the evidence.
- Treat every queued fingerprint as export-blocked until its task is resolved.
- Retry queued cleanup during root startup.
- Remove authorization state only when no saved tune has a live legacy or local
  record with that fingerprint and no other tune owns its recovery block.
- If evidence remains or the fingerprint is shared, remove only this cleanup
  task and preserve authorization state.
- Retrying a completed task is a no-op.

## Non-goals

- No changes to whole-tune purge, draft cleanup, evidence grant/revoke semantics,
  release metadata, versioning, or refinement behavior.

## Architecture and data decisions

The queue uses an atomically written JSON file in Application Support. An
authorization lookup consults the queue before returning a receipt, making a
persisted task a fail-closed export boundary. Queue corruption remains an error
instead of being discarded so it cannot silently re-enable export.

## Test mapping

- Fault-injected purge proves the task survives failure, blocks export, and is
  completed by a newly created coordinator on retry.
- A second retry proves idempotence.
- A live cross-tune fingerprint proves cleanup preserves shared authorization.

## Delivery and rollback

This is local persistence only and requires no migration. Rolling back leaves
the queue file inert; existing authorization and evidence formats are unchanged.

## Tasks

- [x] Add durable scoped cleanup storage and coordinator.
- [x] Make authorization lookup fail closed while queued.
- [x] Wire individual deletion and startup retry.
- [x] Compile the focused tests with generic build-for-testing.
