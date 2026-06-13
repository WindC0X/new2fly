> Superseded note (2026-06-12): this file recorded the focused post-fix recheck. It is superseded by `postfix-true-final-goal-attainment-2026-06-12.md`, which ran the requested full post-fix goal-attainment audit and found remaining current blockers.

# Current Final Goal-Attainment Audit and Post-Fix Recheck

Date: 2026-06-12

## Scope correction

The final audit question is: **does the current project meet its development goals, and what current project problems remain?** It is not merely a checklist of whether earlier findings were patched.

Evidence boundaries:

- Current source/docs/spec/tests in `new2fly`, `new-api`, and `opentu`.
- No previous audit reports, archived task reports, `.codebuddy` reports, or prior conversation conclusions were treated as authoritative evidence.
- No secrets were read, no production/provider endpoints were called.

## Dynamic workflow evidence

### Current-source compact goal-attainment audit

- Workflow: `.codex-flow/generated/newapi-opentu-true-goal-attainment-compact-2026-06-12.workflow.ts`
- Journal: `.codex-flow/journal/newapi-opentu-true-goal-attainment-compact-2026-06-12.jsonl`
- Branches: 5/5 usable (`goal-product-contract-docs`, `new-api-runtime-security-contract`, `opentu-runtime-frontend-contract`, `cross-repo-contract-integration`, `quality-ops-release-readiness`).
- Result before final fixes: partial; identified current blockers in MJ error redaction and Creative CDN/origin-first contract drift, plus release-readiness gaps.

### Post-fix focused goal blocker recheck

- Workflow: `.codex-flow/generated/newapi-opentu-postfix-goal-blocker-recheck-2026-06-12.workflow.ts`
- Journal: `.codex-flow/journal/newapi-opentu-postfix-goal-blocker-recheck-2026-06-12.jsonl`
- Branches: 3/3 usable (`MJ session-broker`, `Creative hybrid CDN/origin-first`, `release readiness classification`).
- Result after final fixes: `goal_met_with_gaps` with no confirmed current application/code blockers. Remaining items are release-readiness gaps.

## Final fixes applied after the compact audit

### `opentu`

- `packages/drawnix/src/services/model-adapters/mj-image-adapter.ts`
  - Session-broker MJ submit/fetch non-unsupported failures now throw status-only errors (`MJ submit failed: <status>`, `MJ query failed: <status>`) without reading or embedding raw backend response bodies.
- `packages/drawnix/src/services/model-adapters/mj-image-adapter.test.ts`
  - Added regression tests for submit 500 and fetch 502 sensitive backend body redaction.
- `apps/web/src/sw/app-shell-routing.ts`
  - HTML documents are now origin-first preload targets, matching Creative same-origin/CDN boundary.
- `apps/web/src/sw/app-shell-routing.spec.ts`
  - Added/updated tests proving HTML and release metadata are origin-first while hashed static assets/icons remain CDN-first.
- `docs/CDN_DEPLOYMENT.md`, `docs/NPM_CDN_DEPLOY.md`, `docs/CREATIVE_EMBED_DEPLOYMENT.md`
  - Clarified that HTML, SW, runtime config, release metadata, and Creative API/relay remain origin-first.
  - Clarified that `manifest.json` / `version.json` in the npm/CDN package are static fallback/install copies, not runtime CDN rewrite targets.
  - Removed stale hardcoded `aitu-app@0.5.x` examples in the touched deployment docs.
- `scripts/publish-npm.js`
  - Generated npm README now documents the static-asset-only boundary.
  - `--dry-run` now executes `npm pack --dry-run --json` to verify the real packlist.

### `new2fly` Trellis specs

- `.trellis/spec/frontend/creative-async-mj-relay.md`
  - Aligned the MJ missing-idempotency-key contract with current safer behavior: fail before fetch; never generate random keys or derive keys from prompt/credentials.
  - Required tests now include sanitized non-unsupported relay errors.
- `.trellis/spec/frontend/creative-asset-sync.md`
  - Aligned hybrid CDN contract with runtime origin-first behavior for HTML/release metadata and CDN rewrite only for allowed public static assets.

## Current verdict

- **Development goal attainment:** materially met for the audited Creative/new-api/opentu integration after the final fixes.
- **Confirmed current application/code blockers:** none found by the post-fix dynamic recheck and main-thread verification.
- **Current project problems / release-readiness gaps:**
  1. Three repositories still contain many uncommitted/untracked changes. This is expected during the active session but must be resolved before release sign-off.
  2. Full release CI was not fully executed in this pass (`go test ./...`, full `pnpm check/lint/build/e2e`, real browser/provider/Redis/S3/CDN smoke remain follow-ups).
  3. Local test warnings remain known environment warnings: `.npmrc` `${NPM_TOKEN}`, crypto fallback, `indexedDB is not defined`, and a `postmessage-duplex` sourcemap warning.

## Fresh verification after final fixes

```bash
cd /mnt/f/code/project/opentu
pnpm --filter @aitu/drawnix exec vitest run src/services/model-adapters/mj-image-adapter.test.ts --no-file-parallelism --maxWorkers=1 --minWorkers=1
```

Result: exit 0; 1 file / 7 tests passed.

```bash
cd /mnt/f/code/project/opentu
pnpm exec vitest run apps/web/src/sw/app-shell-routing.spec.ts --no-file-parallelism --maxWorkers=1 --minWorkers=1
```

Result: exit 0; 1 file / 5 tests passed.

```bash
cd /mnt/f/code/project/opentu
pnpm nx run drawnix:typecheck
```

Result: exit 0; `NX Successfully ran target typecheck for project drawnix`.

```bash
cd /mnt/f/code/project/opentu
pnpm --filter @aitu/drawnix exec vitest run \
  src/services/provider-routing/provider-transport.session-broker.test.ts \
  src/services/creative-session-broker.test.ts \
  src/services/__tests__/audio-api-service.test.ts \
  src/services/__tests__/video-api-service.session-broker.test.ts \
  src/services/__tests__/media-api-routing.test.ts \
  src/services/model-adapters/mj-image-adapter.test.ts \
  src/services/creative-document-assets.test.ts \
  src/services/creative-document-sync.test.ts \
  --no-file-parallelism --maxWorkers=1 --minWorkers=1
```

Result: exit 0; 8 files / 103 tests passed.

```bash
cd /mnt/f/code/project/opentu
node --check scripts/publish-npm.js
node scripts/publish-npm.js --dry-run --skip-build
```

Result: both exit 0. Dry run executed `npm pack --dry-run --json`; packlist contained static allowed files such as `assets/**`, `icons/**`, `logo/**`, `favicon.ico`, `manifest.json`, `version.json`, `README.md`, and `package.json`; it did not include `index.html`, `sw.js`, `init.json`, or Creative API/relay paths.

```bash
cd /mnt/f/code/project/opentu && git diff --check
cd /mnt/f/code/project/new-api && git diff --check
cd /mnt/f/code/project/new2fly && git diff --check
```

Result: all exit 0.

## Prior unchanged backend verification retained

No `new-api` code was changed after the earlier backend verification in this pass. The retained backend verification remains:

```bash
cd /mnt/f/code/project/new-api
go test -count=1 ./router ./middleware ./controller ./model ./service ./relay/...
```

Result: exit 0.

## Recommended next actions

1. Before release sign-off, freeze all three repositories: review, commit, or explicitly exclude untracked tooling/build artifacts (`.cache/`, `.codegraph/`, `.codex-flow/`, `audio-test.pptx`, etc.).
2. Run full release gates if required by the release target: `go test ./...`, opentu full check/lint/build/e2e, and deployment smoke with real browser + configured Redis/S3-compatible storage/provider-like channels.
3. Keep the post-fix dynamic recheck journal and this report as the current final audit evidence; do not rely on earlier broad timed-out workflow conclusions.
