# Current Release Evidence Pack — 2026-06-13

## Scope

Release-readiness verification for current sibling repos:

- new2fly: `/mnt/f/code/project/new2fly`
- new-api: `/mnt/f/code/project/new-api`
- opentu: `/mnt/f/code/project/opentu`

No secrets read. No provider/payment/CDN/production endpoints called.

## Recent work commits

- new-api: `ba920ee fix(creative): harden embedded relay and asset lifecycle`
- opentu: `570af4be fix(drawnix): harden creative session broker flows`
- new2fly: `91bffcf docs(spec): record creative hardening contracts`
- new2fly: `971e4ff chore(task): record creative remediation archives`
- new2fly archive/journal: `d3b48b8`, `04fe0ba`

## Git status after verification commands

- new2fly: untracked `.cache/` plus current task dir.
- new-api: untracked `.codegraph/`, `.codex-flow/` only.
- opentu: tracked `apps/web/public/version.json` changed only in `buildTime` due `pnpm build:web`; untracked `packages/drawnix/audio-test.pptx`.

## Local verification results

### Backend

Command:

```bash
cd /mnt/f/code/project/new-api
(go test -count=1 ./router ./middleware ./controller ./model ./service ./relay/... && go build ./...)
go test -count=1 .
```

Result: passed.

Logs:

- `verification/new-api-release-build-test-2026-06-13.log`
- `verification/new-api-root-creative-dist-test-2026-06-13.log`

### Frontend type/build

Commands:

```bash
cd /mnt/f/code/project/opentu
pnpm nx run drawnix:typecheck
pnpm build:web
```

Results:

- `drawnix:typecheck`: passed.
- `build:web`: passed; generated `dist/apps/web/index.html`, `sw.js`, `version.json`, `idle-prefetch-manifest.json`.

Warnings:

- `.npmrc` warns `${NPM_TOKEN}` missing, but build still succeeds; no secret read.
- Sass `@import` / global built-in deprecation warnings.
- Vite chunk-size warnings for large chunks.

Logs:

- `verification/opentu-drawnix-typecheck-release-2026-06-13.log`
- `verification/opentu-build-web-2026-06-13.log`

### Browser smoke

Command:

```bash
cd /mnt/f/code/project/opentu
pnpm e2e:smoke
```

First cold run: failed. Both smoke specs timed out waiting for `.drawnix` at 10s. Page snapshot showed boot overlay at `82%` and SEO content still visible.

Diagnostic run with local server showed initial page had root empty and boot overlay at 82% after 15s while Vite was still cold-compiling many modules.

Warm diagnostic after server finished compiling:

- Console warning: `The database "aitu-workspace" can't be downgraded from version 9 to version 8.`
- Final DOM after 60s: `htmlClass="app-ready aitu-toolbar-dock-left"`, boot removed, `rootChildCount=1`, `.drawnix` count 1, SEO hidden.

Warm rerun of `pnpm e2e:smoke`: passed, 2 tests / 2 passed.

Logs:

- `verification/opentu-playwright-smoke-2026-06-13.log`
- `verification/opentu-playwright-smoke-diagnostics-2026-06-13.log`
- `verification/opentu-playwright-smoke-diagnostics-warm-2026-06-13.log`
- `verification/opentu-playwright-smoke-warm-2026-06-13.log`

Interpretation: browser runtime can pass, but E2E harness has a cold-start timeout/prewarm risk. IndexedDB downgrade warning indicates local browser profile/version residue but did not block warm startup.

## Cross-repo artifact contract

`opentu` build output after current source:

- `/mnt/f/code/project/opentu/dist/apps/web/index.html` timestamp 2026-06-13
- `/mnt/f/code/project/opentu/dist/apps/web/sw.js` timestamp 2026-06-13
- `/mnt/f/code/project/opentu/dist/apps/web/version.json` buildTime `2026-06-13T00:31:47.580Z`

`new-api` embedded Creative dist currently used by Go embed:

- `/mnt/f/code/project/new-api/router/web/creative/dist/index.html` timestamp 2026-06-10
- `/mnt/f/code/project/new-api/router/web/creative/dist/sw.js` timestamp 2026-06-10
- `/mnt/f/code/project/new-api/router/web/creative/dist/version.json` buildTime `2026-06-09T17:28:42.660Z`

`new-api` also has root package test `main_creative_dist_test.go`, which verifies `new-api/web/creative/dist` and `new-api/router/web/creative/dist` match each other. That passed. However, no tested pipeline step in this session copied sibling `opentu/dist/apps/web` into both `new-api` embedded dist locations after the latest frontend fixes.

Relevant evidence:

- `new-api/Dockerfile` says `web/creative/dist` is a prebuilt opentu artifact provided by CI pipeline and is copied into Docker image; it is not built in Dockerfile.
- Historical task note says after modifying opentu source, rebuild with `/creative/`, copy dist to new-api, rebuild new-api.
- Current session did not execute such copy/sync.

Log:

- `verification/cross-repo-artifact-contract-2026-06-13.log`

Interpretation: if releasing current `new-api` embedded Creative artifact without a CI sync step, the frontend fixes from opentu commit `570af4be` are not in the embedded Creative page. This is a release blocker unless the release pipeline has a guaranteed external sync step not visible in current commands.

## Config readiness

Observed from `new-api/.env.example` and docs:

- `FRONTEND_BASE_URL` documented as non-Creative SPA fallback; Creative API/relay route is local.
- `CREATIVE_VIDEO_RELAY_ENABLED=false` default.
- `CREATIVE_ASSET_SYNC_ENABLED=false` default.
- `CREATIVE_ASSET_ROLLOUT_MODE=local` default.
- `CREATIVE_ASSET_STORAGE=database`; production must use `s3-compatible`.
- S3-compatible settings documented: endpoint, region, bucket, prefix, access key id, secret key, force path style.

Interpretation: config docs are substantially present and default-safe; production readiness still requires real env validation outside this no-secrets session.

## Candidate release-gate findings

1. HIGH candidate: Embedded Creative dist in new-api is stale relative to current opentu source/build; release requires syncing generated artifacts or proving CI sync exists.
2. MEDIUM: Cold Playwright smoke can fail due Vite dev cold compilation and 10s `.drawnix` wait, though warm smoke passes.
3. MEDIUM/LOW: `.npmrc` warns missing `${NPM_TOKEN}` during pnpm commands; harmless for local build but release npm publish needs env secret in CI.
4. LOW: Sass and chunk-size warnings.
5. LOW/MEDIUM: local IndexedDB downgrade warning from reused browser profile; warm startup still succeeds.
