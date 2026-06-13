# Creative Async Task Billing Consistency Backend Contract

## Scenario: Creative async task submit, polling, billing outbox, and key affinity

### 1. Scope / Trigger

- Trigger: changing async task submit, idempotency, polling, settlement, refund, or selected-key affinity code in `new-api` for Creative Video, Suno, MJ, Gemini/Vertex realtime fetch, or future Creative task providers.
- This is cross-layer backend work: HTTP relay response timing, DB task/idempotency rows, durable billing outbox rows, channel/key affinity, polling CAS, wallet/subscription/token quota mutation, and public fetch behavior must remain consistent.
- Applies to `controller/relay.go`, `service/task_polling.go`, `service/task_billing.go`, `model/task.go`, and realtime task fetch code in `relay/relay_task.go`.

### 2. Signatures

- DB models:
  - `Task.PrivateData.UpstreamTaskID` stores the provider task id for new Creative tasks.
  - `Task.PrivateData.Key` stores the submit-time selected upstream key.
  - `Task.PrivateData.IdempotencyKey` marks new Creative idempotent submit tasks.
  - `Task.PrivateData.BillingContext.PreConsumedQuota` stores submit-time pre-consume quota for durable submit-settle retry.
  - `TaskBillingOutbox(TaskRowID, UserId, TaskID, Operation)` is unique for each task billing operation; processors must resolve modern rows by `TaskRowID + UserId`, not by provider/public `TaskID` alone.
- Outbox operations:
  - `submit_settle` adjusts `actual_quota - pre_consumed_quota` after accepted submit.
  - `terminal_settle` applies success-time actual quota adjustment.
  - `terminal_refund` refunds pre-consumed quota on terminal failure / fail-closed paths.
- Outbox statuses:
  - `pending`, `processing`, `failed`, `done`.

### 3. Contracts

- Submit success response must be buffered until:
  1. provider submit returned success;
  2. local `Task` row is inserted;
  3. scoped Creative idempotency points at the public task id;
  4. submit billing settle is either completed or durably queued in `TaskBillingOutbox`.
- If provider submit succeeded but local task insert/idempotency/settle finalization fails, do not delete the idempotency guard merely to allow retry; retries must not create a second upstream task.
- Terminal polling transitions must use status CAS. Only the CAS winner may create/process a terminal billing outbox entry.
- `ProcessTaskBillingOutbox` must atomically claim a pending/failed/stale-processing row before applying funding/token/log effects. Concurrent processors must not double-refund or double-settle.
- `ProcessTaskBillingOutbox` must fail closed for ownerless legacy/anomalous outbox rows (`task_row_id=0` and `user_id=0`) instead of falling back to `task_id` alone; such rows require explicit backfill or manual repair before retry.
- New Creative tasks must use stored selected key affinity. If `IdempotencyKey` is present and `PrivateData.Key` or `PrivateData.UpstreamTaskID` is missing, polling/realtime fetch must fail closed instead of falling back to current channel key or public task id.
- Legacy non-Creative tasks may still fall back from missing `UpstreamTaskID` to `TaskID`, and from missing selected key to current channel key, but this compatibility path must not apply to Creative idempotent tasks.

### 4. Validation & Error Matrix

- Task insert fails after provider success -> no flushed success; keep idempotency guard so replay cannot resubmit upstream.
- Idempotency completion fails after task insert -> no flushed success; keep local task/idempotency knowledge for safe recovery/replay.
- Submit settle fails after task insert/idempotency -> success may flush only if `submit_settle` outbox exists; otherwise fail closed.
- Terminal success/failure CAS loses -> skip settlement/refund and do not enqueue a billing operation.
- Terminal success/failure CAS wins -> enqueue exactly one `terminal_settle` or `terminal_refund`, then process or leave retryable pending/failed outbox.
- Channel missing/cache error -> per-task CAS to failure; CAS winner refunds via outbox.
- Creative task has empty upstream id -> classify as null upstream and fail/refund; never poll provider with public task id.
- Creative task has empty selected key -> fail closed; never poll/fetch with current channel key.

### 5. Good/Base/Bad Cases

- Good: provider returns task id, backend inserts local `task_xxx`, completes scoped idempotency, enqueues `submit_settle`, processes it, then flushes public task id.
- Base: two pollers see terminal failure; one CAS wins, creates one refund outbox, concurrent outbox processing claims once, wallet/token/log are changed once.
- Bad: `Task.GetUpstreamTaskID()` fallback sends public `task_xxx` to provider for a Creative task with missing `PrivateData.UpstreamTaskID`.
- Bad: realtime fetch for a Creative Gemini/Vertex task with missing `PrivateData.Key` uses `channel.Key`.
- Bad: deleting idempotency after provider success but before local insert allows user retry to submit a second upstream task.

### 6. Tests Required

- Controller unit tests for idempotency-delete decision: delete only before provider accepted the task.
- Model tests for `UpdateWithStatusAndBillingOutbox`: only CAS winner creates the outbox.
- Service tests for outbox idempotency and concurrent processing: repeated/concurrent processing applies refund/settle once.
- Service polling tests for channel missing/cache error, null upstream classification, missing selected key fail-closed, and terminal CAS settle/refund once.
- Relay tests for realtime fetch key selection: Creative missing key/upstream id fails closed; Creative stored key works; legacy fallback remains explicit.
- Targeted validation command should include `controller`, `service`, `model`, `relay`, `relay/common`, and `relay/constant`.

### 7. Wrong vs Correct

#### Wrong

```text
provider accepted -> task.Insert fails -> DeleteCreativeVideoIdempotency -> retry submits provider again
Creative task UpstreamTaskID empty -> Task.GetUpstreamTaskID() returns public task_xxx -> provider poll
outbox pending processed by two workers -> both see FundingDone=false -> double refund
```

#### Correct

```text
provider accepted -> task.Insert fails -> keep idempotency guard -> retry sees still-preparing/conflict, no second submit
Creative task UpstreamTaskID empty -> null-task CAS failure -> terminal_refund outbox once
outbox pending -> atomic status claim to processing -> only claimer applies funding/token/log effects
```
