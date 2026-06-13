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
- Artifact source:
  - `opentu/dist/apps/web/`
- Local no-secrets gate script:
  - `cd /mnt/f/code/project/new2fly`
  - `python3 scripts/creative_release_gate.py check`
  - `python3 scripts/creative_release_gate.py build-sync-check --run-new-api-tests` for the full local rebuild/sync/test gate
  - add `--embedded-smoke-url http://localhost:<port>/creative/` when a local `new-api` server is already running and browser smoke should be included
- Remote-backed RC verification:
  - prove candidate refs with live `git ls-remote` output before reporting a pushed branch as verified
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
- Backend route contract:
  - `new-api` serves the SPA under `/creative/`.
  - `new-api` serves hashed chunks under `/creative/assets/*`; missing `/creative/assets/*` paths are static 404s, not SPA fallback.
  - `new-api` keeps `/creative/api/*` and `/creative/relay/v1/*` as API/relay routes, not SPA/static fallbacks.
- Release-environment readiness checks:
  - if a target environment sets `FRONTEND_BASE_URL`, prove the node mode and route behavior before claiming embedded `/creative/` is available; non-master redirect mode only registers Creative API/relay locally and may redirect `/creative/` static/app-shell paths to the external frontend
  - do not treat OpenTU `release:dry`, `npm:publish:dry`, or deploy upload scripts as no-network/no-mutation checks; they may contact registries, rewrite `dist/`, or use SSH/rsync/scp paths
  - verify publish credentials by presence or identity only (`NPM_TOKEN`, `DOCKERHUB_USERNAME`, `DOCKERHUB_TOKEN`, `GITHUB_TOKEN`), never by printing secret values

### 3. Contracts

- Embedded Creative builds must use `VITE_BASE_URL=/creative/`; the default `base='./'` build is valid for standalone static serving but not for the `new-api` embedded contract.
- The embedded `index.html` must reference entry JS/CSS under `/creative/assets/...`.
- `opentu/dist/apps/web/`, `new-api/web/creative/dist/`, and `new-api/router/web/creative/dist/` must contain the same relative files with the same bytes after sync.
- `new-api/web/creative/dist/index.html`, `sw.js`, and `version.json` must match `new-api/router/web/creative/dist/*`.
- `sw.js` must register and run from `/creative/sw.js` when loaded from `/creative/`; runtime metadata (`version.json`, manifests, `sw.js`) stays same-origin.
- Generated artifact files may contain build-tool whitespace or sourcemaps; release gates must either accept generated-artifact policy exceptions or enforce normalization at the Opentu build-output source, not by manually editing only `new-api` copies.
- Source whitespace checks and generated-dist checks are separate gates: run source-only `git diff --check` for hand-written code, and enforce generated dist by byte identity across `opentu/dist/apps/web/`, `new-api/web/creative/dist/`, and `new-api/router/web/creative/dist/`.
- `apps/web/public/version.json` buildTime changes caused by local `pnpm build:web` are build side effects unless intentionally part of an Opentu source release; do not commit source timestamp churn blindly.
- No-secrets RC verification must not inherit arbitrary host environment into the temporary `new-api` server. Use `env -i` plus only the minimum build/runtime variables needed for local SQLite and Go caches. Do not pass provider, payment, CDN, analytics, Pyroscope, Redis, or production endpoint variables.
- A local embedded smoke server should disable known background external-update paths where supported, for example `CHANNEL_UPSTREAM_MODEL_UPDATE_TASK_ENABLED=false`; keep the smoke short-lived and stop it immediately after the browser check.
- Embedded release readiness is not complete until the target environment has a redacted presence-only env check and a read-only route/CDN check for `/creative/`, `/creative/sw.js`, existing `/creative/assets/*`, missing `/creative/assets/*`, `/creative/api/*`, and `/creative/relay/v1/*`.
- The embedded `new-api` Docker path depends on prebuilt `web/creative/dist`; the Dockerfile does not build OpenTU. CI/release orchestration must run the artifact identity gate before image build/push.
- Keep standalone OpenTU npm/CDN/hybrid release policy separate from embedded `new-api` policy. Hybrid scripts may exclude `.map` files while the embedded artifact gate can allow `sw.js.map`; production must make one explicit sourcemap decision per release path.

### 4. Validation & Error Matrix

- `index.html` references `./assets/...` after an embedded release build -> fail; rebuild with `VITE_BASE_URL=/creative/`.
- `new-api/web/creative/dist` differs from `new-api/router/web/creative/dist` -> fail; resync both targets from the same Opentu dist.
- `new-api` Go embed/static tests pass but Opentu source was changed after the dist sync -> fail release readiness; rebuild and resync before packaging.
- Missing `/creative/assets/*` returns Creative SPA HTML -> fail; hashed asset prefix is reserved for static chunks and must fail as a static miss.
- Full `git diff --check` fails only inside generated dist -> treat as release-policy risk; do not hand-normalize one target unless all artifact copies remain byte-identical.
- `pnpm e2e:smoke` cold-start fails before app readiness but prewarmed/long-wait runtime succeeds -> classify as E2E harness/readiness risk, not as proof of runtime failure.
- `sw.js.map` or other generated maps are emitted -> decide by production sourcemap policy; if forbidden, disable/strip at the Opentu artifact source and keep all embedded copies identical.
- RC verification relies only on local remote-tracking refs -> warn; use `git ls-remote` to prove the pushed branch still points at the verified commit.
- Temporary embedded smoke server started with the ambient shell environment -> warn/fail no-secrets hygiene; rerun with `env -i` and a temporary SQLite DB before claiming no-secrets verification.
- Target has `FRONTEND_BASE_URL` in non-master redirect mode and `/creative/` or `/creative/assets/*` redirects away from `new-api` -> fail embedded release readiness unless that external frontend is the intended Creative host and is checked separately.
- Release check uses `pnpm run release:dry`, `npm:publish:dry`, `deploy:upload`, or SSH/rsync/scp scripts as a supposedly no-network/no-mutation gate -> fail process hygiene; use static syntax/packlist inspection or an explicitly authorized live release dry run instead.

### 5. Good/Base/Bad Cases

- Good: run `VITE_BASE_URL=/creative/ pnpm build:web`, `rsync -a --delete dist/apps/web/` to both `new-api` targets, verify all three artifact trees have identical relative hashes, then run `go test -count=1 .` and selected `new-api` package tests. The repeatable local command is `python3 scripts/creative_release_gate.py build-sync-check --run-new-api-tests` from `new2fly`.
- Good RC verification: live-check the three candidate refs, run the source/artifact/Go gate, run OpenTU typecheck and `NX_SKIP_NX_CACHE=true pnpm e2e:smoke`, then run `--embedded-smoke-url` against a sanitized temporary local `new-api` SQLite server.
- Good release-env readiness: run a redacted env presence-only script, then read-only HTTP checks proving `/creative/` app-shell/static paths stay on the intended host while API/relay paths remain no-store and non-SPA.
- Base: source-only `git diff --check` passes while generated dist has known whitespace; the release gate documents the generated-artifact exception.
- Bad: copy a default `base='./'` Opentu build into `new-api`, producing `./assets/...` entry refs that do not satisfy the embedded `/creative/assets/*` route contract.
- Bad: run embedded smoke against a server inheriting production/provider/CDN environment, then call the result a no-secrets verification.
- Bad: build/push a `new-api` Docker image from a checkout where `web/creative/dist` was not freshly verified against the OpenTU artifact source.

### 6. Tests Required

- Opentu build check: assert rebuilt `dist/apps/web/index.html` contains `/creative/assets/` entry JS/CSS and no `./assets/` entry refs for embedded releases.
- Cross-repo artifact check: assert source and both `new-api` target dist trees have identical relative path lists and hashes.
- `new-api` tests: run root Creative dist contract test and router static/API boundary tests after syncing artifacts.
- Browser smoke: run official smoke with a documented readiness strategy; cold readiness must use the shared Drawnix readiness wait instead of duplicated hardcoded 10s waits. Embedded browser smoke runs with `CREATIVE_EMBEDDED_BASE_URL=http://localhost:<port>/creative/ pnpm e2e:creative-embedded` or through the release gate script's `--embedded-smoke-url`.
- Release hygiene: run source-only diff checks and separately classify generated dist policy findings such as whitespace or sourcemaps. `scripts/creative_release_gate.py --source-diff-check` documents this split and `--sourcemap-policy forbid` turns maps into an explicit failure when release policy requires it.
- No-secrets hygiene: for RC checks, assert the temporary server uses local SQLite, no Redis, no `.env`/`.env.local`, sanitized `env -i`, and disabled upstream-model update task before executing embedded smoke.
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
