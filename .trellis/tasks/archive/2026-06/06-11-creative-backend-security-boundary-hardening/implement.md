# Implementation Plan — Creative backend security boundary hardening

## Steps

1. Add failing router test for `FRONTEND_BASE_URL` + Creative paths.
2. Extract/register Creative API/relay routes outside static web serving fallback.
3. Add Suno cross-platform fetch tests and implement platform validation + sanitized DTO.
4. Add forbidden-field tests for notify/callback/webhook/owner/user/API-secret aliases; update backend denylist and route-specific guards.
5. Add cache header tests; skip/override cache for Creative API/relay.
6. Add XFF spoof test or trusted proxy config test; implement canonical/trusted origin logic.
7. Harden proxy redirect client usage and sensitive header stripping where feasible.
8. Run targeted Go tests.

## Validation

```bash
cd /mnt/f/code/project/new-api
GOCACHE=/mnt/f/code/project/new2fly/.cache/go-build \
GOTMPDIR=/mnt/f/code/project/new2fly/.cache/go-tmp \
GOMODCACHE=/home/windc0x/go/pkg/mod \
go test ./router ./middleware ./controller ./relay/common ./relay/constant \
  -run 'Creative|Suno|MJ|Midjourney|Router|SetWebRouter|Forwarded|Forbidden|Cache|Proxy|Notify|Owner' -count=1
```

## Dynamic Workflow Check Branch

Parent post-fix workflow branch `backend-security-boundary-review` must independently inspect the fixed files and report whether H1/H5/H9/M6/H10/M1/proxy hardening are fully covered by tests.
