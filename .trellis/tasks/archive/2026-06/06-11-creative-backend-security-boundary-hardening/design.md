# Design — Creative backend security boundary hardening

## Affected Areas

- `../new-api/router/main.go`
- `../new-api/router/web-router.go`
- `../new-api/middleware/creative.go`
- `../new-api/middleware/cache.go`
- `../new-api/controller/creative.go`
- `../new-api/relay/relay_task.go`
- `../new-api/controller/video_proxy*.go`
- `../new-api/service/http_client.go`

## Route Design

Extract Creative API/relay route registration into a function that can be called regardless of static web serving mode. `FRONTEND_BASE_URL` should only affect SPA/static fallback. Creative API/relay paths should either route normally or return controlled JSON fail-closed responses.

## DTO/Privacy Design

Suno fetch should validate `task.Platform == TaskPlatformSuno` before serialization. Response DTO should be Suno-specific and exclude generic internal fields like channel id, quota, user id, raw `data`, and upstream/private result URLs unless explicitly required by the Suno frontend contract.

## Forbidden Field Design

Use normalized denylist coverage across snake/camel/kebab and nested paths. Add missing categories:

- notify/callback/webhook variants;
- owner/user override variants;
- `mj-api-secret`, `apiSecret`, `api_secret`, and similar provider secret aliases.

Allow route-specific top-level model only where the existing contract explicitly permits it; Creative Suno/MJ derive model server-side.

## Origin/Cache/Proxy Design

- Prefer configured public origin or trusted proxy-gated forwarded origin.
- Cache middleware should skip Creative API/relay or Creative groups should overwrite `Cache-Control` to private/no-store.
- Proxy clients should share `service` redirect validation; redirect policy should strip sensitive headers on cross-host redirects.
