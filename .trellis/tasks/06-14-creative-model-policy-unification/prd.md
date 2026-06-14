# Creative Model Policy Unification

## Goal

Unify model availability, default model policy, and model selection behavior for embedded OpenTU inside `new-api` Creative so that every OpenTU component uses the current user’s `new-api` channel/ability-backed model pool, while preserving `new-api` as the owner of channel routing and upstream credentials.

## User Problem

The current implementation only hides OpenTU standalone provider defaults in some embedded UI surfaces. It does not fully satisfy the intended model architecture:

1. OpenTU settings should represent the model list/defaults shared by multiple OpenTU components, but the list must be synchronized from `new-api` channel/ability availability.
2. `new-api` channel configuration remains the real upstream capability source: channels have groups, enabled status, models, priority, weight, keys, base URL, and model mapping.
3. OpenTU still has static/default model lists across many places, including but not limited to dock/AI input, ChatDrawer, model dropdowns, workflow/tool windows, generation services, and MCP tools. Those static defaults may include models not present in any enabled `new-api` channel and must not leak into embedded `/creative/` as selectable or executable defaults.

## Confirmed Facts From Code Inspection

### new-api backend

- A logged-in browser session has a user group. New users default to `User.Group = "default"` (`model/user.go`).
- Channels have `Channel.Models`, `Channel.Group`, `Status`, `Priority`, and `Weight`; channel group also defaults to `default` (`model/channel.go`).
- Channel abilities are generated from `Channel.Models x Channel.Group`; enabled abilities depend on channel status (`model/ability.go`, `AddAbilities`, `UpdateAbilities`).
- Creative model catalog endpoint is `GET /creative/api/models` (`router/web-router.go`).
- `CreativeListModels` calls `creativeModelsForUser`, which calls `service.GetUserCreativeModelPool(userCache.Group)` and then `model.GetGroupEnabledModels(group)` (`controller/creative.go`, `service/creative.go`, `model/ability.go`).
- `GetUserCreativeModelPool` returns the union of models from the current user’s usable groups, deduplicated and sorted.
- Runtime provider/channel selection is backend-owned: `GetRandomSatisfiedChannel(group, model, retry)` chooses an enabled channel for a group+model using priority/weight/cache, not browser-selected raw channel (`model/channel_cache.go`, `model/ability.go`).
- There is no single “default channel” concept. The operational default is the user’s `default` group plus whatever enabled channels/abilities are bound to that group.
- `new-api` already stores per-user Creative model preferences via `CreativeModelPreference` with safe fields: default, pinned, recent, displayMode, customOrder. It intentionally excludes provider keys/base URLs/channel overrides (`model/creative.go`).

### OpenTU frontend

- Static model catalogs/defaults exist in `packages/drawnix/src/constants/model-config.ts`, `CHAT_MODELS.ts`, `creative-display-policy.ts`, Gemini config, generation preference service, chat hooks, canvas operations, MCP tools, video analyzer pages, and other component/service entry points.
- Current embedded session-broker initialization builds one managed profile: `new-api-creative` / `New API Creative` and fetches `/creative/api/bootstrap` plus `/creative/api/models` (`creative-session-broker.ts`).
- Current `creative-display-policy.ts` still contains static default visible/default model ids such as `gpt-5.5`, `gpt-image-2-vip`, `seedance-1.5-pro`, `suno_music` and friends.
- Current model preference sync can fetch/apply per-user defaults, but does not by itself define an admin/global default policy or guarantee all component fallbacks avoid static defaults.

## Required Product Semantics

1. OpenTU embedded users choose logical models and per-feature defaults, not raw `new-api` channels.
2. `new-api` administrators configure upstream channels, groups, model mappings, priorities, weights, and enabled status.
3. If several channels support the same model, OpenTU should show one logical model; `new-api` selects the actual channel by backend routing policy.
4. If users or admins need to distinguish upstreams, they should expose distinct logical model names/model mappings in `new-api` (for example `fast-gpt-4o`, `cheap-gpt-4o`, `azure-gpt-4o`) rather than letting OpenTU select channel ids directly.
5. OpenTU embedded mode must never present or execute a model that is not in the current user’s available `new-api` Creative model pool.
6. OpenTU standalone mode may keep its existing static/provider behavior unless explicitly changed by a separate task.


## Admin Default / Recommended Model Policy Decision

Default and recommended models are in scope for this task and must be configured in `new-api`, not in OpenTU standalone provider settings.

Recommended product semantics:

1. Store an administrator-managed Creative model policy in `new-api` as safe JSON.
2. Support a global policy plus per-user-group overrides. The current user group chooses the group override; the available model pool is still the union returned by `service.GetUserCreativeModelPool(user.Group)`.
3. Admin UI should present selectable model IDs from `new-api` abilities/channel groups rather than forcing raw free-text entry. Manual JSON may remain as an expert/debug escape hatch only if it is validated and normalized before save.
4. Policy shape should include at least:
   - per-modality defaults: `text`, `agent`, `image`, `video`, `audio`;
   - per-modality recommended lists;
   - optional ordering/display metadata when needed.
5. Runtime policy must be filtered against the current user's effective `/creative/api/models` catalog before it is returned to OpenTU. Stale policy entries are ignored or reported as stale diagnostics; they must not become executable.
6. User model preferences remain per-user overrides, but only if still present in the effective catalog.

Effective selection order in embedded OpenTU:

1. valid user preference for the relevant modality;
2. valid admin group default for the user's group;
3. valid admin global default;
4. first valid recommended/available model for the modality;
5. no valid model -> explicit unavailable state and local fail-closed submit/generate behavior.


## Default Model List Behavior For Dock / ChatDrawer / Tool Components

In embedded `/creative/` mode, every model list box (dock/AI input, ChatDrawer, tool windows, workflow forms, benchmark selectors, MCP tool defaults, etc.) must treat its default list as a projection of the managed Creative model policy, not as a component-local static array.

Required behavior per component:

1. Source list:
   - use only the current `new-api-creative` managed catalog from `/creative/api/models`;
   - filter by modality/capability needed by the component (text/image/video/audio/agent);
   - never append OpenTU static model lists in embedded mode.
2. Ordering/defaulting:
   - apply the effective Creative policy in this order: valid user default/pinned/recent/custom order, valid admin/global defaults when available, then remaining available models sorted by display priority;
   - policy entries not present in the current catalog are ignored or marked stale, not submitted.
3. Initial selected value:
   - if the persisted selected model is still available, keep it;
   - otherwise select the first valid policy/default model for that modality when auto-selection is safe;
   - if no valid model exists, show an explicit unavailable/empty state and disable submit/generate actions for that modality.
4. Static model metadata:
   - OpenTU static `model-config`/`CHAT_MODELS` data may be used only to enrich labels/icons/vendor/type hints for models that are already present in the managed catalog;
   - static entries absent from the managed catalog must not become selectable or executable.
5. Standalone mode:
   - standalone OpenTU may keep the existing static/default lists unless a separate task changes that behavior.

## Requirements

1. Define a single embedded Creative model policy contract:
   - available model pool = current user’s `new-api` `/creative/api/models` result;
   - default/recommended/pinned/recent policy = safe Creative model preference/policy constrained to that available pool;
   - channel selection = backend only.
2. Update OpenTU embedded model consumers so model lists/defaults/fallbacks across settings, AI input dock/dropdowns, ChatDrawer, benchmark/workbench, workflow/tool windows, generation services, and MCP tools resolve through the managed Creative model policy instead of static defaults.
3. Any persisted/default model that is no longer available must be invalidated or replaced by a valid model of the same modality from the current pool.
4. Empty pool behavior must be explicit and fail closed:
   - show `New API Creative` with no selectable models;
   - do not fall back to OpenTU static defaults;
   - submit/generate actions should block with a clear local message before relay/provider calls.
5. `new-api` must expose enough safe metadata for OpenTU to classify/display models by modality/vendor/owner without exposing channel ids, keys, base URLs, or sensitive routing internals.
6. Admin/operator documentation must explain how to make models available:
   - configure channel models;
   - bind channel groups;
   - enable channel/abilities;
   - optionally create logical model names/mappings for upstream-distinct behavior;
   - set Creative default policy if implemented in scope.
7. Regression tests must cover representative model consumers and guarantee no embedded fallback to static OpenTU defaults.

## Out of Scope Unless Separately Approved

- Letting browser/OpenTU users choose raw `new-api` channel ids.
- Exposing provider API keys/base URLs/channel internals to OpenTU.
- Changing standalone OpenTU provider behavior outside embedded `/creative/`.
- Creating real provider tasks or consuming provider quota.
- Production deployment beyond local/staging verification.

## Acceptance Criteria

- [ ] The task documents the final model ownership/routing contract in Trellis specs.
- [ ] Embedded `/creative/` model settings and all primary model selectors consume only the managed `new-api-creative` catalog/policy.
- [ ] ChatDrawer, dock/AI input, benchmark/tool/workflow surfaces no longer show static OpenTU defaults in embedded mode when those models are absent from `/creative/api/models`.
- [ ] Generation paths fail closed before relay/provider calls if no valid model exists for the requested modality.
- [ ] A stale persisted/default model is reconciled to an available model or marked unavailable; it is not submitted silently.
- [ ] Multiple channels for the same model remain deduped as one logical model in OpenTU; backend routing still selects the channel.
- [ ] Tests prove static-only models are not selectable/executable in embedded mode.
- [ ] Build/typecheck/unit tests and embedded smoke pass after dist sync/rebuild.

## Planning Decision Status

- Resolved: default/recommended model policy is a `new-api` administrator-managed Creative policy with global defaults and per-user-group overrides, then per-user OpenTU preferences are applied only as safe overrides constrained by the current catalog.
- Remaining before implementation: review `design.md` and `implement.md`, then explicitly approve `task.py start`.
