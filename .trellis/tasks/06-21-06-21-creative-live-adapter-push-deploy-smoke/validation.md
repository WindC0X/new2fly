# Validation record — Creative live adapter push / staging smoke

Date: 2026-06-21

## Push

- `new-api` branch `feat/creative-embed` pushed to fork.
  - Verified commit: `ed0fea4 feat(creative): add live image provider adapters`
  - Post-push ahead/behind: `0 0`
- `new2fly` branch `master` pushed to origin.
  - Verified top commit before this task's local planning files: `c23bbaa chore: record journal`
  - Post-push ahead/behind: `0 0`
- `opentu` had no changes for this task.

## Staging deployment

Local Docker Compose staging runbook used:

- `ops/newapi-opentu-staging/README.md`
- URL: `http://127.0.0.1:39084/creative/`
- Container: `newapi-opentu-staging-new-api`
- Image tag: `new-api-creative-embed:staging-current`
- New image id: `sha256:feca78b9fa50477efdb6b475d5a445c58fe9b7b161c9b3312c377c65e574a784`

Safety posture:

- Bound to `127.0.0.1`, not LAN/public.
- Used existing named Docker volumes; did not run `down -v` and did not wipe staging data.
- No production data or production provider credentials were touched.

Pre-deploy gate:

```bash
python3 scripts/creative_release_gate.py check --source-diff-check
```

Result: passed. Embedded Creative artifact contract, source diff check, and no-secret gate completed.

Deployment command:

```bash
docker build --pull=false --progress=plain -t new-api-creative-embed:staging-current /mnt/f/CODE/Project/new-api
STAGING_BIND_ADDR=127.0.0.1 STAGING_PORT=39084 \
  docker compose -f ops/newapi-opentu-staging/docker-compose.yml \
  -p newapi-opentu-staging up -d
```

Health result: container became `healthy`.

## Route/header smoke

Command:

```bash
bash ops/newapi-opentu-production/creative-route-check.sh --assert \
  http://127.0.0.1:39084 http://127.0.0.1:39084
```

Result: passed.

Key observations:

- `/creative/` -> 200 HTML, no-cache, nosniff.
- `/creative/sw.js` -> 200 JS, no-cache, nosniff.
- `/creative/version.json` -> 200 JSON.
- existing `/creative/assets/*` -> 200 immutable asset.
- missing `/creative/assets/*` -> 404 non-HTML.
- unauthenticated `/creative/api/bootstrap` -> 401 JSON, `private, no-store`.
- wrong-method relay path -> JSON no-store failure, not SPA HTML.

## Authenticated/admin smoke

Authorized staging admin login succeeded.

Authenticated Creative endpoints:

- `GET /creative/api/bootstrap`
  - HTTP 200
  - `Cache-Control: private, no-store`
  - returned 2 existing channel-derived models before live binding setup.
- `GET /creative/api/models`
  - HTTP 200
  - returned 2 existing channel-derived models before live binding setup.

Admin Creative endpoints:

- `GET /api/creative/adapter-manifests`
  - HTTP 200
  - manifests included live presets `duomi_image_live` and `grsai_image_live` and templates `duomi_gpt_image`, `grsai_gpt_image`, `grsai_gpt_image_vip`, `grsai_nano_banana`.
- `GET /api/creative/model-bindings`
  - HTTP 200
  - initial config was empty: `version=1`, `bindings=[]`.
- `POST /api/creative/model-bindings/validate` with current empty config
  - HTTP 200, `valid=true`.
- `POST /api/creative/model-bindings/dry-run` with current empty config
  - HTTP 200, `noProviderCall=true`.

## Staging live binding no-provider smoke

The existing staging channel had model `Gpt-image-2`, while live adapter templates intentionally require provider model id `gpt-image-2` from the provider contract. To avoid mutating the existing channel and to avoid provider calls, a staging-only dummy channel was created:

- Channel name: `creative-live-smoke-duomi`
- Channel id: `2`
- Model: `gpt-image-2`
- Base URL: dummy explicit URL
- Key: dummy non-real key
- Purpose: validation/catalog/parameter-schema smoke only; not for real generation.

Staging options set:

- `creative.adapter.enabled=true`
- `creative.adapter.canary_groups=default`

Saved Creative Model Binding:

- id: `duomi:gpt-image-2:staging-live`
- adapterPreset: `duomi_image_live`
- parameterTemplate: `duomi_gpt_image`
- providerModelId: `gpt-image-2`
- channelId: `2`
- enabled: `true`
- canaryGroups: `default`

Validation:

- `POST /api/creative/model-bindings/validate`
  - HTTP 200
  - `valid=true`
- `POST /api/creative/model-bindings/dry-run`
  - HTTP 200
  - `noProviderCall=true`
  - request preview was offline/redacted and did not call provider.
- `PUT /api/creative/model-bindings`
  - HTTP 200
  - binding saved.
- `GET /creative/api/models` after save
  - HTTP 200
  - returned `duomi:gpt-image-2:staging-live`
  - `parameterSchema` ids: `size`, `quality`
  - tags: `creative-adapter`, `image`, `live`, `duomi`

## Browser smoke

Python Playwright browser smoke used the authenticated staging session cookie and opened `/creative`.

Result:

- URL: `http://127.0.0.1:39084/creative/?board=...`
- Title: `New API Creative - 我的画板1`
- Browser `fetch('/creative/api/bootstrap')`: HTTP 200
- Browser `fetch('/creative/api/models')`: HTTP 200
- Model count: 4
- Target live binding: `duomi:gpt-image-2:staging-live`
- Target schema ids: `size`, `quality`
- Target schema labels: `图片尺寸`, `质量`
- Target tags: `creative-adapter`, `image`, `live`, `duomi`

## Not executed

- No real Duomi/GrsAI provider submit/fetch/content smoke was executed.
- No production deployment was executed.
- The staging dummy live binding is not a real generation channel. To test real generation, replace/bind to a real Duomi or GrsAI channel with provider key/BaseURL/model and explicitly authorize provider smoke.

## Current conclusion

- Push: complete.
- Local Docker staging deploy: complete.
- Staging route/header smoke: pass.
- Staging authenticated/admin no-provider smoke: pass.
- Staging browser model/schema smoke: pass.
- Real provider E2E: not run by design.
- Production: gated pending user authorization after reviewing staging result.

## Staging real provider smoke

User explicitly selected real staging provider smoke. This step can incur provider cost.

Before real provider submit:

- Saved live bindings were updated to use real staging channels:
  - `duomi:gpt-image-2:live-smoke` -> channel `4` (`duomi-live-smoke`), `duomi_image_live`, `duomi_gpt_image`.
  - `grsai:gpt-image-2:live-smoke` -> channel `3` (`grsai-live-smoke`), `grsai_image_live`, `grsai_gpt_image`.
- `validate`: HTTP 200, `valid=true`.
- `dry-run`: HTTP 200, `noProviderCall=true`, 2 bindings, provider previews redacted/offline.
- Initial real submit was blocked before provider call by price gate: `gpt-image-2 price not configured`.
- For staging-only smoke, `SelfUseModeEnabled=true` was temporarily enabled, then restored to `false` after smoke to reduce accidental future provider spend.

Real smoke prompt:

```text
A tiny red square centered on a plain white background. No text.
```

Duomi result:

- Model: `duomi:gpt-image-2:live-smoke`
- Submit: HTTP 202, status `in_progress`
- Task id: `task_SVSb7WDZ4mrrNa7wvLLm2qldC9zoFqyA`
- Poll result: HTTP 200, status `completed`, progress `100%`, attempts `7`
- Public result URL: `/creative/relay/v1/images/tasks/task_SVSb7WDZ4mrrNa7wvLLm2qldC9zoFqyA/content`
- Submit/fetch DTO privacy check: no raw `http://` or `https://` provider URL in response body.
- Content fetch: HTTP 200, `Content-Type: image/png`, `Cache-Control: private, no-store`, PNG signature `89504e470d0a1a0a`, bytes `666509`.

GrsAI result:

- Model: `grsai:gpt-image-2:live-smoke`
- Submit: HTTP 202, status `in_progress`
- Task id: `task_RyEjkNYP8AC6n7AuCmu6wsQsVMh32qv4`
- Poll result: HTTP 200, status `completed`, progress `100%`, attempts `7`
- Public result URL: `/creative/relay/v1/images/tasks/task_RyEjkNYP8AC6n7AuCmu6wsQsVMh32qv4/content`
- Submit/fetch DTO privacy check: no raw `http://` or `https://` provider URL in response body.
- Content fetch: HTTP 200, `Content-Type: image/png`, `Cache-Control: private, no-store`, PNG signature `89504e470d0a1a0a`, bytes `699390`.

Post-smoke safety action:

- `SelfUseModeEnabled` restored to `false` on staging.
- Live bindings and real staging channels remain configured. Because self-use mode is now disabled and no price is configured for `gpt-image-2`, accidental future generation should be blocked by the price gate unless pricing or self-use mode is enabled again.

Updated conclusion:

- Staging real Duomi provider E2E: pass.
- Staging real GrsAI provider E2E: pass.
- DTO privacy/content proxy boundary: pass in both real provider smokes.
- Production remains gated pending separate production deployment authorization.

## Manual UI failure follow-up — rate limit and parameter schema fix

User-reported issue after the first staging provider smoke:

- Two manual `/creative` image generations showed local cards with:
  - `creative image task fetch failed: 429`
  - `creative image task submit failed: 429`
- The visible parameter labels were confusing because square `1024x1024` values displayed only as `1:1`.

Root-cause evidence:

- The two manual GrsAI tasks were inserted and eventually completed upstream, but the browser stopped polling after global web rate-limit `429` responses.
- Direct post-cooldown owner-scoped fetch returned both tasks as `completed` with proxied content URLs.
- Both task content endpoints returned `HTTP 200`, `Content-Type: image/png`, `Cache-Control: private, no-store`, PNG signature `89504e470d0a1a0a`.
- The failure cards remaining in the browser are stale local UI state from the earlier `429`; they can be closed/refreshed/retried after the fix.

Code changes applied in `new-api`:

- Narrowly bypassed the IP-level `GlobalWebRateLimit` for high-frequency authenticated Creative operational routes:
  - `GET`/`HEAD /creative/relay/v1/images/tasks/:task_id`
  - `GET`/`HEAD /creative/relay/v1/images/tasks/:task_id/content`
  - `PUT /creative/api/documents/:id`
  - `PATCH /creative/api/preferences/model`
- Kept Creative image task submit (`POST /creative/relay/v1/images/tasks`) subject to protective route guards; it is not blanket-exempted.
- Updated parameter schema display labels so square options show `1024×1024 (1:1)` instead of only `1:1`, and GrsAI GPT image uses `图片尺寸/尺寸` in the catalog.
- Removed unsafe wording from admin manifest descriptions after validation caught `provider` as forbidden display text.

Tests run locally in `new-api`:

```bash
gofmt -w middleware/rate-limit.go middleware/rate-limit_test.go service/creative_model_capability.go service/creative_model_capability_test.go
go test -count=1 ./middleware ./service -run 'TestGlobalWebRateLimit|TestCreativeAdapterManifestsAdminState|TestCreativeLive|TestCreativeGrsAI|TestCreativeImageAdapter'
go test -count=1 ./controller -run 'TestCreativeImageTask|TestCreative.*Model|TestCreative.*Binding|TestCreative.*Bootstrap'
```

Result: passed.

Staging redeploy after fix:

- Rebuilt local candidate Docker image and recreated the staging container without wiping named volumes.
- New staging image id: `sha256:d0ce561cdcfafd8539f974ad87346ad5e7dfa1906ad73ed2de98e4592068b968`.
- Container health: `healthy`.
- Route/header smoke still passed.

Staging config refresh after fix:

- Refreshed Creative Model Bindings from the current adapter manifests using admin `validate -> dry-run -> put`.
- `validate`: HTTP 200.
- `dry-run`: HTTP 200, `noProviderCall=true`.
- `put`: HTTP 200.
- `/creative/api/models` now exposes:
  - Duomi `size`: `1024x1024` label `1024×1024 (1:1)`; `quality` label `质量`.
  - GrsAI `aspectRatio`: label `图片尺寸`, short label `尺寸`, `1024x1024` label `1024×1024 (1:1)`.

Staging verification after fix:

- Repeated existing manual task status polling 75 times against `/creative/relay/v1/images/tasks/:task_id`: all `HTTP 200`, no `429`.
- Submit probe after the 75 polls returned `403` due missing Creative nonce, not `429`; this proves polling no longer exhausts the shared web limiter before relay guards run.
- Repeated document autosave-path PUT probe 65 times: all `400` from payload validation, no `429`; this proves the global web limiter no longer blocks high-frequency autosave traffic.
- Browser smoke opened `/creative/`, fetched `/creative/api/models`, verified both live-smoke model schemas, and observed no browser console errors. The page body still contained the previous local `429` failure cards, which are stale UI state from before the fix.

## Dynamic workflow review after fix

Workflow file:

```bash
.codex-flow/generated/creative-rate-param-fix-review.workflow.ts
```

Run command:

```bash
codex-flow run .codex-flow/generated/creative-rate-param-fix-review.workflow.ts
```

Journal:

```text
.codex-flow/journal/creative-rate-param-fix-review.jsonl
```

Parallel branches:

- `rate-limit-boundary`: `pass_with_risks`, `mustFix=[]`.
- `parameter-schema-contract`: `pass_with_risks`, `mustFix=[]`.
- `staging-evidence-review`: `pass_with_risks`, `mustFix=[]`.

Main findings:

- The global web limiter bypass is narrow and does not include provider submit routes.
- Actual Creative route security/no-store controls remain in the route stack; submit remains protected by auth/origin/nonce/model rate/billing/idempotency guards.
- Parameter changes preserve provider wire values while improving displayed labels.
- Evidence supports the manual UI root cause: old local failure cards came from previous `429` responses, while the underlying manual tasks completed and their content proxies are available.

Non-blocking risks noted:

- Stored bindings keep schema snapshots; staging was explicitly refreshed through admin `validate -> dry-run -> put`, and other environments need the same admin refresh or a deliberate migration if immediate label update is required.
- Old browser failure cards are stale local UI state and may need close/refresh/retry by the user.
- Temporary smoke artifacts under `/tmp/newapi-staging-smoke-FvfQLt` include local DB snapshots/provider-auth helpers; keep them local and clean up when no longer needed.

## Trellis check after follow-up fix

Changed files:

- `new-api/middleware/rate-limit.go`
- `new-api/middleware/rate-limit_test.go`
- `new-api/service/creative_model_capability.go`
- `new-api/service/creative_model_capability_test.go`
- `.trellis/spec/backend/creative-backend-security-boundary.md`
- task validation notes in this directory

Checks:

```bash
go test -count=1 ./middleware ./service ./controller -run 'TestGlobalWebRateLimit|TestCreativeAdapterManifestRegistryExposesSafeTemplates|TestCreativeLive|TestCreativeGrsAI|TestCreativeImageAdapter|TestCreativeImageTask|TestCreative.*Model|TestCreative.*Binding|TestCreative.*Bootstrap'
go test -count=1 ./middleware ./service ./controller
python3 scripts/creative_release_gate.py check --source-diff-check
```

Results: all passed.

## Parameter UI contract correction — Duomi 21:9 and GrsAI default handling

User feedback corrected an over-narrow interpretation of the Duomi Apifox contract:

- Duomi `size` does not document raw ratio `21:9` as a provider enum.
- The same Duomi API documents custom `widthxheight` sizes, with dimensions divisible by 16 and within the pixel budget.
- Final implementation therefore keeps Creative UI `21:9` for Duomi, but maps it to provider `1792x768` before provider-facing live submit and dry-run preview.

New-api code changes:

- `service/creative_image_adapter.go`
  - `creativeDuomiSizeParam` maps Duomi UI `size=21:9` to provider `size=1792x768`.
  - `creativeStringParam` no longer turns missing/nil map keys into string `"<nil>"`.
  - GrsAI GPT image helpers omit raw `auto`, omit `imageSize` for `gpt-image-2` / `gpt-image-2-vip`, and map UI aspect ratio + resolution tier to provider pixel `aspectRatio`.
- `service/creative_model_capability.go`
  - Duomi `gpt-image-2` schema exposes `size=21:9` plus documented custom-size-compatible options.
  - Duomi dry-run preview now calls the same size mapping helper as live submit.
  - GrsAI `gpt-image-2` and `gpt-image-2-vip` expose `aspectRatio + imageSize`; dry-run mirrors live adapter omission/mapping behavior.

Local verification after correction:

```bash
cd /mnt/f/CODE/Project/new-api
go test -count=1 ./service
go test -count=1 ./middleware
cd /mnt/f/code/project/new2fly
python3 scripts/creative_release_gate.py check --source-diff-check
```

Results: all passed.

Staging v4 deployment and smoke:

- Rebuilt staging image and recreated the staging container without wiping volumes.
- Image id: `sha256:c1168fe2f087179c366935f48d4073045fb1e35fa1a21c7b8d1eac7632d9aed0`.
- Container health: `healthy`.
- Refreshed Creative Model Bindings from current adapter manifests using admin `validate -> dry-run -> put`.
- `/creative/api/models` exposed:
  - Duomi `size` default `auto`, 14 options including `1024x1024`, `21:9`, `1:2`, `2:1`; `quality` default `auto`, 4 options.
  - GrsAI normal `aspectRatio` default `auto`, 14 options; `imageSize` only `1K`.
  - GrsAI VIP `aspectRatio` default `auto`, 16 options; `imageSize` `1K/2K/4K`.
- Browser schema smoke: `/creative/` title `New API Creative - 我的画板1`, model count `7`, console errors `0`.
- Dry-run default preview:
  - Duomi default body: `{"model":"gpt-image-2","prompt":"[REDACTED]","size":"auto"}`.
  - GrsAI normal default body omits raw `aspectRatio=auto` and `imageSize`.
  - GrsAI VIP default body omits raw `aspectRatio=auto` and `imageSize`.

Staging real provider smoke v4:

- Duomi `duomi:gpt-image-2:live-smoke` with `userParams={"size":"21:9","quality":"low"}`:
  - Submit HTTP `202`, terminal status `completed`, content HTTP `200`, content type `image/png`, cache `private, no-store`, PNG signature `89504e470d0a1a0a`.
  - Submit/fetch DTO privacy checks did not expose raw provider HTTP URLs.
- GrsAI normal `grsai:gpt-image-2:live-smoke` with empty `userParams={}`:
  - Submit HTTP `202`, terminal status `completed`, content HTTP `200`, content type `image/png`, cache `private, no-store`, PNG signature `89504e470d0a1a0a`.
  - Submit/fetch DTO privacy checks did not expose raw provider HTTP URLs.
- VIP was not live-smoked; it remains catalog/browser/dry-run covered only.

Dynamic workflow v4 focused re-audit:

```bash
codex-flow run .codex-flow/generated/creative-param-ui-v4-focused-reaudit.workflow.ts
```

Journal:

```text
.codex-flow/journal/creative-param-ui-v4-focused-reaudit.jsonl
```

Result:

- `provider-doc-contract-v4`: `pass_with_notes`, `mustFix=[]`.
- `staging-evidence-review-v4`: `pass_with_notes`, `mustFix=[]`.
- `schema-adapter-wire-values-v4`: `fail`, `mustFix=[Duomi dry-run preview did not reuse live 21:9 -> 1792x768 mapping when admin default is 21:9]`.

Follow-up mustFix fix:

- `creativeModelBindingDryRunRequestPreview` now maps Duomi dry-run `size` through `creativeDuomiSizeParam`.
- Added regression test `TestBuildCreativeModelBindingsDryRunMirrorsDuomiLiveSizeMapping`.
- Re-ran local `go test -count=1 ./service`, `go test -count=1 ./middleware`, and release gate; all passed.

Staging v5 dry-run verification:

- Rebuilt and redeployed staging image without wiping volumes.
- Image id: `sha256:0e5e894228334fd5b09d62209049b3a20801e9022e98d7295117510094efc5b2`.
- Container health: `healthy`.
- Ran validate/dry-run only with a temporary Duomi binding draft whose schema default `size` was `21:9`; did not save this draft.
- Validate: HTTP `200`, `success=true`, `valid=true`.
- Dry-run: HTTP `200`, `success=true`, `noProviderCall=true`.
- Duomi preview body: `{"model":"gpt-image-2","prompt":"[REDACTED]","size":"1792x768"}`.

Dynamic workflow v5 mustFix re-audit:

```bash
codex-flow run .codex-flow/generated/creative-param-ui-v5-mustfix-reaudit.workflow.ts
```

Journal:

```text
.codex-flow/journal/creative-param-ui-v5-mustfix-reaudit.jsonl
```

Result:

- `dryrun-live-parity`: `pass_with_notes`, `mustFix=[]`.
- `staging-v5-evidence`: `pass`, `mustFix=[]`.
- Aggregated `mustFix=[]`.

Current conclusion:

- Creative Duomi `gpt-image-2` parameter UI, dry-run, live adapter, and staging provider smoke are aligned for `21:9` and default/auto handling.
- Creative GrsAI normal `gpt-image-2` parameter UI, dry-run, live adapter, and staging provider smoke are aligned for default/auto handling.
- Creative GrsAI VIP remains schema/dry-run/browser verified only; live provider smoke is intentionally not claimed.

## Staging v7 GrsAI complete parameter UI correction

User-reported issue after v6:

- The expected GrsAI GPT Image parameter control is a single model parameter popup containing all three groups: `图片尺寸`, `图片分辨率`, and `质量`.
- GrsAI accepts `quality` even if some public documentation omits it.
- GrsAI `gpt-image-2` supports only `1K` resolution; `gpt-image-2-vip` supports `1K/2K/4K`.

Implementation updates:

- `new-api/service/creative_model_capability.go`
  - `grsai_gpt_image` exposes `aspectRatio`, `imageSize`, `quality`.
  - `grsai_gpt_image` `imageSize` options are `1K` only.
  - `grsai_gpt_image_vip` `imageSize` options are `1K`, `2K`, `4K`.
  - GrsAI `quality` label/shortLabel changed from `画质` to `质量`.
  - Dry-run omits `quality=auto` and sends non-auto `quality`.
- `new-api/service/creative_image_adapter.go`
  - GrsAI live adapter sends non-empty, non-`auto` `quality` in the provider request body.
- `opentu/packages/drawnix/src/constants/model-config.ts`
  - Static GPT Image quality label/shortLabel changed to `质量` for direct managed no-schema fallback consistency.

Local verification:

- `go test -count=1 ./service -run 'TestCreativeAdapterManifestRegistryExposesSafeTemplates|TestBuildCreativeModelBindingsDryRunMirrorsGrsAIGPTImageLiveMapping|TestBuildCreativeModelBindingsDryRunOmitsGrsAIGPTImageAutoAspectRatioLikeLiveAdapter|TestCreativeGrsAIGPTImageMapsUiAspectAndResolutionToPixelAspectRatio'` passed.
- `go test -count=1 ./service` passed.
- `go test -count=1 ./middleware` passed.
- `pnpm --filter @aitu/drawnix exec vitest run src/constants/__tests__/model-config.test.ts` passed: 16 tests.
- `python3 scripts/creative_release_gate.py build-sync-check --opentu /mnt/f/CODE/Project/opentu --new-api /mnt/f/CODE/Project/new-api --run-new-api-tests --source-diff-check`:
  - OpenTU `web:typecheck`, Vite app build, SW build, dist sync, artifact contract, and source diff checks passed.
  - Final broad `go test ./controller` portion failed on existing controller test DB fixture isolation (`no such table: channels` / `database is closed`), so this broad package gate is not claimed green.
- Follow-up focused gate passed:
  - `python3 scripts/creative_release_gate.py check --opentu /mnt/f/CODE/Project/opentu --new-api /mnt/f/CODE/Project/new-api --source-diff-check`.
  - `go test -count=1 ./service ./middleware ./router ./model ./relay ./relay/common ./relay/constant`.

Staging deploy/update:

- Rebuilt local staging image and recreated the staging container without deleting named volumes.
- Image id: `sha256:ba345850d05d1b13bdacf3178f01e5d15cae5d5d2d95ab17c513ad725e80da0c`.
- Container health: `healthy`.
- Refreshed saved Creative Model Bindings from current adapter manifests using admin `validate -> dry-run -> put` with session CSRF/nonce; no provider call was made.
- Refresh results:
  - validate: `success=true`, `valid=true`.
  - dry-run: `success=true`, `noProviderCall=true`.
  - put: `success=true`.

Staging `/creative/api/models` v7 evidence:

- `grsai:gpt-image-2:live-smoke`
  - `aspectRatio` label `图片尺寸`, options `auto`, `1:1`, `2:3`, `3:2`, `3:4`, `4:3`, `4:5`, `5:4`, `9:16`, `16:9`, `21:9`.
  - `imageSize` label `图片分辨率`, options `1K` only.
  - `quality` label `质量`, options `auto`, `low`, `medium`, `high`.
- `grsai:gpt-image-2-vip:live-smoke`
  - `aspectRatio` label `图片尺寸`, options `auto`, `1:1`, `2:3`, `3:2`, `3:4`, `4:3`, `4:5`, `5:4`, `9:16`, `16:9`, `21:9`.
  - `imageSize` label `图片分辨率`, options `1K`, `2K`, `4K`.
  - `quality` label `质量`, options `auto`, `low`, `medium`, `high`.

Browser UI smoke v7:

- Script: `/tmp/newapi-staging-smoke-FvfQLt/ui_param_probe_v7.cjs`.
- Evidence JSON: `/tmp/newapi-staging-smoke-FvfQLt/ui_param_probe_v7.json`.
- Opened logged-in `/creative/`, opened the parameter dropdown for the current GrsAI image model.
- Result:
  - `paramsTriggers=1`.
  - Same popup contained `图片尺寸`, `图片分辨率`, and `质量`.
  - Popup contained `21:9`.
  - Popup did not contain forbidden/extreme options `9:21`, `1:3`, `3:1`, `1:2`, `2:1`.
  - The visible menu text was:
    - `图片尺寸`: `自动`, `1:1`, `2:3`, `3:2`, `3:4`, `4:3`, `4:5`, `5:4`, `9:16`, `16:9`, `21:9`.
    - `图片分辨率`: `1K`, `2K`, `4K` for the selected VIP model.
    - `质量`: `自动`, `快速`, `标准`, `高清`.

Provider smoke status:

- No v7 live GrsAI provider generation was run automatically because it may incur cost.
- Previous v4 staging provider smoke verified GrsAI normal default generation completed with PNG output, but it did not test non-auto `quality`.
- `quality` live-provider acceptance remains to be confirmed by an explicitly authorized GrsAI real-generation smoke, e.g. normal `gpt-image-2` with `userParams={"aspectRatio":"1:1","imageSize":"1K","quality":"low"}`.

## Staging v8/v9 GrsAI parameter contract recheck and fallback closure

Additional user clarification:

- GrsAI `quality` is accepted in live behavior even if some docs omit it.
- GrsAI `gpt-image-2` is constrained to `1K` output.
- GrsAI `gpt-image-2-vip` supports `1K`, `2K`, and `4K`.

Follow-up fix after dynamic workflow v8:

- Dynamic workflow v8 journal: `.codex-flow/journal/creative-grsai-param-v8-reaudit.jsonl`.
- v8 parallel branches found backend/staging/config pass, but flagged one real fallback gap: OpenTU static fallback still grouped `gpt-image-2` and `gpt-image-2-vip` under the same `1k/2k/4k` resolution options.
- Fixed in OpenTU commit `17cea8a4fdd19780545c67ef454c01bbea0b2cb1`:
  - `gpt-image-2` static fallback resolution is now `1k` only.
  - `gpt-image-2-vip` static fallback resolution remains `1k`, `2k`, `4k`.
  - Both retain `quality` label/shortLabel `质量` and options `auto`, `low`, `medium`, `high`.
  - Case-variant fallback such as `Gpt-image-2` is tested to resolve to ordinary `gpt-image-2` and only expose `1k` resolution.

Local verification after the fallback fix:

- `pnpm --filter @aitu/drawnix exec vitest run src/constants/__tests__/model-config.test.ts` passed: 17 tests.
- `python3 scripts/creative_release_gate.py build-sync-check --opentu /mnt/f/CODE/Project/opentu --new-api /mnt/f/CODE/Project/new-api --source-diff-check` passed.
  - Embedded dist provenance now points to OpenTU commit `17cea8a4fdd19780545c67ef454c01bbea0b2cb1`.
- Restored OpenTU source-side generated `apps/web/public/version.json` after build; OpenTU worktree is clean.
- `go test -count=1 ./service ./middleware ./router ./model ./relay ./relay/common ./relay/constant` passed.
- `go test -count=1 ./controller -run 'TestCreativeImageTaskSubmitGrsAILiveForcesAsyncAndBearerAuth'` passed.
- `python3 scripts/creative_release_gate.py check --opentu /mnt/f/CODE/Project/opentu --new-api /mnt/f/CODE/Project/new-api --source-diff-check` passed.

Staging v8 redeploy and smoke:

- Rebuilt local staging image after dist provenance changed and recreated staging container without deleting named volumes.
- Final staging image id: `sha256:83dc469d99ab650508bf7c1c8477aafe63b31db1ca4187ec84d92da9dff23716`.
- Container health: `healthy`.
- Re-ran smoke scripts using renewed admin session; authentication material was not recorded in this report.

Staging v8 API/admin evidence:

- Evidence files:
  - `/tmp/newapi-staging-smoke-FvfQLt/v8_probe_admin_summary.json`
  - `/tmp/newapi-staging-smoke-FvfQLt/v8_validate_dryrun_summary.json`
  - `/tmp/newapi-staging-smoke-FvfQLt/v8_modified_dryrun_summary.json`
  - `/tmp/newapi-staging-smoke-FvfQLt/ui_param_probe_v8.json`
- `/api/creative/adapter-manifests` exposes `grsai_gpt_image` and `grsai_gpt_image_vip` with schema IDs `aspectRatio`, `imageSize`, `quality`.
- `/creative/api/models` exposes both GrsAI live bindings with the same schema IDs.
- Saved binding config validate/dry-run/put all returned HTTP 200 success.
- Default dry-run omits `quality` and `imageSize` when defaults are `auto/1K/auto`.
- Modified non-persisted dry-run with non-auto params proved provider preview behavior:
  - ordinary `gpt-image-2`, `16:9 + 1K + quality=high` -> provider body includes `aspectRatio=1672x941`, `quality=high`, and no `imageSize`.
  - VIP `gpt-image-2-vip`, `16:9 + 4K + quality=high` -> provider body includes `aspectRatio=3840x2160`, `quality=high`, and no `imageSize`.

Staging v8 browser UI evidence:

- Logged-in `/creative/` UI smoke opened the parameter popup.
- Result:
  - `paramsTriggers=1`.
  - Same popup contains `图片尺寸`, `图片分辨率`, and `质量`.
  - `forbiddenVisible=[]` for `9:21`, `1:3`, `3:1`, `1:2`, `2:1`.
  - Visible VIP popup includes `1K`, `2K`, `4K`, and quality labels `自动`, `快速`, `标准`, `高清`.

Dynamic workflow v9 recheck:

- Workflow: `.codex-flow/generated/creative-grsai-param-v9-recheck.workflow.ts`.
- Journal: `.codex-flow/journal/creative-grsai-param-v9-recheck.jsonl`.
- Branch results:
  - `static-fallback`: pass; no path found where ordinary `gpt-image-2` static fallback still shows `2k/4k`.
  - `backend-and-admin-contract`: pass; no must-fix for backend/admin schema or adapter mapping.
  - `staging-and-artifact`: functional evidence pass, but publish gate fail until dirty new-api dist/backend changes and OpenTU provenance commit are committed/pushed or explicitly recorded.

Current conclusion:

- GrsAI parameter contract is locally and staging verified for schema/admin/UI/dry-run paths.
- Real paid provider generation with non-auto GrsAI `quality` is not claimed in this report; run only after explicit cost authorization.
- Before declaring publish-ready, commit the new-api backend/dist changes, commit this validation/spec record, and push/record the OpenTU commit used by embedded dist provenance.
