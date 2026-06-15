# VPS-A Read-only Preflight — 2026-06-15

Scope: read-only SSH preflight authorized by user. No files were modified, no services were restarted, no deployment was attempted, and no secret values were printed.

## SSH / host

- SSH key present locally: `~/.ssh/id_ed25519`.
- SSH target succeeded: `admin@47.80.71.35`.
- Hostname: `iZ5ts1b7e631cus6rzvbt3Z`.
- Probe time: `2026-06-15T14:39:31+08:00`.
- User: `admin`.

## System health

- Root filesystem: 40G total, 29G used, 8.7G available, 77% used.
- Memory: 1.8Gi total, 637Mi available at probe time.
- Swap: 6.0Gi total, 507Mi used.
- User services reported active:
  - `cliproxyapi.service`
  - `cluster-monitor.timer`
  - `backup-core-state.timer`

## new-api deployment baseline

- App directory exists: `/home/admin/apps/new-api`.
- Current deployment shape: Docker Compose with host networking.
- Current compose service/image:
  - service: `new-api`
  - container: `new-api-relay`
  - image: `calciumion/new-api:v0.13.2`
  - image id: `sha256:98361b3114f043f94ffd5affc457ee8d64923a0cc53e2824f2e727017ac098f1`
  - container created: `2026-05-27T12:01:29Z`
  - restart policy: `always`
- Current `docker-compose.yml` metadata:
  - size: 255 bytes
  - modified: `2026-05-27 20:01:28 +0800`
- Current compose content, redacted for accidental secret-like scalar values:

```yaml
services:
  new-api:
    image: calciumion/new-api:v0.13.2
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

## Selected env presence (redacted)

From container env inspection, selected keys were:

```text
PORT=13000
SESSION_SECRET=<set>
SQLITE_PATH=<set>
TZ=Asia/Hong_Kong
```

No `CREATIVE_*` asset/video env keys appeared in the selected env output. No `FRONTEND_BASE_URL` appeared in the selected env output. Secret values were not printed.

## Data/backups

- `/home/admin/apps/new-api/data`: 1.2G.
- `/home/admin/apps/new-api/backups`: 4.4G.
- Recent automatic DB backup exists for 2026-06-15:
  - `/home/admin/apps/new-api/backups/auto/new-api.db.20260615-031500.bak`
  - size: 197455872 bytes.

## Reverse proxy / network

- `new-api-relay` uses `network_mode: host` and `PORT=13000`.
- System `caddy` service is active; `nginx` inactive.
- Public domains route through Caddy/new-api baseline:
  - `https://api.se7endot.top/v1/models -> 401` (expected public API unauthenticated status)
  - `https://console.se7endot.top/login -> 200`

## Current Creative route baseline before deployment

The current production image is not the embedded Creative candidate. Route checks show `/creative` is not correctly served as the new embedded Creative surface yet:

| URL | Status | Content-Type | Classification |
| --- | ---: | --- | --- |
| `https://console.se7endot.top/creative` | 200 | `text/html; charset=utf-8` | Existing console SPA fallback, not verified Creative app shell |
| `https://console.se7endot.top/creative/` | 301 | `text/html; charset=utf-8` | Redirects to `/creative` |
| `https://console.se7endot.top/creative/sw.js` | 200 | `text/html; charset=utf-8` | Incorrect for Creative SW; current SPA fallback |
| `https://console.se7endot.top/creative/version.json` | 200 | `text/html; charset=utf-8` | Incorrect for Creative metadata; current SPA fallback |
| `https://console.se7endot.top/creative/assets/__missing_release_check__.js` | 200 | `text/html; charset=utf-8` | Incorrect; missing asset should be static miss, not SPA fallback |
| `https://console.se7endot.top/creative/api/bootstrap` | 200 | `text/html; charset=utf-8` | Incorrect; API boundary should be JSON/no-store and unauthenticated should reject |
| `https://console.se7endot.top/creative/relay/v1/chat/completions` | 200 | `text/html; charset=utf-8` | Incorrect; relay boundary should not be SPA fallback |
| `https://api.se7endot.top/creative/` | 404 | not present | Not served on API domain baseline |
| `https://api.se7endot.top/creative/api/bootstrap` | 404 | not present | Not served on API domain baseline |

## Deployment implications

- Candidate deployment must replace the current official image `calciumion/new-api:v0.13.2` with a custom image/check-out that includes embedded Creative dist and routes.
- The target uses Docker Compose + host networking; runbook should preserve this shape unless explicitly changed.
- Before deployment, create at least a DB backup and a compose file backup under `/home/admin/apps/new-api/backups` or another documented backup directory.
- Current production env does not show Creative asset sync configured. If S3-compatible storage is not ready, first production cutover should deploy Creative with `CREATIVE_ASSET_SYNC_ENABLED=false` or keep cloud-sync disabled until storage config is supplied.
- Post-deploy route checks must prove console `/creative/*` no longer falls back to the default console SPA for static/API/relay paths.
