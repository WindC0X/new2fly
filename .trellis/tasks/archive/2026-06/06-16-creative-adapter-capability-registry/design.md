# Creative Adapter Capability Registry v3 Design

Date: 2026-06-16

## 0. Status

This v3 design supersedes the v2 workspace draft and incorporates the codex-flow v2 audit findings. It is intentionally mock-first. Real provider calls are blocked until the explicit gates in this document pass.

## 1. Architecture Decision

`new-api` is the source of truth for Creative capability bindings, provider presets, parameter schemas, channel selection, pricing, task state, idempotency, CAS/outbox billing, and result URL privacy.

OpenTU is a renderer and request client:

```text
new-api bootstrap catalog
  -> OpenTU model list + parameter schema UI
  -> OpenTU submit { model: bindingId, prompt, images?, userParams }
  -> new-api resolver validates binding/group/channel/modality/params
  -> new-api preset maps to provider/mock request
  -> new-api task/billing/URL-private result DTO
```

## 2. Frozen Cross-Repo Contract

### 2.1 IDs

| Field | Owner | Meaning |
|---|---|---|
| `bindingId` / catalog `id` | new-api | Unique model variant and OpenTU relay `model` value |
| `providerModelId` | new-api | Upstream provider model sent by preset |
| `priceModelId` | new-api | Model name used by pricing/billing helpers |
| OpenTU `selectionKey` | OpenTU local only | UI/source key; never sent as backend model |

Rules:

- OpenTU submits `model = catalogItem.id` exactly.
- OpenTU may display `providerModelId`, but must not use it for routing.
- `bindingId`, `providerModelId`, and `priceModelId` must be tested with three distinct values.
- Existing policy/preference entries that reference old provider model ids are stale/alias inputs and must be diagnosed or migrated to binding ids.

### 2.2 Request Payload

Schema-backed Creative image requests use:

```json
{
  "model": "grsai:gpt-image-2-vip:generate",
  "prompt": "...",
  "images": ["new-api-owned-or-sanitized-reference-url"],
  "userParams": {
    "size": "1024x1024",
    "quality": "auto"
  }
}
```

`userParams` contains only backend schema fields. It never contains internal callback functions, idempotency keys, modelRef, sourceProfileId, channel, provider, URL, callback, webhook, or headers.



### 2.3 Frozen Parameter Schema Contract

`CreativeParameterSchemaItem` is a cross-repo JSON contract and must be kept identical in Go and TypeScript.

```json
{
  "id": "size",
  "label": "尺寸",
  "shortLabel": "尺寸",
  "description": "Provider-safe size choice",
  "type": "enum",
  "defaultValue": "1024x1024",
  "options": [{"value":"1024x1024","label":"1024×1024"}],
  "min": null,
  "max": null,
  "step": null,
  "required": false,
  "order": 10,
  "hidden": false
}
```

Allowed `type` values: `enum`, `string`, `number`, `integer`, `boolean`.

Rules:

- `id` must pass the shared forbidden-key normalizer and a safe identifier regex.
- `defaultValue` and option `value` are typed JSON values: string, number, or boolean.
- `enum` requires non-empty `options` and default must be one of the options when present.
- `number`/`integer` may define `min/max/step`; `integer` must cast to an integer before submit.
- `boolean` may render as a switch or true/false enum, but the submitted `userParams` value is boolean.
- `hidden=true` fields are server/admin preset inputs only; they are not returned to regular OpenTU clients and cannot be submitted by OpenTU.
- Unknown schema `type` fails validation in admin APIs; OpenTU should ignore unknown types defensively only for backward compatibility, never for newly saved enabled bindings.

## 3. new-api Design

### 3.1 Versioned Binding Config

Config key: `creative.model_bindings`, versioned JSON. It must be writable only through dedicated admin APIs, not generic option editing.

```json
{
  "version": 1,
  "bindings": [
    {
      "id": "mock:gpt-image-2:preview",
      "providerModelId": "gpt-image-2",
      "priceModelId": "gpt-image-2",
      "displayName": "GPT Image 2 · Mock Preview",
      "modality": "image",
      "enabled": false,
      "canaryGroups": ["test"],
      "channelId": null,
      "adapterPreset": "mock_image_task",
      "parameterTemplate": "mock_gpt_image",
      "recommendedScore": 10,
      "sortOrder": 100
    }
  ]
}
```

Enabled binding validation fails closed on duplicate ids, invalid ids, unknown preset/template, unsupported modality, unknown group/channel, disabled channel, channel not supporting provider model, or schema fields rejected by the shared forbidden normalizer.

### 3.2 Admin APIs

```http
GET  /api/creative/model-bindings
PUT  /api/creative/model-bindings
POST /api/creative/model-bindings/validate
POST /api/creative/model-bindings/dry-run
```

Hard gates:

- admin session required;
- same-origin + CSRF/nonce for writes and dry-run;
- API-token-only access rejected;
- generic `/api/option` cannot write `creative.model_bindings`;
- sanitized audit event for every PUT;
- dry-run output redacts key, Authorization, baseURL, signed URL query, base64, object keys.

### 3.3 Resolver Order

The resolver must run after generic request parsing and before the current broker/group/channel/pricing decisions.

Required order for Creative image task route:

1. Route auth/session/same-origin/nonce/idempotency.
2. Forbidden-material pre-scan for reserved control fields.
3. Resolve `model` as binding id if present.
4. Validate user/group/canary/binding enabled/modality.
5. Validate typed `userParams` against schema.
6. Select locked channel or provider-model candidate channels.
7. Populate relay/task context:
   - `CreativeBindingID`
   - `CreativeProviderModelID`
   - `CreativePriceModelID`
   - `CreativeAdapterPreset`
   - `CreativeParameterTemplate`
   - `CreativeLockedChannelID`
   - `CreativeManaged=true`
   - normalized typed `CreativeUserParams`
8. Pricing uses `CreativePriceModelID`.
9. Channel selection uses `CreativeProviderModelID` or locked channel.
10. Task metadata stores binding/preset/provider/price/channel/userParams.

### 3.4 Pricing Contract

Do not temporarily overwrite `OriginModelName` to mean all of binding, provider, and price.

Add or emulate explicit price fields:

```text
RelayInfo.CreativeBindingID
RelayInfo.CreativeProviderModelID
RelayInfo.CreativePriceModelID
RelayInfo.PriceModelName
```

All price helpers and `TaskBillingContext` must be tested with `bindingId != providerModelId != priceModelId`.

### 3.5 Channel Mapping Contract

For Creative adapter bindings:

- channel `model_mapping` is disabled by default, or only applies to `providerModelId` after validation;
- dry-run must show final provider model after mapping;
- mapping cannot change `priceModelId` unless explicitly configured and tested;
- locked channel must remain locked through retry paths.

### 3.6 Parameter Schema and Forbidden Normalizer

One shared canonical forbidden-key normalizer must be used by:

- admin binding JSON validator;
- schema id validator;
- hidden/admin-only fields validator;
- relay JSON/query/form/multipart/file-part guard;
- legacy `params` migration guard;
- dry-run preview validator.

Reserved/dangerous key families include credentials, auth headers, base URL/path/endpoint/host, channel/group/provider/model override, owner/user ids, callback/webhook/notifyHook, signed URL credentials, object storage internals.

If a legitimate provider field would be forbidden, it must be server-owned inside the preset and never user-supplied.

### 3.7 Image Routes

Phase C1 introduces task-aware mock image routes only:

```http
POST /creative/relay/v1/images/tasks
GET  /creative/relay/v1/images/tasks/:taskId
```

POST gates:

- browser session required;
- same-origin required;
- nonce required;
- idempotency required;
- API token-only rejected;
- forbidden material rejected before upstream/mock call.

GET gates:

- owner-scope;
- no generic TaskDto;
- private allowlisted DTO only.

DTO must not include user id, channel id, quota, private data, raw properties, provider key, raw provider URL, or signed query.

### 3.8 Sync Image URL Privacy

Existing sync `ImageHelper` can write upstream response directly. If sync Creative image routes remain enabled for adapter bindings, implementation must add a real interception point:

- buffered writer around adaptor response, or
- adaptor returns structured `ImageResponse`, or
- adapter bindings use only task route until sync private URL rewrite exists.

No sync adapter binding may return raw provider URL to the browser.

### 3.9 Task Metadata

Use versioned metadata, not scattered fields:

```json
{
  "version": 1,
  "creativeManaged": true,
  "bindingId": "mock:gpt-image-2:preview",
  "providerModelId": "gpt-image-2",
  "priceModelId": "gpt-image-2",
  "adapterPreset": "mock_image_task",
  "parameterTemplate": "mock_gpt_image",
  "channelId": 12,
  "upstreamTaskId": "...",
  "userParams": {"size":"1024x1024"},
  "pollParserMeta": {}
}
```

Public DTO rebuilds from allowlist only. Polling reads preset from task metadata and fails closed when metadata/key affinity is missing.

### 3.10 Idempotency / Provider Accepted Recovery

Critical gate:

- If provider/mock accepted the task, idempotency guard must not be deleted even if task insert, idempotency completion, or submit-settle fails.
- Persist pending/recovery state or durable recovery outbox.
- Only provider-not-accepted failures may release idempotency for retry.

Tests must cover repeated same idempotency key after accepted/local failure and prove no second upstream submit.

### 3.11 URL Privacy and Asset Mode

C1 uses mock private image URLs only. C2 cannot start until one image result mode is chosen and tested:

- short-lived new-api proxy, or
- S3-compatible asset sync, or
- DB/local asset only for local/test.

Production DB fallback is not allowed silently. Missing storage config must fail closed if asset sync mode is selected.

## 4. OpenTU Design

### 4.1 Runtime Model Types

OpenTU must preserve:

```ts
interface CreativeModelEndpointItem {
  id: string; // bindingId
  providerModelId?: string;
  displayName?: string;
  parameterSchema?: CreativeParameterSchemaItem[];
  recommendedScore?: number;
  sortOrder?: number;
}
```

`ModelConfig` must include equivalent runtime fields.

### 4.2 Parameter Rendering

Priority:

```text
runtime parameterSchema > static model-config params > no params
```

Supported value types: `string | number | boolean`, plus `integer` cast/validation. Boolean can be rendered as switch or true/false enum in Phase A, but submitted value must be typed.

### 4.3 Payload Building

For schema-backed Creative runtime models:

- submit `model = model.id`;
- construct `userParams` from schema field ids;
- include `size/aspectRatio/duration` only as schema fields, not legacy rewritten top-level values;
- keep internal adapter options outside `userParams`.

### 4.4 Preferences and Policy

- Binding id is the preference key.
- Same provider model with two bindings must have independent selected params and defaults.
- Stale provider model policy entries must be surfaced as diagnostics or mapped by backend aliases.
- Server `recommendedScore/sortOrder` wins over static recommendation for managed models.



### 4.5 End-to-End `userParams` Carrier

OpenTU must introduce an explicit schema-backed parameter carrier instead of reusing legacy `params`:

```ts
type CreativeUserParamValue = string | number | boolean;
type CreativeUserParams = Record<string, CreativeUserParamValue>;

interface SchemaBackedGenerationArgs {
  model: string; // raw bindingId
  prompt: string;
  images?: string[];
  userParams?: CreativeUserParams;
  internalOptions?: {
    idempotencyKey?: string;
    modelRef?: unknown;
    sourceProfileId?: string;
    onProgress?: unknown;
    onSubmitted?: unknown;
  };
}
```

Required pipeline changes:

- `ParsedGenerationParams` carries `userParams` separately from legacy `extraParams`.
- `WorkflowStep.args` carries `userParams` for schema-backed managed models.
- `GenerationParams` / adapter requests carry `userParams` and internal options as different fields.
- `generation-api-service` and default adapters must not merge `userParams` into legacy provider `params`.
- Schema-backed managed models disable legacy `size/aspectRatio/duration` rewrite and top-level promotion unless a compatibility adapter explicitly derives a non-user provider field server-side.
- Negative tests must assert `onProgress`, `onSubmitted`, `idempotencyKey`, `modelRef`, `sourceProfileId`, `provider`, `channel`, `callback`, `webhook`, `headers`, and URL/control override fields never appear in `userParams` or serialized public request bodies.

### 4.6 Preference Isolation Rules

For schema-backed managed models:

- scoped preference key is the raw binding id or stable OpenTU key containing the raw binding id;
- switching from binding A to binding B must not use A's selected params as fallback;
- if B has no saved params, defaults come only from B's runtime schema;
- old top-level/provider-model params may migrate only through explicit backend alias diagnostics; otherwise ignore and report stale preference;
- tests must cover A → B → A switching for two bindings sharing one `providerModelId`.

## 5. Provider Presets

### 5.1 Phase Policy

- Phase A: no provider presets beyond mock preview schema.
- Phase B: provider dry-run/fixtures only.
- Phase C1: mock upstream only.
- Phase C2+: real provider call requires explicit user authorization, test key/quota cap, canary group, kill switch rehearsal, and no-secret evidence.

### 5.2 Duomi

Blocked until local captured fixtures exist. All Duomi bindings default `enabled=false` and `fixture_required=true`.

Required fixtures: auth header, submit success/failure, poll running/success/failed, result paths, business code semantics, empty/single/multi reference image behavior.

### 5.3 GrsAI

GrsAI may proceed to dry-run/mock from local reports, but not real calls.

Required fixture areas:

- explicit Bearer auth redaction;
- `gpt-image-2-vip` pixel size matrix and quality enum;
- OpenAI-compatible `image` array and edits excluded from first preset;
- Nano Banana wrapper `code`, `data.status`, `data.results`, error paths;
- async late result and violation;
- `n=1` first, batch fan-out later.

## 6. Rollout and Kill Switches

- Global `creative.adapter.enabled=false` default.
- Per-binding `enabled` and canary groups/users.
- Dry-run/mock flags are separate from real provider enablement.
- Kill switch must affect bootstrap, submit, and background polling/cache.
- Rollback rehearsal required before C2.

## 7. Observability and Redaction

Structured logs/metrics may include binding id, preset, channel id, task id hash/truncated, status, duration, retry count, validation reason, settle/refund state.

They must not include API keys, Authorization, baseURL secrets, signed URL query, raw provider URLs, base64, object keys, cookies, CSRF, nonce, or user private media URL.

A fake-secret corpus test must assert redaction across validator, dry-run, submit, poll, fetch, logs, metrics labels, task DTO, Trellis artifacts, and build outputs.

## 8. Phase Acceptance Gates

### Phase A — Schema Preview

- DTO/catalog carries `providerModelId`, `priceModelId`, `parameterSchema`, sort/recommendation.
- OpenTU renders runtime schema and sends typed `userParams` in tests.
- No provider call path exists.
- Binding id/provider/price id distinct test passes.

### Phase B — Admin Validator + Dry Run

- Admin APIs enforce authz/CSRF/raw-option block.
- Binding validator catches group/channel/modality/preset/template/schema errors.
- Dry-run produces redacted request previews.
- Provider fixtures exist for any preset not marked fixture-blocked.

### Phase C1 — Mock Upstream Full Chain

- New image task route uses mock preset only.
- Task metadata, idempotency accepted-failure recovery, CAS/outbox/refund, owner-scoped fetch, and private image DTO tests pass.
- No real provider/network call.

### Phase C2 — Single Real Canary, Later

Blocked until C1 passes and user explicitly authorizes real provider usage.
