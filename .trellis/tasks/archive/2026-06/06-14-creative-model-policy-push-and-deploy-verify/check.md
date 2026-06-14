# Check — Creative Model Policy Push And Deploy Verify

Date: 2026-06-14
Operator: WindC0X / Codex
Scope: user-fork push attempt + local-only Docker Compose staging at `127.0.0.1:39084`.

## 1. Push / publication result

### Intended safe targets

| Repo | Local branch / commit | Intended remote target | Result |
|---|---|---|---|
| `/mnt/f/code/project/opentu` | `feat/creative-embed` @ `b206848e` | `fork feat/creative-embed` (`https://github.com/WindC0X/opentu.git`) | Blocked by local HTTPS auth |
| `/mnt/f/code/project/new-api` | `feat/creative-embed` @ `3cca3ac` | `fork feat/creative-embed` (`https://github.com/WindC0X/new-api.git`) | Blocked by local HTTPS auth |
| `/mnt/f/code/project/new2fly` | `master` @ `48185db` before this task | `origin master` (`https://github.com/WindC0X/new2fly.git`) | Blocked by local HTTPS auth |

Attempted commands:

```bash
git -C /mnt/f/code/project/opentu push -u fork feat/creative-embed
git -C /mnt/f/code/project/new-api push fork feat/creative-embed
git -C /mnt/f/code/project/new2fly push origin master
```

Observed failure for all three pushes:

```text
fatal: could not read Username for 'https://github.com': No such device or address
```

No token, credential helper secret, or GitHub credential store was read or printed. Because the user stated GitHub credentials are on the host, no further WSL auth retry was attempted.

### Host-side push commands to run from a credentialed Windows terminal

```bat
cd F:\code\project\opentu
git push -u fork feat/creative-embed

cd F:\code\project\new-api
git push fork feat/creative-embed

cd F:\code\project\new2fly
git push origin master
```

Do not push to upstream `origin` in `opentu` or `new-api` unless explicitly intended.

## 2. Source / release-gate verification

Command:

```bash
cd /mnt/f/code/project/new2fly
python3 scripts/creative_release_gate.py check --source-diff-check
```

Result: **passed**.

Sanitized summary:

- OpenTU embedded index refs: `2` `/creative/assets` entries.
- new-api web embedded index refs: `2` `/creative/assets` entries.
- new-api router embedded index refs: `2` `/creative/assets` entries.
- Dist tree identity: `223` files; `new-api:web` and `new-api:router` match OpenTU.
- Sourcemap policy: `allow`; generated maps present: `1`.
- `git diff --check` passed for relevant paths in `new2fly`, `opentu`, and `new-api`.

## 3. Docker image build

Command:

```bash
docker build --pull=false --progress=plain \
  -t new-api-creative-embed:staging-current \
  /mnt/f/code/project/new-api
```

Result: **passed**.

Final image:

```text
new-api-creative-embed:staging-current
sha256:0a8f0baef549092078ed992e72a538b1a300de096de96442bfc739a82bc0a992
```

The image was built from `/mnt/f/code/project/new-api` after the release-gate check; no stale pre-existing image was used as the deployment candidate.

## 4. Local staging deployment

Command:

```bash
cd /mnt/f/code/project/new2fly
STAGING_BIND_ADDR=127.0.0.1 STAGING_PORT=39084 \
  docker compose -f ops/newapi-opentu-staging/docker-compose.yml \
  -p newapi-opentu-staging up -d
```

Result: **running and healthy**.

Container status:

```text
container: newapi-opentu-staging-new-api
status: running
health: healthy
restart_count: 0
ports: 127.0.0.1:39084->3000/tcp
image: sha256:0a8f0baef549092078ed992e72a538b1a300de096de96442bfc739a82bc0a992
```

No `docker compose down -v` or other destructive volume reset was run.

## 5. Route / asset smoke checks

Base URL: `http://localhost:39084`

| Check | Result | Notes |
|---|---:|---|
| `GET /api/status` | `200` | JSON `success=true` |
| `GET /creative/` | `200` | `Cache-Control: no-cache`, `Content-Type: text/html; charset=utf-8` |
| Parsed HTML `/creative/assets` refs | `2` | `/creative/assets/index--kc2_lmf.js`, `/creative/assets/index-Bhsy9ZA3.css` |
| Entry JS | `200`, `460` bytes | `/creative/assets/index--kc2_lmf.js` |
| Entry CSS | `200`, `12882` bytes | `/creative/assets/index-Bhsy9ZA3.css` |
| Startup app JS | `200`, `3055079` bytes | `/creative/assets/startup-app-CARGtTpt.js` |
| Startup app CSS | `200`, `439368` bytes | `/creative/assets/startup-app-DxC2basr.css` |
| Startup runtime JS | `200`, `1752` bytes | `/creative/assets/startup-runtime-Di8qk2Fd.js` |
| Representative dynamic chunks | `200` | 20+ sampled lazy chunks returned `200` |
| `GET /creative/sw.js` | `200`, `164948` bytes | service worker script exists under `/creative/` |
| Unauthenticated `GET /api/creative/model-policy` | `401` | expected root-auth boundary |
| Unauthenticated `PUT /api/creative/model-policy` | `401` | expected root-auth boundary |

No normal `/api/status`, `/creative/`, or representative `/creative/assets/...` route returned `429` or `5xx`.

## 6. Headless browser smoke

Tool: Python Playwright Chromium, fresh unauthenticated browser context.

Result: **page loaded without page crash**.

Observed sanitized data:

```text
goto_status: 200
title: Opentu - 我的画板1
page_error_count: 0
failed_request_count: 0
http_4xx_5xx_count: 1
http_4xx_5xx_sample: /creative/api/bootstrap -> 401
```

The `/creative/api/bootstrap -> 401` response is expected in this local staging context because no logged-in NewAPI session/cookie was provided. It did not crash the page. The visible page text included `返回控制台`, `灵感创意`, and the prompt panel. Clicking `返回控制台` navigated to:

```text
/sign-in?redirect=%2Fdashboard
```

The screenshot check showed the `返回控制台` button visible at the top-left of the canvas (not hidden by the left toolbar) in a `1440x1000` viewport.

## 7. Known local noise not pushed / not committed

These remain intentionally untracked and were not included in this task's commit scope:

- `/mnt/f/code/project/opentu/packages/drawnix/audio-test.pptx`
- `/mnt/f/code/project/new-api/.codegraph/`
- `/mnt/f/code/project/new-api/.codex-flow/`
- `/mnt/f/code/project/new2fly/.cache/`

## 8. Commands for future operation

### Open staging URL

```text
http://localhost:39084/creative/
```

### Restart local staging without deleting data

```bash
cd /mnt/f/code/project/new2fly
STAGING_BIND_ADDR=127.0.0.1 STAGING_PORT=39084 \
  docker compose -f ops/newapi-opentu-staging/docker-compose.yml \
  -p newapi-opentu-staging up -d
```

### Stop local staging without deleting data

```bash
cd /mnt/f/code/project/new2fly
docker compose -f ops/newapi-opentu-staging/docker-compose.yml \
  -p newapi-opentu-staging down
```

Do not use `down -v` unless intentionally wiping local staging volumes.

## 9. Not run / out of scope

- No public/production deployment, DNS, TLS, reverse-proxy, CDN, or LAN bind was performed.
- No provider/payment/S3/CDN credentials were configured or inspected.
- No real generation task was created and no provider quota was consumed.
- Authenticated admin/model-policy UI changes were not exercised with a real admin session because this task intentionally avoided browser cookies and secrets.

## 10. Final assessment

Local staging verification **passed** for the committed Creative embedded candidate. Remote publication is the only blocked item, and the blocker is host/WSL GitHub HTTPS authentication rather than a code or staging failure. Use the host-side push commands above from a credentialed terminal to publish the three repositories.
