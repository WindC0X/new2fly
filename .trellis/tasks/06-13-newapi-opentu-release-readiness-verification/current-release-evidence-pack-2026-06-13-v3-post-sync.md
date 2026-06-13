# Current Release Evidence Pack v3 — 2026-06-13 Post-Sync

## Scope and safety

Release-readiness verification for sibling repos:

- new2fly: `/mnt/f/code/project/new2fly`
- new-api: `/mnt/f/code/project/new-api`
- opentu: `/mnt/f/code/project/opentu`

No secrets were read. No provider/payment/CDN/production endpoints were called. Localhost browser/dev-server checks only.

## Change since v2 evidence pack

The previous dynamic workflow found a HIGH blocker: `new-api` embedded Creative dist was stale relative to current `opentu` build output. This session resolved that blocker by rebuilding OpenTU with the backend-required base and syncing the generated dist into both embedded new-api locations:

```bash
cd /mnt/f/code/project/opentu
VITE_BASE_URL=/creative/ pnpm build:web
rsync -a --delete /mnt/f/code/project/opentu/dist/apps/web/ /mnt/f/code/project/new-api/web/creative/dist/
rsync -a --delete /mnt/f/code/project/opentu/dist/apps/web/ /mnt/f/code/project/new-api/router/web/creative/dist/
```

Why `/creative/` base: `new-api/main_creative_dist_test.go` and `router/web_router_test.go` require `index.html` to reference entry JS/CSS under `/creative/assets/...`. A plain `pnpm build:web` defaulted to `base='./'`, which would fail the embedded contract.

## Embedded artifact state after sync

Post-sync inspection:

- `new-api/web/creative/dist`: 223 files.
- `new-api/router/web/creative/dist`: 223 files.
- Both `index.html`, `sw.js`, and `version.json` hashes match between the two embedded dist trees.
- Both embedded `index.html` files reference:
  - `/creative/assets/index-Bs1ESiJC.js`
  - `/creative/assets/index-Bhsy9ZA3.css`
- Both embedded `version.json` files have buildTime `2026-06-13T02:21:22.501Z`.
- A new `sw.js.map` is present because it is emitted by the current OpenTU service-worker build.

Evidence logs:

- `verification/opentu-build-web-creative-base-2026-06-13.log`
- `verification/opentu-dist-creative-base-inspection-2026-06-13.log`
- `verification/new-api-creative-dist-rsync-2026-06-13.log`

## Local verification results after sync

### new-api

Command:

```bash
cd /mnt/f/code/project/new-api
go test -count=1 .
go test -count=1 ./router ./middleware ./controller ./model ./service ./relay/... && go build ./...
```

Result: passed.

Important precheck: embedded root/router Creative dist hashes and `/creative/assets` entry refs were checked before the Go tests.

Evidence log:

- `verification/new-api-post-dist-sync-tests-2026-06-13.log`

### opentu build/typecheck

Commands:

```bash
cd /mnt/f/code/project/opentu
VITE_BASE_URL=/creative/ pnpm build:web
pnpm nx run drawnix:typecheck
```

Results: passed.

Expected warnings observed:

- `.npmrc` warns `${NPM_TOKEN}` is missing. No secret was read; local build still passed. Release/publish CI must provide it when needed.
- Sass `@import` / global built-in deprecation warnings.
- Vite large chunk warnings.

Evidence logs:

- `verification/opentu-build-web-creative-base-2026-06-13.log`
- `verification/opentu-drawnix-typecheck-post-dist-sync-2026-06-13.log`

### Browser smoke / runtime

Official command:

```bash
cd /mnt/f/code/project/opentu
pnpm e2e:smoke
```

Observed sequence after sync:

1. Cold run failed: both specs timed out waiting for `.drawnix` at the configured 10s expect timeout.
2. Immediate rerun without a manually prewarmed server also failed the same way.
3. Manual Playwright diagnostic against a separately started dev server showed:
   - page at 10s and 17.5s was at boot overlay `82%`;
   - `.drawnix` became visible at about 18.0s;
   - final DOM had `.drawnix` count 1;
   - console warning: `The database "aitu-workspace" can't be downgraded from version 9 to version 8.`
4. Official `pnpm e2e:smoke` against the already-warmed existing dev server passed: 2 tests / 2 passed.

Interpretation: runtime can pass, but the Playwright harness has a reproducible cold-start/prewarm sensitivity because the app reaches `.drawnix` after the hardcoded 10s expect timeout on this machine.

Evidence logs:

- `verification/opentu-e2e-smoke-post-dist-sync-2026-06-13.log`
- `verification/opentu-e2e-smoke-warm-rerun-post-dist-sync-2026-06-13.log`
- `verification/opentu-manual-playwright-readiness-diagnostic-2026-06-13.log`
- `verification/opentu-manual-playwright-readiness-diagnostic-2026-06-13.png`
- `verification/opentu-e2e-smoke-prewarmed-existing-server-2026-06-13.log`

## Git / release-freeze state

After restoring OpenTU `apps/web/public/version.json` buildTime side effect to HEAD:

- new2fly: untracked `.cache/` and the active Trellis task directory.
- new-api: generated Creative dist changes only, plus local tool dirs `.codegraph/` and `.codex-flow/`.
- opentu: untracked `packages/drawnix/audio-test.pptx` only.

Concise counts for new-api tracked generated dist update:

- 88 deleted old hashed assets.
- 72 modified files.
- 92 untracked new files, all generated dist or local tool dirs.

`git diff --check` notes:

- Full `git diff --check` in new-api reports many trailing-whitespace findings inside generated Creative dist files (mostly `sw-debug/*`, `user-manual/index.html`, `versions.html`). This appears to come directly from the OpenTU dist output. I did not manually whitespace-normalize generated artifacts because doing so would make new-api embedded dist diverge from the built OpenTU artifact.
- Source-only diff-check excluding `web/creative/dist/**` and `router/web/creative/dist/**` passed for new-api; opentu and new2fly diff-check passed.

Evidence logs:

- `verification/git-diff-check-post-dist-sync-2026-06-13.log` (large, includes generated whitespace findings)
- `verification/git-diff-check-source-only-2026-06-13.log`

## Config readiness summary

Based on code/docs/examples from previous evidence collection:

- `FRONTEND_BASE_URL` is non-Creative SPA fallback only; Creative API/relay route remains local.
- `CREATIVE_VIDEO_RELAY_ENABLED=false` default.
- `CREATIVE_ASSET_SYNC_ENABLED=false` default.
- `CREATIVE_ASSET_ROLLOUT_MODE=local` default.
- `CREATIVE_ASSET_STORAGE=database`; production must use `s3-compatible` with endpoint/region/bucket/prefix/access-key/secret config.
- This no-secrets session did not validate real production S3/NPM/CDN credentials or health.

## Candidate final release-gate findings

1. HIGH: stale embedded dist blocker appears resolved in the current worktree after `/creative/` rebuild + dual rsync + new-api tests.
2. MEDIUM: official Playwright smoke is not cold-start robust on this machine; runtime passes only after prewarm or a longer wait.
3. MEDIUM: full `git diff --check` fails on generated Creative dist whitespace; source-only diff-check passes. Decide whether release process allows generated artifact whitespace or needs an artifact normalization step in CI.
4. MEDIUM/LOW: production env/S3/NPM_TOKEN/CDN credentials were not live-validated by design; require CI/release-environment validation outside this no-secrets task.
5. LOW: Sass deprecation and chunk-size warnings.
6. LOW: IndexedDB downgrade warning appears tied to local browser profile residue and did not block warmed smoke.

## Provisional verdict for dynamic workflow to challenge

`mostly_ready` if generated-dist whitespace and cold E2E harness behavior are accepted as non-runtime release risks; `not_ready` if the release gate requires cold `pnpm e2e:smoke` and full `git diff --check` to pass without exclusions.
