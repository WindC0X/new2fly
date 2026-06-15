# Creative Embedded Push And Deployment Verification

## Goal

Publish the completed embedded Creative integration refs safely across the three related repositories, then verify the selected target serves the new-api embedded `/creative/` surface with **云同步** enabled for logged-in users. For this run, the selected target is local staging only; real private/public deployment remains blocked until a target environment and production S3-compatible asset storage are provided.

This task starts after local implementation and local staging verification were completed in the previous task:

- OpenTU commit: `bc938728 feat(creative): align embedded cloud sync and model metadata`
- new-api commit: `bfef310 feat(creative): harden embedded model policy and sync`
- new2fly orchestration/verification commit: `8a47658 chore(creative): record embedded cleanup verification`
- task/archive/journal commits in new2fly: `62391b6`, `525b5b3`

## User Value

The code is locally verified but not yet available from a shared remote or deployed target. The user needs a repeatable, low-risk path to:

1. push the correct branches without overwriting the existing platformization OpenTU fork work;
2. deploy or prepare deployment of the new-api embedded Creative artifact;
3. configure real cloud sync correctly rather than leaving local database-only staging settings in a production-like environment;
4. prove the target works with route/header checks and authenticated Creative cloud-sync smoke.

## Confirmed Facts

### Repository state

- `/mnt/f/code/project/new2fly`
  - branch: `master`
  - remote: `origin https://github.com/WindC0X/new2fly.git`
  - latest commit: `525b5b3 chore: record journal`
  - working tree clean after previous task.
- `/mnt/f/code/project/opentu`
  - branch: `feat/creative-embed`
  - remotes:
    - `fork https://github.com/WindC0X/opentu.git`
    - `origin https://github.com/ljquan/opentu.git`
  - latest commit: `bc938728 feat(creative): align embedded cloud sync and model metadata`
  - user previously stated the existing fork is also used for the platformization OpenTU route, so embedded work must be pushed as a separate branch/ref, not force-pushed over that work.
- `/mnt/f/code/project/new-api`
  - branch: `feat/creative-embed`
  - remotes:
    - `fork https://github.com/WindC0X/new-api.git`
    - `origin https://github.com/QuantumNous/new-api`
  - latest commit: `bfef310 feat(creative): harden embedded model policy and sync`
- GitHub credentials are on the host machine, not necessarily available inside WSL/Codex.

### Local staging state from previous task

- Local staging URL: `http://127.0.0.1:39084/creative/`.
- Local staging image: `new-api-creative-embed:staging-current`, image id `sha256:66efd68874c200ac438a92d1d327db1379a749236863213efdb8f0d1c4303e88`.
- Local staging env file is ignored by git: `ops/newapi-opentu-staging/.env.staging.local`.
- Local staging has Creative cloud sync enabled using database backend:
  - `CREATIVE_ASSET_SYNC_ENABLED=true`
  - `CREATIVE_ASSET_ROLLOUT_MODE=local`
  - `CREATIVE_ASSET_STORAGE=database`
- This local database backend is explicitly not production storage.
- Authenticated smoke already passed locally:
  - bootstrap `assetSyncEnabled=true`
  - document create/list/get/update/delete passed
  - bad nonce update rejected with 403
  - asset upload/range content/delete passed

### Production cloud-sync requirement

- Production must not use `CREATIVE_ASSET_STORAGE=database`.
- Production should use:
  - `CREATIVE_ASSET_SYNC_ENABLED=true`
  - `CREATIVE_ASSET_ROLLOUT_MODE=production`
  - `CREATIVE_ASSET_STORAGE=s3-compatible`
  - complete private S3-compatible object storage env keys.
- Browser should read assets via `/creative/api/assets/:id/content`; raw S3 URLs or signed object URLs must not be exposed.

## Requirements

### A. Push strategy

1. Produce host-side push commands for all three repositories that do not require exposing GitHub credentials in Codex logs.
2. Push OpenTU embedded work to a distinct branch, recommended:
   - remote: `fork`
   - branch: `feat/creative-embed`
3. Do not overwrite or force-push the user's existing platformization OpenTU branch unless explicitly approved.
4. Push new-api embedded work to:
   - remote: `fork`
   - branch: `feat/creative-embed`
5. Push new2fly orchestration/Trellis commits to:
   - remote: `origin`
   - branch: `master`, unless the user chooses a release branch.
6. After push, verify remote refs with `git ls-remote` or equivalent, recording exact commit hashes.

### B. Deployment / staging path

7. Keep local staging as a safe verification target with loopback binding by default.
8. Do not claim production readiness from local staging alone.
9. If deploying to a real host, define:
   - target base URL;
   - whether it uses Docker image, direct checkout, or another deployment runner;
   - env source and secret injection mechanism;
   - rollback command/ref.
10. Ensure the deployed new-api image/check-out contains the synced `web/creative/dist` and `router/web/creative/dist` artifacts from the verified new-api commit.

### C. Cloud-sync configuration

11. For local/staging verification, database storage is allowed only when labeled local/canary and not public production.
12. For production, require private S3-compatible storage configuration before enabling Creative asset cloud sync.
13. Do not print or commit S3 credentials, GitHub credentials, SESSION_SECRET, provider keys, payment credentials, or admin passwords.
14. Multi-instance deployments must use a stable shared `SESSION_SECRET`.

### D. Post-deploy verification

15. Run read-only route/header checks against the chosen target:
   - `/creative/`
   - `/creative/sw.js`
   - `/creative/version.json`
   - at least one existing `/creative/assets/*`
   - missing `/creative/assets/*`
   - `/creative/api/bootstrap`
   - `/creative/relay/v1/chat/completions` wrong method boundary
16. Run embedded Playwright smoke against the target when network/browser access is available.
17. Run authenticated cloud-sync smoke against the target only when explicitly authorized and credentials can be supplied without logging secrets.
18. Record whether each verification is local-only, staging, or production.

## Out Of Scope Unless Separately Confirmed

- Pushing to upstream origins (`ljquan/opentu` or `QuantumNous/new-api`) rather than user forks.
- Force-pushing any branch.
- Publishing Docker images to a registry.
- Creating or managing a real S3 bucket/provider account.
- Changing DNS/TLS/CDN.
- Running real provider generation, payment, or production quota-consuming requests.

## Acceptance Criteria

- [ ] Push commands are prepared and reviewed, with separate OpenTU embedded branch strategy that does not disturb platformization work.
- [ ] The chosen remote refs are pushed or a host-side push runbook is provided if WSL credentials are unavailable.
- [ ] Remote refs are verified against expected commits.
- [ ] Deployment target and mode are documented before deployment starts.
- [ ] Production cloud-sync env requirements are documented with placeholders only and no secret values.
- [ ] Local/staging and production storage modes are clearly separated.
- [ ] Route/header checks pass on the selected target or failures are recorded with exact risk.
- [ ] Embedded smoke passes on the selected target when applicable.
- [ ] Authenticated Creative cloud-sync smoke passes on the selected target when authorized.
- [ ] Rollback steps are documented for code ref and cloud-sync env toggles.

## Planning Decisions (2026-06-15)

- Deployment scope for this task follows the recommended low-risk route: first push and verify remote refs for all three repositories.
- No production/public deployment is attempted yet because a real target URL/host and production S3-compatible Creative asset storage are not defined in this session.
- Local staging remains the executable verification target; production deployment will be a separate step after target env, storage, and rollback ownership are confirmed.
- Codex may attempt WSL `git push --dry-run` / push only if credentials are already available without exposing secrets; otherwise it must provide host-side commands.

## Open Questions

1. Resolved for this task: keep deployment local-only after push; do not deploy to a real private/public target until that target is provided.
2. Resolved for this task: Codex may try non-secret WSL dry-run/push if credentials are already available; otherwise provide host-side commands.
3. Resolved for this task: production S3-compatible storage is not configured here, so production Creative cloud sync must remain disabled until storage is ready.
