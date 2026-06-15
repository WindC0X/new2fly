# Creative Reverse-Proxy Origin Hotfix

## Goal

Fix production `/creative/api/bootstrap` returning `403 Forbidden` for logged-in users behind the HTTPS reverse proxy, so embedded Creative can bootstrap the authenticated session and display the user's model catalog.

## User Evidence

On `https://console.se7endot.top/creative/`, after logging into new-api, browser Console shows:

```text
GET https://console.se7endot.top/creative/api/bootstrap 403 (Forbidden)
{status: 403, success: false, modelCount: 0, ...}
```

The static `/creative/` app shell loads, but authenticated bootstrap fails; therefore text/image model dropdowns remain empty.

## Confirmed Technical Hypothesis

- `new-api` is behind Caddy/HTTPS reverse proxy.
- The browser uses `https://console.se7endot.top` as Origin/Referer.
- The Go app likely receives an internal HTTP request with `Request.TLS == nil`.
- `middleware.creativeRequestOrigin` currently infers scheme from `Request.TLS`, so it may compute `http://console.se7endot.top`.
- Creative same-origin validation then rejects the HTTPS Origin/Referer as cross-origin and returns 403.

## Requirements

1. Fix Creative same-origin origin inference to respect reverse-proxy scheme headers, especially `X-Forwarded-Proto: https`, and preferably standard `Forwarded: proto=https`.
2. Preserve security:
   - do not accept arbitrary cross-site origins;
   - continue rejecting mismatched Origin/Referer hosts;
   - do not weaken nonce/CSRF checks;
   - do not make `/creative/relay/*` usable without session + nonce.
3. Add tests covering:
   - HTTPS reverse proxy header + HTTPS Referer accepted;
   - HTTPS reverse proxy header + HTTPS Origin accepted;
   - mismatched cross-site Origin still rejected;
   - fallback behavior without proxy headers remains unchanged.
4. Rebuild and redeploy candidate image to VPS-A after tests pass.
5. Verify logged-in production bootstrap can return 200 with models, without printing cookies/CSRF/nonce/password.

## Acceptance Criteria

- [x] `new-api` tests for Creative origin validation pass.
- [x] Release gate passes or targeted Go tests + build pass before deployment.
- [x] New production image is deployed to VPS-A.
- [x] Public unauthenticated `/creative/api/bootstrap` still returns 401.
- [x] Authenticated browser `/creative/api/bootstrap` returns 200 after login.
- [x] `/creative/` model dropdowns can see text models for a logged-in user.
- [x] Existing public baseline remains: `/v1/models -> 401`, `/login -> 200`.
- [x] Route/header assertion remains passing.

## Out of Scope

- Enabling Creative 云同步 / S3 storage.
- Adding image models/channels.
- Changing user/channel/model policy configuration unless required to prove bootstrap.
- Provider generation or quota-consuming calls.
