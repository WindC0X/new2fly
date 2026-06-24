# Final Goal Audit v22 — Main-Session Verification

Date: 2026-06-23
Scope: verify material finding emitted by `creative-final-goal-audit-v22-postfix-2026-06-23` before accepting it as a defect.

## Workflow state

- Workflow file: `.codex-flow/generated/creative-final-goal-audit-v22-postfix-2026-06-23.workflow.ts`
- Journal: `.codex-flow/journal/creative-final-goal-audit-v22-postfix-2026-06-23.jsonl`
- First run status: only `opentu-managed-image-runtime` returned a useful branch; four other branches returned timeout/null.
- Synthesis verdict: `blocked`.
- Verifier verdict: `needs_rerun`.
- Consequence: v22 is **not** a completed final audit. The four null branches must be rerun in smaller workflows.

## Finding RLC-FINAL-001

Verdict: **ACCEPTED — HIGH**

Claim: Creative live image submit binds provider submission to the browser request context. If the provider has accepted the job but the browser/client request is canceled or times out before the upstream id is read locally, the durable task row is left without `PrivateData.UpstreamTaskID`; polling and GET reconciliation then intentionally skip it until the ambiguous-submit timeout, after which it is failed/refunded. The upstream job can still complete, but new-api has no id with which to recover it.

### Main-session evidence

Checked with `fast-context` and `codegraph` for relevant files, then verified exact line ranges in current `new-api` source.

1. `controller/creative_image_tasks.go`
   - Lines 303-346 create and persist a durable Creative image task row before provider submit, with `ProviderSubmitInFlight=true` but no upstream id yet.
   - Line 348 calls `service.SubmitCreativeImageProviderTask(c.Request.Context(), ...)`, so provider submission inherits the browser request cancellation/deadline.
   - Lines 357-370 handle ambiguous submit errors by calling `creativeMarkImageTaskSubmitAmbiguous(...)` and returning `202`, but no upstream id is available or persisted.
   - Lines 414-417 persist `UpstreamTaskID` only on the normal provider-result path.
   - Lines 731-743 in GET reconciliation return nil for missing upstream id while `ProviderSubmitInFlight`/`ProviderSubmitAmbiguous` is fresh, and fail only after timeout; no correlation recovery is attempted.
   - Lines 874-905 `creativeMarkImageTaskSubmitAmbiguous` explicitly clears `ProviderSubmitInFlight`, sets `ProviderSubmitAmbiguous=true`, and persists `private_data`; it does not have an upstream id to store.

2. `service/creative_image_adapter.go`
   - Lines 514-524 build and execute the provider HTTP request with the caller-provided context.
   - Lines 525-528 convert context-canceled / timed-out provider transport errors into `errCreativeImageProviderTransportAmbiguous`.
   - Lines 542-553 mark any non-nil `ctx.Err()` / `context.Canceled` / `context.DeadlineExceeded` / network timeout as ambiguous.

3. `service/task_polling.go`
   - Lines 169-177 skip ambiguous Creative image tasks when `pollingUpstreamTaskID(task)` is empty.
   - Lines 345-360 expire ambiguous submits after `creativeImageAmbiguousSubmitTimeoutSeconds`.
   - Lines 148-150 fail/refund expired ambiguous tasks with `creative image provider submit timed out before returning a task id`.

4. Existing tests confirm current intended-but-defective behavior:
   - `controller/creative_test.go:2349-2464` (`TestCreativeImageTaskSubmitLiveTimeoutStaysPendingAndReplaysTask`) simulates a slow provider returning `{"id":"dm-late-accepted"...}` after local timeout. The assertions require `PrivateData.UpstreamTaskID` to be empty, `ProviderSubmitAmbiguous=true`, replay to return the same public task, and GET to remain `in_progress` without another provider call.
   - `service/task_polling_affinity_test.go:652-684` verifies ambiguous tasks with no upstream id are skipped until timeout and then expired.

### Impact

- User sees a pending task that can later become failed/refunded even though the provider may have accepted and completed it.
- new-api loses the only recovery key (`UpstreamTaskID`), so late success cannot be polled or materialized.
- Retry/idempotency replay is safe from duplicate submit, but it cannot recover the accepted upstream job.

### Required fix direction

- Detach provider submission from browser cancellation after the durable task row is created, while keeping a bounded submit timeout.
- Persist `UpstreamTaskID` as soon as provider accepted response is available.
- Preserve idempotency replay semantics and billing outbox invariants.
- Add a RED regression test where request context is canceled while provider still returns an accepted id; expected result is durable `UpstreamTaskID` plus subsequent polling/reconciliation ability, not an ambiguous no-id task.

## Pending v22 work

Rerun remaining null branches in smaller workflows before calling v22 final audit complete:

1. `opentu-task-refresh-cache-canvas`
2. `newapi-backend-admin-binding`
3. `embedded-release-provenance-security`
4. `goal-attainment-cross-layer-state-machine`
