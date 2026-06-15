# Check — Creative Embedded Production Deploy

Date: 2026-06-15  
Scope: VPS-A production Phase 1 deployment of embedded Creative `/creative/` route/UI. Creative 云同步 and video relay remain disabled.

## Outcome

Deployment completed successfully.

- Production container now runs `new-api-creative-embed:bfef310-prod`.
- Candidate image ID used locally, loaded remotely, and running in production:
  - `sha256:66efd68874c200ac438a92d1d327db1379a749236863213efdb8f0d1c4303e88`
- Existing public baseline still passes:
  - `https://api.se7endot.top/v1/models -> 401 application/json`
  - `https://console.se7endot.top/login -> 200 text/html`
- Creative route/header assertion passes on `https://console.se7endot.top`.
- Embedded browser smoke passes.
- Live DB critical table row counts did not decrease versus pre-deploy backup snapshot.
- Effective Creative Phase 1 env in the running container:
  - `CREATIVE_ASSET_SYNC_ENABLED=false`
  - `CREATIVE_VIDEO_RELAY_ENABLED=false`

No production `.env` values, admin password, cookies, CSRF/nonce, provider keys, S3 keys, payment credentials, or GitHub tokens were printed or committed.

## Local pre-deploy gates

### Repository/ref state

- `new2fly master`: `8b8b0e2283c4a64ee65595b11ebd701d8ba68b01`
- `new-api feat/creative-embed`: `bfef3101603837088f011112101038bbcde01b14`
- `opentu feat/creative-embed`: `bc938728754f7acbfbe8043a717c823bcedcacf0`
- Remote refs matched expected commits for `WindC0X/opentu` and `WindC0X/new-api`.

### Release gate

Command:

```bash
python3 scripts/creative_release_gate.py check --source-diff-check --run-new-api-tests
```

Result: passed.

Evidence highlights:

- Creative embedded artifact contract holds.
- `opentu`, `new-api/web/creative/dist`, and `new-api/router/web/creative/dist` matched: 174 files.
- No generated sourcemaps found.
- `git diff --check` gates passed for `new2fly`, `opentu`, and `new-api` source scopes.
- `new-api` Go tests passed for root/router/middleware/controller/model/service/relay packages.
- `go build ./...` passed.

### Candidate image build

Command shape:

```bash
cd /mnt/f/code/project/new-api
docker build --pull=false --progress=plain -t new-api-creative-embed:bfef310-prod .
```

Result: passed.

Local image identity:

```text
candidate_image_id=sha256:66efd68874c200ac438a92d1d327db1379a749236863213efdb8f0d1c4303e88
size=207090228
```

## VPS-A pre-cutover baseline

Sanitized target facts before cutover:

```text
host=iZ5ts1b7e631cus6rzvbt3Z
app_dir=/home/admin/apps/new-api
compose_services=new-api
current_container=new-api-relay
current_image=calciumion/new-api:v0.13.2 sha256:98361b3114f043f94ffd5affc457ee8d64923a0cc53e2824f2e727017ac098f1
root_disk=/dev/vda3 40G total, 29G used, 8.7G available, 77% used
```

Pre-cutover public baseline:

```text
api_models=401 content_type=application/json; charset=utf-8
console_login=200 content_type=text/html; charset=utf-8
```

Pre-cutover Creative assert was expected to fail because production had not yet been deployed:

- `/creative/sw.js`, `/creative/version.json`, `/creative/api/bootstrap`, and relay paths returned console HTML fallback behavior.
- No real `/creative/assets/*` reference could be discovered.

## Image transfer/load

Transfer method: local `docker save | gzip` streamed over SSH to remote `docker load`; no registry/GitHub credential was copied to VPS-A.

Remote loaded image identity:

```text
remote_candidate_image_id=sha256:66efd68874c200ac438a92d1d327db1379a749236863213efdb8f0d1c4303e88
size=207083680
repo_tag=new-api-creative-embed:bfef310-prod
```

Local/remote image IDs match.

## Maintenance, backup, and DB-copy rehearsal

Maintenance script stopped the existing service, created backups, rehearsed against a DB copy, applied Phase 1 env, switched compose image, and started the candidate.

Sanitized evidence:

```text
remote_image_identity=match
maintenance=service_stopped
backup_dir=/home/admin/apps/new-api/backups/creative-embed-20260615-171239
rehearsal_dir=/home/admin/apps/new-api/backups/creative-migration-rehearsal-20260615-171239
db_backup_integrity=ok
row_counts_pre=written
rehearsal_db_integrity=ok
rehearsal_status=ready
row_counts_rehearsal=written
phase1_env=apply
compose_image=apply
compose_up=done
candidate_container_image=new-api-creative-embed:bfef310-prod sha256:66efd68874c200ac438a92d1d327db1379a749236863213efdb8f0d1c4303e88
```

Notes:

- `.env` backup stayed on VPS-A and was not printed.
- SQLite backup used `.backup`; integrity check returned `ok`.
- Rehearsal container used copied DB, minimal env, generated temporary secrets, and localhost-only `127.0.0.1:13984` binding.
- A transient `curl: (56) Recv failure: Connection reset by peer` occurred during readiness polling before `/api/status` became ready; the rehearsal ultimately passed.

## Post-deploy checks

### Existing service baseline

```text
api_models=401 content_type=application/json; charset=utf-8
console_login=200 content_type=text/html; charset=utf-8
```

Result: passed.

### Creative route/header assertion

Command:

```bash
ops/newapi-opentu-production/creative-route-check.sh --assert \
  https://console.se7endot.top \
  https://api.se7endot.top
```

Result: passed.

Sanitized route table:

```text
creative-app-shell          GET 200 text/html; charset=utf-8        no-cache                         nosniff
creative-service-worker     GET 200 text/javascript; charset=utf-8  no-cache                         nosniff
creative-version-json       GET 200 application/json                no-cache                         nosniff
creative-existing-asset     GET 200 text/javascript; charset=utf-8  public, max-age=31536000, immutable nosniff
creative-missing-asset      GET 404 text/plain; charset=utf-8       no-cache                         nosniff
creative-bootstrap-unauth   GET 401 application/json; charset=utf-8 private, no-store
creative-relay-wrong-method GET 404 application/json; charset=utf-8 private, no-store                nosniff
existing-api-models-unauth  GET 401 application/json; charset=utf-8
existing-console-login      GET 200 text/html; charset=utf-8        no-cache
```

### Embedded browser smoke

Command:

```bash
python3 scripts/creative_release_gate.py check \
  --embedded-smoke-url https://console.se7endot.top/creative/
```

Result: passed.

Playwright result:

```text
1 passed — @creative-embedded new-api /creative/ smoke › serves app shell and keeps API/relay paths out of SPA fallback
```

The command also rechecked the embedded artifact contract and completed with:

```text
[done] no-secrets Creative release gate completed
```

### Live DB and env post-check

Remote post-check result:

```text
live_row_count_decrease=none
effective_creative_env=CREATIVE_VIDEO_RELAY_ENABLED=false,CREATIVE_ASSET_SYNC_ENABLED=false
running_image=new-api-creative-embed:bfef310-prod sha256:66efd68874c200ac438a92d1d327db1379a749236863213efdb8f0d1c4303e88
container_status=Up
```

## Not run

Authenticated Creative 云同步 smoke was not run in this task because the safe helper requires an interactive credential flow and this session should not place the admin password into tool command/stdin logs. Phase 1 disabled-state was instead verified by effective container env and route/API boundaries. Full authenticated document/asset cloud-sync smoke remains for a separately authorized Phase 2 with S3-compatible storage.

## Rollback status

Rollback was not needed.

Rollback remains available using:

- backup dir: `/home/admin/apps/new-api/backups/creative-embed-20260615-171239`
- previous image/ref: `calciumion/new-api:v0.13.2`
- backed-up compose: `$backup_dir/docker-compose.yml.pre-creative`
- backed-up env: `$backup_dir/.env.pre-creative`
- backed-up SQLite DB: `$backup_dir/new-api.db.pre-creative.bak`

Emergency rollback should restore previous compose/image and restart while keeping the live DB as-is unless a later audited DB rollback-forward plan is written.

## Spec update judgment

No additional `.trellis/spec/` update was needed in this deployment task. The durable lessons exercised here were already captured before deployment in `.trellis/spec/frontend/creative-embedded-release-artifact.md`:

- preserve production `.env`/data/log mounts;
- run SQLite DB-copy rehearsal before live cutover;
- map container `/data/...` SQLite paths to host data mount;
- keep rehearsal localhost-only with minimal env;
- avoid passing authenticated smoke secrets in subprocess argv/logs;
- verify image identity by image ID/digest.

This task applied those rules and recorded evidence; it did not introduce a new reusable convention.
