# Design — Creative Embedded Push And Deployment Verification

## 1. Scope

This task is release orchestration, not feature development. It coordinates three repositories:

- `opentu`: source embedded Creative frontend branch `feat/creative-embed`.
- `new-api`: backend/admin/default frontend plus embedded Creative dist branch `feat/creative-embed`.
- `new2fly`: Trellis, ops runbook, release gates, local staging records on `master`.

## 2. Branch and remote design

### Recommended refs

- OpenTU embedded integration:
  - local: `/mnt/f/code/project/opentu`, branch `feat/creative-embed`, commit `bc938728`
  - push: `fork feat/creative-embed`
  - reason: avoids overwriting the existing platformization fork branch/work.
- new-api integration:
  - local: `/mnt/f/code/project/new-api`, branch `feat/creative-embed`, commit `bfef310`
  - push: `fork feat/creative-embed`
- new2fly orchestration:
  - local: `/mnt/f/code/project/new2fly`, branch `master`, latest `525b5b3`
  - push: `origin master` unless user wants a separate release branch.

### Credential boundary

GitHub credentials are on the host. Preferred push path is host-side commands from the same working trees or host clones. Codex must not ask for or print GitHub tokens. If WSL can use host Git credential manager, verify by `git ls-remote`/`git push --dry-run` first; otherwise provide commands for the host terminal.

## 3. Deployment design

### Local staging

Current local staging remains the baseline verification target:

- image: `new-api-creative-embed:staging-current`
- compose: `ops/newapi-opentu-staging/docker-compose.yml`
- default URL: `http://127.0.0.1:39084/creative/`
- env: ignored `.env.staging.local`

Local staging may use `CREATIVE_ASSET_ROLLOUT_MODE=local` and `CREATIVE_ASSET_STORAGE=database` for smoke verification only.

### Production-like deployment

A real deployment must explicitly choose one of:

1. Docker image built from verified `new-api` commit.
2. Direct checkout/server build from verified `new-api` commit.
3. External CI/CD using verified refs.

Production must not inherit local `.env.staging.local` blindly. It needs a separate env source with production-grade storage settings.

## 4. Cloud-sync env contract

### Local/staging database backend

Allowed for local verification:

```env
CREATIVE_ASSET_SYNC_ENABLED=true
CREATIVE_ASSET_ROLLOUT_MODE=local
CREATIVE_ASSET_STORAGE=database
```

### Production S3-compatible backend

Required for production cloud-sync assets:

```env
CREATIVE_ASSET_SYNC_ENABLED=true
CREATIVE_ASSET_ROLLOUT_MODE=production
CREATIVE_ASSET_STORAGE=s3-compatible
CREATIVE_ASSET_S3_ENDPOINT=<private object storage endpoint>
CREATIVE_ASSET_S3_REGION=<region or auto>
CREATIVE_ASSET_S3_BUCKET=<private bucket>
CREATIVE_ASSET_S3_PREFIX=creative-assets
CREATIVE_ASSET_S3_ACCESS_KEY_ID=<secret>
CREATIVE_ASSET_S3_SECRET_ACCESS_KEY=<secret>
CREATIVE_ASSET_S3_FORCE_PATH_STYLE=<true|false>
CREATIVE_ASSET_USER_MAX_BYTES=<quota>
CREATIVE_ASSET_USER_MAX_ASSETS=<quota>
SESSION_SECRET=<stable shared secret>
```

If S3-compatible storage is not ready, production should fail closed by leaving `CREATIVE_ASSET_SYNC_ENABLED=false` or not deploying cloud-sync assets yet.

## 5. Verification design

### Read-only route/header matrix

Use read-only requests to prove route boundaries without provider/payment traffic:

- `/creative/` returns HTML app shell.
- `/creative/sw.js` returns JS/service worker content.
- `/creative/version.json` returns JSON/metadata.
- existing `/creative/assets/*` returns static asset, not HTML fallback.
- missing `/creative/assets/*` returns static miss, not Creative SPA shell.
- `/creative/api/bootstrap` is API boundary with private no-store; unauthenticated target should return 401.
- `/creative/relay/v1/chat/completions` GET/wrong method remains non-SPA no-store boundary.

### Browser smoke

Run existing embedded smoke through:

```bash
python3 scripts/creative_release_gate.py check --embedded-smoke-url <base>/creative/
```

### Authenticated cloud-sync smoke

Use `/tmp/creative-cloud-sync-smoke.cjs` or promote it into a tracked script if this becomes recurring. It exercises:

- login;
- bootstrap `assetSyncEnabled` and CSRF/nonce;
- document create/list/get/update/delete;
- bad nonce rejection;
- asset upload/range content/delete;
- no storage/provider field leakage in asset upload response.

Do not print passwords or tokens.

## 6. Rollback design

- Code rollback: redeploy previous new-api image/ref; keep previous pushed refs available.
- Cloud-sync disable: set `CREATIVE_ASSET_SYNC_ENABLED=false` and restart if storage health is questionable.
- Storage rollback: do not delete S3 objects during rollback; keep private bucket and app metadata intact for investigation.
- Local staging rollback: `docker compose ... down` or rebuild previous `new-api-creative-embed:staging-current` tag from previous commit.

## 7. Risks

- OpenTU fork branch conflict with platformization work if pushed to the wrong branch.
- Production accidentally using database asset backend if local env is copied.
- Deployment target may not yet exist or may be unreachable from WSL.
- Browser/auth smoke requires admin credentials; must be supplied without logging secrets.
- Docker image registry publishing may require host credentials and is out of scope unless separately approved.
