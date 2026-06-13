# Design — Container Staging Parity Checks

## Deployment Shape

Use direct local Docker build/run instead of the repository `docker-compose.yml`.

Why direct Docker commands:

- validates the actual Dockerfile packaging path,
- avoids pulling the published `calciumion/new-api:latest` image,
- avoids compose's default Postgres/Redis password topology,
- keeps all checks local and disposable.

## Build Contract

Build from `/mnt/f/code/project/new-api`:

```bash
docker build \
  --pull=false \
  -t new-api-creative-embed:container-staging-<timestamp> \
  /mnt/f/code/project/new-api
```

Notes:

- No `--push`.
- No release tag.
- Dockerfile must include `web/creative/dist` from the local checkout.
- Run the no-secrets artifact gate before/around the build to prove the local artifact is synchronized.

## Runtime Contract

Run the image as a short-lived local container:

```bash
docker run --rm \
  --name new-api-creative-container-staging-<timestamp> \
  -p 127.0.0.1:<host-port>:3000 \
  -e GIN_MODE=release \
  -e TZ=Asia/Shanghai \
  -e SESSION_SECRET=creative-container-local-session-secret \
  -e SYNC_FREQUENCY=3600 \
  -e UPDATE_TASK=false \
  -e CHANNEL_UPSTREAM_MODEL_UPDATE_TASK_ENABLED=false \
  -v <tmp-data>:/data \
  -v <tmp-logs>:/app/logs \
  new-api-creative-embed:container-staging-<timestamp> \
  --log-dir /app/logs
```

Do not set `SQL_DSN`; the container should use SQLite under `/data`.
Do not set `REDIS_CONN_STRING`, provider keys, payment keys, S3 config, CDN config, analytics keys, Pyroscope config, or production endpoints.

## Route/Header Checker

Use the same redaction contract as local `go run` staging:

- only `GET`/`HEAD`,
- no cookies/auth/secrets,
- no response bodies,
- selected headers only: `content-type`, `cache-control`, `location`, `x-content-type-options`, and any `x-creative-*` if present,
- classify `pass`/`warn`/`fail`/`not-run`.

## Dynamic Workflow Use

After the main session collects redacted observations, run read-only dynamic-workflow sidecars over:

1. Docker packaging/no-secrets hygiene,
2. static route/cache boundary,
3. API/relay non-SPA and no-store boundary.

Sidecars must not run live checks themselves. They receive only local files and redacted observations.

## Cleanup

- Stop/remove the container after checks.
- Remove temporary data/log dirs if no longer needed.
- Optionally remove the local image if space is a concern; this is not required for the report and should be recorded if done.

## Limitations

Container staging validates packaging and runtime parity on the local Docker host. It still does not prove:

- public CDN/DNS routing,
- production env correctness,
- S3/provider/payment health,
- multi-arch image build/push,
- production scheduler policy,
- final production sourcemap policy.
