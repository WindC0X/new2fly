# Creative startup recovery production deployment

- Date: 2026-06-16
- Scope: production VPS-A `/home/admin/apps/new-api`, `console.se7endot.top/creative/`

## Commits

- OpenTU: `360a81f7 fix(creative): harden embedded startup recovery`
- new-api artifact sync: `8a2b011 chore(creative): sync hardened embedded artifact`
- new-api embed fix: `3fb17f1 fix(creative): embed underscore assets in binary`
- new2fly records/spec: `6a5b051 chore(spec): document creative underscore asset embed`

## Local verification before deployment

- `pnpm verify:creative-embedded-startup` passed.
- `VITE_BASE_URL=/creative/ pnpm build:web` passed, including web typecheck.
- `python3 scripts/creative_release_gate.py sync` passed and copied OpenTU dist to both new-api dist targets.
- `python3 scripts/creative_release_gate.py check --source-diff-check --run-new-api-tests` passed before the Go embed follow-up.
- After the Go embed follow-up:
  - `go test -count=1 . ./router` passed.
  - `go build ./...` passed.
  - `python3 scripts/creative_release_gate.py check --source-diff-check` passed.

## Production deployment

- First deployed image: `new-api-creative-embed:8a2b011-creative-startup`; this fixed the stale entry alias but still returned 404 for `__vite-browser-external-UePf-KSV.js` because Go directory embed skipped `_`-prefixed files.
- Final deployed image: `new-api-creative-embed:3fb17f1-creative-startup`, local image id `sha256:ca9bb3d454095d53bd62b879065c8003df5173c70003a09e58e2d16ce8cfc4a7`.
- Compose backups created on VPS:
  - `backups/docker-compose.before-8a2b011-creative-startup.20260616-203122.yml`
  - `backups/docker-compose.before-3fb17f1-creative-startup.20260616-204158.yml`
- Only the compose `image:` line was changed; production `.env`, SQLite data, users, and channel config were not modified.

## Production verification

- Container: `image=new-api-creative-embed:3fb17f1-creative-startup status=running restart=0`.
- `TurnstileCheckEnabled=true`; `smoke_users=0`.
- `HEAD /creative/` returned 200 with `cache-control: no-cache` and `x-creative-build-time: 2026-06-16T12:05:44.669Z`.
- `HEAD /creative/assets/index-CeAw2BfZ.js` returned 200.
- `HEAD /creative/assets/__vite-browser-external-UePf-KSV.js` returned 200.
- Intentional missing asset `HEAD /creative/assets/no-such-asset-creative-startup.js` returned 404, proving static miss remains non-SPA fallback.
- Headless Chromium unauthenticated smoke:
  - boot overlay removed: `#app-boot-loading` count `0`.
  - React root mounted: `rootChildren=1`.
  - `/creative/cdn-config.js` returned 200.
  - `/creative/api/bootstrap` returned 401 because the browser was not logged in; this is expected and did not block boot.
- Recent production logs after final deployment showed no unexpected `/creative/assets` 404 besides the intentional missing-asset probe.

## Follow-up product note

Current Duomi/GrsAI state is unchanged by this startup fix: production has backend admin APIs for `creative.model_bindings`, but no React admin UI and no real Duomi/GrsAI live adapter. GrsAI remains dry-run/fixture-only; Duomi remains blocked until fixtures and a real backend adapter are implemented.
