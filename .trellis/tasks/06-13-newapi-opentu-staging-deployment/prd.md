# New-api/OpenTU Staging Deployment

## Goal

Create a safe, persistent local staging deployment for the embedded OpenTU/new-api release candidate, using Docker Compose and the locally built candidate image, so the user has a running staging URL to access after the task finishes.

This stage promotes prior disposable container parity into a durable local staging service. It remains non-production: no provider/payment/CDN/S3 integrations, no public deploy, no image push, and no secret values in git or reports.

## Background / Confirmed Facts

- Local `go run` staging route checks passed:
  - `.trellis/tasks/archive/2026-06/06-13-release-env-live-readonly-checks/check.md`
- Local Docker/container parity checks passed:
  - `.trellis/tasks/archive/2026-06/06-13-newapi-opentu-container-staging-parity/check.md`
- The previous local Docker image proved the Dockerfile packages `web/creative/dist` correctly.
- The user asked to continue from validation into actual deployment.
- Recommended safe deployment target for this task:
  - local Docker Compose service,
  - bound to `127.0.0.1:39084` by default,
  - persistent until explicitly stopped,
  - temporary/non-production SQLite volume,
  - generated local session secret in an ignored env file,
  - no production credentials or external service configs.

## Requirements

1. Create durable local staging operations files under `ops/newapi-opentu-staging/`.
2. Do not commit local secret/env files.
3. Build/tag the local candidate image as `new-api-creative-embed:staging-current`.
4. Start Docker Compose project `newapi-opentu-staging` with:
   - local-only default bind: `127.0.0.1:39084:3000`,
   - named volumes for `/data` and `/app/logs`,
   - no `SQL_DSN`, no `REDIS_CONN_STRING`, no provider/payment/CDN/S3 env,
   - `GIN_MODE=release`,
   - `UPDATE_TASK=false`,
   - `CHANNEL_UPSTREAM_MODEL_UPDATE_TASK_ENABLED=false`,
   - long `SYNC_FREQUENCY`,
   - local generated `SESSION_SECRET` stored in an ignored file.
5. Verify staging URL:
   - `http://localhost:39084/creative/`
6. Run embedded smoke and redacted route/header checks against the deployed service.
7. Use dynamic workflow for a read-only deployment review over redacted observations.
8. Leave the staging service running at the end if checks pass.
9. Document stop/restart commands.

## Out of Scope Unless Separately Confirmed

- Binding to LAN/public interfaces (`0.0.0.0`) or configuring firewall rules.
- Domain, TLS, reverse proxy, CDN, or DNS.
- S3/provider/payment/channel health checks.
- Production env presence checks.
- Docker image push, multi-arch manifest creation, or GitHub Actions release workflow.
- Reading or printing any existing secrets.
- Creating a root user or initializing application data through UI/API.

## Acceptance Criteria

- [ ] `ops/newapi-opentu-staging/` contains a safe Docker Compose staging config and README/runbook.
- [ ] Local secret env file is generated but ignored/untracked and not printed.
- [ ] `new-api-creative-embed:staging-current` image is built from the candidate checkout.
- [ ] Compose service is running and healthy on `http://localhost:39084`.
- [ ] Embedded smoke passes against `http://localhost:39084/creative/` or failure is captured.
- [ ] Route/header checks pass and record redacted observations only.
- [ ] Dynamic workflow reviews the deployment evidence.
- [ ] Final `check.md` includes URL, commands, pass/warn/fail/not-run, and stop/restart instructions.
- [ ] No tracked source changes outside ops/Trellis/spec/reporting are introduced unless separately approved.
