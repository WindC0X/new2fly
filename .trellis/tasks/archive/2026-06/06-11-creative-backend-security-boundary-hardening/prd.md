# Creative backend security boundary hardening

## Goal

Fix `../new-api` Creative backend route, DTO privacy, forbidden relay-field, same-origin trust, cache, and proxy boundary issues before release.

## Source Findings

- Codex H1: `FRONTEND_BASE_URL` deployment bypasses `SetWebRouter`, so Creative API/relay routes are not registered and may redirect.
- Codex H5: Suno fetch serializes same-user non-Suno tasks with generic internal DTO fields.
- Codex H9/M6: notify/callback/owner/API-secret variants are not consistently forbidden.
- Codex H10: Creative expected origin trusts client-controlled `X-Forwarded-*` without trusted proxy gating.
- Codex M1: global Cache middleware can set long-lived cache headers on Creative API/relay errors.
- Hardening from comparison: avoid redirect-unchecked `http.DefaultClient` fallback and strip sensitive headers across redirects.

## Requirements

- Creative API and relay routes must exist independently of static web serving and `FRONTEND_BASE_URL` fallback.
- Suno fetch must only return Suno tasks owned by the current user and must use a sanitized response shape.
- Backend relay guards must reject callback/notify/webhook, owner/user override, MJ API secret, API-secret aliases, provider/channel/group/model override variants according to each route contract.
- Creative same-origin checks must use trusted/canonical origin information, not raw client-supplied forwarded headers unless the request came through a trusted proxy path.
- Creative API/relay responses must be private/no-store or at least not inherit week-long public cache headers.
- Creative proxy fetches must use clients with SSRF redirect checks and must not carry sensitive headers across redirects.

## Acceptance Criteria

- [x] `FRONTEND_BASE_URL` router test proves `/creative/api/*` and `/creative/relay/v1/*` do not 301 to frontend.
- [x] Same-user MJ task requested through Suno fetch is rejected or sanitized with no MJ private URL/channel/quota/data leakage.
- [x] Backend tests reject `notifyHook`, `notify_hook`, `callback`, `webhook`, owner/user aliases, `mj-api-secret`, and API-secret aliases in JSON/form/multipart/query/header where applicable.
- [x] XFF spoof test documents fail-closed behavior unless trusted proxy config explicitly allows forwarded origin.
- [x] Creative API/relay error tests confirm no long-lived public cache headers.
- [x] Proxy redirect hardening tests or focused code review confirms redirect validation and sensitive header stripping.
