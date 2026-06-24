# Runtime lifecycle postfix v10 branch results — 2026-06-23

Status: codex-flow fan-out completed; built-in synthesis failed twice (`synthesis: null`).

Journal: `/mnt/f/code/project/new2fly/.codex-flow/journal/creative-runtime-lifecycle-postfix-reaudit-v10-2026-06-23.jsonl`

## new-api: feat/creative-embed; opentu: feat/creative-embed; new2fly: master

Status: `finding`; findings: 1

Backend new-api Creative image async lifecycle checks pass from current code: submit is durable before provider call, selected key and endpoint affinity are stored, empty upstream fails closed, ambiguous submit is held then fail-closed/refunded, polling uses CAS plus billing outbox, and materialization failures remain retryable. One cross-layer frontend recovery gap remains for remote tasks that hit the client-side Creative timeout.

### F-CROSS-001 — Creative managed image local timeout is not recoverable after refresh

Severity: MEDIUM

Evidence: opentu packages/drawnix/src/services/media-executor/fallback-adapter-routes.ts:489-558 stops Creative managed image polling after CREATIVE_REMOTE_IMAGE_TIMEOUT_MS with a plain Error; the submit path persists that as code IMAGE_GENERATION_ERROR at fallback-adapter-routes.ts:674-688, while the resume path stores error.name at packages/drawnix/src/hooks/useTaskExecutor.ts:535-555. Refresh recovery only treats failed Creative managed image tasks as recoverable when error.code === TIMEOUT at packages/drawnix/src/utils/task-utils.ts:138-162.

Impact: A long-running provider task with a known remoteId can be marked failed locally and then not recovered after refresh. Manual retry clears remoteId and generates a new idempotency key, so the existing backend/provider task can be orphaned and the user may pay or wait twice.

Fix direction: Normalize Creative managed remote poll timeout failures to a stable TIMEOUT code in both initial execution and resume paths, or broaden isRecoverableRemoteTaskFailure to recognize this specific timed-out Creative remote state while preserving remoteId. Add tests covering timeout -> refresh -> resume polling instead of regenerate.


## opentu: feat/creative-embed; new-api: feat/creative-embed; new2fly: master

Status: `finding`; findings: 2

审计基于当前代码和测试静态重建，未做 live provider、部署、push 或凭据读取。OpenTU 的普通本地超时、IndexedDB restore、remoteId resume、idempotency retryAttempt、stale completion guard、SW/cache miss、thumbnail、canvas load verification、任务历史和 viewport 持久化大体已有保护；两个剩余问题集中在 Creative managed 远程任务的本地 poll-budget 终态化，以及 dock 插入路径的画布元数据缺口。

### OTU-LIFECYCLE-001 — Creative managed poll budget can still turn a running remote task into nonrecoverable local failure

Severity: HIGH

Evidence: opentu packages/drawnix/src/services/media-executor/fallback-adapter-routes.ts:478-489 polls Creative managed image tasks only until CREATIVE_REMOTE_IMAGE_TIMEOUT_MS, then throws "creative image task timed out" at 558. executeCreativeManagedImageTask catches that and writes a terminal failed task with IMAGE_GENERATION_ERROR at 674-687, then task-queue-service.ts:1378-1401 can persist EXECUTION_ERROR. useTaskStorage.ts:148-177 restores only isRecoverableRemoteTaskFailure(), and task-utils.ts:138-161 only treats TIMEOUT/INTERRUPTED-style failures as recoverable. retryTask() then clears remoteId at task-queue-service.ts:2444-2447, so retry becomes a fresh generation.

Impact: A slow provider task that is still running can be shown as failed locally. Late provider success is not recovered on refresh, and the retry button starts a new upstream task, risking duplicate cost and abandoning the original result.

Fix direction: Make Creative managed remoteId poll-budget expiry non-terminal, or store a recoverable TIMEOUT state that restore/resume handles without clearing remoteId. Keep regenerate explicit and separate from resume. Add a test where provider stays in_progress past CREATIVE_REMOTE_IMAGE_TIMEOUT_MS, local polling stops/reloads, then backend later returns completed and the same remoteId is resumed.

### OTU-LIFECYCLE-002 — Dock image insertion drops generated-media rehydrate metadata

Severity: MEDIUM

Evidence: Dialog insertion preserves generated image metadata via dialog-task-insert.ts:39-56 and passes it to insertImageFromUrl at 96-107. The toolbar dock TaskQueuePanel does not use that helper; TaskQueuePanel.tsx:607-624 verifies/rehydrates the cache but calls insertImageFromUrl(board, ready.url) without metadata. data/image.ts:468-472 only writes contentUrl/remoteTaskId/providerTaskId/mimeType onto the canvas node when metadata is supplied. Cache miss recovery can fall back to canvas metadata at useGeneratedMediaCacheMissRecovery.ts:211-231, but dock-inserted nodes lack that fallback.

Impact: Images inserted from the dock can survive while the task record and Cache Storage entry exist, but if task history is cleared/retained away and the virtual cache misses after refresh, the canvas node lacks durable content metadata to rehydrate from backend content.

Fix direction: Route TaskQueuePanel image insertion through insertDialogTaskResultToBoard or pass the same generated-image canvas metadata to insertImageFromUrl. Add a TaskQueuePanel/dock insertion test that clears task history or simulates missing task lookup, evicts /__aitu_cache__, and verifies rehydrate from canvas metadata.


## generated image media lifecycle

Status: `finding`; findings: 4

Source/test-only audit completed for the generated image media lifecycle. Backend slow-provider lifecycle gates look repaired in current code, and frontend auto-insert/cache-miss recovery has strong readiness checks, but several manual/media-library/frame insertion callers still drop generated-image metadata after verification. No live provider calls, deploys, pushes, or credential reads were performed.

### GIML-001 — Manual task-queue image insert verifies cache but drops durable generated metadata

Severity: HIGH

Evidence: opentu/packages/drawnix/src/components/task-queue/TaskQueuePanel.tsx:607-624 builds contentUrl/remoteTaskId/providerTaskId metadata for generated image readiness, but then calls insertImageFromUrl(board, ready.url) without passing metadata. opentu/packages/drawnix/src/data/image.ts:331-343 only accepts generated metadata via the final metadata argument, and persists it to the inserted node at 468-472. opentu/packages/drawnix/src/hooks/useGeneratedMediaCacheMissRecovery.ts:211-231 depends on durable node metadata when task records are gone.

Impact: Manual task-queue inserts can create canvas nodes without contentUrl/remoteTaskId/providerTaskId. After refresh or task-history cleanup, cache-miss recovery cannot reconstruct the provider content URL from the node, so generated images can become permanently unrecoverable on the canvas.

Fix direction: Pass the same generated-image metadata object into insertImageFromUrl after ensureGeneratedImageCacheUrlReady, and add a TaskQueuePanel manual-insert test that deletes task records then rehydrates from node metadata.

### GIML-002 — Media preview canvas insert omits generated rehydrate metadata

Severity: HIGH

Evidence: opentu/packages/drawnix/src/components/shared/media-preview/MediaViewport.tsx:516-528 verifies readiness with item.rehydrateSourceUrl and item.rehydrateMetadata, then calls quickInsertCanvasMedia(contentType, readyMediaUrl) without the metadata argument. opentu/packages/drawnix/src/services/canvas-operations/media-quick-insert.ts:81-87 exposes the metadata parameter and forwards it to selected-frame insertion at 99-106 when supplied.

Impact: Dock/media preview insertion can pass availability verification but lose durable generated metadata on the inserted canvas node, breaking refresh/cache-miss recovery when local task records are absent.

Fix direction: Forward item.rehydrateMetadata into quickInsertCanvasMedia from MediaViewport, and assert inserted generated image nodes retain contentUrl/remoteTaskId/providerTaskId.

### GIML-003 — Media library viewer insertion drops generated metadata after readiness check

Severity: HIGH

Evidence: opentu/packages/drawnix/src/components/media-library/MediaLibraryGrid.tsx:1260-1275 verifies generated image cache readiness with rehydrate metadata, but then calls insertImageFromUrl(board, ready.url) without the final metadata argument. opentu/packages/drawnix/src/data/image.ts:468-472 persists generated metadata only when that argument reaches getGeneratedImageCanvasMetadata.

Impact: Media-library viewer insertion can create generated-image canvas nodes that cannot self-rehydrate after IndexedDB/task-history loss, even though the preview path had enough remote identity information.

Fix direction: Pass item.rehydrateMetadata, or the fallback asset-derived metadata already built at 1264-1272, into insertImageFromUrl. Add a media-library viewer insertion regression test for durable node metadata.

### GIML-004 — Grouped PPT slide frame insertion does not carry generated metadata

Severity: MEDIUM

Evidence: opentu/packages/drawnix/src/hooks/useAutoInsertToCanvas.ts:1275-1299 verifies grouped generated image items before insertion, but the PPT slide grouped-frame path at 1350-1357 calls insertMediaIntoFrame(..., undefined) without metadata. Other nearby single/frame paths pass metadata, for example quickInsert at 1112-1118.

Impact: Grouped PPT slide image insertion can succeed and complete post-processing while omitting durable generated metadata for the frame-inserted image, leaving that slide image less recoverable after refresh/cache loss.

Fix direction: Pass getImageTaskCanvasMetadata/current task metadata into insertMediaIntoFrame for grouped PPT slide insertion, matching the single-image and normal frame insertion paths. Add a grouped PPT slide auto-insert test that asserts metadata on every inserted/replaced frame image.


## user-visible-ui-status-error-surfaces

Status: `finding`; findings: 1

审计重建了当前前后端生命周期链路。慢 provider、后端幂等/计费/outbox、前端刷新恢复、缓存 miss 重水化、错误脱敏和 TaskItem memoization 在检查范围内有对应源码保护。主要缺口是用户可见的 retry 语义：失败远程任务的按钮和动作没有准确区分“恢复已有任务”和“重新生成”。

### UI-RETRY-SEMANTICS-001 — Retry button does not distinguish resume from fresh regeneration

Severity: MEDIUM

Evidence: /mnt/f/code/project/opentu/packages/drawnix/src/components/task-queue/TaskItem.tsx:270 makes FAILED/CANCELLED tasks retryable without checking recoverable remote state; /mnt/f/code/project/opentu/packages/drawnix/src/components/task-queue/TaskItem.tsx:1080 renders the same primary button text `重试`; /mnt/f/code/project/opentu/packages/drawnix/src/components/task-queue/TaskQueuePanel.tsx:313 and /mnt/f/code/project/opentu/packages/drawnix/src/components/task-queue/DialogTaskList.tsx:165 call `retryTask(taskId)` directly; /mnt/f/code/project/opentu/packages/drawnix/src/services/task-queue-service.ts:2395 resets the task, increments retryAttempt, clears result/error, and explicitly clears `remoteId` at line 2446 for a fresh submission; /mnt/f/code/project/opentu/packages/drawnix/src/utils/task-utils.ts:138 defines `isRecoverableRemoteTaskFailure` for failed remote tasks, but this helper is not used by TaskItem/TaskQueuePanel/DialogTaskList labeling or action routing; /mnt/f/code/project/opentu/packages/drawnix/src/hooks/useTaskExecutor.ts:411 resumes only PROCESSING tasks with remoteId, not FAILED tasks clicked through the retry button.

Impact: Users can see a generic retry action on a failed remote task while the implementation discards the remote identity and starts a new provider submission. This can mislead users about whether they are resuming an existing job or regenerating, and can cause unexpected duplicate generation/billing behavior.

Fix direction: Split retry affordances by task state. For `isRecoverableRemoteTaskFailure(task)`, either route the action through a resume/poll path that preserves remoteId/upstream identity, or label the button/action as a fresh regeneration and require clear user intent. Keep the current `retryTask` fresh-submit path for terminal failures that cannot be resumed.


## Creative schema-backed image params and live adapter compatibility

Status: `finding`; findings: 2

审计重建了当前 backend/frontend 代码路径。核心 schema-backed 渲染、Duomi/GrsAI live adapter 映射、21:9、poll/retry/cache materialization mostly成立；主要缺口是刷新发生在 submit response 前时，frontend 不能用原始 idempotency key 恢复。

### F1 — Refresh during managed image submit can regenerate with a new idempotency key instead of resuming

Severity: HIGH

Evidence: Frontend only persists `remoteId` after submit response: `/mnt/f/code/project/opentu/packages/drawnix/src/services/media-executor/fallback-adapter-routes.ts:638` and `:647`. On reload, `useTaskStorage` keeps only resumable tasks and otherwise marks processing tasks failed: `/mnt/f/code/project/opentu/packages/drawnix/src/hooks/useTaskStorage.ts:90`, `:106`, `:126`. Resumable image tasks require `remoteId`: `/mnt/f/code/project/opentu/packages/drawnix/src/utils/task-utils.ts:86`. Retry then increments `retryAttempt`: `/mnt/f/code/project/opentu/packages/drawnix/src/services/task-queue-service.ts:2417`, and uses a retry-scoped idempotency key: `:1161`.

Impact: Refresh or tab close after backend durable submit but before frontend receives the task id can strand the original backend task and make user retry create a second provider/backend attempt. This violates the refresh/retry/resume gate and can duplicate generation/billing intent.

Fix direction: Persist the initial Creative image idempotency key on task creation and treat managed `SUBMITTING` tasks without `remoteId` as recoverable by replaying the same key once, instead of marking failed and forcing `retry-1`. Add a refresh-during-submit test proving backend idempotency returns/resumes the original task.

### F2 — GrsAI nano-banana lacks the same required schema contract as GPT image templates

Severity: LOW

Evidence: Backend enforces required labels/options for Duomi GPT image and GrsAI GPT image/VIP only: `/mnt/f/code/project/new-api/service/creative_model_capability.go:1918`. `grsai_nano_banana` is only allowlisted by field id/value: `:2065`, `:2096`. A backend test saves a nano-banana schema with only `auto/1:1/16:9` aspect options and passes dry-run: `/mnt/f/code/project/new-api/service/creative_model_capability_test.go:1615`, `:1638`.

Impact: Current built-in nano template is correct, but stored live nano bindings can drift in labels/options and still pass validation. The frontend will faithfully render that drift because runtime schema is authoritative.

Fix direction: Add a required schema contract for `grsai_nano_banana`, preferably model-family aware for base/pro vs nano-banana-2 extended ratios, or explicitly document/admin-gate intentional subsets. Add tests for 21:9 and extended nano options.


## refresh/reopen workspace lifecycle

Status: `pass`; findings: 0

未发现当前 refresh/reopen workspace lifecycle 分支的新增阻断问题。审计仅基于当前源码和现有测试文件，未执行 live provider、部署、推送、凭据读取或浏览器实测。

