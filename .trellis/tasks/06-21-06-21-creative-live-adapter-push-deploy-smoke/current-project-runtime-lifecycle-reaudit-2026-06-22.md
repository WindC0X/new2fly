# Creative Runtime Lifecycle 全面再审报告

日期：2026-06-22  
范围：`../new-api` + `../opentu`，当前编排目录 `new2fly`。  
性质：只读深度审查 + 动态工作流 synthesis；未调用 live provider，未打印/落盘凭据或签名 URL。

## 0. 结论

- 本轮重新审查完成，第二轮动态工作流 synthesis 成功；不是把第一轮失败结果当完成。
- 当前 Creative image 最大问题不是单个 UI bug，而是跨层生命周期状态机不闭合：慢 provider、remoteId 持久化、retry 幂等、Cache Storage、canvas image load、失败原因、尺寸回流、viewport refresh 没有统一成端到端契约。
- 这不是发布通过结论：本轮没有执行 Vitest/Playwright/Go/fake provider 动态测试，报告中的 `requiredValidation` 是必须补上的防回归测试。
- 后续所有深度审查必须执行三道强制门槛：真实慢 provider 动态时序测试；分支审查后的跨层状态机 synthesis；刷新恢复/重试语义/Cache Storage 生命周期端到端验收。该规则已落盘到 `.trellis/spec/guides/deep-audit-runtime-lifecycle-guide.md`。

## 1. 动态工作流证据

- 第一轮：`.codex-flow/generated/creative-runtime-lifecycle-reaudit-20260622.workflow.ts`；journal `.codex-flow/journal/creative-runtime-lifecycle-reaudit-20260622.jsonl`。第一轮分支有效，但 canvas 分支异常且 synthesis 输入过大失败，未作为完成结果。
- 有效分支压缩：`.codex-flow/generated/creative-runtime-lifecycle-reaudit-effective-branches-20260622.json`。
- 第二轮修正：`.codex-flow/generated/creative-canvas-rerun-synthesis-20260622.workflow.ts`；journal `.codex-flow/journal/creative-canvas-rerun-synthesis-20260622.jsonl`。第二轮包含 canvas rerun + compact final synthesis，已完成。
- 结构化结果：`.trellis/tasks/06-21-06-21-creative-live-adapter-push-deploy-smoke/runtime-lifecycle-reaudit-result-2026-06-22.json`。

## 2. Findings（按修复优先级）

1. P0/P1 Cache miss + canvas load 未验证会造成空白或被删除图片，但 task/anchor 仍 completed。证据：opentu useAutoInsertToCanvas.ts:981-988、153-156；data/image.ts:389-398；retry-image.tsx:207-271；asset-cleanup.ts:43-64、127-136；apps/web/src/sw/index.ts:4939-5052。
2. P1 慢 provider 晚于 120s 成功会被 OpenTU 误判失败，且 image remoteId 未持久化无法刷新恢复。证据：fallback-adapter-routes.ts:272-318、266-270；task-storage-writer.ts:291-305；TASK_CONSTANTS.ts:9-20。
3. P1 retry 复用 taskId/idempotency key，业务上的“重新生成”会变成 NewAPI replay 旧任务。证据：fallback-adapter-routes.ts:139-140、240-254；task-queue-service.ts:2280-2335；new-api creative_image_tasks.go:631-683。
4. P1 NewAPI provider accepted 后才写 durable Task/billing/outbox，insert/billing 失败会留下不可恢复 accepted 任务窗口。证据：new-api creative_image_tasks.go:256-263、282-364。
5. P1 status/content GET 与 submit 同限流，poll/content/cache 临时 429/5xx 容易被当终态失败；provider poll terminal taxonomy 也不足。证据：new-api web-router.go:90-115；model-rate-limit.go:166-199；creative_image_adapter.go:370-371、480；creative_image_tasks.go:467-470。
6. P1 安全失败原因已在 adapter 层提取/脱敏，但 DTO/UI 丢失，用户只看到 generic failure。证据：creative_image_adapter.go:396-468、515-528；creative_image_tasks.go:66-75、718-727。
7. P2 最终尺寸锁定 schema fallback，provider target resolution 与 natural dimensions 没有回流到 canvas。证据：useAutoInsertToCanvas.ts:640-708、245-272、290-296；creative-image-display-size.ts:34-42；size-ratio.ts:5-28；new-api creative_image_tasks.go:66-75、710-727；creative_image_adapter.go:39-45、193-221、260-340、396-466。
8. P2 provider adapter/binding contract 仍有配置漂移风险，尤其 Nano Banana allowed-values 与 dry-run/live body parity。证据：creative_model_capability.go:553、1289-1300、2028、2068；creative_image_adapter.go:145。
9. P2 viewport-only 与 cloud sync refresh 生命周期不完整，pan/zoom 或 pending mutation 可在隐藏/刷新/多标签场景丢失。证据：opentu app.tsx:725-775、817-821、710-717；creative-document-sync.ts:760-765、1161-1175、898-930。
10. P2 DialogTaskList 手动插入成功后未 markAsInserted，状态与画布可重复插入。证据：TaskQueuePanel.tsx:564-723；DialogTaskList.tsx:215-244；task-queue-service.ts:2541-2563。

## 3. Canvas rerun 分支确认的具体缺陷

### F1 — P1 — Auto Insert 在验证图片加载前就标记插入成功

- 现象：生成 Creative 图片后画布节点可能为空白，但任务被标记为 inserted/completed。
- 影响：用户会看到空白/白色图片节点，但任务、anchor、历史状态显示已插入/完成，后续自动插入会被 insertedToCanvas 跳过。
- 根因：画布插入状态机把“创建 image element”当作“图片可显示成功”，真实 image load 被推迟到 React 渲染层，且失败不会回写任务状态。
- 关键证据：
  - /mnt/f/code/project/opentu/packages/drawnix/src/services/canvas-operations/media-quick-insert.ts:52-67 insertMedia: image 分支调用 insertImageFromUrl(board, content, point, false, size, true, true)。
  - /mnt/f/code/project/opentu/packages/drawnix/src/services/canvas-operations/canvas-insertion.ts:139-148 insertImageToCanvas: 注释说明不等待下载，传 skipImageLoad=true 且 lockReferenceDimensions=true。
  - /mnt/f/code/project/opentu/packages/drawnix/src/data/image.ts:389-398 insertImageFromUrl: skipImageLoad && referenceDimensions 时直接构造 imageItem，不加载图片；lockReferenceDimensions=true 时 shouldUpdateSizeAfterLoad=false。
  - /mnt/f/code/project/opentu/packages/drawnix/src/hooks/useAutoInsertToCanvas.ts:981-988: quickInsert 后立即 completePostProcessing 并 finalizeTaskInsertion。
  - /mnt/f/code/project/opentu/packages/drawnix/src/hooks/useAutoInsertToCanvas.ts:153-156 finalizeTaskInsertion: 直接 markAsInserted(taskId, 'auto_insert')。
- 修复方向：把 Creative image auto insert 的 post-processing 完成条件改为“节点已插入且图片可加载”。至少在 markAsInserted 前对本地 cache URL 做 getCachedBlob 或 Image decode 验证；失败时 completePostProcessing 应标记 failed，并保留 anchor 可重试。
- 验证：Vitest mock insertImageFromUrl 的 URL 为缺失 cache URL，断言 completePostProcessing/markAsInserted 当前仍被调用；修复后应不调用 markAsInserted，并写入 postProcessing failed。

### F2 — P1 — Cache Miss 有异步删除补救，但不回写任务状态且只覆盖根层节点

- 现象：Cache Storage 缺失时，图片节点先裂图/隐藏，顶层节点最终可能被异步删除，但任务状态不回滚。
- 影响：顶层 cache-miss 图片最终会被删掉，但任务仍显示已插入；嵌套/frame 内图片可能删不掉，只隐藏为不可见空洞。用户既失去画布内容，也没有明确可重试状态。
- 根因：Cache miss 处理只发生在 Image 组件渲染失败后的局部 cleanup；删除逻辑不具备全树定位，也不通知 TaskQueue/anchor 状态机。
- 关键证据：
  - /mnt/f/code/project/opentu/packages/drawnix/src/components/retry-image.tsx:207-271 RetryImage: 只有 maxRetries 耗尽后才调用外部 onError。
  - /mnt/f/code/project/opentu/packages/drawnix/src/plugins/components/image.tsx:228-249 Image.handleImageError: 隐藏 img，并调用 handleVirtualUrlImageError。
  - /mnt/f/code/project/opentu/packages/drawnix/src/utils/asset-cleanup.ts:149-175 handleVirtualUrlImageError: 对虚拟 URL 先做 250/750/1500ms 三次 _retry，然后 verifyVirtualImageCache。
  - /mnt/f/code/project/opentu/packages/drawnix/src/utils/asset-cleanup.ts:43-64 verifyVirtualImageCache: getCachedBlob 返回 null 后调用 removeElementFromBoard。
  - /mnt/f/code/project/opentu/packages/drawnix/src/utils/asset-cleanup.ts:127-136 removeElementFromBoard: 只在 board.children 根层按 element.id 查找并删除。
  - /mnt/f/code/project/opentu/apps/web/src/sw/index.ts:4939-5052 handleCacheUrlRequest: /__aitu_cache__/... cache miss 返回 404 Media not found。
- 修复方向：把 cache miss 删除从纯渲染层补救升级为任务状态事件：删除或加载失败时回写 postProcessing failed/insertedToCanvas=false，并支持 nested element path 删除。对 frame/nested 图片不要只查 board.children 根层。
- 验证：构造顶层与 frame 内两个 /__aitu_cache__ 图片元素，mock getCachedBlob=null；当前应只删除根层元素且 task.insertedToCanvas 仍为 true。修复后两者都应进入 failed/retryable 状态。

### F3 — P2 — 最终显示尺寸锁定为 schema fallback，不使用真实 natural dimensions

- 现象：生成占位和最终画布节点尺寸按 400 基准比例显示，未按真实图片 natural dimensions 修正。
- 影响：4K/2K/真实像素只影响 provider 请求，不影响画布显示尺寸。21:9 会按 400x171 这类展示比例插入；如果真实输出比例不同，画布不会纠正。
- 根因：显示尺寸来源是参数 schema fallback，而不是最终图片内容；auto insert 还把 fallback 作为优先值锁住。
- 关键证据：
  - /mnt/f/code/project/opentu/packages/drawnix/src/hooks/useAutoInsertToCanvas.ts:640-708: 先 getTaskMediaDimensions，再把 dimensions 作为 fallback 传入 getTaskImageDimensions。
  - /mnt/f/code/project/opentu/packages/drawnix/src/hooks/useAutoInsertToCanvas.ts:245-272 getTaskImageDimensions: 有 fallback 时直接返回，不读取 task.result.width/height。
  - /mnt/f/code/project/opentu/packages/drawnix/src/hooks/useAutoInsertToCanvas.ts:290-296 getTaskMediaDimensions: image 尺寸从 task.params.size/userParams 推导。
  - /mnt/f/code/project/opentu/packages/drawnix/src/utils/creative-image-display-size.ts:34-42 resolveCreativeImageDisplaySize: 只读取 size、userParams.aspectRatio、userParams.size。
  - /mnt/f/code/project/opentu/packages/drawnix/src/utils/size-ratio.ts:5-28 parseSizeToPixels: 默认宽度 400，按比例计算高度。
  - /mnt/f/code/project/new-api/controller/creative_image_tasks.go:66-75 creativeImageTaskDTO: DTO 无 width/height。
  - ……另有 2 条证据见 JSON 结果。
- 修复方向：后端 task DTO 或 content metadata 返回真实 width/height；前端下载 content 后 decode naturalWidth/naturalHeight 并写入 task.result。auto insert 最终尺寸应优先 natural dimensions，schema ratio 只作为 placeholder。
- 验证：mock managed image content 为 3840x1648，task.params.userParams.aspectRatio=21:9；当前 canvas element 应为 400x171。修复后应根据 natural ratio/目标 frame 规则得到一致尺寸。

### F4 — P2 — Resolution 映射是单向的，结果尺寸没有回流

- 现象：size/aspectRatio/resolution 已映射给 provider，但没有映射回画布显示状态。
- 影响：用户选择 2K/4K 会影响远端生成，但前端无法从 task result 知道实际像素或比例；后续 canvas、thumbnail、restore 只能猜。
- 根因：provider request 映射与前端 display state 断开，adapter result 只传 URL。
- 关键证据：
  - /mnt/f/code/project/new-api/service/creative_image_adapter.go:193-221 creativeDuomiSizeParam: aspectRatio + imageSize 映射 provider size，21:9 -> 1792x768，非 1K 强制回 1K。
  - /mnt/f/code/project/new-api/service/creative_image_adapter.go:260-282 creativeGrsAIAspectRatioParam/creativeGrsAIImageSizeParam: gpt-image-2/gpt-image-2-vip 把分辨率编码到 aspectRatio pixel value，不单独发 imageSize。
  - /mnt/f/code/project/new-api/service/creative_image_adapter.go:284-340 creativeGrsAIGPTImagePixelAspectRatio/table: gpt-image-2-vip 4K 21:9 -> 3840x1648 等 pixel 映射。
  - /mnt/f/code/project/new-api/service/creative_image_adapter.go:396-466 parseDuomiCreativeImageResult/parseGrsAICreativeImageResult: 成功只抽取 ResultURL，不解析 provider 返回图片尺寸。
- 修复方向：保留当前 provider 参数映射，但把 provider pixel target 和实际下载后的 natural dimensions 明确写入 task metadata/result，供画布与历史恢复使用。
- 验证：单元测试 creativeGrsAIGPTImagePixelAspectRatio 覆盖 21:9 4K；再测 task DTO/result，当前不会返回 width/height。修复后 DTO/result 应包含实际或目标尺寸。

### F5 — P1 — Retry 复用 taskId/idempotency key，语义混淆为旧任务 replay

- 现象：失败/timeout anchor 点击重试，不一定触发新的生成。
- 影响：timeout 后上游最终成功时，点击重试可能不发新 provider 请求而直接拿旧结果；真失败时也可能重放旧失败任务，表现为立即失败。
- 根因：前端 retry 清理的是本地字段，但幂等键仍绑定原 taskId；后端按幂等语义返回旧任务。
- 关键证据：
  - /mnt/f/code/project/opentu/packages/drawnix/src/services/media-executor/fallback-adapter-routes.ts:139-140 createCreativeImageTaskIdempotencyKey: 固定为 opentu-image-${taskId}。
  - /mnt/f/code/project/opentu/packages/drawnix/src/services/task-queue-service.ts:2280-2335 retryTask: 复用同一个 taskId，清 result/remoteId/insertedToCanvas 后重新 executeTask。
  - /mnt/f/code/project/opentu/packages/drawnix/src/services/task-queue-service.ts:1012-1076 executeTask image branch: 传 taskId: task.id 给 executor.generateImage。
  - /mnt/f/code/project/opentu/packages/drawnix/src/services/media-executor/fallback-adapter-routes.ts:240-254 executeCreativeManagedImageTask: submit 使用同一个 Idempotency-Key。
  - /mnt/f/code/project/new-api/controller/creative_image_tasks.go:631-683 creativePrepareImageTaskIdempotency: 同 key 同 payload 命中时直接返回旧 task DTO。
- 修复方向：区分“恢复/继续查询旧任务”和“重新生成”。真正 retry 应创建新 local taskId 或 retryAttempt 参与 idempotency key；恢复旧任务则应使用持久化 remoteId 并在 UI 文案中标明。
- 验证：mock 后端第一次 120s timeout、本地 failed，随后同 key GET/POST 返回旧 success 或 failed；断言当前 retry 没有新 provider submit。修复后 retryAttempt 应产生新 key，resume 则不应显示为重新生成。

### F6 — P1 — Managed Image 轮询窗口过短且 remoteId 不持久化

- 现象：Duomi/GrsAI 慢任务仍在上游生成时，本地节点已经 timeout/failed。
- 影响：慢 provider 任务会被本地误判失败；刷新后因为没有 remoteId，无法恢复远端生成状态。
- 根因：managed image path 没有 durable remoteId/resume 状态，且轮询窗口硬编码 120 秒。
- 关键证据：
  - /mnt/f/code/project/opentu/packages/drawnix/src/services/media-executor/fallback-adapter-routes.ts:272-318 executeCreativeManagedImageTask: 固定 for attempt < 120，每秒 poll，约 120s 后 throw timed out。
  - /mnt/f/code/project/opentu/packages/drawnix/src/services/media-executor/fallback-adapter-routes.ts:266-270: remoteTaskId 只写 LLM log metadata。
  - /mnt/f/code/project/opentu/packages/drawnix/src/services/media-executor/task-storage-writer.ts:291-305: 存在 updateRemoteId，但 managed image submit 路径未调用。
  - /mnt/f/code/project/opentu/packages/drawnix/src/services/media-executor/fallback-adapter-routes.ts:319-329: catch 统一 failTask。
- 修复方向：使用全局 image generation timeout/backoff 策略；submit accepted 后立即持久化 remoteId；刷新恢复时继续 poll。poll/content/cache 的 429/5xx 应退避重试，不应直接 fail。
- 验证：fake timer 让 submit accepted，poll 第 130 秒返回 success；当前应 failTask(timeout)。修复后应继续 poll 或进入 resumable pending，并保存 remoteId。

### F7 — P1 — Anchor Retry 不覆盖已完成后的渲染/缓存失败

- 现象：空白节点一旦被标记 inserted/completed，anchor 会完成并移除，后续失败不会重新打开 retry 状态。
- 影响：空白/被删除图片节点无法通过原 anchor 重试；用户可能只看到任务历史里“已完成/已插入”，没有可操作恢复入口。
- 根因：anchor retry 状态机只认识任务失败或 postProcessing failed，不认识 render/cache load failed。
- 关键证据：
  - /mnt/f/code/project/opentu/packages/drawnix/src/hooks/useImageGenerationAnchorSync.ts:78-88 derivePostProcessingStatus: insertedToCanvas 或 postProcessing completed 即判定 completed。
  - /mnt/f/code/project/opentu/packages/drawnix/src/hooks/useImageGenerationAnchorSync.ts:280-300 scheduleCompletedRemoval: completed anchor 延迟后删除。
  - /mnt/f/code/project/opentu/packages/drawnix/src/hooks/useAutoInsertToCanvas.ts:1642-1650 handleAnchorRetry: completed 且 insertedToCanvas/postProcessing completed 时直接 updateRetryAnchor('completed') 返回。
  - /mnt/f/code/project/opentu/packages/drawnix/src/hooks/useAutoInsertToCanvas.ts:1668-1683: 只有 FAILED/CANCELLED 或 completed+postProcessing failed 才 retryTask。
  - /mnt/f/code/project/opentu/packages/drawnix/src/utils/asset-cleanup.ts:59-60: cache miss 删除节点没有触发 postProcessing failed。
- 修复方向：图片加载失败或 cache miss 删除必须把 workflowCompletionService/taskQueue 状态改为 failed，并阻止 completed anchor 自动移除；retry action 应能从“已插入但渲染失败”恢复。
- 验证：插入后立即 markAsInserted，再让 RetryImage 最终 onError 并删除节点；当前 anchor 已 completed/removed。修复后 anchor 应转 failed 或保留 retry。

### F8 — P2 — DialogTaskList 手动插入未 markAsInserted

- 现象：同一生成图片通过对话框插入后，任务状态不显示已插入，可能重复插入。
- 影响：从 DialogTaskList 插入的结果不会设置 insertedToCanvas，任务仍可重复插入，anchor/任务列表状态与实际画布不一致。
- 根因：两个手动插入入口没有共享状态更新逻辑。
- 关键证据：
  - /mnt/f/code/project/opentu/packages/drawnix/src/components/task-queue/TaskQueuePanel.tsx:564-723 handleInsert: 手动插入成功后调用 taskQueueService.markAsInserted(taskId, 'manual')。
  - /mnt/f/code/project/opentu/packages/drawnix/src/components/task-queue/DialogTaskList.tsx:215-244 handleInsert: 插入 image/video 后只显示成功/失败消息，没有 markAsInserted。
  - /mnt/f/code/project/opentu/packages/drawnix/src/services/task-queue-service.ts:2541-2563 markAsInserted: 该函数是 insertedToCanvas 的统一写入口。
- 修复方向：DialogTaskList 插入成功后统一调用 taskQueueService.markAsInserted(taskId, 'manual')，并复用 TaskQueuePanel 的插入 helper，避免入口分叉。
- 验证：组件测试点击 DialogTaskList insert，mock insertImageFromUrl resolve；当前 markAsInserted 未调用。修复后应调用一次。

## 4. 用户实测问题覆盖表

| 用户问题 | 本轮结论 | 对应证据/缺陷 |
|---|---|---|
| U1 Duomi 上游仍在生成但前端 120s timeout | 已覆盖 | F6 / ranked #2：managed image poll 固定 120s，remoteId 未持久化。 |
| U2 点击重试不发新请求却显示旧图 | 已覆盖 | F5 / ranked #3：retry 复用 taskId 和 Idempotency-Key，被 NewAPI 幂等 replay。 |
| U3 失败节点重试立刻失败 | 已覆盖 | F5 + F7：旧失败 replay；render/cache failed 不回写 postProcessing failed。 |
| U4 failure reason 泛化为 creative image task failed | 已覆盖 | ranked #6：adapter 提取 FailReason，但 DTO/UI 未传递。 |
| U5 选中图片 dock 缩略图裂图 | 已覆盖为同类风险 | Cache Storage /__aitu_cache__ 不是 durable source；dock/TaskItem 应统一 rehydrate。 |
| U6 刷新画布 viewport 重置 | 已覆盖为独立 P2 | ranked #9：viewport-only/cloud sync refresh 生命周期不完整。 |
| U7 刷新后任务历史图片加载失败 | 已覆盖 | Cache Storage miss + 无 durableRef/contentRef/assetRef。 |
| U8 生成中小长条、成功后空白节点 | 已覆盖 | F1/F2/F3：placeholder 尺寸/真实图片 decode/cache load 与完成状态断开。 |

## 5. 跨层状态机 synthesis

1. OpenTU UI 选择 binding/userParams -> TaskQueue 创建本地任务 -> executor POST NewAPI，当前 Idempotency-Key 由 local taskId 固定生成。
2. NewAPI 解析 binding/adapter params -> 预扣费/submit provider -> provider accepted 后才写本地 Task/billing/outbox；accepted 与 durable recovery 之间存在不可恢复窗口。
3. OpenTU managed image poll 当前固定约 120s；submit 后 remoteTaskId 只写日志 metadata，未持久化为 image task 的 remoteId，刷新后不能可靠 resume。
4. NewAPI status/content GET 与 submit 同处 relay 限流组；poll 404/410/429/5xx、provider unknown status、content/cache 抖动没有清晰 terminal/retryable taxonomy。
5. content 下载后写入 Cache Storage 并保存 /__aitu_cache__/ 本地虚拟 URL；任务/board/UI 缺少 remoteTaskId/contentRef/assetRef 这样的 durableRef。
6. quickInsert 创建 image element 后即可 completePostProcessing/markAsInserted；真实图片 decode/cache load 发生在渲染层，失败不会回写 task/postProcessing。
7. RetryImage/SW/asset-cleanup 在 cache miss 后可能隐藏或删除节点，且根层删除与任务状态回滚脱节；nested/frame 内元素处理也不完整。
8. refresh/retry 生命周期应分成 resume old remote task 与 regenerate new task；当前 retry 复用 taskId/idempotency key，容易 replay 旧成功或旧失败。
9. viewport/workspace 变更还有独立刷新风险：viewport-only 未完整进入 visibilitychange、tab sync、NewAPI cloud outbox。

## 6. 三道审查门槛执行情况

- Gate 1 已满足：慢 provider 130s/150s/180s、120s timeout、remoteId/resume、retry/idempotency replay、Cache Storage miss、canvas blank/delete、anchor retry、natural dimensions、failure reason、provider adapter params、NewAPI durable backend、viewport refresh 均已覆盖。
- Gate 2 已满足：覆盖 OpenTU UI/TaskQueue/executor/Cache/SW/canvas/viewport 与 NewAPI relay/adapter/idempotency/task/billing/DTO 的跨层状态机。
- Gate 3 已满足到审计产物级别：每类风险都有明确 fake timer/mock cache/mock backend/contract/viewport 测试建议；但这些测试尚未在当前只读沙箱执行。
- synthesis verdict：审计层面通过三道 anti-regression gate：1) 已知问题覆盖完整，2) 已重建跨层状态机，3) 已给出可执行防回归验证清单。限制：本轮为只读静态审计，未运行 Vitest/Playwright/Go 测试，未调用 live provider，因此这不是发布通过结论。

## 7. 必补动态/自动化验证

1. Vitest fake timer：provider 第 130s/150s/180s 返回 success，断言本地不会在 120s fail，并且 remoteId 已持久化、刷新后可 resume。
2. Mock retry contract：resume 不 POST，只 GET 旧 remote task/content；regenerate 使用新 taskId 或 retryAttempt idempotency key，provider submit count 增加。
3. Mock Cache Storage miss：顶层与 frame/nested /__aitu_cache__ 图片均不得被静默删除；应 rehydrate 或进入 failed/retryable，并回写 task/postProcessing。
4. Image decode/natural dimensions：content 为 3840x1648 或 1792x768 时，markAsInserted 只在 decode 成功后发生，canvas size 使用 natural ratio/明确规则。
5. NewAPI fault injection：provider accepted 后 Task/outbox/idempotency completion 失败时存在 durable recovery record，重放不二次 submit，可继续查询或退款。
6. NewAPI route tests：status/content GET 不消耗模型提交限流；404/410/terminal provider error 入 failure/refund，429/5xx 使用 retry-after/backoff。
7. DTO/UI tests：failReason/errorCode 经过脱敏传到 OpenTU task.error，且不泄露 key、cookie、CSRF、nonce、signed URL 或 provider secret。
8. Provider contract tests：Nano Banana schema allowed-values、auto dry-run/live parity；Duomi/GrsAI target pixel mapping 与 result metadata/width/height 回流。
9. Viewport/browser smoke：pan/zoom 后立即 visibilitychange hidden/reload/tab sync，断言 viewport 与 NewAPI cloud pending mutation 不丢。
10. DialogTaskList component test：插入成功后 markAsInserted(taskId, 'manual') 调用一次。

## 8. 建议修复顺序

1. 先修 durable identity：NewAPI accepted recovery record + OpenTU image remoteId/invocationRoute 持久化 + resumePendingTasks image 分支。
2. 拆分 retry 语义：resume 查询旧 remote task，regenerate 创建新 local taskId 或 retryAttempt idempotency key。
3. 统一 timeout/backoff/error taxonomy：使用 15min image timeout 或 provider TTL；GET status/content 免模型提交限流；429/5xx/cache 写失败进入 retryable/resumable。
4. 修 Cache Storage 生命周期：保存 durableRef，SW/unified cache/TaskItem/dock/canvas cache miss 走 rehydrate；失败时保留占位并回写 failed/retryable，不自动静默删除。
5. 修 canvas 成功门槛：markAsInserted/completePostProcessing 必须等待 cached blob 或 Image decode；失败不置 completed，anchor 保留 retry。
6. 补尺寸回流：NewAPI DTO/result 或 OpenTU content decode 写入真实 width/height；canvas display size 优先 natural dimensions，schema ratio 只作 placeholder。
7. 补 provider/binding contract：Nano Banana allowed values 与 dry-run/live parity；Duomi/GrsAI target pixel 与实际 result metadata 对齐。
8. 最后修 viewport/cloud outbox 与 DialogTaskList markAsInserted 分叉。

## 9. 主会话复核记录

- 已抽查 `fallback-adapter-routes.ts`：确认 `opentu-image-${taskId}` 固定幂等键、`for attempt < 120` 固定轮询窗口；另有 `updateRemoteId` 但 managed submit 主路径未作为 durable image remoteId 使用。
- 已抽查 `useAutoInsertToCanvas.ts` + `data/image.ts`：确认 `completePostProcessing`/`markAsInserted` 早于真实 image decode；`skipImageLoad && referenceDimensions` 且 `lockReferenceDimensions=true` 时不更新自然尺寸。
- 已抽查 `asset-cleanup.ts` + SW：确认 Cache Storage miss 会进入 `removeElementFromBoard`，但删除与 task/postProcessing 状态回写脱节。
- 已抽查 `creative_image_tasks.go` + `creative_image_adapter.go`：确认 DTO 不带 width/height；adapter 有 FailReason，但 DTO/UI 仍存在丢失链路；NewAPI 幂等命中会返回旧 task DTO。

## 10. 限制与不能过度声称的内容

- 没有 live 调用 Duomi/GrsAI，本报告确认的是代码状态机与可复现路径，不代表所有 provider 实际响应都已动态覆盖。
- 没有运行浏览器刷新/Cache Storage/viewport smoke；这些必须在修复后作为验收测试执行。
- 本轮使用已知问题文件作为覆盖清单，避免漏掉用户复现；但关键 finding 均重新从当前源码取证，不是仅复述旧报告。
