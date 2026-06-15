# Creative Adapter Capability Registry v2 — codex-flow 深度审查报告

日期：2026-06-15  
方案：`.trellis/workspace/WindC0X/creative-adapter-capability-plan-v2-2026-06-15.md`  
工作流：

- `.codex-flow/generated/creative-adapter-capability-v2-audit.workflow.ts`
- `.codex-flow/generated/creative-adapter-capability-v2-contract-focused.workflow.ts`

Journal：

- `.codex-flow/journal/creative-adapter-capability-v2-audit.jsonl`
- `.codex-flow/journal/creative-adapter-capability-v2-contract-focused.jsonl`

## 1. 总裁决

v2 方案方向正确：`new-api` 做 Creative 能力/适配/任务/计费权威，OpenTU 只消费后端 schema 并提交 `bindingId + userParams`。

但 codex-flow 审查认为：**仍不能直接进入实现/生产 rollout**。方案需要先升级为 v3，把以下阻断项变成明确设计和测试门禁，尤其是 idempotency、计费入口、resolver 接入顺序、同步图片 URL 私有化、新 image task DTO、Admin/路由安全边界。

## 2. codex-flow 覆盖情况

第一轮并行 5 分支：

- ✅ `newapi-relay-task-billing`
- ✅ `opentu-frontend-params-ui`
- ✅ `provider-fixtures-duomi-grsai`
- ✅ `security-rollout-ops`
- ⚠️ `contract-and-architecture` 超时

第二轮补审：

- ✅ `contract-newapi`
- ✅ `contract-opentu`

因此合同/架构缺口已通过 focused workflow 补齐。

## 3. Critical 阻断项

### C1 provider accepted 后 idempotency guard 不能删除

证据：`controller/relay.go` 现有路径在 `taskErr != nil && !taskPersisted` 时删除 Creative idempotency；而 provider accepted + 本地 task 不可达正是最危险窗口。

要求：

- provider accepted 后，task insert / idempotency complete / submit_settle 任一失败，都不得删除 idempotency 记录。
- 必须保留 pending/recovery 状态或写 durable recovery/outbox。
- 只有 provider 未 accepted 时才可删除/释放 idempotency。

影响：否则用户重试可能创建第二个上游付费任务，造成重复供应商扣费和账务不可恢复。

## 4. High 阻断项

1. **PriceModelID 没落到现有计费入口**  
   `ModelPriceHelper*` 当前读 `relayInfo.OriginModelName`。v3 必须明确 `BindingID / ProviderModelID / PriceModelID` 三者如何进入 price helper、billing mode、TaskBillingContext。

2. **Binding resolver 接入顺序不够硬**  
   当前 Broker 先按 body `model` 做 group/modality 选择，Distribute 再按同一个 `model` 选渠道。v3 必须固定：forbidden guard 后、Broker 前解析 binding；Broker 用 binding 授权，Distribute 用 provider model/locked channel。

3. **同步 ImageHelper URL 私有化没有可执行拦截点**  
   当前 ImageHelper 让 adaptor 直接写响应。v3 必须设计 buffered writer 或结构化 ImageResponse 重写，先 sanitizer/private asset，再 flush。

4. **新 image task fetch 不能复用通用 TaskDto**  
   必须返回专用 owner-scoped DTO，禁止泄漏 `UserId/ChannelId/Quota/PrivateData/Properties/Data` 中的内部字段和 raw provider URL。

5. **selected-key affinity fail-closed 标记不足**  
   新 Creative image async task 必须要求 idempotency key，或新增 `CreativeManaged=true`；polling selected key 不得只靠是否有旧 idempotency key 判断。

6. **OpenTU 仍会丢弃 runtime `parameterSchema/providerModelId`**  
   必须扩展 `CreativeModelEndpointItem`、`ModelConfig`、runtime catalog 持久化与 normalize。

7. **OpenTU 参数系统仍是字符串/静态 modelId 体系**  
   必须支持 boolean/integer/number typed value 或提交前 cast；`getCompatibleParams` 必须 runtime schema 优先。

8. **OpenTU 提交链路仍混用 legacy `params`**  
   必须拆分 `userParams` 与内部 adapter options，避免 `onProgress/onSubmitted/idempotencyKey/modelRef` 混入可透传参数。

9. **Duomi 缺少本地事实源**  
   当前本地未找到 Duomi captured fixtures。所有 Duomi preset 必须标记 `disabled + fixture_required`，不能启用真实调用。

10. **Admin model-bindings API 缺 authz/CSRF/raw option 绕过门禁**  
    必须规定 admin-only、同源/CSRF/nonce、通用 `/api/option` 对新 key 禁写或只读、sanitized audit event。

11. **新 image task 路由未完整继承 Creative relay 边界**  
    POST 必须 session + same-origin + nonce + idempotency；GET owner-scope；API-token-only 拒绝；forbidden material 在 upstream 前拒绝。

12. **image 私有化与 asset sync 生产门禁未关闭**  
    C2 前必须确定短期 proxy / DB / S3-compatible asset sync 路线，并证明缺配置 fail-closed、不泄露 storage internals。

13. **危险字段 normalizer 只覆盖 userParams 不够**  
    必须覆盖 admin binding JSON、schema id、hidden fields、legacy params、headers/query/form/multipart/file part。

## 5. Medium 重点改进

- `images.task` endpoint type 未映射到现有 policy/modality 系统。
- channel `model_mapping` 与 binding `providerModelId` 优先级未定义。
- Task metadata 需要 versioned `CreativeTaskMetadata`，不能零散塞进 Data/Properties。
- Catalog 元数据查找当前隐式绑定 `id == pricing.ModelName`，需要分离 metadata key。
- Policy/preference 需要按当前 binding catalog 做 stale/alias 诊断。
- 现有 Creative forbidden guard 会先于 schema 白名单拒绝潜在合法字段，保存期 validator 必须复用同一规则。
- GrsAI VIP 尺寸矩阵、OpenAI-compatible image array、Nano Banana wrapper/status、batch/n 策略需要 fixture 固化。
- no-secret artifacts、dynamic redaction、kill switch 缓存/后台任务维度、真实 provider 调用授权边界需要补成发布门禁。

## 6. 推荐下一步

先不要进入代码实现。下一步应产出 v3 方案，变化点：

1. 把 `BindingID / ProviderModelID / PriceModelID` 作为跨仓协议和 relay 内部字段明确落地。
2. 明确 resolver 在 forbidden guard 后、Broker 前接入，并定义 Broker/Distribute/pricing/model_mapping 的双模型语义。
3. 把 provider accepted 后 idempotency/recovery 作为 P0 账务门禁。
4. 明确 image sync/async 的 URL 私有化拦截点和专用 DTO。
5. 先做 Phase A/B/C1：schema preview、admin validator/dry-run、mock upstream；Duomi 全部 fixture-blocked，GrsAI 也先 mock/dry-run。
6. 把本报告的 Critical/High 全部转为 v3 acceptance tests，再允许实施。
