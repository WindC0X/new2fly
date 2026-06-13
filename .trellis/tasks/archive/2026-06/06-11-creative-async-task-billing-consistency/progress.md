# Progress — Creative async task billing consistency

## Status

Implemented and locally verified on 2026-06-11.

## Backend changes in `../new-api`

- `controller/relay.go`
  - Submit success still buffers upstream response until local task insert + scoped idempotency completion + durable submit billing outbox finalization.
  - Submit billing finalization now uses `SettleSubmittedTaskBillingDurably` / `TaskBillingOutbox` instead of logging-and-flushing after `SettleBilling` errors.
  - Idempotency records are deleted only when the provider was not accepted (`result == nil`) and no task was persisted; provider-accepted local failures keep the idempotency guard to prevent duplicate upstream submit.
- `model/task.go`, `model/main.go`
  - Added `TaskBillingOutbox` with `(task_id, operation)` uniqueness, `pending/processing/failed/done` statuses, stage flags, and migrations in normal/fast migrate paths.
  - Added `TaskBillingContext.PreConsumedQuota` and `UpdateWithStatusAndBillingOutbox` for terminal CAS + outbox enqueue in one DB transaction.
- `service/task_billing.go`
  - Added submit/terminal billing outbox processing.
  - Outbox processing atomically claims rows before applying funding/token/log effects to avoid concurrent double refund/settle.
  - Pending/failed/stale-processing outboxes are retried from the polling loop.
- `service/task_polling.go`
  - Removed billable unconditional `TaskBulkUpdateByID` paths from null-upstream/channel-failure handling.
  - Channel failure, null upstream, timeout, missing selected key, and terminal failure paths now use per-task CAS + refund outbox.
  - Creative tasks (`PrivateData.IdempotencyKey` present) no longer fall back from missing `UpstreamTaskID` to public `TaskID`.
  - Creative tasks missing `PrivateData.Key` fail closed instead of falling back to current channel key.
- `relay/relay_task.go`
  - Gemini/Vertex realtime fetch now fails closed for Creative tasks missing stored selected key/upstream id; channel-key fallback remains only for legacy tasks.

## Regression tests added/updated

- `controller/relay_task_test.go`
  - Idempotency delete decision keeps guard after provider acceptance.
- `model/task_cas_test.go`
  - CAS winner creates exactly one billing outbox.
- `service/task_billing_test.go`
  - Outbox refund idempotency.
  - Concurrent outbox processing applies refund once.
  - Submit-settle outbox adjusts pre-consume delta.
- `service/task_polling_affinity_test.go`
  - Creative missing selected key fail-closed for video and Suno.
  - Channel missing per-task CAS + refund.
  - Null-upstream CAS + refund once.
  - Creative null-upstream classification does not fall back to public task id.
- `relay/relay_task_test.go`
  - Realtime fetch key selection: Creative missing key fails closed, stored key works, legacy fallback remains explicit.

## Dynamic workflow verification

- `.codex-flow/generated/creative-async-task-billing-check.workflow.ts`
  - Found two real gaps: Creative null-upstream classification fallback and realtime fetch channel-key fallback.
  - Both were fixed.
- `.codex-flow/generated/creative-async-task-billing-recheck.workflow.ts`
  - Found two further gaps: deleting idempotency after provider-accepted insert failure and non-claimed outbox concurrent processing.
  - Both were fixed.
- `.codex-flow/generated/creative-async-task-billing-recheck2.workflow.ts`
  - Rechecked and passed submit/idempotency plus previous key/upstream findings.
  - One terminal branch failed due tool/backend auth instability; covered manually with code inspection and tests below.

## Validation commands

Run in `/mnt/f/code/project/new-api` with:

```bash
GOCACHE=/mnt/f/code/project/new2fly/.cache/go-build \
GOTMPDIR=/mnt/f/code/project/new2fly/.cache/go-tmp \
GOMODCACHE=/home/windc0x/go/pkg/mod \
go test ./controller ./service ./model ./relay ./relay/common ./relay/constant \
  -run 'Creative|Task|Billing|Idempotency|CAS|Refund|Settle|Channel|Key|Realtime|NullUpstream|ShouldDelete' -count=1
```

Passed.

```bash
GOCACHE=/mnt/f/code/project/new2fly/.cache/go-build \
GOTMPDIR=/mnt/f/code/project/new2fly/.cache/go-tmp \
GOMODCACHE=/home/windc0x/go/pkg/mod \
go test ./controller ./service ./model ./relay -count=1
```

Passed.

```bash
GOCACHE=/mnt/f/code/project/new2fly/.cache/go-build \
GOTMPDIR=/mnt/f/code/project/new2fly/.cache/go-tmp \
GOMODCACHE=/home/windc0x/go/pkg/mod \
go test ./router ./middleware ./controller ./service ./model ./relay ./relay/common ./relay/constant -count=1
```

Passed.

## Notes / residual

- Dynamic workflow terminal-only retry hit `401 Unauthorized` from the codex-flow backend; the terminal outbox fix was manually verified and covered by concurrent/idempotent Go tests.
- Existing broader `go test ./relay/...` historical failures in unrelated relay subpackages were not rerun as part of this child.
