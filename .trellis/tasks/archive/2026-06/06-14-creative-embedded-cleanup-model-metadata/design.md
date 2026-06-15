# Design — Creative Embedded Standalone Cleanup And Model Metadata

## 1. Scope

This task spans two repositories:

- `/mnt/f/code/project/opentu`: embedded UI cleanup, toolbox filtering, managed model metadata consumption, selector/parameter behavior, tests, rebuild.
- `/mnt/f/code/project/new-api`: Creative catalog payload enrichment and safe backend tests.

`new2fly` owns orchestration artifacts, release gates, local staging runbook, and final verification records.

## 2. Embedded UI cleanup design

### 2.1 Embedded surface policy

Create or reuse a single embedded-mode gate (`isCreativeEmbeddedMode`) for standalone-only surfaces. The embedded app should treat these as product/platform chrome, not user tools:

- feedback QR: hidden by default;
- upstream OpenTU GitHub link: hidden;
- GitHub/Gist Cloud Sync: hidden;
- external URL tools requiring `${apiKey}`: hidden or unavailable without settings redirect;
- local Backup/Restore: allowed only as user data import/export, with provider secrets/environment export disabled.

### 2.2 Feedback button

Current hard-coded QR has external OpenTU/Tuzi branding. MVP behavior:

- `FeedbackButton` returns `null` in embedded mode.
- `BottomActionsSection` remains stable; hiding the component should not disturb project/toolbox/task vertical alignment.
- Do not add a replacement QR until there is a new-api admin setting/source of truth.

Future extension: `CreativeBootstrap` may expose a safe `ui.feedback` object with label and image URL. If implemented later, image URL must be same-origin or administrator-configured and sanitized.

### 2.3 GitHub button / menu

- In embedded `AppToolbar`, remove the standalone GitHub button.
- The non-embedded toolbar/menu can keep existing OpenTU GitHub behavior.
- If a GitHub menu item is present in non-embedded app menu, leave unchanged unless it appears in embedded menu.

### 2.4 Cloud Sync / Backup Restore

- Cloud Sync is backed by `GitHubSyncContext` and token/Gist flows, so hide `CloudSync` in embedded app menus and prevent deferred `SyncSettings` from opening in embedded mode.
- `SyncStatusIndicator` should return `null` in embedded mode if it can appear under a provider.
- Backup/Restore may remain because it is local user data; however `includeEnvironment` / `includeSecrets` should be disabled or forced false when embedded.
- UI copy should make embedded backup local-data-only if the dialog exposes environment options.

### 2.5 Toolbox external API-key tools

Current `ToolboxDrawer` blocks any URL containing `${apiKey}` and opens settings. In embedded mode that is wrong because users cannot configure provider keys.

MVP:

- Filter built-in external URL tools requiring `${apiKey}` from `toolboxService.getAvailableTools()` results in embedded mode, or filter them inside `ToolboxDrawer` before display/search/categories.
- As a defense-in-depth path, if a custom/persisted tool with `${apiKey}` is clicked in embedded mode, show a local unavailable message and do not open settings.
- `Chat-MJ` is hidden by default in embedded mode.

## 3. Creative model metadata contract

### 3.1 Backend DTO

Introduce a Creative-specific model DTO rather than widening general OpenAI model behavior everywhere, for example:

```go
type CreativeModelCatalogItem struct {
  ID                     string                  `json:"id"`
  Object                 string                  `json:"object"`
  Created                int                     `json:"created"`
  OwnedBy                string                  `json:"owned_by"`
  SupportedEndpointTypes []constant.EndpointType `json:"supported_endpoint_types"`
  Label                  string                  `json:"label,omitempty"`
  ShortLabel             string                  `json:"shortLabel,omitempty"`
  ShortCode              string                  `json:"shortCode,omitempty"`
  Description            string                  `json:"description,omitempty"`
  Type                   string                  `json:"type,omitempty"`
  Vendor                 string                  `json:"vendor,omitempty"`
  Tags                   []string                `json:"tags,omitempty"`
  UI                     CreativeModelUIHints    `json:"ui,omitempty"`
}
```

The exact shape can be adjusted during implementation, but the boundary is strict: no channel IDs, base URLs, keys, selected-key/affinity, upstream secret values, or owner-group details.

### 3.2 Metadata sources

For each user-visible logical model:

1. Start with existing `buildOpenAIModel` fields for compatibility.
2. Merge safe metadata from `model.Model` / pricing metadata where available:
   - description;
   - icon/vendor name if safe;
   - tags;
   - custom endpoint metadata.
3. Optionally derive UI fields from known model IDs and endpoint hints:
   - `type`: text/image/video/audio;
   - vendor/owned_by;
   - `shortCode`: deterministic from metadata/static matching, not secret-bearing.
4. Keep exact static OpenTU model ID matching on the frontend as the highest-fidelity source when available.

### 3.3 Catalog version

`catalogVersion` should include the enriched model JSON so UI cache invalidates when metadata changes, not only when raw model IDs change.

### 3.4 Admin policy integration

Existing `creative.model_policy` remains the admin mechanism for defaults/recommended lists. Metadata enrichment does not grant availability. The effective policy still filters against the current user model pool.

## 4. OpenTU model metadata consumption

### 4.1 Type extension

Extend `CreativeModelEndpointItem` / `RemoteModelListItem` parsing to accept safe metadata fields:

- `label`, `name`, `displayName`, `shortLabel`, `shortCode`, `description`;
- `type`, `modality`, `modalities`, `vendor`, `owned_by`;
- `tags`, `supported_endpoint_types`;
- optional `imageDefaults`, `videoDefaults`, or constrained `parameters` if backend emits them.

### 4.2 Merge strategy

`normalizeCreativeModel` should:

1. Use exact `getStaticModelConfig(id)` when available.
2. Overlay safe server display fields only when useful and non-empty.
3. For unknown IDs, build a `ModelConfig` with:
   - inferred `type` from explicit `type`/`modality` first, endpoint hints second, ID fallback last;
   - `vendor` from server vendor/owned_by first, ID fallback second;
   - `label`/`shortLabel`/`shortCode` from server metadata if present, otherwise deterministic fallback;
   - `tags` merged from server tags plus `runtime`/`creative`.
4. Never add static-only model IDs that are not in the managed catalog.

### 4.3 Parameter behavior

Existing parameter compatibility in `model-config.ts` already supports exact IDs and tags. The fix should prefer adding tags/metadata so existing `getCompatibleParams` works, instead of hard-coding selector-specific exceptions.

Expected behavior:

- Known exact models like `gpt-image-2`, `gpt-5.5-mini`, `seedance-1.5-pro`, `nano-banana` render with their static short code/params.
- Custom aliases can render better if new-api metadata/tags identify them.
- Unknown models remain callable only if in catalog, but get conservative generic params.

## 5. Admin model policy UX design

### 5.1 Current problem

`CreativeModelPolicySection` is functionally safe but visually/operationally weak: the administrator has to edit a large JSON blob while the page only previews pools and stale diagnostics after the fact. This makes the intended model-policy mental model hard to discover.

### 5.2 Target information architecture

Default layout should be a guided policy builder:

1. **Header summary**: concise explanation plus save status/actions.
2. **Availability overview**: cards/chips for groups, model counts, stale count, current policy version.
3. **Global policy builder**:
   - modality rows (`text`, `agent`, `image`, `video`, `audio`);
   - one default model picker per modality;
   - recommended multi-select per modality.
4. **Group override builder**:
   - group list or accordion;
   - per-group rows only show models available for that group;
   - empty group state explains it inherits global policy.
5. **Diagnostics and cleanup**:
   - stale entries grouped by group/modality;
   - action to load/apply cleaned policy;
   - no stale state kept visually quiet.
6. **Advanced JSON**:
   - collapsed by default or tabbed under "Advanced JSON";
   - format/load-cleaned/save retained for expert recovery.

### 5.3 UX constraints

- Avoid a giant textarea as the first thing users see.
- Avoid exposing provider/channel/key/base URL concepts inside this policy UI.
- Keep backend validation as the source of truth; frontend helps construct valid policy but does not weaken server checks.
- Use existing shadcn/settings primitives in `web/default` to match the current dashboard system.
- Preserve i18n key usage for Chinese/English labels.

### 5.4 Data model

The existing `CreativeModelPolicyState` is enough for MVP guided editing, but type definitions may need small helpers:

- `allowedModalities` drives rows.
- `modelPools` drives group-specific option sets.
- `policy.global` and `policy.groups` become editable local draft state.
- `cleanedPolicyJSON` remains the source for cleanup action.

If enriched catalog metadata is added during this task, the admin UI may show labels/short names in model pickers, but must continue to save logical model IDs only.

## 6. Testing strategy

### OpenTU unit/component tests

- Feedback/GitHub/cloud sync hidden in embedded mode.
- Toolbox filters or blocks API-key-template external tools in embedded mode without opening settings.
- `normalizeCreativeModel` / creative session broker preserves static metadata for exact models and consumes server short labels/codes for unknown custom models.
- Model selector uses enriched metadata and does not fall back to standalone static defaults outside the managed catalog.
- Parameter compatibility for server-tagged models does not leak MJ params to non-MJ models.

### new-api tests

- `/creative/api/models` returns enriched safe DTO fields.
- DTO redaction test asserts no forbidden keys appear in JSON (`api_key`, `apiKey`, `base_url`, `baseUrl`, `channel_id`, `channelId`, `selected_key`, `group`, `owner_id`, etc.).
- Catalog version changes when safe metadata changes.
- Existing generic model list tests still pass.

### Integration / staging

After implementation:

1. OpenTU tests/typecheck for touched packages.
2. new-api Go tests for Creative/model catalog.
3. `python3 scripts/creative_release_gate.py build-sync-check --run-new-api-tests`.
4. Rebuild local Docker staging image.
5. Start `newapi-opentu-staging` and run Playwright checks:
   - feedback QR absent;
   - GitHub toolbar button absent;
   - Cloud Sync absent from embedded menu;
   - Chat-MJ/API-key prompt absent;
   - model dropdown shows meaningful labels/short codes for configured models;
   - no page crash.

## 7. Rollback

- UI hiding changes are low risk and can be reverted independently.
- Backend DTO enrichment should be Creative-specific; rollback by returning current `dto.OpenAIModels` fields only.
- If model metadata enrichment destabilizes selectors, keep UI cleanup and roll back enrichment behind a narrower frontend fallback.
