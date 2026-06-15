# Implementation Plan — Creative Embedded Production Deployment Preparation

## Phase 1 — Planning

- [x] Create Trellis task after user consent.
- [x] Inspect previous push/local-staging verification records.
- [x] Inspect current staging runbook, new-api env example/docs, Dockerfile, and relevant Trellis specs.
- [x] Run authorized read-only VPS-A preflight and record sanitized findings. Target facts confirmed: VPS-A, Docker Compose host networking, `/home/admin/apps/new-api`, current image `calciumion/new-api:v0.13.2`, current `/creative/*` fallback/404 baseline.
- [x] Resolve primary scope decision: this task is runbook/preflight-only; live deployment/restart remains out of scope until separately authorized.
- [x] Review planning artifacts with the user before `task.py start`.

## Phase 2 — Implementation candidates

If scope is runbook/preflight-only (recommended):

1. Add `ops/newapi-opentu-production/README.md` with:
   - verified refs section;
   - VPS-A Docker Compose deployment flow;
   - direct checkout and CI/CD notes;
   - pre-deploy gates;
   - env/secret injection contract;
   - post-deploy route/header commands;
   - embedded smoke command;
   - authenticated cloud-sync smoke handling;
   - rollback;
   - DB-copy migration rehearsal and data/channel/config preservation checks.
2. Add `ops/newapi-opentu-production/env.production.example` with placeholders only.
3. Optionally add a no-secrets helper for route/header table generation if it avoids copy/paste mistakes.
4. Include existing public baseline checks so deployment does not silently break current new-api usage: `/v1/models -> 401`, `/login -> 200`, and optional authorized authenticated/API smoke.
5. Document that real deployment may use a multi-hour maintenance window, but must preserve users/tokens/channels/abilities/options/pricing/quotas and keep rollback to `calciumion/new-api:v0.13.2`/previous compose available.
6. Include a pre-live DB-copy migration rehearsal command sequence that never points the candidate at the live DB until the rehearsal passes.
6. Link the production runbook from the existing local staging README.
7. Update Trellis specs only if the runbook captures a durable new rule not already present.

If scope includes live deployment:

1. Require explicit approval for write actions on VPS-A, confirm deploy via `/home/admin/apps/new-api` Docker Compose, confirm image build/publish path, confirm secret-injection method, confirm maintenance window, confirm DB-copy migration rehearsal, and confirm rollback owner/window.
2. Verify S3-compatible storage readiness before enabling Creative asset sync.
3. Run deployment commands only through authorized channels and without printing secrets.
4. Record target-specific route/header/smoke evidence in `check.md`.

## Phase 3 — Validation

- `python3 ./.trellis/scripts/task.py validate 06-15-creative-embedded-production-deploy-prep`.
- `git diff --check` on changed docs/scripts.
- Secret scan over new runbook/template for placeholder-only values.
- If helper script added, run it against local staging or a supplied target and record sanitized output.
- Optional dynamic workflow check to review the runbook for production overclaim, secret leakage, and missing rollback.

## Phase 4 — Finish

- Commit runbook/planning changes.
- Archive task.
- Record journal.

## Rollback points

- Before `task.py start`: planning-only, no deployment mutation.
- Runbook-only implementation: delete or revise docs/scripts before commit.
- Live deployment, if later authorized: rollback to previous image/ref and/or disable `CREATIVE_ASSET_SYNC_ENABLED`.

## Implementation progress

- [x] Added `ops/newapi-opentu-production/README.md` production runbook.
- [x] Added `ops/newapi-opentu-production/env.production.example` placeholder-only env template.
- [x] Added `ops/newapi-opentu-production/creative-route-check.sh` no-secret route/header checker.
- [x] Added `ops/newapi-opentu-production/creative-cloud-sync-smoke.sh` no-secret authenticated 云同步 smoke helper for Phase 1 disabled-state and Phase 2 S3-backed checks.
- [x] Linked production runbook from `ops/newapi-opentu-staging/README.md`.
- [x] Ran `bash -n` for the route checker.
- [x] Ran `bash -n` for the cloud-sync smoke helper.
- [x] Ran route checker against current production baseline; it correctly shows existing `/creative/*` is not yet the embedded Creative contract while existing `/v1/models` and `/login` baselines remain healthy.
- [x] Ran secret-ish scan; hits are placeholder/key names only, not values.
- [x] Ran `git diff --check` on changed files.
- [x] Ran dynamic workflow production runbook review v2; fixed blocking findings around SQLite host path mapping, localhost-only rehearsal, authenticated smoke procedure, stale runbook identity, and abort rollback.
- [x] Ran dynamic workflow production runbook review v3; remaining findings were warnings only, with no must-fix blockers.
- [x] Ran dynamic workflow production runbook final blocker check v5; both read-only branches passed with no must-fix blockers.
