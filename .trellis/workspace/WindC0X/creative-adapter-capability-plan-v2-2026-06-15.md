# Creative Adapter Capability Registry v2 方案

日期：2026-06-15  
范围：`new-api` 内嵌 OpenTU Creative 的模型能力目录、动态参数 schema、供应商请求适配、异步任务、结果私有化、管理端配置与发布门禁。  
当前阶段：方案与审查；不进行真实供应商调用，不消耗额度。

## 0. 结论先行

推荐路线是：**在 `new-api` 内建设 Creative Adapter Capability Registry（能力注册表 + 内置安全 preset），OpenTU 只做动态 UI 渲染和统一提交。**

不建议只靠现有 new-api channel 配置，也不建议长期放一个外部中间件。原因：Creative 生成链路同时依赖 new-api 的用户、分组、渠道、额度、任务归属、幂等、CAS 结算、URL 私有化和安全清洗；如果适配逻辑放到 OpenTU 或外部中间件，会绕开这些边界。

## 1. 背景问题

目前 `/creative/api/bootstrap` 可以下发登录用户在 new-api 中可用的模型池，但 OpenTU 的模型参数主要来自前端静态 `model-config.ts`，导致：

1. new-api channel 新增运行时图片模型后，OpenTU 能看到模型，但参数面板可能为空或错误。
2. 同名模型在不同渠道的真实 API 形态不同，例如 `gpt-image-2` 在 Duomi、Grsai 的路径、字段、异步模式、返回结构可能完全不同，不能只按 provider model id 合并。
3. 现有 new-api 的 `model` 字符串同时承担授权、modality、渠道选择、计费、policy/preference key 等语义；直接把 “模型变体 id” 当普通 model 塞进去会破坏这些链路。
4. 当前 OpenTU 会构造本地 `selectionKey = new-api-creative::<id>`；它是 UI 来源键，不应直接成为后端模型 id。
5. `dto.ImageRequest.Extra` / 前端 `params` 不是稳定的跨仓契约：OpenTU 内部回调、幂等键、用户参数混在一起，后端也不会自然把 Extra 合并到 provider body。

## 2. 目标与非目标

### 2.1 目标

- new-api 成为 Creative 模型能力、参数 schema、供应商 preset、渠道绑定、任务归属和结果 DTO 的权威来源。
- OpenTU 支持后端下发 `parameterSchema`，优先用运行时 schema 渲染参数。
- 支持同名 provider 模型的多渠道/多接口变体，例如：
  - `duomi:gpt-image-2:async`
  - `grsai:gpt-image-2:generate`
  - `grsai:gpt-image-2-vip:generate`
  - `grsai:gpt-image-2:openai-images`
  - `grsai:nano-banana:draw`
- 后端对用户参数进行白名单、类型、枚举、范围、危险字段递归校验。
- 异步提交、轮询、计费、退款、结果 URL 私有化统一由 new-api 处理。
- 管理端配置必须可校验、可 dry-run、可回滚；不能让 raw option JSON 成为生产唯一入口。

### 2.2 非目标

- 不让 OpenTU 保存或传入供应商 API key/baseURL/header/path。
- 不让管理员在 Phase 1 配置任意 URL、任意 header、任意 JSONPath、任意 JS/DSL。
- 不在 OpenTU 内硬编码 Duomi/Grsai 的供应商协议。
- 不在没有 fixture 和 mock upstream 测试前发起真实 Duomi/Grsai 付费调用。
- 不把 provider 同名模型自动合并成一个 UI 模型。

## 3. 冻结跨仓线协议

### 3.1 模型 id 语义

**唯一推荐契约：**

```text
CatalogItem.id              = backend raw bindingId（OpenTU 提交给 new-api 的 model 值）
CatalogItem.providerModelId = 真实供应商模型名（仅展示、诊断、后端上游请求用）
OpenTU local selectionKey   = UI 内部来源键；不得作为 relay payload model 发给 new-api
Relay payload model         = raw bindingId
Relay payload userParams    = 按 parameterSchema 收集的用户参数对象
```

示例：

```json
{
  "id": "grsai:gpt-image-2-vip:generate",
  "providerModelId": "gpt-image-2-vip",
  "displayName": "GPT Image 2 VIP · Grsai",
  "type": "image",
  "modality": "image",
  "owned_by": "grsai",
  "supportedEndpointTypes": ["images.task"],
  "parameterSchema": [
    {"id":"size","label":"尺寸","type":"enum","defaultValue":"1024x1024","options":[{"value":"1024x1024","label":"1024×1024"}]},
    {"id":"quality","label":"质量","type":"enum","defaultValue":"auto","options":[{"value":"auto","label":"自动"},{"value":"high","label":"高"}]}
  ]
}
```

兼容规则：

- 后端可为旧 `creative.model_policy` 或用户偏好中的 provider model id 提供 alias/stale diagnostics，但新策略主键必须逐步迁移到 binding id。
- OpenTU 可保留本地 `selectionKey` 做 React key / profile 来源，但提交时必须使用 `model.id`（即 raw binding id）。
- 同一个 `providerModelId` 的两个 binding 必须有独立偏好、参数 schema、排序和可用性。

### 3.2 Relay 请求契约

首版 Creative image task 请求建议：

```json
{
  "model": "grsai:gpt-image-2-vip:generate",
  "prompt": "...",
  "images": ["https://..."] ,
  "userParams": {
    "size": "1024x1024",
    "quality": "auto"
  }
}
```

约束：

- `userParams` 只包含 schema 字段；不包含 `onProgress`、`onSubmitted`、`idempotencyKey`、函数、内部 adapter 选项。
- legacy `params` 可短期兼容，但进入后端前统一归一化为 `userParams`；后端对 `params` 和 `userParams` 同时出现时 fail-closed 或以 `userParams` 为唯一入口并记录 diagnostics。
- `size/duration/aspectRatio` 不再由前端旧逻辑改写后丢失；OpenTU 对 backend schema 模型按原始 schema id 收集参数。

## 4. new-api 后端设计

### 4.1 配置模型：CreativeModelBinding

首版保存仍可使用 versioned option JSON，但必须通过专用 API 校验后写入。

```json
{
  "version": 1,
  "bindings": [
    {
      "id": "grsai:gpt-image-2-vip:generate",
      "providerModelId": "gpt-image-2-vip",
      "displayName": "GPT Image 2 VIP · Grsai",
      "modality": "image",
      "enabled": true,
      "group": "default",
      "channelId": 12,
      "adapterPreset": "grsai_gpt_image_generate",
      "parameterTemplate": "grsai_gpt_image_2_vip",
      "priceModelId": "gpt-image-2-vip",
      "recommendedScore": 90,
      "sortOrder": 10,
      "aliases": ["gpt-image-2-vip"]
    }
  ]
}
```

关键规则：

- `id` 全局唯一；只允许安全字符集；不能等于 provider model id 除非该 binding 明确唯一且无歧义。
- `providerModelId` 是上游请求模型。
- `priceModelId` 默认等于 provider model id；如要按 binding 单独计价，必须有明确价格配置和测试。
- `channelId` 若存在，必须在保存时和请求时二次校验：channel enabled、用户 group 可用、支持 providerModelId、支持 modality/endpoint、未被禁用。
- `adapterPreset` 和 `parameterTemplate` 只能引用内置白名单。
- `enabled=false` 的 binding 可保存但不下发、不允许提交。

### 4.2 管理 API：禁止 raw option 直写成为生产路径

新增：

```http
GET  /api/creative/model-bindings
PUT  /api/creative/model-bindings
POST /api/creative/model-bindings/validate
POST /api/creative/model-bindings/dry-run
```

`validate` / `PUT` 必须返回：

- normalized bindings
- diagnostics：error/warning/info
- duplicate id、unknown preset/template、unknown group/channel、channel 不支持模型、错 modality、disabled channel、stale alias、policy stale item
- cleaned JSON preview
- catalog preview（按 group）
- dry-run request preview（脱敏 header，禁止输出 key/baseURL）

PUT 保存前 fail-closed：只要 enabled binding 有 error 就拒绝保存。

### 4.3 Binding Resolver 接入点

Resolver 必须在 relay 现有 model auth / modality / channel selection / pricing 前运行，或在这些步骤使用 resolver 后的元数据。流程：

1. 从 body 读取 `model`。
2. 若命中 binding id：
   - 校验 binding enabled、group/user 可用。
   - 校验 endpoint modality 与请求路由匹配，例如 image task 路由只能 image。
   - 校验 locked channel 或自动 channel 候选支持 `providerModelId`。
   - 将 provider model 写入 relay 内部 `OriginModelName` 或新增字段；同时保留 `BindingID`。
   - 计算 `PriceModelID`，避免 binding id 查不到价格。
   - 注入不可由前端覆盖的 `AdapterPreset`、`ParameterTemplate`、`LockedChannelID`、`ProviderModelID`。
3. 若未命中 binding id：走 legacy 模型路径，但不允许 legacy 请求携带 adapter-only 字段。

必须新增/扩展 `RelayInfo` 或上下文键：

```go
CreativeBindingID
CreativeProviderModelID
CreativeAdapterPreset
CreativeParameterTemplate
CreativePriceModelID
CreativeLockedChannelID
CreativeUserParams
```

注意：当前 `RelayTask` 已有 `relayInfo.LockedChannel` 分支，方案要保证 Creative binding 的 channel lock 能真正进入 `Distribute()` / `getChannel()` / retry 分支，而不是只在 catalog 中展示。

### 4.4 参数 schema 与校验

后端 schema：

```go
type CreativeParameterSchemaItem struct {
    ID           string                `json:"id"`
    Label        string                `json:"label"`
    ShortLabel   string                `json:"shortLabel,omitempty"`
    Description  string                `json:"description,omitempty"`
    Type         string                `json:"type"` // enum|string|number|integer|boolean
    DefaultValue any                   `json:"defaultValue,omitempty"`
    Options      []CreativeParamOption `json:"options,omitempty"`
    Min          *float64              `json:"min,omitempty"`
    Max          *float64              `json:"max,omitempty"`
    Step         *float64              `json:"step,omitempty"`
    Required     bool                  `json:"required,omitempty"`
    Hidden       bool                  `json:"hidden,omitempty"` // admin/server-side only, not user UI
}
```

校验规则：

- 未在 schema 中声明的用户字段拒绝。
- enum 必须命中 options。
- number/integer 做范围和 step 校验；前端字符串数字可由后端显式 cast。
- boolean 可接受 true/false，兼容字符串 `"true"/"false"` 仅作为迁移支持。
- 递归危险字段名归一化拒绝：`apiKey/api_key/authorization/bearer/token/baseUrl/url/endpoint/host/channelId/userId/owner/notifyHook/callback/webhook/mjApiSecret/modelId/providerModelId` 等；但要与现有 Creative 全局 forbidden guard 的行为对齐，避免下发一个 schema 后提交必然被 guard 拒绝。
- 用户参数不得影响 path/header/baseURL/channel/preset/provider model。

### 4.5 Adapter Preset 接口

内置 preset 只能用 Go 代码注册，不提供任意 URL/header DSL。

建议接口：

```go
type CreativeAdapterPreset interface {
    Key() string
    EndpointMode() CreativeEndpointMode // sync image, async task, poll
    ValidateBinding(binding CreativeModelBinding) []Diagnostic
    BuildSubmit(ctx CreativeAdapterContext, req CreativeSubmitRequest) (*http.Request, error)
    ParseSubmit(ctx CreativeAdapterContext, resp *http.Response, body []byte) (CreativeSubmitResult, error)
    BuildPoll(ctx CreativeAdapterContext, task CreativeTaskMetadata) (*http.Request, error)
    ParsePoll(ctx CreativeAdapterContext, resp *http.Response, body []byte) (CreativePollResult, error)
}
```

内置 body mapper 支持：

- 固定字段映射：prompt、images、providerModelId、schema params。
- conditional omit：空 `image` / `image_urls` / `urls` 不发送。
- server-side transform：ratio -> pixel size、boolean default、quality default。
- redacted request preview：不输出 key、Authorization、baseURL、signed URL、base64。

### 4.6 Async image 路由与任务持久化

不要假设现有 `/creative/relay/v1/images/generations` 同步 ImageHelper 能承载所有异步 provider。建议新增 task-aware 路由：

```http
POST /creative/relay/v1/images/tasks
GET  /creative/relay/v1/images/tasks/:taskId
```

返回统一 DTO：

```json
{
  "taskId": "public id",
  "status": "queued|running|succeeded|failed",
  "progress": 0,
  "assets": { "images": [{"url":"/creative/api/assets/..."}] },
  "error": null
}
```

任务持久化必须记录：

- `BindingID`
- `AdapterPreset`
- `ParameterTemplate`
- `ProviderModelID`
- `PriceModelID`
- `ChannelID`
- `UpstreamTaskID`
- `UserParams` normalized snapshot
- polling parser metadata（如需要）

存储位置可以先放 `Task.Properties` / `Task.PrivateData`，但需要迁移文档和测试。后台轮询必须从 task 上的 preset 分派，不能只按 platform/channel type 推断。

### 4.7 计费、幂等、CAS、退款门禁

异步 adapter 必须继承当前已修复的任务账务策略：

- provider accepted 后先本地插入 Task。
- idempotency mapping 完成失败不得让用户看到不可恢复成功；要有 syslog/outbox。
- `submit_settle` durable outbox 入队成功后才 flush 成功响应。
- 终态 CAS winner 才能结算/退款。
- provider accepted 但本地持久化失败必须按现有规则退款或记录不可退款异常。
- locked channel / selected key / upstream key affinity 必须持久化，fetch/poll 不允许前端覆盖。

### 4.8 结果 URL 私有化与资产链路

同步图片和异步图片都不能直接把供应商 URL 当长期结果暴露给浏览器。

首版要求：

- provider URL 先通过 new-api sanitizer，拒绝内网、file、credential query 等危险 URL。
- 成功结果返回 new-api controlled proxy/asset URL，或进入后续云同步/asset 表。
- 不要复用 video content proxy 假装覆盖 image；为 image 建专用 DTO/path。
- 上游错误和日志中 URL、key、base64、signed query 必须脱敏。

## 5. OpenTU 前端设计

### 5.1 Runtime catalog 类型扩展

`CreativeModelEndpointItem` / `ModelConfig` 增加：

```ts
interface CreativeParameterSchemaItem {
  id: string;
  label: string;
  shortLabel?: string;
  description?: string;
  type: 'enum' | 'string' | 'number' | 'integer' | 'boolean';
  defaultValue?: string | number | boolean;
  options?: Array<{ value: string | number | boolean; label: string }>;
  min?: number;
  max?: number;
  step?: number;
  required?: boolean;
}

interface ModelConfig {
  id: string;              // raw binding id
  providerModelId?: string;
  parameterSchema?: ParamConfig[];
}
```

转换规则：

- runtime `parameterSchema` 优先级最高。
- boolean 首版可转成 enum `true/false`，但提交前按 schema cast 回 boolean；或者实现原生 switch 控件。
- number/integer 可继续通过 input，但内部保留 typed value 或提交时 cast。
- 未知 schema type 不渲染并记录 console warn，不阻断整个模型。

### 5.2 参数优先级

```text
runtime model.parameterSchema > static model-config params > no params
```

`getCompatibleParams()` 不应只按 provider model id 查找；对于 Creative runtime 模型，必须按 binding id 或直接传 model object。

### 5.3 提交流程

- OpenTU 选择模型时使用 `model.id`（raw binding id）。
- 请求 new-api 时 `model = model.id`。
- 单独构造 `userParams`：从当前 schema 的 field id 收集所有已选参数，包含 `size/aspectRatio/duration`，不经过旧的 `1:1 -> 1x1` legacy normalize。
- 内部 adapter options 保持独立：`onProgress/onSubmitted/idempotencyKey/modelRef/sourceProfileId` 不得进 `userParams`。
- 同 providerModelId 的两个 binding 必须能独立保存 UI 选择和参数偏好。

## 6. Provider preset 首批建模

所有 provider preset 在真实调用前必须有 captured fixture 或 mock fixture。以下是目标建模，不代表立即可生产调用。

### 6.1 Duomi `gpt-image-2` async

- Submit: `POST /v1/images/generations?async=true`
- Body: `model`, `prompt`, `size`, conditional `image`
- Poll: `GET /v1/tasks/{id}`
- Result candidate: `data.images[].url`（需 fixture 确认）
- Auth builder：待确认；默认按 OpenAI-compatible `Authorization: Bearer <key>`，若文档/实测证明 raw key 再单独 preset。

### 6.2 Duomi Nano Banana

- Text: `POST /api/gemini/nano-banana`
- Edit: `POST /api/gemini/nano-banana-edit`
- Body: `model?`, `prompt`, `aspect_ratio`, `image_size`, hidden/admin-only `oversea`, conditional `image_urls`
- Poll: `GET /api/gemini/nano-banana/{id}`
- 需 fixture 固化：成功 `code` 集合、`data.images` vs `data.data.images`、`status` string/number、失败 msg 路径。

### 6.3 Grsai `gpt-image-2` generate

- Submit: `POST /v1/api/generate`
- Body: `model`, `prompt`, conditional `images`, `aspectRatio`, `quality`, hidden `replyType=async`
- Poll: `GET /v1/api/result?id={id}`
- Parser 必须支持：`id/taskId/task_id/requestId/data.id`，running 状态集合，succeeded 暂无 URL 继续轮询，URL 多路径递归提取，错误字段脱敏。

### 6.4 Grsai `gpt-image-2-vip` generate

单独 binding/template：

- provider model: `gpt-image-2-vip`
- `size` 只允许像素尺寸，或服务端从 ratio+resolution 转像素。
- `quality: auto|low|medium|high`，默认 `auto`。
- 不复用普通 `gpt-image-2` 的比例 enum。

### 6.5 Grsai OpenAI-compatible images

- Submit: `POST /v1/images/generations`
- Body: `model`, `prompt`, conditional `image`, `size`, `quality`, fixed `response_format=url`
- 首版强制 `n=1`；禁止 `b64_json/background/output_format/output_compression` 暴露。
- 若返回 URL，同样进入 image sanitizer/private asset。

### 6.6 Grsai Nano Banana draw

不要复用 `grsai_generate`，单独 preset：

- Submit: `POST /v1/draw/nano-banana`
- Body: `prompt`, conditional `urls`, `aspectRatio`, `imageSize`, hidden/admin-only `shutProgress/webHook` 不暴露。
- Poll: `POST /v1/draw/result` body `{id}`
- Result: `data.results[].url`，状态 `data.status`，失败 `error/msg/failure_reason`。
- provider model id 必须根据实测模型列表确认后再 enabled。

## 7. 分阶段实施计划

### Phase 0 — 任务边界整理

- 归档已完成的 origin hotfix Trellis 任务，另建 `creative-adapter-capability-registry` 任务。
- 明确本阶段不触发真实 provider 调用，不改生产配置。

### Phase A — Catalog/Schema preview（无 provider 调用）

交付：

- new-api DTO 增加 `providerModelId`、`displayName`、`parameterSchema`、`catalogVersion`。
- new-api 内置一个 fake/canary binding，仅对 test group 下发。
- OpenTU 保留并消费 runtime `parameterSchema`。
- OpenTU 参数 UI 支持 enum/number/string/boolean 映射。
- OpenTU 提交 payload 中可形成 `model=bindingId` + `userParams`，但默认不进入真实 provider。

验收：

- 切换不同 binding，参数列表随 schema 变化。
- 同 provider model 两个 binding 不互相覆盖偏好。
- 没有 schema 的模型仍走静态 fallback。
- 无登录/非 canary 用户看不到 preview binding。

### Phase B — Admin validator + dry-run preset（仍无 provider 调用）

交付：

- `GET/PUT/POST validate/dry-run /api/creative/model-bindings`。
- 内置 templates/presets 的 normalize/validate/dry-run。
- provider fixtures 单测。
- recursive denylist、conditional omit、redacted preview。

验收：

- 错 channel/group/modality/unknown preset/duplicate id 被拒绝。
- dry-run 能展示脱敏后的 path/method/body，不含 key/baseURL。
- Duomi/Grsai fixtures 覆盖 submit id、poll success/running/failed、late result、无参考图/多参考图。

### Phase C1 — Mock upstream task full chain

交付：

- 新 image task route submit/fetch。
- mock creative adapter preset。
- Task metadata 持久化。
- URL sanitizer/private image DTO。
- 计费/幂等/outbox 使用 mock，不打真实 provider。

验收：

- provider accepted + insert fail、settle fail、idempotency fail、双 poller CAS、refund pending 均有测试。
- fetch 只能取本人任务，且 task 上的 binding/preset/channel 不可由前端覆盖。

### Phase C2 — 单 preset canary

交付：

- 选择一个低风险 preset（优先 Grsai OpenAI-compatible 或 mock-compatible）对 test group/canary user 启用。
- 真实调用必须单独授权，并设置小额度/测试 key/单 channel。

验收：

- 成功图像 URL 被私有化。
- provider 错误脱敏。
- kill switch 可即时隐藏 binding 并拒绝提交。

### Phase C3 — 扩大 provider preset

交付：

- Duomi async、Duomi nano、Grsai generate/vip/draw 逐个启用。
- 每个 preset 独立 canary、独立回滚。

验收：

- 每个 preset 有 fixture + mock + canary evidence。
- metrics/日志能按 binding/preset/channel/taskId 排查失败。

### Phase D — 管理 UI

交付：

- new-api 管理后台 Creative 模型能力页面。
- 配置预览、dry-run、diagnostics、policy stale 修复入口。
- 默认/推荐模型选择展示 binding displayName，而不是只展示 provider model id。

## 8. 测试矩阵

### new-api

- service: binding JSON normalize、version fail-closed、duplicate id、unknown preset/template、denylist、schema cast。
- catalog: 按用户 group/channel/model/modality 过滤；enabled=false 不下发。
- broker/resolver: binding id 解析、provider model rewrite、price model、channel lock、wrong group/modality/channel 拒绝。
- admin API: validate/dry-run/PUT cleaned JSON；错误诊断稳定。
- adapter presets: per-provider fixture table tests。
- task: submit/fetch、Task metadata、CAS、outbox、refund、idempotency、locked channel affinity。
- sanitizer: provider URL -> private image asset；危险 URL 拒绝；错误/log redaction。

### OpenTU

- runtime normalize: 保留 `parameterSchema/providerModelId/id`。
- `getCompatibleParams`: runtime schema 优先，静态 fallback。
- UI: enum/number/string/boolean 渲染；默认值；未知 type 降级。
- payload: `model` 为 raw binding id，`userParams` 完整且 typed；内部回调不混入。
- preference/policy: 同 providerModelId 多 binding 独立。
- build/typecheck/e2e: Creative embedded artifact 同步到 new-api。

### 发布门禁

- new-api targeted Go tests + `go build ./...`。
- OpenTU typecheck/unit/e2e（至少相关包）。
- `creative_release_gate.py build-sync-check --run-new-api-tests`。
- 本地/容器 staging route/header matrix。
- no-secrets grep：日志、dist、配置不含 key。
- image ID/digest 记录、option backup、rollback 命令记录。

## 9. Feature flags、灰度、回滚

- 全局：`creative.adapter.enabled=false` 默认关闭。
- per-binding：`enabled` + `canaryGroups` / `canaryUsers`。
- dry-run-only：Phase B/C1 只允许 dry-run/mock。
- kill switch：关闭后 bootstrap 不下发，relay 提交立即 403/404，不影响 legacy Creative 模型。
- rollback：恢复上一版 option JSON；回滚镜像；清理 preview binding；保留任务表 metadata 兼容读取。

## 10. 可观测性

结构化日志/metrics 字段：

- `bindingId`
- `providerModelId`
- `adapterPreset`
- `parameterTemplate`
- `channelId`
- `platform`
- `publicTaskId`
- `upstreamTaskId`（必要时 hash/截断）
- `upstreamStatus`
- `durationMs`
- `retryCount`
- `validationRejectReason`
- `settle/refund/outbox status`

禁止记录：API key、Authorization、baseURL secret、signed URL query、base64 body、完整用户图片 URL（除非已脱敏）。

## 11. 主要风险与应对

| 风险 | 应对 |
|---|---|
| binding id 与现有 pricing/policy/channel 语义冲突 | resolver 分离 `BindingID`、`ProviderModelID`、`PriceModelID`，补计费/策略迁移测试 |
| OpenTU 下发 schema 但 payload 仍发旧 model/旧 params | Phase A 先锁跨仓契约并加 payload 测试 |
| channelId 配错导致越权或错渠道 | admin validate + 请求时二次校验 + locked channel 测试 |
| async provider accepted 后本地失败导致漏扣/漏退 | C1/C3 账务门禁，沿用 durable outbox/CAS |
| provider 文档与实测不一致 | 每个 preset fixture-first，不带 fixture 不 enabled |
| 供应商 URL 外泄或过期 | image sanitizer/private asset，不直接回 provider URL |
| 管理 raw JSON 配错 | 专用 validator API + diagnostics + dry-run + cleaned JSON |

## 12. 当前不应立即做的事

- 不要直接把 Duomi/Grsai 的路径写进 OpenTU。
- 不要让管理员通过通用 option 页面粘贴未经校验的 binding JSON 后直接生产生效。
- 不要把 `new-api-creative::<id>` 当后端 model 发送。
- 不要把 `replyType`、`webHook`、`callback`、`oversea` 这类影响路由/外发的字段作为普通用户参数首版暴露。
- 不要在没有 fixture/mock/billing gate 的情况下启用真实异步 provider。

## 13. 开放问题（实施前需关闭）

1. 首个 canary preset 选 Grsai OpenAI-compatible 还是纯 mock？推荐先纯 mock，再 Grsai OpenAI-compatible。
2. `PriceModelID` 是固定 provider model 计费，还是允许 binding 级自定义倍率？推荐首版 provider model 计费，binding 级仅 diagnostics。
3. image private asset 是落 DB/对象存储，还是先做短期 proxy？推荐先最小 proxy + sanitizer，云同步另行开关。
4. Duomi auth 是否 Bearer？Duomi nano 结果路径真实 shape？Grsai nano provider model id 最终列表？这些必须用 fixture 或人工文档确认后再 enabled。
