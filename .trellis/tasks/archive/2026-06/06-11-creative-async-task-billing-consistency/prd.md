# Creative async task billing consistency

## Goal

Fix async task lifecycle consistency in `../new-api` so Creative Video/Suno/MJ submit, idempotency, terminal polling, settlement, refund, and selected-key affinity are atomic or durably recoverable.

## Source Findings

- Codex H2: submit success path does not atomically persist task, complete idempotency, and settle billing before flushing success.
- Codex H3: terminal CAS winner can crash or hit billing failure after status transition, causing permanent missing refund/settlement.
- Codex H4: channel lookup failure and null upstream id use unconditional bulk failure without CAS/refund.
- Codex M9: selected-key affinity can fall back to current channel key in status/realtime/content paths.
- Claude Code confirmed H2/H3/H4 and narrowed M9 scope.

## Requirements

- Accepted task submit success must only be returned after local task state and idempotency state are safe and billing/log work is either complete or durably queued.
- Idempotency replay must not double-charge, double-submit, or expose a task before its local state is safe.
- Terminal success/failure transitions must use CAS; only the CAS winner may enqueue or perform settlement/refund.
- Billing settlement/refund must be retryable and idempotent after process crash or transient DB/cache failures.
- Channel missing/cache failure/null upstream id paths must not use unconditional bulk update for billable tasks.
- New Creative tasks missing submit-time selected key must fail closed unless an explicit legacy migration path is documented and tested.

## Acceptance Criteria

- [ ] Tests cover task insert failure after upstream success: no non-recoverable visible success and no leaked idempotency completion.
- [ ] Tests cover idempotency completion failure after task insert: safe recovery or no visible success.
- [ ] Tests cover `SettleBilling` failure: success response is not flushed unless durable retry state exists.
- [ ] Tests cover terminal CAS success/failure with only one refund/settle across concurrent callers.
- [ ] Tests cover channel missing/cache error and null upstream id: per-task CAS and refund once.
- [ ] Tests cover selected-key missing fallback behavior for Creative tasks.
- [ ] Relevant Go targeted tests pass.
