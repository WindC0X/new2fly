# Design — Release Environment Readiness Checks

## Boundary Model

This task uses a two-tier verification boundary.

### Tier A: Safe local/static checks (default)

Allowed without extra authorization:

- Inspect source files, docs, examples, workflow files, Dockerfiles, and already-produced reports.
- Check existence of expected config templates and release commands.
- Compare candidate commits/refs and artifact policies.
- Run no-secret local commands that do not call provider/payment/CDN/production endpoints.
- Generate redacted checklists and runbooks.

Forbidden in Tier A:

- Reading actual secret values.
- Invoking real provider/payment/CDN APIs.
- Publishing packages/images or uploading artifacts.
- Running SSH deployment scripts.

### Tier B: Live read-only release-environment checks (requires explicit confirmation)

Allowed only after the user provides target environment details and confirms the operations:

- HTTP `GET`/`HEAD` against a specified staging/production base URL for route and cache-header checks.
- Secret presence checks that report only present/missing, never values.
- Object-storage health checks that use safe list/head/presign probes and redact bucket/key/credential material.
- Provider/payment/channel health checks that use existing safe health endpoints or dry-run/read-only status endpoints.
- Publish credential checks that verify identity/session without publishing, where the tool supports it.

Forbidden even in Tier B unless separately confirmed:

- Upload/delete object storage data outside a controlled disposable test key.
- Triggering provider jobs, paid requests, payment transactions, refunds, or webhook deliveries.
- Publishing NPM packages, Docker images, or deployment artifacts.
- Changing DNS/CDN/reverse-proxy settings.

## Check Surfaces

### 1. Environment and secrets injection

Expected evidence:

- Release deploy system defines required variables by name.
- The check reports only `present`, `missing`, `empty`, or `default/unsafe`, not values.
- Dangerous defaults such as `SESSION_SECRET=random_string`, default DB/Redis passwords, SQLite in production, or database asset storage in production are flagged.

Key Creative/new-api variables to account for include:

- `SESSION_SECRET`
- `SQL_DSN` or intentionally managed database binding
- `REDIS_CONN_STRING` when Redis is expected
- `FRONTEND_BASE_URL`
- `TRUSTED_REDIRECT_DOMAINS`
- `CREATIVE_VIDEO_RELAY_ENABLED`
- `CREATIVE_ASSET_SYNC_ENABLED`
- `CREATIVE_ASSET_ROLLOUT_MODE`
- `CREATIVE_ASSET_STORAGE`
- `CREATIVE_ASSET_S3_ENDPOINT`
- `CREATIVE_ASSET_S3_REGION`
- `CREATIVE_ASSET_S3_BUCKET`
- `CREATIVE_ASSET_S3_PREFIX`
- `CREATIVE_ASSET_S3_ACCESS_KEY_ID`
- `CREATIVE_ASSET_S3_SECRET_ACCESS_KEY`
- `CREATIVE_ASSET_S3_FORCE_PATH_STYLE`
- `CHANNEL_UPSTREAM_MODEL_UPDATE_TASK_ENABLED`
- `UPDATE_TASK`

### 2. `/creative/` domain/reverse-proxy/CDN routing

Expected route behavior:

- `GET /creative/` serves the Creative app shell.
- `GET /creative/assets/<known asset>` returns static asset with an immutable/static cache policy.
- Missing `/creative/assets/*` returns static 404 and not SPA HTML.
- `/creative/api/*` and `/creative/relay/v1/*` are not rewritten to SPA fallback.
- Service worker is scoped under `/creative/` and does not capture non-Creative routes.
- `FRONTEND_BASE_URL` must not redirect Creative API/relay/static routes away from new-api.

### 3. Object storage / CDN for Creative assets

Expected behavior:

- Production rollout should use S3-compatible storage, not database storage, unless explicitly canary/local.
- Bucket/prefix/region/endpoint force-path-style settings match the actual provider.
- Access policy is private by default; browser-facing URLs are generated through the intended proxy/presign path.
- Health checks must not list or print unrelated object keys; if a live probe is needed, use a disposable prefix/key and clean it up only with explicit approval.

### 4. Provider/payment/channel health

Expected behavior:

- Checks are read-only or use existing health/status mechanisms.
- No paid generation, payment mutation, refund, or webhook send is triggered.
- Creative relay failure paths fail closed and do not expose upstream secrets or unredacted provider responses.

### 5. Publish/release path

Expected behavior:

- new-api Docker path includes the embedded `web/creative/dist` artifacts.
- Docker/GHCR/NPM credentials are verified by presence or non-mutating identity checks only.
- OpenTU standalone/hybrid publish path and embedded new-api path are not conflated.
- Production sourcemap policy is explicit: either forbid maps and enforce `--sourcemap-policy forbid`, or allow known generated maps with rationale.

## Reporting Contract

`check.md` should have one row per surface:

- Surface
- Status: `pass`, `warn`, `fail`, or `not-run`
- Evidence
- Risk
- Required follow-up / owner

For any live checks, include:

- target base URL/environment name,
- exact command category,
- redaction statement,
- whether the call was read-only,
- timestamp.
