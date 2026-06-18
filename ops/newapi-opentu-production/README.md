# New API Embedded Creative Production Runbook

This runbook prepares the `new-api` production deployment on VPS-A for the embedded Creative `/creative/` surface.

It is intentionally conservative: current `new-api` may be paused for a maintenance window, but existing user data, API keys, channels, model/pricing options, quotas, and logs must survive unchanged.

## 0. Current verified inputs

### Candidate refs

| Component | Remote/ref | Verified commit |
| --- | --- | --- |
| OpenTU embedded frontend | `WindC0X/opentu feat/creative-embed` | `bc938728754f7acbfbe8043a717c823bcedcacf0` |
| new-api backend + embedded dist | `WindC0X/new-api feat/creative-embed` | `bfef3101603837088f011112101038bbcde01b14` |
| new2fly ops/runbook | current repository | record the commit SHA after this runbook is committed |

Re-verify before deployment:

```bash
expect_ref() {
  local repo="$1" ref="$2" expected="$3" got
  got=$(git ls-remote "$repo" "$ref" | awk '{print $1}')
  test "$got" = "$expected" || {
    echo "ref mismatch for $repo $ref" >&2
    exit 1
  }
}

expect_ref https://github.com/WindC0X/opentu.git refs/heads/feat/creative-embed \
  bc938728754f7acbfbe8043a717c823bcedcacf0
expect_ref https://github.com/WindC0X/new-api.git refs/heads/feat/creative-embed \
  bfef3101603837088f011112101038bbcde01b14

cd /mnt/f/code/project/new-api
test "$(git rev-parse HEAD)" = bfef3101603837088f011112101038bbcde01b14
```

### VPS-A preflight baseline

Read-only preflight on 2026-06-15 found:

- SSH target: `admin@47.80.71.35`.
- Hostname: `iZ5ts1b7e631cus6rzvbt3Z`.
- App dir: `/home/admin/apps/new-api`.
- Current compose shape: `network_mode: host`, `container_name: new-api-relay`, `env_file: .env`, `./data:/data`, `./logs:/app/logs`.
- Current image: `calciumion/new-api:v0.13.2`.
- Selected env presence: `PORT=13000`, `SESSION_SECRET=<set>`, `SQLITE_PATH=<set>`, `TZ=Asia/Hong_Kong`; no selected `CREATIVE_*` keys were present.
- Public baseline: `https://api.se7endot.top/v1/models -> 401`, `https://console.se7endot.top/login -> 200`.
- Current `/creative/*` is not the embedded Creative contract yet: console domain falls back to HTML for SW/API/static miss paths, API domain returns 404.

## 1. Release strategy

### Recommended two-phase rollout

1. **Phase 1: route/UI cutover only**
   - Deploy the candidate image that embeds Creative routes and dist.
   - Keep `CREATIVE_ASSET_SYNC_ENABLED=false`.
   - Verify existing `new-api` baseline plus `/creative/*` static/API boundaries.
2. **Phase 2: enable Creative 云同步**
   - Only after private S3-compatible storage is configured and checked.
   - Set `CREATIVE_ASSET_SYNC_ENABLED=true`, `CREATIVE_ASSET_ROLLOUT_MODE=production`, `CREATIVE_ASSET_STORAGE=s3-compatible`.
   - Run authenticated cloud-sync smoke.

Do not use `CREATIVE_ASSET_STORAGE=database` in production.

## 2. What can affect existing users

- A real deployment replaces/restarts the `new-api-relay` container, so API/console can be unavailable during the maintenance window.
- The intended route change is additive under `/creative/*`.
- Existing `/v1/*`, `/api/*`, `/login`, `/dashboard`, and ordinary console routes should remain on existing routers, but this must be verified after restart.
- The candidate image can run DB AutoMigrate on startup. Treat this as additive migration risk: rehearse against a DB copy before touching the live DB.

## 3. Hard data-preservation rules

Do not run deployment commands that delete, reinitialize, replace, truncate, or download/print the production DB or `.env`.

Must preserve:

- `/home/admin/apps/new-api/data`
- `/home/admin/apps/new-api/logs`
- existing `.env`, especially `SESSION_SECRET` and `SQLITE_PATH`
- users, tokens/API keys, channels, abilities, options, pricing, quotas, logs

Rollback is image/compose rollback. Do not attempt destructive schema rollback just because Creative tables/columns were added.

## 4. Pre-deploy gates on the build machine

From `/mnt/f/code/project/new2fly`:

```bash
python3 scripts/creative_release_gate.py check --source-diff-check --run-new-api-tests
```

If rebuilding OpenTU artifacts:

```bash
cd /mnt/f/code/project/opentu
VITE_BASE_URL=/creative/ pnpm build:web

cd /mnt/f/code/project/new2fly
python3 scripts/creative_release_gate.py build-sync-check --run-new-api-tests
```

Before building/pushing an image, confirm these trees match byte-for-byte through the release gate:

- `/mnt/f/code/project/opentu/dist/apps/web`
- `/mnt/f/code/project/new-api/web/creative/dist`
- `/mnt/f/code/project/new-api/router/web/creative/dist`

## 5. Candidate image build

The upstream `new-api` Dockerfile does not build OpenTU. It copies the already-synced Creative dist from `web/creative/dist`.

Build a custom image from the verified `new-api` checkout. Example tag:

```bash
cd /mnt/f/code/project/new-api
docker build --pull=false --progress=plain \
  -t new-api-creative-embed:bfef310 \
  .
```

If deploying from a registry, tag/push using the operator-approved registry. Do not publish credentials in shell history or logs.

Before rehearsal and cutover, close the image identity loop:

```bash
docker image inspect new-api-creative-embed:bfef310 \
  --format 'candidate_image_id={{.Id}} repo_digests={{join .RepoDigests ","}}'
```

Choose one transfer path and use the same candidate image for both rehearsal and the final compose cutover:

- registry push/pull: record the immutable `RepoDigest` after push and verify the VPS-A pulled image has the same digest;
- `docker save` / `docker load`: record the source image ID and verify the loaded VPS-A image ID before setting `CANDIDATE_IMAGE`;
- build on VPS-A: rerun the ref/artifact gates on that checkout and record the resulting image ID.

Do not use a mutable tag alone as proof that rehearsal and production cutover used the same image.

## 6. VPS-A backup and DB-copy migration rehearsal

All commands in this section are examples for an authorized maintenance window. They are intentionally conservative and avoid printing `.env` or DB content.

> Important: `env.production.example` is a checklist/template fragment, not a full production `.env`. Never copy it over `/home/admin/apps/new-api/.env`. Preserve the existing production `.env` and append/update only reviewed Creative keys.

### 6.1 Read-only baseline

```bash
ssh -i ~/.ssh/id_ed25519 admin@47.80.71.35 \
  'cd /home/admin/apps/new-api && docker compose ps && df -h / && free -h'
```

### 6.2 Start maintenance and create consistent backups on VPS-A

Because the user accepts a maintenance window, prefer a stopped-container backup over a hot `cp` of SQLite files.

```bash
ssh -i ~/.ssh/id_ed25519 admin@47.80.71.35 'bash -s' <<'REMOTE'
set -euo pipefail
APP=/home/admin/apps/new-api
TS=$(date +%Y%m%d-%H%M%S)
BK="$APP/backups/creative-embed-$TS"
umask 077
mkdir -p "$BK"
cd "$APP"

# Stop writes before taking the live backup. This is the maintenance-window start.
docker compose stop new-api

cp -a docker-compose.yml "$BK/docker-compose.yml.pre-creative"
cp -a .env "$BK/.env.pre-creative"

resolve_live_db() {
  local raw db_path live_db
  raw=$(awk -F= '/^SQLITE_PATH=/{print $2}' .env | tail -1)
  db_path=$(printf '%s' "$raw" | sed 's/["'"'"']//g' | cut -d'?' -f1)
  if [ -z "$db_path" ]; then db_path="/data/new-api.db"; fi
  case "$db_path" in
    /data/*) live_db="$APP/data/${db_path#/data/}" ;;
    "$APP"/data/*) live_db="$db_path" ;;
    data/*) live_db="$APP/$db_path" ;;
    /*)
      echo "SQLITE_PATH resolves outside the standard app data mount; inspect on VPS only." >&2
      echo "Stop and explicitly verify the host path before proceeding." >&2
      exit 1
      ;;
    *) live_db="$APP/$db_path" ;;
  esac
  if [ ! -f "$live_db" ]; then
    echo "live_db_not_found; inspect resolved path on VPS only." >&2
    exit 1
  fi
  printf '%s\n' "$live_db"
}
LIVE_DB=$(resolve_live_db)

sqlite3 "$LIVE_DB" ".backup '$BK/new-api.db.pre-creative.bak'"
sqlite3 "$BK/new-api.db.pre-creative.bak" "PRAGMA integrity_check;"

# If WAL/SHM files exist, record their presence as metadata only. The .backup
# output above is the canonical backup artifact.
for suffix in -wal -shm; do
  if [ -e "$LIVE_DB$suffix" ]; then
    stat -c "%n %s bytes %y" "$LIVE_DB$suffix" >> "$BK/sqlite-wal-shm-presence.txt"
  fi
done

printf 'backup_dir=%s\n' "$BK"
printf 'db_backup=%s\n' "$BK/new-api.db.pre-creative.bak"
REMOTE
```

The `.env` backup remains on VPS-A and must not be printed or copied into task logs.

### 6.3 Capture strict row-count snapshot

Run this against the DB backup created in 6.2 and again against the rehearsal DB after candidate startup. Critical table query failures must block deployment. Replace `BK=...` with the `backup_dir=...` printed by 6.2.

```bash
ssh -i ~/.ssh/id_ed25519 admin@47.80.71.35 'bash -s' <<'REMOTE'
set -euo pipefail
APP=/home/admin/apps/new-api
cd "$APP"
BK='<backup_dir-from-6.2>'
DB_SNAPSHOT="$BK/new-api.db.pre-creative.bak"
test -f "$DB_SNAPSHOT"
python3 - "$DB_SNAPSHOT" <<'PY'
import sqlite3, sys
path = sys.argv[1]
critical = [
    'users', 'tokens', 'channels', 'abilities', 'options',
    'models', 'vendors', 'quota_data', 'logs', 'top_ups',
    'redemptions', 'tasks', 'subscription_plans',
    'subscription_orders', 'user_subscriptions',
    'subscription_pre_consume_records',
]
con = sqlite3.connect(path)
try:
    cur = con.cursor()
    existing = {row[0] for row in cur.execute("SELECT name FROM sqlite_master WHERE type='table'")}
    missing = [t for t in critical if t not in existing]
    if missing:
        raise SystemExit('missing critical tables: ' + ','.join(missing))
    for table in critical:
        count = cur.execute(f'SELECT COUNT(*) FROM {table}').fetchone()[0]
        print(f'{table}\t{count}')
finally:
    con.close()
PY
REMOTE
```

### 6.4 Rehearse candidate startup against a DB copy

This step must use a DB copy and a **minimal whitelist env**, not the full production `.env`. Replace `<candidate-image>` with the built/pulled candidate image.

```bash
ssh -i ~/.ssh/id_ed25519 admin@47.80.71.35 'bash -s' <<'REMOTE'
set -euo pipefail
APP=/home/admin/apps/new-api
TS=$(date +%Y%m%d-%H%M%S)
TEST_DIR="$APP/backups/creative-migration-rehearsal-$TS"
CANDIDATE_IMAGE='<candidate-image>'
umask 077
mkdir -p "$TEST_DIR/data" "$TEST_DIR/logs"
cd "$APP"

resolve_live_db() {
  local raw db_path live_db
  raw=$(awk -F= '/^SQLITE_PATH=/{print $2}' .env | tail -1)
  db_path=$(printf '%s' "$raw" | sed 's/["'"'"']//g' | cut -d'?' -f1)
  if [ -z "$db_path" ]; then db_path="/data/new-api.db"; fi
  case "$db_path" in
    /data/*) live_db="$APP/data/${db_path#/data/}" ;;
    "$APP"/data/*) live_db="$db_path" ;;
    data/*) live_db="$APP/$db_path" ;;
    /*)
      echo "SQLITE_PATH resolves outside the standard app data mount; inspect on VPS only." >&2
      echo "Stop and explicitly verify the host path before proceeding." >&2
      exit 1
      ;;
    *) live_db="$APP/$db_path" ;;
  esac
  if [ ! -f "$live_db" ]; then
    echo "live_db_not_found; inspect resolved path on VPS only." >&2
    exit 1
  fi
  printf '%s\n' "$live_db"
}
LIVE_DB=$(resolve_live_db)
sqlite3 "$LIVE_DB" ".backup '$TEST_DIR/data/new-api.db'"
sqlite3 "$TEST_DIR/data/new-api.db" "PRAGMA integrity_check;"

# Minimal env only. Do not copy production .env into the rehearsal container.
SESSION_SECRET=$(openssl rand -hex 32)
CRYPTO_SECRET=$(openssl rand -hex 32)
cat > "$TEST_DIR/.env.rehearsal" <<ENV
PORT=13984
GIN_MODE=release
TZ=Asia/Hong_Kong
SQLITE_PATH=/data/new-api.db?_busy_timeout=30000
SESSION_SECRET=$SESSION_SECRET
CRYPTO_SECRET=$CRYPTO_SECRET
CREATIVE_ASSET_SYNC_ENABLED=false
CREATIVE_VIDEO_RELAY_ENABLED=false
SYNC_FREQUENCY=3600
UPDATE_TASK=false
CHANNEL_UPSTREAM_MODEL_UPDATE_TASK_ENABLED=false
MEMORY_CACHE_ENABLED=false
ENV
unset SESSION_SECRET CRYPTO_SECRET

docker rm -f new-api-creative-rehearsal >/dev/null 2>&1 || true
docker run -d --name new-api-creative-rehearsal \
  -p 127.0.0.1:13984:13984 \
  --env-file "$TEST_DIR/.env.rehearsal" \
  -v "$TEST_DIR/data:/data" \
  -v "$TEST_DIR/logs:/app/logs" \
  "$CANDIDATE_IMAGE" --log-dir /app/logs >/dev/null
trap 'docker rm -f new-api-creative-rehearsal >/dev/null 2>&1 || true' EXIT

for i in $(seq 1 30); do
  if curl -fsS http://127.0.0.1:13984/api/status >/dev/null; then
    echo 'rehearsal_status=ready'
    break
  fi
  sleep 2
  if [ "$i" -eq 30 ]; then
    echo 'rehearsal_status=failed'
    echo 'Inspect docker logs on the VPS only after local redaction; do not paste raw logs into task records.'
    exit 1
  fi
done

python3 - "$TEST_DIR/data/new-api.db" <<'PY'
import sqlite3, sys
path = sys.argv[1]
critical = [
    'users', 'tokens', 'channels', 'abilities', 'options',
    'models', 'vendors', 'quota_data', 'logs', 'top_ups',
    'redemptions', 'tasks', 'subscription_plans',
    'subscription_orders', 'user_subscriptions',
    'subscription_pre_consume_records',
]
creative = [
    'creative_model_preferences', 'creative_documents', 'creative_assets',
    'creative_asset_quotas', 'creative_document_asset_refs',
    'creative_asset_lifecycle_outboxes',
]
con = sqlite3.connect(path)
try:
    cur = con.cursor()
    existing = {row[0] for row in cur.execute("SELECT name FROM sqlite_master WHERE type='table'")}
    missing = [t for t in critical if t not in existing]
    if missing:
        raise SystemExit('missing critical tables after rehearsal: ' + ','.join(missing))
    for table in critical + [t for t in creative if t in existing]:
        count = cur.execute(f'SELECT COUNT(*) FROM {table}').fetchone()[0]
        print(f'{table}\t{count}')
finally:
    con.close()
PY

printf 'rehearsal_dir=%s\n' "$TEST_DIR"
REMOTE
```

Passing criteria:

- Candidate container starts and `/api/status` is reachable on the rehearsal port.
- Row counts for existing critical tables do not collapse unexpectedly.
- Creative tables may be added.
- No command touched the live DB.
- Rehearsal container env does not contain production provider/payment/S3/admin secrets.
- Rehearsal port is bound only to `127.0.0.1`; the DB copy is not publicly reachable.

If any backup, row-count, or rehearsal gate fails after the old container has been stopped, abort the deploy before editing compose:

```bash
ssh -i ~/.ssh/id_ed25519 admin@47.80.71.35 'bash -s' <<'REMOTE'
set -euo pipefail
cd /home/admin/apps/new-api
# Keep current docker-compose.yml, .env, data, and logs unchanged.
docker compose up -d
curl -k -sS -o /dev/null -w 'api_models=%{http_code}\n' https://api.se7endot.top/v1/models
curl -k -sS -o /dev/null -w 'console_login=%{http_code}\n' https://console.se7endot.top/login
REMOTE
```

Expected abort baseline remains `api_models=401` and `console_login=200`.

## 7. Phase 1 production cutover: Creative routes only

Only after the rehearsal passes, update the production compose image to the candidate image while preserving current service shape.

Required production env additions/updates for Phase 1:

```env
CREATIVE_ASSET_SYNC_ENABLED=false
CREATIVE_VIDEO_RELAY_ENABLED=false
```

Preserve existing `SESSION_SECRET`, `SQLITE_PATH`, `PORT=13000`, and other production settings. Do not replace the production `.env` with `env.production.example`.

Example compose target shape:

```yaml
services:
  new-api:
    image: <candidate-image>
    container_name: new-api-relay
    network_mode: host
    restart: always
    command: --log-dir /app/logs
    env_file:
      - .env
    volumes:
      - ./data:/data
      - ./logs:/app/logs
```

Restart during the approved maintenance window:

```bash
ssh -i ~/.ssh/id_ed25519 admin@47.80.71.35 \
  'cd /home/admin/apps/new-api && docker compose up -d'
```

## 8. Post-deploy checks

### 8.1 Existing baseline checks

These protect current users:

```bash
curl -k -sS -o /dev/null -w 'api_models=%{http_code}\n' https://api.se7endot.top/v1/models
curl -k -sS -o /dev/null -w 'console_login=%{http_code}\n' https://console.se7endot.top/login
```

Expected:

- `api_models=401`
- `console_login=200`

### 8.2 Creative route/header matrix

From this repository, use assertion mode after deployment:

```bash
ops/newapi-opentu-production/creative-route-check.sh --assert \
  https://console.se7endot.top \
  https://api.se7endot.top
```

The script automatically tries to extract one real `/creative/assets/*` path from `/creative/`. If extraction fails, assertion mode fails. It also redacts query strings/fragments from `Location` headers before printing.

Expected after a correct Phase 1 cutover:

- `/creative/` returns HTML app shell with status 200.
- `/creative/sw.js` returns JavaScript, not HTML.
- `/creative/version.json` returns JSON, not HTML.
- one real `/creative/assets/*` returns non-HTML static content.
- missing `/creative/assets/*` returns a static miss, not HTML fallback.
- `/creative/api/bootstrap` returns JSON unauthorized/no-store when logged out, not HTML.
- `/creative/relay/v1/chat/completions` wrong method does not return SPA HTML.
- existing `/v1/models` unauthenticated remains 401.
- existing `/login` remains 200.

### 8.3 FRONTEND_BASE_URL route ownership check

If `FRONTEND_BASE_URL` is set in the effective production env, do not claim embedded readiness until the route matrix proves:

- `/creative/` does not redirect to an unintended external frontend.
- `/creative/assets/*` remains static asset/static miss behavior.
- `/creative/api/*` and `/creative/relay/v1/*` remain local no-store API/relay boundaries.

Unexpected `Location` headers, HTML API fallback, or HTML static-miss fallback are release blockers.

### 8.4 Embedded browser smoke

```bash
python3 scripts/creative_release_gate.py check \
  --embedded-smoke-url https://console.se7endot.top/creative/ \
  --drawnix-ready-timeout-ms 90000
```

### 8.5 Authenticated cloud-sync smoke

Run only after explicit credential handling is approved. Use a dedicated smoke user when possible. Passwords should be typed at the prompt or provided by the operator's secret channel; do not put them in shell history.

The helper below prints only statuses and sanitized generated IDs. It must not print cookies, CSRF, nonce, passwords, token values, response bodies, asset bytes, S3 endpoints, or provider/storage credentials.

Phase 1 disabled-state check:

```bash
ops/newapi-opentu-production/creative-cloud-sync-smoke.sh \
  --phase disabled \
  https://console.se7endot.top
```

Expected Phase 1 result:

- login succeeds for the smoke user;
- `/creative/api/bootstrap` returns Creative auth material;
- `asset_sync_enabled=false`;
- a nonce-protected asset upload attempt is rejected with 403 or 503;
- no document/asset rows are intentionally created.

Phase 2 full Creative 云同步 smoke, after S3-compatible storage is configured:

```bash
ops/newapi-opentu-production/creative-cloud-sync-smoke.sh \
  --phase enabled \
  https://console.se7endot.top
```

Expected Phase 2 result:

- login/bootstrap succeeds and `asset_sync_enabled=true`;
- bad nonce is rejected with 403;
- document create/get/update/list/delete succeeds for a generated smoke document;
- image asset upload succeeds;
- uploaded asset URL is same-origin `/creative/api/assets/:id/content` and never a bucket/signed URL;
- metadata read succeeds;
- byte range fetch returns 206;
- unreferenced smoke asset delete succeeds;
- output contains only statuses and sanitized generated IDs.

## 9. Rollback

### 9.1 Code/image rollback

If existing baseline checks fail, rollback immediately:

1. Restore previous compose image/ref, normally `calciumion/new-api:v0.13.2` unless the pre-deploy backup says otherwise.
2. Keep the same `.env`, `data`, and `logs` mounts.
3. Restart with Docker Compose.
4. Re-run existing baseline checks.

Example:

```bash
ssh -i ~/.ssh/id_ed25519 admin@47.80.71.35 'bash -s' <<'REMOTE'
set -euo pipefail
APP=/home/admin/apps/new-api
cd "$APP"
# Edit docker-compose.yml to restore the backed-up image/ref, or copy back the backed-up compose file.
# Do not alter .env or data.
docker compose up -d
REMOTE
```

Do not delete Creative tables/columns as part of emergency rollback. Leave additive DB artifacts for later audited rollback-forward cleanup if needed.

### 9.2 Cloud-sync/S3 rollback

If Phase 2 cloud-sync checks fail but the base app remains healthy:

1. Set `CREATIVE_ASSET_SYNC_ENABLED=false` in the effective production env.
2. Keep `CREATIVE_ASSET_STORAGE=s3-compatible` and `CREATIVE_ASSET_S3_*` values in the secret store unless rotating them for security; do not print them.
3. Restart `new-api`.
4. Verify `/creative/api/bootstrap` reports asset sync disabled for authenticated users.
5. Preserve S3 objects and DB metadata for investigation. Do not bulk-delete bucket contents or Creative asset rows during emergency rollback.

If both base app and cloud-sync fail, perform code/image rollback first, then investigate storage state offline.

## 10. Phase 2: enable Creative 云同步

Only after private S3-compatible storage is ready, append/update the reviewed Phase 2 keys from `env.production.example`:

```env
CREATIVE_ASSET_SYNC_ENABLED=true
CREATIVE_ASSET_ROLLOUT_MODE=production
CREATIVE_ASSET_STORAGE=s3-compatible
CREATIVE_ASSET_S3_ENDPOINT=<private-object-storage-endpoint>
CREATIVE_ASSET_S3_REGION=<region-or-auto>
CREATIVE_ASSET_S3_BUCKET=<private-bucket>
CREATIVE_ASSET_S3_PREFIX=creative-assets
CREATIVE_ASSET_S3_ACCESS_KEY_ID=<secret>
CREATIVE_ASSET_S3_SECRET_ACCESS_KEY=<secret>
CREATIVE_ASSET_S3_FORCE_PATH_STYLE=<true|false>
```

Ensure there is exactly one effective `CREATIVE_ASSET_SYNC_ENABLED` key after editing; remove or override the Phase 1 `false` value. Then restart and run authenticated Creative cloud-sync smoke. Public asset refs must remain `/creative/api/assets/:id/content`; never expose bucket or signed URLs.
