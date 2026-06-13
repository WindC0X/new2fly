# Check — New-api/OpenTU Local Staging Deployment

Date: 2026-06-13 (Asia/Shanghai)
Task: `.trellis/tasks/06-13-newapi-opentu-staging-deployment`

## Result

**PASS for persistent local staging deployment.**

A Docker Compose staging service is running locally and healthy at:

```text
http://localhost:39084/creative/
```

This is a **local staging** deployment, bound to `127.0.0.1` by default. It is not a production/public deployment verdict.

## Current Running Service

Compose project:

```text
newapi-opentu-staging
```

Container:

```text
newapi-opentu-staging-new-api
```

Image:

```text
new-api-creative-embed:staging-current
IMAGE_ID=sha256:fe95e2ac97dfc4813480e9802c3e22ed28246bbde8ae3ab0664a4bf7a4c043d8
IMAGE_SIZE=221295156
```

Service status evidence at `2026-06-13T15:20:38Z`:

```text
Up healthy
127.0.0.1:39084->3000/tcp
/api/status => 200 application/json
```

Latest verification evidence was refreshed after the initial dynamic review warning; see:

- `smoke-evidence.txt`
- `route-check.md`
- `service-status.md`

## Safety / Scope Statement

- No Docker image was pushed or published.
- No GitHub Actions release workflow, manifest creation, deploy upload, SSH, or remote rsync/scp was run.
- No provider, payment, CDN, production S3, or production/public domain was called.
- No existing secret values were read, printed, copied, or persisted.
- A new local staging `SESSION_SECRET` was generated into ignored file:
  - `ops/newapi-opentu-staging/.env.staging.local`
  - value was not printed and is not committed.
- The service did not receive `SQL_DSN` or `REDIS_CONN_STRING`; logs show SQLite fallback and Redis disabled.
- Default binding is localhost only: `127.0.0.1:39084`.

Build-time note: Docker build may contact normal package/image repositories if caches are missing. This task did not push/publish images or call provider/payment/CDN/S3 services.

## Ops Files Added

```text
ops/newapi-opentu-staging/docker-compose.yml
ops/newapi-opentu-staging/README.md
ops/newapi-opentu-staging/.gitignore
```

The ignored local env file exists for runtime but is not tracked:

```text
ops/newapi-opentu-staging/.gitignore:1:.env.staging.local ops/newapi-opentu-staging/.env.staging.local
```

## Deployment Commands

Build candidate image:

```bash
python3 scripts/creative_release_gate.py check --source-diff-check
docker build --pull=false --progress=plain \
  -t new-api-creative-embed:staging-current \
  /mnt/f/code/project/new-api
```

Start/recreate staging:

```bash
STAGING_BIND_ADDR=127.0.0.1 STAGING_PORT=39084 \
  docker compose -f ops/newapi-opentu-staging/docker-compose.yml \
  -p newapi-opentu-staging up -d
```

Stop without deleting data:

```bash
docker compose -f ops/newapi-opentu-staging/docker-compose.yml \
  -p newapi-opentu-staging down
```

Reset local staging data/log volumes:

```bash
docker compose -f ops/newapi-opentu-staging/docker-compose.yml \
  -p newapi-opentu-staging down -v
```

## Gate 1 — Artifact / Build Gate

Command:

```bash
python3 scripts/creative_release_gate.py check --source-diff-check
```

Result: **PASS**

Evidence:

- OpenTU/new-api embedded index refs point to `/creative/assets/...`.
- `new-api:web` matches OpenTU dist: 223 files.
- `new-api:router` matches OpenTU dist: 223 files.
- generated maps present under `sourcemap-policy=allow`.
- source-only `git diff --check` passed with generated artifact exclusions.

## Gate 2 — Image Build

Command:

```bash
DOCKER_BUILDKIT=1 docker build --pull=false --progress=plain \
  -t new-api-creative-embed:staging-current \
  /mnt/f/code/project/new-api
```

Result: **PASS**

Evidence:

- build completed successfully.
- Dockerfile Creative dist copy step was cached from the prior successful candidate build but remains part of the same image chain:
  - `COPY ./web/creative/dist ./web/creative/dist`
- final local image tag `new-api-creative-embed:staging-current` points to the expected image id above.

## Gate 3 — Runtime Readiness

Result: **PASS**

Evidence from `deployment-evidence.txt` and `service-status.md`:

- compose service created and started.
- `/api/status` returned `200 application/json`.
- compose reports `Up ... (healthy)`.
- container logs include:
  - `SQL_DSN not set, using SQLite as database`
  - `REDIS_CONN_STRING not set, Redis is not enabled`
  - `upstream model update task disabled by CHANNEL_UPSTREAM_MODEL_UPDATE_TASK_ENABLED`

Warnings:

- Container logs still show internal scheduled tasks such as Codex credential auto-refresh, subscription quota reset, and dashboard data update. With no production credentials and localhost-only staging this is acceptable for this local deployment, but production scheduler policy remains not-run.
- `VERSION` in the local checkout is empty, so the startup banner has a blank New API version. The production release workflow writes `VERSION` from tag; this is not a `/creative/` staging blocker.

## Gate 4 — Embedded Smoke

Command:

```bash
python3 scripts/creative_release_gate.py check \
  --embedded-smoke-url http://localhost:39084/creative/ \
  --drawnix-ready-timeout-ms 60000
```

Result: **PASS**

Saved evidence: `smoke-evidence.txt`

Key output:

- artifact contract checks passed.
- Playwright project `creative-embedded` ran against the persistent staging URL.
- `1 passed (21.8s)` in the saved rerun.
- `NX Successfully ran target e2e for project web-e2e`.
- `no-secrets Creative release gate completed`.

Observed warning:

- pnpm printed `.npmrc` substitution warnings for `${NPM_TOKEN}` being unset. No token value was printed, and no publish/deploy command was run.

## Gate 5 — Route/Header Checks

Raw redacted table: [`route-check.md`](./route-check.md)

Summary:

| Surface | Result | Evidence |
|---|---|---|
| `/creative/` app shell | PASS | HEAD/GET `200`, `text/html`, `Cache-Control: no-cache`, no `Location`, `nosniff` |
| `/creative/sw.js` | PASS | HEAD/GET `200`, `text/javascript`, `no-cache`, no `Location`, `nosniff` |
| `/creative/version.json` | PASS | HEAD/GET `200`, `application/json`, `no-cache`, no `Location`, `nosniff` |
| existing JS asset | PASS | `/creative/assets/index-Bs1ESiJC.js` HEAD/GET `200`, `text/javascript`, `public, max-age=31536000, immutable`, no `Location`, `nosniff` |
| existing CSS asset | PASS | `/creative/assets/index-Bhsy9ZA3.css` HEAD/GET `200`, `text/css`, `public, max-age=31536000, immutable`, no `Location`, `nosniff` |
| missing asset | PASS | `/creative/assets/__missing_staging_deploy_check__.js` HEAD/GET `404`, `text/plain`, `no-cache`, no `Location`, `nosniff`; not SPA fallback |
| API bootstrap | PASS | HEAD `404` and GET `401`, both `application/json`, `private, no-store`, no `Location`; GET unauthenticated fail-closed, HEAD wrong-method/static miss fail-closed |
| missing API | PASS | HEAD/GET `404`, `application/json`, `private, no-store`, no `Location`; not SPA fallback |
| relay GET/HEAD | PASS | `/creative/relay/v1/chat/completions` HEAD/GET `404`, `application/json`, `private, no-store`, no `Location`; GET/HEAD wrong-method fail-closed, not SPA fallback |

Note: `GET /creative/api/bootstrap` did not include `x-content-type-options`; this is a non-blocking response-header consistency hardening note already seen in previous local gates.

## Dynamic Workflow Review

Dynamic workflow was used for read-only review of redacted evidence.

Commands / journals:

```text
.codex-flow/journal/staging-deployment-review.jsonl
.codex-flow/journal/staging-deployment-summary-review.jsonl
```

Results:

| Branch | Verdict | Notes |
|---|---|---|
| `ops_deployment_safety` | WARN | Compose and logs match local safe staging; warned not to overclaim production and not to claim `.env.staging.local` contents because it was intentionally not read. |
| `route_and_smoke_readiness` | WARN | Initial review saw route/status evidence but did not find saved 39084 smoke output. This was corrected by rerunning smoke and saving `smoke-evidence.txt`. |
| redacted summary readiness review | PASS | Based on summarized redacted evidence, local persistent staging at `http://localhost:39084/creative/` can be reported ready, with production gaps explicitly not-run. |

## Production / Public Not-run Items

These remain out of scope and were not executed:

- Public DNS/domain/TLS/reverse proxy/CDN.
- LAN/public exposure (`STAGING_BIND_ADDR=0.0.0.0`).
- Production env presence-only check.
- S3-compatible asset storage health.
- Provider/payment/channel health.
- Docker image push or multi-arch manifest creation.
- GitHub Actions release workflows.
- NPM/Docker publish, deploy upload, SSH, rsync/scp.
- Production `FRONTEND_BASE_URL` behavior.
- Final production sourcemap policy.
- Production scheduler/background-task policy.

## Acceptance Criteria Status

- [x] `ops/newapi-opentu-staging/` contains Docker Compose staging config and README.
- [x] Local secret env file is generated, ignored, untracked, and value not printed.
- [x] `new-api-creative-embed:staging-current` image is built from candidate checkout.
- [x] Compose service is running and healthy on `http://localhost:39084`.
- [x] Embedded smoke passes against `http://localhost:39084/creative/`.
- [x] Route/header checks pass with redacted observations only.
- [x] Dynamic workflow reviews deployment evidence.
- [x] `check.md` includes URL, commands, pass/warn/fail/not-run, and stop/restart instructions.
- [x] No tracked source changes outside ops/Trellis/spec/reporting were introduced.

## Final Verdict

The local persistent staging deployment is ready at:

```text
http://localhost:39084/creative/
```

Use this as the current safe staging URL for manual browser checks. It is localhost-only unless separately changed and rechecked.
