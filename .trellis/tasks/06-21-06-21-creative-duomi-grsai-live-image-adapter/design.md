# Design — Creative Duomi / GrsAI live image adapter

## Architecture

```text
OpenTU embedded UI
  -> /creative/api/bootstrap + /creative/api/models
  -> user selects binding id + typed schema params
  -> POST /creative/relay/v1/images/tasks
      new-api auth/session/origin/nonce/idempotency/forbidden guards
      -> binding resolver
      -> channel/key selection
      -> provider adapter submit
      -> local Task insert + idempotency completion + billing durable settle
  -> GET /creative/relay/v1/images/tasks/:task_id
      -> owned task fetch
      -> optional poll/reconcile if non-terminal
      -> sanitized DTO
  -> GET /creative/relay/v1/images/tasks/:task_id/content
      -> owned result proxy/storage fetch
```

## Boundaries

### OpenTU / browser boundary

Allowed browser submit shape:

```json
{
  "model": "<creative binding id>",
  "prompt": "<user prompt>",
  "images": ["<optional safe user image refs when enabled>"],
  "userParams": { "<schema id>": "typed scalar" }
}
```

Forbidden browser authority remains forbidden at every layer: API keys, authorization headers, provider/base URL, channel/group/user/owner overrides, callbacks/webhooks/notify hooks, arbitrary URL routing, model refs, source profile refs, and idempotency-in-body.

### Channel / binding boundary

- `Channel` owns key/base URL/model list/model mapping.
- `creative.model_bindings` owns logical Creative binding metadata and `channelId` lock.
- Runtime task metadata stores public-safe binding metadata plus private task data stores selected key/upstream id/result URL/billing context.

### Provider adapter boundary

Introduce a backend service abstraction, for example:

```go
type CreativeImageProviderAdapter interface {
    PresetID() string
    Submit(ctx context.Context, req CreativeImageSubmitRequest) (CreativeImageSubmitResult, error)
    Poll(ctx context.Context, req CreativeImagePollRequest) (CreativeImagePollResult, error)
}
```

Core request/result concepts:

- `CreativeImageSubmitRequest`: channel id/base URL/selected key, binding id, provider model id, prompt, images, typed userParams, idempotency key, user/group ids, price model id.
- `CreativeImageSubmitResult`: provider task id, provider status, raw/sanitized provider payload, initial progress, optional provider result URLs if terminal immediate success.
- `CreativeImagePollRequest`: selected key, base URL, provider task id, provider model id, previous task metadata.
- `CreativeImagePollResult`: normalized status (`pending|running|succeeded|failed`), progress, fail reason, result URL candidates, sanitized provider summary.

Provider-specific files should live under `service/` or a small `service/creative_image_adapters/` package; keep controller orchestration thin.

## Provider mappings

### Duomi

- Auth: `Authorization: <selected key>`.
- Submit: `POST {baseURL}/v1/images/generations?async=true`.
- Submit body:
  - `model = binding.ProviderModelId`
  - `prompt`
  - `size = userParams.size`
  - `image = images` only after reference-image support is explicitly enabled/validated
  - `quality = userParams.quality` when schema includes it
- Submit parse: require non-empty `id`.
- Poll: `GET {baseURL}/v1/tasks/{providerTaskID}`.
- Poll parse:
  - `state` maps to internal status.
  - `data.images[].url` becomes private result URL candidates.
  - `progress` copied after bounds check.

### GrsAI

- Auth: `Authorization: Bearer <selected key>`.
- Submit: `POST {baseURL}/v1/api/generate`.
- Submit body:
  - `model = binding.ProviderModelId`
  - `prompt`
  - `images = images` only after reference-image support is explicitly enabled/validated
  - `aspectRatio = userParams.aspectRatio`
  - `imageSize = userParams.imageSize` for nano-banana schemas
  - `replyType = "async"` forced server-side
- Submit parse:
  - `status=running` with non-empty `id` means accepted.
  - `status=succeeded` may be terminal immediate success but still store as task + private result and return sanitized DTO.
  - `violation|failed` should become terminal failure/refund if provider did not return accepted running, or stored failure if a task id exists.
- Poll: `GET {baseURL}/v1/api/result?id={providerTaskID}`.
- Poll parse:
  - `status` maps to internal status.
  - `results[].url` becomes private result URL candidates.
  - `progress` copied after bounds check.

## Parameter templates

Use backend templates as source of truth. Proposed templates:

- `duomi_gpt_image`
  - `size`: enum/string constrained options for common ratios/pixels; later custom dimension support can use validated string with regex.
  - `quality`: enum `low|medium|high`; display label `质量`.
- `grsai_gpt_image`
  - `aspectRatio`: enum common ratios / documented pixel options depending model family.
- `grsai_nano_banana`
  - `aspectRatio`: enum including nano-banana extended ratios.
  - `imageSize`: enum such as `1K`, with extension points for model-specific sizes.

If the same provider has model-specific schemas, create separate templates or allow binding-level `parameterSchema` override copied from template. Do not infer schema from model name in OpenTU.

## Task lifecycle

### Submit happy path

1. Middleware validates browser session, origin, nonce, forbidden keys, and scoped idempotency.
2. Controller validates JSON prompt/model/images.
3. Resolver loads binding, validates adapter preset/template, channel id, enabled/canary group, channel status/model support, and typed userParams.
4. Service selects concrete channel key and resolves final base URL/model mapping.
5. Billing pre-consume/session is established before provider call.
6. Adapter submits provider request.
7. After provider accepted, mark provider accepted in Gin context so idempotency cleanup will not delete the guard on downstream failures.
8. Insert local `Task` with:
   - `TaskID`: local public task id.
   - `Platform`: `creative_image`.
   - `Status`: submitted/running or terminal if provider immediately returned terminal.
   - `ChannelId`: locked channel id.
   - `Properties.OriginModelName`: binding id or price model id as appropriate for billing/logs.
   - `Properties.UpstreamModelName`: provider model id.
   - `PrivateData.UpstreamTaskID`: provider task id.
   - `PrivateData.Key`: selected upstream key.
   - `PrivateData.IdempotencyKey`: idempotency key.
   - `PrivateData.ResultURL`: private first result URL only after terminal success; never public DTO.
   - `PrivateData.BillingContext`: pricing snapshot/pre-consumed quota.
9. Complete scoped idempotency.
10. Run/queue submit settle outbox.
11. Return sanitized `202 Accepted` DTO.

### Poll/reconcile

- Fetch route may opportunistically poll non-terminal tasks, or a background poller may process them; both must share the same service function.
- Poll service must:
  - require `Platform == creative_image` and `creativeManaged` metadata;
  - require non-empty `PrivateData.UpstreamTaskID` and `PrivateData.Key` for idempotent Creative tasks;
  - call provider adapter with stored selected key;
  - update task status/progress/result through CAS for terminal transitions;
  - enqueue/process terminal settle or refund via outbox exactly once.

### Content handling

Preferred v1: content route fetches the private provider result URL server-side using an SSRF-safe managed client, strips sensitive headers on redirects, and streams image bytes with `private, no-store`. If existing Creative asset-sync storage is enabled later, content route can serve stored object references instead.

Fail closed if:

- task not owned by user;
- platform/metadata mismatch;
- status not success;
- no private result URL;
- URL is unsafe/private network/redirects to unsafe target;
- content type is not image-like or body exceeds configured cap.

## Admin UI design

Current Creative Model Bindings UI can remain JSON/expert-first, but live mode needs clearer generation helpers:

- Adapter manifest cards show:
  - provider family;
  - transport mode `live`;
  - requires channel;
  - can be enabled status;
  - required validation/smoke notes.
- Channel picker stays based on `/api/creative/channel-summaries` only.
- Draft generator lets admin choose:
  - adapter preset: Duomi live / GrsAI live;
  - channel summary;
  - provider model from sanitized channel model list;
  - parameter template;
  - binding id/display name/canary groups.
- Save still goes through validate + dry-run/preview + PUT. For live adapters, dry-run must remain no-provider-call unless a separate explicit “live smoke” endpoint is added later.
- Actual provider keys are entered only in normal Channel config.

## Compatibility and migration

- Existing mock bindings and Phase 1 production behavior must continue working.
- Existing `grsai_gpt_image_dryrun` remains offline-only; do not silently turn dry-run bindings into live.
- Existing direct channel models in `/creative/api/models` remain separate from Creative adapter bindings.
- Live manifests can be introduced disabled by default and hidden from non-canary groups.

## Security and logging

- Redact provider request/response logs: no keys, signed URLs, raw provider body with URL tokens, base64 image data, cookies, CSRF/nonce, selected key, or raw headers.
- Public DTOs expose only local task id, status/progress, binding/model metadata safe fields, typed userParams, and owned content URL when success.
- Provider errors returned to users must be sanitized and bounded.
- Admin audit logs record actor, counts, adapter ids/statuses only, never raw binding JSON or provider credentials.

## Rollout / rollback

- Keep live adapters behind adapter manifest + global adapter flag + per-binding `enabled` + canary groups.
- Production rollout can be disabled by flipping binding `enabled=false`, clearing canary group, or disabling global adapter flag.
- A failed live task should refund by outbox; rollback must not require deleting historical tasks.
