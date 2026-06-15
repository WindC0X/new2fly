# Creative Embedded Production Deploy

## Goal

Deploy the embedded Creative `/creative/` route/UI to VPS-A production as **Phase 1 only**, preserving existing `new-api` data/config and keeping Creative 云同步 disabled.

This task is a real deployment task, unlike the prior runbook-prep task. It may stop/restart production `new-api` during an authorized maintenance window, but it must not damage user data, API keys/tokens, channels, abilities, options, pricing, quotas, logs, or existing service functionality.

## User Value

The embedded Creative integration has been developed, reviewed, locally staged, documented, committed, and pushed. The user now needs it deployed to the current production `new-api` instance so `/creative/` becomes available on `https://console.se7endot.top/creative/`, without breaking the existing API relay/console.

## Confirmed Facts

- Deployment target: VPS-A `admin@47.80.71.35`.
- Production app dir: `/home/admin/apps/new-api`.
- Current production container: `new-api-relay` via Docker Compose.
- Current production image before this deployment: `calciumion/new-api:v0.13.2`.
- Current compose shape discovered earlier:
  - `network_mode: host`
  - `env_file: .env`
  - `./data:/data`
  - `./logs:/app/logs`
  - `command: --log-dir /app/logs`
  - `PORT=13000`
- Current public baseline before deployment:
  - `https://api.se7endot.top/v1/models -> 401`
  - `https://console.se7endot.top/login -> 200`
- Current `/creative/*` is not the embedded contract yet; console domain returns fallback HTML for many paths and API domain returns 404.
- Production runbook and helpers are committed/pushed in `new2fly`:
  - `ops/newapi-opentu-production/README.md`
  - `ops/newapi-opentu-production/env.production.example`
  - `ops/newapi-opentu-production/creative-route-check.sh`
  - `ops/newapi-opentu-production/creative-cloud-sync-smoke.sh`
- Relevant commits:
  - new2fly runbook commit: `f94e86b`
  - new2fly Trellis/spec commit: `f1cd71e`
  - new2fly journal/latest pushed commit: `8b8b0e2`
  - new-api candidate ref from prior verification: `bfef3101603837088f011112101038bbcde01b14`
  - OpenTU candidate ref from prior verification: `bc938728754f7acbfbe8043a717c823bcedcacf0`
- The user allows current `new-api` to be paused for several hours if necessary, but data/config preservation is mandatory.

## Requirements

### Phase 1 scope

1. Deploy only the embedded Creative route/UI candidate to VPS-A.
2. Keep Creative 云同步 disabled:
   - `CREATIVE_ASSET_SYNC_ENABLED=false`
   - `CREATIVE_VIDEO_RELAY_ENABLED=false` unless separately authorized later.
3. Do not enable S3/R2/OSS-compatible Creative asset storage in this task.
4. Do not run provider generation, payment, quota-consuming, or destructive admin actions.

### Data/config preservation

5. Preserve production `.env`, especially `SESSION_SECRET`, `SQLITE_PATH`, provider/payment/channel settings, and other existing keys.
6. Preserve `/home/admin/apps/new-api/data` and `/home/admin/apps/new-api/logs` mounts.
7. Before live cutover, stop writes and create a consistent backup of:
   - `docker-compose.yml`
   - `.env` on VPS only, without printing/copying it into chat/task logs
   - SQLite DB via `.backup`
8. Run candidate startup/migration against a copied DB before touching the live DB with the candidate image.
9. If backup, row-count, or DB-copy rehearsal fails, restart the old service and stop deployment.

### Image/build identity

10. Build or otherwise prepare a candidate Docker image from the verified `new-api` candidate checkout.
11. Verify/refuse stale artifacts before image build.
12. Record image identity by image ID and, if applicable, digest; ensure rehearsal and production cutover use the same image.
13. Prefer a transfer path that does not require copying GitHub/registry credentials into WSL or logs. Recommended path: build locally, `docker save`/compress, `scp` to VPS-A, `docker load`, verify image ID.

### Verification

14. Before deployment, verify current public baseline.
15. After deployment, verify existing service baseline remains:
   - unauthenticated `/v1/models` returns 401 JSON
   - console `/login` returns 200 HTML
16. Verify Creative route/header matrix with assertion mode:
   - `/creative/`
   - `/creative/sw.js`
   - `/creative/version.json`
   - discovered existing `/creative/assets/*`
   - missing `/creative/assets/*`
   - `/creative/api/bootstrap`
   - `/creative/relay/v1/chat/completions`
17. Run embedded browser smoke against `https://console.se7endot.top/creative/` if the local tool environment can run it.
18. Run authenticated Phase 1 disabled-state smoke only if user provides/authorizes a smoke account credential flow; it must not log secrets.

### Rollback

19. If existing service baseline fails, immediately restore previous compose/image and restart.
20. Do not delete Creative tables/columns or object/storage metadata as emergency rollback.
21. Keep backup paths and image identities recorded in task check notes.

## Out of Scope

- Phase 2 Creative 云同步 enablement with S3/R2/OSS-compatible storage.
- Provider generation smoke that consumes upstream quota.
- Payment/webhook testing.
- DNS/TLS/CDN changes.
- Force-pushing or changing upstream origins.
- Printing or committing admin passwords, cookies, CSRF/nonce, `.env` values, provider keys, S3 keys, payment credentials, or GitHub tokens.

## Acceptance Criteria

- [ ] Candidate image identity is recorded and matches the image used for DB-copy rehearsal and final cutover.
- [ ] VPS-A pre-cutover baseline is recorded.
- [ ] Production compose/env/DB backups are created on VPS-A without printing secrets.
- [ ] Candidate DB-copy rehearsal starts successfully and row-count checks do not indicate destructive loss of existing tables.
- [ ] Production cutover completes with `CREATIVE_ASSET_SYNC_ENABLED=false`.
- [ ] Existing service baseline passes after cutover.
- [ ] Creative route/header assertion passes after cutover.
- [ ] Embedded smoke passes or is recorded as not-run with reason.
- [ ] Rollback path remains available and tested by command readiness, or rollback is actually performed if deployment fails.
- [ ] Task check notes record sanitized evidence only.

## Open Question

- Before Phase 2 execution, user must explicitly authorize the dangerous production write operation: stopping/restarting `new-api`, creating backups, loading candidate image, and editing/replacing compose/env keys for Phase 1.
