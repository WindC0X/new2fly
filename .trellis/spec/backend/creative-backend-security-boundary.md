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
