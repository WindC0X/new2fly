# Creative Release Blocker Remediation

## Goal

Coordinate the release-blocking remediation for the embedded Creative integration across `../new-api` and `../opentu`, based on the merged audit/arbitration findings. The parent task owns scope, sequencing, integration acceptance, and final verification strategy; implementation work is delegated to child tasks.

## Source Evidence

- Codex audit report: `.trellis/tasks/archive/2026-06/06-11-newapi-opentu-deep-audit/audit-report.md`
- Claude Code audit report: `.trellis/workspace/WindC0X/creative-embed-audit-2026-06-11.md`
- User-approved arbitration in conversation: Codex report is the main evidence source; Claude Code arbitration is used for de-duplication, severity calibration, and supplemental findings.

## Release Policy

- Treat all HIGH items in this PRD as release blockers.
- Medium items may ship after explicit risk acceptance only if each remaining item has a documented owner, impact statement, and follow-up task.
- No child task may be marked complete without targeted regression tests for its fixed HIGH findings.
- Verification/check stages should partially use dynamic workflows (`codex-flow`) for independent read-only audit branches and post-fix adversarial checks, while deterministic unit/integration tests remain mandatory.

## Child Task Map

1. `06-11-creative-backend-security-boundary-hardening` — backend route/privacy/forbidden-field/same-origin/cache/proxy boundary fixes.
2. `06-11-creative-async-task-billing-consistency` — async task submit, idempotency, billing, CAS refund/settle, channel failure, stored-key fallback fixes.
3. `06-11-creative-frontend-session-broker-asset-sync-hardening` — Opentu session-broker stripping, asset URL discovery, hydrate sanitizer, unsupported error cleaning, nonce fail-fast.
4. `06-11-creative-asset-quota-delete-lifecycle-hardening` — backend asset quota reservation, delete/tombstone/outbox, document/ref transaction, PRD/spec reconciliation.

## Requirements

### HIGH / Release Blockers

- H5: Suno fetch endpoints must reject non-Suno tasks and return only a sanitized Suno-specific DTO.
- H9/M6: Browser/client-supplied `notifyHook`, `notify_hook`, `callback`, `webhook`, owner/user override fields, and API-secret variants must be blocked both in Opentu request construction and new-api backend relay guards.
- H2: Async task submit success must not become visible until task persistence, scoped idempotency completion, and billing/log bookkeeping are safe or durably recoverable.
- H3: Terminal task CAS winners must record durable settlement/refund work so process crashes or DB/cache failures cannot permanently skip billing compensation.
- H4: Channel lookup failure and null upstream id task failure must transition tasks with per-task CAS and refund/settle semantics, not unconditional bulk updates.
- H7/H8: Opentu cloud asset preparation/hydration must detect all required local media refs and must run unsafe URL sanitizer even when a remote payload contains no cloud asset refs.
- H6: Creative asset quota checks and writes must be atomic or reservation-based enough to prevent concurrent bypass of per-user count/byte limits.
- H1: Creative API/relay routes must be registered independently of static web serving so `FRONTEND_BASE_URL` deployment either supports Creative routes or returns controlled same-origin JSON fail-closed responses, never a frontend redirect for Creative API/relay paths.

### MEDIUM / Hardening

- X-Forwarded-* same-origin expectations must be based on trusted proxy configuration or canonical public origin, not arbitrary client headers.
- Cache middleware must not add public/long-lived cache headers to `/creative/api` or `/creative/relay` responses.
- Asset delete must not lose object-key metadata before object deletion succeeds; use tombstone/outbox or equivalent recoverable lifecycle.
- Document mutation and document asset ref refresh/delete must be in a consistent transaction or lock domain.
- Frontend unsupported backend errors must be sanitized before reading/logging raw response bodies.
- Stored-key fallback paths must be narrowed to explicit legacy migration cases or fail closed for new Creative tasks.
- Creative proxy clients must not use redirect-unchecked `http.DefaultClient` fallbacks, and redirects must strip sensitive headers.

## Out Of Scope

- Broad redesign of the Creative product surface.
- Adding new providers or expanding unsupported MJ actions beyond explicit existing contracts.
- Production endpoint calls, real provider calls, payment provider calls, or real S3 mutations during planning/checking.
- Full multi-database migration matrix unless a child task changes schema/locking behavior that requires it.

## Acceptance Criteria

- [x] All child task planning artifacts exist: `prd.md`, `design.md`, `implement.md`, plus relevant `implement.jsonl` / `check.jsonl` manifests.
- [x] Each HIGH finding has at least one red/green regression test or a documented deterministic verification harness.
- [x] Dynamic workflow check stage used read-only multi-branch `codex-flow` verification in backend-security, async-billing, and frontend session/assets children; the final asset-lifecycle workflow attempts timed out and were explicitly triaged with deterministic tests/manual review rather than counted as pass evidence.
- [x] Targeted Go test suites pass in `../new-api` for router/middleware/controller/model/service/relay Creative areas.
- [x] Targeted Vitest suites pass in `../opentu` for session-broker video/audio/MJ, creative asset sync, provider transport, and SW pass-through areas.
- [x] Parent final review confirms no stale audit finding remains unclassified as fixed, accepted risk, or follow-up.
