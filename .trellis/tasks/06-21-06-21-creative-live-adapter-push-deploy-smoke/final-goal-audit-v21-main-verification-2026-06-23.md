# v21 final-goal audit — main-session verification

Date: 2026-06-23
Scope: Verify dynamic-workflow v21 synthesis findings against current local code before accepting them as repair work.

## Method

- Loaded Trellis task artifacts and project specs before code changes.
- Used `fast-context` and `codegraph` first to locate cross-file task lifecycle paths, then targeted `rg`/line reads for exact evidence.
- Findings below are main-session verdicts, not blindly accepted workflow output.

## Findings verdicts

### OTU-ABORT-001 — ACCEPTED — HIGH

**Symptom:** A managed Creative image task can be accepted by the backend/provider and have `remoteId` persisted, but a browser-side `AbortError` during later poll/content materialization is treated as terminal `IMAGE_GENERATION_ERROR`.

**Evidence:**

- `packages/drawnix/src/services/media-executor/fallback-adapter-routes.ts`
  - `executeCreativeManagedImageTask()` persists remote identity via `updateStoredRemoteId(...)` after submit.
  - `pollCreativeManagedImageTask()` and `downloadCreativeImageTaskContent()` rethrow `AbortError` / aborted signal.
  - The outer catch currently maps non-timeout/non-submit-interrupted errors to `IMAGE_GENERATION_ERROR` and calls `failStoredTask(...)`.
- `packages/drawnix/src/services/task-queue-service.ts` already has resumable handling for `TIMEOUT` + managed image + `remoteId`; the adapter route needs to preserve that resumable contract instead of persisting a terminal failure.

**Root cause:** abort after remote acceptance is not distinguished from pre-acceptance submit interruption or ordinary provider failure.

**Fix direction:** Once a remote task id has been persisted, local abort should leave the task in `processing/polling` (or throw a timeout-like recoverable error) and must not call `failStoredTask()`.

**Verification case:** Accepted remote id + aborted content/status fetch => `updateRemoteId` called, `failTask` not called, progress remains recoverable/polling, thrown error is recoverable for queue-level resume.

### OTU-SYNC-001 — ACCEPTED — HIGH

**Symptom:** A stale storage update from an older execution attempt can overwrite a newer retry in memory.

**Evidence:**

- `packages/drawnix/src/services/task-queue-service.ts`
  - Existing execution writebacks use `getExecutionAttemptSnapshot()` / `shouldSkipExecutionAttemptWriteback()` to guard by `retryAttempt` + `startedAt`.
  - `retryTask()` increments `params.retryAttempt`, resets `remoteId`, and sets a new `startedAt` for fresh retries.
  - `syncTaskFromStorage(taskId, storageTask)` directly merges storage fields into the current memory task without checking `storageTask.params.retryAttempt` or `storageTask.startedAt` against the current attempt.
- Callers: `image-generation-service.ts` and `video-generation-service.ts` pass task records read from IndexedDB through `syncTaskFromStorage(...)` while async executor/storage writes may still be unwinding.

**Root cause:** direct storage-to-memory sync bypasses the same late-write attempt guard used by task executor writebacks.

**Fix direction:** Skip sync when storage task carries an older/different `retryAttempt` or `startedAt` than the current in-memory attempt.

**Verification case:** current task is retryAttempt=1/startedAt=new; stale storage task retryAttempt=0/startedAt=old/status=completed/remoteId=old must not update memory or emit taskUpdated.

### OTU-IDEMP-001 — ACCEPTED — MEDIUM

**Symptom:** Fresh managed-image retries reuse the default `opentu-image-${taskId}` idempotency key, allowing the backend to deduplicate the retry to the previous backend task.

**Evidence:**

- `fallback-adapter-routes.ts` has `createCreativeImageTaskIdempotencyKey(taskId, retryAttempt)` that already supports `-retry-N`.
- `executeCreativeManagedImageTask()` currently computes `params.idempotencyKey || createCreativeImageTaskIdempotencyKey(taskId)` and ignores `params.retryAttempt`.
- `fallback-executor.ts` passes `params.retryAttempt` into `executeCreativeManagedImageTask()`.
- `task-queue-service.ts` fresh retry increments `params.retryAttempt`; submit-interrupted resume does not increment and should continue using the original key.

**Root cause:** helper supports retry-aware keys but the managed Creative route does not pass the retry attempt.

**Fix direction:** Use `createCreativeImageTaskIdempotencyKey(taskId, params.retryAttempt)` when caller did not provide an explicit idempotency key.

**Verification case:** retryAttempt=2 submits with `Idempotency-Key: opentu-image-<taskId>-retry-2`; no retryAttempt still submits original key.

### OTU-CACHE-001 — ACCEPTED — MEDIUM

**Symptom:** Canvas/manual insertion cache-readiness only attempts rehydrate once. If provider reports completed but same-origin content endpoint is still warming up, preview UI can recover via `RetryImage`, but canvas insertion can fail permanently.

**Evidence:**

- `packages/drawnix/src/utils/generated-media-cache.ts`
  - `ensureGeneratedImageCacheUrlReady()` performs one `unifiedCacheService.getCachedBlob(...)` then one `rehydrateGeneratedImageCacheUrl(...)` call.
  - `ensureGeneratedImageUrlsReadyForCanvas()` maps all URLs through that single-attempt path.
- `packages/drawnix/src/components/retry-image.tsx` explicitly retries rehydrate across later image-load attempts; canvas/insert path lacks an equivalent bounded retry.

**Root cause:** preview and canvas readiness paths have divergent slow-content recovery semantics.

**Fix direction:** Add bounded retry for generated image content rehydrate/fetch in the shared cache readiness utility so canvas/manual insertion uses the same slow-content tolerance without depending on image element retries.

**Verification case:** cache miss + content endpoint returns transient 503/network failure twice then image blob => ensure-ready succeeds, caches blob, and returns decoded dimensions.

### OTU-VIDEO-001 — REJECTED / already covered by current code

**Workflow claim:** refresh recovery can set failed remote video task to `processing`, but executor path does not restart polling.

**Main-session evidence:**

- `useTaskStorage()` marks recoverable failed remote tasks as `processing`/`polling`.
- `DrawnixDeferredRuntime` waits for `isTaskStorageReady`, then calls `fallbackMediaExecutor.resumePendingTasks(..., taskQueueService.getAllTasks())` from memory, which includes tasks just recovered by `useTaskStorage`.
- `fallback-executor.ts` `resumePendingTasks()` filters processing video tasks with `remoteId` and calls `resumeVideoTask()`.
- `task-queue-service.ts` manual retry for failed remote video tasks also explicitly calls `fallbackMediaExecutor.resumePendingTasks(..., [resumedTask])`.

**Verdict:** The branch was incomplete because it inspected `useTaskExecutor()` skip behavior but missed the deferred runtime resume path. No code fix accepted from this finding at this time.

**Residual risk:** The deferred resume is idle-delayed; if future UX requires immediate visible polling after refresh, that is an enhancement, not the claimed missing resume bug.

### REL-PROV-001 — ACCEPTED — HIGH (process/release readiness)

**Evidence:** `git status --short` on 2026-06-23 shows dirty worktrees in `new2fly`, `opentu`, and `new-api`, including source changes, generated Creative dist changes, and new task/audit artifacts.

**Impact:** Current candidate provenance is not clean/immutable. Do not claim release-ready or pushed provenance until changes are committed/pushed or explicitly documented as local-only.

### REL-GATE-001 — ACCEPTED — MEDIUM (process/release gate)

**Evidence:** Prior local `creative_release_gate.py` runs can pass in a dirty checkout; the gate is artifact/build/smoke oriented and is not a complete clean-worktree/provenance gate.

**Impact:** Passing release gate is necessary but not sufficient for release readiness.

**Fix direction:** Either extend the gate with a clean/provenance mode or keep release reports explicitly separating local dirty verification from release candidate verification.

### REL-STAGE-001 — ACCEPTED — HIGH (deployment status)

**Evidence:** Latest v20/v21 dirty candidate has local test/gate/E2E evidence in task notes, but no fresh staging/production deployment evidence for the newest post-v20 candidate.

**Impact:** Do not call staging/prod ready until the candidate is deployed to staging and smoked there, or explicitly label it local-only.

## Accepted repair queue

1. `OTU-ABORT-001` — TDD regression + adapter route fix.
2. `OTU-SYNC-001` — TDD regression + storage sync attempt guard.
3. `OTU-IDEMP-001` — TDD regression + retry-aware managed idempotency key.
4. `OTU-CACHE-001` — TDD regression + bounded shared rehydrate retry.
5. Release/process findings — document status now; do not solve by hiding dirty state. A provenance gate improvement can be added after runtime repairs if needed.

## Rejected / no-fix

- `OTU-VIDEO-001` rejected as stated; current code has a refresh resume path via `DrawnixDeferredRuntime -> fallbackMediaExecutor.resumePendingTasks`.
