# Creative 集成全量深度审查报告（独立重审）

> 日期: 2026-06-12
> 范围: new-api（Go 后端）≈9,847 行 + opentu（TS 前端）≈7,770 行手写 creative 集成代码；`dist/**` 构建产物排除
> 基准: PRD `06-07-opentu-new-api`（R1–R7 + 11 验收项）+ `product-decisions.md`（7 项决策）
> 方法: 达成度 workflow（16 个 opus agent 并行取证）+ Codex 独立后端审 + Gemini 独立前端审 → 主控逐条代码级裁决（推翻误报、确认真实缺口）
> 性质: 审查交付物，**未改任何代码**
> 主轴: 以「开发目标达成度」为主，全量质量审查为辅

---

## 0. 一句话结论

**核心目标（Phase 3 推荐交付终点：全链路 + 容灾 + 异步幂等 + 计费 + 资产同步）已扎实达成**，四条媒体链路全部走 new-api relay 且有专测；但有 **2 项 R5/R6 硬缺口未闭合**，且本轮独立重审发现 **2 个发布前必修的计费/安全缺陷（之前报告未点出）**。建议这 4 项闭合后再宣告达标。

---

## 1. 开发目标达成度（主轴）

裁定原则：不信 Trellis「Completed」勾选，只信代码 + 测试，附 file:line。

| # | 验收项 | 裁定 | 关键证据 |
|---|--------|------|---------|
| 1 | `/creative/` 同源 SPA（Go embed 直发 index.html） | ✅ met | router/web-router.go:164,312 |
| 2 | bootstrap 拉取（enabled/auth/能力/模型） | ⚠️ partial | controller/creative.go:152-202,1334-1353 |
| 3 | 图片走生产 `/v1/images/generations` | ✅ met | controller/creative.go:512-514; relay/image_handler.go:23-45 |
| 4 | 视频 submit+poll+content（buffer-until-persist/owner/幂等/key 亲和） | ✅ met | controller/relay.go:566-636; service/task_polling.go |
| 5 | suno music submit+fetch（服务端推断/禁前端 model/作用域幂等） | ✅ met | controller/creative.go:91-122,798-863 |
| 6 | MJ imagine（服务端注入/owner+platform/SSRF/mj-api-secret） | ✅ met | controller/creative.go:136-137,649 |
| 7 | 失败请求显示渠道重试链（复用标准重试/自动封禁） | ✅ met | controller/relay.go:241-264; service/channel_select.go:83-162 |
| 8 | 成功请求记账/日志/任务记录（钱包 TokenId==0） | ✅ met | controller/relay.go:167,614-629 |
| 9 | 资产上传云端 + 跨设备懒下载（user_id 隔离非设备绑定） | ✅ met | controller/creative_asset.go:45,88; model/creative_asset.go:123-145 |
| 10 | R5: 软删除 tombstone + name/prompt/model 元数据列 | ❌ unmet | model/creative_asset.go:37-56,336 |
| 11 | R6: 尺寸/MIME/容量/**频率**限制 + 短时签名 URL | ⚠️ partial | web-router.go:53-58; rate-limit.go:111-151 |
| 12 | R3: 模型/能力/分组/默认模型由服务端驱动（前端侧） | ↪️ deviated | creative-display-policy.ts:11-107 |
| 13 | 前端无直连兜底 + 凭证/路由材料剥离 + 递归脱敏 | ✅ met | creative-cloud-sanitizer.ts:130-205 |

**合计: 9 met / 2 partial / 1 unmet / 1 deviated。**

SW scope（PRD R2「SW 仅限 /creative/」）单独裁定 → ✅ met（见 §4 矛盾裁决）。

---

## 2. 真实目标缺口（必须明确「接受 / 补做」）

### G1 — R5 软删除 tombstone + 资产元数据列【unmet，硬缺口】
- `FinalizeCreativeAssetDelete` 用 `tx.Delete(&asset)` 物理删行（model/creative_asset.go:336），无 `gorm.DeletedAt`/保留型 tombstone；`pending_delete` 仅用于排序存储清理，删除后行彻底消失。
- schema 无 `name/prompt/model` 列（model/creative_asset.go:37-56），上传 multipart 对这些字段一律 400 拒绝（controller/creative_asset.go:200-204）。
- **影响**: 跨设备删除同步无法实现（第二设备无 tombstone 可读 → 删除事件丢失）；资产无法携带名称/提示词/模型来源。R5 两个子项全失。

### G2 — R6 per-user 频率限制【partial 缺口】
- 已达成 3/4: 尺寸（64MB 双校验）、MIME（白名单 + SVG 拦截 + sniff）、总容量（按用户字节/数量配额 + DB/磁盘健康闸）。
- 缺失: upload 与所有 relay 路由**均未挂** `ModelRequestRateLimit` 或按用户键限流；唯一生效的是 IP 键 `GlobalWebRateLimit`，可被 IP 轮换绕过。`UploadRateLimit/DownloadRateLimit` 存在但 IP 基且零路由引用。
- **影响**: 单用户可高频刷上传/中继，滥用与成本放大敞口真实存在。

### G3 — R3 bootstrap 服务端字段缺位【partial】
- 模型白名单已服务端驱动（per-group），核心安全诉求满足。
- 缺失: 无服务端默认模型字段、可用分组未下发（`ownerGroups` 内部算后丢弃 creative.go:1339-1343）、无独立能力矩阵、无顶层 `enabled` 标志。
- 与下方偏离 D1 互为表里（双端一致取舍）。

---

## 3. 发布前必修缺陷（本轮独立重审新发现，之前报告未点出）

### ⚠️ B1 — `model_name` 计费套利 + 模型池白名单绕过【HIGH，确认】
- **链路**: 提交体禁止字段过滤器 `CreativeRejectForbiddenRelayFields`（router web-router.go:97，递归）对每个 key 走 `creativeForbiddenRelayBodyKey`。`model_name` 经 `creativeNormalizeRelayFieldName` 归一化为 `modelname` —— **不在**禁止名单（名单只有 `model/xmodel/modelid/modeloverride`，controller/creative.go:1646-1674）；且 `creativeRelayFieldSegments` 分隔符集合**不含下划线**（creative.go:1682），`model_name` 不拆分为 `model`。两道防线都漏过。
- **消费侧**: `taskcommon.UnmarshalMetadata` 只 `delete(metadata, "model")`，**不删 `model_name`**（relay/channel/task/taskcommon/helpers.go:20-22）；Kling 等 `requestPayload` 带 `json:"model_name"` tag（kling/adaptor.go:66），metadata 里的 `model_name` 反序列化**覆盖**发往上游的模型（kling/adaptor.go convertToRequestPayload）。受影响 adaptor: kling/vidu/jimeng/gemini/vertex/doubao。
- **计费侧**: 计费锁定顶层 `info.OriginModelName`（relay_task.go:169-181），`AdjustBillingOnSubmit` 为 `BaseBilling` 空实现（taskcommon/helpers.go:90），**从不按 metadata.model_name 重定价**。
- **后果**: 用户提交 `{"model":"便宜模型","metadata":{"model_name":"贵模型"}}` → 按便宜模型计费、上游执行贵模型；同时 metadata.model_name 绕过 distributor 的模型池白名单校验。
- **修复**: ① 禁止名单递归覆盖所有别名 `modelname/model_name/modelId/upstream_model` 等（建议归一化后用 `strings.Contains(normalized,"model")` 收口或显式枚举）；② metadata merge 后**强制重写**为服务端选定的上游模型字段，禁止 metadata 覆盖 model 类字段。
- 备注: Codex 定级 CRITICAL。主控裁定 HIGH —— 利用面限于 video-class provider 且需该上游接受 model_name 覆盖；但属直接经济损失 + 访问控制绕过，发布前必修。

### ⚠️ B2 — 上游已提交后因本地 DB 写失败而退款 → 免费任务 + 追踪丢失【HIGH，确认】
- **链路**: 上游 submit 成功并拿到 `UpstreamTaskID`（relay_task.go:240-258）→ 返回非空 result → controller/relay.go:614 `task.Insert()` 或 :617 `CompleteCreativeVideoIdempotencyScoped` 失败置 `taskErr` → defer（relay.go:519-523）在 `taskErr != nil` 时**无条件** `Billing.Refund(c)`。
- **后果**: 上游任务在跑（真实成本），用户被全额退款（免费），幂等记录卡在 preparing（重试拿不到结果，但不会二次提交——幂等保护已正确，shouldDelete 仅 `!taskPersisted && result==nil`，relay.go:651-657），task 行缺失 → 轮询追踪永久丢失。
- **触发前提**: DB 写故障（非常态、非攻击者可控），但后果是计费与任务状态不一致。
- **范围澄清**: settle 路径**已安全**（`SettleSubmittedTaskBillingDurably` enqueue 成功即返回 nil → 不触发退款；仅 enqueue 失败才退款，此时 outbox 未建退款合理，task_billing.go:172）。真正缺口仅 insert/idempotency 两条。
- **修复**: 上游 accepted 后 insert/idempotency 失败时**不得走预扣退款**；改为标记 task 为 billing-pending + 落 recovery/outbox，由 durable worker 结算或补偿（与既有 `TaskBillingOutbox` 机制对齐）。
- 备注: Codex 定级 CRITICAL（含 settle 路径）；主控核验后将 settle 路径排除（已被 outbox 保护），范围收窄至 insert/idempotency，定 HIGH。

---

## 4. 矛盾裁决记录（多源结论冲突，主控代码级钉死）

### SW scope: Gemini「HIGH 可控根路径」 vs workflow「met」→ 裁定 **met（Gemini 误报）**
- Gemini 审的是 opentu **独立部署**（SW 从根注册 → 能拦 `/api`）。
- 但**嵌入态**: `sw.js` 仅在 `/creative/sw.js` 提供（web-router.go:312），全仓**无** `Service-Worker-Allowed` 头，`main.tsx:525` 用相对 `./sw.js` 注册 → 默认 scope 即资源所在目录 `/creative/`，浏览器规范上**无法**逃逸到根/`/api`/`/v1`。
- 符合全局协议警示「Gemini 对后端/部署理解有缺陷，需客观审视」。建议: 仍可加显式 `{scope:'/creative/'}` 作纵深防御（LOW，非阻断）。

### 计费机制 `IsPlayground=true`（relay_info.go:507）—— 未声明偏离，安全
- PRD 称唯一差异是 `TokenId==0`，实现额外置 `IsPlayground=true` 跳过 token 配额扣减。功能正确（临时空 key token 本无配额，钱包仍正常扣费），属「更正确」的多机制实现，不破坏验收。

---

## 5. 偏离清单（deviated — 多为更安全的有意收敛，建议回写 PRD）

### D1 — R3 服务端驱动 UI 策略 → 前端硬编码并主动剥离【安全偏离，可接受】
- 仅**模型列表**真正服务端驱动；默认模型/能力矩阵/可用分组改为前端常量，且 `stripCreativeServerUiPolicy` 递归删除服务端返回的 `defaultModel/group(s)/displayPolicy/uiPolicy`（creative-display-policy.ts:11-80）。
- 比 PRD 更保守 —— 杜绝服务端注入展示策略的攻击面。与 G3 后端缺省字段缺位一致，是双端一致设计取舍，非疏漏。
- 备注: Gemini 定级 CRITICAL（按 PRD 字面）；主控裁定为**可接受偏离**（功能正确、更安全），仅需回写 PRD 与决策记录。

### D2 — R6 短时签名 URL → owner-scoped 同源代理流式下载【更安全】
- 任何签名 URL 都不下发浏览器，改 `CreativeGetAssetContent` 同源代理；签名仅限服务端↔S3 段，主动拒绝 `signedurl/objectkey` 字段。比 PRD 更安全。

### D3 — R5 容量配额 vs 决策4「不设 byte-quota」冲突 → 实现选了 R5【两权威源打架】
- 代码实现独立 byte-quota（`UserMaxBytes` 默认 2GiB + 全局/用户 DB 上限）。PRD R5 与决策4 直接矛盾，从未显式 reconcile，建议产品侧拍板后回写。

---

## 6. 其他确认缺陷（非阻断，建议排期）

| 级别 | 位置 | 问题 | 修复 |
|------|------|------|------|
| HIGH | relay_info.go:523-537 + override.go:941 | 仅当管理员配置 header-override/pass_headers 时，Cookie/CSRF/nonce 可被转发上游 | creative 请求源头剥离 Cookie/X-Creative-*/Authorization，禁止 override 显式转发敏感头 |
| HIGH | task_polling.go:298-303,599; video_proxy.go:147 | 多处脱敏前 log 完整上游响应体 / 带 key 的 Gemini URL / presigned URL | 统一先 redactor + 长度上限再 log |
| MEDIUM | relay_task.go:225; kling/suno/vidu adaptor | task submit 非 200 分支 `ReadAll` 后未 `Close`，连接池泄漏 | `DoRequest` 成功后统一 `defer resp.Body.Close()` |
| MEDIUM | controller/creative.go:575; relay_task.go:313; model/task.go:454 | Suno/MJ list-by-condition 接受无上限 `[]any` IN 查询（无注入但可 DoS） | 改 `[]string` + 数量上限（≤200）+ 长度校验 |
| MEDIUM | service/creative_asset.go:317-324 | S3 先 Put 对象后写 DB，进程崩溃留孤儿对象 | 先写 pending 元数据/outbox 再上传 finalize，或前缀扫描 GC |
| MEDIUM | creative_asset.go:287→324 | 配额 check 与 Create 无事务/锁，并发上传可协同击穿全局字节上限 | check+insert 入同一事务 + per-user 配额行原子预留（注: 06-11 任务声称已修，需复核是否落地） |

### 前端（Gemini 提出，主控复核）
| 级别 | 位置 | 主控复核 |
|------|------|---------|
| HIGH | video-api-service.ts:121; audio-api-service.ts:114 | 幂等 key 缺失时 fallback 生成随机 key，reload 中断可能二次提交。**建议复核**: taskId 应强制为幂等源 |
| MEDIUM | provider-transport.ts:110-285 | 敏感路由头/query 用黑名单剥离，新增 vendor 头可能漏。建议转白名单（纵深防御） |
| MEDIUM | creative-cloud-sanitizer.ts:1-45 | 黑名单字段 + 值检测，结构化敏感数据可能漏同步。建议 Board 属性白名单 |
| LOW | creative-document-assets.ts:153 | `STORAGE_HOST_PATTERNS` 静态列表，可能漏区域性 S3/私有 MinIO |

---

## 7. 待修清单（按优先级）

**P0（发布前必修）**
1. B1 — `model_name` 计费套利 + 模型池绕过
2. B2 — 上游已提交后 DB 写失败误退款（免费任务 + 追踪丢失）

**P1（目标硬缺口，决定是否宣告 PRD 达标）**
3. G1 — R5 软删除 tombstone + name/prompt/model 元数据列
4. G2 — R6 per-user 频率限制

**P2（安全加固 / 非阻断）**
5. §6 HIGH 两条（header 转发、日志脱敏）
6. §6 MEDIUM 五条 + 前端 §6 各条

**P3（文档对齐，非代码）**
7. 回写 PRD/决策: D1（服务端驱动收敛）、D2（签名 URL→同源代理）、D3（byte-quota reconcile）、G3（bootstrap 字段）

---

## 8. 总评

后端全链路中继、容灾（标准重试/自动封禁/跨组）、视频幂等与 key 亲和、计费/日志/任务记录、资产跨设备懒下载、前端零兜底 + 递归脱敏均**已达 Phase 3 终点且有专测**，Trellis 的 Completed 勾选经得起代码核验，无注水。

**但本轮独立重审在「之前报告判定通过」的计费/安全路径上挖出 2 个发布前必修缺陷（B1/B2）**，加上既有的 2 项 R5/R6 硬缺口（G1/G2），共 4 项需闭合方可宣告完整达标。其余 deviated 项为「代码比 PRD 更保守/更安全」的有意取舍，不阻断交付，仅需回写文档。
