# Creative 当前项目全面深度审查报告

日期：2026-06-21  
范围：`/mnt/f/CODE/Project/new-api` (`feat/creative-embed`) + `/mnt/f/CODE/Project/opentu` (`feat/creative-embed`) + 当前 staging 只读 smoke。  
目标：审查当前 Creative 嵌入 NewAPI 是否达成产品目标、是否存在真实用户体验/业务/可靠性问题；不是只复查历史修复项。

## 审查方法与证据

- 主会话静态复核：后端路由/鉴权/模型绑定/adapter/任务状态，前端模型选择/参数 UI/提交链路/任务队列/画布插入/云同步/设置。
- 动态工作流：
  - `.codex-flow/generated/creative-current-experience-full-audit-20260621.workflow.ts`
  - `.codex-flow/generated/creative-current-experience-continuation-20260621.workflow.ts`
  - `.codex-flow/generated/creative-current-experience-remaining-ui-cloud-20260621.workflow.ts`
- Journal：
  - `.codex-flow/journal/creative-current-experience-full-audit-20260621.jsonl`
  - `.codex-flow/journal/creative-current-experience-continuation-20260621.jsonl`
  - `.codex-flow/journal/creative-current-experience-remaining-ui-cloud-20260621.jsonl`
- 主会话反证：部分子流程早期声称 staging `39084` 不可达；主会话 curl 已验证 staging 可达，因此未采纳该结论。
- 未做 live provider 调用；未读取/打印 provider key、cookie、CSRF、nonce。

## 当前结论

当前项目**还未达到可发布的稳定嵌入目标**。核心链路已经具备：NewAPI session bootstrap、NewAPI 模型 catalog、Creative model binding、Duomi/GrsAI adapter parameter schema、OpenTU 参数下拉与 typed `userParams` 提交流程。  
但存在多项会直接影响真实体验的问题：任务丢失/轮询限流/刷新不可恢复、画布空白或比例错误、admin binding 配置不可恢复、旧 GitHub/Gist 云同步仍能后台运行、备份恢复不会进入 NewAPI 云同步、dist provenance 落后。

## HIGH / P0-P1

### H1. Live provider accepted before durable persist，可能丢任务

**症状**：上游已经接收生成任务，但 NewAPI 本地 task/idempotency/billing 持久化失败时，用户得到 500/409，刷新后查不到任务；上游可能仍在生成，结果不可恢复。

**证据**：
- `new-api/controller/creative_image_tasks.go:263-282` 先调用 `SubmitCreativeImageProviderTask`。
- `new-api/controller/creative_image_tasks.go:349-380` 后续才 `creativeImageTaskInsertWithBilling`、complete idempotency、process outbox。

**建议**：提交前先 durable accepted/outbox，或 provider accepted 后必须写入 recovery record；idempotency complete、task insert、billing outbox 需要同一耐久事务/补偿路径。

### H2. Creative image status/content GET 被模型请求限流，轮询会误失败

**症状**：前端每秒轮询 `/images/tasks/:id`，如果模型请求限流开启，GET 状态/内容也消耗或命中 `ModelRequestRateLimit`，用户看到生成中突然 429/失败，但上游任务可能仍成功。

**证据**：
- `new-api/router/web-router.go:90-99` `/creative/relay/v1` group 统一挂 `ModelRequestRateLimit`。
- `new-api/router/web-router.go:110-115` image task POST/GET/content 均在该 group 下。
- `new-api/middleware/model-rate-limit.go:166-199` 无 GET/path 豁免。
- `opentu/.../fallback-adapter-routes.ts:302-315` 前端每 1s 轮询。

**建议**：GET status/content 从 model request rate limit 中拆出；只对 submit/generation 类请求限流。前端也要实现 429/5xx retry/backoff。

### H3. Managed image submit 后不持久化 remoteId，刷新后不可恢复

**症状**：任务提交成功后，页面刷新/中断时无法恢复轮询，只能失败或丢失状态。

**证据**：
- `opentu/.../fallback-adapter-routes.ts:262-270` submit 后只更新 LLM log metadata。
- 同文件 video path `:580-588` 有 `taskStorageWriter.updateRemoteId`，image path 没有等价调用。
- `opentu/.../fallback-executor.ts:1211-1270` 恢复逻辑主要筛选有 `remoteId` 的 video task。

**建议**：image task accepted 后立即 `updateRemoteId` 并保存 invocation route；实现 image pending resume 轮询。

### H4. Managed image 429/5xx/cache 写入失败直接 fail，无 retry/backoff

**症状**：短暂网络抖动、限流或 cache 写入失败会把实际可能成功的任务标记失败。

**证据**：
- `opentu/.../fallback-adapter-routes.ts:157-167` non-ok 直接 throw。
- `opentu/.../fallback-adapter-routes.ts:184-205` content 下载成功后 cache 写失败也 throw。
- `opentu/.../fallback-adapter-routes.ts:319-329` catch 统一 `failTask`。

**建议**：submit/poll/content 按 `Retry-After` + 指数退避重试；cache write failure 不应等同 provider generation failure，可降级保留 blob/object URL 或标记“生成成功但本地缓存失败”。

### H5. Stored-read 对 `creative.model_bindings` 校验过严，admin GET 可 500

**症状**：旧 schema、null `parameterSchema`、删除 canary group、channel 后续撞 ID 等都会让 admin binding 页面无法打开，UI 内无法修复。

**证据**：
- `new-api/service/creative_model_capability.go:782` stored read 直接 parse。
- `new-api/service/creative_model_capability.go:1177` stored read 仍 strict validate。
- `new-api/controller/creative_model_bindings.go:18-20` admin GET 错误直接 500。
- generic option 更新 `creative.model_bindings` 被拒绝，只能专用接口恢复。

**建议**：读取/恢复与保存校验拆分。admin GET 应返回 raw config、cleaned config、diagnostics；runtime catalog fail-closed 跳过坏 binding，不让整个配置不可读。

### H6. Channel 更新路径可制造 Creative binding ID collision

**症状**：binding 保存时不冲突，但 channel 后续新增同名 model 后绕过校验，下一次读取 binding 配置失败或 catalog 展示分裂。

**证据**：
- binding validate 阶段检查当前 abilities collision。
- `new-api/model/channel.go:566-571` `Channel.Update` 重建 abilities 但无 Creative binding collision guard。
- `new-api/model/channel.go:832-836` `EditChannelByTag` 同样无 guard。

**建议**：channel update / batch update / upstream model sync 路径加 Creative binding collision guard；或自动将冲突 binding 标记 stale/disabled diagnostics。

### H7. 旧 GitHub/Gist 云同步在 embedded mode 仍可后台运行

**症状**：用户浏览器残留 standalone OpenTU 的 GitHub/Gist token/config 时，在 NewAPI embedded Creative 中保存/删除画板或打开素材库，会静默触发旧 Gist 同步；用户以为使用的是 NewAPI 云同步。

**证据**：
- `opentu/.../workspace-service.ts:1311-1332` workspace event 直接动态 import old `github-sync/sync-engine`，只检查 `tokenService.hasToken()`，无 embedded guard。
- `opentu/.../DeferredMediaLibraryModal.tsx:7-12` embedded 可访问的素材库仍包 `GitHubSyncProvider`。
- `opentu/.../GitHubSyncContext.tsx:245-289` 有 token 时会 validate 并 pull remote。
- `opentu/.../MediaLibraryGrid.tsx:1433-1444` 旧“同步”按钮仍可出现。

**建议**：embedded mode 在 service 层硬禁用 legacy GitHub sync，而不是只隐藏入口。guard `workspace-service.triggerSyncMarkDirty`、`DeferredMediaLibraryModal`、`GitHubSyncProvider`、素材/任务旧同步按钮。

### H8. Backup/Restore 在 embedded 中只写本地，不触发 NewAPI 云同步

**症状**：用户恢复备份后本地能看到画板，但 NewAPI cloud sync 没收到恢复内容；换设备/刷新云端后可能丢。若之前已有云保存，badge 还可能继续显示“已同步到云端”。

**证据**：
- `opentu/.../backup-restore-dialog.tsx:300-317` embedded restore 后直接提示“导入成功”。
- `opentu/.../backup-import-service.ts:457,471` 直接 `workspaceStorageService.saveBoard()`。
- `opentu/.../backup-import-service.ts:200-202` 只 `workspaceService.reload()`。
- `opentu/.../creative-document-sync.ts:817-839` 只处理 `boardCreated/boardUpdated/boardDeleted`，不处理 `treeChanged`。

**建议**：embedded restore 后显式 enqueue restored boards 到 `CreativeDocumentCloudSyncService`，或改走 workspaceService 会发 boardCreated/boardUpdated 的 API；flush 前 badge 显示“本地已恢复，等待云同步”。

### H9. 画布插入可把未验证图片节点标记成功，导致空白节点

**症状**：生成成功后画布出现空白节点，但任务/后处理显示完成。

**证据**：
- `opentu/.../canvas-insertion.ts:138-155` 图片插入默认 `skipImageLoad=true` 且 `lockReferenceDimensions=true`。
- `opentu/.../data/image.ts:391-398` skip load 时不验证图片实际可加载。
- `opentu/.../useAutoInsertToCanvas.ts:981-988` quickInsert 后直接 `completePostProcessing` + `markAsInserted`。

**建议**：图片插入应至少在 post-processing 完成前验证可加载；失败时保留任务可重试，不 mark inserted；或异步加载失败后更新任务/anchor 状态。

## MEDIUM

### M1. 生成占位/最终显示尺寸优先使用 schema fallback，可能变成小长条或比例不准

**证据**：
- `opentu/.../useAutoInsertToCanvas.ts:245-272` `getTaskImageDimensions` 一旦有 fallback 直接返回，不读 `task.result.width/height`。
- `opentu/.../creative-image-display-size.ts:34-42` 只从 `size/userParams.aspectRatio` 推导显示比例。
- `opentu/.../size-ratio.ts:5-28` 默认宽度 400；21:9 会显示为约 `400x171` 的长条。

**建议**：完成后优先用实际图片 natural width/height 或 provider result width/height；占位可按比例，但最终不应锁死 schema fallback。

### M2. DialogTaskList 手动插入未 markAsInserted，可能重复插入

**证据**：`TaskQueuePanel` 多处手动插入后 `markAsInserted`，`DialogTaskList` 未见等价调用。

**建议**：所有手动插入入口统一走 taskQueueService mark path。

### M3. 运行中任务依赖当前 channel endpoint，管理员改 BaseURL 会让旧任务 fail-closed

**症状**：任务提交到旧 endpoint 后，管理员更新 channel BaseURL，轮询时当前 endpoint != saved endpoint，旧任务失败/退款，结果不可取。

**建议**：运行中任务应使用 task private data 中的 endpoint/key snapshot 完成轮询，或提供明确迁移/废弃策略。

### M4. Provider poll 非 2xx 错误分类不足，可能长期 in_progress

**症状**：上游 404/410/terminal error 被当作 reconcile error 记录，用户持续看到旧状态。

**建议**：adapter poll 错误分类，404/410/明确 terminal error 应转终态并退款/结算。

### M5. manifest / idle-prefetch / cdn-config 缓存过长

**证据**：staging 只读 smoke：`/creative/manifest.json`、`/creative/idle-prefetch-manifest.json`、`/creative/cdn-config.js` 为 `max-age=604800`；`sw.js` 和 `version.json` 是 no-cache。

**建议**：Creative boot/config 相关静态资源 no-cache 或短缓存，避免旧 PWA metadata/prefetch/config 持续影响。

### M6. dist provenance 落后于 opentu HEAD

**证据**：当前 `opentu` HEAD 为 `3f139164`，但三份 dist `version.json` 均为 `17cea8a4`。dist bundle 中已有部分新 marker，说明不能单靠 marker 判断；但发布追踪不可可靠证明。

**建议**：重建 opentu dist，同步到 `new-api/web/creative/dist` 与 `new-api/router/web/creative/dist`，并保证 `version.gitCommit` 指向真实 opentu HEAD。

### M7. `/creative` shell 未登录可进入，登录语义不清

**症状**：未登录用户能看到 Creative shell/canvas，但 bootstrap/models/API 为 401；用户可能误以为服务异常或先创作只存在本地浏览器的内容。

**证据**：
- `new-api/router/web-router.go` serveCreative 静态 shell 无 UserAuth。
- `/creative/api/*` 有 session auth。
- `opentu/.../creative-session-broker.ts` bootstrap 401 后安装 unavailable profile。
- badge 文案为“云同步不可用 · 已保存到此浏览器”，不是“请登录 NewAPI”。

**建议**：要么 `/creative` shell 也要求登录并跳转；要么 bootstrap 401 时首屏显示登录要求 overlay，不进入正常画布。

### M8. Creative model id 大小写策略不一致

**症状**：`Gpt-image-2` 与 `gpt-image-2` 在 channel、binding、policy、catalog 中行为分裂；admin default/recommended 可能 stale，或用户看到两个近似模型。

**证据**：
- `new-api/service/creative_model_capability.go:1598-1622` channel model/mapping exact string lookup。
- `new-api/service/creative_model_capability.go:1703-1718` live template provider model id 使用 canonical 小写。
- `new-api/service/creative_model_policy.go:458-505` policy availability exact match。
- `new-api/controller/creative.go:1423-1438` catalog dedupe exact id。

**建议**：明确 Creative logical/provider model id 是否大小写敏感。推荐对 provider-contract 模型做 canonical matching，并回写真实可执行 id；catalog dedupe 与 policy availability 使用同一 canonical key。

### M9. nano-banana allowed values / `auto` live-dry-run 不一致

**证据**：
- `new-api/service/creative_model_capability.go:2068-2069` nano-banana 只限制字段 ID。
- allowed values 只覆盖 `grsai_gpt_image` / `grsai_gpt_image_vip`。
- schema default `aspectRatio=auto`；dry-run 省略 auto，但 live submit 会发送 `aspectRatio:"auto"`。

**建议**：补 `grsai_nano_banana` allowed values；决定 auto provider contract，并让 live/dry-run 一致。

## 已确认正常 / 非问题

- 未登录访问 `/creative/` 只得到 SPA shell；`/creative/api/bootstrap`、`/creative/api/models`、relay API 未登录均 401，未发现凭证泄漏。
- Duomi/GrsAI GPT image 参数主链路源码可成立：NewAPI 模板包含 `aspectRatio`、`imageSize`、`quality`；OpenTU `ParametersDropdown` 会逐项渲染所有 `compatibleParams`；提交时转成 typed `userParams`。
- GrsAI `gpt-image-2` 被限制 1K，`gpt-image-2-vip` 支持 1K/2K/4K；quality 非 auto 透传。
- OpenTU 正常 dropdown 选择会保留 `new-api-creative` source/profile，主链路未发现裸 model id 绕过 managed profile。
- 常见模型 id 会生成 shortCode，`#img` 不是正常主链路必然问题；只有 catalog 缺失/模型不可用/无法生成 shortCode 时会 fallback。

## 推荐修复顺序

1. **任务可靠性组合修**：H2 + H3 + H4，先解决 status/content GET 限流、remoteId 持久化/resume、429/5xx retry/backoff。
2. **画布显示修**：H9 + M1 + M2，防空白节点、最终尺寸用真实图片、统一 markAsInserted。
3. **配置恢复性修**：H5 + H6 + M8，admin read fail-soft、channel update collision guard、大小写 canonical 策略。
4. **云同步语义修**：H7 + H8 + M7，embedded 硬禁旧 GitHub sync，restore 入 NewAPI sync queue，未登录首屏/文案明确。
5. **发布工件修**：M5 + M6，重建 dist、校准 version provenance、缩短 Creative config cache。
6. **provider 细节修**：M3 + M4 + M9，运行中 endpoint snapshot 策略、poll 错误分类、nano-banana 参数契约。

## 后续验证建议

- 单元/集成：NewAPI binding stale read、channel update collision、case-variant policy/binding、nano-banana allowed values、image task rate-limit bypass。
- 前端：参数下拉三参数同窗、selectedParams -> userParams、image remoteId persistence、429 retry、canvas image load failure 不 mark success。
- Browser smoke：
  - 未登录 `/creative` 显示登录要求或跳转。
  - embedded mode 预置 `github_sync_token` 后不得请求 `https://api.github.com`，不得显示旧 Gist 同步按钮。
  - backup restore 后 NewAPI cloud sync pending mutation 增加，flush 前 badge 不显示 cloud-saved。
- Staging：重建 dist 后核对 `version.json.gitCommit == opentu HEAD`，再执行登录态模型/参数/生成 mock 或 provider-authorized smoke。
