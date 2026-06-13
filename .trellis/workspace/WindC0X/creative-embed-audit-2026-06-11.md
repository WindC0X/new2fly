# creative-embed 深度审查报告

> 日期: 2026-06-11
> 范围: 手写代码 ~6,500 行 Go(new-api)+ ~5,000 行 TS(opentu);`web/creative/dist/**` 构建产物排除
> 方法: Codex(后端)+ Gemini(前端)独立审查 → 主控逐条代码级验证 → opus 动态 workflow 对抗性核实
> 性质: 审查交付物,**未改任何代码**

---

## Part A — 目标达成度审查(PRD R1-R7 / 11 验收项 / 7 项产品决策)

基准: `06-07-opentu-new-api/prd.md` + `product-decisions.md` + 4 对 backend/frontend spec。
原则: 不信 trellis「Completed」勾选,只信代码 + 测试。核验方式: 11 个 opus agent 并行,逐域裁定 met/partial/unmet/deviated,附 file:line 证据。

**结论: 核心目标全部达成,4 处与 PRD/决策文字偏离,3 处真实缺口。无虚假勾选——所有勾选扛住代码核验。**

### 达成度总览

| 目标域 | 裁定 | 关键证据 |
|------|------|---------|
| R2 同源挂载 + SW 隔离 | ✅ met | `/creative/` 同源、刷新不 404(SPA fallback 有路由测试)、SW 靠相对 `./sw.js`+无 `Service-Worker-Allowed` 头天然限定 `/creative/`、嵌入 CSP 齐全 |
| R3 网关唯一 provider + 服务端模型池 | ⚠️ mostly_met | 单一 session-broker profile、模型池完全服务端驱动(空池抛错无前端兜底)、前端无跨上游重试 ✅;capabilities/默认模型/分组「由服务端暴露」偏离 |
| R4 多渠道容灾 + 异步幂等 | ✅ met | image/video/suno/mj 全进 new-api relay 引擎;异步幂等表 + 成功缓冲到落库后才 flush + CAS 单赢家结算 + per-key 轮询亲和性(有专测) |
| R5 资产云同步 | 🟡 partial | 存储层/去重/隔离/lazy download/fail-closed ✅;元数据缺 name/prompt/model 三列、软删除 tombstone 未实现(硬删除) |
| R6 session 鉴权 + 隔离 + 上传限制 | ⚠️ mostly_met | 无浏览器长期 key、HttpOnly+CSRF+同源、tokenless 钱包计费、user_id 隔离、大小/MIME/容量限制 ✅;频率限制部分缺失、签名 URL 偏离 |
| 验收: image 链路 | ✅ met | `/creative/relay/v1/images/generations` → 真实 `ImageHelper`(与生产 `/v1` 同一条),多测试覆盖 |
| 验收: video 链路 | ✅ met | submit+poll+content 全通,buffer-until-persist 排序、owner-scoped、key 亲和性、幂等 replay/409 全有专测 |
| 验收: suno 链路 | ✅ met | music/lyrics 服务端推断模型、禁止前端传 model、action-scoped 幂等、owner-scoped fetch、stored-key 轮询 |
| 验收: mj 链路 | ✅ met | imagine 服务端注入、owner+platform scoped、image proxy 带 SSRF 防护、`mj-api-secret`(非 Bearer)、12 个其他 action 全 501 无兜底 |
| 计费+日志+任务记录 | ✅ met | 与普通 relay 同一套机器,无分叉路径;唯一差异是 session-broker token 把计费导向用户钱包(TokenId==0) |
| 前端 no-fallback + 凭证剥离 | ✅ met | 4 个契约(video/suno/mj/asset)全实现 + Vitest 覆盖;凭证/路由材料 header+query 双向剥离;unsupported 不回退直连 provider |

### 4 处偏离(deviated — 多数是合理的安全收敛,需回写 PRD)

1. **R3 capabilities/默认模型/分组「由 new-api 暴露」未兑现**。bootstrap 不返回 capability 矩阵,服务端 UI 策略字段被前端主动剥离,默认模型改由 opentu 客户端硬表决定。性质: 安全 remediation 的有意决定,不破坏「唯一网关 + 服务端模型池」,但与 PRD 原文矛盾。
2. **R5 vs 决策4 byte-quota 冲突**。R5 明列「容量配额」,决策4 说「不单独设 byte-quota」。代码实现了独立 byte-quota(`UserMaxBytes` 默认 2GiB + 全局/用户 DB 上限),默选了 R5。两个权威源直接打架,从未显式 reconcile。
3. **R6 签名 URL 偏离**。PRD 要求短期签名 URL 下发浏览器,代码改为任何签名 URL 都不下发,改用 owner-scoped 同源 content 流式代理。更安全,但字面未实现。

### 3 处真实缺口(应明确「接受/补做」)

1. **R5 软删除 tombstone 未实现**(unmet)。硬删除,仅靠引用计数 gate;跨设备同步缺 tombstone 协调。
2. **R5 元数据缺 3 列**(partial)。无 `name`/`prompt`/`model` 列,上传路径主动拒绝这些字段。
3. **R6 per-user 频率限制缺失**(partial)。只有 IP 维度全局 `GlobalWebRateLimit`,无针对性 creative 上传/relay 限速。

### 总评

推荐交付终点 Phase 3(全链路 + 容灾)已扎实达成,四条媒体链路 + 容灾 + 幂等 + 计费全部 met 且有专测。trellis 全 Completed 勾选经得起核验,无注水。未完全达成集中在 R5 完备性(tombstone/元数据)与 R6 边角(频率限制/签名 URL),其中签名 URL 与 byte-quota 是「代码比 PRD 更保守/更安全」的偏离。

---

## Part B — 代码缺陷审查(发布前)

整体安全基线扎实: session-broker 服务端 CSRF+nonce 恒定时间比对、同源校验、禁止字段递归过滤(header/query/body)、云同步前递归脱敏、SSRF `ValidateURLWithFetchSetting` 兜底、响应头剥离认证字段。**无 CRITICAL 漏洞。**

### 已确认 HIGH(主控手验)

| 位置 | 问题 |
|------|------|
| `video_proxy.go:152` / `creative.go:660` | SSRF 仅校验初始 URL,`http.DefaultClient` 跟随重定向,跳转目标未再校验 → 重定向/DNS rebinding 绕过;敏感头可带到跳转目标。修: `CheckRedirect` 每跳重校验并剥离敏感头 |
| `relay.go:612-620` | 上游提交成功后才本地持久化 + 完成幂等;Insert/幂等失败走「退款+删幂等」但上游已在跑 → 免费任务 + 丢轮询追踪。修: 失败入 `pending_reconciliation` |
| `relay.go:619` | `SettleBilling` 失败仅写日志,仍 flush 成功响应并记消费 → 补扣失败放行未付费。修: 写 billing-retry outbox 并标记待结算 |
| `task_polling.go:117,421` | 空 upstream-id/渠道失败任务批量置 FAILURE,无 CAS、无退款 → 已预扣 quota 永不退。修: 逐条 CAS 抢占后统一退款 |
| `task_polling.go:482` | 脱敏前 `LogDebug` 完整上游响应体 → presigned URL/token 泄漏日志。修: 先脱敏再记 |

### opus workflow 对抗性核实确认 MEDIUM

| 位置 | 核实结论 |
|------|---------|
| `creative_asset.go:287→324` | ✅确认 MEDIUM。配额 check 与 `DB.Create` 无事务/无锁,并发上传同读同放行。越界有界(每请求受单文件上限约束),真正风险是全局 DB 字节上限被协同突发击穿。修: check+insert 入同一事务 + per-user 配额行原子预留 |
| `creative.go:354/445/470` | ✅确认 MEDIUM。文档变更与 ref 刷新分属不同事务。Create/Update 靠 ClientMutationId 重试自愈,但 **Delete 不可自愈** → 孤儿 ref 行永久残留,资产永远删不掉。修: 至少 Delete+DeleteRefs 包进一个事务 |
| `relay_task.go:224` | ✅确认 MEDIUM。通读 `RelayTaskSubmit` 全程无 `defer resp.Body.Close()`,非 200 分支 `io.ReadAll` 后直接 return,连接不回收。修: `resp` 判空后立即 defer Close |

### opus 核实后降级/推翻

| 原结论 | 核实后真相 |
|------|---------|
| `model/creative.go` `FOR UPDATE` 破坏 SQLite(Codex HIGH) | ❌误报。`glebarez/modernc-sqlite` 解析但忽略 `FOR UPDATE`;实跑 model 包测试(SQLite)`ok 0.032s` |
| `creative-document-assets.ts` 白名单漏字段泄漏签名 URL(Gemini HIGH) | ❌基本误报。`getUnsafeRemoteUrlKind` 对每个字符串值运行,与字段名无关;白名单仅用于 local-upload/cloud-ref 检测 |
| `relay_info.go:523` cloneRequestHeaders 泄漏 Cookie/CSRF(Codex HIGH) | ⚠️降 MEDIUM。仅当管理员配置 header-override 表达式才外泄。建议白名单 |
| `creative.go:590` MJ ListByCondition「违反 Rule 1」 | ❌降 LOW。`c.BindJSON` 是全仓约定,Rule 1 只管 `encoding/json` 显式调用;`GetByTaskIds` 全参数化无注入。ids 无上限属实,加 `len>200` 即可 |
| `video_proxy.go:223` writeVideoDataURL 无限内存 | ❌降 LOW。data: URL 非任意用户输入,只有 Gemini/Vertex 上游响应能产生。修: 加大小上限 + MIME 白名单 + 无条件 nosniff |
| `task.go:164` AUTO_INCREMENT 破坏迁移 | ❌降 LOW(纯风格)。GORM v2 忽略 legacy 标签按约定生成各方言 DDL;既有 Task 结构体同标签同批迁移 |
| `mj/adaptor.go:180` FetchTask 未转义 | LOW 维持。taskID 来自可信上游响应非用户输入。防御性加 `url.PathEscape` |
| 前端 localStorage 竞态 | ❌降 LOW。reconcile 对相同 model pool 确定性,last-write-wins 无分歧且自愈 |
| 前端 model 剥离正则 | ❌降 LOW。`stripModel` 仅在 `authType==='session-broker'` 生效,正则是 broker 模式内收窄白名单非替代 flag;model 非凭证、同源、broker 服务端重选 group |

### 发布前建议处理

- **5 HIGH**(手验): SSRF 重定向、上游提交早于持久化、结算失败放行、批量 FAILURE 不退款、脱敏前日志
- **3 MEDIUM**(opus 确认): 资产配额竞态、文档删除孤儿 ref、task 响应体泄漏

无 CRITICAL。其余降 LOW(防御性/风格)。整体架构安全基线扎实,问题集中在一致性边界与资金幂等,而非认证授权。
