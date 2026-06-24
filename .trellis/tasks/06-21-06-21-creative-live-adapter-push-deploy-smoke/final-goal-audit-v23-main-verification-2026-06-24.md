# v23 OpenTU retry/storage/cache lifecycle post-fix workflow — main-session verification

Date: 2026-06-24
Scope: OpenTU runtime lifecycle after v22c/v22d fixes. This file records main-session verification of dynamic workflow outputs before accepting findings.

## Workflow status

- `creative-runtime-lifecycle-postfix-v23-opentu-retry-cache-2026-06-24.workflow.ts`: incomplete. Three branches timed out (`opentu-storage-attempt-identity`, `opentu-cache-miss-refresh-canvas`, `opentu-retry-resume-state-machine`); only `opentu-test-coverage-and-contracts` returned a material result. This run is not a valid final audit.
- `creative-runtime-lifecycle-postfix-v23a-storage-2026-06-24.workflow.ts`: storage split completed, but one branch (`storage-sync-restore`) was inconclusive and is not accepted as evidence. `writer-propagation` returned two material findings below.

## Findings arbitration

### WP-001 — accepted HIGH

Finding: resumed video callbacks can bypass the `expectedStartedAt`/`expectedRetryAttempt` guarded storage write.

Evidence verified in current code:

- `packages/drawnix/src/services/media-executor/fallback-executor.ts` `resumeVideoTask()` creates a write guard from `task.params` plus `task.startedAt`.
- The completion path calls `completeStoredTask(task.id, completionResult, writeGuard)`, but ignores whether the guarded write actually applied, then unconditionally calls `onTaskUpdate(task.id, TaskStatus.COMPLETED, ...)`.
- The failure path similarly calls guarded `taskStorageWriter.failTask(...)` and then unconditionally emits `onTaskUpdate(... FAILED ...)`.
- `TaskQueueService.retryTask()` and startup resume callbacks pass `onTaskUpdate` through to `taskQueueService.updateTaskStatus(...)`, which merges and persists without attempt guard.

Impact: an old resumed video poll can write stale completion/failure/progress into the current retry attempt after storage-level CAS rejects the stale write. This can revert user-visible state and persist an incorrect terminal result.

### WP-002 — accepted MEDIUM, scoped

Finding: not all status/progress storage writes are guarded by the execution attempt identity.

Evidence verified in current code:

- `taskStorageWriter.updateStatus(taskId, status)` has no guard parameter and can reopen terminal tasks or update a newer retry attempt.
- `resumeVideoTask()` no-callback progress path calls `updateStatus(task.id, PROCESSING)` and `updateProgress(task.id, mappedProgress)` without the `writeGuard`.
- `generateImage()`, `generateVideo()`, and `generateText()` start/progress writes call `updateStatus`/`updateProgress` without passing available `writeGuard`.
- `generateText()` specifically writes `updateProgress(taskId, 30, 'submitting')` without the available guard.

Scoped fix direction: make `taskStorageWriter` guarded write methods return a boolean, add guard support to `updateStatus`, pass the guard from executor paths where available, and suppress resumed video callbacks when the guarded durable write is skipped. Avoid broad state-machine rewrites in this slice.

## Coverage finding not yet accepted

`OTU-COV-001` from v23 is plausible but not yet fully main-session verified in this slice: embedded E2E coverage appears to lack a submit-interrupted/no-remoteId refresh recovery case. It remains pending for the next workflow/test-coverage slice.

## RED verification performed before implementation

Command:

```bash
cd /mnt/f/code/project/opentu
pnpm vitest run --no-file-parallelism --maxWorkers=1 --minWorkers=1 \
  packages/drawnix/src/services/__tests__/task-storage-writer.test.ts \
  packages/drawnix/src/services/__tests__/media-executor.test.ts
```

Observed expected failures before production code changes:

- `taskStorageWriter.updateStatus(...)` returned `undefined` instead of boolean false/true and did not enforce guards.
- resumed video completion callback still fired after mocked guarded `completeTask` returned false.
- no-callback resumed video progress called `updateStatus` without the expected guard.

Also observed one test-pollution failure because the new fallback-utils mock was not yet unmocked between tests; this is a test hygiene issue to fix with the implementation.

## Fix verification update

The accepted `WP-001`/`WP-002` findings were repaired in the OpenTU working tree.

Fresh verification after the fix:

- Targeted `task-storage-writer.test.ts` + `media-executor.test.ts`: PASS, 39 tests.
- `tsconfig.spec.json --noEmit`: PASS.
- `task-queue-service-image-retry.test.ts`: PASS, 25 tests.
- Split broader lifecycle/cache/canvas suite excluding task-queue file: PASS, 78 tests.
- `pnpm nx run drawnix:typecheck`: PASS.
- `pnpm nx run web:typecheck`: PASS.

The remaining workflow work is not complete: v23b cache/canvas and v23c retry/resume state-machine splits still need to run, followed by synthesis/verifier and main-session arbitration.
