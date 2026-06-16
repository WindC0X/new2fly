# Research: Duomi / GrsAI image adapter status

- Query: 核实当前 DuomiAPI / GrsAI 的 `gpt-image-2`、`nano banana` 系列适配状态；查 `new-api` Creative model bindings/admin UI/service 和 OpenTU schema-backed image task 路径；回答当前生产里用户在哪里配置、是否已有真实 adapter preset/template、缺哪些代码/配置、短期可用方案。
- Scope: internal
- Date: 2026-06-16

## Findings

### Files found

- `/mnt/f/code/project/new-api/service/creative_model_capability.go` — Creative adapter binding option key、allowed presets/templates、stored catalog filter、resolver、validator、dry-run preview、GrsAI fixture parser。
- `/mnt/f/code/project/new-api/controller/creative_model_bindings.go` — admin-only `GET/PUT/validate/dry-run` binding endpoints。
- `/mnt/f/code/project/new-api/router/api-router.go` — `/api/creative/model-bindings` 路由注册和 nonce/root auth 中间件。
- `/mnt/f/code/project/new-api/controller/option.go` — 阻止通过通用 `/api/option` 写 `creative.model_bindings`。
- `/mnt/f/code/project/new-api/controller/creative.go` — `/creative/api/models` 将 stored bindings 追加到用户模型 catalog。
- `/mnt/f/code/project/new-api/controller/creative_image_tasks.go` — schema-backed Creative image task mock 路径，提交/获取/私有 content DTO。
- `/mnt/f/code/project/new-api/router/web-router.go` — `/creative/relay/v1/images/tasks` 路由和 sync image route gate。
- `/mnt/f/code/project/new-api/dto/pricing.go` — `CreativeModelCatalogItem` / `CreativeParameterSchemaItem` Go DTO。
- `/mnt/f/code/project/new-api/service/creative_model_capability_test.go` — GrsAI dry-run fixture-only tests、Duomi preset blocked tests、no-provider-call/redaction expectations。
- `/mnt/f/code/project/new-api/relay/channel/gemini/constant.go` — Gemini channel source model list includes nano-banana-related names, but this is not Creative adapter binding preset logic。
- `/mnt/f/code/project/opentu/packages/drawnix/src/services/creative-session-broker.ts` — OpenTU consumes new-api catalog fields (`providerModelId`, `priceModelId`, `parameterSchema`) and builds managed profile catalog。
- `/mnt/f/code/project/opentu/packages/drawnix/src/constants/model-config.ts` — TypeScript schema contract, runtime schema normalization, static nano-banana model metadata, and typed `userParams` builder。
- `/mnt/f/code/project/opentu/packages/drawnix/src/services/media-executor/fallback-executor.ts` — schema-backed image requests choose managed image task route before legacy adapters。
- `/mnt/f/code/project/opentu/packages/drawnix/src/services/media-executor/fallback-adapter-routes.ts` — OpenTU POSTs schema-backed requests to `/creative/relay/v1/images/tasks` with `model` and typed `userParams` only。
- `/mnt/f/code/project/opentu/packages/drawnix/src/services/async-image-api-service.ts` — standalone/runtime OpenTU async image path for nano-banana-pro models via provider transport, not the new-api Creative schema-backed adapter binding path。

### Current production/user configuration surface

- Backend-owned binding config key is `creative.model_bindings` (`CreativeModelBindingsOptionKey`) in `new-api` service code (`service/creative_model_capability.go:19-23`).
- Config shape is versioned `CreativeModelBindingsConfig{version, bindings[]}` and each binding owns `id`, `providerModelId`, `priceModelId`, `enabled`, `canaryGroups`, optional `channelId`, `adapterPreset`, `parameterTemplate`, and `parameterSchema` (`service/creative_model_capability.go:91-110`).
- The generic option endpoint explicitly rejects direct writes to `creative.model_bindings` and tells callers to use `/api/creative/model-bindings` (`controller/option.go:147-152`).
- Dedicated admin APIs exist in backend: `GET /api/creative/model-bindings`, `PUT /api/creative/model-bindings`, `POST /api/creative/model-bindings/validate`, `POST /api/creative/model-bindings/dry-run` (`router/api-router.go:201-209`), implemented in `controller/creative_model_bindings.go:11-75`.
- These endpoints require root dashboard auth via `middleware.RootAuth()` and write/validate/dry-run require `middleware.CreativeRequireNonce()` (`router/api-router.go:201-209`); the controller also rejects API-access-token-only requests (`controller/creative_model_bindings.go:77-85`).
- I found no `web/default/src` admin UI section/API client for `model-bindings` / `creative.model_bindings`; current admin UI evidence exists for model policy only. Therefore, from current code, production configuration is via backend admin API (or storage/DB option value managed through that API), not a visible React admin UI panel.

### Existing presets/templates and runtime availability

- Allowed adapter presets are only `mock_image_task` and `grsai_gpt_image_dryrun` (`service/creative_model_capability.go:39-42`). Allowed parameter templates are only `mock_gpt_image` and `grsai_gpt_image` (`service/creative_model_capability.go:44-47`).
- Preset/template pairing is fail-closed: `mock_image_task` may only use `mock_gpt_image`, and `grsai_gpt_image_dryrun` may only use `grsai_gpt_image` (`service/creative_model_capability.go:588-597`).
- Stored catalog exposure is stricter than validation: `/creative/api/models` only returns stored bindings whose preset/template is `mock_image_task` + `mock_gpt_image`; all GrsAI dry-run bindings are filtered out of public catalog (`service/creative_model_capability.go:203-224`).
- Image task resolver is also mock-only: even if a GrsAI dry-run binding is stored, submit rejects it because `ResolveCreativeImageModelBindingForGroup` requires `mock_image_task` + `mock_gpt_image` (`service/creative_model_capability.go:294-337`, especially `316-318`).
- The mock built-in preview binding is `mock:gpt-image-2:preview` with upstream/provider model `gpt-image-2`, price model `mock-gpt-image-2-price`, and schema fields like `size`/`quality` (`service/creative_model_capability.go:1280-1325`).
- GrsAI currently has fixture/dry-run shape only: dry-run preview marks `transport: fixture`, `adapterFamily: grsai`, `offline: true`, sends preview `model`, `prompt`, `images`, `aspectRatio`, `replyType`, and redacts response URLs (`service/creative_model_capability.go:544-568`).
- GrsAI fixture parser only validates local response shape/status/result count and deliberately does not expose provider result URLs (`service/creative_model_capability.go:599-635`). Tests call this “fixture without provider material” and assert no `http://`, `https://`, auth, bearer, or baseURL appears in dry-run output (`service/creative_model_capability_test.go:882-904`).
- Duomi is explicitly not an allowed preset. Tests assert a `duomi_gpt_image` preset is blocked (`service/creative_model_capability_test.go:572-574`), and mutation tests expect `duomi_live_call` as an unknown preset (`service/creative_model_capability_test.go:681-685`).
- Source-only grep found no Duomi adapter implementation in service/controller/relay code beyond tests and fake-secret names. Source-only grep found GrsAI only in dry-run/fixture service + tests. No real GrsAI transport/client/poller was found.

### OpenTU schema-backed path state

- new-api catalog DTO carries `providerModelId`, `priceModelId`, and `parameterSchema` (`dto/pricing.go:14-33`); schema items support `enum|string|number|integer|boolean`, typed defaults/options, min/max/step, required/order/hidden (`dto/pricing.go:36-55`).
- OpenTU mirrors this schema contract as `CreativeParameterSchemaItem` and `CreativeUserParams` (`model-config.ts:80-115`) and marks runtime schema params in `ParamConfig` (`model-config.ts:149-156`).
- `creative-session-broker.ts` reads server fields `providerModelId`, `priceModelId`, and `parameterSchema` from `/creative/api/models`, preserves exact catalog `id` as model id, builds `selectionKey = new-api-creative::<id>`, and stores `parameterSchema` on the managed model (`creative-session-broker.ts:253-334`).
- Runtime schema normalization drops hidden fields and unsafe ids, orders fields, converts enum/boolean UI options to strings while preserving original runtime values for submit (`model-config.ts:2711-2778`).
- `buildCreativeUserParams` casts selected UI strings back to typed string/number/integer/boolean/enum values and emits only schema ids (`model-config.ts:2791-2851`).
- For schema-backed models, OpenTU bypasses legacy image adapter params and calls the managed image task route: `fallback-executor.ts` checks `isCreativeManagedImageTask`, `hasCreativeUserParams`, or `hasRuntimeParameterSchema(modelName)` and then calls `executeCreativeManagedImageTask` (`fallback-executor.ts:229-246`).
- `executeCreativeManagedImageTask` POSTs to `/creative/relay/v1/images/tasks` with JSON body `{ model, prompt, userParams }`, same-origin credentials, Creative auth headers, and an idempotency key (`fallback-adapter-routes.ts:208-256`).
- Generic/legacy generation API path rejects schema-backed Creative image requests and tells callers they must use the managed image task route (`generation-api-service.ts:443-450`).

### Image task backend path state

- new-api registers `/creative/relay/v1/images/tasks` POST/GET/content under relay middleware with session bridge, user auth, same-origin, nonce, and forbidden relay field guards (`router/web-router.go:90-114`).
- Submit request body supports `model`, `prompt`, `images`, and `userParams`; reference images are currently rejected (`controller/creative_image_tasks.go:30-35`, `124-132`).
- Submit resolves the binding, stores metadata with binding/provider/price/preset/template/userParams, creates a terminal mock success task, and stores a private mock URL in `PrivateData.ResultURL` (`controller/creative_image_tasks.go:132-183`).
- Billing context uses `resolved.PriceModelId`, while task properties preserve binding as origin and provider model as upstream (`controller/creative_image_tasks.go:167-180`).
- Public DTO returns only route-specific fields and rewrites success result to `/creative/relay/v1/images/tasks/:task_id/content`; content endpoint serves mock PNG with private no-store headers (`controller/creative_image_tasks.go:340-379`).
- Sync `/creative/relay/v1/images/generations` rejects managed image binding IDs before provider relay and instructs using task route (`controller/creative_image_tasks.go:91-110`, `router/web-router.go:106-108`).

### Nano Banana status

- In `new-api`, Gemini channel model list includes `gemini-3-pro-image-preview`, `nano-banana-pro-preview`, and `gemini-3.1-flash-image-preview` (`relay/channel/gemini/constant.go:12-18`). This is normal channel/model support, not a Creative adapter binding preset/template.
- In OpenTU static metadata, nano-banana family aliases are present for Gemini image models such as `gemini-3-pro-image-preview-vip (nano-banana-pro-vip)`, 2K/4K variants, `gemini-2.5-flash-image-vip (nano-banana-vip)`, and `gemini-3.1-flash-image-preview (nano-banana-2)` (`model-config.ts:366-455`).
- OpenTU also has a standalone async image service documented for nano-banana-pro models that posts to provider `/videos` and polls `/videos/:id` via `providerTransport`, requiring a provider API key (`async-image-api-service.ts:1-6`, `138-219`). This is not the backend-owned schema-backed Creative adapter path and would violate the “OpenTU has no provider credentials/protocol logic” goal if used for embedded managed bindings.
- No `nano_banana` Creative adapter preset/template was found in `new-api/service/creative_model_capability.go`; nano-banana can only be exposed to embedded OpenTU today through ordinary channel catalog/static metadata or by adding a mock binding using existing `mock_image_task` semantics, not a real backend adapter.

### What is missing for real Duomi/GrsAI adapter support

For real provider-capable `gpt-image-2` / nano-banana-style bindings, missing pieces are:

1. **Allowlisted real preset/template definitions** — add explicit preset names for each supported provider operation and template names for provider-safe user parameters. Today allowed presets/templates are only mock + GrsAI dry-run (`service/creative_model_capability.go:39-47`, `588-597`).
2. **Public catalog/runtime resolver enablement** — extend `GetStoredCreativeModelBindingsCatalogForGroup` and `ResolveCreativeImageModelBindingForGroup` beyond `mock_image_task` + `mock_gpt_image` only, but keep provider presets gated by global flag, canary, channel support, and real-call authorization (`service/creative_model_capability.go:203-224`, `294-337`).
3. **Backend provider transport adapter** — implement provider request builder, submit, poll/fetch, response parser, retry/idempotency behavior, and error mapping for Duomi/GrsAI without exposing URL/header/key control to OpenTU. No such transport exists currently for either provider.
4. **Channel/key integration** — choose how preset locks to `channelId` or provider-model channel selection; validator already can check channel existence/status/model support (`service/creative_model_capability.go:874-887`), but runtime submit path currently forces mock channel `0` and never calls channel broker/provider relay (`controller/creative_image_tasks.go:154-181`).
5. **Async task lifecycle** — replace terminal mock success with accepted/running/polling/CAS/outbox/refund semantics for real providers; current C1 image route is local terminal mock only (`controller/creative_image_tasks.go:154-198`).
6. **URL privatization / asset sync** — real provider result URLs must be downloaded/proxied/stored and exposed only through owner-scoped private content/asset endpoints; current mock content endpoint always serves a local 1x1 PNG (`controller/creative_image_tasks.go:241-259`, `340-379`).
7. **Fixture coverage and no-provider-call gates** — add captured local fixtures for each provider status/result/error shape. GrsAI has dry-run request/response shape tests; Duomi has none and is explicitly blocked (`service/creative_model_capability_test.go:416-443`, `469-495`, `572-578`, `882-927`).
8. **Admin UI if desired** — backend APIs exist, but no React admin section/client for model bindings was found. A usable production admin experience would need a UI that calls `/api/creative/model-bindings`, `/validate`, and `/dry-run` instead of `/api/option`.

### Short-term usable paths

- **Safest available path:** use `mock_image_task` bindings with `mock_gpt_image` parameter schemas for OpenTU runtime UI/payload validation and full `/creative/relay/v1/images/tasks` mock chain. This exercises model binding IDs, typed `userParams`, idempotency, route boundaries, private DTO/content, and price/provider metadata without provider calls.
- **GrsAI admin-only shape check:** use disabled `grsai_gpt_image_dryrun` + `grsai_gpt_image` configs only through `POST /api/creative/model-bindings/validate` and `/dry-run`; it can preview sanitized request shape and parse local fixture shape, but it is not public-catalog selectable and not executable through image task submit.
- **Nano Banana today:** static/OpenTU standalone and normal new-api Gemini channel model entries exist, but they are not backend-owned Creative adapter presets. For embedded schema-backed Creative, expose only through mock bindings until a real backend preset/fixture/poller is implemented.
- **Do not use Duomi live:** current code intentionally blocks Duomi presets; enabling it requires new code and fixtures, not just config.

## Code patterns

- **Fail-closed binding config:** raw JSON key validation rejects unsupported or forbidden fields before unmarshal (`service/creative_model_capability.go:637-705`), then semantic validation checks id collision, preset/template allowlists, channel, group, and schema (`service/creative_model_capability.go:811-905`).
- **Mock-only public/runtime path:** stored catalog and image task resolver both enforce `mock_image_task` + `mock_gpt_image` (`service/creative_model_capability.go:217-219`, `316-318`).
- **GrsAI fixture-only path:** `creativeModelBindingDryRunRequestPreview` recognizes `grsai_gpt_image_dryrun` + `grsai_gpt_image` and returns `transport=fixture`, `offline=true`, and redacted response shape (`service/creative_model_capability.go:544-568`).
- **OpenTU exact binding id contract:** OpenTU preserves server `id` as the model sent to backend and stores `providerModelId` separately (`creative-session-broker.ts:288-334`).
- **OpenTU typed params boundary:** runtime schema values are cast into `CreativeUserParams` only, and legacy adapter fields are removed for schema-backed requests (`model-config.ts:2791-2851`; `fallback-adapter-routes.ts:399-432`).
- **Private task DTO/content pattern:** backend stores raw mock provider URL privately but returns only owner-scoped content URL (`controller/creative_image_tasks.go:172-180`, `340-379`).

## External references

- No external provider documentation was fetched or relied on in this research. The status above is based on current local source and Trellis specs only. Real Duomi/GrsAI call compatibility remains unverified until local captured fixtures and authorized provider docs/evidence are added.

## Related specs

- `.trellis/spec/backend/creative-backend-security-boundary.md` — requires dedicated `creative.model_bindings` admin endpoint, no generic option writes, no provider/channel/baseURL/key leakage, and dry-run redaction.
- `.trellis/spec/backend/creative-async-task-billing-consistency.md` — real async provider work must preserve idempotency, selected-key affinity, billing/outbox/refund, and CAS semantics.
- `.trellis/spec/backend/creative-asset-sync.md` — real result URLs need private/proxied/asset-safe exposure before browser access.
- `.trellis/spec/frontend/creative-embedded-release-artifact.md` — embedded OpenTU must use managed new-api catalog and fail closed instead of static/provider fallbacks.
- `.trellis/spec/frontend/type-safety.md` — security-sensitive tests must keep no-secret/no-provider-leak assertions meaningful.
- Task docs: `.trellis/tasks/06-16-creative-adapter-capability-registry/prd.md`, `design.md`, `implement.md` — current plan explicitly keeps Phase C2+ real provider canary blocked until authorization and fixture evidence.

## Caveats / Not Found

- No production database/options were read and no production endpoint/provider endpoint was contacted; “current production configuration surface” means what the deployed code exposes, not the value currently stored in a live DB.
- I did not find a new-api React/admin UI for `creative.model_bindings`; if an out-of-tree/private dashboard exists, it was outside the searched source paths.
- No real Duomi adapter preset/template/transport/parser/poller was found; Duomi appears only in negative/block tests and fake-secret corpus.
- No real GrsAI adapter transport/poller was found; GrsAI is dry-run/fixture-only and not selectable/executable from public OpenTU catalog under the current resolver.
- No nano-banana Creative adapter preset/template was found; nano-banana appears as Gemini/static model metadata and standalone OpenTU async-image handling, not as the new schema-backed backend-owned adapter binding path.
