# Final Goal-Attainment Evidence Pack — 2026-06-18

Scope: current-code evidence for Creative Adapter Capability Registry final audit. This pack is generated from current files and current local verification commands; it intentionally avoids old audit reports and codex-flow journals.

## Goal under audit

The current task goal is to implement a new-api backed Creative Adapter Capability Registry so embedded OpenTU can render runtime model parameters and submit provider-specific Creative image requests without owning provider credentials/routing/billing/task semantics. Phase C1 is mock/fixture-only; real provider calls remain out of scope.

## Current repository state caveats

- new2fly has `.codex/config.toml` local drift and this task check/evidence update.
- new-api has code changes plus generated Creative dist churn in both `web/creative/dist` and `router/web/creative/dist`.
- OpenTU has code changes from Creative model/runtime/userParams/sync work.
- Generated dist copies were checked for equality: `web/creative/dist` and `router/web/creative/dist` both have 175 files and identical common-file content.

## Verification commands already run in this session

new-api:

```bash
cd /mnt/f/CODE/Project/new-api
go test -count=1 ./controller ./service ./middleware ./model ./dto
# PASS

go test -count=1 ./...
# PASS

go build ./...
# PASS

git diff --check
# PASS
```

OpenTU:

```bash
cd /mnt/f/CODE/Project/opentu
pnpm vitest run packages/drawnix/src/mcp/tools/__tests__/image-generation.test.ts packages/drawnix/src/utils/__tests__/ai-input-parser.test.ts packages/drawnix/src/components/ai-input-bar/__tests__/workflow-converter.test.ts packages/drawnix/src/services/__tests__/image-generation-service.test.ts packages/drawnix/src/services/__tests__/media-executor.test.ts packages/drawnix/src/services/__tests__/generation-api-service.creative-embedded.test.ts packages/drawnix/src/services/creative-session-broker.test.ts packages/drawnix/src/constants/__tests__/model-config.test.ts
# PASS: 8 files, 162 tests

pnpm typecheck
# PASS: nx typecheck for 5 projects

pnpm vitest run packages/drawnix/src/services/__tests__/image-generation-service.test.ts --testTimeout=30000
# PASS: 2 tests

pnpm vitest run packages/drawnix/src/services/__tests__/task-queue-service-image-retry.test.ts --testTimeout=45000
# PASS: 9 tests

git diff --check
# PASS
```

Release/artifact gate:

```bash
cd /mnt/f/code/project/new2fly
python3 scripts/creative_release_gate.py check --source-diff-check
# PASS: embedded artifact contract, dist matching, no sourcemaps, diff checks
```

## Backend evidence — new-api

### Managed sync image route is blocked

File: `/mnt/f/CODE/Project/new-api/controller/creative_image_tasks.go`

```go
func CreativeRejectManagedImageBindingSyncRoute() gin.HandlerFunc {
    return func(c *gin.Context) {
        modelName, err := creativeImageRequestModel(c)
        ...
        binding, ok, err := service.GetCreativeModelBindingByID(modelName)
        ...
        if ok && binding.Modality == "image" {
            creativeOpenAIError(c, http.StatusBadRequest, "creative managed image bindings must use /creative/relay/v1/images/tasks")
            c.Abort()
            return
        }
        c.Next()
    }
}
```

### Image task route is session-only, mock/local, stores explicit metadata and priceModelId

File: `/mnt/f/CODE/Project/new-api/controller/creative_image_tasks.go`

```go
func CreativeRelayImageTaskSubmit(c *gin.Context) {
    if c.GetBool("use_access_token") { ... http.StatusForbidden ... }
    ... DecodeJson ... prompt required ... images rejected ...
    resolved, err := service.ResolveCreativeImageModelBindingForGroup(request.Model, c.GetString("group"), request.UserParams)
    ...
    creativeMarkTaskProviderAccepted(c)
    metadata := creativeImageTaskMetadata{
        Version: 1, CreativeManaged: true,
        BindingId: resolved.BindingId,
        ProviderModelId: resolved.ProviderModelId,
        PriceModelId: resolved.PriceModelId,
        AdapterPreset: resolved.AdapterPreset,
        ParameterTemplate: resolved.ParameterTemplate,
        ChannelId: resolved.ChannelId,
        UserParams: resolved.UserParams,
    }
    task := &model.Task{
        Platform: constant.TaskPlatformCreativeImage,
        UserId: c.GetInt("id"), Group: c.GetString("group"), ChannelId: resolved.ChannelId,
        Quota: 0, Status: model.TaskStatusSuccess,
        Properties: model.Properties{OriginModelName: resolved.BindingId, UpstreamModelName: resolved.ProviderModelId},
        PrivateData: model.TaskPrivateData{
            UpstreamTaskID: "mock_" + publicTaskID,
            ResultURL: "mock://creative-image/" + publicTaskID + "?token=secret",
            BillingContext: &model.TaskBillingContext{OriginModelName: resolved.PriceModelId, PerCallBilling: true, PreConsumedQuota: 0},
        },
    }
    task.SetData(metadata)
    ... Insert ... CompleteCreativeVideoIdempotencyScoped ...
    c.JSON(http.StatusAccepted, creativeImageTaskDTOFromTask(task))
}
```

### Public DTO/content omits private URL/channel and is owner+platform scoped

File: `/mnt/f/CODE/Project/new-api/controller/creative_image_tasks.go`

```go
func CreativeRelayImageTaskFetch(c *gin.Context) {
    if c.GetBool("use_access_token") { ... http.StatusForbidden ... }
    task, ok, err := creativeGetOwnedImageTask(c, c.Param("task_id"))
    ...
    c.JSON(http.StatusOK, creativeImageTaskDTOFromTask(task))
}

func CreativeRelayImageTaskContent(c *gin.Context) {
    if c.GetBool("use_access_token") { ... http.StatusForbidden ... }
    _, ok, err := creativeGetOwnedImageTask(c, c.Param("task_id"))
    ...
    c.Header("Cache-Control", "private, no-store")
    c.Header("Pragma", "no-cache")
    c.Header("X-Content-Type-Options", "nosniff")
    c.Data(http.StatusOK, "image/png", creativeMockPNG())
}

func creativeGetOwnedImageTask(c *gin.Context, taskID string) (*model.Task, bool, error) {
    task, ok, err := model.GetByTaskId(c.GetInt("id"), strings.TrimSpace(taskID))
    ...
    if task.Platform != constant.TaskPlatformCreativeImage { return nil, false, nil }
    var metadata creativeImageTaskMetadata
    if err := task.GetData(&metadata); err != nil || !metadata.CreativeManaged { return nil, false, nil }
    return task, true, nil
}

func creativeImageTaskDTOFromTask(task *model.Task) creativeImageTaskDTO {
    ...
    if task.Status == model.TaskStatusSuccess {
        result["url"] = creativeImageTaskContentURL(task.TaskID)
        result["mimeType"] = "image/png"
    }
    return creativeImageTaskDTO{TaskID: task.TaskID, Status: task.Status.ToVideoStatus(), Model: metadata.BindingId, Result: result, Metadata: creativeImageTaskPublicMetadataFromMetadata(metadata)}
}
```

### Resolver validates enabled/group/mock-only/schema and returns typed userParams

File: `/mnt/f/CODE/Project/new-api/service/creative_model_capability.go`

```go
func ResolveCreativeImageModelBindingForGroup(bindingID string, userGroup string, userParams map[string]any) (CreativeResolvedModelBinding, error) {
    if !creativeAdapterPreviewEnabled() { return ..., errors.New("creative adapter is disabled") }
    ... load config ...
    if !binding.Enabled { ... }
    if binding.Modality != "image" { ... }
    if binding.AdapterPreset != "mock_image_task" || binding.ParameterTemplate != "mock_gpt_image" { ... }
    if !creativeBindingCanaryGroupAllowed(binding, userGroup) { ... }
    normalizedParams, err := ValidateCreativeUserParamsForSchema(binding.ParameterSchema, userParams)
    ...
    return CreativeResolvedModelBinding{BindingId: binding.Id, ProviderModelId: binding.ProviderModelId, PriceModelId: binding.PriceModelId, AdapterPreset: binding.AdapterPreset, ParameterTemplate: binding.ParameterTemplate, ChannelId: channelID, UserParams: normalizedParams}, nil
}
```

### Forbidden normalizer and schema/userParams validation

File: `/mnt/f/CODE/Project/new-api/service/creative_model_capability.go`

```go
func NormalizeCreativeForbiddenKey(key string) string { ... only letters/digits lowercased ... }
func CreativeForbiddenKey(key string) bool { ... checks fragments: apikey, authorization, token, secret, baseurl, url, endpoint, host, header, channel, provider, model, sourceprofileid, idempotency, group, user, owner, notifyhook, callback, webhook, storagebackend ... }

func ValidateCreativeParameterSchema(schema []dto.CreativeParameterSchemaItem) error { ... rejects invalid id, forbidden id, duplicate, sensitive labels/default/options, unsupported types, enum/default mismatch ... }
func ValidateCreativeUserParamsForSchema(schema []dto.CreativeParameterSchemaItem, userParams map[string]any) (map[string]any, error) { ... rejects hidden, forbidden, unsupported fields; validates enum/string/boolean/number/integer and required fields ... }
```

### Admin binding endpoints require dashboard session and no-store; writes require dry-run noProviderCall

File: `/mnt/f/CODE/Project/new-api/controller/creative_model_bindings.go`

```go
func creativeModelBindingsRequireDashboardSession(c *gin.Context) bool {
    if c.GetBool("use_access_token") { c.JSON(http.StatusForbidden, ...); return false }
    return true
}

func UpdateCreativeModelBindings(c *gin.Context) {
    creativeModelBindingsNoStore(c)
    if !creativeModelBindingsRequireDashboardSession(c) { return }
    config, ok := creativeModelBindingsConfigFromRequest(c)
    dryRun, err := service.BuildCreativeModelBindingsDryRun(config)
    if !dryRun.NoProviderCall { ... reject ... }
    config, _, err = service.UpdateStoredCreativeModelBindingsConfig(config)
    common.SysLog("creative model bindings updated by user_id=... bindings=...")
    ...
}
```

File: `/mnt/f/CODE/Project/new-api/router/api-router.go` wires PUT/validate/dry-run through `middleware.CreativeRequireNonce()`.

### Dry-run is offline/fixture/mock

File: `/mnt/f/CODE/Project/new-api/service/creative_model_capability.go`

```go
func BuildCreativeModelBindingsDryRun(config CreativeModelBindingsConfig) (CreativeModelBindingsDryRunResult, error) {
    result := CreativeModelBindingsDryRunResult{NoProviderCall: true, ...}
    for _, binding := range config.Bindings { preview := creativeModelBindingDryRunRequestPreview(binding); ... RedactCreativeDryRunValue(preview) ... }
    return result, nil
}

func creativeModelBindingDryRunRequestPreview(binding CreativeModelBindingConfig) map[string]any {
    if binding.AdapterPreset == "grsai_gpt_image_dryrun" && binding.ParameterTemplate == "grsai_gpt_image" { return map[string]any{"transport":"fixture", "offline":true, ...} }
    return map[string]any{"transport":"mock", "operation":"image_task_preview", ...}
}
```

## Frontend/runtime evidence — OpenTU

### Creative model config recognizes managed bindings and provider/price/schema

File: `/mnt/f/CODE/Project/opentu/packages/drawnix/src/constants/model-config.ts`

```ts
export function isCreativeManagedModelConfig(modelConfig?: ModelConfig | null): boolean { return modelConfig?.creativeManaged === true || ... }
export function isCreativeManagedModel(modelId?: string | null, modelRef?: string | null): boolean { ... }
export function hasRuntimeParameterSchema(modelIdOrConfig: string | ModelConfig): boolean { return !!modelConfig?.parameterSchema?.some((param) => param.runtimeSchema); }
export function sanitizeCreativeUserParamsForModel(modelIdOrConfig, rawUserParams) { ... allowlist runtime schema params; throws on disallowed/invalid ... }
```

Tests cover dangerous param filtering, typed casts, empty managed schema behavior, providerModelId static fallback, and no priceModelId param fallback in `packages/drawnix/src/constants/__tests__/model-config.test.ts`.

### Session broker preserves providerModelId/priceModelId/parameterSchema and marks creativeManaged

File: `/mnt/f/CODE/Project/opentu/packages/drawnix/src/services/creative-session-broker.ts`

```ts
const providerModelId = normalizeServerString(item.providerModelId) || modelId;
const priceModelId = normalizeServerString(item.priceModelId) || providerModelId;
const parameterSchema = normalizeCreativeParameterSchema(...);
return { modelId, modelRef, creativeManaged: true, providerModelId, priceModelId, parameterSchema, ... };
```

### Workflow/submission carries creativeManaged and empty userParams

File: `/mnt/f/CODE/Project/opentu/packages/drawnix/src/services/workflow-submission-service.ts`

```ts
if (parsedInput.creativeManaged || parsedInput.userParams) {
    args.userParams = parsedInput.userParams || {};
    args.creativeManaged = true;
}
...
userParams: parsedInput.creativeManaged || parsedInput.userParams ? parsedInput.userParams || {} : undefined,
creativeManaged: parsedInput.creativeManaged ? true : undefined,
```

File: `/mnt/f/CODE/Project/opentu/packages/drawnix/src/services/workflow-engine/engine.ts` passes `step.args.userParams` and `step.args.creativeManaged` into image generation.

### Image generation/task queue/retry preserves managed empty userParams and strips legacy params

Files: `/mnt/f/CODE/Project/opentu/packages/drawnix/src/services/media-generation/image-generation-service.ts`, `/mnt/f/CODE/Project/opentu/packages/drawnix/src/services/task-queue-service.ts`

```ts
const schemaBacked = isCreativeManagedImageTask(effectiveOptions) || isCreativeManagedModel(effectiveOptions.model || null, effectiveOptions.modelRef || null) || hasCreativeUserParams(effectiveOptions.userParams) || hasRuntimeParameterSchema(...);
const userParams = effectiveOptions.userParams ?? (schemaBacked ? {} : undefined);
...
creativeManaged: schemaBacked ? true : undefined
```

Task queue retry similarly detects `isCreativeManagedModel(...)` and uses `rawUserParams ?? (schemaBacked ? {} : undefined)`.

### Managed image execution uses new-api task route and sanitizes userParams before fetch body

File: `/mnt/f/CODE/Project/opentu/packages/drawnix/src/services/media-executor/fallback-executor.ts`

```ts
const schemaBacked = isCreativeManagedImageTask(params) || isCreativeManagedModel(modelName, effectiveModelRef) || hasCreativeUserParams(params.userParams) || hasRuntimeParameterSchema(modelName);
if (schemaBacked) {
  return executeCreativeManagedImageTask(taskId, { prompt, model: modelName, modelRef: effectiveModelRef, referenceImages, userParams: params.userParams ?? {}, ... }, options, startTime);
}
```

File: `/mnt/f/CODE/Project/opentu/packages/drawnix/src/services/media-executor/fallback-adapter-routes.ts`

```ts
const userParams = sanitizeCreativeUserParamsForModel(params.model, params.userParams);
const submitResponse = await fetch(creativeImageTaskPath(), { method: 'POST', headers: { 'Content-Type':'application/json', 'Idempotency-Key': idempotencyKey }, body: JSON.stringify({ model: params.model, prompt: params.prompt, userParams }) });
```

Reference images for managed image tasks are currently rejected before submit in tests.

### Legacy adapter path fails fast for schema-backed userParams

File: `/mnt/f/CODE/Project/opentu/packages/drawnix/src/services/generation-api-service.ts`

```ts
const rawCreativeUserParams = (params as any).userParams;
if (isCreativeManagedImageTask(params as any) || rawCreativeUserParams !== undefined || hasCreativeUserParams(rawCreativeUserParams)) {
    throw new Error('schema-backed Creative image requests require the managed image task route');
}
```

File: `/mnt/f/CODE/Project/opentu/packages/drawnix/src/services/media-executor/fallback-adapter-routes.ts`

```ts
const schemaBacked = params.creativeManaged === true || hasCreativeUserParams(params.userParams);
if (schemaBacked && !adapter.supportsCreativeUserParams) throw new Error('schema-backed Creative image requests require a managed userParams adapter');
```

## Cross-repo release/config evidence

- Admin credentials/API keys are configured in new-api Channels, not OpenTU.
- Creative model bindings are configured in new-api admin under Creative Model Bindings; bindings map Creative-visible `bindingId` to `providerModelId`, `priceModelId`, optional `channelId`, adapter preset, and parameter schema.
- Current live-provider adapter phase is intentionally not implemented. Duomi remains blocked; GrsAI is fixture/dry-run only; C1 mock image task is the only task route allowed for managed image generation.
- `python3 scripts/creative_release_gate.py check --source-diff-check` confirms OpenTU build artifacts match both embedded new-api dist trees and no sourcemaps are present.

## Known limitations / things to judge

- Dynamic workflow reviewers should decide whether the absence of real Duomi/GrsAI live adapters is acceptable under Phase A/B/C1 out-of-scope, or a goal gap for the user's broader expectation.
- Current state is not clean/releasable until new-api/OpenTU/new2fly changes are committed coherently.
- Previous broad codex-flow attempt timed out because reviewers read large historical `check.md`; this evidence pack is meant to support a fresh focused final audit from current code evidence only.
