# Creative Model Policy Unification Design

## 1. Ownership Boundary

### new-api owns

- channel definitions, keys, base URLs, model mappings, status, priority, weight, groups, and runtime channel selection;
- the effective Creative model catalog exposed to a browser session;
- administrator default/recommended model policy;
- per-user Creative model preference storage and revisioning.

### embedded OpenTU owns

- rendering model selectors and defaults from the managed Creative catalog/policy;
- local reconciliation of stale persisted selections;
- local fail-closed UX when no valid model exists for a requested modality;
- standalone provider/static model behavior outside embedded `/creative/` mode.

OpenTU must not expose raw `new-api` channel IDs, provider credentials, base URLs, selected keys, routing groups, or user/owner overrides to the browser as configuration authority.

## 2. Backend Data Model

Store the administrator Creative model policy in the existing `options` table as JSON under a new non-secret key:

```text
creative.model_policy
```

Recommended normalized schema:

```json
{
  "version": 1,
  "global": {
    "defaults": {
      "text": "gpt-4o",
      "agent": "gpt-4o",
      "image": "gpt-image-1",
      "video": "veo3",
      "audio": "suno_music"
    },
    "recommended": {
      "text": ["gpt-4o"],
      "agent": ["gpt-4o"],
      "image": ["gpt-image-1"],
      "video": ["veo3"],
      "audio": ["suno_music"]
    }
  },
  "groups": {
    "default": {
      "defaults": { "text": "gpt-4o" },
      "recommended": { "text": ["gpt-4o"] }
    },
    "vip": {
      "defaults": { "text": "gpt-4.1", "image": "gpt-image-1" },
      "recommended": { "text": ["gpt-4.1", "claude-sonnet-4"] }
    }
  }
}
```

Rules:

- allowed modalities: `text`, `agent`, `image`, `video`, `audio`;
- model IDs are strings only, trimmed, deduplicated per list;
- unknown top-level fields are dropped during normalization;
- payloads must not include provider keys, base URLs, raw channel IDs, owner/user overrides, notify/callback/webhook fields, or arbitrary provider settings;
- empty/missing policy is valid and means “no admin default”; runtime selection then uses available model ordering/fail-closed behavior.

## 3. Backend API Contract

### Session endpoints

Keep existing safe catalog endpoint shape where possible:

- `GET /creative/api/models`
  - returns current list format for compatibility;
  - model entries remain logical model IDs deduped across channels;
  - no channel IDs or credentials.

Extend bootstrap because OpenTU already calls it during embedded initialization:

- `GET /creative/api/bootstrap`
  - existing fields remain;
  - add `modelPolicy` with the **effective** policy filtered for the current browser session;
  - add `modelPolicyVersion` hash if useful for cache/reconciliation;
  - `catalogVersion` may remain model-list-only or be paired with `modelPolicyVersion` rather than changing old semantics silently.

Effective bootstrap shape:

```json
{
  "modelPolicy": {
    "version": 1,
    "defaults": { "text": "gpt-4o", "image": "gpt-image-1" },
    "recommended": { "text": ["gpt-4o"], "image": ["gpt-image-1"] },
    "stale": {
      "defaults": { "video": "removed-video-model" },
      "recommended": { "audio": ["removed-audio-model"] }
    }
  },
  "modelPolicyVersion": "sha1-of-effective-policy"
}
```

The `stale` field is optional. If included, it is diagnostic only and must not be used by OpenTU as selectable data.

### Admin endpoints

Add dedicated Creative policy endpoints rather than relying only on generic `/api/option/`, because the policy needs validation against groups/model pools:

- `GET /api/creative/model-policy`
  - root/admin-only;
  - returns stored normalized policy;
  - returns available groups and model pools by group for UI dropdowns;
  - returns validation diagnostics for stale model IDs.

- `PUT /api/creative/model-policy`
  - root/admin-only;
  - validates and normalizes JSON;
  - persists through `model.UpdateOption("creative.model_policy", normalizedJSON)` or a thin service wrapper;
  - rejects unsafe fields and malformed modality/default/recommended structures.

Admin UI can still load generic system options, but policy save/read should prefer the dedicated endpoint to avoid silent invalid option writes.

## 4. Effective Policy Calculation

Inputs:

1. current user ID and `User.Group`;
2. available Creative model pool from `service.GetUserCreativeModelPool(user.Group)`;
3. stored admin policy from `creative.model_policy`;
4. per-user `CreativeModelPreference`.

Algorithm:

1. Build the available set from `/creative/api/models` semantics.
2. Normalize raw admin policy.
3. Merge admin global policy with `groups[user.Group]`; group values override global values by modality.
4. Filter defaults/recommended lists by available set.
5. Keep stale diagnostics separately; never return stale entries as selectable defaults.
6. Return effective admin policy in bootstrap.
7. Let OpenTU combine user preferences with effective admin policy client-side, still constrained by the same catalog.

Important distinction: group override selection is based on the logged-in user's primary group. Model availability may still include special usable groups because `GetUserCreativeModelPool` already implements that union.

## 5. Model Modality Classification

Use a layered classifier, with the backend and frontend converging on the same behavior:

1. `supported_endpoint_types` from `dto.OpenAIModels` / `model.GetModelSupportEndpointTypes` is authoritative when present.
2. OpenTU static metadata may enrich labels/icons/type hints **only for model IDs already present** in the managed catalog.
3. Name heuristics may be used as a last resort for display grouping, but not to make static-only models executable.

Suggested mapping:

- `image-generation` -> image;
- `openai-video` plus known Creative video aliases -> video;
- OpenAI/Anthropic/Gemini response/chat endpoints -> text and agent;
- Suno/lyrics aliases or future audio endpoint types -> audio;
- unknown models remain selectable only in generic text/agent contexts if backend endpoint metadata supports text; otherwise they are listed as unsupported for modality-specific tools.

## 6. OpenTU Runtime Design

Introduce a central embedded resolver, for example:

```text
packages/drawnix/src/services/creative-model-policy-resolver.ts
```

Responsibilities:

- parse bootstrap `modelPolicy`;
- merge user preference + admin policy + available catalog;
- return per-modality views:
  - `availableModels`;
  - `recommendedModels`;
  - `defaultModel` or `null`;
  - `staleSelections`;
  - `unavailableReason`.

`creative-session-broker.ts` should install the managed profile `new-api-creative` with catalog and policy from bootstrap. `/creative/api/models` refreshes must update the catalog and re-run reconciliation without reintroducing static defaults.

Embedded mode rules:

- `creative-display-policy.ts` must stop using hard-coded OpenTU defaults as embedded fallbacks;
- `DEFAULT_*_MODEL_ID`, `CHAT_MODELS`, `IMAGE_MODELS`, `VIDEO_MODELS`, `AUDIO_MODELS` can remain for standalone mode and metadata enrichment;
- every model selector must read from the resolver/runtime discovery when `isCreativeEmbeddedMode()` is true;
- persisted selections from local storage must be accepted only if still present in the managed catalog and compatible with the requested modality;
- no valid model means disabled submit/generate UI plus a local error message, before relay/provider calls.

Primary migration targets:

- `creative-session-broker.ts`;
- `creative-display-policy.ts` and tests;
- `runtime-model-discovery.ts` and embedded tests;
- `ai-generation-preferences-service.ts`;
- dock / AI input `ModelSelector` and `ModelDropdown`;
- ChatDrawer model selector;
- video analyzer pages;
- `generation-api-service.ts`, `video-api-service.ts`, `audio-api-service.ts`;
- MCP/canvas operation defaults such as long video generation.

## 7. Admin UI Design

Add a section under `new-api` system settings, preferably:

```text
System Settings -> Models -> Creative Model Policy
```

The form should show:

- global defaults/recommended by modality;
- per-group overrides;
- model pool preview for each group;
- stale saved entries with warnings and one-click cleanup;
- help text: “可用性来自 Channel/Group，OpenTU 只显示逻辑模型，实际渠道由 new-api 路由选择”。

Implementation can start with a validated JSON editor plus generated dropdown helpers if a full visual multi-select form would slow the first safe version. The acceptance bar remains that saves are validated, normalized, and runtime-filtered.

## 8. Compatibility and Migration

- Existing users with no `creative.model_policy` continue to see the managed catalog, but no static-only fallback is allowed in embedded mode.
- Existing per-user `CreativeModelPreference` remains valid only after catalog filtering.
- Standalone OpenTU remains unchanged.
- Existing `/creative/api/models` clients are not broken.
- Stale persisted OpenTU selections are reconciled locally; they do not require a destructive migration.

## 9. Security / Privacy Requirements

- No browser-visible raw channel IDs, selected keys, provider credentials, base URLs, owner/user override fields, callback/notify/webhook fields, or routing internals.
- Admin policy is model IDs and display/order hints only.
- Effective policy calculation is read-only and must tolerate stale channel/model state.
- Empty catalogs fail closed locally and on backend relay validation.

## 10. Rollback

- Backend rollback: remove/ignore `creative.model_policy`; bootstrap omits `modelPolicy`; OpenTU must treat missing policy as empty policy over the managed catalog.
- Frontend rollback: standalone static behavior remains isolated; embedded mode should still at minimum show an empty/unavailable managed profile rather than static defaults.
- Admin UI rollback: keep the option in DB harmless; it is ignored if service code is reverted.
