# v23b Cache/Canvas Dynamic Workflow — Main Session Verification

Date: 2026-06-24
Task: `.trellis/tasks/06-21-06-21-creative-live-adapter-push-deploy-smoke`
Scope: OpenTU generated media cache/canvas/history/workzone lifecycle after v23a storage fixes.

## Verification method

- Reviewed v23b workflow journal: `.codex-flow/journal/creative-runtime-lifecycle-postfix-v23b-cache-canvas-2026-06-24.jsonl`.
- Re-checked current on-disk OpenTU source with `codegraph` and targeted `rg`/`nl` reads.
- No live provider call, browser smoke, secret/cookie/nonce/provider-key read, or signed/raw provider payload inspection was performed.

## Accepted product findings

### VIDEO_CACHE_MISS_NOT_RECOVERED — HIGH

Verdict: accepted.

Evidence:

- Session-broker video download writes local generated video cache URLs as `/__aitu_cache__/video/{remoteId}.{format}` and stores the Blob in `unifiedCacheService`: `packages/drawnix/src/services/media-api/video-api.ts:131-170`.
- Generated cache-miss recovery only recognizes image URLs via `GENERATED_IMAGE_CACHE_PREFIX = '/__aitu_cache__/image/'`: `packages/drawnix/src/utils/generated-media-cache.ts:5,37-47`.
- The canvas video component only turns load errors into local `videoError` and has no equivalent cache-miss event or rehydrate path: `packages/drawnix/src/plugins/components/video.tsx:38-40,139-162`.
- `asset-cleanup` only dispatches generated cache-miss events for `isGeneratedImageCacheUrl(imageUrl)`: `packages/drawnix/src/utils/asset-cleanup.ts:63-66`.

Impact:

A refreshed embedded Creative video whose Cache Storage entry is missing can remain permanently broken (`Video failed to load`) even though the task has a recoverable same-origin content source.

Fix direction:

Introduce generated media cache recognition for video, dispatch/recover video cache misses, and/or ensure video element fallback can rehydrate `/__aitu_cache__/video/*` from durable task metadata/content endpoint.

### BUFFERED_MISS_DROPPED_ON_TRANSIENT_FAILURE — MEDIUM

Verdict: accepted.

Evidence:

- `useGeneratedMediaCacheMissRecovery` deletes the pending miss before async task lookup/content rehydrate succeeds: `packages/drawnix/src/hooks/useGeneratedMediaCacheMissRecovery.ts:221-234`.
- If no content URL can be resolved, it returns without re-buffering: `packages/drawnix/src/hooks/useGeneratedMediaCacheMissRecovery.ts:254-265`.
- Rehydrate failure is only logged and also loses the pending event: `packages/drawnix/src/hooks/useGeneratedMediaCacheMissRecovery.ts:284-314`.
- Content rehydrate uses finite retry and then throws: `packages/drawnix/src/utils/generated-media-cache.ts:246-270`.

Impact:

A temporary IndexedDB/task visibility gap or transient backend content error can convert a recoverable generated image cache miss into a lasting broken/blank canvas node until another independent image error path re-fires.

Fix direction:

Acknowledge/delete pending miss only after successful cache rehydrate and canvas retry update. Requeue with bounded attempts/backoff/TTL on recoverable misses.

### PENDING_BUFFER_GLOBAL_UNBOUNDED — MEDIUM

Verdict: accepted.

Evidence:

- Pending cache misses are held in a module-global `Map`: `packages/drawnix/src/hooks/useGeneratedMediaCacheMissRecovery.ts:23-26`.
- The key includes only normalized path, element id, and task id; no board/document/session scope: `packages/drawnix/src/hooks/useGeneratedMediaCacheMissRecovery.ts:40-47`.
- Buffer insertion has no capacity, TTL, or attempt count: `packages/drawnix/src/hooks/useGeneratedMediaCacheMissRecovery.ts:210-218`.
- Any enabled board drains all pending values: `packages/drawnix/src/hooks/useGeneratedMediaCacheMissRecovery.ts:323-327`.

Impact:

Board switches or long not-ready windows can make the current board consume old-board misses, while long sessions can accumulate unbounded cache-miss retries.

Fix direction:

Add bounded pending entries with attempt/created/lastAttempt fields, TTL/capacity, and safe board matching at processing time. Drop stale entries predictably.

### F1 — MEDIUM

Verdict: accepted.

Evidence:

- On refresh restore, media-generation WorkZone steps with no `step.result.taskId` are explicitly kept as-is: `packages/drawnix/src/components/startup/DrawnixDeferredRuntime.tsx:202-220`.
- Task queue sync only joins a task to a WorkZone step through `step.result.taskId`: `packages/drawnix/src/components/startup/DrawnixDeferredRuntime.tsx:469-474`.
- Workflow engine writes `step.result = { taskId }` in `onTaskCreated`, but the `workflowStorageWriter.saveWorkflow(workflow)` call is fire-and-forget: `packages/drawnix/src/services/workflow-engine/engine.ts:386-390,420-423`.

Impact:

If the page refreshes after task creation but before workflow persistence completes, a media WorkZone step can remain pending/running forever because later task updates have no durable task id mapping to attach to.

Fix direction:

Make task-id persistence durable/awaited before continuing, and/or mark stale media WorkZone steps without task ids as recoverable/failed after a bounded grace period instead of leaving them indefinitely running.

### F2 — MEDIUM

Verdict: accepted.

Evidence:

- Video history maps `imageUrl` to `task.result.thumbnailUrl || task.result.url`: `packages/drawnix/src/hooks/useGenerationHistory.ts:85-99`.
- `GenerationHistory` renders video `imageUrl` through `RetryImage`: `packages/drawnix/src/components/generation-history/generation-history.tsx:88-97`.
- `RetryImage` is image-only and eventually fails after retries: `packages/drawnix/src/components/retry-image.tsx:343-351`.

Impact:

Completed videos without a thumbnail try to render the video file as an image thumbnail, causing broken/loading thumbnails in history after refresh.

Fix direction:

For video history, use an actual thumbnail only when available; otherwise render the existing video placeholder while keeping `previewUrl/downloadUrl` available.

## Not accepted as product finding yet

### CMG-001 — needs no immediate product fix

TaskItem's primary action gate checks `task.result?.url` rather than `task.result?.urls?.length`: `packages/drawnix/src/components/task-queue/TaskItem.tsx:1060-1078`. However current `TaskResult` requires `url` (`packages/drawnix/src/types/shared/core.types.ts:258-262`) and primary image result producers set `url` to the first URL while optionally setting `urls` (`media-api/image-api.ts:121-126`, `media-executor/fallback-executor.ts:546-565`, `fallback-adapter-routes.ts:986-1004`).

This is a defensive hardening candidate, not currently a verified product break.

## Coverage gaps to carry forward

- Browser/E2E does not yet exercise a real generated image/video Cache Storage miss after refresh with actual canvas materialization.
- Slow-provider late success is still mostly unit-level, not a true provider-timing E2E.
- Viewport pan/zoom -> pagehide -> refresh is not covered as a full browser chain.

