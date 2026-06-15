# Creative Adapter Capability Registry 方案草案

日期：2026-06-15
范围：`new-api` 内嵌 OpenTU Creative 的渠道适配、模型能力元数据、参数 schema 下发、请求转换与任务结果统一。

## 0. 背景与问题

当前 `/creative/api/bootstrap` 已能把用户可用模型池下发给 OpenTU，但 OpenTU 的可选参数主要来自前端静态 `model-config.ts`。这导致：

- new-api channel 中新增运行时模型（如 `gemini-imagen`）后，OpenTU 能显示模型，但无法知道应展示哪些参数。
- 同名模型在不同渠道的 API 形态不一致，不能按 model id 直接绑定参数和请求格式。
- Duomi / Grsai 这类渠道同时存在 OpenAI-compatible 和供应商自定义 API，提交、轮询、返回字段均不同。

结论：必须让 new-api 成为 Creative 渠道适配与参数能力的权威来源，OpenTU 只负责动态渲染参数 schema 并提交安全参数值。

## 1. 目标

1. new-api 支持 Creative 专用 adapter preset，把 OpenTU 统一请求转换为供应商真实请求。
2. new-api 下发每个 Creative 模型的 `parameterSchema`，OpenTU 优先使用后端 schema 渲染参数。
3. 支持同名模型多渠道变体，避免参数 schema 与实际路由渠道不匹配。
4. 后端对前端提交的 `params` 做白名单校验、类型校验、枚举校验，并禁止危险字段透传。
5. 异步提交/轮询/结果提取由 new-api 统一处理，OpenTU 不直接理解供应商任务状态。
6. 第一阶段优先内置安全 preset，不做任意自定义 DSL。

## 2. 非目标

- 不让 OpenTU 保存或使用供应商 API key/baseURL。
- 不在 OpenTU 内硬编码 Duomi / Grsai / MJ / Suno 适配逻辑。
- 第一阶段不允许管理员配置任意 URL、任意 JSONPath、任意 header 映射。
- 第一阶段不做跨渠道同名模型自动合并；默认以模型变体区分。

## 3. 核心架构

```text
OpenTU UI
  ↓ parameterSchema 动态渲染
OpenTU request: { model, prompt, images?, params }
  ↓ /creative/relay/...
new-api Creative Adapter Resolver
  ↓ 按 user/group/model selectionKey 解析 CreativeModelBinding
new-api Creative Adapter Preset
  ↓ 参数校验 + 请求映射 + 渠道选择
new-api existing channel/relay/http client
  ↓
Duomi / Grsai / MJ / Suno / other providers
  ↑
new-api unified task/result DTO
  ↑
OpenTU polling/result hydration
```

## 4. new-api 数据模型建议

### 4.1 CreativeModelBinding

存储位置第一阶段可先放 option JSON：`creative.model_bindings`。后续稳定后可迁移 DB 表。

```json
{
  "version": 1,
  "bindings": [
    {
      "id": "grsai:gpt-image-2:generate",
      "modelId": "gpt-image-2",
      "displayName": "GPT Image 2 · Grsai Generate",
      "modality": "image",
      "enabled": true,
      "group": "default",
      "channelId": 12,
      "adapterPreset": "grsai_generate",
      "parameterTemplate": "grsai_gpt_image_2",
      "recommendedScore": 80,
      "sortOrder": 10,
      "aliases": ["gpt-image-2-grsai"]
    }
  ]
}
```

字段规则：

- `id`：全局唯一 selectionKey，不等同于供应商 model id。
- `modelId`：真实供应商模型名，提交上游时使用。
- `displayName`：OpenTU 展示名。
- `modality`：`text|agent|image|video|audio`。
- `channelId`：可选。指定则锁定渠道；为空则按 new-api 现有模型/分组选择渠道。
- `adapterPreset`：内置 preset key。
- `parameterTemplate`：内置参数模板 key。
- `group`：可选，空表示全局；匹配 user group 后下发。

### 4.2 下发给 OpenTU 的模型 DTO

扩展 `dto.CreativeModelCatalogItem`：

```json
{
  "id": "grsai:gpt-image-2:generate",
  "providerModelId": "gpt-image-2",
  "displayName": "GPT Image 2 · Grsai Generate",
  "type": "image",
  "modality": "image",
  "owned_by": "grsai",
  "supportedEndpointTypes": ["images.generate"],
  "parameterSchema": [
    {
      "id": "aspectRatio",
      "label": "比例 / 尺寸",
      "type": "enum",
      "defaultValue": "1024x1024",
      "options": [
        {"value": "1024x1024", "label": "1024×1024"},
        {"value": "1:1", "label": "1:1"},
        {"value": "16:9", "label": "16:9"}
      ]
    }
  ],
  "adapterPreset": "grsai_generate"
}
```

安全约束：`adapterPreset` 可以下发用于诊断展示，但 OpenTU 提交时不得信任该字段；后端必须从服务端 binding 重新解析。

## 5. 参数 schema 类型

第一阶段支持：

```go
type CreativeParameterSchemaItem struct {
    ID           string                  `json:"id"`
    Label        string                  `json:"label"`
    ShortLabel   string                  `json:"shortLabel,omitempty"`
    Description  string                  `json:"description,omitempty"`
    Type         string                  `json:"type"` // enum|string|number|boolean
    DefaultValue any                     `json:"defaultValue,omitempty"`
    Options      []CreativeParamOption   `json:"options,omitempty"`
    Min          *float64                `json:"min,omitempty"`
    Max          *float64                `json:"max,omitempty"`
    Step         *float64                `json:"step,omitempty"`
    Required     bool                    `json:"required,omitempty"`
}
```

第一阶段参数值统一提交为 JSON object；后端根据 schema 转换类型。

危险字段名 denylist 必须递归匹配大小写、下划线、驼峰归一化：

```text
apiKey, apikey, api_key, authorization, bearer, token,
baseUrl, base_url, url, endpoint, host,
channelId, channel_id, userId, user_id, owner, ownerId, owner_id,
notifyHook, notify_hook, callback, callbackUrl, webhook,
mjApiSecret, mj_api_secret
```

## 6. 内置参数模板第一批

### 6.1 `duomi_gpt_image_2`

适配 Duomi `/v1/images/generations?async=true`。

参数：

- `size` enum：`auto`, `1:1`, `16:9`, `9:16`, `3:2`, `2:3`, `4:3`, `3:4`, `5:4`, `4:5`, `21:9`
- 可选后续：`response_format=url` 固定，不暴露。

### 6.2 `duomi_nano_banana`

适配 Duomi `/api/gemini/nano-banana` 和 `/api/gemini/nano-banana-edit`。

参数：

- `aspect_ratio` enum：`auto`, `1:1`, `16:9`, `9:16`, `3:2`, `2:3`, `4:3`, `3:4`, `5:4`, `4:5`, `21:9`
- `image_size` enum：`1K`, `2K`, `4K`
- `oversea` boolean：默认 `true`，第一阶段可固定为 true 不暴露。

### 6.3 `grsai_gpt_image_2`

适配 Grsai `/v1/api/generate`。

参数：

- `aspectRatio` enum：`1024x1024`, `1:1`, `16:9`, `9:16`, `4:3`, `3:4`, `3:2`, `2:3`, `5:4`, `4:5`, `21:9`, `9:21`, `1:2`, `2:1`
- `replyType` enum：`json`, `async`；默认 `json`。

### 6.4 `grsai_nano_banana`

适配 Grsai `/v1/api/generate`。

参数：

- `aspectRatio` enum：`1:1`, `16:9`, `9:16`, `4:3`, `3:4`, `3:2`, `2:3`, `5:4`, `4:5`, `21:9`
- `imageSize` enum：`1K`, `2K`, `4K`
- `replyType` enum：`json`, `async`；默认 `json`。

### 6.5 `grsai_openai_images`

适配 Grsai `/v1/images/generations`。

参数：

- `size` enum：`1024x1024`, `1:1`, `16:9`, `9:16` 等按供应商确认范围。
- `response_format` 固定 `url`，不暴露给前端。

## 7. Creative Adapter Preset 第一批

### 7.1 `duomi_gpt_image_async`

提交：

```http
POST /v1/images/generations?async=true
Authorization: <channel key raw or provider-specific auth builder>
Content-Type: application/json
```

Body map：

```json
{
  "model": "$binding.modelId",
  "prompt": "$request.prompt",
  "size": "$params.size",
  "image": "$request.images"
}
```

提交响应：`id`。

轮询：

```http
GET /v1/tasks/{taskId}
```

状态：

- success：`state == succeeded`
- running：`queued|running|processing|submitted`
- failed：`failed|violation|canceled`

结果：`data.images[].url`。

### 7.2 `duomi_nano_banana`

提交路径按是否有参考图选择：

- 无参考图：`POST /api/gemini/nano-banana`
- 有参考图：`POST /api/gemini/nano-banana-edit`

Body map：

```json
{
  "model": "$binding.modelId",
  "prompt": "$request.prompt",
  "aspect_ratio": "$params.aspect_ratio",
  "image_size": "$params.image_size",
  "oversea": "$params.oversea",
  "image_urls": "$request.images"
}
```

无参考图时不得发送 `image_urls`。

提交响应：`data.task_id`。

轮询：

```http
GET /api/gemini/nano-banana/{taskId}
```

状态：

- success：`data.state == succeeded` 或 `data.status == "3"`
- failed：`data.state == failed|violation` 或 `code != 200`
- running：其他非终态。

结果：`data.data.images[].url`。

### 7.3 `grsai_generate`

提交：

```http
POST /v1/api/generate
Authorization: Bearer <key>
Content-Type: application/json
```

Body map：

```json
{
  "model": "$binding.modelId",
  "prompt": "$request.prompt",
  "images": "$request.images",
  "aspectRatio": "$params.aspectRatio",
  "imageSize": "$params.imageSize",
  "replyType": "$params.replyType"
}
```

`imageSize` 仅在 schema 存在且有值时发送。

提交响应：

- 若 `status == succeeded` 且 `results[].url` 存在，直接返回成功。
- 若 `status == running`，持久化任务并返回 task id。
- 若无 `status` 但有 `id`，按 running 处理。

轮询：

```http
GET /v1/api/result?id={taskId}
```

结果：`results[].url`。

### 7.4 `grsai_openai_images`

提交：

```http
POST /v1/images/generations
Authorization: Bearer <key>
Content-Type: application/json
```

Body map：

```json
{
  "model": "$binding.modelId",
  "prompt": "$request.prompt",
  "image": "$request.images",
  "size": "$params.size",
  "response_format": "url"
}
```

结果：`data[].url`。同步返回，不走任务表，除非供应商返回异步 id。

## 8. new-api 代码改造边界

建议新增/修改：

- `dto/creative.go`
  - 扩展 `CreativeModelCatalogItem`，新增 `ProviderModelId`, `DisplayName`, `SelectionKey`, `ParameterSchema`。
- `service/creative_model_capability.go`
  - binding/template/preset 类型定义、归一化、校验。
- `service/creative_model_capability_builtin.go`
  - 第一批内置 templates 与 presets。
- `service/creative_model_capability_test.go`
  - schema 校验、危险字段 denylist、Duomi/Grsai template 测试。
- `controller/creative.go`
  - `creativeModelsForUser` 合并 binding 后下发模型变体。
  - relay submit 入口从 `model`/`selectionKey` 解析 binding。
- `middleware/creative.go`
  - `CreativeRelaySessionBroker` 选择渠道时支持 binding 锁定 channel。
- `relay/channel/task/*` 或新增 `relay/channel/creativeadapter/*`
  - 放内置 preset submit/poll/parse 逻辑，避免污染通用 relay。
- `web/default` 管理后台
  - 后续阶段加 Creative 模型能力配置 UI；第一阶段可只用 option JSON + 内置默认。

## 9. OpenTU 代码改造边界

建议修改：

- `packages/drawnix/src/constants/model-config.ts`
  - `ModelConfig` 增加 `parameterSchema?: ParamConfig[]` 或兼容字段。
  - `getCompatibleParams(modelId)` 优先返回运行时模型的后端 schema。
- `packages/drawnix/src/utils/runtime-model-discovery.ts`
  - normalize Creative model 时保留 `parameterSchema`, `selectionKey`, `providerModelId`。
- `packages/drawnix/src/components/ai-input-bar/AIInputBar.tsx`
  - 无需理解供应商，继续消费 `getCompatibleParams`。
- `packages/drawnix/src/services/media-api/image-api.ts` / workflow converter
  - 确认提交 payload 使用 selectionKey 作为 `model`，或新增 `modelRef` 字段；推荐 `model` 传 selectionKey，后端根据 binding 转 provider model。

OpenTU 优先级：

```text
runtime parameterSchema > static model-config params > no params
```

## 10. 任务持久化与结果 DTO

new-api 内部统一：

```json
{
  "taskId": "public id",
  "providerTaskId": "upstream id",
  "bindingId": "grsai:gpt-image-2:generate",
  "channelId": 12,
  "platform": "creative_adapter",
  "adapterPreset": "grsai_generate",
  "status": "running|succeeded|failed",
  "progress": 0,
  "assets": {
    "images": [{"url": "..."}],
    "videos": [],
    "audios": []
  },
  "error": ""
}
```

必须保持：

- 用户只能 fetch 自己任务。
- binding/channel/platform 必须与任务创建时一致，fetch 不可被前端覆盖。
- 结果 URL 进入现有 sanitizer / private URL 处理链路。

## 11. 管理后台配置体验

第一阶段最小：管理员粘贴 JSON option。

第二阶段 UI：

```text
Creative 模型能力
- 新建模型变体
  - 显示名
  - 用户分组
  - new-api channel / 自动渠道
  - provider model id
  - modality
  - adapter preset 下拉
  - parameter template 下拉
  - 启用 / 推荐 / 排序
- 预览 OpenTU 下发 JSON
- 测试提交（dry-run，只展示映射后 body，不请求上游）
```

## 12. 安全原则

1. 前端提交的 `model` 只能是 binding id / selectionKey；服务端重新解析，不信任前端 adapter/preset/channel。
2. 参数只允许 schema 白名单字段。
3. 参数值必须类型匹配，enum 必须命中 options。
4. bodyMap 只能从固定 request fields / params 取值，不能读 arbitrary JSONPath。
5. 第一阶段不允许配置任意 path；path 来自内置 preset。
6. notifyHook/callback/webhook/baseUrl/channelId/userId/owner 等字段递归 denylist。
7. 上游错误返回给 OpenTU 前必须脱敏。
8. 异步任务持久化与扣费必须沿用已修复的 CAS/outbox/退款策略。

## 13. 分阶段实施

### Phase A：schema 下发与 OpenTU 渲染

- new-api DTO 支持 `parameterSchema`。
- OpenTU 支持 runtime `parameterSchema`。
- 暂时不接真实新 preset，只给 `gemini-imagen` 一套安全 fallback schema 验证 UI。

验收：图片模型参数不再为空，切换模型参数随 schema 变化。

### Phase B：内置 preset + dry-run

- 实现 `duomi_gpt_image_async`, `duomi_nano_banana`, `grsai_generate`, `grsai_openai_images` 的 submit/poll parser 单元测试。
- 增加 dry-run 映射函数，不请求上游。

验收：给定 OpenTU 请求与 params，可生成预期 Duomi/Grsai request body；危险参数被拒绝。

### Phase C：真实 relay 集成

- relay 入口识别 binding selectionKey。
- 绑定 channel / 使用现有 channel selection。
- 接入任务持久化、幂等、扣费、退款。

验收：mock upstream 下 submit/fetch 全链路通过。

### Phase D：管理后台 UI

- Creative 模型能力配置页。
- policy 页面联动：默认/推荐模型选择展示变体 displayName。

验收：管理员无需改代码即可给已有 preset 增删模型变体。

## 14. 当前 Duomi/Grsai 建议默认变体

- `duomi:gpt-image-2:async` → provider model `gpt-image-2`, preset `duomi_gpt_image_async`, template `duomi_gpt_image_2`
- `duomi:gemini-3-pro-image-preview:nano` → preset `duomi_nano_banana`, template `duomi_nano_banana`
- `duomi:gemini-3.1-flash-image-preview:nano-edit` → preset `duomi_nano_banana`, template `duomi_nano_banana`
- `grsai:gpt-image-2:generate` → preset `grsai_generate`, template `grsai_gpt_image_2`
- `grsai:gpt-image-2:openai-images` → preset `grsai_openai_images`, template `grsai_openai_images`
- `grsai:nano-banana-2:generate` → preset `grsai_generate`, template `grsai_nano_banana`

## 15. 待审查问题

1. 是否应优先使用 binding id 作为 OpenTU `model`，还是保留 provider model id 另传 `selectionKey`？倾向前者，避免同名模型冲突。
2. channelId 锁定是否与 new-api 现有分组/渠道选择冲突？是否需要仅允许管理员绑定同 group 可用 channel？
3. Creative adapter 任务是否复用现有 task platform，还是新增 `creative_adapter` platform？倾向新增，避免 MJ/Suno 跨平台混淆。
4. 参数 schema 是否允许 string/number 自由输入？第一阶段建议 enum/boolean 为主，number 仅明确 min/max。
5. Grsai `replyType=json` 可能同步也可能返回 running，后端需同时支持。
