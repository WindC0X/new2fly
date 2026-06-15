# New-api/OpenTU Local Staging

Safe local Docker Compose staging for the embedded OpenTU `/creative/` candidate.

Default URL:

```text
http://localhost:39084/creative/
```

## Safety defaults

- Binds to `127.0.0.1` by default, not LAN/public.
- Uses local Docker image `new-api-creative-embed:staging-current`.
- Uses SQLite by leaving `SQL_DSN` unset.
- Leaves Redis unset.
- Does not configure provider/payment/CDN/S3 credentials.
- Stores `SESSION_SECRET` in ignored `.env.staging.local`.

## Build candidate image

From repo root:

```bash
python3 scripts/creative_release_gate.py check --source-diff-check
docker build --pull=false --progress=plain \
  -t new-api-creative-embed:staging-current \
  /mnt/f/code/project/new-api
```

## Start / restart

```bash
STAGING_BIND_ADDR=127.0.0.1 STAGING_PORT=39084 \
  docker compose -f ops/newapi-opentu-staging/docker-compose.yml \
  -p newapi-opentu-staging up -d
```

## Stop without deleting data

```bash
docker compose -f ops/newapi-opentu-staging/docker-compose.yml \
  -p newapi-opentu-staging down
```

## Reset staging data/log volumes

Only run this when intentionally wiping local staging state:

```bash
docker compose -f ops/newapi-opentu-staging/docker-compose.yml \
  -p newapi-opentu-staging down -v
```

## LAN exposure

Do not expose staging to LAN/public by default. If explicitly approved later, recreate with:

```bash
STAGING_BIND_ADDR=0.0.0.0 STAGING_PORT=39084 \
  docker compose -f ops/newapi-opentu-staging/docker-compose.yml \
  -p newapi-opentu-staging up -d
```

Then re-run the route/header checks against the chosen host.

## Production deployment

Production deployment is intentionally separate from this local staging runbook. See:

```text
ops/newapi-opentu-production/README.md
ops/newapi-opentu-production/env.production.example
```

Do not copy `.env.staging.local` into production.
