# Creative Runtime Lifecycle Repair Implementation Plan

> **For agentic workers:** REQUIRED EXECUTION MODE: implement through Trellis `trellis-implement` sub-agents, then verify through `trellis-check` sub-agents. Main session coordinates scope, reviews outputs, updates specs, commits, and finishes. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Close the Creative image runtime lifecycle gaps found on 2026-06-22: slow provider recovery, durable remote identity, retry semantics, Cache Storage lifecycle, canvas image-load success, failure reasons, dimensions, provider contracts, viewport refresh, and insertion-state consistency.

**Architecture:** Treat generated Creative media as an async state machine, not a synchronous UI action. The durable identity is the NewAPI public task id (`remoteId` in OpenTU), the durable result is `contentUrl + cacheUrl + dimensions + failure reason`, and UI success is not complete until cached media is load-verified. Retry is split into resume-existing vs regenerate-new-attempt.

**Tech Stack:** NewAPI Go/Gin/Gorm task relay + billing outbox; OpenTU TypeScript/React/Vitest + IndexedDB task storage + Service Worker/Cache Storage + Plait canvas.

---

## 0. Problem Inventory And Deduplication

| Group | Covers | Severity | Primary repos |
|---|---|---:|---|
| A. Durable async identity/backend task lifecycle | accepted-before-durable window, idempotency replay, status/content rate-limit, FailReason/DTO, target dimensions | P1 | `new-api` |
| B. OpenTU managed image executor | 120s timeout, missing `remoteId`, resume after refresh, retry key reuse, failure reason display | P1 | `opentu` |
| C. Cache/canvas display lifecycle | `/__aitu_cache__` non-durable URL, cache miss deletion, blank node, anchor completed too early, dock thumbnail split | P1 | `opentu` |
| D. Dimensions/result metadata | provider target resolution one-way only, natural dimensions absent, 21:9/small-strip display | P2 | both |
| E. Provider binding contracts | Nano Banana allowed-values and dry-run/live parity; Duomi/GrsAI target pixels recorded | P2 | `new-api` |
| F. Viewport/cloud refresh and minor insertion-state split | viewport resets; DialogTaskList missing markAsInserted | P2 | `opentu` |

Do not start with production deploy. Fix and validate locally/staging first.

---

## 1. Target State Machine

```text
OpenTU create local task
  -> POST NewAPI /creative/relay/v1/images/tasks with attempt-scoped Idempotency-Key
  -> NewAPI creates/updates durable task before or immediately around provider submit
  -> provider accepted returns upstream id
  -> NewAPI public task id is returned as OpenTU remoteId
  -> OpenTU persists remoteId + invocationRoute + attempt before polling
  -> polling may outlast 120s and remains resumable until image timeout/TTL
  -> status success returns contentUrl, target dims, failReason when failed
  -> OpenTU downloads content, writes Cache Storage, decodes natural dimensions
  -> task.result stores cacheUrl + contentUrl + remoteId + width/height + mimeType
  -> canvas inserts placeholder but marks postProcessing complete only after load/decode verified
  -> task history/dock/canvas can rehydrate cache from contentUrl after refresh
  -> Retry action chooses either resume existing remoteId or regenerate with retryAttempt+1
```

Definitions:

- **resume**: do not POST a new provider task. Continue GET `/images/tasks/:remoteId` and content download.
- **regenerate**: create a new provider request with a new idempotency key. Reuse the same local task only if `retryAttempt` increments and old `remoteId/result/cacheUrl` are cleared.
- **cache miss**: not a terminal success. It must rehydrate from `contentUrl` or mark postProcessing failed/retryable. It must not silently delete user canvas content.

---

## 2. File Map

### NewAPI

- Modify: `/mnt/f/code/project/new-api/controller/creative_image_tasks.go`
  - DTO fields: `fail_reason`, `error`, `result.width`, `result.height`, `result.targetWidth`, `result.targetHeight`, `result.contentUrl`.
  - Live submit durability order and idempotency completion behavior.
  - Status/content error taxonomy and safe fail reason propagation.
- Modify: `/mnt/f/code/project/new-api/service/creative_image_adapter.go`
  - Provider result target dimension metadata.
  - Temporary vs terminal provider error classification.
  - Duomi/GrsAI response parsing still redacts secrets.
- Modify: `/mnt/f/code/project/new-api/service/creative_model_capability.go`
  - Nano Banana allowed-values and dry-run/live parity validation.
  - Target-pixel metadata for parameter templates.
- Modify: `/mnt/f/code/project/new-api/router/web-router.go` and/or middleware route guards
  - Exempt `GET /creative/relay/v1/images/tasks/:id` and `/content` from model-submit rate limit while keeping auth/session checks.
- Test: `/mnt/f/code/project/new-api/controller/creative_test.go`
- Test: `/mnt/f/code/project/new-api/service/creative_image_adapter_test.go`
- Test: `/mnt/f/code/project/new-api/service/creative_model_capability_test.go`
- Test: `/mnt/f/code/project/new-api/router/web_router_test.go`

### OpenTU

- Modify: `/mnt/f/code/project/opentu/packages/drawnix/src/services/media-executor/fallback-adapter-routes.ts`
  - Typed DTO additions.
  - Persist `remoteId` immediately after submit.
  - Attempt-scoped idempotency key.
  - Backoff/timeout based on `TASK_TIMEOUT.IMAGE`, not hard-coded 120 seconds.
  - Resume helper for managed image tasks.
  - Content download stores `contentUrl`, `remoteTaskId`, `mimeType`, natural width/height.
- Modify: `/mnt/f/code/project/opentu/packages/drawnix/src/services/media-executor/task-storage-writer.ts`
  - Add safe helpers for `updateRemoteId`, `resetForRegenerate`, `markRenderFailed`, and result metadata updates if not already enough.
- Modify: `/mnt/f/code/project/opentu/packages/drawnix/src/services/task-queue-service.ts`
  - Retry increments `retryAttempt` for regenerate.
  - Preserve a separate resume path for processing tasks with `remoteId`.
  - Failure reason display uses backend-safe message.
- Modify: `/mnt/f/code/project/opentu/packages/drawnix/src/utils/task-utils.ts`
  - `isResumableAsyncImageTask` recognizes Creative managed image tasks with `remoteId`.
- Modify: `/mnt/f/code/project/opentu/packages/drawnix/src/hooks/useTaskExecutor.ts`
  - Resume Creative managed image tasks through NewAPI task status/content, not OpenAI async image polling.
- Modify: `/mnt/f/code/project/opentu/packages/drawnix/src/hooks/useAutoInsertToCanvas.ts`
  - Do not call `completePostProcessing` or `markAsInserted` until image cache/decode verification succeeds.
  - On load/cache failure call `failPostProcessing` and keep anchor retryable.
- Modify: `/mnt/f/code/project/opentu/packages/drawnix/src/data/image.ts`
  - Keep placeholder insertion but expose or reuse an image-load verification helper.
  - Natural dimensions must update final element size unless target frame intentionally locks it.
- Modify: `/mnt/f/code/project/opentu/packages/drawnix/src/utils/asset-cleanup.ts`
  - Stop silent deletion for generated media cache misses.
  - Report render/cache failure to task/postProcessing; support nested/frame elements if deletion remains needed for non-generated stale assets.
- Modify: `/mnt/f/code/project/opentu/apps/web/src/sw/index.ts`
  - Cache miss response remains safe, but task/UI rehydrate path must be able to recover from it.
- Modify: `/mnt/f/code/project/opentu/packages/drawnix/src/components/task-queue/DialogTaskList.tsx`
  - Call `markAsInserted(taskId, 'manual')` after successful insert.
- Modify: thumbnail/dock consumers after exact location confirmation, likely:
  - `/mnt/f/code/project/opentu/packages/drawnix/src/components/content-preview/SelectedContentPreview.tsx` or equivalent selected preview component.
  - Task history item components under `components/task-queue/`.
- Modify: viewport/cloud sync after focused confirmation:
  - `/mnt/f/code/project/opentu/packages/drawnix/src/app.tsx`
  - `/mnt/f/code/project/opentu/packages/drawnix/src/services/creative-document-sync.ts`

### Tests / smoke

- Test: `/mnt/f/code/project/opentu/packages/drawnix/src/services/__tests__/media-executor.test.ts`
- Test: `/mnt/f/code/project/opentu/packages/drawnix/src/services/__tests__/task-queue-service-image-retry.test.ts`
- Test: `/mnt/f/code/project/opentu/packages/drawnix/src/hooks/__tests__/useAutoInsertToCanvas.test.ts`
- Test: `/mnt/f/code/project/opentu/packages/drawnix/src/utils/__tests__/task-utils.test.ts`
- Add focused tests for cache miss/render failure and DialogTaskList if no existing file fits.
- Browser smoke after code passes: local/staging only, fake/controlled provider first.

---

## 3. Implementation Tasks

### Task 1: Add failing backend contract tests first

**Files:**
- Modify: `/mnt/f/code/project/new-api/controller/creative_test.go`
- Modify: `/mnt/f/code/project/new-api/service/creative_image_adapter_test.go`
- Modify: `/mnt/f/code/project/new-api/service/creative_model_capability_test.go`
- Modify: `/mnt/f/code/project/new-api/router/web_router_test.go`

- [ ] Add a controller test proving image task DTO includes safe failure reason and result metadata.
  - Arrange a `constant.TaskPlatformCreativeImage` task with `FailReason: "provider rejected prompt"`, `Status: failure`, and creative metadata.
  - Assert JSON contains `fail_reason` or equivalent safe field.
  - Arrange success task with target dimensions in metadata/result.
  - Assert result contains `url`, `mimeType`, and dimension metadata.

- [ ] Add an idempotency test for replay semantics.
  - First request with `Idempotency-Key: opentu-image-task-1` returns a task id.
  - Same key + same payload returns same task id.
  - Different retry key `opentu-image-task-1-retry-1` creates/accepts a separate attempt instead of replaying old terminal failure.

- [ ] Add a route/middleware test proving status/content GET is not counted as model-submit rate limit.
  - Configure `ModelRequestRateLimitCount = 0` / strict limit.
  - POST `/creative/relay/v1/chat/completions` or image submit should still be rate-limited.
  - GET `/creative/relay/v1/images/tasks/:id` and `/content` should pass auth/ownership and not fail due to submit rate limit.

- [ ] Add provider contract tests.
  - Duomi 21:9 + 1K maps to documented `1792x768` target.
  - GrsAI `gpt-image-2-vip` 21:9 + 4K maps to `3840x1648` target.
  - Nano Banana rejects unsupported allowed values and dry-run/live omit or include `auto` consistently.

- [ ] Run expected failing tests.

```bash
cd /mnt/f/code/project/new-api
go test -count=1 ./controller ./service ./router -run 'Creative.*Image|Creative.*Rate|Creative.*Model|ImageProvider'
```

Expected before implementation: one or more tests fail because DTO/rate-limit/Nano contract/dim metadata are incomplete.

---

### Task 2: Harden NewAPI image task lifecycle and DTO

**Files:**
- Modify: `/mnt/f/code/project/new-api/controller/creative_image_tasks.go`
- Modify: `/mnt/f/code/project/new-api/service/creative_image_adapter.go`
- Modify: `/mnt/f/code/project/new-api/service/creative_model_capability.go`
- Modify: `/mnt/f/code/project/new-api/router/web-router.go`

- [ ] Extend `creativeImageTaskMetadata` / public metadata with target dimensions.
  - Fields should be non-secret and safe: `TargetWidth`, `TargetHeight`, `TargetAspectRatio`, `TargetResolution`.
  - Never expose provider key, base URL, signed URL, upstream raw response, or channel secret.

- [ ] Extend `creativeImageTaskDTO`.
  - Add `FailReason string json:"fail_reason,omitempty"`.
  - Add `Error map[string]any json:"error,omitempty"` for failed terminal tasks if frontend expects OpenAI-style error.
  - Add result keys only when known: `contentUrl`, `mimeType`, `targetWidth`, `targetHeight`.
  - Keep `result.url` as broker content URL, not upstream signed URL.

- [ ] Change DTO builder rules.
  - Success: `result.url = /creative/relay/v1/images/tasks/:id/content`.
  - Failure: include sanitized `fail_reason`; do not include signed URL or provider raw body.
  - In-progress: include progress and public metadata only.

- [ ] Reduce accepted-before-durable risk.
  - Preferred approach: create a durable NewAPI task row in submitted/processing state before provider submit once billing preconsume succeeds and `publicTaskID` is known.
  - If provider submit fails, transition that task to failure and enqueue/refund billing outbox.
  - If provider accepts, update same task with `PrivateData.UpstreamTaskID`, `ResultURL`, status/progress, and complete idempotency record.
  - Do not complete idempotency to an absent task.

- [ ] Exempt only status/content GET from model-submit rate limit.
  - Auth/session/ownership/nonce behavior must remain unchanged.
  - Do not exempt POST submit, chat, images/generations, videos, or Suno submit.

- [ ] Normalize temporary/terminal provider errors.
  - Terminal malformed success -> failure/refund with safe reason.
  - Temporary provider 429/5xx during poll should not immediately convert to terminal failure unless provider contract says terminal.

- [ ] Run backend tests.

```bash
cd /mnt/f/code/project/new-api
go test -count=1 ./controller ./service ./router ./model ./relay ./relay/common ./relay/constant
```

Expected after implementation: backend tests pass.

---

### Task 3: Add failing OpenTU executor/retry/resume tests first

**Files:**
- Modify: `/mnt/f/code/project/opentu/packages/drawnix/src/services/__tests__/media-executor.test.ts`
- Modify: `/mnt/f/code/project/opentu/packages/drawnix/src/services/__tests__/task-queue-service-image-retry.test.ts`
- Modify: `/mnt/f/code/project/opentu/packages/drawnix/src/utils/__tests__/task-utils.test.ts`

- [ ] Add fake-timer slow-provider test.
  - Mock POST returns `{ task_id: 'remote-1', status: 'in_progress' }`.
  - Mock GET returns `in_progress` through 129 seconds and `completed` at 130 seconds.
  - Assert task is not failed at 120 seconds.
  - Assert final result completes and `remoteId` was persisted.

- [ ] Add retry idempotency test.
  - Create failed image task with `params.retryAttempt` absent.
  - Call `retryTask(task.id)`.
  - Assert next submit uses `Idempotency-Key: opentu-image-${taskId}-retry-1` or equivalent attempt-scoped key.
  - Assert repeated resume of an existing processing task does not POST a new task.

- [ ] Add Creative managed image resumability test.
  - Task: `type=image`, `status=processing`, `remoteId=remote-1`, `params.model=<creative binding>`, `invocationRoute.operation='image'` with Creative managed route marker.
  - Assert `isResumableAsyncImageTask(task)` returns true.
  - Assert resume path calls NewAPI `/images/tasks/remote-1`, not OpenAI async image polling.

- [ ] Run expected failing tests.

```bash
cd /mnt/f/code/project/opentu
pnpm vitest run packages/drawnix/src/services/__tests__/media-executor.test.ts \
  packages/drawnix/src/services/__tests__/task-queue-service-image-retry.test.ts \
  packages/drawnix/src/utils/__tests__/task-utils.test.ts
```

Expected before implementation: tests fail on 120s timeout, fixed idempotency key, or missing managed image resume.

---

### Task 4: Fix OpenTU managed image executor lifecycle

**Files:**
- Modify: `/mnt/f/code/project/opentu/packages/drawnix/src/services/media-executor/fallback-adapter-routes.ts`
- Modify: `/mnt/f/code/project/opentu/packages/drawnix/src/services/media-executor/task-storage-writer.ts`
- Modify: `/mnt/f/code/project/opentu/packages/drawnix/src/services/task-queue-service.ts`
- Modify: `/mnt/f/code/project/opentu/packages/drawnix/src/utils/task-utils.ts`
- Modify: `/mnt/f/code/project/opentu/packages/drawnix/src/hooks/useTaskExecutor.ts`

- [ ] Replace hard-coded 120 poll attempts.
  - Use `TASK_TIMEOUT.IMAGE` as the outer ceiling.
  - Use polling interval/backoff with jitter or bounded backoff; start near 1s, allow 429/5xx retry with `Retry-After` if present.
  - Do not mark terminal failure for temporary HTTP 429/500/502/503/504 until timeout/TTL expires.

- [ ] Persist `remoteId` immediately after submit.
  - After submit DTO parse, call `taskStorageWriter.updateRemoteId(taskId, submitted.task_id, invocationRoute)` before first poll sleep.
  - Also notify in-memory task queue if needed so refresh before IndexedDB flush is safe.

- [ ] Store complete durable result metadata.
  - On content download, store: `url` local cache URL, `contentUrl`, `remoteTaskId`, `mimeType`, `format`, `size`, `width`, `height`, `targetWidth`, `targetHeight`.
  - Actual `width/height` comes from decoding the downloaded image blob in browser.
  - Backend target dimensions remain separate from actual dimensions.

- [ ] Propagate safe failure reason.
  - If task DTO has `fail_reason` / `error.message`, use it in `taskStorageWriter.failTask`.
  - Preserve generic fallback only when backend provides no safe reason.

- [ ] Split retry semantics.
  - `retryTask` for regenerate increments `params.retryAttempt` and clears `remoteId/result/error/insertedToCanvas`.
  - `createCreativeImageTaskIdempotencyKey(taskId, retryAttempt)` returns old format for attempt 0 and attempt-scoped format for attempt > 0.
  - Resume path never increments retryAttempt and never POSTs.

- [ ] Add managed image resume.
  - If task is Creative managed image + processing + remoteId, resume via GET `/creative/relay/v1/images/tasks/:remoteId` and `/content`.
  - Do not send a new POST in resume.

- [ ] Run focused OpenTU tests.

```bash
cd /mnt/f/code/project/opentu
pnpm vitest run packages/drawnix/src/services/__tests__/media-executor.test.ts \
  packages/drawnix/src/services/__tests__/task-queue-service-image-retry.test.ts \
  packages/drawnix/src/utils/__tests__/task-utils.test.ts
```

Expected: slow provider, retry, and resume tests pass.

---

### Task 5: Add failing cache/canvas display lifecycle tests first

**Files:**
- Modify: `/mnt/f/code/project/opentu/packages/drawnix/src/hooks/__tests__/useAutoInsertToCanvas.test.ts`
- Add or modify: `/mnt/f/code/project/opentu/packages/drawnix/src/utils/__tests__/asset-cleanup.test.ts`
- Add or modify: selected preview/task history test file after locating exact component.

- [ ] Add auto-insert success-gate test.
  - Mock completed task with `/__aitu_cache__/image/task-1.png`.
  - Mock cache/image decode failure.
  - Assert `completePostProcessing` and `markAsInserted` are not called.
  - Assert `failPostProcessing(taskId, ...)` is called.

- [ ] Add cache miss no-silent-delete test.
  - Create board with generated media element using `/__aitu_cache__/image/task-1.png`.
  - Mock `unifiedCacheService.getCachedBlob` returns null.
  - Assert generated media element is not silently removed without task failure/reporting.
  - If deletion remains for non-generated stale assets, assert it only applies to non-generated media and supports nested lookup.

- [ ] Add natural dimension test.
  - Simulate content image `3840x1648` and requested placeholder `21:9`.
  - Assert final canvas element uses natural ratio or documented fit rule, not unconditional 400x171 fallback.

- [ ] Add thumbnail/dock rehydrate test.
  - Task result has `url=/__aitu_cache__/image/task-1.png`, `contentUrl=/creative/relay/v1/images/tasks/remote-1/content`.
  - Cache miss should trigger rehydrate attempt or a retryable failed state, not permanent broken image.

- [ ] Run expected failing tests.

```bash
cd /mnt/f/code/project/opentu
pnpm vitest run packages/drawnix/src/hooks/__tests__/useAutoInsertToCanvas.test.ts \
  packages/drawnix/src/utils/__tests__/asset-cleanup.test.ts
```

Expected before implementation: tests fail on early completion/deletion/no rehydrate.

---

### Task 6: Fix cache/canvas/task-history lifecycle

**Files:**
- Modify: `/mnt/f/code/project/opentu/packages/drawnix/src/hooks/useAutoInsertToCanvas.ts`
- Modify: `/mnt/f/code/project/opentu/packages/drawnix/src/data/image.ts`
- Modify: `/mnt/f/code/project/opentu/packages/drawnix/src/utils/asset-cleanup.ts`
- Modify: `/mnt/f/code/project/opentu/packages/drawnix/src/services/unified-cache-service.ts`
- Modify: `/mnt/f/code/project/opentu/apps/web/src/sw/index.ts` only if key normalization/rehydrate support needs it.
- Modify: selected preview / task history components after exact confirmation.

- [ ] Add image decode/cache verification helper.
  - Input: cache URL and optional expected dimensions.
  - First check `unifiedCacheService.getCachedBlob(url)`.
  - Decode blob via `Image` / `createImageBitmap` where available.
  - Return `{ width, height, mimeType }` or throw safe error.

- [ ] Change auto insert completion gate.
  - Insert placeholder/node.
  - Verify cached image loads.
  - Only then call `completePostProcessing` and `markAsInserted`.
  - On failure: call `failPostProcessing`, leave anchor retryable, set task render/cache error, and do not mark inserted.

- [ ] Stop generated image silent deletion.
  - For `/__aitu_cache__/image/<taskId>.*` or metadata with task id, report task render failure.
  - Keep canvas placeholder where practical so user sees an actionable failed state.
  - If removing non-generated stale nodes remains necessary, use a path-aware nested element removal helper.

- [ ] Implement cache rehydrate path.
  - If task result has `contentUrl` and cache URL misses, fetch content again through same-origin NewAPI route.
  - Re-cache blob to the same local URL.
  - Then retry image load/thumbnail load.
  - If auth/session missing, show retryable error instead of deleting content.

- [ ] Update dock/task history image components.
  - Do not render naked `<img src={localCacheUrl}>` for generated media without fallback.
  - Use shared generated-media image component or hook that performs rehydrate and safe failure display.

- [ ] Run focused tests.

```bash
cd /mnt/f/code/project/opentu
pnpm vitest run packages/drawnix/src/hooks/__tests__/useAutoInsertToCanvas.test.ts \
  packages/drawnix/src/utils/__tests__/asset-cleanup.test.ts
```

---

### Task 7: Fix dimensions and display sizing end-to-end

**Files:**
- Modify: `/mnt/f/code/project/new-api/controller/creative_image_tasks.go`
- Modify: `/mnt/f/code/project/new-api/service/creative_image_adapter.go`
- Modify: `/mnt/f/code/project/opentu/packages/drawnix/src/services/media-executor/fallback-adapter-routes.ts`
- Modify: `/mnt/f/code/project/opentu/packages/drawnix/src/hooks/useAutoInsertToCanvas.ts`
- Modify: `/mnt/f/code/project/opentu/packages/drawnix/src/utils/creative-image-display-size.ts`
- Modify: `/mnt/f/code/project/opentu/packages/drawnix/src/utils/size-ratio.ts` only if helper rules need adjustment.

- [ ] Keep three separate dimension concepts.
  - `placeholderWidth/placeholderHeight`: UI before result exists.
  - `targetWidth/targetHeight`: provider requested/expected output.
  - `width/height`: actual decoded result dimensions.

- [ ] NewAPI returns target dimensions where derivable from adapter/template/userParams.
  - Do not pretend target dimensions are actual result dimensions.
  - Include target metadata in DTO `metadata` or `result`.

- [ ] OpenTU decodes actual dimensions after content download.
  - Store actual `width/height` in task result.
  - Auto-insert uses actual ratio unless inserting into a target frame with intentional contain/stretch behavior.

- [ ] Update placeholder display.
  - During generating, anchor should reflect requested aspect ratio/target ratio, not a tiny generic strip unless requested ratio is genuinely wide.
  - Final displayed image should use actual ratio.

- [ ] Run tests.

```bash
cd /mnt/f/code/project/new-api
go test -count=1 ./service ./controller -run 'Creative.*Image'
cd /mnt/f/code/project/opentu
pnpm vitest run packages/drawnix/src/utils/__tests__/creative-image-display-size.test.ts \
  packages/drawnix/src/hooks/__tests__/useAutoInsertToCanvas.test.ts \
  packages/drawnix/src/services/__tests__/media-executor.test.ts
```

---

### Task 8: Fix provider binding contracts

**Files:**
- Modify: `/mnt/f/code/project/new-api/service/creative_model_capability.go`
- Modify: `/mnt/f/code/project/new-api/service/creative_image_adapter.go`
- Test: `/mnt/f/code/project/new-api/service/creative_model_capability_test.go`
- Test: `/mnt/f/code/project/new-api/service/creative_image_adapter_test.go`

- [ ] Encode Nano Banana allowed-values exactly.
  - Restrict `aspectRatio` and `imageSize` values to the provider-supported set.
  - Reject unsupported admin binding values during validate/save/dry-run.

- [ ] Make dry-run/live body generation identical.
  - If live omits `auto`, dry-run omits it.
  - If live sends `auto`, dry-run sends it.
  - Pick one contract and apply consistently.

- [ ] Ensure Duomi/GrsAI target-pixel metadata aligns with request body.
  - Duomi `gpt-image-2`: `imageSize=1K`, aspect ratios including 21:9.
  - GrsAI `gpt-image-2`: 1K only.
  - GrsAI `gpt-image-2-vip`: 1K-4K including 21:9.

- [ ] Run tests.

```bash
cd /mnt/f/code/project/new-api
go test -count=1 ./service -run 'Creative.*Capability|Creative.*ProviderAdapters|Creative.*Image'
```

---

### Task 9: Fix viewport refresh and DialogTaskList insertion consistency

**Files:**
- Modify: `/mnt/f/code/project/opentu/packages/drawnix/src/components/task-queue/DialogTaskList.tsx`
- Modify: `/mnt/f/code/project/opentu/packages/drawnix/src/app.tsx`
- Modify: `/mnt/f/code/project/opentu/packages/drawnix/src/services/creative-document-sync.ts`
- Add/modify tests after exact current test harness confirmation.

- [ ] Fix DialogTaskList.
  - After successful image/video insertion, call `taskQueueService.markAsInserted(taskId, 'manual')`.
  - Prefer sharing insertion helper with `TaskQueuePanel` to prevent future split.

- [ ] Fix viewport persistence.
  - Persist viewport changes on normal debounce and also flush on `visibilitychange`, `pagehide`, and before cloud sync snapshot.
  - Avoid writing stale default viewport over newer persisted viewport during reload.
  - Multi-tab conflict should prefer latest timestamp or existing document sync revision rule.

- [ ] Add smoke-level test or browser check.
  - Pan/zoom, trigger visibility hidden/reload, reopen; viewport should match previous state.
  - Insert through DialogTaskList; task should show inserted and not duplicate auto-insert.

- [ ] Run focused tests and browser smoke.

```bash
cd /mnt/f/code/project/opentu
pnpm vitest run packages/drawnix/src/services/__tests__/task-queue-service.test.ts
pnpm e2e:creative-embedded -- --grep "viewport|creative"
```

If Playwright suite selection differs locally, record the exact command used in `validation.md`.

---

### Task 10: Full verification gate before deploy/staging

**Files:**
- Modify: `.trellis/tasks/06-21-06-21-creative-live-adapter-push-deploy-smoke/validation.md`
- Modify: `.trellis/tasks/06-21-06-21-creative-live-adapter-push-deploy-smoke/check.md` if created by Trellis check.

- [ ] Run backend verification.

```bash
cd /mnt/f/code/project/new-api
go test -count=1 ./controller ./service ./router ./model ./relay ./relay/common ./relay/constant
```

- [ ] Run OpenTU targeted verification.

```bash
cd /mnt/f/code/project/opentu
pnpm vitest run packages/drawnix/src/services/__tests__/media-executor.test.ts \
  packages/drawnix/src/services/__tests__/task-queue-service-image-retry.test.ts \
  packages/drawnix/src/hooks/__tests__/useAutoInsertToCanvas.test.ts \
  packages/drawnix/src/utils/__tests__/task-utils.test.ts \
  packages/drawnix/src/utils/__tests__/creative-image-display-size.test.ts
pnpm typecheck
```

- [ ] Run no-provider browser/staging smoke.
  - Login required.
  - `/creative` app shell loads.
  - Model list and parameter panel load for configured bindings.
  - Mock/fake image generation covers slow provider timing, retry, refresh, and cache miss.

- [ ] Run controlled real-provider smoke only after explicit user authorization.
  - One Duomi low-cost image.
  - One GrsAI low-cost image.
  - Record redacted task ids/status only.
  - Verify result remains visible after refresh and retry is not stale replay.

- [ ] Dynamic workflow re-audit.
  - Must include the three mandatory gates from `.trellis/spec/guides/deep-audit-runtime-lifecycle-guide.md`.
  - Do not mark complete if synthesis fails; compact and resume.

- [ ] Commit and finish.
  - Commit code changes by coherent slice or final verified batch.
  - Update `.trellis/spec/` if new durable contracts were learned.
  - Run Trellis finish-work after checks pass.

---

## 4. Execution Order

1. **Backend contract + DTO/rate-limit/durable lifecycle**: Tasks 1-2.
2. **OpenTU executor/retry/resume**: Tasks 3-4.
3. **Cache/canvas success gate**: Tasks 5-6.
4. **Dimensions/provider contracts**: Tasks 7-8.
5. **Viewport/minor insertion consistency**: Task 9.
6. **Full verification + dynamic workflow final review**: Task 10.

This order is deliberate. If retry/remote identity remains broken, cache/canvas fixes can still show stale results; if cache/canvas success remains broken, UI can still claim success while media is missing. Do not deploy between Tasks 4 and 6 except to an isolated staging used only for verification.

---

## 5. Reviewer Checklist

- [ ] Slow provider succeeds at 130s/150s/180s without false terminal failure.
- [ ] Browser refresh during processing resumes by `remoteId` without POSTing a duplicate provider task.
- [ ] Retry after failure uses a new attempt-scoped idempotency key.
- [ ] Cache miss after refresh rehydrates or marks failed/retryable; it does not silently delete generated content.
- [ ] `markAsInserted` happens only after image load/decode verification.
- [ ] Task history, dock thumbnail, and canvas use the same generated-media rehydrate path.
- [ ] Failure reason is user-visible and sanitized.
- [ ] 21:9/1K/2K/4K display uses documented target and actual natural dimensions correctly.
- [ ] Status/content GET does not consume model-submit rate limit.
- [ ] Nano Banana dry-run and live submit are contract-equivalent.
- [ ] Viewport persists across pan/zoom + refresh.

---

## 6. Repair Progress — 2026-06-22 Post-v4

### SERVER-DURABLE-CONTENT — fixed locally

Scope: `/mnt/f/code/project/new-api`.

Change summary:

- `GET /creative/relay/v1/images/tasks/:task_id/content` now treats live image provider content as a server-materialized private asset.
- First successful provider content fetch:
  - returns the provider bytes to the current caller;
  - creates/deduplicates a `CreativeAsset` through `CreativeAssetRuntime.CreateOrGet` when the asset runtime is enabled;
  - stores only safe metadata (`source`, `taskId`, `bindingId`, `providerModelId`), never provider result URL/signed URL/key material;
  - updates `Task.PrivateData.ResultURL` to `/creative/api/assets/:assetId/content`.
- Subsequent content reads detect `/creative/api/assets/:assetId/content` and stream through owner-scoped `CreativeAssetRuntime.OpenContent`, including range handling.
- If asset runtime is disabled before first materialization, behavior remains provider-proxy fallback; no generation path is blocked.

Regression test added/updated:

- `controller/creative_test.go::TestCreativeImageTaskContentProxiesLiveResultPrivately`
  - first request fetches provider once and materializes the image;
  - DB task result URL becomes owner-scoped asset content URL;
  - second request succeeds from asset even when provider URL would fail;
  - provider hit count remains one.

Validation run:

```bash
cd /mnt/f/code/project/new-api
go test -count=1 ./controller -run 'TestCreativeImageTaskContentProxiesLiveResultPrivately'
go test -count=1 ./controller -run 'TestCreativeImageTaskContentProxiesLiveResultPrivately|TestCreativeImageTaskSubmitLiveTimeoutStaysPendingAndReplaysTask|TestCreativeImageTaskSubmitLiveBindingUsesLockedChannelAndSanitizedDTO|TestCreativeImageTaskFetchFailClosesMissingLiveAffinityAndRefundsOnce|TestCreativeImageTaskFetchPollsLiveTaskWithCASBillingAndPrivateDTO'
go test -count=1 ./service -run 'TestDispatchPlatformUpdateCreativeImagePollsLiveTaskToSuccess|TestCollectPollingTaskBuckets|TestCreativeImageProviderTransportTimeoutIsAmbiguous|TestMarkTasksFailedWithCASAndRefundNullUpstreamOnlyOnce'
go test -count=1 ./model ./relay ./relay/common ./relay/constant
```

All commands passed.

Cross-repo verification after this backend fix:

```bash
cd /mnt/f/code/project/opentu
pnpm vitest run --no-file-parallelism --maxWorkers=1 --minWorkers=1 \
  packages/drawnix/src/components/retry-image.test.tsx \
  packages/drawnix/src/components/lazy-image/LazyImage.test.tsx \
  packages/drawnix/src/components/media-library/AssetItem.test.tsx \
  packages/drawnix/src/components/shared/SelectedContentPreview.test.tsx \
  packages/drawnix/src/services/__tests__/media-library-projection.test.ts \
  packages/drawnix/src/hooks/__tests__/useGeneratedMediaCacheMissRecovery.test.tsx \
  packages/drawnix/src/services/__tests__/media-executor.test.ts \
  packages/drawnix/src/services/__tests__/task-queue-service-image-retry.test.ts \
  packages/drawnix/src/hooks/__tests__/useTaskExecutor.test.ts
pnpm nx run drawnix:typecheck
pnpm nx run web:typecheck
```

Vitest: 9 files / 57 tests passed. Both typecheck commands passed.

Whitespace checks passed:

```bash
git -C /mnt/f/code/project/new-api diff --check
git -C /mnt/f/code/project/opentu diff --check
git -C /mnt/f/code/project/new2fly diff --check
```

---

## 7. Repair Progress — v5 Follow-up Fixes

See `runtime-lifecycle-postfix-v5-result-2026-06-22.md` for the full v5 dynamic workflow result, main-session verification, fixed findings, open risks, and validation commands.

Fixed after v5:

- `NEWAPI-SERVER-DURABLE-CONTENT`: live image content now fails closed unless Creative asset runtime is ready and provider bytes are materialized; first `Range` read is served through the asset path.
- `NEWAPI-CREATIVE-HISTORY-DTO`: generic task DTO now maps Creative image success content to `/creative/relay/v1/images/tasks/:task_id/content` and suppresses `channel_id` for Creative image tasks.
- `OTU-CREATIVE-TTD-PARAMS`: TTD single/multi/batch image entries now carry schema-backed Creative selections in `userParams` with `creativeManaged: true` instead of legacy `params`.

Still open:

- Ambiguous submit late-success recovery requires provider-side correlation/idempotency support; current code is fail-safe but cannot discover a late-accepted provider task without an upstream lookup key.
- Submit-side 429/5xx, nano-banana strict schema contract, and timeout-after-90m old-remote recovery remain medium follow-ups.
