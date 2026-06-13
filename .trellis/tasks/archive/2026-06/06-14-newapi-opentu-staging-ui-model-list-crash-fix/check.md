# Check Report — Staging UI / Model List / 429 Crash Perception Fix

Date: 2026-06-14 (Asia/Shanghai)

## Summary

Implemented and verified the local staging fixes for the embedded OpenTU `/creative/` app inside `new-api`:

- The observed “new-api crash” was a frontend availability symptom, not a process crash: the container stayed healthy, but `GlobalWebRateLimit` was returning `429` for Creative/static app-shell and chunk requests.
- The embedded `回到控制台` button was moved to the right of the left toolbar and raised above toolbar overlays.
- Embedded provider/model UI now uses only the `new-api-creative` managed session-broker catalog (`New API Creative`). It no longer exposes OpenTU standalone/default provider lists in `/creative/`, including when bootstrap is unauthorized or temporarily unavailable.
- Rebuilt OpenTU, synced the embedded dist into both `new-api` Creative dist trees, rebuilt the local Docker staging image, and restarted the persistent local staging container.

## Code Changes

### `new-api`

- `middleware/rate-limit.go`
  - Added `shouldBypassGlobalWebRateLimit()` for safe `GET`/`HEAD` static/app-shell paths.
  - Bypasses global web rate limit for `/creative`, `/creative/`, `/creative/*` static/app-shell routes and common static resources.
  - Does **not** bypass `/creative/api`, `/creative/api/*`, `/creative/relay`, or `/creative/relay/*`.
  - Sets `Cache-Control: private, no-store`, `Pragma: no-cache`, and `Expires: 0` before rate-limited Creative API/relay errors.
- `middleware/rate-limit_test.go`
  - Regression tests for Creative/static bypass, API/relay still rate-limited, no-store on API/relay `429`, and `/creative/api-docs` not being misclassified as API.
- Synced generated Creative dist:
  - `web/creative/dist/`
  - `router/web/creative/dist/`

### `opentu`

- `apps/web/src/components/ReturnButton.tsx`
  - Extracted button style constants.
  - `left: calc(var(--aitu-toolbar-right-edge, 58px) + 16px)`.
  - `zIndex: 4100`.
- `packages/drawnix/src/services/creative-session-broker.ts`
  - On bootstrap/auth failure, installs the managed `New API Creative` session-broker profile and an empty unavailable catalog instead of leaving the embedded UI to fall back to legacy/default providers.
- `packages/drawnix/src/utils/runtime-model-discovery.ts`
  - In Creative embedded mode, selectable/preferred/profile model lookups use only the managed `new-api-creative` catalog.
  - No static OpenTU fallback is returned for missing embedded selections.
- `packages/drawnix/src/components/settings-dialog/settings-dialog.tsx`
  - Embedded settings sidebar/details filter to `new-api-creative` only.
  - Add/create provider actions are suppressed in embedded mode.
- `packages/drawnix/src/components/ai-input-bar/ModelDropdown.tsx`
  - Embedded dropdown no longer falls back to OpenTU static model config when current selection is absent from the managed catalog.
  - Provider-management action is hidden in embedded mode.
- `packages/drawnix/src/components/model-benchmark/ModelBenchmarkWorkbench.tsx`
  - Benchmark provider filtering respects embedded mode.
- Added/updated tests for session-broker fallback, runtime discovery, model dropdown, return button, and model benchmark profile filtering.

## Model List Configuration Answer

The embedded OpenTU model list is **not configured in OpenTU local provider settings**.

Runtime flow:

1. Browser opens `/creative/`.
2. OpenTU embedded frontend calls:
   - `/creative/api/bootstrap`
   - `/creative/api/models`
3. Frontend writes a managed session-broker profile:
   - profile id: `new-api-creative`
   - display name: `New API Creative`
   - relay base: `/creative/relay/v1`
4. All embedded model selectors/settings read only that managed catalog.
5. `new-api` builds `/creative/api/models` from the current user’s usable group model pool:
   - `router/web-router.go`: `GET /creative/api/models -> controller.CreativeListModels`
   - `controller/creative.go`: `CreativeListModels -> creativeModelsForUser`
   - `service/creative.go`: `GetUserCreativeModelPool(userCache.Group)`
   - `model/ability.go`: `GetGroupEnabledModels(group)` reads enabled rows from `abilities`.

Operational setup therefore happens in the **new-api console/backend data**, not in OpenTU:

1. Create/enable the upstream channel(s).
2. Configure the channel `models` list.
3. Bind the channel to the user’s available group(s).
4. Ensure channel status is enabled so abilities are enabled/generated/refreshed.
5. Log in as a user whose group can use those abilities; `/creative/api/models` will then return the selectable model list.

If not logged in, `/creative/api/bootstrap` and `/creative/api/models` correctly return `401 private, no-store`; the embedded UI now still shows `New API Creative` with `0` models/unavailable state rather than the OpenTU default provider catalog.

## Fresh Verification

### Unit / Type / Build / Artifact Gates

Passed:

```bash
cd /mnt/f/code/project/opentu/packages/drawnix
pnpm vitest run src/services/creative-session-broker.test.ts \
  src/utils/runtime-model-discovery.creative-embedded.test.ts \
  src/components/ai-input-bar/ModelDropdown.test.tsx \
  src/components/model-benchmark/ModelBenchmarkWorkbench.test.tsx \
  --config vitest.config.ts
# Test Files 4 passed; Tests 22 passed
```

```bash
cd /mnt/f/code/project/opentu
pnpm nx run drawnix:typecheck
# NX Successfully ran target typecheck for project drawnix

pnpm nx run web:typecheck
# NX Successfully ran target typecheck for project web
```

```bash
cd /mnt/f/code/project/new-api
go test ./middleware
# ok github.com/QuantumNous/new-api/middleware
```

```bash
cd /mnt/f/code/project/new2fly
python3 scripts/creative_release_gate.py build-sync-check --run-new-api-tests
# OpenTU build passed
# Creative dist synced to both new-api targets
# Creative embedded artifact contract holds
# go test -count=1 . passed
# go test -count=1 ./router ./middleware ./controller ./model ./service ./relay/... passed
# go build ./... passed
# [done] no-secrets Creative release gate completed
```

Additional post-format checks passed:

```bash
cd /mnt/f/code/project/opentu/packages/drawnix
pnpm vitest run src/components/model-benchmark/ModelBenchmarkWorkbench.test.tsx --config vitest.config.ts
# Test Files 1 passed; Tests 2 passed

cd /mnt/f/code/project/new2fly
python3 scripts/creative_release_gate.py check --source-diff-check
# Creative embedded artifact contract holds
# git diff --check passed for new2fly/opentu/new-api source scopes
# [done] no-secrets Creative release gate completed
```

### Local Staging Rebuild / Restart

```bash
docker build --pull=false --progress=plain \
  -t new-api-creative-embed:staging-current \
  /mnt/f/code/project/new-api
# image sha256:bcc6c621efec7df2134e505e88c74405fbd55e0fb7c0a0cdbbc203c8221a0f97
```

```bash
STAGING_BIND_ADDR=127.0.0.1 STAGING_PORT=39084 \
  docker compose -f ops/newapi-opentu-staging/docker-compose.yml \
  -p newapi-opentu-staging up -d --force-recreate
```

Container state after restart:

```text
newapi-opentu-staging-new-api: running healthy, restartCount=0
```

### Embedded Smoke

Passed:

```bash
cd /mnt/f/code/project/new2fly
python3 scripts/creative_release_gate.py check \
  --embedded-smoke-url http://localhost:39084/creative/ \
  --drawnix-ready-timeout-ms 60000
# 1 passed [creative-embedded]
# [done] no-secrets Creative release gate completed
```

### Route/Header Matrix

Fresh read-only route check against `http://localhost:39084`:

| path | class | status | content-type | cache-control | location |
|---|---:|---:|---|---|---|
| `/creative/` | app-shell | 200 | `text/html; charset=utf-8` | `no-cache` | |
| `/creative/assets/index-CVYKr8x9.js` | asset-existing | 200 | `text/javascript; charset=utf-8` | `public, max-age=31536000, immutable` | |
| `/creative/sw.js` | service-worker | 200 | `text/javascript; charset=utf-8` | `no-cache` | |
| `/creative/version.json` | metadata | 200 | `application/json` | `no-cache` | |
| `/creative/api/bootstrap` | api-auth | 401 | `application/json; charset=utf-8` | `private, no-store` | |
| `/creative/relay/v1/videos/task_dummy` | relay-auth | 401 | `application/json; charset=utf-8` | `private, no-store` | |
| `/creative/api-docs` | app-route | 200 | `text/html; charset=utf-8` | `no-cache` | |
| `/creative/assets/definitely-missing.js` | missing-asset | 404 | `text/plain; charset=utf-8` | `no-cache` | |

Repeated static/app-shell checks did not hit `429`:

```text
/creative/      200 200 200 200 200
/creative/sw.js 200 200 200 200 200
/creative/api-docs 200 200 200 200 200
```

### UI Evidence

Screenshots saved under this task directory:

- `return-button-check.png` — `回到控制台` is no longer hidden by the toolbar.
- `settings-after-placeholder.png` — unauthorized/401 state shows only `New API Creative`, `0` models, no legacy provider list.
- `model-settings-after-placeholder-mock.png` — mocked `/creative/api/models` state shows only `New API Creative` with new-api-provided model count/list.
- `model-dropdown-actual-fresh.png` — actual unauthenticated staging dropdown shows no OpenTU static model fallback.

### Dynamic Workflow Status

A dynamic workflow was used for part of the post-fix, read-only review:

- Workflow: `.codex-flow/generated/staging-ui-model-list-postfix-reaudit.workflow.ts`
- Journal: `.codex-flow/journal/staging-ui-model-list-postfix-reaudit.jsonl`

Caveat: the workflow did not fully converge end-to-end; one branch initially ran while the staging service was unavailable and failed to connect. The authoritative closure evidence is therefore the manual fresh verification above plus the committed tests/build/smoke gates. Do not commit `.codex-flow/` unless explicitly requested.

## Notes / Non-goals

- This was local staging only, bound to `127.0.0.1:39084`.
- No production/CDN/S3/payment/provider health checks were performed.
- No real generation tasks were created and no provider quota was consumed.
- `.env.staging.local` was not read or printed.
