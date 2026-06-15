# Design — Creative Embedded Production Deploy

## Scope

This task executes Phase 1 production deployment of embedded Creative on VPS-A. It follows the previously committed production runbook and deliberately keeps Creative 云同步 disabled.

## Deployment strategy

Use a slow-safe maintenance-window cutover:

1. Verify local candidate and image artifact identity.
2. Transfer candidate image to VPS-A without registry/GitHub credentials if practical.
3. Stop current production writes.
4. Create consistent backups on VPS-A.
5. Rehearse candidate startup against a copied DB with localhost-only binding and minimal env.
6. If rehearsal passes, update production compose to candidate image while preserving service shape and existing `.env`/data/log mounts.
7. Restart production and run post-deploy checks.
8. Roll back to previous compose/image if existing service baseline fails.

## Recommended image transfer path

Recommended: local build + `docker save`/`scp`/`docker load`.

Why:

- avoids copying GitHub credentials to VPS-A;
- avoids relying on WSL GitHub credentials;
- avoids registry setup or registry credentials;
- keeps candidate identity verifiable by local and remote image IDs.

Trade-off:

- transferring a compressed Docker image can take time and VPS disk space;
- must check free disk before transfer/load and remove temporary tar after successful load.

Fallbacks:

- registry push/pull only if credentials are already safely configured outside logs;
- build on VPS-A only if repo access and build dependencies are acceptable and ref/artifact gates are rerun there.

## Data preservation design

- The live DB is SQLite behind the container mount `./data:/data`.
- Host-side scripts must map `SQLITE_PATH=/data/...` to `/home/admin/apps/new-api/data/...`.
- Unknown absolute SQLite paths fail closed until manually verified on VPS-A.
- Use SQLite `.backup`, not hot `cp`, for consistent DB backup/copy.
- Rehearsal uses a copied DB and a minimal env; it must not copy full production `.env` into the candidate container.
- Rehearsal binds to `127.0.0.1` only.

## Env contract

Preserve existing production `.env` and append/update only reviewed Creative Phase 1 keys:

```env
CREATIVE_ASSET_SYNC_ENABLED=false
CREATIVE_VIDEO_RELAY_ENABLED=false
```

Do not overwrite `SESSION_SECRET`, `SQLITE_PATH`, `SQL_DSN`, provider keys, payment settings, channel settings, or user/admin settings.

## Verification design

### Pre-cutover

- Git/ref and release gate checks on local candidate.
- Docker image ID recorded.
- VPS disk/free baseline recorded.
- Public current baseline recorded.

### Rehearsal

- Candidate starts on copied DB.
- `/api/status` responds on localhost-only rehearsal port.
- Critical table row counts remain present.
- Creative tables may be added.

### Post-cutover

- Existing public baseline:
  - `/v1/models -> 401 JSON`
  - `/login -> 200 HTML`
- Creative route/header `--assert` passes.
- Embedded browser smoke passes if runnable.
- Phase 1 authenticated cloud-sync smoke is optional unless credentials are authorized; expected state is disabled.

## Rollback design

Rollback restores previous compose/image and restarts service while keeping live DB as-is.

Do not attempt destructive schema rollback during incident response. Additive Creative tables/columns can remain until a later audited cleanup if needed.

## Risk controls

- Maintenance window is allowed, so prefer stopping writes before backup.
- Do not print `.env` or secret values.
- Do not run provider/payment/quota operations.
- Do not proceed from rehearsal to cutover if backup/rehearsal row-count gates fail.
