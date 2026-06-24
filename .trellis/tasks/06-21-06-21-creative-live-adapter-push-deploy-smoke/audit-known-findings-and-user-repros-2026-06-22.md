# Creative 审查发现与实测缺陷汇总（再审输入）

日期：2026-06-22  
任务：`06-21-creative-live-adapter-push-deploy-smoke`  
范围：`../new-api` + `../opentu`，当前项目编排目录为 `new2fly`。  
用途：把此前深度审查发现、用户实测问题、以及审查方法缺陷落盘，作为后续修复和再审的输入。后续再审必须独立重建目标与链路，不能只复核本文件。

## 1. 已有深度审查发现摘要

来源：`.trellis/tasks/06-21-06-21-creative-live-adapter-push-deploy-smoke/current-project-deep-audit-2026-06-21.md`

### HIGH / P0-P1

1. **Live provider accepted before durable persist，可能丢任务**
   - 上游已接受任务后，NewAPI 本地 task/idempotency/billing 持久化失败会导致用户不可恢复。
   - 关键路径：`new-api/controller/creative_image_tasks.go` live submit 先 provider submit，再本地插入和 billing outbox。

2. **Creative image status/content GET 被模型请求限流，轮询会误失败**
   - `/creative/relay/v1/images/tasks/:id` 与 `/content` GET 在统一 relay group 下，可能被模型限流误伤。
   - 前端当前 1s 轮询，429/5xx 没有足够 backoff/recovery。

3. **Managed image submit 后不持久化 remoteId，刷新后不可恢复**
   - image path submit 后只写 LLM log metadata，未像 video path 一样写 `taskStorageWriter.updateRemoteId`。
   - 刷新/中断后无法恢复远端轮询。

4. **Managed image 429/5xx/cache 写入失败直接 fail，无 retry/backoff**
   - poll/content/cache 任一临时错误直接 `failTask`。
   - cache 写入失败被当作 provider 生成失败。

5. **Stored-read 对 `creative.model_bindings` 校验过严，admin GET 可 500**
   - 坏配置/旧 schema/null 字段会让配置页不可读，无法通过 UI 修复。

6. **Channel 更新路径可制造 Creative binding ID collision**
   - binding 保存时做 collision 校验，但 channel 后续更新模型列表未做等价 guard。

7. **旧 GitHub/Gist 云同步在 embedded mode 仍可后台运行**
   - embedded Creative 中如果浏览器残留旧 token/config，可能静默触发旧 Gist 同步。

8. **Backup/Restore 在 embedded 中只写本地，不触发 NewAPI 云同步**
   - 导入备份后仅本地 IndexedDB 更新，不一定进入 NewAPI cloud sync queue。

9. **画布插入可把未验证图片节点标记成功，导致空白节点**
   - 插入时可 `skipImageLoad=true`，post-processing 直接 complete/markAsInserted。

### MEDIUM

1. **生成占位/最终显示尺寸优先使用 schema fallback，可能变小长条或比例不准**。
2. **DialogTaskList 手动插入未 markAsInserted，可能重复插入**。
3. **运行中任务依赖当前 channel endpoint，管理员改 BaseURL 会让旧任务 fail-closed**。
4. **Provider poll 非 2xx 错误分类不足，可能长期 in_progress**。
5. **manifest / idle-prefetch / cdn-config 缓存过长**。
6. **dist provenance 落后于 opentu HEAD**。
7. **未登录 `/creative` shell 可进入，登录语义不清**。
8. **Creative model id 大小写策略不一致**。
9. **nano-banana allowed values / `auto` live-dry-run 不一致**。

## 2. 用户实测发现（2026-06-22）

这些是实际体验路径发现的问题，不应被视为偶发或低优先级。它们暴露的是 Creative async image lifecycle、retry、cache、canvas 和 workspace restore 的端到端状态机缺陷。

### U1. Duomi 慢任务超过前端固定轮询窗口，被本地误判 timeout

**现象**：Duomi 还在生成中时，OpenTU 节点已经显示失败：`creative image task timed out`；Duomi 日志随后最终生成成功。

**已确认代码线索**：
- `opentu/packages/drawnix/src/services/media-executor/fallback-adapter-routes.ts`
- `executeCreativeManagedImageTask` 中固定 `for (let attempt = 0; attempt < 120; attempt++)`，每次 1 秒，约 2 分钟后直接 `throw new Error('creative image task timed out')`。
- 常量 `IMAGE_GENERATION_TIMEOUT_MS = 15 * 60 * 1000` 存在，但该 managed image path 未使用。

**审查要求**：必须模拟 provider 130s/150s/180s 后成功的慢异步任务；不能只跑快速 mock。

### U2. timeout 后上游最终成功，点击“重试”没有发新请求，却显示原先图片

**现象**：对 timeout 失败节点点击重试，马上显示生成动画/载入动画，实际没有发出新的 provider 请求，然后显示原先成功图片。

**高概率链路**：
- 前端本地任务 status=failed；NewAPI 后端任务仍在 provider poll 中并最终 success。
- `retryTask` 复用原 task id。
- managed image submit 使用固定 `Idempotency-Key: opentu-image-${taskId}`。
- 后端 idempotency 命中后可能返回原任务 DTO，而不是创建新 provider 请求。

**审查要求**：必须区分“继续查询/恢复结果”和“重新生成”。真重新生成应使用新的 taskId/idempotency key；继续查询应明确使用 remote task id/content endpoint。

### U3. 真失败节点点击重试，马上重新失败且没有实际重试

**现象**：失败图片节点点击重试，立刻回到失败，没有 provider 请求。

**可能原因**：
- 复用旧 idempotency key 返回已失败任务；
- task params/remoteId/cache state 没有恢复；
- retry path 复用旧错误结果或被前端 blocked/executing state 抵消。

**审查要求**：必须检查 retry 的 UI action、TaskQueueService、executor、NewAPI idempotency、后端 task terminal 状态的完整交互。

### U4. 除 timeout 外，所有失败只显示 `creative image task failed`，真实失败原因丢失

**现象**：失败原因无法定位，UI 只显示泛化错误。

**已确认代码线索**：
- `fallback-adapter-routes.ts` 中 `isCreativeImageTaskFailed(current.status)` 后直接 `throw new Error('creative image task failed')`。
- `new-api/controller/creative_image_tasks.go` 的 creative image task DTO 未返回 `fail_reason`。

**审查要求**：后端 DTO、provider adapter、前端 task.error 必须保留可安全展示的失败原因，同时避免泄露 key/baseURL/签名 URL。

### U5. 选中图片节点在 dock/输入框缩略图是裂图

**现象**：选中生成图片后，dock 中缩略图无法加载。

**可能链路**：
- 图片节点引用 `/__aitu_cache__/image/...` 本地虚拟路径；
- Cache Storage miss 或 SW 初始化/thumbnail 生成时序不稳定；
- dock/输入框读取缩略图未触发 remote content 重新 hydrate。

**审查要求**：必须审查 selected image -> dock thumbnail -> `RetryImage`/`useThumbnailUrl`/Cache Storage/SW fallback 的完整链路。

### U6. 刷新画布后 viewport 被重置到同一个位置

**现象**：刷新页面后画布不保留刷新前 pan/zoom 位置。

**已确认代码线索**：
- `apps/web/src/app/app.tsx` 有 `handleViewportChange` debounce save 和 close snapshot 逻辑。
- 需要验证 `onViewportChange` 是否在实际 scroll/pan/zoom 路径触发，debounce 是否落盘，初始化/同步/切板是否覆盖 viewport。

**审查要求**：必须把 viewport 当作独立持久化状态验收；刷新、pagehide、visibilitychange、tab sync 都要检查。

### U7. 刷新后任务记录图片先变载入动画，随后“图片加载失败”

**现象**：任务记录中的已生成图片刷新后不可加载。

**可能链路**：
- task.result.url 只保存本地 `/__aitu_cache__` URL；
- Cache Storage 缺失或 key 不一致；
- task 未保存 remoteId/content endpoint，无法远端重新下载；
- thumbnail cache 和 image cache 生命周期不一致。

**审查要求**：必须做刷新恢复端到端验收：IndexedDB task -> result URL -> Cache Storage -> SW route -> thumbnail -> UI -> fallback remote hydrate。

### U8. 画布生成中/成功后的节点尺寸与真实比例不一致，可能显示为小长条/空白节点

**现象**：生成中不是按真实比例显示；成功后可能画布空白节点。

**已知关联**：此前审查 H9/M1 已命中“插入未验证”和“fallback 尺寸锁死”。

**审查要求**：占位尺寸、最终 natural size、canvas element referenceDimensions、post-processing success 状态必须一致验证。

## 3. 本轮必须修正的审查方法缺陷

后续所有 Creative 深度审查必须加入以下三条强制门槛：

1. **必须包含真实慢 provider 动态时序测试**
   - 至少覆盖 provider 130s/150s/180s 后成功、临时 429/5xx 后恢复、content cache 写失败但 provider 成功等情形。
   - 可用 fake timer/mock provider，不要求真实等待或 live provider 调用。

2. **分支审查后 synthesis 必须强制做跨层状态机验证**
   - synthesis 不能只是汇总分支结果；必须重建从 UI action 到 backend task 到 provider 到 local storage/cache/canvas 的状态迁移图。
   - 对每个终态判断是否有 durable source of truth、可恢复路径、用户可理解文案。

3. **必须把刷新恢复、重试语义、Cache Storage 生命周期作为一条端到端链路验收**
   - 覆盖：刷新页面、切板、service worker 未就绪、Cache miss、thumbnail miss、任务历史恢复、dock 缩略图、canvas image node、manual retry、resume polling、new generation。

## 4. 再审执行要求

重新全面深度审查时：

- 不要只验证历史修复是否完成；目标是判断当前项目是否达成 Creative 嵌入 NewAPI 的产品目标，是否存在新问题。
- 本文件只能作为 seed checklist；必须独立阅读代码、重建目标、追踪跨层数据流。
- 必须输出每个发现的：症状、用户影响、可复现路径、证据文件/函数、根因、建议修复、验证用例。
- 不能声称通过，除非至少完成：静态代码追踪 + 慢 provider mock/测试设计 + 刷新/重试/cache/canvas/viewport 生命周期检查。
