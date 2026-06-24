# Runtime lifecycle v9/v9b/v9c main-session verification

Date: 2026-06-22

## Workflow status

- v9 broad workflow: incomplete. Four key branches timed out and synthesis failed; not accepted as final audit.
- v9b targeted continuation: six branches completed, synthesis failed.
- v9c synthesis-only: completed.
- Main-session verification used fast-context + codegraph health checks, then exact source inspection with `rg`/`nl`/`sed`.

## Verified blocker findings

### CONFIRMED HIGH — backend submit has an empty-upstream race before provider acceptance

Evidence:
- `new-api/controller/creative_image_tasks.go:301-344` persists a Creative image task as `SUBMITTED` with empty `PrivateData.UpstreamTaskID`, then calls provider submit.
- `new-api/model/task.go:417-425` returns all unfinished tasks, including `SUBMITTED` with `progress != 100%`.
- `new-api/service/task_polling.go:156-178` buckets any non-ambiguous task with empty upstream id into `nullTasks`.
- `new-api/service/task_polling.go:137-145` marks those `nullTasks` failed/refunded.

Impact: if provider submit is slow for > one polling interval, polling can fail/refund the durable task before the submit handler receives upstream id. The provider job can become orphaned, and frontend sees a failed task.

Decision: confirmed. Must fix with a submit-in-flight guard/grace state before provider call and polling/reconcile awareness.

### CONFIRMED HIGH / DESIGN GAP — ambiguous submit late accepted provider task is unrecoverable

Evidence:
- `new-api/service/creative_image_adapter.go:524-553` classifies timeout/context-cancel submit transport errors as ambiguous.
- `new-api/controller/creative_image_tasks.go:353-367` marks `ProviderSubmitAmbiguous` but has no upstream id.
- `new-api/controller/creative_image_tasks.go:725-731` and `new-api/service/task_polling.go:163-171,306-321` only wait until ambiguous timeout, then fail/refund.

Impact: if provider accepted the job but the initial response was lost, backend has no upstream id and cannot materialize success.

Decision: confirmed as unresolved design gap. Do not blindly resubmit. Need provider correlation/idempotency lookup or explicit recovery-needed UX/billing state.

### CONFIRMED HIGH — frontend timeout is terminal while backend may still complete

Evidence:
- `opentu/packages/drawnix/src/constants/TASK_CONSTANTS.ts:14-18` sets Creative remote image frontend timeout to 90 minutes.
- `opentu/packages/drawnix/src/utils/task-utils.ts:109-120` makes that timeout terminal for processing resumable image tasks.
- `opentu/packages/drawnix/src/hooks/useTaskExecutor.ts:282-304,416-472,824-837` writes `FAILED/TIMEOUT` and aborts managed resume.
- `opentu/packages/drawnix/src/hooks/useTaskStorage.ts:165-192` only recovers `INTERRUPTED`, `INTERRUPTED_DURING_SUBMISSION`, `RESUME_FAILED`; it skips `TIMEOUT`.
- `new-api/common/init.go:155-156` defaults backend task timeout to 1440 minutes.

Impact: backend can still reconcile success after frontend has permanently marked failed. This breaks slow-provider lifecycle.

Decision: confirmed. Must fix by making Creative remote image timeout recoverable/non-terminal or aligning backend/frontend SLA.

### CONFIRMED HIGH — generated image rehydrate identity is not end-to-end durable

Evidence:
- Cache miss event carries only taskId/elementId/imageUrl: `opentu/packages/drawnix/src/utils/asset-cleanup.ts:86-101`.
- Recovery only finds task records and ignores canvas node metadata: `opentu/packages/drawnix/src/hooks/useGeneratedMediaCacheMissRecovery.ts:186-203`.
- Single-image canvas insert writes metadata: `opentu/packages/drawnix/src/services/canvas-operations/canvas-insertion.ts:143-158`.
- Multi-image insert lacks metadata parameter: `canvas-insertion.ts:552-568`.
- `useAutoInsertToCanvas.ts:792-809` builds image metadata but frame/PPT and multi-image paths drop it at `869-876`, `915-924`, `999-1003`, `1353-1369`, `1402-1409`.
- GenerationHistory maps only `imageUrl/width/height`: `opentu/packages/drawnix/src/hooks/useGenerationHistory.ts:27-39`; component renders `RetryImage` without rehydrate props at `generation-history.tsx:75-82`.
- Media cache call stores `taskId/model` outside `metadata`; `unified-cache-service.ts:1231-1311` persists only `normalizedOptions.metadata`.

Impact: after browser refresh or Cache Storage eviction, canvas/history/dock can still show broken or empty generated images if task records are missing or insertion path dropped metadata.

Decision: confirmed. Must fix the durable metadata contract across cache miss, multi/frame/manual/history paths.

### CONFIRMED HIGH — image-generation anchor errors bypass sanitizer

Evidence:
- `opentu/packages/drawnix/src/hooks/useImageGenerationAnchorSync.ts:94-108` picks raw post-processing error, task error message, originalError, or anchor.error.
- `image-generation-anchor-view-model.ts:430-445` passes `anchor.error` through.
- `ImageGenerationAnchorContent.tsx:197-200` renders it directly.
- TaskItem already sanitizes: `TaskItem.tsx:477-485`.

Impact: failed canvas anchor may leak signed URLs/callback/provider metadata/raw payload fragments even though task list is sanitized.

Decision: confirmed. Must sanitize anchor error before persistence/rendering.

## Verified should-fix findings

### CONFIRMED MEDIUM — TaskItem memo comparator is too narrow

Evidence:
- Comparator only checks id/status/progress/error/result ref and UI flags: `TaskItem.tsx:225-241`.
- Render depends on `remoteId`, `params`, `result.contentUrl`, dimensions, `cacheWarning`, etc.: `TaskItem.tsx:356-603`.

Decision: confirmed. Fix by removing custom comparator or broadening to task identity/version. Prefer removal for correctness unless profiling proves need.

### CONFIRMED MEDIUM — provider poll errors are under-classified

Evidence:
- `creativeImageProviderJSON` returns generic `creative image provider returned status N` for any non-2xx: `new-api/service/creative_image_adapter.go:536-538`.
- Poll/reconcile only treats `CreativeImageProviderTerminalError` as terminal; other errors stay transient: `controller/creative_image_tasks.go:755-760`, `service/task_polling.go:410-417`.

Decision: confirmed. Should fix with typed classification, but after the lifecycle blockers unless tests show small safe scope.

### CONFIRMED MEDIUM — provider binding builder/schema drift

Evidence:
- `grsai_nano_banana` manifest exposes `1:4/4:1/1:8/8:1`: `new-api/service/creative_model_capability.go:553-595`.
- Validation only allows those for `nano-banana-2*`: `creative_model_capability.go:2028-2078`.
- UI copies template schema directly: `creative-model-bindings-section.tsx:646-660`.
- Backend supports channel model mapping: `creative_model_capability.go:1590-1642`; UI blocks if `providerModelId` is not directly in channel models: `creative-model-bindings-section.tsx:630-640,893-901`.

Decision: confirmed. Should fix after core runtime blockers; it affects admin config ergonomics and future adapters.

## Rejected / narrowed

- Retry/stale-write protection is not currently a blocker. Source shows retry clears remote state and writes are guarded by retryAttempt/startAt/remoteId.
- Same-origin content relay and normal materialize happy path were not shown to be current blockers by v9/v9b/v9c.
- Live-provider behavior remains unverified; all slow-provider conclusions are source/mock-scenario based.
