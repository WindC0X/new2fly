# Progress — 2026-06-11

## Implemented in `../new-api`

- Extracted Creative API/relay registration into `SetCreativeRouter` and registered it in both normal web mode and `FRONTEND_BASE_URL` mode.
- Added private/no-store headers for Creative API/relay, including fail-closed `NoRoute` handling and trailing-slash variants that would otherwise trigger Gin redirects.
- Hardened Creative origin calculation to ignore untrusted `X-Forwarded-*` in both session same-origin middleware and Creative API document-asset origin validation.
- Expanded relay/Suno forbidden-field normalization for notify/callback/webhook/owner/user/API-secret/MJ-secret aliases across JSON, form, multipart file names, query, and headers while preserving generic top-level `model` where allowed.
- Restricted Suno fetch to owner-scoped Suno tasks only and replaced generic task DTO with a sanitized Suno DTO that omits `user_id`, `channel_id`, `quota`, `result_url`, and private URLs.
- Replaced empty-proxy/default-client fallbacks with managed clients carrying redirect checks; cross-host redirects now strip sensitive and cookie-like headers.
- Hardened Creative MJ image proxy nil-client fallback so redirects remain SSRF-checked.

## Dynamic workflow check usage

- Ran `.codex-flow/generated/creative-backend-security-boundary-check.workflow.ts`; it found additional gaps: Creative unmatched/trailing paths under `FRONTEND_BASE_URL`, Suno sanitized DTO coverage, bare `notify`, cookie-like redirect headers, and MJ image default-client fallback.
- Fixed those findings and ran `.codex-flow/generated/creative-backend-security-boundary-recheck.workflow.ts`; recheck passed Suno/denylist and HTTP-client areas, and raised a remaining route trailing-slash concern.
- Added trailing-slash route tests/handlers and verified with Go tests after that finding.

## Verification evidence

```bash
cd /mnt/f/code/project/new-api
GOCACHE=/mnt/f/code/project/new2fly/.cache/go-build \
GOTMPDIR=/mnt/f/code/project/new2fly/.cache/go-tmp \
GOMODCACHE=/home/windc0x/go/pkg/mod \
go test ./router ./middleware ./controller ./relay/common ./relay/constant ./service \
  -run 'Creative|Suno|MJ|Midjourney|Router|SetWebRouter|Forwarded|Forbidden|Cache|Proxy|Notify|Owner|HTTPClient|Redirect' \
  -count=1
# PASS: router, middleware, controller, relay/common, relay/constant, service
```

```bash
GOCACHE=/mnt/f/code/project/new2fly/.cache/go-build \
GOTMPDIR=/mnt/f/code/project/new2fly/.cache/go-tmp \
GOMODCACHE=/home/windc0x/go/pkg/mod \
go test ./router ./middleware ./controller ./service -count=1
# PASS: router, middleware, controller, service
```

```bash
GOCACHE=/mnt/f/code/project/new2fly/.cache/go-build \
GOTMPDIR=/mnt/f/code/project/new2fly/.cache/go-tmp \
GOMODCACHE=/home/windc0x/go/pkg/mod \
go test ./relay -count=1
# PASS: relay package compiles; no test files
```

Known unrelated broader-suite failures observed in `go test ./relay/... -count=1`: existing `relay/channel/claude` file-content conversion tests and `relay/helper` stream scanner status test fail outside this task's touched code path.
