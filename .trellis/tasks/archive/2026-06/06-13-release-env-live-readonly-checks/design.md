# Design — Local/Intranet Staging Deploy and Live Route Checks

## Deployment Shape

Use a short-lived local release-like staging instance instead of a production/staging host that does not yet exist.

Recommended command shape:

```bash
cd /mnt/f/code/project/new-api
tmpdir=$(mktemp -d /tmp/new-api-local-staging.XXXXXX)
env -i \
  PATH="$PATH" \
  HOME="$HOME" \
  USER="${USER:-windc0x}" \
  GOCACHE="$(go env GOCACHE)" \
  GOMODCACHE="$(go env GOMODCACHE)" \
  CGO_ENABLED="$(go env CGO_ENABLED)" \
  PORT=<unused-local-port> \
  SQLITE_PATH="$tmpdir/one-api.db?_busy_timeout=30000" \
  SESSION_SECRET="creative-staging-local-session-secret" \
  GIN_MODE=release \
  SYNC_FREQUENCY=3600 \
  UPDATE_TASK=false \
  CHANNEL_UPSTREAM_MODEL_UPDATE_TASK_ENABLED=false \
  go run . --log-dir "$tmpdir/logs"
```

This is release-like for routing/static/API behavior while intentionally not validating Docker image packaging, production S3, CDN, DNS, provider credentials, or payment integrations.

## Safety Model

### Allowed by default for this task

- Read local specs, task reports, source metadata, and generated artifacts.
- Start a temporary local `new-api` process with sanitized environment and temporary SQLite.
- Run localhost `GET`/`HEAD` checks for `/creative/` paths.
- Run the existing release gate and embedded smoke against localhost.
- Pass redacted route observations into dynamic-workflow read-only sidecars.

### Always forbidden in this task unless a later explicit confirmation narrows and authorizes the exact operation

- Printing secret values.
- Calling provider/payment/CDN/production domains or production S3.
- Mutating storage/provider/payment/channel/release state.
- Publish/deploy/upload/SSH/remote rsync/scp commands.
- Running external channel tests that consume quota.

## Local Staging Contract

- The process environment must be constructed with `env -i`; do not inherit ambient host `.env`/provider/payment/CDN variables.
- Use temporary SQLite. Do not connect to production DB/Redis/S3.
- Disable known background update jobs (`UPDATE_TASK=false`, `CHANNEL_UPSTREAM_MODEL_UPDATE_TASK_ENABLED=false`) for this short-lived staging run.
- Bind to a local port already checked as unused.
- Stop the process after checks and clean temporary files if safe.

## HTTP Route/Header Checker

The checker should:

- use only `GET` and `HEAD`,
- not send cookies, auth, nonce, or provider credentials,
- not print response bodies,
- cap timeouts,
- record status, selected headers, effective URL, and `Location`,
- classify behavior as `pass`, `warn`, `fail`, or `not-run`.

Selected headers:

- `content-type`
- `cache-control`
- `location`
- `x-creative-*` if present
- selected security/static headers such as `x-content-type-options` if useful

Target paths:

- `/creative/`
- `/creative/sw.js`
- `/creative/version.json`
- existing hashed JS asset
- existing hashed CSS asset
- `/creative/assets/__missing_release_check__.js`
- `/creative/api/bootstrap`
- `/creative/api/missing`
- `/creative/relay/v1/chat/completions`

## Result Classification

- `pass`: local staging evidence matches the embedded release contract.
- `warn`: behavior may be valid but needs a production policy decision or was only partially covered.
- `fail`: behavior violates the route/static/API boundary, e.g. missing assets return SPA HTML, API/relay returns app shell, or Creative paths redirect to an unintended external host.
- `not-run`: production-only surfaces not exercised in local staging.

## Dynamic Workflow Use

After the main session collects redacted route/header observations, run a read-only dynamic workflow with independent branches such as:

1. route/static/cache boundary review,
2. no-secrets/local-staging hygiene review,
3. production-only gap/runbook review.

Sidecars must not call endpoints independently. They receive the redacted observations and local report paths only.

## Rollback / Cleanup

- Stop the local `new-api` process on failure or after checks.
- Remove temporary SQLite/log directory if it contains no information needed for the report.
- If a command starts printing secrets or response bodies, interrupt it and record a sanitized failure note.
