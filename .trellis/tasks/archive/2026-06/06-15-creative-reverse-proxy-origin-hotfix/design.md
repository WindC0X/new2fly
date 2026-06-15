# Design — Creative Reverse-Proxy Origin Hotfix

## Root Cause

Creative same-origin checks compare browser `Origin`/`Referer` against an expected origin generated from the server request. Behind TLS-terminating reverse proxies, `Request.TLS` is nil inside the app even though the external request is HTTPS. If the app ignores `X-Forwarded-Proto`/`Forwarded`, it computes `http://host`, causing legitimate `https://host` browser requests to be rejected.

## Fix Design

Update `middleware.creativeRequestOrigin` to derive scheme in this order:

1. trusted reverse-proxy metadata from the current request headers:
   - `Forwarded: proto=https` / `proto=http`
   - `X-Forwarded-Proto: https` / first comma-separated value
   - optionally `X-Forwarded-Scheme`
2. `Request.TLS != nil` -> `https`
3. fallback `http`

Keep host derivation conservative:

- Continue using `Request.Host` as canonical host.
- Do not switch to arbitrary `X-Forwarded-Host` in this hotfix unless a later proxy-trust model is added; using `Request.Host` avoids host-header broadening.

## Security Constraints

- Only scheme is adjusted; host must still match the request host.
- Cross-site Origin/Referer with different host remains rejected.
- Missing Origin/Referer on unsafe methods remains rejected by `CreativeRequireNonce`.
- Safe Creative API reads still allow originless requests but reject explicit mismatched cross-site signals.

## Deployment Design

1. Patch `new-api/middleware/creative.go` and tests.
2. Run targeted Go tests, release gate if feasible.
3. Build image tag `new-api-creative-embed:bfef310-originfix`.
4. Stream-load to VPS-A.
5. Backup current compose only; DB migration is not expected because this is code-only, but keep existing deployment backup from previous Phase 1 available.
6. Update compose image and restart.
7. Verify unauth boundary, authenticated bootstrap from browser/user-supplied test, route/header matrix, and existing baseline.

## Rollback

Restore previous working Phase 1 image `new-api-creative-embed:bfef310-prod` in compose and restart. DB rollback is not needed for this code-only hotfix.
