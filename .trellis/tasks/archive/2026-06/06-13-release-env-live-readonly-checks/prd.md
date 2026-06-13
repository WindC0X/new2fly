# Local/Intranet Staging Deploy and Live Route Checks

## Goal

Build a temporary release-like local/intranet staging deployment for the embedded OpenTU/new-api release candidate, then run live `GET`/`HEAD` route, cache, and boundary checks against that staging instance.

This replaces the earlier assumption that an external staging/production target already existed. The immediate goal is not production deployment; it is to create a safe local staging surface that proves the embedded `/creative/` artifact and new-api routing behave correctly before any real provider/payment/CDN/S3 environment is touched.

## Background / Confirmed Facts

- The user confirmed there is no existing deployed staging/production environment for this check; staging must be created by this task.
- Tier A static/offline release readiness completed and is archived at:
  - `.trellis/tasks/archive/2026-06/06-13-release-env-readiness-checks/check.md`
- Remote-backed RC verification completed and is archived at:
  - `.trellis/tasks/archive/2026-06/06-13-remote-backed-newapi-opentu-rc-verification/check.md`
- Candidate baseline from previous tasks:
  - OpenTU candidate: `39e0fe23180ffcfc98a767043869c4a90171356d`
  - new-api candidate: `c9f318c4210fc47b7454750b610945df5f0ddec4`
  - latest pushed `new2fly` docs/spec record: `af00982fb12a5fd5a7e0c7365b45a137442d5392`
- Docker is available locally, but the recommended first staging target is a short-lived sanitized `env -i go run` new-api process with temporary SQLite, because it avoids inheriting host secrets and avoids publish/deploy/image mutation.
- Previous embedded smoke already proved this style is feasible; this task makes it a release-like staging run with route/header evidence and independent check review.

## Requirements

1. Create a local/intranet staging instance for `new-api` using the current embedded OpenTU artifact.
2. Do not read, print, copy, or persist secret values.
3. Do not call provider, payment, CDN, production S3, production domains, or publish/deploy endpoints.
4. Do not run NPM/Docker publish, deploy upload, SSH, rsync-to-remote, or production configuration commands.
5. Prefer sanitized local staging:
   - start `new-api` from `/mnt/f/code/project/new-api`,
   - use `env -i` with only minimal non-secret runtime/build variables,
   - use temporary SQLite,
   - set `GIN_MODE=release`,
   - disable known background upstream update jobs where supported,
   - bind to an unused local port.
6. Run the no-secrets release artifact gate before/with staging checks.
7. Run browser embedded smoke against the local staging `/creative/` URL.
8. Run live local `GET`/`HEAD` route/header checks only; record selected headers and status, not response bodies.
9. Use dynamic workflow for at least one independent read-only review/check branch over redacted observations.
10. Record production-only work as `not-run` runbook items unless separately authorized later.

## Staging Check Set

Target base URL: local staging, expected `http://localhost:<port>`.

Paths to check with `GET` and/or `HEAD`:

- `/creative/`
- `/creative/sw.js`
- `/creative/version.json`
- existing hashed JS asset from the verified artifact
- existing hashed CSS asset from the verified artifact
- `/creative/assets/__missing_release_check__.js`
- `/creative/api/bootstrap`
- `/creative/api/missing`
- `/creative/relay/v1/chat/completions`

Expected high-level behavior:

- `/creative/`, `sw.js`, `version.json`, and existing assets are served by the local staging host.
- Existing static assets have appropriate static content types and cache behavior.
- Missing `/creative/assets/*` returns a static miss, not the SPA app shell.
- `/creative/api/*` and `/creative/relay/v1/*` do not return the SPA app shell and carry no-store/no-cache-like headers.
- Creative API/relay paths do not redirect to an external frontend host.

## Out of Scope Unless Separately Confirmed

- Production deployment or public-domain routing.
- Provider generation, payment creation/refund/webhook delivery, channel tests that spend quota, or storage mutations.
- Production S3 health checks or object probes.
- CDN/DNS live checks.
- Reading production shell/container env values.
- NPM/Docker image publication or deployment scripts.
- Deciding the final production sourcemap policy beyond reporting current artifact state.

## Acceptance Criteria

- [ ] Planning artifacts reflect local/intranet staging rather than a pre-existing live target.
- [ ] `implement.jsonl` and `check.jsonl` are curated with relevant specs and prior reports.
- [ ] The task is started through Trellis before execution.
- [ ] Release gate runs without inheriting host secrets.
- [ ] A temporary local staging `new-api` process starts successfully with temporary SQLite and sanitized env.
- [ ] Embedded browser smoke passes against local staging `/creative/` or the failure is captured with evidence.
- [ ] Route/header checks run against local staging and record only redacted status/header observations.
- [ ] Dynamic-workflow sidecar reviews the redacted observations or the reason it could not run is recorded.
- [ ] `check.md` summarizes pass/warn/fail/not-run per surface and lists production-only remaining runbook items.
- [ ] No tracked source changes outside Trellis/spec/reporting are introduced unless separately approved.
