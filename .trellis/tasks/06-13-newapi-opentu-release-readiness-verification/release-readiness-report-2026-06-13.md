# Release Readiness Report — new-api + opentu — 2026-06-13

## Verdict

**Final verdict: `mostly_ready`**

No remaining HIGH release blocker was confirmed after the embedded Creative dist sync. The previous HIGH blocker (stale `new-api` embedded Creative artifact) is resolved in the current worktree.

This is **not** `release_ready` yet because two release-gate policy items still need an explicit decision or CI-side validation:

1. Official `pnpm e2e:smoke` is cold-start sensitive on this machine: cold runs fail at the hardcoded 10s `.drawnix` wait, while manual long-wait and prewarmed official smoke pass.
2. Full `git diff --check` reports trailing whitespace inside generated Creative dist files; source-only diff-check passes.

If the release gate requires cold `pnpm e2e:smoke` and full diff-check with generated files included, treat the current state as `not_ready` until those gates are changed or fixed. If the gate accepts prewarming/readiness wait and generated-artifact diff-check exceptions, the code/artifact state is ready for the next controlled release validation stage.

## What changed during this pass

Rebuilt OpenTU with the backend-required embedded base and synced generated artifacts:

```bash
cd /mnt/f/code/project/opentu
VITE_BASE_URL=/creative/ pnpm build:web
rsync -a --delete dist/apps/web/ /mnt/f/code/project/new-api/web/creative/dist/
rsync -a --delete dist/apps/web/ /mnt/f/code/project/new-api/router/web/creative/dist/
```

Why: `new-api` contract tests require entry JS/CSS under `/creative/assets/...`; a default `pnpm build:web` produces `./assets/...` entry refs and is not valid for the embedded route contract.

## HIGH findings

None confirmed after post-sync verification.

Resolved HIGH:

- **Stale embedded Creative dist**: fixed. `opentu/dist/apps/web`, `new-api/web/creative/dist`, and `new-api/router/web/creative/dist` now have matching 223-file artifact trees and `/creative/assets/...` entry refs.

## MEDIUM findings / accepted risks

1. **Cold Playwright smoke is not release-gate clean**
   - Cold `pnpm e2e:smoke`: failed twice at `.drawnix` visible timeout 10s.
   - Manual diagnostic: `.drawnix` became visible at about 18s.
   - Prewarmed official smoke: 2/2 passed.
   - Action: either prewarm in CI and document it, or change the readiness wait/timeout so cold smoke passes reliably.

2. **Generated dist trips full `git diff --check`**
   - Full check reports trailing whitespace only inside generated Creative dist files.
   - Source-only diff-check passes.
   - Action: decide generated-artifact policy. Prefer fixing/normalizing at the OpenTU artifact source or excluding generated dist from whitespace checks; do not hand-edit only one `new-api` copy and break byte identity.

3. **Production env validation not performed by design**
   - No secrets read and no provider/payment/CDN/production endpoints called.
   - Action: release environment must separately validate S3-compatible asset config, NPM_TOKEN/publish token, CDN/domain config, and any provider/payment health checks.

4. **Embedded `/creative/` browser coverage gap**
   - Current official smoke validates OpenTU dev server at `/`, not `new-api` serving `/creative/`.
   - Action: add a local `new-api` `/creative/` Playwright smoke that verifies app shell, service-worker route exclusions, session broker bootstrap, and asset sync/hydration paths without external provider calls.

## LOW findings

- `sw.js.map` is emitted by current OpenTU build and synced into `new-api`. It is not referenced by `index.html`, `sw.js`, or manifests. If production policy forbids sourcemaps, disable/strip it at the OpenTU artifact source and keep all copies identical.
- OpenTU build warnings: missing `${NPM_TOKEN}` in local `.npmrc`, Sass deprecations, stale Browserslist data, and large chunks.
- Local browser diagnostic logged `The database "aitu-workspace" can't be downgraded from version 9 to version 8.`; warmed smoke still passed. Recheck with clean and migrated browser profiles later.

## Verification evidence

### Backend / embedded artifact

Passed:

```bash
cd /mnt/f/code/project/new-api
go test -count=1 .
go test -count=1 ./router ./middleware ./controller ./model ./service ./relay/... && go build ./...
```

Evidence:

- `verification/new-api-post-dist-sync-tests-2026-06-13.log`
- `verification/new-api-creative-dist-rsync-2026-06-13.log`
- `verification/opentu-dist-creative-base-inspection-2026-06-13.log`

### Frontend build/typecheck

Passed:

```bash
cd /mnt/f/code/project/opentu
VITE_BASE_URL=/creative/ pnpm build:web
pnpm nx run drawnix:typecheck
```

Evidence:

- `verification/opentu-build-web-creative-base-2026-06-13.log`
- `verification/opentu-drawnix-typecheck-post-dist-sync-2026-06-13.log`

### Browser smoke

Observed:

- Cold official smoke failed: `verification/opentu-e2e-smoke-post-dist-sync-2026-06-13.log`
- Immediate rerun failed: `verification/opentu-e2e-smoke-warm-rerun-post-dist-sync-2026-06-13.log`
- Manual long-wait diagnostic reached `.drawnix`: `verification/opentu-manual-playwright-readiness-diagnostic-2026-06-13.log`
- Prewarmed official smoke passed: `verification/opentu-e2e-smoke-prewarmed-existing-server-2026-06-13.log`

### Diff/release hygiene

- Full generated-dist diff-check findings: `verification/git-diff-check-post-dist-sync-2026-06-13.log`
- Source-only diff-check passed: `verification/git-diff-check-source-only-2026-06-13.log`

Current intended dirty state:

- `new-api`: generated Creative dist changes; local `.codegraph/` and `.codex-flow/` must not be committed.
- `new2fly`: current task artifacts and spec updates; `.cache/` must not be committed.
- `opentu`: no tracked source diff after restoring buildTime side effect; untracked `packages/drawnix/audio-test.pptx` remains local-only.

## Dynamic workflow evidence

1. v3 broad workflow:
   - Workflow: `.codex-flow/generated/newapi-opentu-release-readiness-2026-06-13-v3-post-sync.workflow.ts`
   - Journal: `.codex-flow/journal/newapi-opentu-release-readiness-2026-06-13-v3-post-sync.jsonl`
   - Result: final synthesis returned `mostly_ready`; browser branch completed; three broad branches timed out due large generated evidence.

2. v4 targeted workflow:
   - Workflow: `.codex-flow/generated/newapi-opentu-release-readiness-2026-06-13-v4-targeted.workflow.ts`
   - Journal: `.codex-flow/journal/newapi-opentu-release-readiness-2026-06-13-v4-targeted.jsonl`
   - Result: all three targeted branches completed and agreed `mostly_ready`; synthesis node failed, but branch outputs were complete and consistent.

## Spec updates made

- Added `.trellis/spec/frontend/creative-embedded-release-artifact.md`.
- Updated `.trellis/spec/frontend/index.md`.
- Updated `.trellis/spec/backend/creative-backend-security-boundary.md` to reference the embedded artifact contract.

## Must do before actual release

1. Decide/implement browser smoke gate:
   - either make cold `pnpm e2e:smoke` pass reliably, or document prewarm/readiness as required CI setup.
2. Decide generated dist diff-check policy:
   - source-only diff-check plus artifact identity check, or normalized generated output from OpenTU build.
3. Ensure release commit includes only intended generated dist/spec/task changes and excludes local tool/cache/test artifacts.
4. Run CI/release-environment validation for secrets-dependent production config outside this no-secrets session.

## Suggested next improvements

- Add embedded `new-api /creative/` Playwright smoke.
- Add a script that performs the full artifact contract: `VITE_BASE_URL=/creative/` build, dual sync, tree-hash compare, and new-api tests.
- Investigate IndexedDB downgrade warning with clean/migrated profiles.
- Triage `sw.js.map` production policy.
