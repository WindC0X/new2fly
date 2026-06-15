# Design — Creative Embedded Production Deployment Preparation

## 1. Scope

This task creates release-operation artifacts in `new2fly`; it does not change `opentu` or `new-api` product code unless planning later identifies a missing deployment helper as necessary.

Primary expected outputs:

- `ops/newapi-opentu-production/README.md` — production deployment/preflight/runback runbook.
- `ops/newapi-opentu-production/env.production.example` — placeholder-only env template.
- Optional helper script only if it materially reduces operator error and can run without secrets.

## 2. Deployment model

The runbook should support three possible deployment modes, but optimize the first implementation around Docker image/Compose because the current local staging path, `new-api/Dockerfile`, and discovered `VPS-A` production shape all use Docker/Compose-compatible operations.

### Mode A — Docker image / Compose (recommended first)

Flow:

1. Verify live remote refs.
2. Check out/build from `new-api feat/creative-embed` at `bfef310...` or a later explicitly verified commit.
3. Run embedded artifact gate before image build.
4. Build an image from the verified `new-api` checkout.
5. Inject production env through the deployment host/secret manager.
6. Start/restart service.
7. Run route/header and smoke checks.

### Mode B — Direct checkout / systemd

Same gates, but instead of building an image the host checks out the verified ref, builds the Go binary with embedded Creative dist, and systemd restarts it with an env file or secret manager.

### Mode C — External CI/CD

CI/CD must reproduce the same gates: live refs, artifact identity, image build from verified checkout, env presence checks, route/header, smoke, rollback.


## 2A. Discovered target environment: VPS-A

From the OpenClawChineseTranslation VPS docs, the current production `new-api` target is `VPS-A`:

- SSH: `admin@47.80.71.35` with local key path `~/.ssh/id_ed25519` according to the docs.
- Service directory: `/home/admin/apps/new-api`.
- Lifecycle: Docker Compose (`docker compose ps`, `docker compose restart`, logs under the same directory).
- Public API: `https://api.se7endot.top`.
- Public console: `https://console.se7endot.top`.
- Admin panel: Tailscale-only on `:8871`.
- Current DB: `/home/admin/apps/new-api/data/new-api.db`; backups under `/home/admin/apps/new-api/backups/auto`.

Design implication: the first production runbook should be `VPS-A + Docker Compose` oriented and include pre-backup, compose backup, image/ref rollback, and public/Tailscale boundary checks.


## 2B. Read-only preflight baseline

The 2026-06-15 read-only SSH preflight confirms the first live deployment path should be a Docker Compose image cutover on `VPS-A`:

- Existing compose file is minimal and currently uses `calciumion/new-api:v0.13.2`.
- The new deployment can either update that image reference to a custom candidate image or replace the service with an equivalent compose file that preserves `network_mode: host`, `container_name: new-api-relay`, volumes, `env_file: .env`, restart policy, and command.
- Because current `/creative/*` on `console.se7endot.top` is default SPA fallback and `api.se7endot.top/creative/*` is 404, post-deploy checks must demonstrate an actual route behavior change, not merely HTTP 200.
- Existing root disk free space is about 8.7G; image build/pull/publish should consider disk pressure and avoid accumulating dangling images before checking space.
- Current env does not appear to configure Creative cloud-sync; deployment should default to `CREATIVE_ASSET_SYNC_ENABLED=false` unless S3-compatible values are supplied through `.env`/secret injection.

## 3. Environment contract

### Required base env for production-like deployment

- `SESSION_SECRET=<stable random secret>`
- `GIN_MODE=release`
- database settings appropriate to the deployment (`SQL_DSN` or managed DB settings)
- `SYNC_FREQUENCY`, `UPDATE_TASK`, and channel update task settings as intentionally chosen for production

### Creative 云同步 disabled path

Safe default if S3 is not ready:

```env
CREATIVE_ASSET_SYNC_ENABLED=false
```

The `/creative/` app can still be served, but browser cloud asset sync should be unavailable/fail closed.

### Creative 云同步 enabled path

Required for production cloud-sync:

```env
CREATIVE_ASSET_SYNC_ENABLED=true
CREATIVE_ASSET_ROLLOUT_MODE=production
CREATIVE_ASSET_STORAGE=s3-compatible
CREATIVE_ASSET_S3_ENDPOINT=<private object storage endpoint>
CREATIVE_ASSET_S3_REGION=<region or auto>
CREATIVE_ASSET_S3_BUCKET=<private bucket>
CREATIVE_ASSET_S3_PREFIX=creative-assets
CREATIVE_ASSET_S3_ACCESS_KEY_ID=<secret>
CREATIVE_ASSET_S3_SECRET_ACCESS_KEY=<secret>
CREATIVE_ASSET_S3_FORCE_PATH_STYLE=<true|false>
CREATIVE_ASSET_USER_MAX_BYTES=<quota>
CREATIVE_ASSET_USER_MAX_ASSETS=<quota>
SESSION_SECRET=<stable shared secret>
```

The runbook must never include actual secret values.

## 4. Verification design

### Pre-deploy gates

- `git ls-remote` candidate refs.
- `python3 scripts/creative_release_gate.py check --source-diff-check --run-new-api-tests`.
- If rebuilding OpenTU: `VITE_BASE_URL=/creative/ pnpm build:web`, sync both new-api dist trees, then rerun gate.
- Confirm `new-api/Dockerfile` is using prebuilt `web/creative/dist` from the candidate checkout.

### Post-deploy read-only route/header table

Record only method/path/status/selected headers/classification:

- `/creative/`
- `/creative/sw.js`
- `/creative/version.json`
- one existing `/creative/assets/*`
- one missing `/creative/assets/*`
- `/creative/api/bootstrap`
- `/creative/relay/v1/chat/completions` wrong-method/non-SPA boundary

Do not record response bodies, cookies, auth headers, CSRF/nonce, query secrets, provider payloads, or generated-task payloads.

### Smoke tests

- Embedded browser smoke: `python3 scripts/creative_release_gate.py check --embedded-smoke-url <target>/creative/`.
- Authenticated cloud-sync smoke: use a helper that reads password/token via stdin or environment supplied by the operator, but never prints it; log only statuses, lengths, and sanitized IDs.

## 5. FRONTEND_BASE_URL boundary

If target env sets `FRONTEND_BASE_URL`, the runbook must require a route check proving:

- `/creative/` app shell does not redirect away unexpectedly;
- `/creative/assets/*` remains static asset/miss, not SPA fallback;
- `/creative/api/*` and `/creative/relay/v1/*` remain local no-store API/relay boundaries.

## 6. Rollback design

- Code rollback: redeploy previous image/ref.
- Cloud-sync rollback: set `CREATIVE_ASSET_SYNC_ENABLED=false` and restart.
- Storage incident: do not delete object storage contents as a rollback step; preserve objects and DB metadata for investigation.
- Route regression: rollback code/image or temporarily disable external redirect config that breaks `/creative/` route ownership.

## 7. Risks

- Accidentally copying local `.env.staging.local` into production.
- Enabling production cloud-sync with database storage.
- Building a Docker image from stale `web/creative/dist`.
- Claiming public/CDN readiness from local staging-only evidence.
- Logging secrets while running authenticated smoke.

## 8. Existing service impact controls

To minimize impact on current `new-api` usage, the first live rollout should be treated as a bounded canary/cutover:

1. Preserve current compose shape: `network_mode: host`, `PORT=13000`, `env_file: .env`, `./data:/data`, `./logs:/app/logs`, and stable `SESSION_SECRET`.
2. Back up before mutation:
   - current `docker-compose.yml`;
   - current DB file or confirm fresh automatic backup;
   - current image/tag (`calciumion/new-api:v0.13.2`) as rollback reference.
3. First phase sets `CREATIVE_ASSET_SYNC_ENABLED=false` unless production S3-compatible storage is supplied.
4. Deploy during a low-traffic window because container replacement can briefly interrupt `/v1` API and console sessions.
5. Post-deploy smoke must include both new Creative checks and existing service baseline checks:
   - `GET https://api.se7endot.top/v1/models` unauthenticated remains `401`;
   - `GET https://console.se7endot.top/login` remains `200`;
   - selected authenticated/API smoke only if explicitly authorized.
6. If baseline checks fail, rollback by restoring the previous compose image/ref and restarting the container; do not run destructive DB rollback.

## 8A. Data/channel/config preservation gate

The user accepts a maintenance window of several hours, but not data/config loss. Therefore the deployment design must prefer slow-safe over fast-risky:

1. Preserve production mounts and secrets:
   - keep `/home/admin/apps/new-api/data` mounted to `/data`;
   - keep `/home/admin/apps/new-api/logs` mounted to `/app/logs`;
   - keep the current `.env`, especially `SESSION_SECRET` and `SQLITE_PATH`;
   - do not copy local staging env into production.
2. Before live restart, create a timestamped backup of:
   - `docker-compose.yml`;
   - `.env` on VPS only, without printing it;
   - `data/new-api.db` or the path referenced by `SQLITE_PATH`;
   - optionally a schema/count snapshot for `users`, `tokens`, `channels`, `abilities`, `options`, and quota/log tables.
3. Run candidate startup/migration against a copied DB path, not the live DB. Passing criteria:
   - candidate process starts far enough to complete DB migration;
   - no destructive row-count collapse in `users`, `tokens`, `channels`, `abilities`, `options`;
   - Creative tables may be added; existing user/channel/config rows must remain.
4. Live rollback is image/compose rollback, not destructive DB rollback. If a migration adds columns/tables, leave them in place unless a later audited rollback-forward script is written.
