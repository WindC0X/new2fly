# v23c retry/resume lifecycle audit — main-session verification and repair

Date: 2026-06-24

## Inputs

Dynamic workflow runs:

- `.codex-flow/generated/creative-runtime-lifecycle-postfix-v23c-retry-resume-2026-06-24.workflow.ts`
- `.codex-flow/journal/creative-runtime-lifecycle-postfix-v23c-retry-resume-2026-06-24.jsonl`
- `.codex-flow/generated/creative-runtime-lifecycle-postfix-v23c-timeout-splits-2026-06-24.workflow.ts`
- `.codex-flow/journal/creative-runtime-lifecycle-postfix-v23c-timeout-splits-2026-06-24.jsonl`

The first workflow had timed-out/null branches. The split workflow completed all timed-out branches and synthesis. Workflow output was treated as untrusted until main-session source verification.

## Main-session verified findings

### Fixed in this slice

#### OTU-CREATIVE-RETRY-DUP-001 — HIGH — confirmed/fixed

Slow Creative image submit can outlive the browser's 60s submit timeout. The previous manual retry path marked the local task as failed/no-remoteId, incremented `retryAttempt`, and used `opentu-image-<taskId>-retry-1`, bypassing new-api same-key idempotency and allowing a duplicate backend/provider task.

Evidence checked:

- `opentu/packages/drawnix/src/constants/TASK_CONSTANTS.ts`
- `opentu/packages/drawnix/src/services/media-executor/fallback-adapter-routes.ts`
- `opentu/packages/drawnix/src/services/task-queue-service.ts`
- `new-api/controller/creative_image_tasks.go`
- `new-api/model/task.go`

Repair:

- Added `isRecoverableCreativeManagedImageSubmitFailure` for failed/no-remoteId `INTERRUPTED_DURING_SUBMISSION` Creative managed image tasks.
- `retryTask()` now replays that task through the submit-interrupted resume path without incrementing `retryAttempt`, preserving original `opentu-image-<taskId>` idempotency.
- Added regression test proving the retry request does not switch to `-retry-1`.

Files:

- `opentu/packages/drawnix/src/utils/task-utils.ts`
- `opentu/packages/drawnix/src/services/task-queue-service.ts`
- `opentu/packages/drawnix/src/services/__tests__/task-queue-service-image-retry.test.ts`

#### OTU-WORKFLOW-RESTORE-ID-001 — HIGH — confirmed/fixed

`workflowSubmissionService.recoverWorkflows()` returned running/pending workflows but emitted no `recovered` event; `useWorkflowSubmission` ignored the return value and only consumed `event.type === 'recovered'`. Refresh could therefore leave WorkZone/ChatDrawer without recovered task identity.

Repair:

- `recoverWorkflows()` now emits `recovered` for active persisted workflows and recently failed workflows while keeping the return value.
- Added regression test proving active persisted workflows from IndexedDB produce a `recovered` event containing the durable `step.result.taskId`.

Files:

- `opentu/packages/drawnix/src/services/workflow-submission-service.ts`
- `opentu/packages/drawnix/src/services/__tests__/workflow-submission-service-recovery.test.ts`

#### OTU-VIDEO-CS-RECOVERY-001 — HIGH — confirmed/fixed for the canvas/content-status parts

Video Cache Storage miss recovery had three confirmed sub-issues:

1. `Video` kept `videoError=true` after the canvas node URL changed to a recovered `_retry` URL.
2. Video miss events lacked board scope while the recovery hook accepts board-scoped events.
3. new-api video content returned HTTP 400 for incomplete tasks, but the frontend rehydrate retry classifier treats 409/425/429/5xx as retryable.

Repair:

- `Video` resets `videoError=false` and `isLoading=true` when `rawUrl` changes.
- `VideoItem` now carries optional `boardId`; canvas image plugin passes the current board id to the video component; generated video cache-miss events include `boardId`.
- `VideoProxy` returns HTTP 409 for incomplete task content, aligning with the frontend retryable content rehydrate statuses.

Files:

- `opentu/packages/drawnix/src/plugins/components/video.tsx`
- `opentu/packages/drawnix/src/plugins/components/image.tsx`
- `opentu/packages/drawnix/src/plugins/components/video.test.tsx`
- `new-api/controller/video_proxy.go`
- `new-api/controller/video_proxy_test.go`

#### v23c-generation-history-video-preview-fallback-gap — MEDIUM — confirmed/fixed

`useGenerationHistory()` used only `thumbnailUrl || thumbnailUrls[0]` for video history image thumbnails and ignored `previewImageUrl`, causing completed video history items to degrade to placeholders after refresh.

Repair:

- Added `previewImageUrl` as the final actual-image fallback for video history thumbnails.
- Added regression test.

Files:

- `opentu/packages/drawnix/src/hooks/useGenerationHistory.ts`
- `opentu/packages/drawnix/src/hooks/__tests__/useGenerationHistory.test.ts`

## Additional fixed finding

#### opentu-stale-001 — HIGH — confirmed/fixed for same-writer races

`TaskStorageWriter` guarded writes previously performed read/check/write without serializing same-task operations. Concurrent same-attempt terminal writes could both read `processing` and return true, allowing the later writer to overwrite the first terminal result.

Repair:

- Added a per-task write lock around guarded `updateStatus`, `updateProgress`, `completeTask`, `failTask`, and `updateRemoteId`.
- Added regression test proving concurrent `completeTask` then `failTask` returns `[true, false]` and preserves the first terminal `completed` result.

Files:

- `opentu/packages/drawnix/src/services/media-executor/task-storage-writer.ts`
- `opentu/packages/drawnix/src/services/__tests__/task-storage-writer.test.ts`

Note: this closes same-runtime/same-writer fallback races. A future IndexedDB transaction-level CAS can further harden cross-tab/multiple-writer races if that deployment shape becomes relevant.

#### V23C-NONIMG-001 — HIGH — video side confirmed/fixed; audio side remains residual

Main-session verification found the non-image durable-remoteId issue was not uniform:

- Video fallback execution routes call `onSubmitted` through `ExecutionOptions`, but the callback contract was previously synchronous and several video adapters continued polling immediately after invoking it.
- This could let a provider-accepted video task advance before the remote task id was durably written to local task storage.
- Audio still has a separate callback/polling implementation and remains listed under residual findings below.

Repair:

- `ExecutionOptions.onSubmitted` now supports `Promise<void>`.
- `executeVideoViaAdapter` awaits `updateStoredRemoteId(...)` inside its submitted callback before allowing adapter continuation.
- Video adapters now `await onSubmitted?.(...)` before continuing polling/progress.
- Regression coverage verifies the media executor does not continue until the submitted callback's durable-save promise resolves.

Files:

- `opentu/packages/drawnix/src/services/media-executor/types.ts`
- `opentu/packages/drawnix/src/services/media-executor/fallback-adapter-routes.ts`
- `opentu/packages/drawnix/src/services/model-adapters/flux-adapter.ts`
- `opentu/packages/drawnix/src/services/model-adapters/happyhorse-adapter.ts`
- `opentu/packages/drawnix/src/services/model-adapters/kling-adapter.ts`
- `opentu/packages/drawnix/src/services/model-adapters/seedance-adapter.ts`
- `opentu/packages/drawnix/src/services/video-api-service.ts`
- `opentu/packages/drawnix/src/services/__tests__/media-executor.test.ts`

## Verified residual findings not fixed in this slice

These are real or likely-real but need their own focused repair slice because they touch broader audio/video contracts.

1. `V23C-NONIMG-001` audio side — HIGH residual: audio provider `onSubmitted` / task-id persistence remains synchronous/fire-and-forget in `audio-api-service.ts` style paths. Needs async callback contract or durable barrier before polling/continuation.
2. `opentu-stale-002` / `V23C-NONIMG-003` — MEDIUM residual: audio progress/submitted/resume timeout paths have weaker stale-attempt and cancellation guarantees than image/video fallback paths.
3. `opentu-stale-003` — MEDIUM residual: specialized chat analyzer paths still bypass some execution-attempt guards.
4. `v23c-refresh-video-thumbnail-negative-cache` — MEDIUM residual: `useThumbnailUrl` can mark video thumbnail checks as recently done even when the original video blob was not yet in Cache Storage; needs a separate thumbnail retry/recovery slice.

## Validation run

OpenTU targeted Vitest:

```bash
pnpm vitest run --testTimeout=30000 --no-file-parallelism --maxWorkers=1 --minWorkers=1 \
  packages/drawnix/src/services/__tests__/task-queue-service-image-retry.test.ts \
  packages/drawnix/src/services/__tests__/workflow-submission-service-recovery.test.ts \
  packages/drawnix/src/plugins/components/video.test.tsx \
  packages/drawnix/src/hooks/__tests__/useGeneratedMediaCacheMissRecovery.test.tsx \
  packages/drawnix/src/hooks/__tests__/useGenerationHistory.test.ts
```

Result: PASS — 5 files / 42 tests.

TaskStorageWriter race regression:

```bash
pnpm vitest run --testTimeout=30000 --no-file-parallelism --maxWorkers=1 --minWorkers=1 \
  packages/drawnix/src/services/__tests__/task-storage-writer.test.ts
```

Result: PASS — 1 file / 8 tests.

Combined v23c lifecycle regression suite after the TaskStorageWriter and video durable-barrier repairs:

```bash
pnpm vitest run --testTimeout=30000 --no-file-parallelism --maxWorkers=1 --minWorkers=1 \
  packages/drawnix/src/services/__tests__/media-executor.test.ts \
  packages/drawnix/src/services/__tests__/task-storage-writer.test.ts \
  packages/drawnix/src/services/__tests__/task-queue-service-image-retry.test.ts \
  packages/drawnix/src/services/__tests__/workflow-submission-service-recovery.test.ts \
  packages/drawnix/src/plugins/components/video.test.tsx \
  packages/drawnix/src/hooks/__tests__/useGeneratedMediaCacheMissRecovery.test.tsx \
  packages/drawnix/src/hooks/__tests__/useGenerationHistory.test.ts
```

Result: PASS — 7 files / 82 tests.

OpenTU type gates:

```bash
pnpm exec tsc --noEmit --project packages/drawnix/tsconfig.spec.json --pretty false
pnpm nx run drawnix:typecheck
pnpm nx run web:typecheck
```

Result: PASS.

new-api controller tests:

```bash
go test -count=1 ./controller -run 'TestVideoProxyReturnsConflictForIncompleteTaskContent|TestCreativeRelayVideoContent|TestCreativeVideoContentPlatformAllowed|TestApplyVideoProxyCacheHeadersArePrivateByDefault|TestGetVertexTaskKey'
go test -count=1 ./controller
```

Result: PASS.

## Next required action

Run a focused residual repair slice for non-image remoteId durable barriers and audio stale/cancel paths, then run another dynamic workflow re-audit. Do not proceed to final goal audit or deployment claim while the residual HIGH item remains open.
