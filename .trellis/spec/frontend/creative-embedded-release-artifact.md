# Creative Embedded Release Artifact Contract

## Scenario: Opentu build artifact embedded by new-api

### 1. Scope / Trigger

- Trigger: changing Opentu code that is shipped as the embedded Creative frontend under `new-api` `/creative/`.
- This is a cross-repo release contract: Opentu produces the static artifact, while `new-api` embeds and serves it from both `web/creative/dist` and `router/web/creative/dist`.
- Applies to Creative app-shell, service worker, release metadata, static chunks, and future generated files emitted by `pnpm build:web`.

### 2. Signatures

- Build command for embedded release artifacts:
  - `cd /mnt/f/code/project/opentu`
  - `VITE_BASE_URL=/creative/ pnpm build:web`
  - the Opentu `web:build` target must run `node scripts/postprocess-embedded-creative-dist.js` after `web:build-sw`; do not run the postprocess only after `web:build-app`, because service-worker generation can reintroduce `sw.js` metadata after the app bundle is rewritten
- Artifact source:
  - `opentu/dist/apps/web/`
- Local no-secrets gate script:
  - `cd /mnt/f/code/project/new2fly`
  - `python3 scripts/creative_release_gate.py check`
  - `python3 scripts/creative_release_gate.py build-sync-check --run-new-api-tests` for the full local rebuild/sync/test gate
  - add `--embedded-smoke-url http://localhost:<port>/creative/` when a local `new-api` server is already running and browser smoke should be included
- Remote-backed RC verification:
  - prove candidate refs with live `git ls-remote` output before reporting a pushed branch as verified
  - when GitHub credentials are intentionally available only on the host machine, first try a non-interactive WSL `git push --dry-run` / `git ls-remote`; if it cannot read credentials, run push/verify with host Git (for example Windows Git from PowerShell) rather than copying tokens into WSL or logs
  - do not report orchestration/task records such as `new2fly` as pushed until the task/check files have been committed and the final remote ref has been verified
  - run `python3 scripts/creative_release_gate.py check --source-diff-check --run-new-api-tests`
  - run OpenTU checks, including cold smoke with `NX_SKIP_NX_CACHE=true pnpm e2e:smoke`
  - run embedded smoke against a temporary local `new-api` server started with a sanitized process environment:
    ```bash
    env -i \
      PATH="$PATH" HOME="$HOME" USER="$USER" \
      GOCACHE="$(go env GOCACHE)" GOMODCACHE="$(go env GOMODCACHE)" CGO_ENABLED="$(go env CGO_ENABLED)" \
      PORT=<port> SQLITE_PATH="$tmpdir/one-api.db?_busy_timeout=30000" \
      SESSION_SECRET="creative-smoke-local-session-secret" GIN_MODE=release \
      SYNC_FREQUENCY=3600 UPDATE_TASK=false CHANNEL_UPSTREAM_MODEL_UPDATE_TASK_ENABLED=false \
      go run . --log-dir "$tmpdir/logs"
    ```
- Artifact targets in `new-api`:
  - `new-api/web/creative/dist/`
  - `new-api/router/web/creative/dist/`
- Docker/container packaging:
  - `new-api/Dockerfile` rebuilds the default/classic frontends but does not build OpenTU; it copies the prebuilt Creative artifact with `COPY ./web/creative/dist ./web/creative/dist`
  - `.dockerignore` may exclude default/classic generated dist paths, but must not exclude `web/creative/dist` for embedded Creative image builds
- Embedded model/provider UI source:
  - OpenTU embedded under `/creative/` uses the managed session-broker profile id `new-api-creative` (`New API Creative`) and receives its selectable model catalog from `new-api` `/creative/api/bootstrap` plus `/creative/api/models`.
  - The embedded UI must not expose or fall back to OpenTU standalone default provider profiles or static model catalogs as selectable sources.
- Backend route contract:
  - `new-api` serves the SPA under `/creative/`.
  - `new-api` serves hashed chunks under `/creative/assets/*`; missing `/creative/assets/*` paths are static 404s, not SPA fallback.
  - `new-api` keeps `/creative/api/*` and `/creative/relay/v1/*` as API/relay routes, not SPA/static fallbacks.
- Release-environment readiness checks:
  - if a target environment sets `FRONTEND_BASE_URL`, prove the node mode and route behavior before claiming embedded `/creative/` is available; non-master redirect mode only registers Creative API/relay locally and may redirect `/creative/` static/app-shell paths to the external frontend
  - do not treat OpenTU `release:dry`, `npm:publish:dry`, or deploy upload scripts as no-network/no-mutation checks; they may contact registries, rewrite `dist/`, or use SSH/rsync/scp paths
  - verify publish credentials by presence or identity only (`NPM_TOKEN`, `DOCKERHUB_USERNAME`, `DOCKERHUB_TOKEN`, `GITHUB_TOKEN`), never by printing secret values
  - if no deployed staging/production target exists yet, run a local/intranet release-like staging check first with sanitized `env -i`, temporary SQLite, disabled upstream update jobs, `--embedded-smoke-url http://localhost:<port>/creative/`, and a redacted `GET`/`HEAD` route/header table; label the result as local staging only, not production/CDN/S3 readiness

### 3. Contracts

- Embedded Creative builds must use `VITE_BASE_URL=/creative/`; the default `base='./'` build is valid for standalone static serving but not for the `new-api` embedded contract.
- The embedded `index.html` must reference entry JS/CSS under `/creative/assets/...`.
- `opentu/dist/apps/web/`, `new-api/web/creative/dist/`, and `new-api/router/web/creative/dist/` must contain the same relative files with the same bytes after sync.
- `new-api/web/creative/dist/index.html`, `sw.js`, and `version.json` must match `new-api/router/web/creative/dist/*`.
- `sw.js` must register and run from `/creative/sw.js` when loaded from `/creative/`; runtime metadata (`version.json`, manifests, `sw.js`) stays same-origin.
- Generated artifact files may contain build-tool whitespace or sourcemaps; release gates must either accept generated-artifact policy exceptions or enforce normalization at the Opentu build-output source, not by manually editing only `new-api` copies.
- Embedded final-artifact postprocess is part of the Opentu artifact source contract. It must run after `build-sw` and normalize final metadata files such as `sw.js` and `changelog.json`, remove stale `sw.js.map` when embedded policy forbids maps, and keep the source dist ready to sync byte-for-byte into both `new-api` targets.
- Static standalone marker scans must include final generated metadata, not just `index.html`/manifest/chunks. At minimum scan `changelog.json` and `sw.js` for standalone OpenTU/Tuzi/GitHub/API-key markers because they are easy to miss in visual smoke tests but still ship to browsers.
- Source whitespace checks and generated-dist checks are separate gates: run source-only `git diff --check` for hand-written code, and enforce generated dist by byte identity across `opentu/dist/apps/web/`, `new-api/web/creative/dist/`, and `new-api/router/web/creative/dist/`.
- `apps/web/public/version.json` buildTime changes caused by local `pnpm build:web` are build side effects unless intentionally part of an Opentu source release; do not commit source timestamp churn blindly.
- No-secrets RC verification must not inherit arbitrary host environment into the temporary `new-api` server. Use `env -i` plus only the minimum build/runtime variables needed for local SQLite and Go caches. Do not pass provider, payment, CDN, analytics, Pyroscope, Redis, or production endpoint variables.
- A local embedded smoke server should disable known background external-update paths where supported, for example `CHANNEL_UPSTREAM_MODEL_UPDATE_TASK_ENABLED=false`; keep the smoke short-lived and stop it immediately after the browser check.
- Embedded release readiness is not complete until the target environment has a redacted presence-only env check and a read-only route/CDN check for `/creative/`, `/creative/sw.js`, existing `/creative/assets/*`, missing `/creative/assets/*`, `/creative/api/*`, and `/creative/relay/v1/*`.
- Embedded model/provider settings, generation dropdowns, and model benchmark tools must filter provider/profile state to the managed `new-api-creative` session-broker profile. If bootstrap/auth fails or `/creative/api/models` is unavailable, install/show an unavailable managed profile with an empty catalog rather than showing OpenTU legacy defaults.
- Embedded document/asset save status copy uses the product term **云同步** for the new-api-backed Creative sync path, not the old standalone GitHub/Gist Cloud Sync feature. Allowed managed status labels include `云同步就绪`, `正在同步到云端…`, `已同步到云端`, `已保存到此浏览器`, and `云同步不可用 · 已保存到此浏览器`. Release smoke tests must not globally ban the Chinese word `云同步`; instead they must reject concrete standalone setup markers such as `GitHub Gist`, `GitHub Token`, `Cloud Sync`, `API Key`, `API 地址`, `Base URL`, external Tuzi API hosts, and provider profile names.
- Local/intranet staging is an allowed intermediate gate when no real target exists, but the report must keep production-only surfaces as `not-run`: public route/CDN/DNS, production env presence, S3-compatible asset storage, provider/payment/channel health, publish credentials, Docker/NPM publish, deploy/upload/SSH, production `FRONTEND_BASE_URL` mode, and final sourcemap policy.
- Redacted local route checks should record method, path, status, selected headers (`content-type`, `cache-control`, `location`, `x-content-type-options` when present), and classification only. Do not record response bodies, cookies, auth headers, query secrets, provider credentials, or generated-task payloads.
- The embedded `new-api` Docker path depends on prebuilt `web/creative/dist`; the Dockerfile does not build OpenTU. CI/release orchestration must run the artifact identity gate before image build/push.
- Local Docker/container staging parity is a separate intermediate gate from local `go run` staging: build a local-only image from the candidate checkout, run it with temporary data/log paths and no production env, then run the same embedded smoke and redacted route/header table. Do not use the repository's default `docker-compose.yml` with published `calciumion/new-api:latest` or default Postgres/Redis passwords as proof of the local candidate image.
- Keep standalone OpenTU npm/CDN/hybrid release policy separate from embedded `new-api` policy. Hybrid scripts may exclude `.map` files while the embedded artifact gate can allow `sw.js.map`; production must make one explicit sourcemap decision per release path.

### 4. Validation & Error Matrix

- `index.html` references `./assets/...` after an embedded release build -> fail; rebuild with `VITE_BASE_URL=/creative/`.
- `new-api/web/creative/dist` differs from `new-api/router/web/creative/dist` -> fail; resync both targets from the same Opentu dist.
- `new-api` Go embed/static tests pass but Opentu source was changed after the dist sync -> fail release readiness; rebuild and resync before packaging.
- Missing `/creative/assets/*` returns Creative SPA HTML -> fail; hashed asset prefix is reserved for static chunks and must fail as a static miss.
- Embedded `/creative/` settings or model selectors show OpenTU standalone provider defaults such as default/OpenAI/Gemini/Tuzi/Doubao/Kling/Flux/Midjourney instead of `New API Creative` -> fail; the embedded catalog is controlled by `new-api` session-broker APIs, not by local OpenTU provider setup.
- Embedded smoke fails only because the managed save-status badge contains `云同步` -> fix the test; `云同步` is the intended new-api-backed user-facing term. Embedded smoke should fail on legacy GitHub/Gist/API-key setup surfaces, not on managed cloud-sync status copy.
- Full `git diff --check` fails only inside generated dist -> treat as release-policy risk; do not hand-normalize one target unless all artifact copies remain byte-identical.
- `pnpm e2e:smoke` cold-start fails before app readiness but prewarmed/long-wait runtime succeeds -> classify as E2E harness/readiness risk, not as proof of runtime failure.
- `sw.js.map` or other generated maps are emitted -> decide by production sourcemap policy; if forbidden, disable/strip at the Opentu artifact source and keep all embedded copies identical.
- `build-app` postprocess passes but `build-sw` later writes a new `sw.js` with standalone package/CDN markers -> fail; move or repeat postprocess after `build-sw` and add `sw.js` to the release-gate marker scan.
- `changelog.json` still contains standalone OpenTU release notes or API-key/feedback copy -> fail; rewrite it at the Opentu source dist during embedded postprocess and scan it before syncing/packaging.
- RC verification relies only on local remote-tracking refs -> warn; use `git ls-remote` to prove the pushed branch still points at the verified commit.
- Temporary embedded smoke server started with the ambient shell environment -> warn/fail no-secrets hygiene; rerun with `env -i` and a temporary SQLite DB before claiming no-secrets verification.
- Target has `FRONTEND_BASE_URL` in non-master redirect mode and `/creative/` or `/creative/assets/*` redirects away from `new-api` -> fail embedded release readiness unless that external frontend is the intended Creative host and is checked separately.
- Release check uses `pnpm run release:dry`, `npm:publish:dry`, `deploy:upload`, or SSH/rsync/scp scripts as a supposedly no-network/no-mutation gate -> fail process hygiene; use static syntax/packlist inspection or an explicitly authorized live release dry run instead.
- Local staging route checks pass and the report claims production/CDN/S3/provider/payment readiness -> fail process hygiene; local staging can only close the local route/static/API boundary.
- A `GET`/`HEAD`-only route table is used to claim mutating relay/provider behavior -> fail evidence quality unless the claim is backed by an explicit authorized check or existing smoke/log evidence that did not call providers.
- Docker image built from a checkout whose `web/creative/dist` was not first verified against OpenTU dist -> fail packaging readiness; the image will embed whatever stale files are present in `web/creative/dist`.
- Container staging uses `docker-compose.yml` defaults or a pulled `latest` image and then claims candidate parity -> fail evidence quality; it proves the compose/published image path, not the local candidate Dockerfile packaging.

### 5. Good/Base/Bad Cases

- Good: run `VITE_BASE_URL=/creative/ pnpm build:web`, `rsync -a --delete dist/apps/web/` to both `new-api` targets, verify all three artifact trees have identical relative hashes, then run `go test -count=1 .` and selected `new-api` package tests. The repeatable local command is `python3 scripts/creative_release_gate.py build-sync-check --run-new-api-tests` from `new2fly`.
- Good RC verification: live-check the three candidate refs, run the source/artifact/Go gate, run OpenTU typecheck and `NX_SKIP_NX_CACHE=true pnpm e2e:smoke`, then run `--embedded-smoke-url` against a sanitized temporary local `new-api` SQLite server.
- Good local staging when no target exists: start short-lived `new-api` with `env -i`, temporary SQLite, `GIN_MODE=release`, disabled upstream update jobs, run `python3 scripts/creative_release_gate.py check --embedded-smoke-url http://localhost:<port>/creative/`, collect a redacted `GET`/`HEAD` route/header table, stop the process, and report production-only surfaces as `not-run`.
- Good local container parity: run `python3 scripts/creative_release_gate.py check --source-diff-check`, build a local-only image from `/mnt/f/code/project/new-api`, run it with local port binding, temporary `/data` and logs, no `SQL_DSN`/`REDIS_CONN_STRING`/provider/payment/CDN/S3 env, disabled upstream update jobs, then run `--embedded-smoke-url http://localhost:<port>/creative/` and a redacted route/header table before stopping the container.
- Good persistent local staging: add a tracked Docker Compose runbook that uses a local candidate image tag, binds to `127.0.0.1` by default, stores generated local-only secrets in an ignored env file, leaves `SQL_DSN`/`REDIS_CONN_STRING`/provider/payment/CDN/S3 unset, uses named local data/log volumes, runs embedded smoke and route/header checks against the persistent URL, and documents stop/reset commands.
- Good release-env readiness: run a redacted env presence-only script, then read-only HTTP checks proving `/creative/` app-shell/static paths stay on the intended host while API/relay paths remain no-store and non-SPA.
- Base: source-only `git diff --check` passes while generated dist has known whitespace; the release gate documents the generated-artifact exception.
- Bad: copy a default `base='./'` Opentu build into `new-api`, producing `./assets/...` entry refs that do not satisfy the embedded `/creative/assets/*` route contract.
- Bad: run embedded smoke against a server inheriting production/provider/CDN environment, then call the result a no-secrets verification.
- Bad: build/push a `new-api` Docker image from a checkout where `web/creative/dist` was not freshly verified against the OpenTU artifact source.

### 6. Tests Required

- Opentu build check: assert rebuilt `dist/apps/web/index.html` contains `/creative/assets/` entry JS/CSS and no `./assets/` entry refs for embedded releases.
- Final metadata check: assert `dist/apps/web/changelog.json` and `dist/apps/web/sw.js` contain no standalone OpenTU/Tuzi/GitHub/API-key markers and no stale `sw.js.map` remains when the embedded policy strips maps.
- Cross-repo artifact check: assert source and both `new-api` target dist trees have identical relative path lists and hashes.
- `new-api` tests: run root Creative dist contract test and router static/API boundary tests after syncing artifacts.
- Browser smoke: run official smoke with a documented readiness strategy; cold readiness must use the shared Drawnix readiness wait instead of duplicated hardcoded 10s waits. Embedded browser smoke runs with `CREATIVE_EMBEDDED_BASE_URL=http://localhost:<port>/creative/ pnpm e2e:creative-embedded` or through the release gate script's `--embedded-smoke-url`.
- Release hygiene: run source-only diff checks and separately classify generated dist policy findings such as whitespace or sourcemaps. `scripts/creative_release_gate.py --source-diff-check` documents this split and `--sourcemap-policy forbid` turns maps into an explicit failure when release policy requires it.
- No-secrets hygiene: for RC checks, assert the temporary server uses local SQLite, no Redis, no `.env`/`.env.local`, sanitized `env -i`, and disabled upstream-model update task before executing embedded smoke.
- Local staging HTTP check: on the temporary localhost/intranet base URL, assert app-shell, static asset, missing asset, API, relay, service worker, and version metadata status/content-type/cache/location headers without sending provider/payment-generating requests; archive the result as local staging only.
- Container staging HTTP check: on the temporary local container base URL, assert the same app-shell/static/API/relay matrix and additionally record the local image tag/id, Dockerfile Creative dist copy evidence, sanitized runtime env shape, and cleanup state.
- Release-environment HTTP check: on the authorized target base URL, assert app-shell, static asset, missing asset, API, relay, service worker, and version metadata status/content-type/cache/location headers without sending provider/payment-generating requests.
- Publish-path check: before Docker/NPM/standalone deployment, assert artifact identity, selected sourcemap policy, credential presence by name only, and whether the chosen script is allowed to perform network or mutation.

### 7. Wrong vs Correct

#### Wrong

```text
pnpm build:web
rsync dist/apps/web/ new-api/web/creative/dist/
# index.html now references ./assets/... and only one backend dist tree was updated.
```

#### Correct

```text
VITE_BASE_URL=/creative/ pnpm build:web
rsync -a --delete dist/apps/web/ new-api/web/creative/dist/
rsync -a --delete dist/apps/web/ new-api/router/web/creative/dist/
verify all three dist trees have identical relative hashes
```

## Scenario: embedded Creative managed model policy, selectors, and fail-closed generation

### 1. Scope / Trigger

- Trigger: changing embedded OpenTU model discovery, provider settings, model selectors, generation services, MCP tools, canvas operations, or settings/default-model UI used under `/creative/`.
- This is a cross-repo contract with `new-api`: OpenTU embedded mode is only a presentation/execution client for the `new-api-creative` managed profile and must not reintroduce standalone OpenTU provider/static defaults as selectable or executable models.
- Applies to `creative-session-broker.ts`, `creative-model-policy-resolver.ts`, `creative-embedded-model-guard.ts`, `creative-display-policy.ts`, `runtime-model-discovery.ts`, `settings-manager.ts`, Gemini/runtime API wrappers such as `sendChatWithGemini`, AI input/ChatDrawer selectors, settings dialog, generation services, MCP tools, and canvas operations.

### 2. Signatures

- Managed profile constants:
  - `CREATIVE_MANAGED_PROFILE_ID == "new-api-creative"`
  - `CREATIVE_MANAGED_PROFILE_NAME == "New API Creative"`
- Bootstrap/catalog inputs:
  - `GET /creative/api/bootstrap` supplies `modelPolicy` and `modelPolicyVersion`.
  - `GET /creative/api/models` supplies the current user's logical model catalog.
- Resolver/guard functions:
  - `setCreativeModelPolicyFromBootstrap(payload)`
  - `resetCreativeModelPolicySnapshot()`
  - `getCreativePolicyModels(type, fullPool)`
  - `getCreativePolicyDefaultModel(type, fullPool)`
  - `getCreativePolicyDefaultModelForGenerationType(generationType, fullPool)`
  - `resolveCreativeEmbeddedModelForGeneration(type, requestedModel?, requestedModelRef?)`
- Embedded selection refs:
  - valid executable refs must point to `profileId: "new-api-creative"` or an equivalent managed `sourceProfileId` created from the catalog.

### 3. Contracts

- In embedded mode, model lists are projections of the managed catalog plus effective policy ordering. Static OpenTU lists (`CHAT_MODELS`, `IMAGE_MODELS`, `VIDEO_MODELS`, `AUDIO_MODELS`, `DEFAULT_*_MODEL_ID`) are standalone defaults only.
- Static model metadata may enrich labels, icons, vendors, tags, and descriptions for catalog IDs already supplied by `new-api`; static entries absent from the managed catalog must not become selectable, persisted as active defaults, or sent to generation.
- Selection/default order in embedded mode is: valid persisted/user preference when still in the managed catalog, valid admin policy default/recommended order, then remaining managed catalog models sorted by display priority. If no valid model exists for a modality, the UI shows an unavailable state.
- `creative-session-broker.ts` must install policy before reconciling persisted selections; bootstrap/catalog errors or empty model pools must install/show the unavailable managed profile and reset policy instead of falling back to legacy providers.
- Every generation or direct AI runtime entry point that can execute in embedded mode must call a central guard before relay/provider calls. This includes wrappers that build runtime config for direct chat/text utilities, not only high-level generation services. Missing or stale requested model IDs must throw a local unavailable error and must not call the provider relay or generic API transport.
- Settings and defaults UI may display the managed catalog and policy state, but embedded settings must not save standalone provider presets or static fallback model IDs as active Creative defaults.
- Standalone OpenTU behavior is not changed by this contract; standalone provider discovery/static defaults may continue outside `isCreativeEmbeddedMode()`.

### 4. Validation & Error Matrix

- Embedded bootstrap returns catalog `["managed-image"]` and static catalog contains `gpt-image-2-vip` -> selectors show only `managed-image`; `gpt-image-2-vip` may only be used as metadata if IDs match.
- Embedded bootstrap returns policy default `image: "managed-image"` -> image selectors and generation default choose `managed-image`.
- Persisted selection points to `removed-image` -> reconciliation replaces it with a valid policy/catalog model or marks image generation unavailable; it is not submitted silently.
- Empty catalog / bootstrap error -> `New API Creative` unavailable profile, disabled dropdowns/submit buttons, and local fail-closed errors before relay calls or direct chat/text API transports.
- Requested model is not in `getSelectableModels(type)` -> `resolveCreativeEmbeddedModelForGeneration` throws; network provider call count remains zero in tests.
- Component has no explicit `models` prop in embedded mode -> it must not default to static `IMAGE_MODELS` / `IMAGE_VIDEO_MODELS`; it uses managed discovery/policy or stays empty/disabled.
- Non-embedded standalone mode -> existing static defaults and provider profiles remain available.

### 5. Good/Base/Bad Cases

- Good: `/creative/api/models` returns `gpt-4o` and `gpt-image-1`; AI input, ChatDrawer, settings, MCP text/image tools, and canvas image operations all show/use those logical IDs through `new-api-creative`.
- Base: admin policy recommends `suno_music`, but the current user's channel groups do not expose it; audio tools show unavailable or use another available audio model, never the stale recommendation.
- Bad: embedded `ModelDropdown` has no `models` prop and falls back to `IMAGE_MODELS`, showing `gpt-image-2-vip` despite that ID being absent from `/creative/api/models`.
- Bad: task queue or canvas operation sees no requested model and submits `DEFAULT_VIDEO_MODEL_ID` directly to the relay in embedded mode.

### 6. Tests Required

- Resolver tests for bootstrap policy normalization, default/recommended ordering, stale/static-only exclusion, `agent` -> text pool behavior, and empty policy behavior.
- Session broker tests for policy install before persisted-selection reconciliation, empty catalog/unavailable profile, bootstrap error reset, and managed catalog-only profiles.
- Runtime discovery/settings tests proving embedded selectable/preferred/default models come only from `new-api-creative` and no legacy/static provider fallback is used.
- Component tests for AI input dropdown/selector, ChatDrawer selector, and settings dialog empty/managed pool states.
- Generation/runtime tests for text/image/video/audio services, direct Gemini/chat wrappers, task queue, fallback executor, MCP tools, and canvas operations proving invalid or missing embedded models fail before network relay/provider calls.
- Cross-repo release gate after OpenTU changes: `VITE_BASE_URL=/creative/ pnpm build:web`, sync both `new-api` dist trees, then `python3 scripts/creative_release_gate.py build-sync-check --run-new-api-tests`.

### 7. Wrong vs Correct

#### Wrong

```text
if (isCreativeEmbeddedMode() && models.length === 0) {
  return IMAGE_MODELS; // static standalone fallback
}
submit({ model: DEFAULT_IMAGE_MODEL_ID });
```

#### Correct

```text
if (isCreativeEmbeddedMode()) {
  const resolved = resolveCreativeEmbeddedModelForGeneration('image', requestedModel, requestedRef);
  // throws a local unavailable error when the managed catalog has no valid image model
  return submit({ model: resolved.modelId, modelRef: resolved.modelRef });
}
```
