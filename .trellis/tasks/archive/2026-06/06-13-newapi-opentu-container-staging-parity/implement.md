# Implementation Plan — Container Staging Parity Checks

## Phase 1 — Planning and context

1. Create the Trellis task and write PRD/design/implement artifacts.
2. Curate `implement.jsonl` and `check.jsonl` with specs and prior reports.
3. Validate and start the task.

## Phase 2 — Build preflight

1. Confirm Docker availability.
2. Run artifact/source gate:
   - `python3 scripts/creative_release_gate.py check --source-diff-check`
3. Extract current hashed JS/CSS asset paths from `new-api/web/creative/dist/index.html`.
4. Inspect/record Dockerfile contract:
   - Dockerfile copies `./web/creative/dist` into build context.
   - `.dockerignore` does not exclude `web/creative/dist`.

## Phase 3 — Local image and container staging

1. Build a local-only image from `/mnt/f/code/project/new-api`.
2. Pick an unused local host port, defaulting to `39083` if free.
3. Run the container with:
   - local-only port binding,
   - temporary data/log dirs,
   - no `SQL_DSN` and no `REDIS_CONN_STRING`,
   - no provider/payment/CDN/S3 env,
   - disabled upstream update tasks where supported.
4. Wait for `/api/status` or startup log readiness.

## Phase 4 — Checks

1. Run embedded smoke against `http://localhost:<port>/creative/`.
2. Run redacted route/header table against container target paths.
3. Stop the container and clean temporary dirs after evidence is captured.
4. Run dynamic-workflow read-only sidecar review.
5. Write `check.md` with build, runtime, smoke, route, and dynamic review results.

## Phase 5 — Finish

1. Run final validation:
   - Trellis context validate,
   - `git diff --check`,
   - no container still listening/running.
2. Update specs if new durable Docker/container release rule was learned.
3. Commit, archive, journal, and push `new2fly`.

## Rollback / safety

- If Docker build fails, capture failure and do not try production images as a substitute.
- If container starts printing secrets or connects to unexpected services, stop it immediately and record a sanitized failure.
- Do not push image, run release workflows, or deploy.
