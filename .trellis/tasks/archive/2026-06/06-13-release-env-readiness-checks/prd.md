# Release Environment Readiness Checks

## Goal

Plan and execute the post-RC checks that were intentionally left out of the no-secrets local verification for the OpenTU embedded-in-new-api release candidate.

The objective is to determine whether the release candidate is operationally ready for a real release environment, without accidentally reading/printing secrets or calling mutable/provider/payment/production endpoints without explicit authorization.

## Background / Confirmed Facts

- The no-secrets local RC verification task passed and is archived at:
  - `.trellis/tasks/archive/2026-06/06-13-remote-backed-newapi-opentu-rc-verification/check.md`
- Verified candidate commits from that task:
  - OpenTU: `WindC0X/opentu:newapi-embed-release-gate` at `39e0fe23180ffcfc98a767043869c4a90171356d`
  - new-api: `WindC0X/new-api:feat/creative-embed` at `c9f318c4210fc47b7454750b610945df5f0ddec4`
  - new2fly executable gate revision: `e40508f1d13f6356bfb0f5dd2c8b30d4456f829d`
- The previous task already passed:
  - artifact identity/source/new-api Go tests/build gate
  - OpenTU typecheck
  - OpenTU cold smoke with `NX_SKIP_NX_CACHE=true`
  - embedded `/creative/` smoke against sanitized local SQLite `new-api`
- Remaining checks were explicitly scoped as release-environment-only:
  - production/staging secrets injection
  - provider/payment/channel health
  - S3/object storage and CDN/domain configuration
  - NPM/Docker publish credentials and release path
  - production sourcemap policy
  - long-running scheduler behavior
- Relevant repo evidence found:
  - `new-api/.env.example` documents Creative env keys including `CREATIVE_ASSET_STORAGE`, S3 endpoint/region/bucket/prefix/access/secret keys, rollout mode, quota keys, video relay enablement, `TRUSTED_REDIRECT_DOMAINS`, Redis/DB/session keys, and scheduler flags.
  - `new-api/Dockerfile` embeds prebuilt `web/creative/dist` and does not build OpenTU inside the Dockerfile.
  - `new-api/.github/workflows/docker-build.yml` publishes tagged multi-arch Docker images to Docker Hub using `DOCKERHUB_USERNAME` and `DOCKERHUB_TOKEN`.
  - `new-api/.github/workflows/docker-image-alpha.yml` publishes alpha images to Docker Hub and GHCR.
  - `opentu/package.json` contains hybrid/npm/deploy scripts, including `release`, `release:dry`, `npm:publish`, and `e2e:creative-embedded`.
  - `opentu/scripts/deploy-hybrid.js` excludes `.map` files from CDN upload in the hybrid release path, while the embedded new-api artifact gate currently allows `sw.js.map` unless `--sourcemap-policy forbid` is used.

## Requirements

1. Keep the current session secret-safe by default:
   - Do not read, print, copy, or persist secret values.
   - Do not call provider/payment/CDN/production endpoints unless the user explicitly confirms the target environment and allowed operations.
2. Produce an actionable release-environment readiness report that separates:
   - locally verifiable/static evidence,
   - safe presence-only checks,
   - live read-only checks requiring explicit authorization,
   - release-environment-only manual checks that cannot be run from this workspace.
3. Cover the operational surfaces left open by the RC verification:
   - S3/object storage for Creative assets,
   - CDN/domain/reverse-proxy routing for `/creative/`, `/creative/assets/*`, `/creative/api/*`, `/creative/relay/v1/*`, and service worker scope,
   - provider/payment/channel health and fail-closed behavior,
   - production/staging secret injection and environment defaults,
   - NPM/Docker publish credentials and artifact provenance,
   - sourcemap policy and generated artifact policy,
   - background scheduler behavior and external-update tasks.
4. Use dynamic-workflow sidecar review for at least part of the check phase, because the user requested dynamic workflow participation in verification/checking work.
5. Persist findings under this Trellis task, and update specs if a reusable release-readiness rule is learned.

## Non-goals / Out of Scope Unless Explicitly Approved

- Reading or displaying secret values.
- Mutating production data, uploading release artifacts, publishing NPM/Docker packages, changing DNS/CDN settings, or triggering provider/payment state changes.
- Executing remote deployment scripts that use SSH/rsync/scp or auto-deploy paths.
- Running destructive VCS or cleanup commands.

## Acceptance Criteria

- [ ] Planning artifacts (`prd.md`, `design.md`, `implement.md`) define safe vs live check boundaries.
- [ ] Static/offline release-readiness checks are executed and recorded.
- [ ] Dynamic-workflow sidecar check is executed for independent review or the reason it could not run is documented.
- [ ] Any live endpoint/secret-presence checks are run only after explicit user confirmation and only with redacted outputs.
- [ ] A final `check.md` lists pass/warn/fail status for each operational surface.
- [ ] Remaining manual release-environment checks are clearly listed with exact commands/runbook shape.
- [ ] No tracked source changes outside Trellis/spec/reporting are introduced unless separately approved.

## Open Question Blocking Execution Scope

Which release environment and authority level should this task use?

Recommended: start with static/offline + redacted presence-only checks in this workspace, and prepare a manual/live runbook; run live staging/production endpoint checks only after the user provides the target base URL/environment and explicitly confirms allowed read-only calls.
