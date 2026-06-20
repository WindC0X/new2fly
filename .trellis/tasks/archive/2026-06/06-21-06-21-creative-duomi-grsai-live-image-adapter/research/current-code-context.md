# Current code context for Creative live image adapters

Date: 2026-06-21
Repos inspected: `/mnt/f/CODE/Project/new-api`; relevant OpenTU embedded behavior is covered by existing specs and previous Phase 1 deployment.

## Existing backend state

- `service/creative_model_capability.go`
  - Defines `creative.model_bindings` config, parser, validator, manifests, parameter templates, channel summary helper, catalog projection, and mock-only resolver.
  - Existing manifests:
    - `mock_image_task`: available, mock, can be saved/enabled, no provider call.
    - `grsai_gpt_image_dryrun`: available only for offline dry-run, cannot be enabled for user catalog, no provider call.
    - `duomi_image_live`: currently `future`, `CanBeEnabled=false`, `SupportsProviderCall=false`.
    - `grsai_image_live`: currently `future`, `CanBeEnabled=false`, `SupportsProviderCall=false`.
  - Existing templates:
    - `mock_gpt_image`
    - `grsai_gpt_image`
    - `duomi_gpt_image`
  - Current validator intentionally blocks live/future provider-call presets from being saved/enabled.
  - Current public stored catalog only exposes enabled `mock_image_task` + `mock_gpt_image` bindings when adapter/mock flags and group gates pass.
  - `ResolveCreativeImageModelBindingForGroup` is mock-only and rejects anything not `mock_image_task` + `mock_gpt_image`.
  - `ValidateCreativeUserParamsForSchema` already validates visible schema fields, hidden fields, forbidden keys, scalar type, enum, and numeric limits.
  - `ListCreativeChannelSummaries` returns only sanitized channel summary fields (`id`, `name`, `group`, `status`, `models`) and intentionally omits keys/base URLs/settings.

- `controller/creative_image_tasks.go`
  - Routes are under `/creative/relay/v1/images/tasks`.
  - Current submit requires browser session, JSON body, prompt, no images, model binding resolution, and idempotency.
  - Current execution is local mock only: inserts `TaskPlatformCreativeImage`, status `SUCCESS`, quota `0`, internal `PrivateData.ResultURL=mock://...`, and returns a private DTO with content URL `/creative/relay/v1/images/tasks/:task_id/content`.
  - Fetch/content require owner + `Platform == creative_image` + `creativeManaged == true` metadata.
  - Public DTO intentionally omits `channel_id`, `quota`, `private_data`, raw result URL, and other generic task internals.
  - Sync `/creative/relay/v1/images/generations` rejects stored managed image binding IDs before broker/distribute/provider relay.

- `model/task.go` and `service/task_billing.go`
  - `Task.PrivateData` supports `Key`, `UpstreamTaskID`, `IdempotencyKey`, `ResultURL`, and `BillingContext`.
  - `TaskBillingOutbox` supports `submit_settle`, `terminal_settle`, `terminal_refund` with unique `(task_row_id,user_id,task_id,operation)`.
  - `UpdateWithStatusAndBillingOutbox` performs status CAS and enqueues billing outbox in the same transaction.
  - `ProcessTaskBillingOutbox` atomically claims outbox rows and applies funding/token/log effects once.
  - Existing spec requires Creative tasks with idempotency to fail closed if missing upstream id or selected key; legacy fallback must not apply.

## Existing frontend/admin state

- `web/default/src/features/system-settings/models/creative-model-bindings-section.tsx`
  - Admin UI currently presents manifests/templates from backend.
  - UI copy explicitly says Duomi/GrsAI live adapters are future/blocked, GrsAI dry-run is offline only, and save requires validate + dry-run `noProviderCall=true`.
  - UI uses `/api/creative/channel-summaries`, not full channel DTO, for safe channel picking.

- OpenTU embedded model/parameter behavior is already spec-governed:
  - Runtime `parameterSchema` from backend catalog is authoritative.
  - OpenTU submits backend catalog/binding id as `model` and typed `userParams` only.
  - Static parameter fallback is limited to managed direct catalog/provider model identity; `priceModelId` must not grant parameters.

## Gaps for this task

1. A live provider adapter abstraction does not exist for Creative image tasks.
2. `ResolveCreativeImageModelBindingForGroup` only supports mock bindings; it needs a live resolver path that validates channel lock and provider model support without leaking channel secrets.
3. `CreativeRelayImageTaskSubmit` currently bypasses channel selection, provider HTTP, selected-key affinity, billing settle, and async pending state.
4. There is no polling worker/fetch-time poll path for Creative image provider tasks.
5. Provider result URLs are not proxied/stored for live image outputs; public content route currently returns a mock PNG.
6. Current manifests/templates/UI copy intentionally block live adapters and must be updated only after transport/parser/billing tests exist.
7. The validator and dry-run semantics need a new distinction between offline dry-run and live save/enable: live adapters may be saveable/enabled only for supported presets, valid channel, valid template/schema, and explicit feature flag/canary policy.

## Existing contracts that must remain true

- OpenTU never receives provider key/base URL/channel authority.
- Browser request may only submit logical binding id + prompt + typed `userParams`; no callback/webhook/header/url/provider/channel override fields.
- Provider result URLs must be stored privately or proxied; public DTO must expose owned content URLs only.
- Idempotency guard must not be deleted after provider accepted a task.
- Submit success must not be flushed before local task insert, idempotency completion, and billing settle/outbox durability.
- Terminal status updates must use CAS; only CAS winner settles/refunds.
- Same-user wrong-platform task fetch must look like not-found.
- Admin channel picker must stay sanitized.
