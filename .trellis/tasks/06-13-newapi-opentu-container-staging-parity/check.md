# Check — New-api/OpenTU Container Staging Parity

Date: 2026-06-13 (Asia/Shanghai)
Task: `.trellis/tasks/06-13-newapi-opentu-container-staging-parity`

## Result

**PASS for local Docker/container staging parity.**

A local `new-api` Docker image was built from the current candidate checkout, started as a disposable local container, and passed the embedded OpenTU artifact gate, browser embedded smoke, and redacted `GET`/`HEAD` route/header checks for `/creative/` static/API/relay boundaries.

This is **not** a production deployment verdict. Production/CDN/S3/provider/payment/publish checks remain `not-run`.

## Safety / Scope Statement

- No Docker image was pushed or published.
- No GitHub Actions release workflow, Docker manifest creation, deploy upload, SSH, or remote rsync/scp was run.
- No provider, payment, CDN, production S3, or production domain was called.
- No secret values were read, printed, copied, or persisted.
- Container runtime did not receive `SQL_DSN`, `REDIS_CONN_STRING`, provider/payment/CDN/S3 env, or production endpoint variables.
- HTTP checks sent no cookies/auth/provider credentials and recorded only status + selected headers, not response bodies.

Note: Docker build necessarily contacted normal package/image repositories for base metadata/packages/dependencies when cache was missing (`docker.io`, Debian apt, Go/Bun dependency fetches). This was build-time dependency retrieval only; no publish/deploy/provider/payment/CDN/S3 endpoint was called.

## Candidate / Image

- OpenTU candidate baseline from prior RC task: `39e0fe23180ffcfc98a767043869c4a90171356d`
- new-api candidate baseline from prior RC task: `c9f318c4210fc47b7454750b610945df5f0ddec4`
- local image tag:
  - `new-api-creative-embed:container-staging-20260613-225454`
- image inspect:
  - `IMAGE_ID=sha256:fe95e2ac97dfc4813480e9802c3e22ed28246bbde8ae3ab0664a4bf7a4c043d8`
  - `IMAGE_SIZE=221295156`

Local image was left present for traceability; it was not pushed. It can be removed later with:

```bash
docker rmi new-api-creative-embed:container-staging-20260613-225454
```

## Docker Packaging Evidence

Relevant Dockerfile contract in `/mnt/f/code/project/new-api/Dockerfile`:

```dockerfile
# web/creative/dist is a prebuilt opentu artifact provided by the CI pipeline (not built in this Dockerfile)
COPY ./web/creative/dist ./web/creative/dist
```

Relevant `.dockerignore` evidence:

- excludes `/web/default/dist` and `/web/classic/dist`, which are rebuilt by Dockerfile stages.
- does **not** exclude `/web/creative/dist`, so the prebuilt embedded Creative artifact remains in build context.

Build command:

```bash
cd /mnt/f/code/project/new-api
DOCKER_BUILDKIT=1 docker build --pull=false --progress=plain \
  -t new-api-creative-embed:container-staging-20260613-225454 .
```

Result: **PASS**

Key build evidence:

- Docker build context transferred successfully.
- Dockerfile step `COPY ./web/creative/dist ./web/creative/dist` executed successfully.
- Go binary build completed.
- Final image exported and tagged locally.

## Runtime Setup

Container target:

```text
http://localhost:39083
```

Run command shape used:

```bash
docker run -d \
  --name new-api-creative-container-staging-20260613-225454 \
  -p 127.0.0.1:39083:3000 \
  -e GIN_MODE=release \
  -e TZ=Asia/Shanghai \
  -e SESSION_SECRET=creative-container-local-session-secret \
  -e SYNC_FREQUENCY=3600 \
  -e UPDATE_TASK=false \
  -e CHANNEL_UPSTREAM_MODEL_UPDATE_TASK_ENABLED=false \
  -v /tmp/new-api-container-staging.TY8EPq/data:/data \
  -v /tmp/new-api-container-staging.TY8EPq/logs:/app/logs \
  new-api-creative-embed:container-staging-20260613-225454 \
  --log-dir /app/logs
```

Startup/readiness evidence:

- `/api/status` readiness returned `200 application/json`.
- container logs include:
  - `SQL_DSN not set, using SQLite as database`
  - `REDIS_CONN_STRING not set, Redis is not enabled`
  - `upstream model update task disabled by CHANNEL_UPSTREAM_MODEL_UPDATE_TASK_ENABLED`
  - server ready on container port `3000`

Warnings / notes:

- The container still started internal scheduled tasks such as Codex credential auto-refresh, subscription quota reset, and dashboard data update. Under this sanitized local no-secret container this did not reach production credentials, but long-running scheduler policy remains a production deployment item.
- `VERSION` in the local checkout is empty, so the container startup banner printed `New API  started` with a blank version. The release workflow writes `VERSION` from the tag before production image build; for ad-hoc local staging this is a warning, not a `/creative/` route parity failure.

Cleanup evidence:

- container running: `false`
- container exists: `false`
- temporary data/log directory exists: `false`
- port `39083` listening: `false`

## Gate 1 — Embedded Artifact / Source Diff Check

Command:

```bash
cd /mnt/f/code/project/new2fly
python3 scripts/creative_release_gate.py check --source-diff-check
```

Result: **PASS**

Key output:

- `opentu embedded index refs: 2 /creative/assets entries`
- `new-api:web embedded index refs: 2 /creative/assets entries`
- `new-api:router embedded index refs: 2 /creative/assets entries`
- `new-api:web matches opentu: 223 files`
- `new-api:router matches opentu: 223 files`
- `sourcemap-policy=allow; generated maps present: 1`
- `Creative embedded artifact contract holds`
- source-only `git diff --check` passed for `new2fly`, `opentu`, and `new-api` with generated artifact exclusions.

Production note: generated map policy remains a production release decision.

## Gate 2 — Embedded Browser Smoke Against Container

Command:

```bash
cd /mnt/f/code/project/new2fly
python3 scripts/creative_release_gate.py check \
  --embedded-smoke-url http://localhost:39083/creative/ \
  --drawnix-ready-timeout-ms 60000
```

Result: **PASS**

Key output:

- artifact contract checks passed again.
- `pnpm e2e:creative-embedded` ran Playwright project `creative-embedded`.
- `1 passed (24.5s)`.
- `NX Successfully ran target e2e for project web-e2e`.
- `no-secrets Creative release gate completed`.

Observed warning:

- pnpm printed `.npmrc` substitution warnings for `${NPM_TOKEN}` being unset. No token value was printed, and no publish/deploy command was run.

## Gate 3 — Container Route/Header Checks

Raw redacted table: [`route-check.md`](./route-check.md)

Summary:

| Surface | Result | Evidence |
|---|---|---|
| `/creative/` app shell | PASS | HEAD/GET `200`, `text/html`, `Cache-Control: no-cache`, no `Location`, `nosniff` |
| `/creative/sw.js` | PASS | HEAD/GET `200`, `text/javascript`, `no-cache`, no `Location`, `nosniff` |
| `/creative/version.json` | PASS | HEAD/GET `200`, `application/json`, `no-cache`, no `Location`, `nosniff` |
| existing JS asset | PASS | `/creative/assets/index-Bs1ESiJC.js` HEAD/GET `200`, `text/javascript`, `public, max-age=31536000, immutable`, no `Location`, `nosniff` |
| existing CSS asset | PASS | `/creative/assets/index-Bhsy9ZA3.css` HEAD/GET `200`, `text/css`, `public, max-age=31536000, immutable`, no `Location`, `nosniff` |
| missing asset | PASS | `/creative/assets/__missing_container_check__.js` HEAD/GET `404`, `text/plain`, `no-cache`, no `Location`, `nosniff`; not SPA fallback |
| API bootstrap | PASS | HEAD `404` and GET `401`, both `application/json`, `private, no-store`, no `Location`; GET unauthenticated fail-closed, HEAD wrong-method/static miss fail-closed |
| missing API | PASS | HEAD/GET `404`, `application/json`, `private, no-store`, no `Location`; not SPA fallback |
| relay GET/HEAD | PASS | `/creative/relay/v1/chat/completions` HEAD/GET `404`, `application/json`, `private, no-store`, no `Location`; GET/HEAD wrong-method fail-closed, not SPA fallback |

Important nuance:

- The route/header checker intentionally used only `GET`/`HEAD`.
- Non-SPA conclusions are based on status/content-type/cache/location and the route contract; response bodies were intentionally not captured.
- `GET /creative/api/bootstrap` did not include `x-content-type-options` in this observation. This is not blocking for route parity but remains a response-header consistency hardening note.

## Dynamic Workflow Independent Review

Dynamic workflow was used for independent read-only review over redacted observations.

Command:

```bash
codex-flow run .codex-flow/generated/container-staging-parity-review.workflow.ts
```

Journal:

- `.codex-flow/journal/container-staging-parity-review.jsonl`

Results:

| Branch | Verdict | Notes |
|---|---|---|
| `docker_packaging_no_secrets` | WARN | Local image/tag/route evidence matched; logs show SQLite/no Redis/no production credentials. Warned that production scheduler policy remains a gap and final report must record cleanup evidence. Cleanup evidence is now recorded above. |
| `creative_route_boundary` | PASS | All observed `/creative/` static/API/relay container routes match non-SPA, cache, and redirect expectations. |

Required notes incorporated:

- Local container parity does not prove production reverse-proxy/CDN/S3/provider/payment behavior.
- `HEAD /creative/api/bootstrap = 404` and `GET /creative/api/bootstrap = 401` are method-dependent fail-closed behaviors, not a parity failure.
- The dynamic workflow did not execute live checks itself; it only reviewed local redacted files.

## Production-only Not-run Items

These remain out of scope and were not executed:

- Docker image push or multi-arch manifest creation.
- GitHub Actions release workflows.
- Production/public base URL route/CDN/DNS checks.
- Redacted production env presence-only checks.
- S3-compatible asset storage health or object probes.
- Provider/payment/channel health.
- Publish credential identity/presence checks.
- NPM/Docker publish, deploy upload, SSH, rsync/scp.
- Final production sourcemap policy decision (`sw.js.map` currently present under allow policy).
- Production `FRONTEND_BASE_URL`/node-mode behavior.
- Long-running production scheduler/background-task policy.

## Acceptance Criteria Status

- [x] Planning artifacts define Docker/container parity scope and safety boundaries.
- [x] `implement.jsonl` and `check.jsonl` are curated.
- [x] Local candidate Docker image builds successfully.
- [x] Container runs locally with temporary data/log paths and no production env/secrets.
- [x] Embedded smoke passes against container `/creative/`.
- [x] Route/header checks run against the container and record redacted observations only.
- [x] Dynamic-workflow sidecar reviews redacted observations.
- [x] `check.md` summarizes pass/warn/fail/not-run per surface.
- [x] No tracked source changes outside Trellis/spec/reporting were introduced.

## Final Verdict

The embedded OpenTU/new-api candidate passes **local Docker/container staging parity** for `/creative/` packaging, app shell/static asset serving, API/relay non-SPA boundaries, and no-store/no-redirect behavior.

Recommended next stage is a separate, explicitly authorized real-environment readiness task covering production/staging env presence, public route/CDN/DNS, S3/provider/payment/channel health, and release/publish controls.
