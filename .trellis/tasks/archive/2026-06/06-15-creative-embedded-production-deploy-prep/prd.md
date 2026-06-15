# Creative Embedded Production Deployment Preparation

## Goal

Prepare a safe, repeatable production-deployment package for the already pushed embedded Creative integration, without exposing secrets or prematurely claiming production readiness.

This task is about **deployment preparation and operational runbooks**. It does not deploy to a real host unless a target environment, credentials, and S3-compatible Creative asset storage are explicitly provided and authorized.

## User Value

The embedded `/creative/` integration is locally verified and pushed to forks, but production rollout is still blocked by deployment/environment decisions. The user needs a concrete checklist/runbook that answers:

1. which refs/image inputs to deploy;
2. what environment variables are required and which are forbidden in production;
3. how to enable **云同步** safely with S3-compatible storage;
4. how to verify route boundaries, embedded smoke, and authenticated cloud-sync after deployment;
5. how to roll back code or cloud-sync quickly if checks fail.

## Confirmed Facts

### Published refs from previous task

- OpenTU embedded branch:
  - repo: `WindC0X/opentu`
  - branch: `feat/creative-embed`
  - verified commit: `bc938728754f7acbfbe8043a717c823bcedcacf0`
- new-api embedded branch:
  - repo: `WindC0X/new-api`
  - branch: `feat/creative-embed`
  - verified commit: `bfef3101603837088f011112101038bbcde01b14`
- new2fly orchestration branch:
  - repo: `WindC0X/new2fly`
  - branch: `master`
  - final verified commit after archive/journal: `0bcd677a034b6f610ac21c6a3d2c47ec99ad4e8a`

### Local staging verification already completed

- Local staging URL: `http://127.0.0.1:39084/creative/`.
- Local image: `new-api-creative-embed:staging-current`.
- Route/header matrix passed for app shell, service worker, metadata, static asset, missing static asset, API boundary, and relay boundary.
- Embedded Playwright smoke passed.
- Authenticated Creative cloud-sync smoke passed locally:
  - login/bootstrap succeeded;
  - `assetSyncEnabled=true`;
  - document create/list/get/update/delete succeeded;
  - bad nonce rejected with 403;
  - asset upload/range/delete succeeded;
  - storage/provider internals were not leaked in the upload response.


### VPS-A read-only preflight (2026-06-15)

A read-only SSH preflight was authorized and completed. Full sanitized notes are in `research/vps-a-readonly-preflight-2026-06-15.md`. Key findings:

- SSH to `admin@47.80.71.35` works from this environment with `~/.ssh/id_ed25519`.
- Current production `new-api` runs from `/home/admin/apps/new-api` via Docker Compose, host networking, container `new-api-relay`.
- Current image is `calciumion/new-api:v0.13.2`, not the embedded Creative candidate image.
- Current compose uses `env_file: .env`, volume mounts `./data:/data` and `./logs:/app/logs`, and `PORT=13000`.
- Selected container env shows `SESSION_SECRET` and `SQLITE_PATH` are set, but no selected `CREATIVE_*` or `FRONTEND_BASE_URL` keys appeared. Values were not printed.
- Caddy is active; Nginx inactive.
- Existing public baseline remains healthy for current paths: `api.se7endot.top/v1/models -> 401`, `console.se7endot.top/login -> 200`.
- Current `/creative/*` on `console.se7endot.top` is not the embedded Creative route contract: service worker/version/assets/API/relay paths return HTML fallback or redirect.
- Current `/creative/*` on `api.se7endot.top` returns 404.
- Recent auto DB backup exists under `/home/admin/apps/new-api/backups/auto`; root disk was 77% used at preflight time.

### Production cloud-sync constraints

- `CREATIVE_ASSET_SYNC_ENABLED=false` by default.
- `CREATIVE_ASSET_ROLLOUT_MODE=production` requires `CREATIVE_ASSET_STORAGE=s3-compatible`.
- `CREATIVE_ASSET_STORAGE=database` is local/test/canary only and must not be used for production cloud-sync.
- Complete S3-compatible config is required in production:
  - `CREATIVE_ASSET_S3_ENDPOINT`
  - `CREATIVE_ASSET_S3_REGION`
  - `CREATIVE_ASSET_S3_BUCKET`
  - `CREATIVE_ASSET_S3_PREFIX`
  - `CREATIVE_ASSET_S3_ACCESS_KEY_ID`
  - `CREATIVE_ASSET_S3_SECRET_ACCESS_KEY`
  - `CREATIVE_ASSET_S3_FORCE_PATH_STYLE`
- Missing production S3 config fails closed in `new-api` runtime; it must not silently fall back to DB.
- Multi-instance deployments require a stable shared `SESSION_SECRET`.
- Public asset URLs returned to browsers must remain same-origin `/creative/api/assets/:id/content`, never raw S3/signed URLs.

### Packaging constraints

- `new-api/Dockerfile` builds default/classic frontends and the Go binary, but does **not** build OpenTU.
- `new-api/Dockerfile` copies prebuilt Creative artifacts from `web/creative/dist`.
- Therefore image build/publish must be preceded by artifact identity checks across:
  - `/mnt/f/code/project/opentu/dist/apps/web`
  - `/mnt/f/code/project/new-api/web/creative/dist`
  - `/mnt/f/code/project/new-api/router/web/creative/dist`


### VPS target information discovered from OpenClawChineseTranslation docs

Source directory inspected: `/mnt/f/CODE/Project/OpenClawChineseTranslation/docs`. Relevant source files include:

- `VPS_FINAL_HANDOFF_2026-04-09.md`
- `VPS_SERVICE_INVENTORY_2026-03-06.md`
- `VPS_OPERATIONS_RUNBOOK_2026-03-06.md`
- `VPS_TOPOLOGY_2026-03-06.md`
- `VPS_A_API_RELAY_BLUEPRINT_2026-03-12.md`
- `VPS_A_CAPACITY_GOVERNANCE_2026-03-21.md`
- `VPS_MONITORING_2026-03-14.md`

The likely production target for this Creative/new-api deployment is `VPS-A`:

- Role: public edge/control node for `CPA + new-api + helper + subscription bridge + monitor/backup`.
- Public host/IP: `47.80.71.35`.
- Internal/Tailscale host/IP noted in topology: `100.99.109.30`.
- SSH entry from docs: `ssh -i ~/.ssh/id_ed25519 admin@47.80.71.35`.
- Current new-api service path: `/home/admin/apps/new-api`.
- Current new-api deployment shape: Docker Compose, checked/restarted with `cd /home/admin/apps/new-api && docker compose ...`.
- Public API domain: `https://api.se7endot.top`.
- Public user panel domain: `https://console.se7endot.top`.
- Tailscale-only new-api admin entry: `https://iz5ts1b7e631cus6rzvbt3z.tailefed73.ts.net:8871`.
- Existing public smoke expectations: `https://api.se7endot.top/v1/models -> 401`, `https://console.se7endot.top/login -> 200`.
- Existing backups/monitoring: `backup-core-state.timer` active; new-api DB source `/home/admin/apps/new-api/data/new-api.db`; backup target `/home/admin/apps/new-api/backups/auto`.

Secret handling note: docs contain references to secret/key/token management in adjacent helper documents, but this task must not print or copy secret values. Only paths, domains, service names, and non-secret operational metadata are recorded here.

### Credential boundary

- GitHub credentials are on the host machine; previous push verification used Windows host Git, not WSL token copying.
- Secrets must not be printed, committed, or captured in task records.



### User risk tolerance and hard safety requirement

User decision (2026-06-15): existing `new-api` can be paused for several hours if needed, but the rollout must not damage or reset existing user data, channel configuration, model/pricing options, API keys, quotas, or other state required for later normal use.

Planning implication:

- A short or multi-hour maintenance window is acceptable.
- Data/config preservation is a hard release gate, not a best-effort goal.
- Deployment must preserve the mounted production data directory (`/home/admin/apps/new-api/data`) and current `.env`/`SESSION_SECRET`.
- No command may delete, truncate, reinitialize, or replace the production DB as part of normal deployment.
- Because candidate startup runs `model.InitDB()` / `migrateDB()` on master nodes and AutoMigrates additive Creative tables, pre-deploy validation must run the candidate against a **copy** of the production SQLite DB before touching the live DB.
- Rollback should restore the previous image/compose and keep the live DB as-is; do not attempt destructive schema rollback.

### Existing new-api impact assessment

- Planning/runbook work and read-only preflight have no runtime impact.
- A real deployment would replace/restart the current `new-api-relay` container, so it can cause a short API/console interruption during image pull/start/restart.
- The intended code change is additive around `/creative/*`; existing `/v1/*`, `/api/*`, dashboard, login, and console routes should remain owned by existing routers. The candidate code has tests covering `/creative` isolation and `FRONTEND_BASE_URL` behavior.
- The practical production risk is still non-zero because deploying the candidate replaces the whole `new-api` image, not only a static file directory. Regression gates must therefore include existing public baseline checks: `api.se7endot.top/v1/models -> 401`, `console.se7endot.top/login -> 200`, plus any high-value authenticated API smoke the operator authorizes.
- Current `/creative/*` on `console.se7endot.top` is only default SPA fallback. The deploy will intentionally change that path family to the embedded Creative app/API/static route contract. Existing non-Creative users should not depend on `/creative/*`; if they do, that path behavior changes by design.
- Database impact should be treated as additive/migration risk: take a DB backup, run candidate startup/migration against a production DB copy first, then keep rollback image/compose available.
- First production phase should keep `CREATIVE_ASSET_SYNC_ENABLED=false` unless S3-compatible storage is ready; this avoids production startup/config failures and avoids storing user Creative assets in DB.

## Requirements

### A. Production deployment prep artifacts

1. Produce a production deployment runbook under `ops/` with explicit steps for:
   - selecting verified refs;
   - building/verifying the candidate image or direct checkout;
   - injecting environment variables through the target platform's secret manager;
   - route/header verification;
   - authenticated cloud-sync smoke;
   - rollback.
2. Produce a redacted production env template/checklist with placeholders only; no real secrets.
3. Keep local staging and production deployment instructions separate.
4. Use the term **云同步** for the new-api backed Creative sync feature.

### B. Safety boundaries

5. Do not deploy to a public/private target without explicit target details and authorization.
6. Do not enable production Creative asset sync with DB storage.
7. Do not copy `.env.staging.local` into production.
8. Do not print GitHub tokens, S3 credentials, provider keys, payment credentials, admin passwords, `SESSION_SECRET`, cookies, or CSRF/nonce values.
9. If S3-compatible storage is not ready, production rollout must keep `CREATIVE_ASSET_SYNC_ENABLED=false` or defer Creative cloud-sync enablement.

### C. Verification requirements

10. Include pre-deploy gates:
    - live remote ref verification;
    - `python3 scripts/creative_release_gate.py check --source-diff-check --run-new-api-tests`;
    - artifact identity checks before image build/publish.
11. Include post-deploy read-only checks for:
    - `/creative/`
    - `/creative/sw.js`
    - `/creative/version.json`
    - an existing `/creative/assets/*`
    - a missing `/creative/assets/*`
    - `/creative/api/bootstrap`
    - `/creative/relay/v1/chat/completions` wrong-method/non-SPA boundary
12. Include embedded browser smoke command.
13. Include authenticated cloud-sync smoke procedure that accepts credentials without logging secrets.
14. Include production-only checks as `not-run` unless the real target is provided and checked.

### D. Rollback requirements

15. Document rollback for:
    - code/image ref;
    - disabling `CREATIVE_ASSET_SYNC_ENABLED`;
    - S3 storage health concerns;
    - preserving objects/metadata for investigation rather than destructive cleanup.
16. Document data-preservation gates:
    - preserve `/home/admin/apps/new-api/data`;
    - back up live DB before deployment;
    - run candidate migration/startup against a DB copy first;
    - do not delete/reinitialize users, tokens, channels, abilities, options, pricing, quotas, or logs.

## Out Of Scope Unless Separately Confirmed

- Real deployment to a private/public host.
- DNS/TLS/CDN changes.
- Creating or managing an S3 bucket/provider account.
- Publishing Docker images to a registry.
- Running real provider generation, payment, or quota-consuming requests.
- Force-pushing any branch or changing upstream origins.

## Acceptance Criteria

- [ ] A production deployment runbook exists and is clearly separate from local staging docs.
- [ ] A production env template/checklist exists with placeholders only and no secret values.
- [ ] The runbook states that production Creative cloud-sync requires S3-compatible storage and must not use DB storage.
- [ ] The runbook includes pre-deploy artifact/ref gates, post-deploy route/header checks, embedded smoke, authenticated cloud-sync smoke, and rollback.
- [ ] The runbook explains how to handle `FRONTEND_BASE_URL` and verify `/creative/` remains served by the intended host.
- [ ] Validation confirms no secret values were committed.
- [ ] Planning explicitly records whether this task is runbook-only or includes an authorized live deployment.
- [ ] The runbook includes a data/channel/config preservation gate and DB-copy migration rehearsal before any live DB touch.

## Open Questions

1. Partially resolved: target host is confirmed reachable as `VPS-A` with Docker Compose at `/home/admin/apps/new-api`; still need explicit approval before any live deployment or service restart.
2. Resolved for planning: optimize first for Docker image/Compose on `VPS-A`, with direct checkout/CI notes as alternatives.
3. Still open: is S3-compatible object storage already available for production Creative 云同步, or should production launch with asset sync disabled until storage is ready?
