# Implement Plan — Creative pinned candidate push deploy smoke

## Phase A — Context / safety

- [x] Confirm local repo heads and clean worktrees for `opentu`, `new-api`, and `new2fly`.
- [x] Confirm runbook pinned refs match intended OpenTU/new-api commits.
- [x] Confirm `.codex-flow/`, `.env`, DB/log/secret files are not staged.

## Phase B — Push and remote verification

- [x] Attempt WSL `git push --dry-run` / `git ls-remote` where credentials work without exposing secrets.
- [x] If WSL credentials fail, use host Git/PowerShell for push/verify; do not copy tokens into WSL.
- [ ] Push:
  - [x] OpenTU `feat/creative-embed` at `0b584e2cf7c622b9fa431b3bf39b4a86055699bc`.
  - [x] new-api `feat/creative-embed` at `53b8f54126214b4eac7b33619d45c097fe443e34`.
  - [x] new2fly `master` at the current task commit.
- [x] Verify remote refs with `git ls-remote` and record hashes.

## Phase C — Post-push gates

- [x] Run `TMPDIR=/dev/shm GOCACHE=/dev/shm/go-cache-new-api GOMODCACHE=/dev/shm/go-mod-cache-new-api bash scripts/creative_ci_gate.sh` in `new-api`.
- [x] Run `bash -n ops/newapi-opentu-production/creative-route-check.sh ops/newapi-opentu-production/creative-cloud-sync-smoke.sh` in `new2fly`.
- [x] Run `PYTHONDONTWRITEBYTECODE=1 python3 scripts/creative_release_gate.py check --new-api /mnt/f/CODE/Project/new-api --opentu /mnt/f/code/project/opentu --source-diff-check --sourcemap-policy forbid`.
- [x] Confirm embedded dist provenance still reports OpenTU commit `0b584e2cf7c622b9fa431b3bf39b4a86055699bc`.

## Phase D — Staging/candidate validation

- [x] Run local disposable candidate/container staging from pinned commits, or document why the existing staging service is used instead.
- [x] Verify `/creative/`, static assets, `/creative/api/bootstrap`, `/creative/api/models`, model catalog/parameter UI, and route/API boundaries in staging.
- [x] Keep staging cloud sync disabled unless explicitly using isolated non-production S3-compatible storage.
- [x] Record staging result separately from production readiness.
- [x] Do not proceed to VPS/production preflight if staging fails.

## Phase E — VPS/production read-only preflight

- [x] Run read-only VPS/runbook preflight only after staging passes.
- [x] Confirm current production image, compose, app dir, env key presence, and backup plan without printing secrets.
- [x] Confirm current route baseline using redacted GET/HEAD checks only.
- [x] Stop and ask for explicit production mutation authorization before any build/load/restart/env edit/authenticated smoke.

## Phase F — Authorized deployment/smoke

Only after explicit authorization:

- [x] Build or package candidate image from pinned new-api commit.
- [x] Verify candidate image ID/digest.
- [x] Take production backup/rehearsal per runbook.
- [x] Deploy Phase 1 route/UI with Creative asset sync disabled.
- [x] Run redacted public route smoke.
- [x] Run authenticated smoke only with authorized session/credentials and redaction controls. Not run for this Phase 1 CLI rollout because no browser session / Turnstile-safe authenticated path was provided; public route + unauth boundary + embedded Playwright smoke passed.
- [x] Record not-run items: S3 cloud sync, live provider smoke, Duomi/GrsAI live adapter.

## Phase G — Finish

- [x] Update task journal with pushed refs, gate evidence, and deployment/smoke result or blocked reason.
- [x] Update specs only if new reusable deployment/provenance rule is learned. No new reusable spec rule beyond existing staging/provenance/deployment contracts.
- [ ] Commit task/runbook changes.
- [ ] Archive Trellis task after acceptance criteria are met or explicitly mark blocked if external authorization/credentials are unavailable.

## Rollback Points

- Before push: no remote changes.
- After push: remote ref rollback requires explicit instruction; prefer forward fix over history rewrite.
- Before staging: no staging/production change.
- After staging: production remains unchanged.
- Before production mutation: no production change.
- After deployment: rollback via previous image/compose/env backup; do not delete DB schema/data.
