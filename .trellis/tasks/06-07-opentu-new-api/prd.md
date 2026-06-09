# Opentu 嵌入 new-api 集成评估文档

## Goal

系统性评估将 [`ljquan/opentu`](https://github.com/ljquan/opentu) 作为 `new-api` 的「创意（画图/视频/音乐）」能力嵌入 [`QuantumNous/new-api`](https://github.com/QuantumNous/new-api) 的需求、可选方案、技术风险、上游 provider 适配、多渠道容灾、资产云同步，以及使用 Codex 分阶段落地的可行性。本文档用于后续产品决策、技术评审和实施拆解。

## What I already know

- 用户希望在 new-api 导航中新增或承载类似截图里的「创意（画图/视频/音乐）」入口。
- 目标不是单纯放一个链接，而是评估 Opentu 与 new-api 的深度整合，包括：
  - Opentu 作为创作工作台嵌入 new-api；
  - new-api 作为唯一 provider gateway；
  - 上游 provider 适配与多渠道容灾；
  - Opentu 资产通过简单存储层实现云同步；
  - Codex 是否能承担主要实施工作。
- 本轮已经检查两个上游仓库的当前源码快照：
  - `ljquan/opentu`：浅克隆 commit `bf44d14`。
  - `QuantumNous/new-api`：浅克隆 commit `4ca47ee`。
- Opentu 是大型 React 18 + Vite + Nx + pnpm + Plait 画布应用，不是普通单页组件。
- new-api 是 Go/Gin 后端 + React 19/Rsbuild/Bun 前端 + Go embed 静态资源的 AI 网关/管理系统。
- new-api 已具备图片、视频、Suno、Midjourney、OpenAI compatible、Gemini 等 relay/task 路由基础，以及多渠道选择、重试、自动禁用、multi-key、channel affinity 等能力。

## Requirements

### R1. 集成目标

- 在 new-api 中提供「创意（画图/视频/音乐）」入口。
- 用户进入该入口后可以使用 Opentu 的画布、素材库、图片生成、视频生成、音乐生成等创作能力。
- Opentu 不应直接接管 provider 路由、计费、渠道容灾；这些能力应收敛到 new-api。

### R2. 推荐集成模式

- 首选将 Opentu 作为独立微前端/同源静态应用挂载在 new-api 下，例如：

  ```text
  /creative/
    index.html
    sw.js
    assets/...
  ```

- 不推荐第一阶段源码级合并 `@drawnix/drawnix` 到 new-api 默认 React app。
- Opentu Service Worker 必须限制在 `/creative/` 作用域，不能控制 new-api 根站、`/api`、`/v1`、`/assets` 等路径。

### R3. Provider Gateway 与模型来源

- Opentu 应将 new-api 视为唯一 Creative Gateway provider。
- 模型列表、能力矩阵、可用分组、默认模型应由 new-api 暴露给 Opentu。
- Opentu 前端不应直接维护多套上游 provider 失败重试逻辑。
- 新增或扩展 provider 时，优先在 new-api 渠道/模型配置层完成，减少 Opentu 变更。

### R4. 多渠道容灾

- 图片、视频、音乐、Midjourney 类请求应进入 new-api 的 relay/task 流程。
- new-api 负责：
  - `group + model` 渠道选择；
  - priority / weight；
  - retry；
  - auto group；
  - cross-group retry；
  - multi-key；
  - channel affinity；
  - 自动禁用异常渠道；
  - 计费预扣、退款、结算；
  - 任务日志。
- 对异步任务（视频、音乐、MJ）必须避免重复提交、重复扣费、跨渠道轮询失败。

### R5. 资产云同步

- 增加一层简单存储层，用于同步 Opentu 的资产库。
- MVP 只同步素材资产，不同步完整画布、多人协作状态或任务队列内部状态。
- 需要同步：
  - metadata：素材 id、类型、名称、mime、size、contentHash、prompt、model、createdAt、updatedAt；
  - binary：图片、视频、音频文件本体。
- 推荐后端形态：
  - metadata 存 new-api DB；
  - binary 先支持本地 `/data/creative-assets`，产品级再支持 S3/R2/MinIO。
- 需要 contentHash 去重、lazy download、软删除 tombstone、用户隔离、容量配额。

### R6. 安全与权限

- Creative 入口必须遵守 new-api 登录态和用户权限。
- 浏览器端暴露长期 API key 风险较高；MVP 可使用专用受限 token，长期推荐 session-auth creative relay。
- 资产访问必须按 user_id 隔离。
- 上传需要文件大小、mime、总容量和频率限制。
- 对象存储下载 URL 应使用短期签名 URL。

### R7. 许可证与合规

- Opentu 为 MIT，new-api 为 AGPL-3.0。
- 如果分发包含 Opentu 代码/构建产物，应保留 MIT notice。
- new-api 修改版作为网络服务运行时需关注 AGPL 源码提供义务。

## Acceptance Criteria

### Documentation acceptance

- [x] 明确需求范围和目标。
- [x] 明确不推荐源码级合并作为第一阶段方案。
- [x] 给出推荐架构和替代方案。
- [x] 覆盖 provider 适配与多渠道容灾设计。
- [x] 覆盖资产云同步设计。
- [x] 覆盖 Codex 实施可行性和分阶段路线。
- [x] 给出风险矩阵和难度评估。

### Future implementation acceptance

- [ ] `/creative/` 能在 new-api 同源访问。
- [ ] 刷新 `/creative/` 不 404。
- [ ] Opentu Service Worker scope 仅限 `/creative/`。
- [ ] Opentu 可从 new-api 获取 bootstrap 配置。
- [ ] 图片生成至少一条链路走通 new-api `/v1/images/generations`。
- [ ] 视频生成至少一条链路走通 new-api `/v1/videos` + poll + content。
- [ ] 音乐生成至少一条链路走通 new-api `/suno/submit/music` + fetch。
- [ ] MJ imagine 至少一条链路走通 new-api `/mj/submit/imagine` + fetch。
- [ ] 失败请求能在 new-api 日志中看到 channel retry 路径。
- [ ] 成功请求计费、日志、任务记录正常。
- [ ] 素材新增后能上传云端，并在另一设备 lazy download。

## Definition of Done

对本任务（文档任务）：

- [x] PRD 已创建并记录核心需求。
- [x] 详细方案报告已创建。
- [x] 文档包含需求、架构、风险、阶段、Codex 可行性。
- [x] 文档路径在最终回复中给出。

对未来实施任务：

- 代码变更小步提交。
- 相关 lint/typecheck/test 通过。
- Docker 构建链路可复现。
- 关键路径有 E2E 或手工验收脚本。
- 安全、配额、回滚策略记录清楚。

## Technical Approach

推荐采用三层结构：

```text
new-api 主应用
  ├── 导航/权限/用户体系
  ├── Creative bootstrap / session relay / asset APIs
  └── /creative/ 静态挂载 Opentu

Opentu Creative Workspace
  ├── 画布、素材库、创作 UI
  ├── 本地 IndexedDB / Cache Storage
  └── Creative Gateway Provider Adapter

new-api Provider Gateway
  ├── relay / task router
  ├── channel selection / retry / auto-ban / affinity
  ├── billing / logs / quota
  └── upstream providers
```

### 最小推荐架构

```text
Opentu UI
  → NewAPI Creative Gateway Provider
  → new-api /v1, /suno, /mj routes
  → new-api channel/task/relay
  → upstream providers
```

### 资产同步架构

```text
Opentu AssetStorageService / UnifiedCacheService
  → CloudAssetSyncService
  → /api/creative/assets
  → DB metadata + local disk / S3 object storage
```

## Decision (ADR-lite)

### Context

Opentu 与 new-api 的前端技术栈、运行时假设和构建体系差异较大：Opentu 是 React 18 + Vite/Nx + Service Worker + IndexedDB/Cache Storage 的完整创作应用；new-api 默认前端是 React 19 + Rsbuild + TanStack Router，并由 Go embed 进后端二进制。直接源码级融合会带来 React 版本冲突、构建链复杂化、Service Worker 污染、样式/状态冲突和长期维护成本。

### Decision

第一阶段采用同源独立微前端方式，将 Opentu 构建产物挂载到 new-api `/creative/`，并通过 new-api 提供 Creative bootstrap、provider gateway 和资产同步 API。Provider routing、计费、日志、多渠道容灾全部由 new-api 统一负责。

### Consequences

优点：

- 快速验证产品价值。
- 最大限度保留 Opentu 原有功能。
- 避免 React 18/19 源码冲突。
- 可以复用 new-api 现有渠道、计费、容灾能力。
- 后续 provider 接入主要在 new-api 完成。

代价：

- UI 风格短期会有割裂。
- Docker/CI 多一个前端构建产物。
- 需要认真隔离 Service Worker scope。
- 需要新增 bootstrap/token/session relay 和资产 API。
- 如果未来要原生融合，仍需更大迁移。

## Out of Scope

当前文档任务不包含代码实现。

未来 MVP 不建议包含：

- 源码级合并 Opentu 到 new-api default React app。
- 多人协作编辑。
- 完整画布云同步。
- 完整任务队列云同步。
- 复杂资产版本冲突 UI。
- 自研 provider 多渠道路由在 Opentu 前端重复实现。
- 一开始就强依赖 S3/R2；本地磁盘可作为 MVP。

## Open Questions

后续实施前建议确认：

- Creative 是否对所有登录用户开放，还是仅特定分组/管理员开放？
- MVP 是否接受前端持有一个专用受限 API token，还是必须第一版就做 session-auth creative relay？
- 资产云同步第一版使用本地磁盘还是直接接 S3/R2/MinIO？
- 是否需要把 Opentu 的 UI 主题调整到 new-api 风格，还是先保留 Opentu 原风格？
- 首批必须跑通的 provider/model 列表是什么？

## Technical Notes

源码检查要点：

- Opentu：
  - `README.md` 描述平台能力：AI 生成与模型路由、画布工作区、任务与素材管理、工具箱、PPT/内容工作流。
  - `apps/web/project.json` 使用 Nx target 构建 `web` 和 `sw`。
  - `apps/web/vite.sw.config.ts` 输出 `sw.js`。
  - `apps/web/src/main.tsx` 注册 `./sw.js`。
  - `packages/drawnix/src/services/asset-storage-service.ts` 使用 localForage 保存资产 metadata。
  - `packages/drawnix/src/services/unified-cache-service.ts` 管理媒体 cache/blob。
  - `packages/drawnix/src/services/provider-routing/*` 已有 provider binding 抽象。
- new-api：
  - `Dockerfile` 构建 `web/default` 与 `web/classic` 后由 Go embed 打入二进制。
  - `router/web-router.go` 负责静态资源服务与 SPA fallback。
  - `router/relay-router.go` 支持 `/v1/images/generations`、`/v1/images/edits`、`/suno/*`、`/mj/*` 等。
  - `router/video-router.go` 支持 `/v1/videos`、`/v1/videos/:task_id`、`/v1/videos/:task_id/content`。
  - `middleware/distributor.go` 负责模型解析与 channel selection。
  - `service/channel_select.go` 负责 auto group / cross-group retry 选择。
  - `controller/relay.go` 负责 relay retry、task retry、计费回滚、日志。

## Related Documents

- [`integration-assessment.md`](integration-assessment.md) — 完整专业评估报告。
