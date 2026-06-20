# Design — Creative pinned candidate push deploy smoke

## Scope and Repositories

This task spans three repositories:

- `opentu` — source commit used to build embedded Creative dist.
- `new-api` — backend plus embedded dist candidate.
- `new2fly` — Trellis task records, release runbook, ops smoke scripts, release gate.

## Design Principles

1. **Remote refs before deployment.** Production deployment must use commits that can be fetched again from GitHub, not local-only worktrees.
2. **No secret migration into WSL.** If credentials are host-only, push/verify through host Git rather than copying tokens.
3. **Data-preserving rollout.** Production DB, env, channels, users, tokens, quota, and logs are preserved; rollback is image/compose rollback, not destructive schema rollback.
4. **Staging before VPS.** A pushed candidate must pass staging/candidate validation before any VPS/production preflight or mutation.
5. **Phase boundaries stay explicit.** Phase 1 route/UI deployment is separate from cloud-sync enablement and live provider smoke.
6. **Evidence labels matter.** Local gate, remote ref verification, staging validation, read-only production preflight, deployment rehearsal, production route smoke, cloud-sync smoke, and provider smoke are separate evidence categories.

## Technical Design

### 1. Push/ref verification

- Confirm local HEADs and clean worktrees before push:
  - `git status --short`
  - `git rev-parse HEAD`
- Push expected branches:
  - `opentu feat/creative-embed`
  - `new-api feat/creative-embed`
  - `new2fly master`
- Verify remote refs with `git ls-remote` using the same remote URLs expected by the runbook.
- If WSL credential helpers fail, run host-side Git/PowerShell commands; capture only commit hashes/status, not credentials.

### 2. Gate preservation

- Re-run new-api CI gate after any dist/provenance changes.
- Re-run new2fly release gate with explicit `--new-api /mnt/f/CODE/Project/new-api --opentu /mnt/f/code/project/opentu` paths to avoid wrong sibling checkout.
- Keep embedded dist identity: `opentu/dist/apps/web`, `new-api/web/creative/dist`, and `new-api/router/web/creative/dist` byte-identical.

### 3. Staging validation

- Run staging from the pushed candidate before touching VPS/production.
- Preferred order:
  1. local disposable candidate/container staging from pinned commits;
  2. existing staging service if one is available and safe to update;
  3. only then VPS/production read-only preflight.
- Staging checks cover `/creative/`, static assets, `/creative/api/bootstrap`, `/creative/api/models`, login/session behavior where available, model catalog/parameter UI, and route/API boundary behavior.
- Staging must keep `CREATIVE_ASSET_SYNC_ENABLED=false` unless explicitly testing cloud sync with isolated non-production storage.

### 4. VPS/production preflight

- Read production target metadata from the existing runbook and prior docs only after staging passes.
- Run read-only checks only until explicit production mutation authorization is given.
- Validate:
  - SSH reachability and app dir;
  - current compose shape and image;
  - current env presence without printing secrets;
  - backup/rehearsal strategy;
  - public baseline for `/v1/models`, `/login`, `/creative/*` routes if safe/read-only.

### 5. Deployment execution boundary

Production mutation includes any of:

- building/transferring/loading candidate image on production host;
- stopping or restarting production container;
- editing production compose/env;
- running DB-copy rehearsal that stops writes or manipulates production app state;
- authenticated smoke using admin/browser credentials.

These require an explicit confirmation at the deployment step.

### 6. Smoke taxonomy

- **Route smoke:** unauthenticated/public GET/HEAD route boundary checks; redacted headers only.
- **Authenticated Creative smoke:** browser/session based, no API-token-only bypass; redacted IDs/statuses only.
- **Cloud-sync smoke:** only if S3-compatible production config is explicitly enabled.
- **Provider smoke:** only if live provider credentials and model/channel config are explicitly authorized; not part of this task by default.

## Compatibility and Rollback

- Push is reversible through normal Git branch management but should not rewrite history without explicit instruction.
- Production rollback is image/compose rollback using the pre-deploy backup and previously running image.
- Do not delete Creative tables/columns as rollback.
- Keep `CREATIVE_ASSET_SYNC_ENABLED=false` in Phase 1 unless a separate cloud-sync rollout is authorized.
