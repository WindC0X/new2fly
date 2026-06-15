# Implementation Plan — Creative Embedded Production Deploy

## Phase 1 — Planning

- [x] Create Trellis task.
- [x] Define Phase 1 deployment scope: route/UI only, Creative 云同步 disabled.
- [x] Identify production runbook and helper scripts to follow.
- [x] Record data-preservation and rollback requirements.
- [x] User review/authorization for dangerous production write actions.
- [x] Run `task.py start` only after authorization.

## Phase 2 — Pre-deploy local gates

1. Verify working tree clean.
2. Verify live refs:
   - OpenTU `feat/creative-embed` expected `bc938728754f7acbfbe8043a717c823bcedcacf0`.
   - new-api `feat/creative-embed` expected `bfef3101603837088f011112101038bbcde01b14`.
3. Verify local candidate checkout state under `/mnt/f/code/project/new-api`.
4. Run release gate from `new2fly`:
   - `python3 scripts/creative_release_gate.py check --source-diff-check --run-new-api-tests`
5. Build candidate Docker image from `/mnt/f/code/project/new-api`.
6. Record image ID.
7. Save/compress image for transfer or otherwise verify selected transfer path.

## Phase 3 — VPS-A pre-cutover and backup

1. SSH read-only baseline:
   - `docker compose ps`
   - disk/free space
   - current image/compose summary
   - public `/v1/models` and `/login` baseline
2. Transfer/load candidate image and verify remote image ID.
3. Start maintenance window:
   - stop current service writes with `docker compose stop new-api` or matching service name.
4. Create backup directory with `umask 077`.
5. Backup `docker-compose.yml` and `.env` on VPS only.
6. Resolve live SQLite path with `/data/*` host mapping.
7. Create SQLite `.backup` and run `PRAGMA integrity_check`.
8. Capture strict row-count snapshot from backup artifact.

## Phase 4 — DB-copy rehearsal

1. Create copied DB via SQLite `.backup` into rehearsal dir.
2. Start candidate container with:
   - copied DB only;
   - minimal whitelist env;
   - generated temporary secrets;
   - `CREATIVE_ASSET_SYNC_ENABLED=false`;
   - `127.0.0.1:13984:13984` only.
3. Wait for `/api/status`.
4. Re-run critical row-count snapshot on copied DB.
5. If any gate fails, restart old service and stop deployment.

## Phase 5 — Production cutover

1. Preserve current compose shape and mounts.
2. Update image to candidate image.
3. Ensure Phase 1 env keys are present/effective:
   - `CREATIVE_ASSET_SYNC_ENABLED=false`
   - `CREATIVE_VIDEO_RELAY_ENABLED=false`
4. `docker compose up -d`.
5. Check logs briefly for startup failure without copying sensitive bodies.

## Phase 6 — Post-deploy checks

1. Existing baseline:
   - `https://api.se7endot.top/v1/models -> 401`
   - `https://console.se7endot.top/login -> 200`
2. Creative route/header assertion:
   - `ops/newapi-opentu-production/creative-route-check.sh --assert https://console.se7endot.top https://api.se7endot.top`
3. Embedded browser smoke:
   - `python3 scripts/creative_release_gate.py check --embedded-smoke-url https://console.se7endot.top/creative/`
4. Optional authenticated Phase 1 disabled-state smoke if credentials are authorized:
   - `ops/newapi-opentu-production/creative-cloud-sync-smoke.sh --phase disabled https://console.se7endot.top`
5. Record sanitized evidence in `check.md`.

## Phase 7 — Rollback if needed

Rollback immediately if existing baseline fails or Creative route assertion shows route ownership regression:

1. Restore backed-up compose or previous image `calciumion/new-api:v0.13.2` as recorded.
2. Keep `.env`, `data`, and `logs` unchanged.
3. `docker compose up -d`.
4. Re-run existing baseline.
5. Record sanitized rollback evidence.

## Validation commands

- `python3 ./.trellis/scripts/task.py validate 06-15-creative-embedded-production-deploy`
- Release gate before image build.
- `bash -n` production helper scripts if edited.
- Route checker `--assert` after deployment.

## Rollback points

- Before maintenance: no production mutation.
- After image transfer/load: remove temporary tar/images if not deployed.
- After service stop but before cutover: `docker compose up -d` with old compose.
- After cutover: restore previous image/compose and restart.

## Notes

- `.codex-flow/` dynamic workflow artifacts remain local/ignored unless explicitly needed for evidence.
- Do not commit or print production `.env`, passwords, cookies, CSRF, nonce, provider keys, S3 keys, or GitHub tokens.

## Execution progress

- [x] Started task after user authorized production write operation.
- [x] Verified local refs and release gate.
- [x] Built candidate Docker image and recorded image ID.
- [x] Stream-loaded candidate image to VPS-A and verified remote image ID matches.
- [x] Stopped production service during maintenance window and created compose/.env/SQLite backups.
- [x] Ran DB-copy migration rehearsal with copied DB and localhost-only candidate container.
- [x] Applied Phase 1 env keys and updated production compose to candidate image.
- [x] Restarted production service on candidate image.
- [x] Verified existing public baseline, Creative route/header assertion, embedded browser smoke, live DB row-count non-decrease, and effective Phase 1 env.
- [x] Recorded sanitized deployment evidence in check.md.
