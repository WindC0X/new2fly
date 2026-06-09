# Opentu 嵌入 new-api：源码级可行性评估(三方交叉验证版 v2)

> 本文替换初版评估。初版方向正确,但低估了前端/SW/构建链,漏掉了若干关键源码事实,且把"session relay"误判为远期难项。本版基于**真实源码**重新推导,并经三套独立方法交叉验证。
>
> - 源码基准:`QuantumNous/new-api@4ca47ee`、`ljquan/opentu@bf44d14e`(本地真实克隆,非文档推测)。
> - 验证方法:① Claude 双仓库源码核查 ② Gemini 独立前端分析(SESSION `290eda80-2a2f-4ba8-8035-abe966db075c`)③ 13-agent 对抗式 Workflow(六维 × 调查→对抗验证→综合)④ Codex 独立后端分析(SESSION `019ea0a5-5363-7c80-9ee9-6308c798c4b5`)。
> - 需求基准:见同目录 `prd.md`(R1–R7 仍成立)。

## 1. 结论(Executive Summary)

- **可行,但不是"把 opentu dist 塞进 new-api"。** 综合难度 **7–8 / 10**,工期 **~8–11 周**(AI coding agent + 人审)。主成本在 **opentu 客户端改造**(虚拟 URL、自带容灾、gateway provider),不在 Go 胶水。
- **核心架构不变**:opentu 做创作工作台,**new-api 是唯一 provider gateway**(渠道选择/重试/auto-ban/计费/日志全部归 new-api)。
- **三方独立收敛**于同一批结论与同一套架构,置信度高;Codex 因更看重计费补丁与 exact-key 亲和,把总评定到 8/10。

## 2. 对初版评估的关键纠错(源码级)

| # | 初版/常识判断 | 源码级真相 |
|---|---|---|
| 1 | 整体"静态嵌入中等、分散难度" | 加权 **7–8/10、~8–11 周**;成本集中在 opentu 客户端 |
| 2 | (未提) | **最大隐藏杀手**:opentu 给本地媒体生成**根绝对**虚拟 URL(`/__aitu_cache__/`、`/asset-library/`、`/__aitu_generated__/audio/`,~110 处),从 `/creative/` 文档发出会**逃出 SW scope** → 命中 `web-router.go:35` 的 NoRoute 返回 **HTTP 200 的 HTML 当图片**(非干净 404,更难排查) |
| 3 | (未提) | `middleware/cache.go:8-15` 对除 `/` 外一切设 `max-age=604800`(1 周),会把 `/creative/sw.js` 钉成陈旧版本 → 必须 per-path no-cache |
| 4 | "session relay 远期/`TokenOrUserAuth` 白嫖容灾" | **错**:`TokenOrUserAuth` 的 session 分支只设 `id`(`auth.go:194-207`),`Distribute`/`GenRelayInfo`/billing 需 group/using-group/user-quota/token 字段;`/v1/videos/:id/content` 能 session-only 仅因纯下载(`shouldSelectChannel=false`)。需新写 `CreativeSessionRelayAuth`。**且 tokenless 计费非完全免费**:`PreConsumeTokenQuota`/`BillingSession.Settle`/`Refund` 假定 token key 存在,须 guard `TokenId==0` 走 user 钱包 |
| 5 | "异步重复提交:高风险"(泛泛) | 精确定位:post-send 超时 → `do_request_failed`→HTTP 500,500 ∉ `{504,524}` 跳过表(`status_code_ranges.go:31`)→ 换渠道重试;任务行只在成功后落库(`controller/relay.go:572-598`)→ 首个已接受 upstream 变 orphan + 双扣。Suno 退款分支非 CAS(`task_polling.go:238`)。RequestId 是追踪非业务幂等 |
| 6 | "Opentu 不重复实现容灾即可" | opentu 自带**主线程 `FallbackMediaExecutor`** + planner `fallbackModelRef`,是第二套容灾;不中和会与 new-api 双路由/双提交/绕过计费 |
| 7 | "微前端隔离好"(乐观但成立) | **印证且更乐观**:opentu vite `base` 默认相对 `./`、SW 用 `self.location` 自算 scope(静态资源天然适配子路径);完成端退款 CAS 已内置且有并发单测(`model/task_cas_test.go`);`StoredAsset` 加字段非破坏、`contentHash` 现成 SHA-256 |
| 8 | "poll 锁定原 channel 即可" | channel 级亲和已保证(按 `task.ChannelId` 轮询),但 **multi-key 渠道 exact-key 亲和未保证**(`relay_task.go:421-443` 用 `channelModel.Key`)→ 需记录 submit 时 key index/hash |

## 3. 真实难度矩阵(六维,经对抗验证)

| 维度 | Workflow | Codex | 取值 | 工期 | 核心原因 |
|---|:--:|:--:|:--:|---|---|
| 嵌入 & 构建 | 6.5 | 6 | **6.5** | ~1.5–2 周 | NoRoute 只放行 `/v1,/api,/assets` + `Cache()` 1 周强缓存;pnpm/Nx/Vite 第三套工具链 |
| SW 隔离 | 7 | (并入b/c) | **7** | ~1.5–2 周 | ~110 处根绝对虚拟 URL 逃逸 + `virtual-media-url.ts` 检测层 + 持久化画布数据迁移 |
| Provider 网关接缝 | 7 | 6 | **7** | ~2–3 周 | 两套并行路径系统,仅 `baseUrl=<host>/v1` 时对齐;通用异步 poll 掉 `/v1`;**Flux 无 new-api 路由(404)** |
| 鉴权 & 安全 | 6 | 8 | **7** | ~1–1.5 周 | `CreativeSessionRelayAuth` + **tokenless 计费补丁**(`PreConsumeTokenQuota`/Settle/Refund guard);CSRF 面;opentu apiKey 假设遍布 ~58 文件 |
| 异步任务完整性 | 7 | 8 | **7.5** | ~2–3 周 | 完成端已 CAS;真洞在提交端:无幂等 + 超时误重试 + Suno 非 CAS + opentu 第二容灾 + exact-key 亲和 |
| 资产云同步 | 6.5 | 7(MVP) | **6.5** | ~2–3 周 | `getAllAssets` 过滤掉不在 Cache API 的资产 → 云端独有资产**在网格隐身**;byte-quota 不可复用计费 `Quota`;SW 大视频 lazy-download 内存 |

## 4. 最硬 / 最易被低估的风险(Top 6)

1. **虚拟媒体 URL 逃逸 SW scope → HTML-200 当图片**(正确性,高)。修复:统一 `buildVirtualUrl(BASE_URL)` 覆盖 ~110 站点 + `virtual-media-url.ts` 检测层 + 持久化画布/IndexedDB 资产记录迁移或双键匹配。
2. **post-send 超时双提交 + orphan 计费**(正确性/费用,高)。修复:提交前先落预留行(idempotency reservation)+ `UNIQUE(user_id, key)` + 超时(500)改不可重试待定,交由 timeout sweeper 收敛。
3. **`Cache()` 1 周强缓存钉死 SW**(正确性,高)。修复:`/creative/` 下 `sw.js`/`index.html`/`version.json` per-path no-cache 覆盖。
4. **双容灾引擎绕过网关**(正确性/费用,高)。修复:中和 opentu `FallbackMediaExecutor` + planner `fallbackModelRef`,塌缩为单一 gateway profile。
5. **tokenless 计费路径**(费用,中高)。`PreConsumeTokenQuota`/`Settle`/`Refund` 须显式 guard `TokenId==0 && TokenKey==""` 走 user 钱包,否则 session 用户有余额也扣不动。
6. **上游 merge 冲突面**(可维护性,中高且持久)。所有逻辑落新文件;`main.go`/`web-router.go`/`Dockerfile`/`provider-routing/*` 改动最小化;opentu dist CI 离线构建只 COPY 产物;固定并跟踪上游 SHA。

## 5. 推荐架构

```text
浏览器(同源)
  opentu /creative/  ──(session cookie, 无长期 key)──▶  new-api /api/creative/relay/*
        │                                                      │ CreativeSessionRelayAuth (补 group/quota 上下文)
        │ NewAPI Creative Gateway provider                     │ CreativeRelayPathRewrite (/api/creative/relay/v1/.. → /v1/..)
        │ (唯一 provider,无 failover/billing)                 │ Distribute + Relay/RelayTask/RelayMidjourney
        ▼                                                      ▼  channel 选择 / 重试 / auto-ban / 计费(UserId) / 日志
  本地画布 / 素材库 / 任务 UI                              upstream providers
        │
        └─ Creative Asset Cloud Sync ──▶ /api/creative/assets/* ──▶ DB(creative_assets)+ 本地盘/对象存储
```

**原则**:① new-api 唯一网关;② opentu 只认 same-origin creative gateway,无长期 key;③ new-api 只加 **additive** 路由/中间件,不污染 public `/v1`/`/mj`/`/suno`;④ 异步提交服务端幂等;⑤ asset sync 与 provider relay 分离(byte-quota ≠ 计费 quota)。

## 6. 依赖顺序路线(additive-first,上游可干净 merge)

- **Phase 0 — POC,先拆两个杀手(~3–4 天)**:`/creative/` 静态挂载 + SPA fallback(NoRoute 之前)+ `sw.js`/`index.html`/`version.json` no-cache 覆盖 + `buildVirtualUrl()` 验证 `<img>` 落在 scope 内。
  - 验收:`GET /creative/assets/*.js` 返回 JS 非 HTML;SW scope 恰为 `/creative/`;生成图经 SW 拦截正常渲染;`/api`、`/v1` 不被任何 SW 控制。
- **Phase 1 — Bootstrap / 网关鉴权(~1.5 周)**:`CreativeSessionRelayAuth`(补 `GetUserCache→WriteContext→ContextKeyUsingGroup`)+ tokenless 计费补丁 + `GET /api/creative/bootstrap` + opentu gateway 模式(`authType:'session'`、`credentials:'same-origin'`、绕过 key 强校验)+ CSRF 自定义头 + SW 对 `/v1`/`/suno` 直通不缓存。
  - 验收:登录态 POST 图片生成 → Distribute 选渠道 + 预扣 user 钱包成功;非白名单模型被拒;既有 token 客户端行为不变。
- **Phase 2 — Provider 全链路(~2 周)**:`CreativeRelayPathRewrite` + creative relay route group;锁定 `baseUrl=<host>/v1`;修通用异步 poll(`DEFAULT_VIDEO_POLL_PATH` 补 `/v1`);`binding.submitPath` 成权威路径;Flux 置为不支持;实证并接通**真实** SW 配置机制(源码注释自相矛盾、所谓 fetch-relay 不存在)。
  - 验收:URL 等价矩阵 —— image/async-image/video(+poll+content)/MJ/Suno/Gemini 的最终 URL == new-api 路由。
- **Phase 3 — 异步完整性硬化(~2–3 周)**:独立 `CreativeRelayIdempotency` 表 + `Idempotency-Key`(复用 opentu `SWTask.id`,在 `provider-transport.ts` 注入)+ 预留行 close orphan window + 超时改非重试待定 + Suno 退款走 CAS + 中和 opentu 容灾 + exact-key 亲和(记录 key index/hash)。
  - 验收:同 key 重复提交 → 一行一扣;模拟 post-send 超时 → 恰一个 upstream、失败退一次;并发 poller+sweeper → 退款恰一次。
- **Phase 4 — 资产云同步 MVP(~2–3 周,可与 2/3 并行)**:`creative_assets` 表(`UNIQUE(user_id,content_hash)`+软删,加进**两张** migration 列表)+ 独立 byte-quota + 流式磁盘后端(`MultipartReader`+`io.Copy`+Range,藏在 `CreativeBlobBackend` 接口后)+ opentu `CloudAssetStore` + SW lazy-download 钩子(替换 `sw/index.ts:5136` 硬 404)+ 放宽 `getAllAssets` 让云端独有资产可见。
  - 验收:同 hash 上传幂等;软删经 `list(since=)` 消失;云端独有资产在网格可见;lazy-download 命中渲染、超时降级 404;byte-quota 生效;大视频上传不 OOM。
- **Phase 5 — 生产硬化**:CSP/CSRF/CORS 收紧(creative 严格同源);对象存储后端;E2E;监控;容量管理。

## 7. 决策与本评估推荐

| 决策项 | 选项 | **推荐** | 理由 |
|---|---|---|---|
| ① 构建拓扑 | Dockerfile 内建 pnpm stage / **CI 离线产物 COPY** | **CI 离线产物** | new-api Dockerfile diff 压到 ~2 行,解耦工具链,上游 merge 最干净,可缓存;代价是 CI plumbing + 固定 opentu SHA |
| ② 鉴权 | **session-cookie + tokenless 计费补丁** / minted scoped token | **session-cookie** | HttpOnly 不可被 JS 读,浏览器/SW/IndexedDB/备份无长期密钥,安全最优;代价是 Codex 指出的有界计费补丁;强制同源(SameSite=Strict)+ CSRF 自定义头 |
| ③ 幂等存储 | **独立 `CreativeRelayIdempotency` 表** / `tasks` 加 UNIQUE 列 | **独立表** | 不动热 `tasks` schema/插入时序(迁移风险最低),additive 隔离(merge 干净),预留行天然 close orphan window |
| ④ Flux | **MVP suppress** / 新增 new-api `/flux` relay | **MVP suppress** | new-api 无 `/flux` 路由;给"该模型暂不支持网关"可控提示优于裸 404;确为刚需再加 relay |
| ⑤ 资产后端 | **本地盘 MVP(藏接口后)** / 直接 S3 | **本地盘 + `CreativeBlobBackend` 接口** | 最快见效、无外部依赖;接口留好 S3/R2/MinIO 投放位;独立 byte-quota,**绝不复用计费 `Quota`** |
| ⑥ 首期协议 | 全开 / **单链路渐进** | **单链路渐进** | 先 OpenAI-compatible image 跑通,再 video(+poll+content)→ Suno → MJ imagine 逐协议验收;Kling/Jimeng/Gemini/Flux 延后 |
| ⑦ 钱包计费 | 直接扣钱包 / 二次确认 | **直接扣钱包 + 模型白名单** | creative 用量本就该像普通 relay 计费;以"创意模型白名单"限定范围,MVP 不加二次确认 |

## 8. AI 可实现 vs 需人类决策

- **AI 可实现**:全部 Go 胶水(`CreativeSessionRelayAuth`、`CreativeRelayPathRewrite`、creative router、idempotency 表/服务、`creative_asset` 模型+控制器+磁盘后端+Range、两张 migration 列表)、计费 guard、opentu gateway provider type + 无 key transport + `buildVirtualUrl()` ~110 站点机械改写 + poll 路径修复 + SW lazy-download + `getAllAssets` 放宽、各 Go httptest / opentu Vitest 矩阵。
- **需人类决策**:本文档第 7 节七项;另需**实证 SW 配置真实机制**(`config-indexeddb-writer.ts` 注释称 Fetch Relay 但该模块不存在,`sw-channel/common.ts` 称 SW 读 IndexedDB —— 必须先实证再接通,否则 gateway 配置会"主线程对、SW 静默失败")。

## 9. 关键文件索引(引用即真值)

- new-api:`router/web-router.go:24-45`、`middleware/cache.go:8-15`、`middleware/auth.go:170,194-208,367-401`、`middleware/distributor.go:59-83,134-158,236-399`、`controller/relay.go:485-603`、`relay/relay_task.go:82-106,175-177,421-443`、`relay/common/relay_info.go:463-496`、`model/task.go:44-127,404-417`、`service/task_polling.go:165-251,473-499`、`setting/operation_setting/status_code_ranges.go:26-33`、`main.go:38-48,179-198`、`Dockerfile:1-39`、`router/relay-router.go:69-201`、`router/video-router.go:10-52`。
- opentu:`apps/web/src/sw/index.ts:248-319,1858-1872,4264-4311,5033-5143`、`apps/web/vite.config.ts:1146`、`apps/web/src/main.tsx:525`、`packages/drawnix/src/services/provider-routing/{provider-transport.ts:158-216,binding-inference.ts:398-730,invocation-planner.ts:105-185,types.ts}`、`utils/settings-manager.ts:1330-1388`、`utils/config-indexeddb-writer.ts`、`utils/virtual-media-url.ts`、`services/media-executor/fallback-executor.ts`、`services/asset-storage-service.ts:35-176,414-481`、`types/asset.types.ts:90-105`、`video-binding-utils.ts:18,491-497`。

## 10. Phase 0 将验证的前置假设

- opentu 在 `VITE_BASE_URL=/creative/` 与默认相对 `base` 两种构建下的静态资源/SW/虚拟 URL 真实行为(二者交互:静态资源相对 base 即可,但虚拟 URL 修复需要 `import.meta.env.BASE_URL` 绝对值 → 需实测取舍)。
- new-api `Cache()` 对 `/creative/sw.js` 的真实缓存行为与 no-cache 覆盖点。
- SW 注册后 `/api`、`/v1` 确实不被拦截。
