# Research: creative embedded 82 loading

- Query: 定位 OpenTU embedded Creative 在 new-api 生产 `/creative/` 卡在“正在唤起工作台 / 82%”加载页的可能代码路径、等待点、资源/IndexedDB/worker/bootstrap/auth 请求。
- Scope: internal
- Date: 2026-06-16

## Findings

### Files found

- `/mnt/f/code/project/opentu/apps/web/index.html` — standalone OpenTU boot shell and boot progress controller source; embedded build inherits and postprocesses this shell.
- `/mnt/f/code/project/opentu/apps/web/src/main.tsx` — main React entry; updates boot progress to 88 and mounts React app.
- `/mnt/f/code/project/opentu/apps/web/src/app/app.tsx` — calls `window.__OPENTU_BOOT__.markReady()` after the app loading state clears.
- `/mnt/f/code/project/opentu/packages/drawnix/src/drawnix.tsx` — starts embedded Creative session-broker bootstrap after Drawnix mounts.
- `/mnt/f/code/project/opentu/packages/drawnix/src/services/creative-session-broker.ts` — fetches `/creative/api/bootstrap` and `/creative/api/models`, applies session auth/nonce/model catalog, and catches failures into an unavailable catalog.
- `/mnt/f/code/project/opentu/packages/drawnix/src/services/creative-mode.ts` — defines embedded-mode path detection and Creative endpoint constants.
- `/mnt/f/code/project/opentu/apps/web/src/sw/index.ts` — service worker install/fetch/static cache logic, including static resource handling and fetch-without-timeout behavior.
- `/mnt/f/code/project/opentu/apps/web/vite.config.ts` — embedded Creative artifact cleanup/postprocess plugin; rewrites app shell branding, CDN/local settings, and writes `cdn-config.js`.
- `/mnt/f/code/project/opentu/scripts/postprocess-embedded-creative-dist.js` — final embedded-dist postprocess for `sw.js`, changelog, and standalone name/CDN rewrites.
- `/mnt/f/code/project/new-api/router/web-router.go` — serves `/creative/`, `/creative/assets/*`, `/creative/sw.js`, `/creative/api/*`, and `/creative/relay/*` from the embedded artifact with cache/security headers.
- `/mnt/f/code/project/new-api/controller/creative.go` — `CreativeBootstrap`, model catalog, nonce/auth payload, relay constants.
- `/mnt/f/code/project/new-api/controller/creative_model_policy.go` — effective model-policy calculation during bootstrap.
- `/mnt/f/code/project/new-api/service/creative_model_capability.go` — stored/preview Creative model binding catalog gating.
- `/mnt/f/code/project/new-api/web/creative/dist/index.html` — current embedded production app shell in new-api; contains the observed boot text and references `/creative/assets/index-DNVo0rPB.js`.

### Code patterns and load chain

1. The observed “82%” is the boot shell's simulated-progress ceiling, not a backend status.
   - Boot title is rendered at `/mnt/f/code/project/opentu/apps/web/index.html:516-552`; embedded dist keeps the same text at `/mnt/f/code/project/new-api/web/creative/dist/index.html:391-423`.
   - `startSimulatedProgress()` caps progress at `Math.min(82, ...)` and stops the timer at 82 unless `markReady()` runs: `/mnt/f/code/project/opentu/apps/web/index.html:1088-1111`; embedded dist equivalent is `/mnt/f/code/project/new-api/web/creative/dist/index.html:848-871`.
   - `markReady()` is the only normal path that removes the loading overlay: `/mnt/f/code/project/opentu/apps/web/index.html:1140-1165`; embedded dist equivalent is `/mnt/f/code/project/new-api/web/creative/dist/index.html:900-925`.

2. The app should normally move past 82 before waiting for Creative bootstrap APIs.
   - `main.tsx` updates boot progress to 88 immediately before React mount: `/mnt/f/code/project/opentu/apps/web/src/main.tsx:313-317` and `/mnt/f/code/project/opentu/apps/web/src/main.tsx:389-622` for SW setup; the built `startup-app-C8xJTzUZ.js` contains `正在挂载工作台界面...` and progress 88.
   - `App` calls `markReady()` when `showCrashDialog || initError || !isLoading`: `/mnt/f/code/project/opentu/apps/web/src/app/app.tsx:231-240`.
   - On first non-StrictMode initialization, `App` deliberately clears `isLoading` before `workspaceService.initialize()`: `/mnt/f/code/project/opentu/apps/web/src/app/app.tsx:301-305`; this means slow IndexedDB workspace initialization should not by itself leave the boot shell at 82.
   - Therefore a persistent 82% usually means the startup entry did not evaluate/mount React, or the global boot controller was not available when App tried to mark ready.

3. Embedded dist startup depends on an extra `cdn-config.js` gate before importing the real app chunk.
   - Current new-api embedded index loads `/creative/assets/index-DNVo0rPB.js` in `<head>`: `/mnt/f/code/project/new-api/web/creative/dist/index.html:387-388`.
   - That small entry waits on `window.__OPENTU_START_MAIN_ENTRY__`, then dynamically imports `./startup-app-C8xJTzUZ.js` (observed in `/mnt/f/code/project/new-api/web/creative/dist/assets/index-DNVo0rPB.js`).
   - The boot shell creates `window.__OPENTU_START_MAIN_ENTRY__`: `/mnt/f/code/project/new-api/web/creative/dist/index.html:449-451`.
   - It resolves only after `appendManagedBootScript('./cdn-config.js', ...)` succeeds or fails: `/mnt/f/code/project/new-api/web/creative/dist/index.html:1155-1180`.
   - The embedded Vite plugin writes `cdn-config.js` as a local same-origin script and sets local CDN preference: `/mnt/f/code/project/opentu/apps/web/vite.config.ts:1293-1311`, `/mnt/f/code/project/opentu/apps/web/vite.config.ts:1314-1329`.
   - If `/creative/cdn-config.js` never completes at the browser/SW/network layer, the main entry waits forever and the UI remains at the 82 simulated ceiling. There is no timeout around this boot gate.

4. Service worker static-resource handling can create indefinite waits because its internal origin fetch has no timeout.
   - In production SW static handling, GET navigations/resources are routed through `handleStaticRequest`: `/mnt/f/code/project/opentu/apps/web/src/sw/index.ts:4597-4654`.
   - `fetchQuick()` is a direct `return fetch(request, fetchOptions)` with no AbortController/timeout: `/mnt/f/code/project/opentu/apps/web/src/sw/index.ts:4865-4871`.
   - For app shell and non-smart static resources, `handleStaticRequest()` awaits `fetchQuick()` and only falls back on rejection, not on hanging response: `/mnt/f/code/project/opentu/apps/web/src/sw/index.ts:5703-5793` and `/mnt/f/code/project/opentu/apps/web/src/sw/index.ts:5877-5954`.
   - `cdn-config.js` is a same-origin script under the SW scope. It is not versioned/hased under `/assets/`, so it follows the origin-first branch and can hang if an existing SW controls the page and the origin request stalls.
   - This is a strong fit for “82% forever”: the dynamic-import Promise is pending, so no recoverable import error is thrown and `markError()` is not called.

5. The new-api router appears to serve the embedded artifact correctly in the checked tree, but should be verified against the actually deployed binary/image.
   - `/creative/`, `/creative/index.html`, and SPA fallback return the embedded index with `Cache-Control: no-cache`: `/mnt/f/code/project/new-api/router/web-router.go:203-250`.
   - `/creative/assets/*` are served as real files, immutable when hashed: `/mnt/f/code/project/new-api/router/web-router.go:224-239`.
   - Missing `/creative/assets/*` returns 404, not HTML fallback: `/mnt/f/code/project/new-api/router/web-router.go:241-245`.
   - `/creative/api/*` and `/creative/relay/*` are explicitly excluded from SPA fallback and return API/relay not-found: `/mnt/f/code/project/new-api/router/web-router.go:207-211`.
   - Tests assert route behavior, headers, and asset references: `/mnt/f/code/project/new-api/router/web_router_test.go:230-285`; main/router embedded dist parity is asserted in `/mnt/f/code/project/new-api/main_creative_dist_test.go:35-61`.
   - Current checked-in dist has the entry assets present: `/mnt/f/code/project/new-api/web/creative/dist/assets/index-DNVo0rPB.js`, `startup-app-C8xJTzUZ.js`, `startup-runtime-Di8qk2Fd.js`, `startup-app-DxC2basr.css`, and `cdn-config.js` exist locally. The artifact version is `0.9.6` in `/mnt/f/code/project/new-api/web/creative/dist/version.json`.

6. `/creative/api/bootstrap` and `/creative/api/models` are post-mount session-broker steps, so failures there should not leave the first boot overlay at 82.
   - `initializeCreativeManagedSessionBroker()` is started inside Drawnix after component mount: `/mnt/f/code/project/opentu/packages/drawnix/src/drawnix.tsx:360-364`.
   - The session broker first waits for `settingsManager.waitForInitialization()`, then fetches `/creative/api/bootstrap` and `/creative/api/models`: `/mnt/f/code/project/opentu/packages/drawnix/src/services/creative-session-broker.ts:617-639`.
   - It catches bootstrap/model errors, installs an unavailable managed profile/catalog, logs a warning, dispatches an error event, and returns status `error`: `/mnt/f/code/project/opentu/packages/drawnix/src/services/creative-session-broker.ts:667-691`.
   - Backend bootstrap returns session-broker auth material, nonce, profile base URL, capabilities, catalog version, policy, models, asset sync status, and preference: `/mnt/f/code/project/new-api/controller/creative.go:163-223`.
   - `CreativeListModels` is session-protected but read-only: `/mnt/f/code/project/new-api/controller/creative.go:225-240`; model catalog composition appends stored/preview bindings at `/mnt/f/code/project/new-api/controller/creative.go:1389-1411`.
   - Thus 401/500/empty model pool would break model availability later, but should display the workbench shell unless another error happens before React/App readiness.

7. IndexedDB/workspace initialization is less likely as the sole 82% cause, but still relevant if React crashes before the `isLoading=false` effect is observed.
   - `App` no longer waits for workspace restore to end the boot overlay: `/mnt/f/code/project/opentu/apps/web/src/app/app.tsx:263-305`.
   - On errors inside workspace init, it sets `initError` and still clears loading in `finally`: `/mnt/f/code/project/opentu/apps/web/src/app/app.tsx:495-503`, which should call `markReady()` through the earlier effect.
   - SW and storage code use IndexedDB heavily (`sw-task-queue`, app workspace stores), but the code path found does not show an IndexedDB wait before the boot overlay is cleared.

### Likely causes ranked

1. **Most likely: a boot static resource request is pending, especially `/creative/cdn-config.js` or `/creative/assets/startup-app-C8xJTzUZ.js`, under an already-installed SW.** The 82 cap plus no `markError()` points to a pending Promise rather than a thrown error. The boot gate for `cdn-config.js` has no timeout, and SW `fetchQuick()` has no timeout.
2. **Likely: deployed artifact mismatch/stale SW cache.** If production serves an index referencing a chunk not present in the deployed `web/creative/dist/assets`, dynamic import would normally error/reload, but a stale/hanging SW response or old cache could turn this into a pending load. Verify deployed `index.html` asset names against the actual served asset list, not just repository files.
3. **Possible: service worker scope/version transition issue.** Existing clients may be controlled by an older `/creative/sw.js`; navigation/app shell can be cache-first for controlled clients and old caches are searched before network. A bad committed cache can keep serving an old shell or stale entry until recovery clears caches.
4. **Less likely as first-screen blocker: `/creative/api/bootstrap`, auth/nonce, or empty model catalog.** Those requests are issued after the React app/Drawnix effect mounts and are caught into a degraded profile. They should not keep the boot shell at 82 by themselves.
5. **Less likely as sole blocker: IndexedDB workspace corruption/slowness.** App sets loading false before awaiting workspace initialization and catches init errors.

### Suggested validation points (no production connection performed)

Use a browser/devtools or local/staging reproduction against the affected deployed artifact:

1. In Network panel, reload `/creative/?sw=0&_t=<now>` and check whether the page passes 82.
   - If yes, focus on SW stale-cache/static fetch handling.
   - `sw=0` path is supported by the boot shell and main entry: `/mnt/f/code/project/opentu/apps/web/index.html:1297-1345` and `/mnt/f/code/project/opentu/apps/web/src/main.tsx:33-41`.
2. Check whether any of these requests are `pending`, stalled, 404, 503, HTML-as-JS, or wrong MIME:
   - `/creative/cdn-config.js`
   - `/creative/assets/index-DNVo0rPB.js` (or deployed entry asset name)
   - `/creative/assets/startup-runtime-*.js`
   - `/creative/assets/startup-app-*.js`
   - `/creative/assets/startup-app-*.css`
   - `/creative/sw.js`, `/creative/version.json`, `/creative/idle-prefetch-manifest.json`
3. In Application > Service Workers, unregister `/creative/sw.js`; clear Cache Storage entries named `drawnix-static-v*`; reload `/creative/`.
4. Compare deployed `/creative/index.html` asset references with actual `/creative/assets/*` files in the deployed image/binary. The repo tests only prove the checked-in tree is internally consistent.
5. Add temporary local/staging instrumentation around `loadCDNConfigAndBootstrap()` and `appendManagedBootScript()` to log `cdn-config` start/success/error/timeout; do not log secrets.
6. Inspect console for absence of `正在挂载工作台界面...` progress 88. If absent, the startup app chunk did not evaluate; if present but overlay remains, inspect React/App readiness and `__OPENTU_BOOT__` availability.

### Suggested fix directions

1. Add a bounded timeout to the boot `cdn-config.js` gate. If the script neither loads nor errors within a short window, call the same fallback path that resolves `__OPENTU_START_MAIN_ENTRY__` and proceeds with local boot.
2. Add timeout/AbortController behavior to SW `fetchQuick()` for startup static resources, especially `cdn-config.js`, root shell, and entry chunks, so SW can fall back/error instead of leaving browser requests pending indefinitely.
3. Consider marking `/creative/cdn-config.js` as origin-first/no-cache and/or bypass SW static cache like `sw.js`, `version.json`, and manifests.
4. Add an embedded boot smoke test that asserts `window.__OPENTU_BOOT__.markReady()` is called or `#app-boot-loading` disappears after serving the built new-api artifact, with SW enabled and disabled.
5. Add production diagnostics endpoint/checklist for embedded artifact parity: index references, file existence, content type, cache-control, and version hash.

## Caveats / Not Found

- I did not connect to production or any live deployment; findings are from local source/artifact inspection only.
- I did not find evidence that `/creative/api/bootstrap` is on the critical path before the first boot overlay clears; it is post-mount and caught on failure.
- I did not prove the deployed binary/image matches `/mnt/f/code/project/new-api/web/creative/dist`; artifact mismatch remains a deployment caveat.
- I did not run browser automation against a local new-api server in this research pass.
- `precache-manifest.json` is absent in the checked-in embedded dist; `idle-prefetch-manifest.json` exists. The SW treats missing precache manifest as non-fatal.

## External references

- No external web references used. Internal artifact version observed: `new-api/web/creative/dist/version.json` reports Creative artifact version `0.9.6`, build time `2026-06-16T03:06:34.268Z`.

## Related specs

- `.trellis/spec/frontend/creative-embedded-release-artifact.md` — embedded release artifact parity, no frontend redirect, private/no-store API behavior, `/creative/assets/` references.
- `.trellis/spec/backend/creative-backend-security-boundary.md` — Creative embedded API/relay security boundaries and same-origin/session requirements.
- `.trellis/spec/frontend/state-management.md` — runtime catalog/preferences and client state concerns.
- `.trellis/spec/frontend/creative-asset-sync.md` and `.trellis/spec/backend/creative-asset-sync.md` — asset/privacy boundaries relevant to `/creative/api/assets`, but not found to be first-boot blocker here.
