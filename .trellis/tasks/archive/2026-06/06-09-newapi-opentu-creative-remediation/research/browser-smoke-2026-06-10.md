# Browser Smoke Evidence — 2026-06-10

## Environment

- new-api repo: `/mnt/f/code/project/new-api`
- opentu repo: `/mnt/f/code/project/opentu`
- Temporary server port: `3019`
- Temporary database: `/tmp/new-api-creative-smoke-3019.db`
- Temporary log: `/tmp/new-api-creative-smoke-3019.log`
- Server command:

```bash
cd /mnt/f/code/project/new-api
setsid env \
  SESSION_SECRET=creative_smoke_secret_3019 \
  SQLITE_PATH=/tmp/new-api-creative-smoke-3019.db \
  PORT=3019 \
  GIN_MODE=release \
  go run main.go > /tmp/new-api-creative-smoke-3019.log 2>&1 < /dev/null &
```

The isolated SQLite instance was initialized through `/api/setup`, then logged in through `/api/user/login`.

## Curl smoke

### `/creative/` page

- `GET /creative/` returned `HTTP/1.1 200 OK`.
- Response headers included creative embedded controls:
  - `Content-Security-Policy: frame-ancestors 'self'; base-uri 'self'; object-src 'none'`
  - `Permissions-Policy: camera=(), microphone=(), geolocation=(), payment=()`
  - `X-Creative-Build-Version: 0.9.6`
  - `X-Creative-Build-Time: 2026-06-09T17:28:42.660Z`
- HTML size: `55205` bytes.
- HTML referenced `/creative/assets/` entries.

### `/creative/api/bootstrap`

- `success=true`.
- `auth.mode=session-broker`.
- `auth.csrfToken` and `auth.nonce` were present.
- `profile.brokerBaseUrl=/creative/relay/v1`.
- `models_count=0` in this isolated DB because no channels/models were configured.
- `assetSync.enabled=false` with reason `creative asset sync disabled`, expected for this local smoke without S3/config.

### Image relay safety chain

With browser session but no same-origin signal:

- `POST /creative/relay/v1/images/generations` returned `403` with `creative request origin is invalid`.

With same-origin `Origin` but no CSRF/nonce:

- Returned `403` with `creative session auth is invalid`.

With same-origin `Origin`, valid `X-Creative-CSRF`, valid `X-Creative-Nonce`, and forbidden body field `apiKey`:

- Returned `400 Bad Request` with `forbidden field apiKey` before any upstream relay.

With same-origin `Origin`, valid CSRF/nonce, and allowed body:

- Returned `403` with `model is not available for this user`, which is expected for the isolated DB with no creative model pool and proves the request reached server-side model/group gating rather than direct browser upstream fallback.

## Playwright browser smoke

Executed from `/mnt/f/code/project/opentu` using `@playwright/test` Chromium:

```bash
node <inline playwright script>
```

Observed output:

```text
login status 200
login success body includes true
button visible true
after click url http://127.0.0.1:3019/dashboard
creative requests 24
leaked creative requests 0
```

Warnings observed in the browser console were expected for this isolated smoke environment:

- `creative models pool is empty` because no upstream channels/models were configured.
- `asset_sync_failed` because asset sync is disabled locally.
- IndexedDB version warning from existing browser profile/test environment.

## Parent task impact

This smoke validates the current parent-task browser gate at a local no-upstream level:

- Authenticated `/creative/` loads.
- Return-to-console button is visible in the browser-rendered UI.
- Clicking the button navigates to `/dashboard`.
- Creative bootstrap uses session-broker mode and `/creative/relay/v1` broker base.
- Image relay route exists and enforces same-origin + CSRF/nonce + forbidden-field rejection.
- No `/creative` browser requests in the Playwright trace contained `Authorization`, `X-API-Key`, `apiKey`, `baseUrl`, or `provider` URL leakage.

Not covered by this local smoke:

- Real upstream image generation, because the isolated DB had no configured model/channel pool.
- Video/Suno/MJ, which remain split child tasks.
