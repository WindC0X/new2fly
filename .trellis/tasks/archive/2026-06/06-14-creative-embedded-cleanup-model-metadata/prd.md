# Creative Embedded Standalone Cleanup And Model Metadata

## Goal

Make the embedded OpenTU Creative app feel like a managed surface inside `new-api`, not a standalone OpenTU install. Remove or gate standalone-only entry points, stop asking end users for API keys, and restore model selector / generation parameter quality by carrying safe model metadata from `new-api` into OpenTU's managed catalog.

## User Value

The current local staging page loads, but several UI surfaces still expose OpenTU standalone product assumptions:

- feedback group QR code points to the original OpenTU/Tuzi asset;
- embedded toolbar still shows a GitHub button for the upstream OpenTU project;
- cloud sync and some settings still reference GitHub/Gist/API key workflows;
- toolbox `Chat-MJ` opens a third-party URL that requires `${apiKey}` and forces users into OpenTU settings;
- managed model selectors show generic `#img`/plain IDs because `new-api` exposes only logical model IDs and endpoint hints, not enough display/capability metadata.

Users should see a coherent new-api-managed Creative surface where available models, defaults, parameter options, and unavailable states are controlled by the administrator and current channel/model pool.

## Confirmed Facts From Code / Screenshots

### Embedded detection / managed session

- OpenTU embedded mode is detected by `/creative` / `/creative/`:
  - `apps/web/src/utils/embed-detection.ts`
  - `packages/drawnix/src/services/creative-mode.ts`
- Managed profile constants already exist:
  - `CREATIVE_MANAGED_PROFILE_ID = "new-api-creative"`
  - `CREATIVE_MANAGED_PROFILE_NAME = "New API Creative"`
  - `/creative/api/bootstrap`, `/creative/api/models`, and `/creative/relay/v1` are the managed entry points.
- `creative-session-broker.ts` installs a managed provider/catalog from `/creative/api/models` and fails closed when the pool is empty.

### Standalone UI remnants

- Feedback button is always rendered by `BottomActionsSection` and uses hard-coded external QR assets:
  - `packages/drawnix/src/components/toolbar/bottom-actions-section.tsx`
  - `packages/drawnix/src/components/feedback-button/feedback-button.tsx`
  - `QR_CODE_URL = https://tuziai.oss-cn-shenzhen.aliyuncs.com/aitu/AiTu.png`
- Embedded top app toolbar always renders a GitHub button linking upstream OpenTU:
  - `packages/drawnix/src/components/toolbar/app-toolbar/app-toolbar.tsx`
  - `window.open('https://github.com/ljquan/aitu', '_blank')`
- App menu exposes Backup/Restore and Cloud Sync in the same menu:
  - `packages/drawnix/src/components/toolbar/app-toolbar/app-menu-items.tsx`
- Cloud Sync uses GitHub/Gist token flows and is standalone-only for embedded new-api unless explicitly redesigned:
  - `packages/drawnix/src/components/sync-settings/SyncSettings.tsx`
  - `packages/drawnix/src/contexts/GitHubSyncContext.tsx`
- Backup/Restore is local import/export and can remain useful, but the `includeEnvironment` / `includeSecrets` options need embedded-mode safety review because new-api should own provider credentials.
- Toolbox `Chat-MJ` is a built-in external iframe tool with `${apiKey}` in the URL:
  - `packages/drawnix/src/tools/built-in-manifests.tsx`
  - `url: 'https://vercel.ddaiai.com/#/?settings={"key":"${apiKey}","url":"https://api.tu-zi.com"}'`
- `ToolboxDrawer` detects `${apiKey}` and opens settings with message `该工具需要配置 API Key，请先完成设置`:
  - `packages/drawnix/src/components/toolbox-drawer/ToolboxDrawer.tsx`

### Model metadata gap

- `new-api` `/creative/api/models` currently returns `[]dto.OpenAIModels` via `creativeModelsForUser`:
  - fields: `id`, `object`, `created`, `owned_by`, `supported_endpoint_types`
  - no `label`, `shortLabel`, `shortCode`, `type`, `vendor`, `imageDefaults`, `videoDefaults`, or parameter capability metadata.
- OpenTU `normalizeCreativeModel` uses static model config when exact model ID is known; otherwise it infers generic fallback labels and type from endpoint hints/ID.
- Static OpenTU model config already contains high-quality metadata and parameter compatibility:
  - `packages/drawnix/src/constants/model-config.ts`
  - examples: `shortCode` values like `sc15p`, `nb`, `g55`, and param configs for image size/resolution/quality, video duration/ratio, MJ params.
- If a new-api channel uses logical model names not matching OpenTU static IDs or lacks endpoint hints, embedded UI degrades to generic badges such as `#img`.

### new-api model metadata source

- `new-api` model/pricing metadata exists in `model.Model` / `model.Pricing` structures with fields such as `model_name`, `description`, `icon`, `tags`, `vendor_id`, `endpoints`.
- `buildOpenAIModel` currently does not carry those metadata fields to Creative; it only sets OpenAI-compatible list fields plus `SupportedEndpointTypes`.

### Admin model policy UX gap

- Current `web/default/src/features/system-settings/models/creative-model-policy-section.tsx` is mostly a large JSON textarea plus passive group preview.
- The screenshot shows the page is hard to operate because the primary action is editing raw JSON, while the useful model pool/default/recommended choices are only shown as badges below.
- Existing API state already returns enough structure for a better UI baseline:
  - `allowedModalities`
  - `policy`, `policyJSON`, `cleanedPolicy`, `cleanedPolicyJSON`
  - `modelPools[]` with `group`, `models`, `modelCount`, and `effectivePolicy`
  - `diagnostics.staleByGroup`
- The backend dedicated endpoint already validates unsafe fields, so the UI should guide safe policy construction instead of making JSON the primary workflow.

## Requirements

### A. Embedded standalone cleanup

1. In embedded mode, hide the hard-coded `用户反馈群` QR entry by default.
2. In embedded mode, hide the GitHub toolbar button linking to upstream OpenTU.
3. In embedded mode, hide Cloud Sync / GitHub-Gist sync entry points unless a future new-api-backed sync contract is explicitly implemented.
4. Keep local Backup/Restore available only if it is safe in embedded mode:
   - local export/import can remain;
   - provider/API-key/environment secret backup must be disabled or hidden in embedded mode;
   - no export/import path may suggest it configures new-api provider/channel credentials.
5. In embedded mode, toolbox built-in external tools that require `${apiKey}` must not open the standalone API-key settings flow.
6. `Chat-MJ` must either:
   - be hidden in embedded mode by default, or
   - be replaced by a new-api relay-backed component/tool only if it can work without browser API keys.

Recommended MVP decision: hide `Chat-MJ` and other API-key-template external tools in embedded mode. Keep new-api relay-backed native tools (image/video/audio/batch/MJ adapter paths) available through existing Creative generation surfaces.

### B. Managed model metadata / selector fidelity

7. Extend the Creative model catalog contract so `/creative/api/models` and bootstrap `models` can include safe UI metadata, without exposing channel IDs, provider keys, base URLs, selected keys, owner group internals, or routing authority.
8. Preserve existing OpenAI-compatible model list behavior outside `/creative/api/*`; do not break `/v1/models`-style consumers.
9. In OpenTU embedded mode, merge server-provided metadata with static model config:
   - exact static model config should keep rich defaults;
   - server metadata may provide display/vendor/short-code hints for custom logical IDs;
   - if metadata is absent, fallback inference remains but must not invent executable static defaults for unavailable models.
10. Model selectors and footer chips must show meaningful short names when available, not generic `#img` for every image model.
11. Parameter dropdowns must use the selected model's capability/default metadata where possible:
   - image: aspect ratio / size / resolution / quality as supported;
   - video: duration / size / aspect ratio as supported;
   - text: temperature / sampling / length only when supported or generic text defaults are valid;
   - MJ-specific parameters only for MJ-capable models.
12. If the administrator configured a model name unknown to OpenTU and no metadata exists, the UI should remain usable with a clear fallback label and no unsafe/static-only parameter assumptions.

### C. Admin / operations behavior

13. The administrator-facing model/channel workflow remains the source of truth:
   - new-api channel/model pool decides availability;
   - `creative.model_policy` decides default/recommended models;
   - OpenTU embedded UI only consumes the filtered user-effective catalog/policy.
14. No end-user embedded UI should ask users to configure upstream API keys or provider base URLs.
15. No new secret-bearing fields are allowed in Creative bootstrap/models payloads.

### D. Creative model policy admin UX

16. Replace the raw-JSON-first `Creative 模型策略` page with a guided policy builder as the default workflow.
17. Keep JSON editing as an advanced/escape hatch mode, not the primary visible surface.
18. Provide clear sections for:
   - global defaults by modality;
   - global recommended models by modality;
   - per-group overrides;
   - group/model-pool preview;
   - stale/invalid diagnostics and one-click cleaned-policy load/apply.
19. Model selection controls in the admin policy UI must only offer models from the effective available pool for the relevant scope/group.
20. The UI must make the distinction clear:
   - Channels/model pool define what exists;
   - Creative model policy only selects defaults/recommendations from that pool;
   - OpenTU never receives upstream provider/channel/key authority.
21. The admin page should be compact and scannable on a wide dashboard viewport: large empty JSON editor area should be avoided by default.
22. Saving from the guided UI must produce the same normalized policy shape accepted by `/api/creative/model-policy` and preserve backend validation.

## Out Of Scope Unless Separately Confirmed

- Public/production deployment, DNS/TLS/CDN work.
- Replacing the feedback QR with a custom administrator-uploaded image in this MVP. Default is hidden; configurable feedback can be a follow-up if desired.
- Building a full new-api-backed cloud sync replacement for GitHub/Gist sync.
- Rewriting third-party `Chat-MJ` itself.
- Letting end users choose concrete channel/provider/base URL in OpenTU embedded mode.
- Creating real provider generation tasks or consuming provider quota during verification.

## Acceptance Criteria

- [ ] Embedded `/creative/` no longer shows hard-coded `用户反馈群` QR by default.
- [ ] Embedded `/creative/` no longer shows the upstream OpenTU GitHub toolbar button.
- [ ] Embedded app menu no longer exposes standalone GitHub/Gist Cloud Sync.
- [ ] Embedded Backup/Restore remains local-data only or is safely limited; environment/API-key secret export/import is hidden/disabled in embedded mode.
- [ ] Clicking/opening toolbox `Chat-MJ` in embedded mode no longer opens settings or prompts the user to configure API Key; the tool is hidden or explicitly marked unavailable without settings redirect.
- [ ] `/creative/api/models` returns only safe model catalog metadata and no channel IDs, API keys, base URLs, selected keys, group internals, or provider secrets.
- [ ] OpenTU embedded model dropdowns render meaningful labels/short codes for known static models and server-enriched custom models.
- [ ] Image/text/video footer chips do not collapse to generic `#img` when metadata exists.
- [ ] Model parameter dropdowns reflect selected model type/capabilities and do not show MJ-only params for non-MJ models.
- [ ] Empty/unknown model metadata still fails closed for generation if the model is not in the managed catalog.
- [ ] Relevant unit tests pass in OpenTU and new-api.
- [ ] Embedded release gate, dist sync, Docker/local staging, and Playwright smoke are rerun before completion.

## Open Product Decision

Current recommended MVP: **hide standalone-only feedback/GitHub/cloud-sync/Chat-MJ API-key surfaces in embedded mode** and restore model selector quality through safe metadata. If the product later wants a replacement feedback QR, add a new administrator-configurable Creative feedback setting rather than hard-coding a new image into OpenTU.
