# Check — Creative Embedded Standalone Cleanup And Model Metadata

Date: 2026-06-14/15 local staging verification.

## Scope verified

Repositories:

- `/mnt/f/code/project/opentu` — embedded Creative frontend.
- `/mnt/f/code/project/new-api` — Creative backend/admin UI and embedded dist.
- `/mnt/f/code/project/new2fly` — release gate, staging compose, Trellis records.

No provider/payment/production endpoints were called. Secrets were not read or printed. Local staging only.

## Dynamic workflow final-audit evidence

The user-required final review was partially run through dynamic workflows, independent of prior reports:

- Completed earlier compact final audit: `.codex-flow/generated/creative-embedded-cleanup-final-audit-compact-20260614.workflow.ts`, journal `.codex-flow/journal/creative-embedded-cleanup-final-audit-compact-20260614.jsonl`.
  - Result used at the time: no OpenTU UI/model-selector/admin i18n must-fix; artifact/static marker gap found.
  - Follow-up manual check showed admin i18n missing-key finding was a false positive: en/zh/fr/ja/ru/vi missing key count = 0 for used `setting.*` keys.
- Post-fix delta attempt: `.codex-flow/generated/creative-embedded-final-delta-audit-20260615.workflow.ts`, journal `.codex-flow/journal/creative-embedded-final-delta-audit-20260615.jsonl`.
  - Outcome: all four broad branches timed out, so this run is recorded but not relied upon for pass/fail.
- Post-fix command-bounded dynamic audits:
  - Artifact branch passed in `.codex-flow/generated/creative-embedded-final-micro-audit-20260615.workflow.ts`, journal `.codex-flow/journal/creative-embedded-final-micro-audit-20260615.jsonl`.
  - UI branch passed in `.codex-flow/generated/creative-embedded-final-ui-command-audit-20260615.workflow.ts`, journal `.codex-flow/journal/creative-embedded-final-ui-command-audit-20260615.jsonl`.
  - Model/catalog branch passed in `.codex-flow/generated/creative-embedded-final-command-audit-20260615.workflow.ts`, journal `.codex-flow/journal/creative-embedded-final-command-audit-20260615.jsonl`; the UI branch in that same command-bounded run was inconclusive due insufficient grep context and was superseded by the later UI command audit above.

## Fresh verification commands

### OpenTU typecheck

```bash
cd /mnt/f/code/project/opentu
pnpm nx run drawnix:typecheck
```

Result: exit 0, `NX Successfully ran target typecheck for project drawnix`.

### Full build/sync/release gate with new-api tests

```bash
cd /mnt/f/code/project/new2fly
python3 scripts/creative_release_gate.py build-sync-check --run-new-api-tests
```

Result: exit 0.

Key evidence from output:

- `opentu embedded static brand contract holds`
- `new-api:web embedded static brand contract holds`
- `new-api:router embedded static brand contract holds`
- `new-api:web matches opentu: 174 files`
- `new-api:router matches opentu: 174 files`
- `no generated sourcemaps found`
- Go tests for `.`, `./router`, `./middleware`, `./controller`, `./model`, `./service`, `./relay/...` passed.
- `go build ./...` passed.

Build noise: pnpm warned about unresolved `${NPM_TOKEN}` in `.npmrc`; this is expected in WSL without host publish credentials and did not block local install/build.

### Docker image and local staging

```bash
cd /mnt/f/code/project/new2fly
docker build --pull=false --progress=plain -t new-api-creative-embed:staging-current /mnt/f/code/project/new-api
STAGING_BIND_ADDR=127.0.0.1 STAGING_PORT=39084 \
  docker compose -f ops/newapi-opentu-staging/docker-compose.yml \
  -p newapi-opentu-staging up -d
```

Result: exit 0.

Image:

```text
sha256:2a822d4d15b505ef7795a4ff7be7d584ab54d148c41797268356992b900d7509
```

Container status:

```text
newapi-opentu-staging-new-api   Up (healthy)   127.0.0.1:39084->3000/tcp
```

Container log showed startup complete and repeated `/api/status` 200 health checks. Unauthenticated Creative bootstrap returned 401 as expected for fail-closed local staging.

### Staging smoke gate

```bash
cd /mnt/f/code/project/new2fly
python3 scripts/creative_release_gate.py check --embedded-smoke-url http://127.0.0.1:39084/creative/
```

Result: exit 0.

Key evidence:

- Artifact contract passed again.
- Playwright `@creative-embedded new-api /creative/ smoke` passed: `1 passed`.
- API/relay paths did not fall back to SPA shell.
- Settings denylist now includes standalone/provider-key copy and `creative_session_unavailable`.

### DOM deep check on current staging

Command: Playwright script against `http://127.0.0.1:39084/creative/`, inspecting initial UI, settings dialog, toolbox, visible text and common attributes.

Result: exit 0.

Screenshot:

```text
/tmp/creative-stage-final-20260614-friendly-empty.png
```

Key DOM evidence:

- Title: `New API Creative - 我的画板1`.
- `#root` exists and has children.
- No boot placeholder remains.
- Bad marker hits: `[]` for initial/settings/toolbox.
- Denylist included: `用户反馈群`, `GitHub Gist`, `GitHub Token`, `Cloud Sync`, `云同步`, `API Key`, `APIKey`, `api.tu-zi.com`, `wiki.tu-zi.com`, `opentu.ai`, `API 地址`, `Base URL`, `Chat-MJ`, `OpenAI 兼容`, `Gemini 兼容`, `自定义接入`, `用户手册`, feedback/GitHub/OpenTu markers, and `creative_session_unavailable`.
- Settings empty state is friendly: `托管会话暂不可用；请返回控制台登录，或等待管理员同步 New API Creative 模型池。`
- The staging-only `#img` model badge remains expected in unauthenticated/empty model-pool fail-closed mode; authenticated non-empty catalog should be validated separately after real admin channels/models are configured.

### Static marker quick scan

```bash
python3 - <<'PY'
from pathlib import Path
roots=[Path('/mnt/f/code/project/opentu/dist/apps/web'), Path('/mnt/f/code/project/new-api/web/creative/dist'), Path('/mnt/f/code/project/new-api/router/web/creative/dist')]
markers=['OpenTu','OpenTU','Opentu','opentu.ai','api.tu-zi.com','wiki.tu-zi.com','aitu-app','API Key','GitHub Gist','GitHub Token','用户反馈群','用户手册','creative_session_unavailable']
for root in roots:
    print('ROOT', root)
    for f in ['changelog.json','sw.js']:
        p=root/f
        txt=p.read_text(errors='ignore') if p.exists() else ''
        hits=[]
        for m in markers:
            if (m.lower() in txt.lower()) if m.islower() else (m in txt):
                hits.append(m)
        print(f, hits)
    print('sw.js.map exists', (root/'sw.js.map').exists())
PY
```

Result:

- For all three roots, `changelog.json []`, `sw.js []`, `sw.js.map exists False`.

## Fixes additionally made during verification

- `settings-dialog.tsx`: managed session-broker empty/error state now renders a friendly embedded message instead of raw `creative_session_unavailable`.
- `creative-embedded.spec.ts`: embedded settings denylist now explicitly includes `creative_session_unavailable`.
- `postprocess-embedded-creative-dist.js`: embedded build postprocess rewrites final `sw.js`/`changelog.json` and removes stale `sw.js.map` after service worker build.
- `creative_release_gate.py`: static brand scan covers `changelog.json` and `sw.js`, and marker list includes `OpenTU` / `API Key`.

## Remaining caveats

- Local staging was unauthenticated and model pool is empty, so model-selector display of `#img` is expected fail-closed evidence, not proof of authenticated non-empty catalog UX. That path should be smoke-tested after real admin channels/models are configured.
- No real provider, payment, or production traffic was exercised.
- Dynamic broad post-fix audit timed out; final confidence relies on fresh release gate, Playwright staging smoke, DOM deep check, static marker scan, and command-bounded dynamic audit branches.

## Spec update

Updated `.trellis/spec/frontend/creative-embedded-release-artifact.md` to record the new executable contract: embedded postprocess must run after `build-sw`, final `sw.js`/`changelog.json` must be scanned for standalone markers, and stale `sw.js.map` must be handled at the Opentu source artifact before sync.

## 2026-06-15 authenticated model UI delta fix

User-reported regression after configuring two mock channel models:

- `/creative` can load while logged out.
- bottom-left sync copy was confusing.
- authenticated model selector still displayed disabled `#img` and no image parameter control.

Clarification verified fresh on staging:

```text
GET /creative/              -> 200 text/html static SPA shell
GET /creative/api/bootstrap -> 401 Unauthorized without a session
GET /creative/api/models    -> 401 Unauthorized without a session
```

So the unauthenticated page shell is public static HTML, but Creative credentials/catalog/nonce remain protected behind `/creative/api/*`; no browser upstream credentials are exposed in logged-out mode.

### Source fix and regression tests

OpenTU delta:

- `runtime-model-discovery.ts` now preserves the exact executable model id from `new-api` (for example `Gpt-image-2`) when enriching case-insensitive static model matches, while still preferring static presentation/parameter metadata for direct discovery paths.
- Added regression coverage proving:
  - embedded selectable models remain managed-catalog-only;
  - static-only `gpt-image-2` is not recreated as an embedded pinned choice;
  - persisted managed `Gpt-image-2` keeps `selectedModelIds=['Gpt-image-2']` and `selectionKey='new-api-creative::Gpt-image-2'`;
  - direct discovery of `Gpt-image-2` returns `shortCode='gpt2'` and static `imageDefaults`, not generated fallback `gi2`.
- Bottom-left badge copy with asset sync disabled now shows only `本地已保存` instead of implying login/cloud sync.

New-api test hardening:

- `service/creative_asset_test.go` was made non-flaky: the S3 object-key no-raw-user-id assertion now checks path segments instead of banning an arbitrary digit substring that can occur randomly in opaque IDs.

### Fresh commands after the delta

```bash
cd /mnt/f/code/project/opentu/packages/drawnix
pnpm exec vitest run \
  src/hooks/use-runtime-models.test.tsx \
  src/constants/__tests__/model-config.test.ts \
  src/services/creative-session-broker.test.ts \
  src/hooks/use-creative-document-sync-status.test.tsx \
  src/utils/runtime-model-discovery.creative-embedded.test.ts \
  --config vitest.config.ts
```

Result: exit 0, 5 files / 31 tests passed.

```bash
cd /mnt/f/code/project/new-api
go test -count=1 ./service -run TestCreativeAssetFakeS3StorageSupportsRangeAndDelete
```

Result: exit 0.

```bash
cd /mnt/f/code/project/new2fly
python3 scripts/creative_release_gate.py build-sync-check --run-new-api-tests
```

Result: exit 0. Evidence included OpenTU build/typecheck, artifact sync identity, static brand contract, no generated sourcemaps, `go test -count=1 .`, selected package Go tests, and `go build ./...`.

### Dynamic workflow delta check

Additional dynamic workflow verification was used for this delta:

- First run: `.codex-flow/generated/creative-model-ui-delta-audit-20260615.workflow.ts`, journal `.codex-flow/journal/creative-model-ui-delta-audit-20260615.jsonl`.
  - Result: UI/auth evidence branch passed; source branch found a real direct-discovery short-code gap (`Gpt-image-2` could become generated `gi2` instead of static `gpt2`).
  - Action: fixed and added direct-discovery regression test.
- Post-fix run: `.codex-flow/generated/creative-model-ui-delta-audit-20260615b.workflow.ts`, journal `.codex-flow/journal/creative-model-ui-delta-audit-20260615b.jsonl`.
  - Result: both source and verification-synthesis branches passed.

### Staging rebuild and smoke

```bash
docker build --pull=false --progress=plain \
  -t new-api-creative-embed:staging-current \
  /mnt/f/code/project/new-api
```

Result: exit 0.

Image:

```text
sha256:11d5060b5113074ae2be4fd75733b3f77c99390555614ead959b542ea4dd2994
```

```bash
STAGING_BIND_ADDR=127.0.0.1 STAGING_PORT=39084 \
  docker compose -f ops/newapi-opentu-staging/docker-compose.yml \
  -p newapi-opentu-staging up -d
```

Result: container `newapi-opentu-staging-new-api` reached `healthy`, bound to `127.0.0.1:39084`.

```bash
python3 scripts/creative_release_gate.py check \
  --embedded-smoke-url http://127.0.0.1:39084/creative/
```

Result: exit 0, Playwright embedded smoke `1 passed`.

### Authenticated UI smoke on current staging

Password was used only through a silent stdin prompt and was not saved to files.

Key evidence from `/tmp/creative-auth-smoke.cjs`:

```json
{"step":"login","status":200,"success":true,"userId":1}
{"step":"bootstrap","status":200,"success":true,"authMode":"session-broker","csrfTokenLength":48,"nonceLength":48,"modelCount":2,"assetSyncEnabled":false}
{"step":"models","status":200,"success":true,"ids":["Gpt-5.5-mini","Gpt-image-2"],"forbiddenKeyHits":[]}
```

UI evidence:

- title: `New API Creative - 我的画板1`;
- return-to-console button is visible;
- model button is enabled and renders `N # gpt2` for the configured `Gpt-image-2` catalog item;
- no generic `#img` badge;
- parameter button is enabled and shows `自动, 1K, 自动`;
- parameter dropdown contains resolution/quality and `1K` / `2K` / `4K` options;
- bottom-left copy shows `本地已保存` only;
- no `登录后同步`, `等待平台保存`, `用户反馈群`, `GitHub Gist`, `GitHub Token`, `Cloud Sync`, `API Key`, `Chat-MJ`, or `api.tu-zi.com` markers;
- console error count: 0.

Screenshot:

```text
/tmp/creative-auth-model-params.png
```

### Remaining caveats for this delta

- This smoke covers local staging with the two configured mock models (`Gpt-image-2`, `Gpt-5.5-mini`). It does not exhaust every custom alias or all modalities.
- No real provider generation, payment, or production endpoint was exercised.

### Diff hygiene after delta

```bash
git -C /mnt/f/code/project/opentu diff --check -- ':!dist/**'
git -C /mnt/f/code/project/new-api diff --check -- ':!web/creative/dist/**' ':!router/web/creative/dist/**'
git -C /mnt/f/code/project/new2fly diff --check -- ':!.codex-flow/**' ':!.cache/**'
```

Result: all exit 0.

## 2026-06-15 Creative 云同步 naming + local staging enablement delta

User terminology update: use **云同步** for the new-api-backed Creative document/asset sync UX, not "平台同步". The implementation still means new-api session-backed cloud sync, not the original OpenTU GitHub/Gist sync.

### Local staging configuration

Updated ignored local staging env file:

```text
ops/newapi-opentu-staging/.env.staging.local
```

Added local verification-only Creative cloud sync settings:

```env
CREATIVE_ASSET_SYNC_ENABLED=true
CREATIVE_ASSET_ROLLOUT_MODE=local
CREATIVE_ASSET_STORAGE=database
CREATIVE_ASSET_USER_MAX_BYTES=2147483648
CREATIVE_ASSET_USER_MAX_ASSETS=10000
```

This is intentionally local/staging database storage only. Production remains required to use `CREATIVE_ASSET_ROLLOUT_MODE=production` with `CREATIVE_ASSET_STORAGE=s3-compatible` and complete private S3-compatible object storage configuration.

Container was recreated from local image and reached healthy state:

```text
image sha256:66efd68874c200ac438a92d1d327db1379a749236863213efdb8f0d1c4303e88
newapi-opentu-staging-new-api: Up (healthy), 127.0.0.1:39084->3000/tcp
```

Unauthenticated boundary remains fail-closed:

```text
GET http://127.0.0.1:39084/creative/api/bootstrap -> 401 Unauthorized
Cache-Control: private, no-store
```

### UI wording delta

Changed embedded save status copy from ambiguous platform/local labels to explicit cloud/browser labels:

- idle: `云同步就绪`
- syncing: `正在同步到云端…`
- cloud-saved: `已同步到云端`
- local pending with sync enabled: `已保存到此浏览器 · 等待云同步 N`
- local pending with sync disabled: `云同步不可用 · 已保存到此浏览器`
- local saved: `已保存到此浏览器`

Built artifact scan confirmed all three embedded artifact trees contain the new labels and no longer contain the old ambiguous strings:

```text
opentu/dist/apps/web: 本地已保存=0, 平台已保存=0, 等待平台保存=0
new-api/web/creative/dist: 本地已保存=0, 平台已保存=0, 等待平台保存=0
new-api/router/web/creative/dist: 本地已保存=0, 平台已保存=0, 等待平台保存=0
```

The embedded Playwright smoke denylist was adjusted narrowly: it no longer treats the managed status word `云同步` as a forbidden standalone marker, but it still rejects GitHub/Gist/Cloud Sync/APIKey/Base URL/provider setup markers.

### Fresh commands after this delta

```bash
cd /mnt/f/code/project/opentu/packages/drawnix
pnpm exec vitest run \
  src/hooks/use-creative-document-sync-status.test.tsx \
  src/utils/runtime-model-discovery.creative-embedded.test.ts \
  --config vitest.config.ts
```

Result: exit 0, 2 files / 10 tests passed.

```bash
cd /mnt/f/code/project/new2fly
python3 scripts/creative_release_gate.py build-sync-check --run-new-api-tests
```

Result: exit 0. OpenTU embedded artifact rebuilt, synced into both new-api Creative dist trees, all artifact/static-brand checks passed, new-api selected Go tests and `go build ./...` passed.

```bash
cd /mnt/f/code/project/new2fly
docker build --pull=false --progress=plain \
  -t new-api-creative-embed:staging-current /mnt/f/code/project/new-api
STAGING_BIND_ADDR=127.0.0.1 STAGING_PORT=39084 \
  docker compose -f ops/newapi-opentu-staging/docker-compose.yml \
  -p newapi-opentu-staging up -d --force-recreate
```

Result: image `sha256:66efd68874c200ac438a92d1d327db1379a749236863213efdb8f0d1c4303e88`; container healthy.

```bash
cd /mnt/f/code/project/new2fly
python3 scripts/creative_release_gate.py check \
  --embedded-smoke-url http://127.0.0.1:39084/creative/
```

First run failed because the old smoke denylist still banned the Chinese status word `云同步`. After narrowing the denylist to standalone GitHub/Gist/API-key surfaces, rerun result: exit 0, embedded Playwright smoke passed.

### Dynamic workflow delta audit

Ran a command-bounded dynamic workflow for this delta:

- workflow: `.codex-flow/generated/creative-cloud-sync-delta-audit-20260615.workflow.ts`
- journal: `.codex-flow/journal/creative-cloud-sync-delta-audit-20260615.jsonl`
- rerun: `codex-flow run .codex-flow/generated/creative-cloud-sync-delta-audit-20260615.workflow.ts`

Branches:

1. UI copy / smoke denylist: passed. It confirmed the copy change does not re-expose standalone GitHub/Gist/API-key sync surfaces and the denylist relaxation is scoped to managed cloud-sync status copy. Residual risk: phrase-level denylist may miss future reworded standalone markers.
2. Staging cloud sync config: passed. It confirmed local staging env uses `local` + `database` and runtime/docs still require S3-compatible storage for production. Residual risk: static review alone does not prove a user will not reuse local env in production.
3. Authenticated smoke script coverage: mostly passed. It confirmed the prepared smoke covers bootstrap asset sync, nonce-protected document writes, and asset upload/range/delete without printing secret values on the normal path. It found small script gaps: asset field name should be `size`, add GET document, add bad-nonce negative check, and assert no storage/provider fields in upload response. The `/tmp/creative-cloud-sync-smoke.cjs` helper was updated accordingly.

### Authenticated cloud-sync smoke status

Prepared local helper:

```text
/tmp/creative-cloud-sync-smoke.cjs
```

It logs in, asserts `assetSyncEnabled: true`, exercises document create/list/get/update/delete, rejects a bad nonce update, uploads a tiny PNG, range-reads asset content, asserts no storage/provider fields in the upload response, and deletes the asset.

Not run in this Codex transcript because doing so requires entering the admin password; to avoid writing the password into tool logs, run it from a local shell with the password supplied interactively/environment-only, not committed or echoed.

### Authenticated cloud-sync smoke executed

Ran the prepared authenticated smoke against local staging without printing credential values in command output:

```bash
node /tmp/creative-cloud-sync-smoke.cjs
```

Result: exit 0.

Evidence summary:

```text
login -> 200 success=true
bootstrap -> 200 success=true assetSyncEnabled=true csrfTokenLength=48 nonceLength=48
document-create -> 201 success=true revision=1
document-list -> 200 success=true listed=true
document-get -> 200 success=true
document-bad-nonce -> 403
document-update -> 200 success=true revision=2
asset-upload -> 201 success=true url=/creative/api/assets/<opaque-id>/content size=66
asset-content Range bytes=0-7 -> 206 image/png bytes=8
asset-delete -> 200 success=true
document-delete -> 200 success=true
done -> ok=true
```

This confirms local staging Creative 云同步 is enabled for the logged-in new-api session and that the document/asset happy path plus nonce rejection works against the current container image.
