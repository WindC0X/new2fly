# new2fly / new-api / opentu Creative 集成深度审查报告

日期：2026-06-11  
任务：`.trellis/tasks/06-11-newapi-opentu-deep-audit`  
目标项目：`/mnt/f/code/project/new2fly`（编排与合同）；实现仓库：`../new-api`、`../opentu`

## 1. 结论摘要

本次审查是**重新生成并运行动态工作流后的新鲜审查**。未把历史审计报告、归档任务输出、`.codebuddy` 报告、旧 Trellis 报告或 prior assistant 结论作为证据。证据来自：

- 当前 `new2fly/.trellis/spec/backend/creative-*.md` 与 `new2fly/.trellis/spec/frontend/creative-*.md`；
- 当前 `../new-api` 与 `../opentu` 源码、测试、配置、包脚本；
- 本任务新生成的 `codex-flow` journal 和主会话复核的源码行号；
- 本轮实际执行的目标测试命令。

总体判定：**项目开发目标尚未完全达成**。`new-api` 与 `opentu` 已经实现了相当多的主路径能力（Creative routes、browser-session relay、nonce、资产上传/下载、Video/Suno/MJ session-broker 适配、MJ image proxy、部分测试），但仍存在多处会破坏 `new2fly` Creative 集成合同的高风险缺口，主要集中在：

1. 生产路由部署模式可完全绕过 `/creative` 路由注册；
2. 异步任务提交、终态轮询、计费/退款 CAS 的原子性和可恢复性不足；
3. Suno fetch 可序列化非 Suno 任务并暴露 MJ 私有结果；
4. 资产同步 quota / delete / hydrate / URL 发现仍有合同级缺陷；
5. 前端 session-broker 对 Suno lyrics `notifyHook`、Video unsupported submit 错误清洗、缺 nonce 本地 fail-fast 仍不完整；
6. 测试矩阵虽已有不少覆盖，但未证明上述合同不变量。

## 2. 动态工作流与验证状态

### 2.1 动态工作流

- 主 workflow：`.codex-flow/generated/newapi-opentu-deep-audit.workflow.ts`
- 主 journal：`.codex-flow/journal/newapi-opentu-deep-audit.retry-20260611142733.jsonl`
- 主 workflow 结果：12 个分支中 8 个结构化成功、4 个超时，最终 synthesis 失败。
- 已抽取成功分支到：`.trellis/tasks/06-11-newapi-opentu-deep-audit/research/*.json`
- 补充分支 workflow：`.codex-flow/generated/newapi-opentu-deep-audit-supplement.workflow.ts`
- 补充分支 journal：`.codex-flow/journal/newapi-opentu-deep-audit-supplement.jsonl`
- 补充分支状态：6 个分支均超时；未把其非结构化日志作为最终结论证据。

超时分支的覆盖缺口由主会话对当前源码进行定向复核补足，尤其是前端异步媒体流、跨仓 DTO/生命周期、安全对抗面和测试覆盖。

### 2.2 已运行验证命令

在 `../new-api` 运行（通过）：

```bash
GOCACHE=/mnt/f/code/project/new2fly/.cache/go-build \
GOTMPDIR=/mnt/f/code/project/new2fly/.cache/go-tmp \
GOMODCACHE=/home/windc0x/go/pkg/mod \
go test ./middleware ./router ./model ./service ./relay/constant ./relay/common ./relay/channel/task/mj \
  -run 'Creative|Suno|MJ|Midjourney|Task|Asset|Billing|Affinity|Relay|SetWebRouter' -count=1
```

结果：`middleware/router/model/service/relay/constant/relay/common/relay/channel/task/mj` 均 `ok`。

在 `../opentu` 运行（通过；`.npmrc` 因缺少 `${NPM_TOKEN}` 有 warning，部分测试 stderr 打印 `localStorage is not defined` 的初始化警告，但测试最终通过）：

```bash
pnpm exec vitest run \
  packages/drawnix/src/services/__tests__/video-api-service.session-broker.test.ts \
  packages/drawnix/src/services/__tests__/audio-api-service.test.ts \
  packages/drawnix/src/services/model-adapters/mj-image-adapter.test.ts \
  apps/web/src/sw/creative-asset-pass-through.spec.ts \
  --no-file-parallelism --maxWorkers=1 --minWorkers=1
```

结果：4 个 test files、26 个 tests 通过。

> 注意：这些测试证明已有正向覆盖仍能通过，但不覆盖本报告所有高风险场景；不能据此判定开发目标已完成。

## 3. 开发目标达成度矩阵

| 目标合同 | 达成度 | 证据摘要 | 主要缺口 |
|---|---:|---|---|
| Backend Creative route surface | 部分达成 | `router/web-router.go:56-119` 注册 `/creative/api`、`/creative/relay/v1/videos|suno|mj`；`middleware/creative.go:95-129` nonce；`controller/creative.go:739-938` idempotency | `FRONTEND_BASE_URL` 模式跳过 `SetWebRouter`；same-origin 信任客户端 `X-Forwarded-*` |
| Creative Asset Sync 后端 | 部分达成 | `service/creative_asset.go` 有上传、S3/DB storage、MIME/大小校验、owner get/delete；`controller/creative_asset.go` route 使用 session+nonce | quota 非原子；delete 先删 DB 后删对象；cache header；S3 health 不足；DTO 字段漂移 |
| Creative Asset Sync 前端 | 部分达成 | `creative-document-assets.ts` 做深拷贝 rewrite、unsafe URL 检查、hydrate；SW 对 `/creative/api/assets/*` pass-through | URL 发现漏 generated image/video 与 posters/covers/clips 字符串数组；hydrate 无 cloud ref 时跳过 unsafe URL 检查；SW 仅源码顺序测试 |
| Async Video backend | 部分达成 | `CreativeVideoRelayGate` 默认关闭；`RelayTask` buffer response；owner status/content；stored key 在 content proxy 多数路径强制 | submit task/idempotency/billing 非事务；settle failure 仍 flush；channel lookup failure bulk failure no refund；status 路径可能 fallback current key |
| Async Video frontend | 部分达成 | session-broker 空 key、canonical `/videos`、status/content no direct fallback 有测试通过 | submit 404/405/501 未清洗，先读/记录 body；status 也先 console.error 原始 body |
| Async Suno backend | 部分达成 | `/suno/submit/:action` 服务端推导 model；idempotency scope；owner fetch | fetch 未限制 task platform，能返回 MJ/private task DTO；forbidden filter 不拒 notifyHook/owner aliases |
| Async Suno frontend | 部分达成 | canonical `/suno/submit/music|lyrics`、stable `opentu-audio-*`、unsupported submit/poll 测试通过 | lyrics body 会转发 `notifyHook` / `notify_hook` |
| Async MJ backend | 部分达成 | `/mj/submit/imagine` 派生 action/model；MJ adaptor 用 `mj-api-secret`；fetch/image owner scoped；image proxy 有 SSRF validation | channel lookup failure no CAS/refund；Suno fetch 可绕过 MJ sanitized DTO；部分 forbidden aliases 缺失 |
| Async MJ frontend | 基本达成但依赖后端缺口 | canonical `/mj`、stable `opentu-image-*`、`onSubmitted`、unsupported no fallback 测试通过 | 后端缺陷会破坏端到端隐私/计费；URL 清理 denylist 非共享 |
| Cross-cutting session/nonce/credential stripping | 部分达成 | provider transport 会 same-origin credentials、strip auth query/header；后端 rejects many forbidden keys | `X-Forwarded-*` trust；缺 nonce 时前端不本地 fail-fast；debug SW 可能记录 Creative relay headers/body |
| Tests / validation | 部分达成 | 本轮 targeted Go/Vitest 均通过；已有大量 Creative tests | 缺并发 quota、billing outbox/CAS failure、FRONTEND_BASE_URL、XFF spoof、hydrate unsafe no-cloud-ref、Suno notifyHook 等测试 |

## 4. 优先级 Findings

### H1 — `FRONTEND_BASE_URL` 部署模式跳过 Creative 路由注册并把 Creative API/relay 重定向到前端

- 严重度：High；置信度：High；状态：confirmed
- 仓库：`new-api`
- 文件：`router/main.go:15-33`，`router/web-router.go:56-119`
- 影响：非 master 且 `FRONTEND_BASE_URL` 非空时不会调用 `SetWebRouter`，因此 `/creative/api/assets`、`/creative/relay/v1/videos|suno|mj` 不注册；未匹配请求进入 `NoRoute` 301，绕过 Creative session/auth/nonce/same-origin 边界，项目目标中的嵌入式浏览器 API 在该部署形态不可用。
- 证据：`router/main.go:25-32` 只有 `frontendBaseUrl == ""` 才 `SetWebRouter`，否则 `NoRoute` redirect；Creative API/relay 的唯一注册点在 `router/web-router.go:56-119`。
- 修复建议：将 `/creative/api` 与 `/creative/relay/v1` 从 Web 静态 serving 中拆出，在 `SetRouter` 中无条件注册；`FRONTEND_BASE_URL` 只影响 SPA/static fallback。若明确不支持 Creative，应对 `/creative/api*`、`/creative/relay*` 返回受控 404/501 JSON，而不是外部 redirect。
- 验证：新增 `SetRouter` + `FRONTEND_BASE_URL` 集成测试，断言 Creative API/relay 仍注册或受控 fail-closed。

### H2 — 异步任务 submit 成功路径未原子化 task / idempotency / billing，可在结算失败后仍返回成功

- 严重度：High；置信度：High；状态：confirmed
- 仓库：`new-api`
- 文件：`relay/relay_task.go:205-227`，`controller/relay.go:594-640`，`service/task_billing.go:150-245`
- 影响：违反 Video/Suno/MJ 合同中“上游成功响应必须等本地 task、idempotency、settlement/log bookkeeping 安全后才可见”。若 `task.Insert` 成功但 `CompleteCreativeVideoIdempotencyScoped` 或 `SettleBilling` 失败，可能留下可见成功任务、已完成或不一致的幂等记录、未完成账务。
- 证据：`relay_task.go:205-210` 先预扣费；`controller/relay.go:612-618` task insert 与 idempotency complete 分离；`controller/relay.go:619-629` `SettleBilling` 失败只 `SysError`，仍 `FlushTo` 成功响应。
- 修复建议：将 task insert + idempotency complete + billing/log 可见性写入放入事务或 durable outbox；结算失败不得 flush 成功，应持久化可恢复状态或走失败退款路径。
- 验证：mock `SettleBilling` 返回错误，断言不刷新成功响应、不完成幂等、只退款一次；mock idempotency complete 失败，断言 task 不会处于不可恢复成功态。

### H3 — 终态 CAS 与退款/结算分离，CAS winner 崩溃或账务失败会永久 0 次退款/结算

- 严重度：High；置信度：High；状态：confirmed
- 仓库：`new-api`
- 文件：`service/task_polling.go:325-345`，`service/task_polling.go:588-614`，`service/task_billing.go:150-245`
- 影响：正常轮询路径有 CAS 防双花，但没有 durable at-least-once 账务保证。终态状态先写入，随后进程崩溃或 `taskAdjustFunding` / `taskAdjustTokenQuota` 失败，则任务不再被轮询，钱包/订阅预扣无法恢复。
- 证据：`UpdateWithStatus` 成功后才调用 `settleTaskBillingOnComplete` / `RefundTaskQuota`；`RefundTaskQuota` 与 `RecalculateTaskQuota` 只 log 后 return，没有 retry marker/outbox。
- 修复建议：CAS 终态迁移时同步写入 `billing_pending` / outbox，由后台 worker 幂等完成 refund/settle；账务成功后标记 `billing_done`。
- 验证：故障注入 CAS 成功后崩溃/账务 DB 错误，重启后必须自动补偿。

### H4 — video/MJ channel lookup failure 使用无 CAS bulk failure 且不退款

- 严重度：High；置信度：High；状态：confirmed
- 仓库：`new-api`
- 文件：`service/task_polling.go:117-125`，`service/task_polling.go:397-429`，`model/task.go:537-541`
- 影响：如果已预扣的 Video/MJ 任务所属 channel 被删除或缓存读取失败，任务会被批量置 `FAILURE`，但没有 `UpdateWithStatus`、没有 refund，且可覆盖并发终态。
- 证据：`UpdateVideoTasks` 在 `CacheGetChannel` error 分支调用 `TaskBulkUpdateByID`；`model/task.go:537-541` 明确警告该函数无 CAS 且不应用于 billing/quota lifecycle。
- 修复建议：改成逐任务 CAS terminal transition；CAS winner 调 `RefundTaskQuota` 或写入 refund outbox；null upstream id 分支也同样处理。
- 验证：channel missing/cache error 后钱包/订阅/token 只退款一次，CAS loser 不退款。

### H5 — Suno fetch 可返回非 Suno 任务并泄漏 MJ/upstream 私有结果

- 严重度：High；置信度：High；状态：confirmed
- 仓库：`new-api`
- 文件：`relay/relay_task.go:310-359`，`relay/relay_task.go:553-575`，`dto/task.go:32-53`，`model/task.go:133-140`，`controller/creative.go:549-553`
- 影响：拥有某个 MJ 任务的用户可调用 `/creative/relay/v1/suno/fetch/:id` 或 batch fetch 获取通用 `TaskDto`，包含 `result_url`、raw `data`、`channel_id`、quota/user 等；绕过 MJ 合同中“只通过 owner-scoped `/mj/image/:task_id` proxy 暴露图片、上游 id/url 私有”的要求。
- 证据：Suno fetch builder 只按 `user_id + task_id` 取任务并 `TaskModel2Dto`，未检查 `Platform == Suno`；`TaskDto` 包含 `ResultURL` 与 `Data`；`GetResultURL` 返回 `PrivateData.ResultURL`。
- 修复建议：Suno fetch 仅序列化 `TaskPlatformSuno`；返回 Suno-specific sanitized DTO，至少去掉 `result_url`、raw `data`、channel/quota/user 等内部字段。
- 验证：创建同用户 MJ 成功任务后调用 Suno fetch，预期 404/400 或 sanitized non-Suno rejection。

### H6 — 资产配额检查与写入非原子，可并发绕过 UserMaxBytes/UserMaxAssets

- 严重度：High；置信度：High；状态：confirmed
- 仓库：`new-api`
- 文件：`service/creative_asset.go:281-288`，`service/creative_asset.go:317-324`，`model/creative_asset.go:113-123`
- 影响：并发上传多个不同内容时，每个请求都可基于旧 `COUNT/SUM` 通过配额检查，然后同时写入对象和 DB，超过用户存储上限。
- 证据：`CreateOrGet` 先查 content hash，再 `checkQuotaAndStorageHealth`，再 `runtime.storage.Store`，最后 `DB.Create`；配额统计是普通查询，无事务/锁/reservation。
- 修复建议：引入 per-user quota row/counter，在事务中 `SELECT ... FOR UPDATE` 或 CAS reservation；对象写入失败释放 reservation，DB 写入失败清理对象。
- 验证：低配额下并发上传不同 hash，只允许一个成功。

### H7 — 前端资产 URL 发现漏 `__aitu_generated__/image|video` 与 posters/covers/clips 字符串数组

- 严重度：High；置信度：High；状态：confirmed
- 仓库：`opentu`
- 文件：`packages/drawnix/src/services/creative-document-assets.ts:80-94`，`378-435`，`585-664`
- 影响：本地虚拟媒体可能不上传、不报错，直接作为本地 URL 写入云文档，其他浏览器/会话无法 hydrate；违反“云文档只保存 `/creative/api/assets/:id/content` 或 fail-closed”的合同。
- 证据：字段白名单只有 `url/imageUrl/videoUrl/audioUrl/poster/src/thumbnail/.../coverUrl/imageLargeUrl` 与 `urls/thumbnailUrls`；递归仅对命中字段调用 rewriter；缺 `posterUrl/posters/cover/covers/clips` 字符串数组和 `__aitu_generated__/image|video` 识别。
- 修复建议：扩展虚拟媒体前缀和字段集合，或基于值特征递归发现本地虚拟媒体；未知本地媒体字段 fail-closed。
- 验证：参数化测试覆盖 generated image/video、posterUrl、posters、covers、clips 字符串数组。

### H8 — hydrate 在“无云资产引用”分支直接返回，绕过 signed/bucket URL 校验

- 严重度：High；置信度：High；状态：confirmed
- 仓库：`opentu`
- 文件：`packages/drawnix/src/services/creative-document-assets.ts:245-270`、`667-740`；`packages/drawnix/src/services/creative-document-sync.ts:1213-1228`（同步入口由分支审计定位）
- 影响：历史/迁移/异常远端文档若含签名 URL、对象存储 URL 或 credentials URL，且没有 `/creative/api/assets/*` 引用，会被直接导入并本地保存，违反 credential-stripping 合同。
- 证据：`getUnsafeRemoteUrlKind` 能识别 signed/object-storage，但 `hydrateCreativeDocumentAssets` 在 `!hasCreativeAssetContentRefs(copy)` 时 `return copy`，未执行 unsafe URL scan。
- 修复建议：hydrate/远端导入无论是否有 cloud ref 都先跑 unsafe URL sanitizer；发现 unsafe URL 拒绝导入并记录 sanitized 状态。
- 验证：远端文档仅含 `https://bucket...?...signature=...` 且无 cloud ref 时必须失败，不写入 workspace storage。

### H9 — Suno lyrics session-broker 可转发浏览器传入的 `notifyHook` / `notify_hook`

- 严重度：High；置信度：High；状态：confirmed
- 仓库：`opentu` + `new-api`
- 文件：`opentu/packages/drawnix/src/services/audio-api-service.ts:829-847`，`generation-api-service.ts:727-748`；`new-api/controller/creative.go:1230-1288`，`1541-1625`
- 影响：浏览器可通过 embedded Creative session-broker 让上游收到自定义回调地址，导致结果/元数据外发或 provider-mediated SSRF 类风险；同时违反 backend/frontend Suno relay “不得提供 notifyHook/routing material”的合同。
- 证据：`buildLyricsSubmitBody` 从 top-level 和 nested params 读取 `notifyHook` / `notify_hook` 并写 `body.notify_hook`；generation service 将 `params.notifyHook` 传下去；后端 Suno guard 只拒 `model`，通用 forbidden key 列表未包含 `notifyhook/callback/webhook`。
- 修复建议：session-broker audio body 改为白名单构造，丢弃或拒绝 notify/callback/webhook 字段；后端 Suno guard 加兜底拒绝。
- 验证：前端 lyrics/music session-broker 测试 top-level/nested notifyHook 不出现在 body；后端 JSON/form/multipart notifyHook 返回 400。

### H10 — Relay same-origin 依赖客户端可控 `X-Forwarded-Host/Proto`

- 严重度：High；置信度：Medium；状态：needs-runtime-verification
- 仓库：`new-api`
- 文件：`middleware/creative.go:232-287`，`middleware/cors.go:9-15`
- 影响：若部署代理未剥离客户端传入的 `X-Forwarded-*`，攻击者可伪造 expected origin，使跨源 `Origin`/`Referer` 通过 Creative same-origin。GET relay 不要求 nonce，因此此边界对 status/content 尤其重要。
- 证据：`creativeRequestOrigin` 优先取 `X-Forwarded-Proto` 与 `X-Forwarded-Host`，再 fallback 到 `Request.Host`；未见 trusted proxy 校验。CORS 配置为 `AllowAllOrigins=true` 且 `AllowCredentials=true`。
- 修复建议：Creative expected origin 使用配置的 public origin 或可信代理归一化后的 Host；直连客户端的 `X-Forwarded-*` 忽略或禁止。
- 验证：构造 forged XFF + hostile Origin 的 middleware 测试；生产代理配置验证。

## 5. Medium / Low Findings

### M1 — 全局 Cache 中间件污染 Creative API 错误响应头

- 严重度：Medium；状态：confirmed
- 文件：`new-api/router/web-router.go:43-59`，`middleware/cache.go:7-14`，`middleware/creative.go:95-128`
- 影响：Creative API/relay 的 401/403/404/503/nonce 等错误可能带 `Cache-Control: max-age=604800`，违反 private/no-store/nosniff 合同。
- 修复：全局 Cache 跳过 `/creative/api`、`/creative/relay`，或在 Creative group 前统一设置 private/no-store/nosniff。

### M2 — 资产 DELETE 先删 DB 元数据再删对象，失败后不可按 assetId 重试

- 严重度：Medium；状态：confirmed
- 文件：`new-api/service/creative_asset.go:368-385`
- 影响：S3 DeleteObject 失败后 DB 行已删除，后续重试无法定位 ObjectKey，导致私有对象孤儿。
- 修复：pending_delete tombstone / outbox；对象删除成功后 finalize metadata 删除。

### M3 — 文档引用刷新与资产删除之间缺少事务/锁

- 严重度：Medium；状态：likely
- 文件：`new-api/controller/creative.go:440-459`，`service/creative_asset.go:368-380`，`model/creative_asset.go` ref functions
- 影响：同一用户并发保存文档和删除资产时，DELETE 可能在引用写入前看到 ref count 为 0 并删除资产，随后文档落入指向已删除 asset 的引用。
- 修复：文档 mutation 的 asset validation/document write/ref refresh 与 DELETE 判断都纳入一致事务/锁。

### M4 — 生产 S3 unhealthy 只在首次 upload 才暴露

- 严重度：Medium；状态：needs-runtime-verification
- 文件：`new-api/service/creative_asset.go:198-246`，`548-572`
- 影响：bootstrap/status 可能报告 asset sync enabled，但 bucket 权限/endpoint 实际不可用。
- 修复：启动/定期 S3 health probe，unhealthy 时 Status fail-closed。

### M5 — 钱包/Token Redis quota cache 在 DB 更新前异步变更，失败时会漂移

- 严重度：Medium；状态：likely
- 文件：`new-api/model/user.go:883-922`，`model/token.go:375-421`，`service/task_billing.go:87-117`
- 影响：Creative refund/settle 依赖这些函数；DB 更新失败或 batch update 延迟时 Redis 与 DB 不一致。
- 修复：DB commit 成功后更新或 invalidate cache；失败时回滚/删除缓存。

### M6 — Creative forbidden-field filter 缺少 owner / notify / API-secret 变体

- 严重度：Medium；状态：confirmed
- 文件：`new-api/controller/creative.go:1541-1625`
- 影响：合同要求浏览器不能提供 owner override/API-secret/notifyHook；当前通用列表未覆盖 `ownerId/userId/owner/mj-api-secret/apiSecret/notifyHook/callback/webhook` 等全部别名。
- 修复：统一 normalized denylist，覆盖 camel/snake/kebab 和 nested path。

### M7 — 前端 Video session-broker submit 对 404/405/501 未先转 sanitized unsupported-backend

- 严重度：Medium；状态：confirmed
- 文件：`opentu/packages/drawnix/src/services/video-api-service.ts:214-225`，`443-468`，`524-538`
- 影响：Video relay 默认 disabled 返回 404 时，submit 会读取、log、拼接 response body；若错误体含内部信息会泄漏。status 路径虽最终抛 sanitized error，但已先 `console.error` 原 body。
- 修复：session-broker submit/status/content 都先判断 404/405/501 并抛 sanitized error，不读取/传播 body；日志只保留 status/code。

### M8 — session-broker 缺少 CSRF/nonce 时前端不本地 fail-fast

- 严重度：Medium；状态：needs-runtime-verification
- 文件：`opentu/packages/drawnix/src/services/creative-mode.ts:55-64`，`provider-routing/provider-transport.ts:183-191`，`394-438`
- 影响：若持久化 managed profile 存在但 bootstrap auth material 缺失，前端仍会发 POST，只是不带 nonce，最终由后端 403；违反前端 fail-closed/ready gating 目标。
- 修复：session-broker unsafe method 在 transport 层要求 csrf+nonce，否则 fetch 前抛 sanitized `bootstrap required`。

### M9 — status/fetch 路径在 stored key 缺失时回退当前 channel key

- 严重度：Medium；状态：confirmed for status/fetch path
- 文件：`new-api/relay/relay_task.go:441-445`，`controller/video_proxy.go:87-117`，`controller/video_proxy_gemini.go:208-220`
- 影响：合同要求 accepted task status/content 使用 submit-time selected key。status/fetch helper 在 `PrivateData.Key` 空时 fallback `channelModel.Key`；老数据或写入缺陷会漂移到当前 key。部分 content proxy 已对 missing key fail-closed，但 Vertex fallback 仍取 channel key。
- 修复：新 Creative task 缺 key 应 fail-closed 或只对显式 legacy migration path fallback，并打审计标记。

### M10 — Sora status 可能保留上游 `task_id` 等 routing identifier

- 严重度：Medium；状态：needs-runtime-verification
- 文件：`new-api/service/task_polling.go:619-643`，`relay/channel/task/sora/adaptor.go`（分支审计定位）
- 影响：若上游 status body 含 `task_id/job_id/operation`，status 可能泄漏上游 routing id。
- 修复：统一重写/删除 `task_id/job_id/operation/upstream*` 等字段；fixture 测试覆盖。

### L1 — Asset public DTO 与合同字段名漂移

- 严重度：Low；状态：confirmed
- 文件：`new-api/service/creative_asset.go:102-110`，`475-488`
- 影响：返回 `size`、`createdTime`、`updatedTime`，合同示例要求 `sizeBytes` 且尽量只暴露公开字段；未泄露 storage internals，但会造成严格客户端/验收测试漂移。
- 修复：改字段或更新合同并加 JSON shape 测试。

### L2 — embedded URL 参数清理 denylist 不完整

- 严重度：Low；状态：confirmed
- 文件：`opentu/packages/drawnix/src/utils/gemini-api/auth.ts:9-42`，`286-346`，`utils/settings-manager.ts:191-224`
- 影响：`channel/group/model/selectedKey/notifyHook/callback` 等参数可残留在 URL/history/referrer/debug 中，虽 transport 层会剥离请求。
- 修复：与 provider-transport forbidden key 共享统一 denylist。

### L3 — Service Worker debug-mode 可能记录 Creative relay nonce/CSRF/idempotency/header/body

- 严重度：Low；状态：confirmed
- 文件：`opentu/apps/web/src/sw/index.ts:4231-4251`，`4657-4729`
- 影响：资产 API pass-through 已在早期返回，但 `/creative/relay/v1/*` 未排除 debug interception；debug 模式会记录 headers 和 body。
- 修复：对 `/creative/relay/v1/*` 跳过 debug body/header 采集或统一 redaction。

### L4 — 测试覆盖缺口

- 严重度：Low/Medium；状态：confirmed
- 文件：`new-api` 多个 `*_test.go`；`opentu` `video-api-service.session-broker.test.ts`、`audio-api-service.test.ts`、`mj-image-adapter.test.ts`、`creative-asset-pass-through.spec.ts`
- 影响：本轮 targeted tests 通过，但缺并发 quota、billing/outbox failure、FRONTEND_BASE_URL、XFF spoof、Suno non-Suno fetch、notifyHook rejection、hydrate no-cloud-ref unsafe URL、SW runtime cache/no-debug 等场景。
- 修复：按 Findings 的 validation 添加单测/集成测试。

## 6. 已审查且暂未发现重大问题的区域

- `new-api` 已有 canonical `/creative/relay/v1/videos|suno|mj` 主路径注册（在 `SetWebRouter` 模式下）。
- `new-api` MJ submit adaptor 会将 `NotifyHook` 清空，并使用 `mj-api-secret` 而非 browser `Authorization`（`relay/channel/task/mj/adaptor.go:36-69`）。
- `new-api` MJ fetch/image 主路径按 `user_id + task_id` owner scoped，并对 image proxy 调用 `ValidateURLWithFetchSetting` SSRF 校验（`controller/creative.go:563-681`）。
- `opentu` MJ adapter 保留 `/creative/relay/v1`，不 trim `/v1`；session-broker empty key、stable `opentu-image-*`、`onSubmitted` 与 unsupported no-fallback 有测试覆盖并通过。
- `opentu` Video/Suno session-broker canonical path、stable idempotency、direct empty-key fail-fast 有目标测试覆盖并通过。
- `opentu` SW 对 `/creative/api/assets/*` 的早期 pass-through 存在（`apps/web/src/sw/index.ts:4249-4251`），但测试仍偏弱。

## 7. 建议修复顺序

1. 先修 H1、H2、H4、H5、H9：这些会导致端到端不可用、账务错账或私有结果泄露。
2. 同一批补 H3 durable billing/outbox，因为它决定修复是否可恢复。
3. 修 H6/H7/H8：资产同步合同，否则文档云同步不可信。
4. 修 H10/M1/M6/M7/M8/M9：安全边界和错误清洗。
5. 补测试矩阵；把所有 High finding 的复现测试先写红再修。

## 8. 残余风险与未验证项

- 未调用生产端点、外部 AI provider、支付服务、真实 S3/Redis。
- 未做 MySQL/PostgreSQL/SQLite 三库矩阵实际迁移与锁语义验证。
- X-Forwarded-* 风险需要结合真实反向代理是否剥离/覆盖客户端头验证。
- S3 unhealthy fail-closed 需要 fake unhealthy client 或本地 S3-compatible 服务验证。
- Sora 上游 status body 是否含 `task_id` 需要 fixture 或 mock provider 验证。

