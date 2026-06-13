# Design — Creative Release Blocker Remediation

## Task Architecture

This parent task is a coordination task. It should not directly own code changes unless a small integration-only adjustment is needed after child completion. Code changes belong to independently verifiable child tasks.

```text
Parent: release blocker remediation
├── Backend security boundary hardening
├── Async task billing consistency
├── Frontend session-broker + asset sync hardening
└── Asset quota/delete lifecycle hardening
```

## Cross-Repository Boundaries

- `new2fly` owns Trellis planning, specs, task state, and final integration judgment.
- `../new-api` owns backend routes, middleware, relay controllers, async task model/service logic, billing/outbox, asset API/storage, and Go tests.
- `../opentu` owns frontend session-broker request shaping, provider transport stripping, asset prepare/hydrate, service worker behavior, and Vitest tests.

## Verification Strategy

Use two complementary check modes:

1. Deterministic tests:
   - Go unit/integration tests for each backend child task.
   - Vitest tests for each frontend child task.
   - These are required before any child can finish.

2. Dynamic workflow verification:
   - Use `codex-flow` read-only branches after implementation, not as a replacement for tests.
   - Branches should be independent and adversarial:
     - backend route/middleware/privacy branch;
     - async billing/CAS/refund branch;
     - frontend session-broker/asset branch;
     - cross-layer DTO/credential/URL contract branch;
     - test coverage branch.
   - The workflow should write a journal under `.codex-flow/journal/` and the summary should be copied or linked from parent check notes.

## Dynamic Workflow Design

Planned workflow file after fixes:

- `.codex-flow/generated/creative-release-blocker-postfix-check.workflow.ts`

Expected branches:

- `backend-security-boundary-review`: inspect H1/H5/H9/M6/H10/M1/proxy fixes in `../new-api`.
- `async-billing-review`: inspect H2/H3/H4/M9 fixes in `../new-api`.
- `frontend-session-assets-review`: inspect H7/H8/H9/M7/M8 fixes in `../opentu`.
- `asset-lifecycle-review`: inspect H6/M2/M3 fixes in `../new-api`.
- `test-matrix-review`: verify tests cover every HIGH finding and are wired into commands.

Use read-only sandbox for the check workflow. Writable dynamic workflows are not required for this parent task.

## Compatibility And Rollback

- Route extraction must preserve existing admin/classic/default web serving behavior.
- Backend security-denylist changes must preserve legitimate top-level model handling only where the contract explicitly allows server-side derivation.
- Billing/outbox changes must be idempotent; retries must not double-settle or double-refund.
- Asset delete lifecycle changes must be safe if interrupted between metadata and object operations.
- Frontend sanitizer changes must fail closed with sanitized errors, not mutate the live board unexpectedly.

## Risk Controls

- Write regression tests before or alongside fixes for each HIGH finding.
- Keep schema changes minimal; if schema is needed for outbox/tombstone/reservation, include migration and rollback notes in the owning child task.
- Avoid broad refactors of relay or provider routing outside the affected paths.
- No production endpoints or real provider credentials in tests.
