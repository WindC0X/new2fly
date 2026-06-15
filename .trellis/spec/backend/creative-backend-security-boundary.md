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

### 3. Contracts

- `creative.model_bindings` is a privileged backend config; generic `/api/option` must reject direct writes to this key.
- Binding config JSON is versioned; only version `1` is accepted until a migration path exists.
- Dedicated admin writes must persist canonical JSON, not merely validate and echo raw input. Trim and normalize binding/schema fields such as ids, modality, presets/templates, canary groups, and schema type before storage and dry-run.
- Raw binding config parsing must fail closed on unknown keys and forbidden admin/config keys before struct unmarshalling can silently drop them.
- `binding.id`, `providerModelId`, and `priceModelId` are separate fields. Tests should include distinct values.
- The same forbidden-key normalizer must be used for binding IDs, parameter schema IDs, hidden/admin fields, relay body/query/form/multipart checks, and dry-run previews as those paths are wired.
- The parser/validator must not contact provider endpoints; dry-run and fixture phases remain no-provider-call.
- Dedicated admin binding endpoints require root dashboard session. API-token-only access is rejected by the handler, and unsafe methods (`PUT`, `POST validate`, `POST dry-run`) must also pass same-origin + Creative CSRF/nonce middleware.
- Admin PUT audit logs must be sanitized: log actor and counts/status only, never raw binding JSON, provider URLs, keys, headers, signed URLs, object keys, CSRF/nonce, cookies, or raw provider response bodies.
- Phase-B dry-run previews are diagnostic only. They may show binding/provider/price ids and sanitized request shape, but must redact dangerous keys and sensitive string values (provider URLs, signed URL markers, bearer/sk-like material, data/base64-like payloads, credentials, access-key markers, token markers) and must not read channel secrets or perform real provider calls.

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
- API-token-only request to `/api/creative/model-bindings*` -> `403` dashboard-session-required response.
- Non-root dashboard user -> denied by `RootAuth`.
- Missing/bad Creative CSRF/nonce on unsafe admin binding endpoints -> `403` before validation/persistence/dry-run.
- Admin dry-run preview containing `Authorization`, `baseURL`, callback/webhook/notifyHook, API-key, or signed URL material -> redacted before response/logging.

### 5. Good/Base/Bad Cases

- Good: parse disabled mock binding with `id=mock:gpt-image-2:preview`, `providerModelId=gpt-image-2`, and `priceModelId=mock-gpt-image-2-price`; no provider call occurs.
- Good: `POST /api/creative/model-bindings/dry-run` for a mock binding returns `noProviderCall=true` and `transport=mock` without channel key/base URL material.
- Base: empty option during startup parses as empty v1 config.
- Bad: administrator writes arbitrary `creative.model_bindings` JSON through `/api/option`, bypassing schema/forbidden validation and dry-run redaction.
- Bad: dry-run contacts Duomi/GrsAI or emits raw `Authorization`, `baseURL`, signed object URL query, cookie, CSRF, nonce, or raw provider body.

### 6. Tests Required

- Service parser tests for valid v1 config, unsupported version, duplicate IDs, forbidden IDs, required fields, and nested parameter schema validation.
- Shared normalizer tests covering camelCase, snake_case, kebab-case, dotted headers, and whitespace variants.
- Controller tests proving generic `/api/option` rejects `creative.model_bindings`.
- Admin endpoint tests must reuse the same parser/normalizer and cover root/dashboard auth, API-token-only rejection, same-origin/nonce failures on unsafe methods, redaction, no-provider-call dry-run, normalized persistence, and sanitized audit assertions.

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
```
