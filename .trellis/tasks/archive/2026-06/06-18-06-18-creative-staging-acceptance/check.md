# Check — Creative staging acceptance

Date: 2026-06-18 (Asia/Shanghai)
Scope: staging only. Production was not touched. No real Duomi/GrsAI/provider generation calls were made.

## Revisions / image

- new-api: `8f50577 fix(creative): finalize managed binding release gates`
- OpenTU: `59b09cc5 fix(creative): close managed runtime model gaps`
- new2fly baseline: `204a6fa chore(task): archive creative adapter capability task`
- Built image: `new-api-creative-embed:staging-current`
- Image ID: `sha256:ea9bcf6e3a369a434db87fc786a138d7b8df7b9cc69ad6cd73946b1924316712`
- Image created: `2026-06-18T04:24:29.965456229Z`

## Deployment

Compose file:

```bash
ops/newapi-opentu-staging/docker-compose.yml
```

Staging endpoint:

```text
http://127.0.0.1:39084
```

Container:

```text
newapi-opentu-staging-new-api — healthy — 127.0.0.1:39084->3000/tcp
```

Healthcheck output confirmed `"success":true` from `/api/status` and Docker health status `healthy`.

## Commands run

Build image from the checked-out new-api tree:

```bash
cmd.exe /C "cd /d F:\\CODE\\Project\\new-api && docker build --pull=false --progress=plain -t new-api-creative-embed:staging-current ."
```

Refresh staging only:

```bash
cmd.exe /C "cd /d F:\\code\\project\\new2fly && set STAGING_BIND_ADDR=127.0.0.1&& set STAGING_PORT=39084&& docker compose -f ops\\newapi-opentu-staging\\docker-compose.yml -p newapi-opentu-staging up -d"
```

Route smoke:

```bash
bash ops/newapi-opentu-production/creative-route-check.sh --assert http://127.0.0.1:39084 http://127.0.0.1:39084
```

Logged-in/admin smoke used a temporary root smoke user inserted into the staging SQLite database, then deleted after checks. The temporary password was not printed or persisted in the repository. The container was returned to `healthy` after cleanup.

## Route smoke result

```text
creative-app-shell              GET 200 text/html; charset=utf-8       no-cache
creative-service-worker         GET 200 text/javascript; charset=utf-8 no-cache
creative-version-json           GET 200 application/json               no-cache
creative-existing-asset         GET 200 text/javascript; charset=utf-8 public, max-age=31536000, immutable
creative-missing-asset          GET 404 text/plain; charset=utf-8      no-cache
creative-bootstrap-unauth       GET 401 application/json; charset=utf-8 private, no-store
creative-relay-wrong-method     GET 404 application/json; charset=utf-8 private, no-store
existing-api-models-unauth      GET 401 application/json; charset=utf-8
existing-console-login          GET 200 text/html; charset=utf-8       no-cache
```

## Logged-in / admin smoke result

- Temporary dashboard login succeeded.
- Logged-in `/creative/api/bootstrap` returned HTTP 200 JSON success and bootstrap auth material.
- `/system-settings/models/creative-model-bindings` returned HTTP 200 `text/html` app shell.
- `/api/creative/model-bindings` returned HTTP 200 JSON success with `Cache-Control: no-store`.
- `/api/creative/channel-summaries?page=1&page_size=20` returned HTTP 200 JSON success with `Cache-Control: no-store`.
- Channel summaries were sanitized: response items only contained `id`, `name`, `group`, `status`, `models`; no channel `key`, `base_url`, `authorization`, or `access_token` fields appeared.
- Post-cleanup verification: staging container healthy; the temporary smoke user row was removed.

## User-facing staging acceptance checklist

Use staging only:

```text
http://127.0.0.1:39084
```

Manual checks before any production deployment:

- Open `/creative/` and confirm the Creative app shell loads.
- Log out, then open `/creative/api/bootstrap`; it should reject the session instead of redirecting to the public frontend.
- Log in with a staging account and confirm `/creative/api/bootstrap` succeeds.
- As an admin staging user, open `/system-settings/models/creative-model-bindings`.
- Confirm the Creative model bindings API and channel summaries load without exposing provider keys, base URLs, authorization headers, or access tokens.
- Do not submit real Duomi/GrsAI/provider generation requests during this acceptance pass.

## Reviewer verification

- `docker ps --filter name=newapi-opentu-staging-new-api` showed `newapi-opentu-staging-new-api` running `new-api-creative-embed:staging-current` and healthy on `127.0.0.1:39084->3000/tcp`.
- `docker inspect newapi-opentu-staging-new-api` showed image ID `sha256:ea9bcf6e3a369a434db87fc786a138d7b8df7b9cc69ad6cd73946b1924316712`.
- `curl http://127.0.0.1:39084/api/status` returned HTTP 200 with `"success":true`.
- `bash ops/newapi-opentu-production/creative-route-check.sh --assert http://127.0.0.1:39084 http://127.0.0.1:39084` passed.
- Local checkout evidence matched the intended revisions: new-api `8f50577`, OpenTU `59b09cc5`.
- `.codex/config.toml` is unrelated local drift and should not be committed with this staging acceptance task.

## Acceptance criteria

- [x] Staging runs the intended new-api/OpenTU commits or an image built from them.
- [x] `/creative/` loads in staging.
- [x] Logged-out and logged-in boundary checks behave as expected.
- [x] Creative model bindings admin page loads and uses sanitized channel summaries.
- [x] User receives staging URL plus manual validation steps.
- [x] Findings, commands, and caveats are recorded before task closure.

## Caveats

- This was staging smoke only, not production deployment.
- No real provider generation request was made; provider billing/latency is intentionally out of scope for this staging acceptance pass.
- The host must keep Docker Desktop running for the local `127.0.0.1:39084` staging container to remain reachable.

## User staging feedback — 2026-06-18

Observed by user during manual staging acceptance:

- Logged out `/creative/` settings provider shows no model list. This is expected because managed `/creative/api/bootstrap` is dashboard-session scoped.
- Logged in model selector loads channel model `gpt-image-2` from New API model pool.
- The AI input bar still does not show model parameter controls for `gpt-image-2`.
- The Creative Model Bindings admin page is empty and only shows mock / GrsAI dry-run template controls; Duomi / live GrsAI channel adapters are not exposed as usable live adapter bindings.

Initial root-cause evidence:

- OpenTU `AIInputBar` renders `ParametersDropdown` only when `compatibleParams.length > 0`.
- OpenTU `getCompatibleParams()` returns `[]` for `creativeManaged` models without a runtime `parameterSchema`.
- New API direct channel catalog entries from `creativeModelsForUser()` currently do not include `parameterSchema`; stored Creative bindings can include it, but staging `creative.model_bindings` is empty.
- New API admin UI text currently states Duomi / GrsAI live adapters are future preparation and GrsAI is dry-run/fixture only.

Conclusion: manual staging found a real product/readiness gap. The next fix should either make direct channel models receive safe runtime schemas from New API or let OpenTU use static params only for known safe direct catalog models, and separately close the Duomi/GrsAI adapter exposure/configuration gap.

## Follow-up fix after user staging feedback — 2026-06-18

Manual staging feedback showed that logged-in channel models appeared, but `Gpt-image-2` still did not render image parameter controls in the AI input bar.

### Root cause

OpenTU `getCompatibleParams()` treated every `creativeManaged` model without runtime `parameterSchema` as having no parameters. Direct New API channel catalog entries can arrive as managed runtime models with no schema, for example `Gpt-image-2`, while the same known model has safe static parameter metadata in OpenTU.

### Fix implemented

OpenTU source changes:

- `/mnt/f/CODE/Project/opentu/packages/drawnix/src/constants/model-config.ts`
  - Runtime `parameterSchema` remains highest priority.
  - For `creativeManaged` models without schema, static parameter fallback is allowed only when `providerModelId` or `id` maps to a known static model with the same type.
  - `priceModelId` is not used for fallback matching.
  - Unknown managed models without schema still return `[]`.
- `/mnt/f/CODE/Project/opentu/packages/drawnix/src/constants/__tests__/model-config.test.ts`
  - Added coverage for providerModelId fallback, direct id fallback, priceModelId non-fallback, unknown no-schema non-fallback, and runtime schema priority.

The source build side effect in `apps/web/public/version.json` was inspected and reverted because it was only a buildTime timestamp change. The generated embedded dist was rebuilt and synchronized into new-api.

### Duomi / GrsAI live adapter conclusion

Research was written to:

```text
.trellis/tasks/06-18-06-18-creative-staging-acceptance/research/duomi-grsai-adapter-gap.md
```

Current conclusion:

- Today, provider keys/base URLs belong in New API Channels.
- Creative Model Bindings is a safe binding/schema editor; it must not store or expose provider credentials.
- Current code supports mock image task and GrsAI dry-run/fixture only.
- Duomi live and GrsAI live adapters are not yet implemented or configurable as executable Creative bindings.
- Live support requires a separate implementation phase for allowlists, provider request/status/result mapping, channel-locked routing, polling, billing/refund/terminal CAS handling, tests, and live canary gates.

### Sub-agent review

- `trellis-implement` completed the OpenTU source/test fix.
- First `trellis-check` attempt failed due provider API `401 Unauthorized`; it was not counted as verification.
- Retried `trellis-check` completed with no target-change findings and no file modifications.
- Check agent reported:
  - touched-file ESLint passed
  - `pnpm nx run drawnix:typecheck` passed
  - targeted Vitest passed, 15/15
  - `git diff --check` passed for source/docs
  - full `pnpm nx run drawnix:lint` still fails on existing unrelated non-target files (370 errors / 1782 warnings), not fixed in this task.

### Commands / verification

Targeted OpenTU test from main session:

```bash
cd /mnt/f/CODE/Project/opentu
pnpm vitest run packages/drawnix/src/constants/__tests__/model-config.test.ts
```

Result: `1 passed (1)`, `15 passed (15)`. Only existing `.npmrc` `${NPM_TOKEN}` warnings appeared.

Whitespace checks:

```bash
git -C /mnt/f/CODE/Project/opentu diff --check -- packages/drawnix/src/constants/model-config.ts packages/drawnix/src/constants/__tests__/model-config.test.ts
git diff --check -- .trellis/tasks/06-18-06-18-creative-staging-acceptance/research/duomi-grsai-adapter-gap.md .trellis/tasks/06-18-06-18-creative-staging-acceptance/check.md .trellis/tasks/06-18-06-18-creative-staging-acceptance/prd.md
```

Result: passed.

Embedded release gate:

```bash
python3 scripts/creative_release_gate.py build-sync-check --source-diff-check --run-new-api-tests --opentu /mnt/f/CODE/Project/opentu --new-api /mnt/f/CODE/Project/new-api
```

Result: passed.

Highlights:

- `pnpm build:web` completed.
- OpenTU dist, `new-api/web/creative/dist`, and `new-api/router/web/creative/dist` matched: 175 files each.
- No generated sourcemaps found.
- new-api Go tests passed for root package plus selected router/middleware/controller/model/service/relay packages.
- `go build ./...` passed.
- Final gate output: `[done] no-secrets Creative release gate completed`.

### Staging refresh

Built new local staging image:

```bash
cmd.exe /C "cd /d F:\CODE\Project\new-api && docker build --pull=false --progress=plain -t new-api-creative-embed:staging-current ."
```

Image ID:

```text
sha256:679e5905ee7b0d41eaf976946633d813d808ff02e3406d5005d6923ea2c484e7
```

Refreshed local staging only:

```bash
cmd.exe /C "cd /d F:\code\project\new2fly && set STAGING_BIND_ADDR=127.0.0.1&& set STAGING_PORT=39084&& docker compose -f ops\newapi-opentu-staging\docker-compose.yml -p newapi-opentu-staging up -d"
```

Post-refresh container state:

```text
newapi-opentu-staging-new-api — image sha256:679e5905ee7b0d41eaf976946633d813d808ff02e3406d5005d6923ea2c484e7 — healthy
```

Route smoke after refresh and again after temporary-user cleanup:

```bash
bash ops/newapi-opentu-production/creative-route-check.sh --assert http://127.0.0.1:39084 http://127.0.0.1:39084
```

Result: passed. `/creative/` returned 200; unauthenticated `/creative/api/bootstrap` returned 401 private/no-store; wrong-method relay failed closed; missing asset returned static 404.

### Logged-in / admin smoke

A temporary root smoke user was inserted into the local staging SQLite DB, used only for smoke, then deleted. The temporary password was stored only under a temp directory during the smoke and removed after cleanup.

Results:

- Login succeeded as temporary root smoke user.
- `/creative/api/bootstrap` returned success and no-store; model list contained `Gpt-image-2` from the staging channel catalog.
- `/api/creative/model-bindings` returned success and private/no-store when called with the same `New-Api-User` header style used by the frontend.
- `/api/creative/channel-summaries?page=1&page_size=20` returned success and private/no-store.
- Channel summaries response did not contain `key`, `base_url`, `authorization`, `access_token`, or `secret` markers.
- Temporary root smoke user was deleted and staging returned to healthy.

### Browser/UI smoke

Playwright smoke against staging logged in as the temporary user and opened:

```text
http://127.0.0.1:39084/creative/?sw=0
```

Result:

- `.parameters-dropdown__trigger` rendered (`parameterTriggerCount: 1`).
- Screenshot showed the selected image model short code `gpt2` and parameter summary `自动, 1K, 自动`.
- Clicking the parameter dropdown produced menu text containing:
  - `图片尺寸`
  - `图片分辨率` with `1K`, `2K`, `4K`
  - `画质` with `自动`, `快速`, `标准`, `高清`

This confirms the staging UI now renders gpt-image-2 image parameter controls for direct New API channel catalog models.

### Remaining caveats

- Duomi/GrsAI live provider calls were not implemented and were not tested; this remains a future adapter task.
- No production deployment was performed.
- Full project `drawnix:lint` remains blocked by existing unrelated issues outside this task's files; touched-file lint/type/test checks passed.
