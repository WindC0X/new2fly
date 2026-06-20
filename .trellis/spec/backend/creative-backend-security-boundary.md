# Creative Backend Security Boundary Contract

## Scenario: embedded Creative route, cache, origin, DTO, and proxy hardening

### 1. Scope / Trigger

- Trigger: changing any `new-api` route/middleware/controller/service code used by embedded Opentu Creative surfaces under `/creative/api/*` or `/creative/relay/v1/*`.
- This is cross-layer/security work: route availability, browser-session auth, no-store caching, owner-scoped DTOs, forbidden relay material, same-origin calculation, and outbound proxy clients are part of one boundary.
- Applies across Creative video, Suno, MJ, asset sync, and future Creative relay providers.

### 2. Signatures

- Route registration:
  - `SetCreativeRouter(router *gin.Engine)` registers `/creative/api/*` and `/creative/relay/v1/*` independently of static web serving.
  - `SetRouter` must register Creative API/relay even when `FRONTEND_BASE_URL` is configured for non-Creative SPA fallback.
- Global web rate limiting:
  - `GlobalWebRateLimit` may bypass normal static/app-shell reads such as `GET`/`HEAD /creative`, `/creative/`, `/creative/*` static assets, service worker, metadata, and frontend app routes.
  - It must not bypass `/creative/api`, `/creative/api/*`, `/creative/relay`, or `/creative/relay/*`; those API/relay paths still fail closed and set private no-store cache headers on errors.
  - Narrow high-frequency embedded operational routes may bypass only the IP-level global web limiter when they remain protected by Creative session/origin/nonce/owner-scope controls. Current allowed cases are image task `GET`/`HEAD` status/content polling, document autosave `PUT /creative/api/documents/:id`, and model preference `PATCH /creative/api/preferences/model`. Do not blanket-exempt Creative API/relay; mutating provider submit routes still need their own protective limits and billing/idempotency gates.
- Origin helpers:
  - Creative same-origin checks derive expected origin from `Request.URL.Scheme`/TLS and `Request.Host` by default.
  - Raw `X-Forwarded-Proto` / `X-Forwarded-Host` are not trusted unless a future trusted-proxy gate is explicitly implemented and tested.
  - `/creative/api` safe reads may allow originless browser navigation/bootstrap, but explicit cross-site `Origin`/`Referer` signals are rejected; `/creative/relay/v1` safe reads require same-origin.
- HTTP client helpers:
  - Empty proxy path uses a managed `*http.Client` with `CheckRedirect`, never `http.DefaultClient` as an unchecked fallback.
  - Cross-host redirect policy strips sensitive headers before following.

### 3. Contracts

- `FRONTEND_BASE_URL` only controls non-Creative fallback. Creative API/relay paths must never redirect to the external frontend host.
- Matched, unmatched, wrong-method, and trailing-slash Creative API/relay paths must fail closed with controlled API/relay responses and `Cache-Control: private, no-store`.
- Creative static/app-shell assets must not be made unavailable by the global web rate limiter during normal browser boot/chunk loading. API/relay endpoints remain protected by API/session/nonce/origin controls and must not be blanket-exempted together with static paths.
- Embedded image generation polling and document autosave must not exhaust the shared IP-level web limiter during normal use; otherwise a successful provider task can appear as `creative image task fetch failed: 429` or a later submit can fail before reaching the Creative relay guards.
- Global web cache middleware must skip or be overridden for Creative API/relay; no API/relay error may inherit long-lived static web cache such as `max-age=604800`.
- Browser relay requests must not provide upstream credentials or routing authority in headers, query, JSON body, form fields, or multipart file part names.
- Forbidden aliases include API keys/secrets, MJ API secret variants, upstream/base URL/provider/channel/group/model overrides, notify/callback/webhook variants, and owner/user override variants. Route-specific guards may allow only the documented generic top-level `model`; Suno/MJ submit derive model server-side.
- Channel `pass_headers`, wildcard passthrough, and `{client_header:*}` placeholders must not forward browser credentials or Creative control headers (`Cookie`, `Authorization`, `X-Creative-*`, API-key/secret variants, upstream key variants, etc.) to upstream providers.
- Creative task list/fetch endpoints must cap and normalize client-provided `ids` before database lookup; oversized lists, empty IDs, overlong IDs, and nested/object IDs fail before `GetByTaskIds`.
- Public Creative fetch DTOs must be route-specific and owner-scoped. They must not leak generic task internals such as `user_id`, `channel_id`, `quota`, raw private result URLs, upstream ids, or selected keys.
- Outbound proxy/content clients must preserve SSRF redirect validation and strip sensitive headers on cross-host redirects. Fallbacks must not silently downgrade to unchecked `http.DefaultClient`.
- Provider/private URLs and provider response bodies must be redacted/truncated before application logs. Stored task data may keep sanitized status payloads, but logs must not print signed URLs, base64 payloads, API keys, selected keys, cookies, or bearer material.
- Embedded Opentu release artifacts are produced by the frontend contract in `../frontend/creative-embedded-release-artifact.md`: use `VITE_BASE_URL=/creative/`, sync the same `dist/apps/web/` bytes into both `new-api` Creative dist trees, and keep `/creative/assets/*` entry refs intact.

### 4. Validation & Error Matrix

- `/creative/api/*` or `/creative/relay/v1/*` under `FRONTEND_BASE_URL` -> route normally or return controlled fail-closed JSON; never `301/307` to frontend.
- Repeated `GET`/`HEAD` requests for `/creative/`, `/creative/sw.js`, `/creative/version.json`, and existing `/creative/assets/*` -> no global-web-rate-limit `429` during ordinary app bootstrap.
- Repeated requests to `/creative/api/*` or `/creative/relay/*` -> still subject to protective API/session/rate-limit boundaries and return private no-store errors when rejected.
- Creative unmatched/wrong-method/trailing-slash route -> `404`/auth error before external redirect; `private, no-store` cache headers.
- Missing browser session -> `401/403` non-leaky response, still no-store.
- Raw forwarded-host spoof -> expected origin remains request host; cross-origin request fails.
- Explicit cross-site `Origin`/`Referer` on `/creative/api` safe reads -> `403`; originless same-session safe reads remain allowed for bootstrap/navigation compatibility.
- Forbidden relay header/query/body/form/file key -> `400` before session-broker distribution/upstream relay.
- Sensitive browser header passthrough (`Cookie`, `Authorization`, `X-Creative-CSRF`, `X-Creative-Nonce`, API-key variants) -> silently dropped from upstream header overrides.
- Creative Suno/MJ list with too many/overlong/nested `ids` -> `400` without DB fan-out.
- Same-user task fetched through wrong platform endpoint -> non-leaky not-found, not generic DTO serialization.
- Cross-host redirect with `Authorization`, API-key/API-secret/MJ-secret, proxy auth, or cookie-like headers -> header stripped before follow.
- Redirect to blocked/private target -> blocked by SSRF policy; private target not fetched.

### 5. Good/Base/Bad Cases

- Good: `FRONTEND_BASE_URL=https://frontend.example`, `GET /creative/api/bootstrap` returns local Creative auth JSON error with no `Location`, and `/not-creative` redirects to frontend.
- Base: generic image relay accepts top-level `model` but rejects `X-Notify`, `ownerId`, `mj-api-secret`, `callback` file part, or nested `headers.Authorization` before relay.
- Bad: `GET /creative/api/bootstrap/` produces Gin redirect without no-store; Suno fetch returns `channel_id`/`quota`; MJ image proxy falls back to `http.DefaultClient` and follows a redirect to `127.0.0.1`.

### 6. Tests Required

- Router tests for `FRONTEND_BASE_URL` mode covering matched Creative API/relay, missing paths, wrong methods, and trailing-slash variants: assert no frontend `Location` and no-store.
- Embedded artifact tests must assert `web/creative/dist` and `router/web/creative/dist` match each other and that `index.html` references entry JS/CSS under `/creative/assets/`.
- Middleware/controller origin tests proving untrusted `X-Forwarded-*` does not change expected Creative origin.
- Controller relay tests for forbidden aliases across header/query/JSON/form/multipart value keys and multipart file part names, while preserving documented top-level `model` where allowed.
- Relay/channel tests for sensitive header skipping in wildcard passthrough, `pass_headers`, and `{client_header:*}` placeholders.
- Service/controller/relay tests for Creative task-id list caps/normalization before `GetByTaskIds`.
- Platform/DTO tests: same-user non-Suno task via Suno fetch is rejected; same-user Suno fetch response omits task internals and private URLs.
- HTTP client tests: empty proxy fallback has `CheckRedirect` and is not `http.DefaultClient`; cross-host redirects strip sensitive/cookie-like headers.
- Proxy/content tests: MJ image/content fallback clients block unsafe redirects and do not fetch blocked private targets; video proxy and polling logs redact private URL/body material.

### 7. Wrong vs Correct

#### Wrong

```text
FRONTEND_BASE_URL set -> /creative/api/bootstrap 301 https://frontend.example/creative/api/bootstrap
Suno fetch -> TaskModel2Dto with user_id/channel_id/quota/result_url
Redirect -> keep Authorization and X-Api-Key on cross-host Location
Expected origin -> trust X-Forwarded-Host from the browser
```

#### Correct

```text
FRONTEND_BASE_URL set -> /creative/api/bootstrap handled locally with private,no-store
Suno fetch -> platform==suno + owner scope + route-specific sanitized DTO
Redirect -> strip sensitive/cookie-like headers and validate target with SSRF policy
Expected origin -> use request host unless a trusted-proxy gate says otherwise
```

## Scenario: Creative model policy and embedded model catalog contract

### 1. Scope / Trigger

- Trigger: changing `new-api` Creative model availability, bootstrap payloads, model preferences, admin settings, or any code that influences what embedded OpenTU can select under `/creative/`.
- This is a cross-layer/security boundary: `new-api` owns channels, abilities, groups, routing, and default/recommended policy; embedded OpenTU receives only safe logical model IDs and must not receive raw channel or provider authority.
- Applies to `controller/creative.go`, `controller/creative_model_policy.go`, `service/creative_model_policy.go`, `model/option.go`, `controller/option.go`, admin settings UI, and `/creative/api/models` consumers.

### 2. Signatures

- Stored option key:
  - `service.CreativeModelPolicyOptionKey == "creative.model_policy"`
  - default stored value in `model/option.go`: `{"version":1}`
- Policy types:
  - `CreativeModelPolicy{version, global, groups}`
  - `CreativeModelPolicyRule{defaults, recommended}`
  - allowed modalities: `text`, `agent`, `image`, `video`, `audio`
- Public session endpoints:
  - `GET /creative/api/models` returns the current user's logical model catalog; model IDs are deduped by `service.GetUserCreativeModelPool(user.Group)` / ability data.
  - `GET /creative/api/bootstrap` returns existing auth/session data plus `modelPolicy` and `modelPolicyVersion`.
- Admin endpoints:
  - `GET /api/creative/model-policy` returns `CreativeModelPolicyAdminState`.
  - `PUT /api/creative/model-policy` accepts either a policy object or `{ "policy": <object> }` / `{ "value": <object> }`, normalizes, persists, and returns the refreshed admin state.
- Service helpers:
  - `NormalizeCreativeModelPolicyJSON(raw string)`
  - `NormalizeCreativeModelPolicyValue(value any)`
  - `BuildEffectiveCreativeModelPolicy(policy, group, availableModels)`
  - `BuildCreativeModelPolicyAdminState(policy)`
  - `CleanCreativeModelPolicy(policy, poolsByGroup)`

### 3. Contracts

- `creative.model_policy` is safe policy metadata, not a provider/channel configuration blob.
- The only accepted top-level policy fields are `version`, `global`, and `groups`; nested rules only accept `defaults` and `recommended` maps keyed by allowed modality.
- Model IDs are strings, trimmed, deduplicated in list order, and filtered against the current effective model pool before bootstrap returns them as defaults/recommended entries.
- Group policy selection uses the logged-in user's primary `User.Group` for override rules; availability still comes from `service.GetUserCreativeModelPool(user.Group)`, including the project's usable-group union behavior.
- Bootstrap `modelPolicy` is already effective for the current browser session. OpenTU may use `stale` diagnostics for display/debugging only; stale entries are never executable defaults.
- `modelPolicyVersion` must be derived from the effective filtered policy, not from raw stored JSON alone.
- Generic `/api/option` updates must reject or bypass direct mutation of `creative.model_policy`; use the dedicated admin endpoint so validation, unsafe-key checks, model-pool diagnostics, and normalized JSON are always applied.
- Policy payloads must reject unsafe key material and routing/control fields at any depth, including API keys/secrets, base/upstream/provider/channel/group overrides, owner/user overrides, and notify/callback/webhook variants.
- Admin UI may expose an expert JSON editor, but save/read flows go through `/api/creative/model-policy` and show model-pool/stale diagnostics based on channel abilities.

### 4. Validation & Error Matrix

- Empty option / empty request body policy -> normalized `{"version":1}`; effective bootstrap policy has no defaults/recommended and no static fallback authority.
- Unsupported `version` -> `400` from `PUT /api/creative/model-policy`.
- Unknown top-level or nested non-policy fields -> dropped if harmless; forbidden security/control keys -> `400`.
- Default model not in the current user's available pool -> omitted from effective `defaults` and recorded under `stale.defaults`.
- Recommended list entries not in the current user's pool -> omitted from effective `recommended` and recorded under `stale.recommended`; valid entries preserve order and dedupe.
- Group override exists for user's group -> override values win for that modality, then are filtered; other modalities may continue to use global policy.
- Multiple enabled channels expose the same logical model -> `/creative/api/models` returns one logical model; backend routing still selects the concrete channel during relay.
- Direct generic option update for `creative.model_policy` -> rejected or ignored with a controlled error; policy must not be stored unnormalized.
- Admin state with stale saved IDs -> returns diagnostics and `cleanedPolicyJSON` suitable for one-click cleanup, without granting stale IDs to the browser session.

### 5. Good/Base/Bad Cases

- Good: admin saves `{"version":1,"global":{"defaults":{"image":"gpt-image-1"}}}` through `PUT /api/creative/model-policy`; a default-group user whose enabled abilities include `gpt-image-1` receives bootstrap `modelPolicy.defaults.image == "gpt-image-1"`.
- Base: a VIP override sets `text: "vip-gpt"`; default users continue to get the global text default, while VIP users get `vip-gpt` only if it is in their effective pool.
- Bad: `creative.model_policy` is edited through `/api/option` with `{ "channelId": 12, "baseURL": "...", "apiKey": "..." }` and later appears in bootstrap or OpenTU settings.
- Bad: stored global recommended contains `removed-video-model`; bootstrap includes it in `recommended.video` even though `/creative/api/models` no longer lists it.

### 6. Tests Required

- Service tests for empty policy, trim/dedupe, version validation, modality validation, group override merge, stale filtering, `modelPolicyVersion`, unsafe-field rejection, and cleaned-policy diagnostics.
- Controller tests for `GET /creative/api/bootstrap` proving effective policy is filtered to the current user pool and no channel/base URL/key fields leak.
- Admin endpoint tests for `GET`/`PUT /api/creative/model-policy`, including stale diagnostics and normalized JSON persistence.
- Generic option endpoint tests proving `creative.model_policy` cannot be directly changed without the dedicated validator.
- Ability/channel tests or fixtures proving duplicate logical models across channels remain deduped for OpenTU while backend channel selection remains server-side.
- Admin UI type/API tests proving the UI client uses `/api/creative/model-policy` rather than raw `/api/option` for this key.

### 7. Wrong vs Correct

#### Wrong

```text
Browser bootstrap -> modelPolicy copied from raw option JSON, including stale model IDs and channel/provider fields
Admin save -> POST /api/option { key: "creative.model_policy", value: arbitrary JSON string }
OpenTU selector -> user can choose channel id / provider profile / base URL
```

#### Correct

```text
Browser bootstrap -> modelPolicy built by BuildEffectiveCreativeModelPolicy(policy, user.Group, availableModelIDs)
Admin save -> PUT /api/creative/model-policy -> NormalizeCreativeModelPolicyValue -> UpdateStoredCreativeModelPolicy
OpenTU selector -> one logical model ID from /creative/api/models; channel routing stays in new-api
```


## Scenario: Creative adapter binding config parser and forbidden normalizer

### 1. Scope / Trigger

- Trigger: changing backend-owned Creative adapter binding configuration, admin binding APIs, binding dry-run, runtime parameter schemas, or relay forbidden-field guards.
- Applies to `service/creative_model_capability.go`, `controller/option.go`, future `controller/creative_model_bindings.go`, and any path that reads or writes `creative.model_bindings`.

### 2. Signatures

- Stored option key: `service.CreativeModelBindingsOptionKey == "creative.model_bindings"`.
- Parser: `ParseCreativeModelBindingsConfig(raw string) (CreativeModelBindingsConfig, error)`.
- Validator: `ValidateCreativeModelBindingsConfig(config CreativeModelBindingsConfig) error`.
- Shared forbidden normalizer:
  - `NormalizeCreativeForbiddenKey(key string) string`
  - `CreativeForbiddenKey(key string) bool`
- Config shape: `CreativeModelBindingsConfig{version, bindings[]}` where each binding has `id`, `providerModelId`, `priceModelId`, `modality`, `enabled`, optional `canaryGroups`, `channelId`, `adapterPreset`, `parameterTemplate`, ranking fields, and `parameterSchema`.
- Admin endpoints:
  - `GET /api/creative/model-bindings` returns normalized admin state.
  - `PUT /api/creative/model-bindings` validates, normalizes, persists, and emits a sanitized audit log.
  - `POST /api/creative/model-bindings/validate` validates without persisting.
  - `POST /api/creative/model-bindings/dry-run` validates and returns a redacted mock/fixture preview without provider transport.
- Public catalog helper:
  - `GetStoredCreativeModelBindingsCatalogForGroup(userGroup string) []dto.CreativeModelCatalogItem` exposes enabled, canary-matched, mock-safe stored bindings to `/creative/api/models`.

### 3. Contracts

- `creative.model_bindings` is a privileged backend config; generic `/api/option` must reject direct writes to this key.
- Binding config JSON is versioned; only version `1` is accepted until a migration path exists.
- Dedicated admin writes must persist canonical JSON, not merely validate and echo raw input. Trim and normalize binding/schema fields such as ids, modality, presets/templates, canary groups, and schema type before storage and dry-run.
- Raw binding config parsing must fail closed on unknown keys and forbidden admin/config keys before struct unmarshalling can silently drop them.
- `binding.id`, `providerModelId`, and `priceModelId` are separate fields. Tests should include distinct values.
- The same forbidden-key normalizer must be used for binding IDs, parameter schema IDs, hidden/admin fields, relay body/query/form/multipart checks, and dry-run previews as those paths are wired.
- The parser/validator must not contact provider endpoints; dry-run and fixture phases remain no-provider-call.
- Dedicated admin binding endpoints require root dashboard session. API-token-only access is rejected by the handler, and unsafe methods (`PUT`, `POST validate`, `POST dry-run`) must also pass same-origin + Creative CSRF/nonce middleware.
- Admin UI saves for `creative.model_bindings` must be gated by both `POST /api/creative/model-bindings/validate` and `POST /api/creative/model-bindings/dry-run` for the same exact editor draft, with `dryRun.noProviderCall == true`, before enabling or executing `PUT /api/creative/model-bindings`. Async validate/dry-run responses must carry the submitted draft string or hash and must be ignored if the editor has changed before the response returns.
- Admin PUT audit logs must be sanitized: log actor and counts/status only, never raw binding JSON, provider URLs, keys, headers, signed URLs, object keys, CSRF/nonce, cookies, or raw provider response bodies.
- Phase-B dry-run previews are diagnostic only. They may show binding/provider/price ids and sanitized request shape, but must redact dangerous keys and sensitive string values (provider URLs, signed URL markers, bearer/sk-like material, data/base64-like payloads, credentials, access-key markers, token markers) and must not read channel secrets or perform real provider calls.
- Public `/creative/api/models` must include stored enabled mock-safe bindings only when the global adapter flag is enabled and the user's group matches `canaryGroups`. Disabled bindings, wrong-group bindings, non-image bindings, and non-mock/real-provider presets remain hidden from the browser catalog. Hidden schema fields are filtered from catalog responses and still rejected if submitted as `userParams`.
- Stored binding catalog entries preserve `binding.id` as the executable model id and preserve distinct `providerModelId` / `priceModelId`; duplicate IDs from legacy/built-in preview sources are deduped before returning `/creative/api/models`.

### 4. Validation & Error Matrix

- Empty raw config -> `version=1` with no bindings.
- Unsupported version -> error.
- Duplicate binding IDs, case-insensitive -> error.
- Forbidden binding/schema ID such as `callback`, `notifyHook`, `headers.Authorization`, `ownerId`, `baseURL`, or `idempotencyKey` -> error.
- Missing `providerModelId`, `priceModelId`, or `modality` -> error.
- Sensitive `providerModelId` / `priceModelId` / schema default / schema option / display text values such as URLs, signed query material, bearer/sk-like secrets, data/base64-like payloads, credentials, access-key markers, or token markers -> error.
- Raw JSON with unknown or forbidden admin keys such as `baseURL`, `headers`, `Authorization`, `callback`, `webhook`, or `notify` -> error before persistence.
- `null` root, `bindings:null`, `parameterSchema:null`, or `options:null` -> error; arrays must be explicit arrays.
- Direct `PUT /api/option/` for `creative.model_bindings` -> controlled error pointing to `/api/creative/model-bindings`.
- Stored binding disabled, global adapter disabled, wrong canary group, unsupported preset/template, or hidden schema field -> binding omitted from `/creative/api/models`; submit still fails closed if attempted directly.
- API-token-only request to `/api/creative/model-bindings*` -> `403` dashboard-session-required response.
- Non-root dashboard user -> denied by `RootAuth`.
- Missing/bad Creative CSRF/nonce on unsafe admin binding endpoints -> `403` before validation/persistence/dry-run.
- Admin dry-run preview containing `Authorization`, `baseURL`, callback/webhook/notifyHook, API-key, or signed URL material -> redacted before response/logging.
- Admin UI editor changes after validate/dry-run has started but before the response returns -> stale response is ignored and cannot mark the new draft as save-ready.
- Admin UI save clicked before current draft has both validate success and dry-run `noProviderCall=true` -> local error, no `PUT /api/creative/model-bindings`.

### 5. Good/Base/Bad Cases

- Good: parse disabled mock binding with `id=mock:gpt-image-2:preview`, `providerModelId=gpt-image-2`, and `priceModelId=mock-gpt-image-2-price`; no provider call occurs.
- Good: `POST /api/creative/model-bindings/dry-run` for a mock binding returns `noProviderCall=true` and `transport=mock` without channel key/base URL material.
- Good: admin edits the JSON, validates that exact draft, dry-runs that exact draft, sees `noProviderCall=true`, then `PUT /api/creative/model-bindings` is enabled.
- Base: empty option during startup parses as empty v1 config.
- Bad: administrator writes arbitrary `creative.model_bindings` JSON through `/api/option`, bypassing schema/forbidden validation and dry-run redaction.
- Bad: dry-run contacts Duomi/GrsAI or emits raw `Authorization`, `baseURL`, signed object URL query, cookie, CSRF, nonce, or raw provider body.
- Bad: admin validates draft A, edits the textarea to draft B while the request is pending, and draft A's late response marks draft B as save-ready.

### 6. Tests Required

- Service parser tests for valid v1 config, unsupported version, duplicate IDs, forbidden IDs, required fields, and nested parameter schema validation.
- Shared normalizer tests covering camelCase, snake_case, kebab-case, dotted headers, and whitespace variants.
- Controller tests proving generic `/api/option` rejects `creative.model_bindings`.
- Admin endpoint tests must reuse the same parser/normalizer and cover root/dashboard auth, API-token-only rejection, same-origin/nonce failures on unsafe methods, redaction, no-provider-call dry-run, normalized persistence, and sanitized audit assertions.
- Catalog tests must prove stored enabled mock bindings appear for matching groups, disabled/global-off/wrong-group bindings are hidden, hidden schema fields are filtered, and duplicate built-in/stored binding IDs appear only once.
- Admin UI type/component tests should prove the client uses dedicated `/api/creative/model-bindings*` endpoints, attaches Creative nonce headers to validate/dry-run/PUT, never writes this key through `/api/option`, disables save until the current exact draft has validate success and dry-run `noProviderCall=true`, clears the gate on edits/reload/template/format changes, and ignores stale async validate/dry-run responses for older drafts.

### 7. Wrong vs Correct

#### Wrong

```text
PUT /api/option/ { key: "creative.model_bindings", value: "..." } -> stored
POST /api/creative/model-bindings/dry-run -> real provider HTTP request to prove it works
```

#### Correct

```text
PUT /api/option/ { key: "creative.model_bindings", value: "..." } -> rejected
POST /api/creative/model-bindings/validate -> ParseCreativeModelBindingsConfig -> no provider call
POST /api/creative/model-bindings/dry-run -> validate -> redacted mock/fixture preview, no provider call
Admin UI save -> only after same-draft validate + dry-run(noProviderCall=true) -> PUT dedicated endpoint
```

## Scenario: Creative mock image task route contract

### 1. Scope / Trigger

- Trigger: changing `new-api` Creative managed image task routes, binding resolution, task DTOs, image content proxying, or sync image relay behavior for backend-owned adapter bindings.
- Applies to `controller/creative_image_tasks.go`, `router/web-router.go`, `service/creative_model_capability.go`, `constant/task.go`, and related controller/service tests.

### 2. Signatures

- Task platform: `constant.TaskPlatformCreativeImage == "creative_image"`.
- Mock image task routes:
  - `POST /creative/relay/v1/images/tasks`
  - `GET /creative/relay/v1/images/tasks/:task_id`
  - `GET /creative/relay/v1/images/tasks/:task_id/content`
- Sync route privacy gate:
  - `POST /creative/relay/v1/images/generations` must reject managed image binding IDs before session broker, distribution, channel selection, or provider relay.
- Resolver:
  - `ResolveCreativeImageModelBindingForGroup(bindingID, userGroup, userParams)`.
  - `ValidateCreativeUserParamsForSchema(schema, userParams)`.

### 3. Contracts

- Phase C1 image tasks are mock-only. The task submit/fetch/content routes must not call `CreativeRelaySessionBroker`, `Distribute`, channel selection, provider adaptors, provider HTTP clients, or read channel keys/base URLs.
- Submit requires browser-session relay gates inherited from `/creative/relay/v1`: session header bridge, `UserAuth`, same-origin, nonce, and forbidden relay-field guard. API-token-only handlers must reject with a browser-session error.
- Submit also requires a scoped idempotency key. The scope for managed image tasks is `image.task.submit`, separate from video/Suno/MJ scopes.
- Resolver fails closed unless all are true:
  - global `creative.adapter.enabled` is true;
  - binding exists in `creative.model_bindings`;
  - binding is enabled;
  - modality is `image`;
  - preset/template are the current mock allowlist (`mock_image_task` / `mock_gpt_image`);
  - user's group matches `canaryGroups` (or `*`);
  - all submitted `userParams` are visible schema fields with typed values.
- `userParams` must reject hidden schema fields, unsupported fields, forbidden/control keys, sensitive string values, wrong scalar types, enum values outside options, and numeric values outside min/max.
- The created mock task may store internal private data such as `UpstreamTaskID` and `PrivateData.ResultURL`, but public responses must use a route-specific DTO and must not serialize generic task internals (`user_id`, `channel_id`/`channelId`, `quota`, `private_data`), raw provider/mock URLs, signed query material, selected keys, channel keys, or base URLs.
- Fetch/content must load by logged-in `user_id + task_id`, then require `Platform == creative_image` and `creativeManaged == true` metadata before returning a result. Same-user tasks from other platforms must look like not-found.
- Public result URLs point only to `/creative/relay/v1/images/tasks/:task_id/content`; content responses are owner-scoped and `Cache-Control: private, no-store`.
- If mock/provider acceptance has been marked and local persistence fails, the idempotency guard must not be deleted. A retry must not create a second upstream/mock accepted task.
- Until sync response interception and private URL rewriting exists, managed image adapter bindings must be forced to the task route and rejected on `/images/generations` before broker/distribute/provider relay.

### 4. Validation & Error Matrix

- Missing/empty `Idempotency-Key` on `POST /images/tasks` -> `400`, no mock task.
- Same idempotency key + same payload after successful task insert -> return the existing public task DTO, no second mock/provider call.
- Same idempotency key + different payload -> `409`, no second mock/provider call.
- Adapter disabled, binding disabled, wrong group, wrong modality, or non-mock preset/template -> controlled `400`, no mock/provider call.
- `userParams.callback`, hidden schema field, unsupported field, wrong type, or sensitive string value -> controlled `400`, no mock/provider call.
- Cross-user fetch/content or same-user wrong-platform task -> non-leaky not-found.
- Managed binding submitted to `/creative/relay/v1/images/generations` -> controlled `400` before broker/distribute; no raw provider URL can reach the browser on that path.
- Accepted + local insert failure -> `500`/controlled error while retaining the idempotency record.

### 5. Good/Base/Bad Cases

- Good: browser submits `model=mock:gpt-image-2:preview`, typed `userParams`, same-origin nonce, and `Idempotency-Key`; backend creates a local `creative_image` mock task and returns a private DTO with `/content` URL only.
- Base: replay of the same idempotency key and payload returns the same task id without a second local mock acceptance.
- Bad: image task route enters `Distribute()` and reads a channel key; public DTO includes `channel_id`, `quota`, `<private mock URL with signed-query marker>`, or `PrivateData`; sync `/images/generations` accepts a managed binding and streams raw provider URLs to the browser.

### 6. Tests Required

- Controller route tests for submit/fetch/replay/content privacy and no-store headers.
- Controller boundary tests for API-token-only, cross-origin, missing/bad nonce, missing idempotency key, and forbidden JSON/control fields before mock/provider work.
- Service tests for resolver fail-closed behavior, group/canary filtering, mock-only preset/template enforcement, and typed/hidden/forbidden `userParams` validation.
- Sync route test proving managed image binding is rejected before `CreativeRelaySessionBroker` / `Distribute` / provider relay.
- Owner/platform-scope tests proving cross-user and wrong-platform task fetches return not-found and do not leak private URLs.
- Idempotency/recovery tests proving accepted+local-failure keeps the guard; future provider-backed phases must also test idempotency-complete failure, settle failure, and durable outbox/recovery rows.

### 7. Wrong vs Correct

#### Wrong

```text
POST /creative/relay/v1/images/tasks -> CreativeRelaySessionBroker -> Distribute -> provider adaptor
GET /creative/relay/v1/images/tasks/:id -> generic Task JSON with user_id/channel_id/quota/private_data
POST /creative/relay/v1/images/generations with model=mock:gpt-image-2:preview -> provider relay returns raw URL
```

#### Correct

```text
POST /creative/relay/v1/images/tasks -> resolver -> local mock Task(platform=creative_image) -> private DTO
GET /creative/relay/v1/images/tasks/:id -> owner + platform + creativeManaged check -> allowlisted DTO
POST /creative/relay/v1/images/generations with managed binding -> 400 before broker/distribute/provider relay
```

## Scenario: Creative live image provider adapter contract

### 1. Scope / Trigger

- Trigger: enabling a `creative.model_bindings` image binding whose `adapterPreset` performs real provider transport instead of the local mock task path.
- Applies to `service/creative_image_adapter.go`, `service/creative_model_capability.go`, `controller/creative_image_tasks.go`, `model/task.go`, `service/task_billing.go`, `/api/creative/model-bindings*`, `/creative/api/models`, and `/creative/relay/v1/images/tasks*`.
- This is a cross-layer/provider/security contract: admin config, channel credentials, user-visible parameter schema, provider request mapping, polling, billing, idempotency, and result-content privacy must remain consistent.

### 2. Signatures

- Live adapter presets:
  - `duomi_image_live`
  - `grsai_image_live`
- Provider adapter API:
  - `SubmitCreativeImageProviderTask(ctx, CreativeImageProviderRequest) (CreativeImageProviderResult, error)`
  - `FetchCreativeImageProviderTask(ctx, CreativeImageProviderFetchRequest) (CreativeImageProviderResult, error)`
- Binding fields required for live presets:
  - `channelId > 0`
  - `adapterPreset` is a known live preset
  - `parameterTemplate` is a known template for that preset/model family
  - `providerModelId` is listed by the selected enabled channel
  - `parameterSchema` has at least one visible allowlisted field
- Supported live provider mappings:
  - Duomi submit: `POST <BaseURL>/v1/images/generations?async=true`, auth header `Authorization: <channel key>`
  - Duomi poll: `GET <BaseURL>/v1/tasks/{upstreamTaskID}`
  - GrsAI submit: `POST <BaseURL>/v1/api/generate`, auth header `Authorization: Bearer <channel key>`, backend-forced `replyType: "async"`
  - GrsAI poll: `GET <BaseURL>/v1/api/result?id={upstreamTaskID}`

### 3. Contracts

- Live provider keys and base URLs come only from the selected `new-api` channel. The browser and OpenTU never submit, select, or receive provider credentials/base URLs/channel routing authority.
- Readiness/validation for a live binding must require all of: global Creative adapter enabled, selected channel exists, channel is enabled, channel has an explicit non-empty `BaseURL`, channel has at least one available key, channel model list contains `providerModelId`, canary group is valid, and schema/template are allowlisted.
- Catalog/admin readiness checks must not call `GetNextEnabledKey()` or otherwise advance multi-key polling state. Key selection is submit-time only.
- Stored config reads for admin state may tolerate runtime channel drift so the admin UI can load and repair stale config. Save/validate/runtime resolution remain strict and fail closed.
- Submit selects exactly one channel key and stores selected-key affinity in `Task.PrivateData.Key`. Polling must reuse that key and must not rotate to another key.
- Submit stores the provider endpoint snapshot in `Task.PrivateData.ProviderEndpoint`. Polling must fail closed and refund if the current channel base URL no longer matches the stored snapshot.
- Submit must create the task row and submit-billing/outbox bookkeeping in one DB transaction after provider acceptance. If provider accepted but local persistence/finalize fails, refund pre-consumption and retain the idempotency guard so retries do not create duplicate provider tasks.
- Terminal poll/reconcile must use compare-and-swap task status updates with durable billing/refund outbox behavior. A terminal CAS loser reloads the stored task and returns the sanitized current DTO.
- Public DTOs for submit/fetch must not expose selected key, upstream task id, raw provider result URL, channel id, quota, base URL, provider endpoint, or `private_data`. The browser receives only local `/creative/relay/v1/images/tasks/:task_id/content` result URLs.
- Result content for live tasks is fetched server-side from `Task.PrivateData.ResultURL` through the managed safe HTTP client and `ValidateURLWithFetchSetting`. Allowed content types are image raster types only: png, jpeg/jpg, webp, gif, avif. SVG and HTML/XML/script-like content must be rejected even if the provider reports success.
- User-submitted `userParams` are allowlisted by `parameterSchema` and provider template. Hidden fields, unknown fields, forbidden keys, sensitive values, and provider-control fields such as `replyType`, callback/webhook/notify, owner/user, base URL, key/header overrides, or channel/group overrides must never enter provider requests.
- Live catalog entries should be tagged with provider/live family tags and must not include `mock`; mock preview bindings stay explicitly mock-only.

### 4. Validation & Error Matrix

- Live binding with missing/disabled channel, empty `BaseURL`, no available key, unsupported `providerModelId`, invalid canary group, unknown preset/template, or empty visible schema -> validate/save/runtime resolution fails closed.
- Catalog/admin validation path advances channel key index -> fail test; readiness must be side-effect free.
- Existing stored config references a deleted/disabled channel -> admin GET still returns repairable state; validate/save/submit fail closed until repaired.
- Submit accepted by provider but local insert/finalize fails -> refund pre-consumed quota, keep idempotency guard, and do not repeat provider submit on retry.
- Poll task missing `PrivateData.Key`, missing `UpstreamTaskID`, missing `ProviderEndpoint`, or endpoint mismatch with current channel -> terminal failure/refund path, no provider call with a guessed key/base URL.
- Provider reports terminal success without a result URL/content reference -> terminal failure/refund path.
- Provider result URL points to blocked/private/redirected target or returns disallowed content type such as SVG -> content endpoint rejects; raw URL is not sent to the browser.
- Duomi user param includes `callback` or GrsAI user param includes `replyType` -> rejected/ignored before provider request; backend controls provider-only fields.
- Public submit/fetch response contains `channelId`, `quota`, `upstreamTaskID`, selected key, raw result URL, or base URL -> fail privacy test.

### 5. Good/Base/Bad Cases

- Good: admin creates a disabled Duomi live draft from channel `12`, validates/dry-runs with `noProviderCall=true`, saves, enables after channel readiness passes, and users submit typed `size/quality` params through `/creative/relay/v1/images/tasks`.
- Good: GrsAI `gpt-image-2-vip` uses its own parameter template where the visible quality-like values are `1K/2K/4K`; regular GrsAI `gpt-image-2` does not inherit VIP-only values.
- Base: provider accepts a task as `pending`; submit returns a sanitized local task id and future fetch polls using the stored upstream id/key/endpoint snapshot.
- Bad: validation rotates the channel's key index; polling uses a newly selected key after the channel base URL was changed; DTO returns the provider's signed image URL directly; SVG result is proxied to the browser.

### 6. Tests Required

- Adapter mapper/parser tests for Duomi submit/poll and GrsAI submit/poll, including accepted, pending/running, success, failure, malformed success, and provider-error responses.
- Capability tests for live manifests, parameter templates, visible schema non-empty rules, provider-template/model allowlists, GrsAI VIP vs non-VIP schema separation, and live catalog tags.
- Admin binding tests for channel readiness success/failure, explicit-base-URL requirement, no available key, unsupported provider model, runtime drift tolerance on stored read, strict validate/save behavior, and no `GetNextEnabledKey()` side effects.
- Submit tests for selected-key/endpoint snapshot persistence, idempotency replay/conflict, provider accepted + local insert/finalize failure refunds, no duplicate provider calls, DTO privacy, and submit-billing outbox creation.
- Poll/fetch tests for missing key/upstream/endpoint fail-closed refund, endpoint mismatch fail-closed refund, terminal CAS loser reload, malformed terminal provider success refund, and sanitized public DTOs.
- Content tests for owner/platform scope, SSRF/redirect validation, allowed raster content types, SVG denial, and no raw result URL exposure.
- Frontend/admin type checks proving schema-backed parameter fields are displayed from `/creative/api/models` rather than hardcoded provider defaults.

### 7. Wrong vs Correct

#### Wrong

```text
GET /api/creative/model-bindings -> calls channel.GetNextEnabledKey()
POST /creative/relay/v1/images/tasks -> provider accepts -> local insert fails -> idempotency guard deleted
GET /creative/relay/v1/images/tasks/:id -> returns upstreamTaskID/channelId/result_url
Poll -> channel.GetNextEnabledKey() after admin changed BaseURL
```

#### Correct

```text
GET /api/creative/model-bindings -> side-effect-free readiness diagnostics
POST /creative/relay/v1/images/tasks -> lock key + endpoint snapshot -> provider submit -> DB transaction task + submit outbox
GET /creative/relay/v1/images/tasks/:id -> owner/platform/managed check -> sanitized local DTO
Poll -> reuse stored key and require endpoint snapshot match, else fail-closed + refund
```

## Scenario: Creative model bindings channel summary picker

### 1. Scope / Trigger

- Trigger: changing the admin UI or backend endpoints used to help configure `creative.model_bindings` channel-backed bindings.
- Applies to `controller/creative_model_bindings.go`, `service/creative_model_capability.go`, `/api/creative/channel-summaries`, system settings Creative model bindings UI, and related tests.
- This is a cross-layer security/data-minimization contract: Creative binding admin UI needs channel identity and model availability, not provider credentials or transport configuration.

### 2. Signatures

- Admin summary endpoint:
  - `GET /api/creative/channel-summaries?p=<page>&page_size=<n>&keyword=<q>&channel_id=<id>&group=<group>`
- Response DTO:
  - `CreativeChannelSummaryList{items,total,page,page_size}`
  - `CreativeChannelSummary{id,name,group,status,models[]}`
- Frontend client:
  - `getCreativeChannelSummaries(params)` in system settings API.
  - UI consumes `CreativeChannelSummary`, not the generic `Channel` DTO.

### 3. Contracts

- Creative model bindings UI must not call generic `/api/channel` or import/consume the full `Channel` DTO just to build channel-backed Creative binding drafts.
- The summary endpoint returns only `id`, `name`, `group`, `status`, and normalized `models[]` plus pagination metadata.
- Summary responses must not include channel `key`, `base_url`, provider credentials, `header_override`, `param_override`, `settings`, `other`, `other_info`, `model_mapping`, org ids, remarks, balance, quota, or selected-key material.
- The endpoint is admin-session scoped under `/api/creative/*` and inherits private/no-store cache behavior. It is a read-only helper and does not require Creative nonce, but mutating binding writes/validate/dry-run still require nonce.
- The frontend builder may use summaries for convenience only. Persisted config writes still go through model-bindings validate + dry-run + PUT gates, and backend validation remains authoritative for channel existence, enabled status, model support, canary groups, and forbidden fields.
- Generated binding IDs should be deterministic and collision-aware. If the UI derives an ID from provider model data, it must use a safe slug and include enough context such as channel id to avoid silently replacing another channel's binding.

### 4. Validation & Error Matrix

- `channel_id` / `id` query is non-positive or non-integer -> `400` controlled API error.
- Summary request for a channel containing keys/base URLs/overrides/settings -> response omits all sensitive fields; only summary fields remain.
- Empty or duplicate comma-separated `models` string -> response normalizes to a deduped `models[]` without blanks.
- UI selected channel is disabled or has no models -> draft generation is blocked before writing the JSON draft.
- UI manual provider model not in the selected channel's model list -> draft generation is blocked when summary metadata is available.
- Duplicate generated binding id -> explicit confirmation or collision avoidance before replacing an existing draft.

### 5. Good/Base/Bad Cases

- Good: admin searches `gpt-image-2`, receives `[{id: 12, name: "grs", group: "test", status: 1, models: ["gpt-image-2"]}]`, creates a disabled validation-gated draft, then runs validate/dry-run before save.
- Base: admin manually enters a channel id not currently loaded; UI labels the draft as validation-gated and backend validation rejects missing/disabled/unsupported channels.
- Bad: Creative binding UI fetches `/api/channel` and stores `base_url`, `header_override`, or `param_override` in React Query cache; UI says provider credentials are never exposed while the browser has full channel transport fields.

### 6. Tests Required

- Controller test for `/api/creative/channel-summaries` proving no-store headers and sanitized response fields.
- Service/controller fixture with a channel containing fake key, base URL, header/param overrides, settings, model mapping, org id, and remarks; assert none appear in the response body.
- Service test for model-list normalization and pagination/search behavior when practical.
- Frontend type/API check proving Creative binding UI imports `CreativeChannelSummary` and `getCreativeChannelSummaries`, not generic `Channel` / `getChannels`.
- UI/lint/typecheck coverage for disabled channel, empty model list, duplicate binding id, and provider-model mismatch behaviors when those branches are implemented in components.

### 7. Wrong vs Correct

#### Wrong

```text
Creative model bindings page -> GET /api/channel -> full Channel DTO in browser
binding id = mock-image-task:gpt-image-2:preview for every channel
manual providerModelId not in selected channel -> draft silently written as “safe”
```

#### Correct

```text
Creative model bindings page -> GET /api/creative/channel-summaries -> {id,name,group,status,models[]}
binding id = mock:gpt-image-2:ch12:preview or explicit admin-provided id with collision confirmation
manual/unknown values -> validation-gated draft copy, backend validate/dry-run remains authoritative
```
