# Design: Creative adapter manifest and live binding UI

## Architecture Boundary

New API remains the authority for provider credentials, channel availability, model policy, billing, and Creative security. OpenTU remains a managed client that consumes a resolved catalog and parameter schema. The admin Creative Binding page bridges them by binding a New API Channel model to a Creative-safe adapter preset and parameter schema.

```
New API Channel
  ├─ provider/base URL/API key/models   (secret/admin-only)
  ↓ selected by id
Creative Adapter Manifest
  ├─ provider protocol capability       (safe admin metadata)
  ├─ supported transport mode           (mock/dry-run/future-live/live)
  ├─ allowed parameter templates        (safe schemas)
  ↓ bound into
Creative Model Binding
  ├─ channelId/providerModelId/priceModelId/displayName
  ├─ adapterPreset/parameterTemplate/parameterSchema
  ├─ enabled/canary/sort/recommendation
  ↓ resolves to
Public Creative Catalog
  └─ only model metadata + parameterSchema for OpenTU
```

## Backend Contracts

### Adapter Manifest

Introduce an internal manifest type close to:

```go
type CreativeAdapterManifest struct {
    ID                  string   `json:"id"`
    Label               string   `json:"label"`
    Description         string   `json:"description"`
    Modality            string   `json:"modality"`
    ProviderFamily      string   `json:"providerFamily,omitempty"`
    TransportMode       string   `json:"transportMode"` // mock, dry_run, future_live, live
    Status              string   `json:"status"`        // available, disabled, future
    DefaultTemplate     string   `json:"defaultTemplate"`
    AllowedTemplates    []string `json:"allowedTemplates"`
    CanBeEnabled        bool     `json:"canBeEnabled"`
    RequiresChannel     bool     `json:"requiresChannel"`
    SupportsProviderCall bool    `json:"supportsProviderCall"`
    Notes               []string `json:"notes,omitempty"`
}
```

Phase A manifests should include existing available presets and may include future disabled entries:

- `mock_image_task`: mock transport, can be validated and enabled when existing rules allow.
- `grsai_gpt_image_dryrun`: dry-run fixture, admin preview only unless current rules permit disabled save.
- `duomi_image_live`: future/live placeholder, visible as unavailable, cannot be enabled or used for provider calls in Phase A.
- `grsai_image_live`: future/live placeholder, visible as unavailable, cannot be enabled or used for provider calls in Phase A.

The manifest list must be the single shared source used by:

- validation of adapter preset ids,
- validation of allowed parameter templates,
- admin API response,
- UI guided builder choices.

### Parameter Templates

Parameter templates are backend-owned named schemas. They should support:

- model-specific field ids (`quality`, `size`, `resolution`, `aspectRatio`, etc.),
- localized labels/short labels or stable labels that frontend i18n can map,
- enum options with labels,
- default values,
- field ordering,
- future validation metadata.

Chinese copy requirement: `quality` must display as “质量”, not “画质”. Different providers may still expose distinct labels for other concepts, for example “分辨率”, “尺寸”, or provider-specific aspect ratio names.

### Admin APIs

Add a no-store authenticated endpoint:

- `GET /api/creative/adapter-manifests`
  - Dashboard-session admin only, same boundary style as model binding admin APIs.
  - Returns manifest metadata and parameter template summaries/schemas safe for admin UI.

Existing endpoints remain:

- `GET /api/creative/model-bindings`
- `POST /api/creative/model-bindings/validate`
- `POST /api/creative/model-bindings/dry-run`
- `PUT /api/creative/model-bindings`
- `GET /api/creative/channel-summaries`

Validation uses the same manifest registry. `PUT` must still run a no-provider-call dry-run before saving.

### Live Adapter Follow-up Shape

A later live adapter task should implement for each provider:

1. manifest status changes from `future` to `available` behind feature/canary gates,
2. request mapper from Creative normalized task request to provider payload,
3. response parser and task id/result extraction,
4. polling/status parser and terminal-state classification,
5. selected-key/channel affinity and owner-scoped fetch,
6. billing estimate, completion adjustment, failure/refund paths,
7. fixtures and no-secret golden tests,
8. staging smoke with explicit approval before real provider calls.

This prevents UI from becoming a provider-specific switchboard while still allowing provider-specific protocol logic where it belongs.

## Frontend Design

### Admin Binding Page

The admin UI should fetch three data sets in parallel:

- current Creative binding config,
- channel summaries with channel models,
- adapter manifests.

Guided builder flow:

1. Select a channel.
2. Select a model from the selected channel's synced model list or enter a provider model id if allowed by existing UX.
3. Select an adapter manifest filtered by modality/status.
4. Select a parameter template allowed by that manifest.
5. Generate binding draft with manifest/template defaults.
6. Validate and dry-run before save.

A disabled/future adapter should still be visible with explanatory copy, but controls that would save it as enabled must be disabled. This answers “Duomi live / GrsAI live adapter UI” without creating provider-specific pages: they appear as adapter choices with status, prerequisites, and future/live availability.

### Copy Model

Use consistent terms:

- Channel: stores provider credentials, base URL, upstream model list, and New API routing.
- Adapter: knows the provider protocol and supported Creative modality.
- Binding: exposes one Creative model entry by connecting channel model + adapter + parameter schema.
- Parameter schema: the safe user-facing controls OpenTU renders.

Chinese user-facing field copy:

- `quality`: “质量”
- `size`: “尺寸” or “图片尺寸” depending existing context
- `resolution`: “分辨率”
- `aspectRatio`: “比例”

## Security and Privacy

- Never serialize channel secret fields into manifests or bindings.
- Keep webhook, callback, notifyHook, owner, user id, and provider secret keys out of binding schemas.
- Admin endpoints require dashboard session and no-store cache headers.
- Public Creative catalog must not contain admin-only manifest status, provider base URL, API key, or live debug data.
- Future live adapter validation must deny provider-mediated callback/body fields by normalized key.

## Compatibility

- Existing saved binding JSON must continue to load.
- Existing mock and GrsAI dry-run bindings must validate if they used supported templates.
- If manifest fetch fails, UI should show a fail-closed error and avoid saving new bindings based on stale hard-coded defaults.
- Embedded OpenTU schema rendering must keep working with existing `parameterSchema` arrays.

## Rollout and Rollback

Phase A is low provider-risk because no real provider calls are added. Rollback can disable the new manifest endpoint/UI path and retain existing binding storage. Saved binding format remains compatible, so rollback should not corrupt `creative.model_bindings`.
