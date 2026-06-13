# Design — New-api/OpenTU Staging Deployment

## Deployment Shape

Create a tracked local staging runbook and Docker Compose file:

```text
ops/newapi-opentu-staging/
  docker-compose.yml
  README.md
  .gitignore
  .env.staging.local   # generated, ignored, not committed
```

The service runs from local image `new-api-creative-embed:staging-current` and is exposed at:

```text
http://localhost:39084
http://localhost:39084/creative/
```

Default bind is `127.0.0.1` for safety. LAN/public exposure is a later explicit decision.

## Image Contract

Before deployment:

1. run artifact gate with `--source-diff-check`,
2. build/tag candidate image:

```bash
docker build --pull=false --progress=plain \
  -t new-api-creative-embed:staging-current \
  /mnt/f/code/project/new-api
```

No `--push` and no release tag.

## Runtime Contract

Compose service:

- image: `new-api-creative-embed:staging-current`
- container: `newapi-opentu-staging-new-api`
- restart: `unless-stopped`
- ports: `127.0.0.1:39084:3000`
- command: `--log-dir /app/logs`
- volumes:
  - `newapi_opentu_staging_data:/data`
  - `newapi_opentu_staging_logs:/app/logs`
- env:
  - `GIN_MODE=release`
  - `TZ=Asia/Shanghai`
  - `SYNC_FREQUENCY=3600`
  - `UPDATE_TASK=false`
  - `CHANNEL_UPSTREAM_MODEL_UPDATE_TASK_ENABLED=false`
  - generated `SESSION_SECRET` from ignored env file

Do not set:

- `SQL_DSN`
- `REDIS_CONN_STRING`
- provider/payment/CDN/S3 credentials
- production endpoint variables
- analytics/Pyroscope variables

## Verification Design

1. Health/readiness check:
   - `GET /api/status` returns JSON success on localhost.
2. Embedded smoke:
   - `python3 scripts/creative_release_gate.py check --embedded-smoke-url http://localhost:39084/creative/ --drawnix-ready-timeout-ms 60000`
3. Route/header matrix:
   - same static/API/relay paths as previous gates,
   - `GET`/`HEAD` only,
   - selected headers only,
   - no bodies or auth.
4. Dynamic workflow:
   - read-only review of ops config, task evidence, and route table.

## Operational Commands

Start/recreate:

```bash
cd /mnt/f/code/project/new2fly
STAGING_BIND_ADDR=127.0.0.1 STAGING_PORT=39084 \
  docker compose -f ops/newapi-opentu-staging/docker-compose.yml \
  -p newapi-opentu-staging up -d
```

Stop without deleting data:

```bash
docker compose -f ops/newapi-opentu-staging/docker-compose.yml \
  -p newapi-opentu-staging down
```

Delete staging data/log volumes only if intentionally resetting staging:

```bash
docker compose -f ops/newapi-opentu-staging/docker-compose.yml \
  -p newapi-opentu-staging down -v
```

## Limitations

This local staging deployment does not prove public domain/CDN/DNS/TLS/S3/provider/payment behavior and must not be described as production readiness.
