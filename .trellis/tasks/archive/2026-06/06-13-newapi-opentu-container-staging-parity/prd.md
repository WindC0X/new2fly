# New-api/OpenTU Container Staging Parity Checks

## Goal

Verify that the embedded OpenTU `/creative/` release candidate works from the `new-api` Docker/container path, not only from local `go run` staging.

The task builds a local Docker image from `/mnt/f/code/project/new-api`, runs it as a short-lived local container staging instance, and repeats the embedded smoke plus redacted route/header checks against the container. This validates that the Dockerfile includes the prebuilt `web/creative/dist` artifact and that the compiled binary serves the same `/creative/` static/API/relay boundary in a container.

## Background / Confirmed Facts

- Local `go run` staging checks passed and are archived at:
  - `.trellis/tasks/archive/2026-06/06-13-release-env-live-readonly-checks/check.md`
- The Dockerfile in `/mnt/f/code/project/new-api` builds default/classic frontends, compiles Go, and explicitly copies prebuilt Creative artifact:
  - `COPY ./web/creative/dist ./web/creative/dist`
  - comment: `web/creative/dist is a prebuilt opentu artifact provided by the CI pipeline (not built in this Dockerfile)`
- `.dockerignore` excludes default/classic generated dist paths but does not exclude `web/creative/dist`, so the Creative artifact should be present in Docker build context.
- Existing `docker-compose.yml` is not safe as-is for this check because it uses default Postgres/Redis passwords and pulls/runs the published `calciumion/new-api:latest` image rather than the local candidate unless edited.
- Recommended check path: direct local `docker build` + `docker run` with temporary data/log volumes, no push, no compose production defaults.

## Requirements

1. Build a local Docker image from the current `/mnt/f/code/project/new-api` checkout.
2. Do not push, publish, tag as release, or upload the image.
3. Do not read, print, copy, or persist secret values.
4. Do not call provider, payment, CDN, production S3, production domains, or publish/deploy endpoints.
5. Do not use the default `docker-compose.yml` production-like Postgres/Redis password topology for readiness claims.
6. Run the container with local-only port mapping and temporary local data/log directories.
7. Prefer SQLite by leaving `SQL_DSN` unset inside the container; do not mount production DB/Redis/S3 credentials.
8. Disable known background upstream update jobs where supported:
   - `UPDATE_TASK=false`
   - `CHANNEL_UPSTREAM_MODEL_UPDATE_TASK_ENABLED=false`
   - long `SYNC_FREQUENCY`
9. Run embedded smoke against `http://localhost:<port>/creative/`.
10. Run redacted `GET`/`HEAD` route/header checks only; record selected headers and status, not response bodies.
11. Use dynamic workflow for independent read-only review of redacted observations.

## Container Check Set

Target base URL: local container staging, expected `http://localhost:<port>`.

Paths to check with `GET` and/or `HEAD`:

- `/creative/`
- `/creative/sw.js`
- `/creative/version.json`
- existing hashed JS asset from the verified artifact
- existing hashed CSS asset from the verified artifact
- `/creative/assets/__missing_container_check__.js`
- `/creative/api/bootstrap`
- `/creative/api/missing`
- `/creative/relay/v1/chat/completions`

Expected high-level behavior:

- `/creative/`, `sw.js`, `version.json`, and existing assets are served by the containerized local host.
- Existing static assets have appropriate static content types and cache behavior.
- Missing `/creative/assets/*` returns a static miss, not the SPA app shell.
- `/creative/api/*` and `/creative/relay/v1/*` do not return the SPA app shell and carry no-store/no-cache-like headers.
- Creative API/relay paths do not redirect to an external frontend host.

## Out of Scope Unless Separately Confirmed

- Pushing Docker images or creating multi-arch manifests.
- Running GitHub Actions release workflows.
- Production/public domain deployment.
- Provider/payment/channel/S3/CDN health checks.
- Production env presence checks.
- Editing upstream Docker compose defaults beyond documenting local safe usage.
- Final production sourcemap policy decision.

## Acceptance Criteria

- [ ] Planning artifacts define Docker/container parity scope and safety boundaries.
- [ ] `implement.jsonl` and `check.jsonl` are curated with relevant specs and prior reports.
- [ ] The local candidate Docker image builds successfully or the exact failure is captured.
- [ ] The container runs locally with temporary data/log paths and no production env/secrets.
- [ ] Embedded smoke passes against container `/creative/` or the failure is captured with evidence.
- [ ] Route/header checks run against the container and record redacted observations only.
- [ ] Dynamic-workflow sidecar reviews the redacted observations.
- [ ] `check.md` summarizes pass/warn/fail/not-run per surface.
- [ ] No tracked source changes outside Trellis/spec/reporting are introduced unless separately approved.
