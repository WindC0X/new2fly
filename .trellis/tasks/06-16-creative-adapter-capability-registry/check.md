# Check — Creative Adapter Capability Registry

Date: 2026-06-16

## Planning / codex-flow

- `codex-flow run .codex-flow/generated/creative-adapter-capability-v3-short-audit.workflow.ts`
  - Result: found planning Critical/High; artifacts revised.
- `codex-flow run .codex-flow/generated/creative-adapter-capability-v31-gate-audit.workflow.ts`
  - Result: one remaining High for sync URL privacy gate; implement plan revised.
- `codex-flow run .codex-flow/generated/creative-adapter-capability-v312-sync-gate.workflow.ts`
  - Result: PASS, no Critical/High remaining for Phase A/B/C1 planning gate.

## Phase A partial implementation verification

new-api:

```bash
cd /mnt/f/code/project/new-api
go test -count=1 ./controller ./dto
go build ./...
```

Result: PASS.

OpenTU:

```bash
cd /mnt/f/code/project/opentu
pnpm vitest run packages/drawnix/src/constants/__tests__/model-config.test.ts packages/drawnix/src/services/creative-session-broker.test.ts
pnpm typecheck
```

Result: PASS. `.npmrc` warnings for missing `${NPM_TOKEN}` were present but did not affect tests/typecheck.

## Implemented in this slice

- new-api `CreativeModelCatalogItem` now carries `providerModelId`, `priceModelId`, `displayName`, sorting/recommendation placeholders, and `parameterSchema` DTO types.
- Legacy catalog items populate `providerModelId` and `priceModelId` with the existing logical model id, preserving current behavior.
- OpenTU defines matching runtime parameter schema types and converts runtime schema into `ParamConfig`.
- OpenTU preserves `providerModelId`, `priceModelId`, `recommendedScore`, `sortOrder`, and `parameterSchema` from new-api managed catalog responses.
- `getCompatibleParams` now returns runtime schema params before static params when given a runtime model/config.
- Parameter dropdown can render boolean runtime schema params using option-style controls.

## Not yet complete

- No mock binding/template service yet.
- No typed end-to-end `userParams` carrier yet.
- No admin validator/dry-run or image task route yet.
- No provider calls were made.

## Phase A slice codex-flow review

- `codex-flow run .codex-flow/generated/creative-adapter-phase-a-slice-audit.workflow.ts`
  - Result: found two OpenTU High issues: unsafe runtime schema param ids and missing providerModelId static fallback.
- `codex-flow run .codex-flow/generated/creative-adapter-phase-a-slice-reaudit.workflow.ts`
  - Result: providerModelId fallback fixed; unsafe-id denylist still incomplete.
- `codex-flow run .codex-flow/generated/creative-adapter-phase-a-slice-reaudit2.workflow.ts`
  - Result: unsafe-id denylist fixed; found `priceModelId` should not drive frontend params.
- `codex-flow run .codex-flow/generated/creative-adapter-phase-a-slice-final-audit.workflow.ts`
  - Result: PASS, no material Critical/High remaining in targeted static audit.

## Phase A slice final verification

new-api:

```bash
cd /mnt/f/code/project/new-api
go test -count=1 ./controller ./dto
go build ./...
```

Result: PASS.

OpenTU:

```bash
cd /mnt/f/code/project/opentu
pnpm vitest run packages/drawnix/src/constants/__tests__/model-config.test.ts packages/drawnix/src/services/creative-session-broker.test.ts
pnpm typecheck
```

Result: PASS; targeted Vitest now covers 24 tests across the two files. `.npmrc` warnings for missing `${NPM_TOKEN}` remain non-blocking.

## Phase A slice fixes after codex-flow

- Runtime schema parameter IDs are locally filtered against a broader forbidden/control-field matrix before they become `ParamConfig` IDs.
- Static parameter fallback uses `providerModelId`, not `priceModelId`.
- Added negative tests for dangerous schema IDs and for `priceModelId` not influencing frontend parameter fallback.


## Phase A mock preview binding verification

new-api:

```bash
cd /mnt/f/code/project/new-api
go test -count=1 ./service -run 'TestCreativePreview|TestValidateCreativeParameterSchema'
go test -count=1 ./controller -run 'TestCreativeListModels'
go test -count=1 ./controller ./dto ./service
go build ./...
git diff --check
```

Result: PASS.

Dynamic workflow attempt:

```bash
cd /mnt/f/code/project/new2fly
codex-flow run .codex-flow/generated/creative-adapter-phase-a-mock-binding-targeted-reaudit.workflow.ts
```

Result: unavailable in this runtime. All three read-only reviewer nodes failed with `access_denied: Only Codex clients can use this group`; journal path: `.codex-flow/journal/creative-adapter-phase-a-mock-binding-targeted-reaudit.jsonl`. No code/provider action was performed by the failed workflow.

Manual targeted reaudit after the workflow failure:

- Scope is limited to `controller/creative.go`, `controller/creative_test.go`, `service/creative_model_capability.go`, and `service/creative_model_capability_test.go`. Relay/provider/channel/pricing/task/billing files are unchanged.
- Preview binding is fail-closed unless `creative.adapter.enabled=true` and `creative.adapter.canary_groups` contains the user's group (or `*`).
- The preview item is catalog/schema-only and uses intentionally distinct IDs: `id=mock:gpt-image-2:preview`, `providerModelId=gpt-image-2`, `priceModelId=mock-gpt-image-2-price`.
- Schema validation rejects unsafe/control ids, duplicate ids, unknown types, enum without options, non-scalar default/option values, enum default not present by strict kind/value comparison, non-finite numbers, and non-enum default/type mismatches.
- No Duomi/GrsAI/provider call path is added or enabled.

Implemented in this slice:

- Added `service.GetCreativePreviewModelBindingsForGroup` behind disabled global flag plus canary group gate.
- Added `service.ValidateCreativeParameterSchema` and tests for forbidden keys, typed defaults/options, scalar-only values, and strict enum default matching.
- Appended the preview binding to `/creative/api/models` only after regular user model catalog construction.
- Added controller tests proving absent-by-default behavior, canary miss behavior, and canary hit catalog JSON preserving binding/provider/price separation.

Still not complete:

- OpenTU typed end-to-end `userParams` carrier and schema-backed request serialization isolation remain pending.
- Phase B admin validator/dry-run remains pending.
- Phase C1 mock image task route remains pending.
- Real provider calls remain blocked.


## Phase A OpenTU typed userParams verification

OpenTU:

```bash
cd /mnt/f/code/project/opentu
pnpm vitest run \
  packages/drawnix/src/constants/__tests__/model-config.test.ts \
  packages/drawnix/src/components/ai-input-bar/__tests__/workflow-converter.test.ts \
  packages/drawnix/src/services/__tests__/image-generation-service.test.ts \
  packages/drawnix/src/services/__tests__/media-executor.test.ts
pnpm typecheck
git diff --check
```

Result: PASS. Targeted Vitest covered 77 tests across 4 files; typecheck covered 5 Nx projects. `.npmrc` `${NPM_TOKEN}` warnings and existing jsdom/IndexedDB/crypto stderr noise were non-blocking.

Dynamic workflow attempt:

```bash
cd /mnt/f/code/project/new2fly
codex-flow run .codex-flow/generated/creative-adapter-phase-a-opentu-userparams-audit.workflow.ts
```

Result: incomplete/unavailable for final reviewer output because the workflow ended with `unexpected status 403 Forbidden: 用户额度不足, 剩余额度: ¥-0.012528`; journal path: `.codex-flow/journal/creative-adapter-phase-a-opentu-userparams-audit.jsonl`. No provider calls were made by the workflow. Partial journal review still exposed a material risk: schema-backed `userParams` could be ignored by existing GPT/OpenAI-style adapters and fall through to a real provider route with `model=bindingId`. The implementation now fail-closes this by requiring `adapter.supportsCreativeUserParams === true` before any schema-backed adapter `generateImage` call. No production/default adapter currently sets that flag.

Manual targeted reaudit after workflow failure:

- Runtime schema-backed models are detected via `parameterSchema.runtimeSchema`; static model params remain unchanged for non-schema models.
- `buildCreativeUserParams()` collects only schema IDs produced by `normalizeCreativeParameterSchema`; forbidden/control IDs such as URL/baseUrl/endpoint/header/provider/channel/modelRef/sourceProfileId/idempotencyKey/onProgress/onSubmitted/callback/webhook/notifyHook are dropped before they can become selectable or submitted user params.
- Parser/workflow conversion carries typed `userParams` for schema-backed image requests and does not emit legacy `extraParams`, `params`, `size`, or duration/aspect rewrites for those models.
- Image task persistence and executor params strip legacy `params`, `size`, `resolution`, `quality`, `inputFidelity`, `background`, `outputFormat`, `outputCompression`, and `count` whenever `userParams` is present.
- `executeImageViaAdapter` strips legacy adapter fields for schema-backed requests and fail-fast rejects adapters that do not explicitly support `supportsCreativeUserParams`, before reference-image processing or adapter/provider calls.
- No real Duomi/GrsAI/GPT/OpenAI/Gemini/Flux/MJ adapter is marked `supportsCreativeUserParams`; Phase A remains contract/schema/request-boundary only.

Implemented in this slice:

- Added `CreativeUserParams` / typed runtime value helpers and schema-backed param casting for enum/string/number/integer/boolean.
- Added typed `userParams` through `ParsedGenerationParams`, workflow args, workflow submission fallback, workflow engine, image generation options, executor params, and adapter request types.
- Added tests for typed casts, dangerous schema ID filtering, workflow serialization without legacy `params/size`, image generation persistence/executor stripping, successful managed adapter `userParams`, and unsupported adapter fail-fast before provider invocation.

Still not complete:

- OpenTU preference isolation tests for two bindings sharing one provider model remain pending.
- Phase B admin validator/dry-run remains pending.
- Phase C1 mock image task route remains pending.
- Real provider calls remain blocked.


## Phase A OpenTU binding preference isolation verification

Finding fixed in this slice:

- `loadScopedAIImageToolPreferences()` could fall back to global `stored.extraParams` when schema-backed binding B had no scoped preference entry. If binding A and binding B share the same `providerModelId` and compatible parameter IDs, B could inherit A's values instead of B schema defaults.

Implemented fix:

- Runtime schema-backed bindings now avoid cross-binding fallback in `loadScopedAIInputModelParams()` when no exact scoped params exist, letting the caller rebuild defaults from the selected binding schema.
- Runtime schema-backed image tool preferences now avoid global `stored.extraParams` / aspect-ratio fallback when no exact scoped entry or AI-input scoped params exist. Non-schema standalone behavior remains unchanged.
- Added regression coverage using `mock:gpt-image-2:fast` and `mock:gpt-image-2:quality`, both with `providerModelId=gpt-image-2` but distinct binding ids/default schemas.

OpenTU verification after preference isolation fix:

```bash
cd /mnt/f/code/project/opentu
pnpm vitest run \
  packages/drawnix/src/constants/__tests__/model-config.test.ts \
  packages/drawnix/src/services/__tests__/ai-generation-preferences-service.test.ts \
  packages/drawnix/src/components/ai-input-bar/__tests__/workflow-converter.test.ts \
  packages/drawnix/src/services/__tests__/image-generation-service.test.ts \
  packages/drawnix/src/services/__tests__/media-executor.test.ts
pnpm typecheck
git diff --check
```

Result: PASS. Targeted Vitest covered 89 tests across 5 files; typecheck covered 5 Nx projects. Existing `.npmrc`, jsdom crypto/IndexedDB, ConfigWriter, and Browserslist warnings/noise were non-blocking.

Phase A status:

- Phase A checklist items 1-11 are now complete.
- No provider calls were made.
- Phase B admin validator/dry-run remains the next planned phase.


## Phase B new-api binding config parser / generic option block verification

Implemented in new-api commit `37477ef feat(creative): add model binding config parser`:

- Added `service.CreativeModelBindingsOptionKey == "creative.model_bindings"`.
- Added versioned `CreativeModelBindingsConfig` / `CreativeModelBindingConfig` parser for v1 JSON using `common.UnmarshalJsonStr`.
- Added shared `NormalizeCreativeForbiddenKey()` and `CreativeForbiddenKey()` normalizer; existing parameter schema validation now uses it.
- Parser currently validates version, duplicate binding ids, safe binding ids, required `providerModelId` / `priceModelId` / `modality`, and nested `parameterSchema`.
- Generic `PUT /api/option/` now rejects direct writes to `creative.model_bindings`; future writes must go through dedicated `/api/creative/model-bindings` validator/dry-run endpoints.

Verification:

```bash
cd /mnt/f/code/project/new-api
go test -count=1 ./service -run 'TestCreativeForbiddenKey|TestParseCreativeModelBindingsConfig|TestValidateCreativeParameterSchema|TestCreativePreview'
go test -count=1 ./controller -run 'TestUpdateOptionRejectsCreativeModelBindingsGenericWrite'
go test -count=1 ./controller ./service
go build ./...
git diff --check
```

Result: PASS. No provider calls were added or made.

## Phase B new-api admin validate/dry-run endpoints verification

Implemented in new-api commit `69853ed feat(creative): add model binding admin validation`:

- Added dedicated root-admin `/api/creative/model-bindings` endpoints for GET/PUT/validate/dry-run.
- Unsafe admin operations are wired behind `CreativeRequireNonce()` in the real API router; the real route requires root dashboard session, and handlers additionally reject API-token-only access when that flag is present.
- Added normalized config persistence through `service.UpdateStoredCreativeModelBindingsConfig`; persisted JSON trims/canonicalizes binding/schema fields; generic `/api/option` remains blocked for `creative.model_bindings`.
- Added mock-only dry-run request preview with `noProviderCall=true`; no Duomi/GrsAI/provider transport was added.
- Extended validator to reject unsupported modality, unknown adapter preset/template, non-positive channel id, forbidden/empty canary groups, duplicate IDs, forbidden IDs, unknown/forbidden raw admin JSON keys, sensitive provider/price model values, null shape drift, and invalid parameter schema.
- Added sanitized PUT audit log containing only user id and binding count, not binding/provider IDs or payload secrets. Dry-run redaction now covers dangerous keys and sensitive string values such as provider URLs, signed URL markers, bearer/sk-like material, data URLs/base64-like material, credentials, access-key markers, and token markers.

Verification:

```bash
cd /mnt/f/code/project/new-api
go test -count=1 ./controller -run 'TestCreativeModelBindings|TestUpdateOptionRejectsCreativeModelBindingsGenericWrite'
go test -count=1 ./service -run 'TestCreativeForbiddenKey|TestParseCreativeModelBindingsConfig|TestValidateCreativeParameterSchema|TestCreativePreview|TestValidateCreativeModelBindingsConfig|TestBuildCreativeModelBindingsDryRun'
go test -count=1 ./controller ./service
go build ./...
git diff --check
```

Result: PASS. No provider calls were added or made.

Coverage notes / remaining Phase B work:

- Mock dry-run preview is implemented; GrsAI fixture-backed dry-run remains intentionally blocked until local fixture evidence exists.
- Admin security coverage now covers non-root denied, API-token flag denied, missing/bad nonce on validate/dry-run/PUT routes, generic option write blocked, and sanitized PUT audit.
- Validator coverage is partial: duplicate id, unknown preset/template, wrong modality, invalid channel id, forbidden canary/schema ids, forbidden raw admin keys, sensitive provider/price/schema/default/option values, null-shape rejection, Duomi/GrsAI live preset blocking, and raw option bypass are covered. Disabled-channel lookup and hidden user-submitted-field resolver handling are pending future resolver work.

Dynamic workflow review for this slice:

```bash
cd /mnt/f/code/project/new2fly
codex-flow run .codex-flow/generated/creative-adapter-phase-b-admin-validation-audit.workflow.ts
codex-flow run .codex-flow/generated/creative-adapter-phase-b-admin-validation-reaudit.workflow.ts
```

Results:

- First workflow found two Phase-B High issues: config persistence validated but did not canonicalize stored values, and raw JSON unknown/forbidden admin keys could be silently dropped by struct unmarshal. Both were fixed by raw-key validation plus canonical normalization before response/persist/dry-run.
- Re-audit found one remaining High: dry-run redaction was key-only and could echo sensitive string values through `requestPreview.model`. Fixed by sensitive-value validation for provider/price model ids and value-level dry-run redaction.
- Re-audit also reported a pre-existing Medium in the shared Creative nonce same-origin helper: raw forwarded proto headers are still trusted in `middleware/creative.go`; this is outside the current model-bindings slice and remains tracked as the broader XFF/trusted-proxy hardening item.
- Journal paths:
  - `.codex-flow/journal/creative-adapter-phase-b-admin-validation-audit.jsonl`
  - `.codex-flow/journal/creative-adapter-phase-b-admin-validation-reaudit.jsonl`


## Phase B fake-secret / blocked-provider hardening update

Implemented in amended new-api commit `69853ed feat(creative): add model binding admin validation`:

- Added a fake-secret corpus test covering bearer/sk-like material, provider URLs, signed URL markers, data URL/base64-like material, credential/access-key markers, and token markers.
- Validator/admin-state paths now reject sensitive `providerModelId`, `priceModelId`, schema default values, enum option values/labels, display text, and canary group values before diagnostics can echo raw secrets.
- Dry-run redaction now redacts dangerous keys and sensitive string values, including slices of string values.
- Duomi/GrsAI live presets/templates remain blocked by allowlists; no fixture-backed provider transport was added. Added a static AST regression gate proving `BuildCreativeModelBindingsDryRun` does not reference HTTP/client/channel/key/baseURL or Duomi/GrsAI/provider endpoint literals.

Verification rerun:

```bash
cd /mnt/f/code/project/new-api
go test -count=1 ./service -run 'TestCreativeForbiddenKey|TestParseCreativeModelBindingsConfig|TestCreativeModelBindingsRejectFakeSecretCorpus|TestNormalizeCreativeModelBindingsConfig|TestValidateCreativeParameterSchema|TestCreativePreview|TestValidateCreativeModelBindingsConfig|TestBuildCreativeModelBindingsDryRun'
go test -count=1 ./controller -run 'TestCreativeModelBindings|TestUpdateOptionRejectsCreativeModelBindingsGenericWrite'
go test -count=1 ./controller ./service
go build ./...
git diff --check
```

Result: PASS. No provider calls were added or made.

Dynamic workflow follow-up attempt:

```bash
cd /mnt/f/code/project/new2fly
codex-flow run .codex-flow/generated/creative-adapter-phase-b-hardening-reaudit.workflow.ts
```

Result: unavailable due quota precharge failure; both read-only reviewer nodes failed before analysis with `403 Forbidden: 预扣费额度失败`. Journal path: `.codex-flow/journal/creative-adapter-phase-b-hardening-reaudit.jsonl`. Main-thread static review plus the verification commands above were used as fallback.

## Phase C1 mock image task slice verification

Implemented in new-api working tree after commit `69853ed`:

- Added `TaskPlatformCreativeImage` and a browser-session image task route set:
  - `POST /creative/relay/v1/images/tasks`
  - `GET /creative/relay/v1/images/tasks/:task_id`
  - `GET /creative/relay/v1/images/tasks/:task_id/content`
- Added `ResolveCreativeImageModelBindingForGroup()` for mock-only image bindings. It fail-closes unless `creative.adapter.enabled=true`, the binding exists and is enabled, modality is `image`, preset/template are `mock_image_task`/`mock_gpt_image`, the user group matches the binding canary list, and typed `userParams` pass schema validation.
- Added route-specific image task DTO and content proxy contract. The internal mock result URL (`<private mock URL with signed-query marker>`) stays in private task data and the public DTO returns only `/creative/relay/v1/images/tasks/:task_id/content`.
- Added a sync image route gate so managed image binding IDs are rejected before `CreativeRelaySessionBroker()` / `Distribute()` / provider relay.
- Added tests for submit/fetch/replay privacy, route boundary failures, sync-route rejection, owner/platform-scoped fetch, API-token-only handler rejection, accepted+insert-failure idempotency guard retention, typed `userParams`, hidden/forbidden field rejection, and mock/group-scoped binding resolution.

Verification commands run from `/mnt/f/code/project/new-api`:

```bash
gofmt -w constant/task.go service/creative_model_capability.go service/creative_model_capability_test.go controller/creative_image_tasks.go controller/creative_test.go router/web-router.go

go test -count=1 ./controller -run 'TestCreativeImageTask|TestCreativeImageSyncRoute|TestCreativeRelaySessionBroker|TestCreativeModelBindings|TestUpdateOptionRejectsCreativeModelBindingsGenericWrite'

go test -count=1 ./service -run 'TestCreativeForbiddenKey|TestParseCreativeModelBindingsConfig|TestCreativeModelBindingsRejectFakeSecretCorpus|TestNormalizeCreativeModelBindingsConfig|TestValidateCreativeParameterSchema|TestValidateCreativeUserParamsForSchema|TestResolveCreativeImageModelBinding|TestCreativePreview|TestValidateCreativeModelBindingsConfig|TestBuildCreativeModelBindingsDryRun'

go test -count=1 ./controller ./service

go build ./...

git diff --check
```

Result: PASS. The targeted controller/service tests, full controller+service test run, full Go build, and whitespace check all exited 0.

Dynamic workflow validation attempt:

```bash
cd /mnt/f/code/project/new2fly
codex-flow run .codex-flow/generated/creative-adapter-phase-c1-mock-image-task-audit.workflow.ts
```

Result: unavailable in this runtime. All three read-only reviewer nodes failed with `access_denied: Only Codex clients can use this group`; journal path: `.codex-flow/journal/creative-adapter-phase-c1-mock-image-task-audit.jsonl`. No code/provider action was performed by the failed workflow.

Manual targeted review after workflow failure:

- `router/web-router.go` wires image task routes without `CreativeRelaySessionBroker()` or `Distribute()`, while `/images/generations` calls `CreativeRejectManagedImageBindingSyncRoute()` before broker/distribute.
- `controller/creative_image_tasks.go` performs local mock task creation only; no provider/channel HTTP transport is reachable from submit/fetch/content.
- Idempotency uses scoped `CreativeVideoIdempotency` with `scope=image.task.submit`; replay with same hash returns the existing task, conflicting hash returns 409, and accepted+insert failure keeps the guard instead of deleting it.
- Public DTO/fetch/content are owner-scoped and platform-scoped, and do not serialize generic task internals (`user_id`, `channel_id`/`channelId`, `quota`, `private_data`) or internal mock URL/signed-query material.
- This slice remains intentionally partial for real billing/outbox/CAS/refund, real provider/channel selection, full query/form/multipart forbidden matrix, full fake-secret logs/metrics/build corpus, and a stronger AST/panic no-provider-host gate.

## Phase C1 route-boundary / no-provider hardening verification

Additional hardening added after `1fbfcde`:

- `TestCreativeImageTaskRejectsBoundaryAliasesBeforeMockInsert` now covers no-session, bad nonce, forbidden header, forbidden query, forbidden multipart form field, and forbidden multipart file-part name for `/creative/relay/v1/images/tasks`; forbidden alias cases assert `creativeImageTaskInsert` is never reached.
- `TestCreativeImageTaskSourceHasNoProviderTransportReferences` acts as a source gate for the C1 controller and rejects broker/distribute/provider transport/channel key/baseURL references.

Verification commands run from `/mnt/f/code/project/new-api`:

```bash
gofmt -w controller/creative_test.go

go test -count=1 ./controller -run 'TestCreativeImageTask|TestCreativeImageSyncRoute|TestCreativeRelaySessionBroker|TestCreativeModelBindings|TestUpdateOptionRejectsCreativeModelBindingsGenericWrite'

go test -count=1 ./controller ./service

go build ./...

git diff --check
```

Result: PASS. Targeted controller tests, full controller+service tests, full Go build, and whitespace check exited 0.

## Phase C1 idempotency / recovery hardening verification

Additional hardening added after `295404c`:

- Added controller test hooks for image task idempotency completion and accepted-task finalization.
- `TestCreativeImageTaskAcceptedInsertFailureKeepsIdempotencyGuard` now also replays the failed request and proves the pending idempotency record prevents a second mock insert.
- `TestCreativeImageTaskAcceptedFinalizeFailuresReplayExistingTask` covers:
  - accepted task inserted, idempotency completion fails -> first response fails closed, retry returns the persisted task;
  - accepted task inserted, finalization/settle-equivalent fails -> first response fails closed, retry returns the persisted task;
  - both cases retain one task row for the idempotency key and do not second-submit.

Verification commands run from `/mnt/f/code/project/new-api`:

```bash
gofmt -w controller/creative_image_tasks.go controller/creative_test.go

go test -count=1 ./controller -run 'TestCreativeImageTask|TestCreativeImageSyncRoute|TestCreativeRelaySessionBroker|TestCreativeModelBindings|TestUpdateOptionRejectsCreativeModelBindingsGenericWrite'

go test -count=1 ./controller ./service

go build ./...

git diff --check
```

Result: PASS. Targeted controller tests, full controller+service tests, full Go build, and whitespace check exited 0.

Notes:

- This closes C1 mock-route recovery/idempotency gates using scoped idempotency as the durable pending/replay record.
- Real provider quota mutation, terminal settlement/refund, and task billing outbox remain intentionally blocked for C2+ provider-backed work.

## Phase C1 stored binding catalog / kill-switch verification

Implemented after `5fc0a51`:

- Added `GetStoredCreativeModelBindingsCatalogForGroup(userGroup)` so enabled, canary-matched, mock-safe `creative.model_bindings` entries appear in `/creative/api/models`.
- Catalog entries preserve `bindingId`, `providerModelId`, and `priceModelId`; hidden schema fields are filtered from public catalog responses.
- `/creative/api/models` now dedupes stored and built-in preview binding IDs so the same executable binding does not appear twice.
- Added tests proving stored bindings appear for matching users, hidden schema fields stay hidden, global-off/per-binding-disabled/wrong-group states hide bindings, and stored+built-in preview duplication is collapsed.

Verification commands run from `/mnt/f/code/project/new-api`:

```bash
gofmt -w service/creative_model_capability.go service/creative_model_capability_test.go controller/creative.go controller/creative_test.go

go test -count=1 ./controller -run 'TestCreativeListModels|TestCreativeImageTask|TestCreativeImageSyncRoute|TestCreativeRelaySessionBroker|TestCreativeModelBindings|TestUpdateOptionRejectsCreativeModelBindingsGenericWrite'

go test -count=1 ./service -run 'TestCreativeForbiddenKey|TestParseCreativeModelBindingsConfig|TestCreativeModelBindingsRejectFakeSecretCorpus|TestNormalizeCreativeModelBindingsConfig|TestValidateCreativeParameterSchema|TestValidateCreativeUserParamsForSchema|TestResolveCreativeImageModelBinding|TestStoredCreativeModelBindingsCatalog|TestCreativePreview|TestValidateCreativeModelBindingsConfig|TestBuildCreativeModelBindingsDryRun'

go test -count=1 ./controller ./service

go build ./...

git diff --check
```

Result: PASS after fixing a test OptionMap isolation issue. Targeted controller/service tests, full controller+service tests, full Go build, and whitespace check exited 0.

## Phase C1 task metadata / price model verification

Implemented after `0da5fd6`:

- Split internal `creativeImageTaskMetadata` from public DTO metadata. Internal task data now persists `channelId`; public response metadata still omits `channelId` and other task internals.
- Extended submit/fetch test to read the stored task row and assert versioned metadata includes binding/provider/price/preset/template/channel/userParams.
- Extended test coverage for mock pricing context: `Task.PrivateData.BillingContext.OriginModelName` is the distinct `priceModelId`, with per-call/zero-quota C1 mock semantics.

Verification commands run from `/mnt/f/code/project/new-api`:

```bash
gofmt -w controller/creative_image_tasks.go controller/creative_test.go

go test -count=1 ./controller -run 'TestCreativeImageTask|TestCreativeImageSyncRoute|TestCreativeListModels'

go test -count=1 ./controller ./service

go build ./...

git diff --check
```

Result: PASS. Targeted controller tests, full controller+service tests, full Go build, and whitespace check exited 0.

## Phase C1 task fetch platform-scope verification

Implemented after `b96735e`:

- Extended image task fetch tests to cover same-user wrong-platform tasks and same-user unmanaged `creative_image` tasks. Both return not-found through `/creative/relay/v1/images/tasks/:task_id`.
- C1 mock route is terminal/local and has no polling or selected-key fallback path; provider-backed poller/CAS/key-affinity tests remain with existing video/Suno/MJ contracts and future C2+ provider work.

Verification commands run from `/mnt/f/code/project/new-api`:

```bash
gofmt -w controller/creative_test.go

go test -count=1 ./controller -run 'TestCreativeImageTask|TestCreativeImageSyncRoute'

go test -count=1 ./controller ./service

go build ./...

git diff --check
```

Result: PASS. Targeted controller tests, full controller+service tests, full Go build, and whitespace check exited 0.

## Phase C1 fake-secret public surface verification

Implemented after `9c1f24d`:

- Added `TestCreativeImageTaskPublicSurfacesDoNotLeakFakeSecretCorpus`, which stores fake-secret corpus material in private task fields (`UpstreamTaskID`, selected key, private result URL, fail reason, and billing context) and proves image task fetch/content responses do not expose it.
- Cleaned current task/spec documentation to use placeholder descriptions for private mock URL / signed-query markers instead of embedding fake-secret literal values in Trellis artifacts.

Verification commands run from `/mnt/f/code/project/new-api`:

```bash
gofmt -w controller/creative_test.go

go test -count=1 ./controller -run 'TestCreativeImageTask|TestCreativeImageSyncRoute|TestCreativeListModels'

go test -count=1 ./controller ./service

go build ./...

git diff --check
```

Result: PASS. Targeted controller tests, full controller+service tests, full Go build, and whitespace check exited 0.

Artifact check run from `/mnt/f/code/project/new2fly`:

```bash
# Run with the fake-secret corpus patterns kept outside Trellis artifacts.
rg -n '<fake-secret-corpus-patterns>' \
  .trellis/tasks/06-16-creative-adapter-capability-registry \
  .trellis/spec/backend/creative-backend-security-boundary.md
```

Result after cleanup: no matches in current task/spec artifacts.

## Phase C1 final verification sweep

Final verification commands run after all C1 mock image task slices were committed.

From `/mnt/f/code/project/new-api`:

```bash
go test -count=1 ./controller -run 'TestCreativeImageTask|TestCreativeImageSyncRoute|TestCreativeListModels|TestCreativeModelBindings|TestUpdateOptionRejectsCreativeModelBindingsGenericWrite'
go test -count=1 ./service -run 'TestCreativeForbiddenKey|TestParseCreativeModelBindingsConfig|TestCreativeModelBindingsRejectFakeSecretCorpus|TestNormalizeCreativeModelBindingsConfig|TestValidateCreativeParameterSchema|TestValidateCreativeUserParamsForSchema|TestResolveCreativeImageModelBinding|TestStoredCreativeModelBindingsCatalog|TestCreativePreview|TestValidateCreativeModelBindingsConfig|TestBuildCreativeModelBindingsDryRun'
go test -count=1 ./controller ./service
go build ./...
git diff --check
```

From `/mnt/f/code/project/new2fly`:

```bash
# fake-secret corpus grep executed with concrete patterns kept outside this artifact
git diff --check
```

Result: PASS. Targeted controller/service tests, full controller+service tests, full Go build, new-api whitespace check, current-task/spec fake-secret artifact grep, and new2fly whitespace check all exited 0.

## Phase B shared forbidden normalizer matrix verification

Implemented after C1 final sweep:

- Added `TestCreativeForbiddenNormalizerMatrixCoversAdminSchemaDryRunAndRelay`.
- The same dangerous-key corpus now covers:
  - `service.CreativeForbiddenKey`;
  - parameter schema ID validation;
  - raw admin binding JSON key validation;
  - typed `userParams` validation plus hidden-field rejection;
  - dry-run preview redaction;
  - relay JSON nested legacy `params`;
  - relay query parameters;
  - URL-encoded form fields;
  - multipart form field names;
  - multipart file-part names.

Verification commands run from `/mnt/f/code/project/new-api`:

```bash
gofmt -w controller/creative_test.go

go test -count=1 ./controller -run 'TestCreativeForbiddenNormalizerMatrix|TestCreativeRelayRejectsForbiddenAliases|TestCreativeImageTask|TestCreativeImageSyncRoute|TestCreativeModelBindings|TestUpdateOptionRejectsCreativeModelBindingsGenericWrite'

go test -count=1 ./service -run 'TestCreativeForbiddenKey|TestParseCreativeModelBindingsConfig|TestCreativeModelBindingsRejectFakeSecretCorpus|TestNormalizeCreativeModelBindingsConfig|TestValidateCreativeParameterSchema|TestValidateCreativeUserParamsForSchema|TestResolveCreativeImageModelBinding|TestStoredCreativeModelBindingsCatalog|TestCreativePreview|TestValidateCreativeModelBindingsConfig|TestBuildCreativeModelBindingsDryRun'

go test -count=1 ./controller ./service

go build ./...

git diff --check
```

Result: PASS. Targeted controller/service tests, full controller+service tests, full Go build, and whitespace check exited 0.

## Phase B fake-secret corpus response/log verification

Implemented after forbidden normalizer matrix:

- Expanded backend fake-secret corpus recognition to cover cookie, CSRF, nonce, and object-key marker families in addition to existing bearer/key-like, provider URL, signed URL, data/base64-like, credential/token/access-key marker families.
- Added `TestCreativeModelBindingsAdminRejectsFakeSecretCorpusWithoutLogging`: validate and dry-run reject corpus-bearing admin binding payloads, and response/log surfaces do not echo the submitted secret values.
- Existing service corpus tests continue to assert admin-state/dry-run diagnostics reject sensitive provider/schema values without including raw submitted values in error text.

Verification commands run from `/mnt/f/code/project/new-api`:

```bash
gofmt -w service/creative_model_capability.go service/creative_model_capability_test.go controller/creative_model_bindings_test.go

go test -count=1 ./controller -run 'TestCreativeModelBindingsAdmin|TestCreativeForbiddenNormalizerMatrix|TestCreativeRelayRejectsForbiddenAliases'

go test -count=1 ./service -run 'TestCreativeModelBindingsRejectFakeSecretCorpus|TestBuildCreativeModelBindingsDryRun|TestValidateCreativeParameterSchema|TestValidateCreativeUserParamsForSchema|TestCreativeForbiddenKey'

go test -count=1 ./controller ./service

go build ./...

git diff --check
```

Result: PASS. Targeted controller/service tests, full controller+service tests, full Go build, and whitespace check exited 0.

## Phase B locked channel validator verification

Implemented after fake-secret corpus hardening:

- `ValidateCreativeModelBindingsConfig` now validates positive `channelId` references against the database when present.
- Missing locked channels fail closed.
- Disabled locked channels fail closed.
- Enabled locked channels pass validation.
- Existing tests continue to cover duplicate IDs, unknown preset/template, wrong modality, invalid channel id, forbidden canary/schema/admin keys, raw option bypass, and hidden/forbidden user param handling through resolver tests.

Verification commands run from `/mnt/f/code/project/new-api`:

```bash
gofmt -w service/creative_model_capability.go service/creative_model_capability_test.go

go test -count=1 ./service -run 'TestValidateCreativeModelBindingsConfig|TestParseCreativeModelBindingsConfig|TestCreativeModelBindingsRejectFakeSecretCorpus|TestBuildCreativeModelBindingsDryRun'

go test -count=1 ./controller ./service

go build ./...

git diff --check
```

Result: PASS. Targeted service tests, full controller+service tests, full Go build, and whitespace check exited 0.

## Phase B GrsAI fixture-only dry-run completion

Implemented after locked-channel validation:

- Added `grsai_gpt_image_dryrun` + `grsai_gpt_image` as a fixture-only admin validation/dry-run pair.
- The GrsAI dry-run preview is local-only: `transport=fixture`, no base URL, no provider endpoint, no `Authorization`, no API key, and no channel secret fields.
- The preview shows only sanitized request shape: model, prompt placeholder, managed image placeholder, `aspectRatio`, and `replyType=json`.
- Added a fixture response parser for GrsAI image status/result shape. It returns only id/status/result count/progress/sanitized error and never returns provider result URLs.
- Stored/public catalog and C1 submit resolver remain mock-only. Even if a GrsAI fixture binding is enabled and canary-matched, it is hidden from `/creative/api/models` and rejected by the image task submit resolver.
- Duomi remains intentionally blocked pending captured local fixtures for submit/poll/result/error semantics.

Verification commands run from `/mnt/f/code/project/new-api`:

```bash
gofmt -w service/creative_model_capability.go service/creative_model_capability_test.go

go test -count=1 ./service -run 'TestParseCreativeModelBindingsConfig|TestBuildCreativeModelBindingsDryRun|TestParseCreativeGrsAIImageFixtureResponse|TestStoredCreativeModelBindingsCatalog|TestResolveCreativeImageModelBinding|TestValidateCreativeModelBindingsConfig'

go test -count=1 ./controller -run 'TestCreativeModelBindings|TestUpdateOptionRejectsCreativeModelBindingsGenericWrite|TestCreativeForbiddenNormalizerMatrix'

go test -count=1 ./service -run 'TestCreativeForbiddenKey|TestParseCreativeModelBindingsConfig|TestCreativeModelBindingsRejectFakeSecretCorpus|TestNormalizeCreativeModelBindingsConfig|TestValidateCreativeParameterSchema|TestValidateCreativeUserParamsForSchema|TestResolveCreativeImageModelBinding|TestStoredCreativeModelBindingsCatalog|TestCreativePreview|TestValidateCreativeModelBindingsConfig|TestBuildCreativeModelBindingsDryRun|TestParseCreativeGrsAIImageFixtureResponse'

go test -count=1 ./controller ./service
```

Result: PASS.

Full release/no-provider gate before this GrsAI fixture-only slice:

```bash
cd /mnt/f/code/project/new2fly
python3 scripts/creative_release_gate.py check --source-diff-check --run-new-api-tests
```

Result after this fixture-only slice: PASS (`[done] no-secrets Creative release gate completed`).

## Final goal-attainment audit closure — managed image task / channel mapping / empty userParams

Implemented after the retry3/retry4 dynamic final audit findings:

- OpenTU schema-backed managed image task route now fails fast before submit when `referenceImages` are present, matching the C1 backend policy that reference images are unsupported instead of silently dropping them.
- OpenTU managed image task content download now accepts only the exact same-origin content route for the current remote task id; any DTO-provided mismatched content URL falls back to `/creative/relay/v1/images/tasks/{taskId}/content`.
- OpenTU introduced `hasCreativeUserParams()` so an explicit empty `userParams: {}` no longer causes ordinary legacy image adapters to be treated as schema-backed, while runtime schema-backed models with empty params still route through the managed task path.
- new-api locked channel validation now rejects direct `model_mapping` rewrites such as `{"gpt-image-2":"other-upstream-model"}` when the binding claims `providerModelId=gpt-image-2`; identity mapping and logical-model-to-provider mapping remain allowed.
- new-api creative model capability code uses `common.Unmarshal` rather than direct `encoding/json.Unmarshal` calls for new business-code unmarshal paths.

Dynamic workflow audits used during closure:

```bash
codex-flow run .codex-flow/generated/creative-goal-attainment-final-audit-2026-06-16-retry3.workflow.ts
codex-flow run .codex-flow/generated/creative-goal-attainment-final-audit-2026-06-16-retry4-focused.workflow.ts
codex-flow run .codex-flow/generated/creative-frontend-closure-retry6.workflow.ts
codex-flow run .codex-flow/generated/creative-backend-closure-retry6.workflow.ts
```

Results:

- `retry3` integration branch returned `pass_with_notes`; backend/frontend/security timed out, but the completed integration branch found no Critical/High release blocker and identified medium hardening items.
- `retry4-focused` found two true Highs: direct `model_mapping` rewrite and ordinary adapter empty `userParams` misclassification. Both were fixed.
- `creative-frontend-closure-retry6` returned `pass_with_notes`: no Critical/High, empty `userParams:{}` no longer breaks ordinary legacy image adapters, and runtime schema-backed empty params still route through managed tasks.
- `creative-backend-closure-retry6` returned `pass_with_notes`: no Critical/High, direct `model_mapping` rewrite is rejected and covered by tests.

Verification commands run:

```bash
cd /mnt/f/code/project/opentu
pnpm vitest run \
  packages/drawnix/src/services/__tests__/image-generation-service.test.ts \
  packages/drawnix/src/services/__tests__/generation-api-service.creative-embedded.test.ts \
  packages/drawnix/src/services/__tests__/task-queue-service-image-retry.test.ts \
  packages/drawnix/src/services/__tests__/media-executor.test.ts
pnpm typecheck

cd /mnt/f/code/project/new-api
go test -count=1 ./controller ./service

cd /mnt/f/code/project/new2fly
python3 scripts/creative_release_gate.py build-sync-check --source-diff-check --run-new-api-tests
```

Results: PASS.

Notes:

- The OpenTU Vitest run has existing non-blocking noise (`.npmrc ${NPM_TOKEN}` warnings, localStorage crypto warnings, sourcemap warning), but all test files passed.
- The build/release gate has existing Sass/Browserslist/Vite chunk-size warnings, but build, dist sync, no-sourcemap policy, source diff checks, new-api tests, and `go build ./...` all passed.
- No real Duomi/GrsAI/provider calls were made; C1 remains mock-first and fixture/dry-run only.

## 2026-06-16 Post-final-audit Medium Closure

After the focused dynamic security closure reported no Critical/High findings but several Medium/hardening notes, the following closure fixes were implemented and verified:

- OpenTU preserves schema-backed/managed image tasks with empty `userParams` using a local-only `creativeManaged` marker, without reclassifying ordinary legacy adapter calls that explicitly pass `userParams: {}`.
- new-api relay forbidden-body guard now inspects JSON-looking bodies even when `Content-Type` is not JSON, and rejects unsupported opaque unsafe relay bodies instead of pass-through.
- new-api model-policy admin writes require dashboard session plus Creative nonce; the dashboard API client now fetches `/creative/api/bootstrap` and attaches `X-Creative-CSRF` / `X-Creative-Nonce` before saving policy.
- Creative model policy admin state now includes enabled stored managed bindings in model pools, modality buckets, effective policy, and cleaned-policy diagnostics.
- Enabled Creative binding IDs now fail validation if they collide with an enabled channel model ID.
- Locked-channel provider-model validation now accepts runtime-compatible chained `model_mapping` while still rejecting direct rewrites and cycles.

Dynamic workflow evidence:

- `.codex-flow/generated/creative-security-closure-2026-06-16.workflow.ts` / journal `.codex-flow/journal/creative-security-closure-2026-06-16.jsonl`: no Critical/High; surfaced Medium closure items.
- `.codex-flow/generated/creative-medium-closure-postfix-2026-06-16.workflow.ts` / journal `.codex-flow/journal/creative-medium-closure-postfix-2026-06-16.jsonl`: confirmed empty-userParams managed marker and primary backend closures; surfaced the dashboard nonce and chained mapping follow-ups.
- `.codex-flow/generated/creative-last-two-medium-closure-2026-06-16.workflow.ts` / journal `.codex-flow/journal/creative-last-two-medium-closure-2026-06-16.jsonl`: confirmed dashboard nonce source path and chained mapping behavior; remaining notes were reduced to build/test hygiene and addressed with dashboard build plus explicit cycle regression test.

Verification commands run:

```bash
# OpenTU targeted regression
cd /mnt/f/code/project/opentu
pnpm vitest run \
  packages/drawnix/src/services/__tests__/task-queue-service-image-retry.test.ts \
  packages/drawnix/src/services/__tests__/media-executor.test.ts
pnpm typecheck

# new-api backend and dashboard checks
cd /mnt/f/code/project/new-api
go test -count=1 ./controller ./service
go test -count=1 ./service
cd /mnt/f/code/project/new-api/web/default
bun run typecheck
bun run build

# full embedded/no-provider gate
cd /mnt/f/code/project/new2fly
python3 scripts/creative_release_gate.py build-sync-check --source-diff-check --run-new-api-tests
```

Results:

- OpenTU targeted vitest: 2 files passed, 24 tests passed.
- OpenTU typecheck: 5 projects passed.
- new-api `go test -count=1 ./controller ./service`: passed.
- new-api service cycle/collision regression: passed.
- new-api dashboard `bun run typecheck`: passed.
- new-api dashboard `bun run build`: passed; non-blocking Rspack persistent cache save warning observed.
- full release gate: passed; embedded dist synchronized, no sourcemaps, source diff checks passed, Go tests/build passed.

Commits:

- opentu `2f397c31 fix(creative): preserve managed image tasks with empty params`
- new-api `de74021 fix(creative): close adapter registry hardening gaps`

## VPS-A production deployment — creative registry candidate

Date: 2026-06-16

Deployment target:

- Host: VPS-A `47.80.71.35`
- App path: `/home/admin/apps/new-api`
- Compose service/container: `new-api` / `new-api-relay`
- Previous image: `new-api-creative-embed:bfef310-originfix`
- Deployed image: `new-api-creative-embed:de74021-creative-registry`
- Data mount preserved: `./data:/data`, `SQLITE_PATH=/data/new-api.db`

Pre-deploy state:

```bash
cd /mnt/f/code/project/opentu && git status --short --branch
cd /mnt/f/code/project/new-api && git status --short --branch
cd /mnt/f/code/project/new2fly && git status --short --branch
```

Result: opentu/new-api clean on `feat/creative-embed`; new2fly clean except pre-existing `.codex/config.toml`.

Read-only VPS-A preflight:

```bash
ssh -i ~/.ssh/id_ed25519 admin@47.80.71.35 'cd /home/admin/apps/new-api && docker compose ps && docker inspect new-api-relay ... && df -h ...'
```

Result: production was running `new-api-creative-embed:bfef310-originfix`, host-network port `13000`, disk had ~8.1G available before deploy.

Backup:

- Created remote backup directory: `/home/admin/apps/new-api/backups/pre-creative-registry-20260616-175958`
- Contents: `docker-compose.yml`, env backup, container/image inspect JSON, online SQLite backup `new-api.db`, `SHA256SUMS.txt`
- SQLite backup mode: online `.backup`

Build/load/deploy:

```bash
cd /mnt/f/code/project/new-api
docker build -t new-api-creative-embed:de74021-creative-registry .
docker save new-api-creative-embed:de74021-creative-registry | gzip -1 | \
  ssh -i ~/.ssh/id_ed25519 admin@47.80.71.35 'gunzip | docker load'
ssh -i ~/.ssh/id_ed25519 admin@47.80.71.35 \
  'cd /home/admin/apps/new-api && update docker-compose.yml image && docker compose up -d'
```

Result: image built locally, loaded on VPS-A, compose recreated `new-api-relay` successfully.

Unauthenticated no-provider smoke:

```bash
# local on VPS-A and public console/API endpoints
GET  /creative/
GET  /creative/version.json
GET  /creative/api/bootstrap
GET  /creative/api/models
POST /creative/relay/v1/images/tasks
```

Result:

- `/creative/` returns `200`, `Cache-Control: no-cache`, no redirect.
- `/creative/version.json` returns `200`, buildTime `2026-06-16T03:06:34.268Z`.
- `/creative/api/bootstrap`, `/creative/api/models`, and `/creative/relay/v1/images/tasks` return `401` with `Cache-Control: private, no-store` when not logged in.
- Public `https://console.se7endot.top/creative/*` results match local smoke.
- Embedded index asset references checked: no `__vite-browser-external` reference remained; referenced Creative asset `index-DNVo0rPB.js` returned `200`.
- Container remained running with `restart=0`; no panic/fatal crash found in recent logs. The only recent `[ERR]` was expected invalid-token noise from unauthenticated smoke.

Authenticated dashboard smoke status:

- Direct password login smoke is blocked by production Turnstile (`Turnstile token 为空`) unless a real browser/Turnstile session is used.
- No provider calls were made.
- Do not use synthetic session-cookie generation for further smoke; use a real browser dashboard session or a dedicated temporary non-Turnstile smoke path if one is later added.

Operational note:

- During a synthetic-session experiment, shell tracing was accidentally enabled once and printed sensitive session material in the local tool transcript. It was not written into repository files. Recommended follow-up: rotate `SESSION_SECRET` during an agreed maintenance window; this will invalidate current dashboard sessions but should not affect SQLite data, channel config, or API tokens.

## VPS-A post-deploy secret rotation and authenticated smoke

Date: 2026-06-16

Reason:

- Rotated `SESSION_SECRET` after the earlier synthetic-session debug attempt exposed session material in the tool transcript.
- User authorized temporary root smoke user creation because production root credentials were not available in this session; previously supplied credentials were for local staging.

Pre-change backup:

- Created backup directory: `/home/admin/apps/new-api/backups/pre-secret-turnstile-20260616-183628`
- Contents: compose/env backups, container inspect, online SQLite backup, `TurnstileCheckEnabled` original value, checksums.
- Original `TurnstileCheckEnabled`: `true`.

Actions:

- Updated `.env` with a new random `SESSION_SECRET` without printing it.
- Restarted `new-api-relay` so the new session secret took effect.
- Temporarily set DB option `TurnstileCheckEnabled=false` and restarted for login smoke.
- Created a temporary root smoke user with a random password and no API token, used only for dashboard-session smoke.
- Deleted the temporary smoke user after smoke.
- Restored `TurnstileCheckEnabled=true` and restarted.

Authenticated no-provider smoke results:

```text
temp_user_created id_present=true
turnstile_during_smoke=false
login_http=200 success=True role=100 user_id_present=True
self_http=200 success=True role=100 group=admin
bootstrap_http=200 success=True models=19 csrf_present=True nonce_present=True asset_sync=False video_relay=False
models_http=200 success=True count=19
admin_policy_http=200 success=True keys=allowedModalities,cleanedPolicy,cleanedPolicyJSON,diagnostics,key,modelPools,policy,policyJSON
admin_bindings_http=200 success=True bindings=0 keys=config,configJSON
validate_no_nonce_http=403 success=False message=creative session auth is invalid
validate_with_nonce_http=200 success=True message=
dry_run_with_nonce_http=200 success=True message=
temp_user_remaining=0
turnstile_after_restore=true
final status=running restart=0 image=new-api-creative-embed:de74021-creative-registry
```

Model sample returned by Creative bootstrap included 19 production channel models, including text models and `grok-imagine-image-lite`; no provider generation endpoint was called.

Final public/local checks after restore:

- `https://console.se7endot.top/creative/` → `200`, `Cache-Control: no-cache`.
- `https://console.se7endot.top/creative/version.json` → `200`, buildTime `2026-06-16T03:06:34.268Z`.
- `https://console.se7endot.top/creative/api/bootstrap` while logged out → `401`, `Cache-Control: private, no-store`.
- `TurnstileCheckEnabled=true`.
- `smoke_users=0`.
- `new-api-relay` is running `new-api-creative-embed:de74021-creative-registry` with restart count `0` after final restart.
- No panic/fatal/traceback/recent `[ERR]` lines were found in the final 3-minute log scan.

Reviewer note:

- A read-only `trellis-check` sub-agent confirmed the smoke plan: `TurnstileCheckEnabled=false` is the correct temporary key; `SESSION_SECRET` rotation invalidates dashboard sessions but not API access tokens; GET bootstrap/policy/bindings are no-provider; validate/dry-run are local no-provider admin checks; relay generation endpoints were intentionally not called.

## Phase B/C admin UI — Creative model bindings management page

Implemented in new-api working tree:

- Added TypeScript DTOs for `CreativeParameterSchemaItem`, `CreativeModelBindingsConfig`, admin state, validate response, and dry-run response in `web/default/src/features/system-settings/types.ts`.
- Added dedicated API client functions in `web/default/src/features/system-settings/api.ts`:
  - `GET /api/creative/model-bindings`
  - `POST /api/creative/model-bindings/validate`
  - `POST /api/creative/model-bindings/dry-run`
  - `PUT /api/creative/model-bindings`
- Validate/dry-run/PUT all reuse the existing Creative nonce bootstrap helper and send `X-Creative-CSRF` / `X-Creative-Nonce`.
- Added `web/default/src/features/system-settings/models/creative-model-bindings-section.tsx` as a root-only System Settings -> Models & Routing section.
- Registered the section as `/system-settings/models/creative-model-bindings` through the existing model section registry.
- UI is JSON-first and mock-first:
  - no `/api/option` write path;
  - Duomi live adapters are explicitly unavailable;
  - GrsAI template is disabled and dry-run/fixture-only;
  - dry-run preview displays `noProviderCall` and redacted request preview;
  - Save is disabled unless the current exact editor draft has both validate success and dry-run `noProviderCall=true`.
- Fixed review-found async race: validate/dry-run mutation variables now carry the submitted draft; late responses for stale drafts are ignored and cannot mark a changed editor as save-ready.

Verification after final async-race fix:

```bash
cd /mnt/f/code/project/new-api/web/default
pnpm exec eslint \
  src/features/system-settings/api.ts \
  src/features/system-settings/types.ts \
  src/features/system-settings/models/section-registry.tsx \
  src/features/system-settings/models/creative-model-bindings-section.tsx
pnpm typecheck
pnpm build:check
```

Result: PASS. Full `pnpm lint` was also attempted earlier and failed on 99 existing React lint errors outside this change set, so targeted lint was used for the modified files.

Backend contract smoke:

```bash
cd /mnt/f/code/project/new-api
go test ./controller ./service -run 'CreativeModelBindings|UpdateOptionRejectsCreativeModelBindingsGenericWrite'
```

Result: PASS.

Trellis check sub-agent result:

- Found one Medium issue: UI copy required validate/dry-run before save, but initial Save path only called PUT. The check agent patched the UI to require same-draft validate + dry-run `noProviderCall=true` before save.
- No remaining High/Low findings from that check after the patch.

Dynamic workflow final review:

1. `codex-flow run .codex-flow/generated/creative-bindings-ui-final-audit.workflow.ts`
   - Result: found the same stale pre-fix save-gate issue; one branch timed out. Superseded by later fixes.
2. `codex-flow run .codex-flow/generated/creative-bindings-ui-final-audit-v2.workflow.ts`
   - Result: found a real High async race: pending validate/dry-run responses could mark a changed draft as save-ready. Also raised a `channelId` concern.
   - Resolution: async race fixed. `channelId` was classified as non-blocking because current v3 design explicitly allows root-admin backend-owned locked channel config; it remains forbidden to OpenTU/userParams and is backend-validated.
3. `codex-flow run .codex-flow/generated/creative-bindings-ui-final-audit-v3.workflow.ts`
   - Result: both branches timed out; no conclusion used.
4. `codex-flow run .codex-flow/generated/creative-bindings-ui-final-audit-v4.workflow.ts`
   - Result: failed because the selected model override was not supported by the runtime; no conclusion used.
5. `codex-flow run .codex-flow/generated/creative-bindings-ui-final-audit-v5.workflow.ts`
   - Result: PASS in two focused read-only branches.
   - Branch A confirmed validate/dry-run results bind to the submitted draft and stale responses are ignored; Save requires current draft validate + dry-run `noProviderCall=true`.
   - Branch B confirmed dedicated `/api/creative/model-bindings*` endpoints, nonce on unsafe requests, no `/api/option` write use from the section, and no real Duomi/GrsAI calls or credential/baseURL/header/callback fields in templates.

Spec update:

- Updated `.trellis/spec/backend/creative-backend-security-boundary.md` to capture the admin UI same-draft validate+dry-run save gate, stale async result handling, and required future UI test assertions.

Remaining release risk:

- `web/default` currently has little/no system-settings UI test harness and no package test script for this section. The contract is recorded in spec; future work should add component/API tests for the same-draft gate if a suitable frontend test harness is introduced.

## Local smoke — Creative model bindings admin UI before deployment

Date: 2026-06-16

Scope: local-only smoke for `new-api` commit `ac65d7f` before any production deployment. No production data or provider endpoint was used.

Setup:

- Started `new-api` locally on `127.0.0.1:3017` with a temporary SQLite database under `/tmp/newapi-creative-bindings-smoke/`.
- Initialized a temporary local root account through `/api/setup`.
- Logged in through `/api/user/login` with a cookie jar.
- Stopped the local process after smoke.

API smoke:

```text
GET  /api/setup -> success, sqlite, uninitialized before setup
POST /api/setup -> success
POST /api/user/login -> success, role=100
GET  /api/user/self with New-Api-User: 1 -> success, role=100
GET  /api/creative/model-bindings with New-Api-User: 1 -> success, {version:1, bindings:[]}
GET  /creative/api/bootstrap -> success, csrfToken present, nonce present
POST /api/creative/model-bindings/validate with Creative nonce + New-Api-User -> success, valid=true
POST /api/creative/model-bindings/dry-run with Creative nonce + New-Api-User -> success, noProviderCall=true, bindings=0
PUT  /api/creative/model-bindings with Creative nonce + New-Api-User -> success
```

Frontend/static smoke:

```text
GET /system-settings/models/creative-model-bindings -> 200, SPA root HTML served
web/default/dist/static/js/* contains Creative Model Bindings / model-bindings / noProviderCall strings
```

Browser automation note:

- Superseded by the 2026-06-17 Playwright browser smoke below after Chromium was installed.

Operational note:

- The first isolated `HOME` attempt failed because Go module downloads timed out against `proxy.golang.org`; the successful run used the existing local Go module/build cache while still using the temporary SQLite database and local-only environment.
- An attempted `SYNC_FREQUENCY=0` value caused excessive option-sync logging; future local smoke should use the default or a large positive interval instead of `0`.

## Local browser smoke — Creative model bindings admin UI

Date: 2026-06-17

Scope: local-only Playwright smoke for `new-api` commit `ac65d7f`. No production data, production endpoint, or real provider endpoint was used.

Setup:

- Started `new-api` locally on `127.0.0.1:3017` with a temporary SQLite database under `/tmp/newapi-creative-browser-smoke.*`.
- Initialized a temporary local root account through `/api/setup`.
- Logged in through `/api/user/login`.
- Used a temporary Playwright runner under `/tmp/playwright-smoke-runner` so repository `package.json` / lockfiles were not changed.
- Stopped the local process after smoke.

Browser smoke assertions:

```text
GET /system-settings/models/creative-model-bindings -> real Chromium page load succeeds
Page renders "Creative Model Bindings"
Page renders the safety copy:
  - "Duomi live adapters are unavailable"
  - "GrsAI is dry-run/fixture only here"
Page renders buttons:
  - Format JSON
  - Load mock template
  - Load GrsAI dry-run template
  - Validate
  - Dry Run
  - Save Bindings
Save Bindings is disabled on initial load
Load mock template keeps Save Bindings disabled
Validate calls POST /api/creative/model-bindings/validate and returns valid=true
Save Bindings remains disabled after validate alone
Dry Run calls POST /api/creative/model-bindings/dry-run and returns noProviderCall=true
Page renders "Dry-run preview" and "noProviderCall=true"
Save Bindings becomes enabled only after same-draft validate + dry-run
Save calls PUT /api/creative/model-bindings successfully
Unsafe Creative admin requests include New-Api-User=1, X-Creative-CSRF, and X-Creative-Nonce
No external/provider HTTP requests are observed by the browser context
```

Recorded Creative admin browser requests:

```text
GET  /api/creative/model-bindings
POST /api/creative/model-bindings/validate
POST /api/creative/model-bindings/dry-run
PUT  /api/creative/model-bindings
GET  /api/creative/model-bindings
```

Result: PASS.

## VPS-A production deployment — Creative model bindings admin UI

Date: 2026-06-17

Deployment target:

- Host: VPS-A `47.80.71.35`
- App path: `/home/admin/apps/new-api`
- Compose service/container: `new-api` / `new-api-relay`
- Previous image: `new-api-creative-embed:3fb17f1-creative-startup`
- Deployed image: `new-api-creative-embed:ac65d7f-creative-bindings-ui`
- Data mount preserved: `./data:/data`, SQLite database preserved at `/home/admin/apps/new-api/data/new-api.db`

Pre-deploy state:

```text
local new-api branch: feat/creative-embed
local new-api commit: ac65d7f feat(creative): add model bindings admin UI
remote container before deploy: new-api-creative-embed:3fb17f1-creative-startup, running, restart=0
remote disk before deploy: ~7.4G available
```

Backup:

- Created remote backup directory: `/home/admin/apps/new-api/backups/pre-creative-bindings-ui-20260617-002541`
- Contents: `docker-compose.yml`, `.env`, container/image inspect JSON, online SQLite backup `new-api.db`, `SHA256SUMS.txt`
- SQLite backup mode: online `sqlite3 .backup`
- Backup DB size: `191M`

Build/load/deploy:

```bash
cd /mnt/f/code/project/new-api
docker build --pull=false --progress=plain -t new-api-creative-embed:ac65d7f-creative-bindings-ui .
docker save new-api-creative-embed:ac65d7f-creative-bindings-ui | gzip -1 | \
  ssh -i ~/.ssh/id_ed25519 admin@47.80.71.35 'gunzip | docker load'
ssh -i ~/.ssh/id_ed25519 admin@47.80.71.35 \
  'cd /home/admin/apps/new-api && update docker-compose.yml image && docker compose up -d'
```

Result:

```text
local image id: sha256:1efcab7b9d95103ad668561841c40bc871c78d6f8e1e6fab304b8c75d334690f
loaded image: new-api-creative-embed:ac65d7f-creative-bindings-ui
container after deploy: new-api-creative-embed:ac65d7f-creative-bindings-ui running restart=0
```

Unauthenticated/public smoke after deploy:

```text
https://console.se7endot.top/creative/ -> 200, Cache-Control: no-cache
https://console.se7endot.top/creative/version.json -> 200, Cache-Control: no-cache, buildTime 2026-06-16T12:05:44.669Z
https://console.se7endot.top/creative/api/bootstrap while logged out -> 401, Cache-Control: private, no-store
https://console.se7endot.top/system-settings/models/creative-model-bindings -> 200, Cache-Control: no-cache, SPA shell served
https://api.se7endot.top/v1/models without token -> 401
```

Authenticated browser smoke:

- Used a temporary root smoke user with random password and no persisted credential output.
- Temporarily set `TurnstileCheckEnabled=false` for the smoke window only, then restored it to `true` and restarted the container.
- First attempt with non-sudo SQLite writes failed with `attempt to write a readonly database`; it made no DB changes. Retried with `sudo -n sqlite3`.
- Browser automation used real Chromium against `https://console.se7endot.top`.
- No provider generation endpoint was called and no external browser request was observed.
- Production smoke intentionally did **not** click `Save Bindings` / `PUT`; it only exercised GET, validate, and dry-run for the current server config.

Browser smoke assertions:

```text
POST /api/user/login -> success, role=100
GET  /api/user/self -> success, role=100
GET  /system-settings/models/creative-model-bindings -> real Chromium page load succeeds
Page renders "Creative Model Bindings"
Page renders safety copy for Duomi unavailable and GrsAI dry-run/fixture only
Save Bindings starts disabled
POST /api/creative/model-bindings/validate -> success, valid=true
Save Bindings remains disabled after validate alone
POST /api/creative/model-bindings/dry-run -> success, noProviderCall=true
Page renders "Dry-run preview" and "noProviderCall=true"
Save Bindings becomes enabled after same-draft validate + dry-run
Unsafe Creative admin requests include New-Api-User, X-Creative-CSRF, and X-Creative-Nonce
No PUT /api/creative/model-bindings was sent
No external/provider browser requests were observed
```

Recorded Creative admin browser requests:

```text
GET  /api/creative/model-bindings
POST /api/creative/model-bindings/validate
POST /api/creative/model-bindings/dry-run
```

Final state after cleanup:

```text
container: new-api-creative-embed:ac65d7f-creative-bindings-ui running restart=0
TurnstileCheckEnabled=true
smoke_users=0
public creative shell/version OK
logged-out bootstrap still 401 private/no-store
recent log scan: no panic/fatal/traceback; one expected invalid-token line from unauthenticated /v1/models smoke
remote disk after deploy: ~7.1G available
```

Result: PASS.

## Final goal-attainment audit follow-up fixes

Date: 2026-06-17

Reason:

- A dynamic final audit was run with the intended goal "do not depend on previous reports; audit whether the current project achieves the development goal and whether material issues remain".
- The first workflow completed 3/4 branches; the broad frontend branch timed out. A focused frontend supplement found one real frontend safety-copy issue.
- This exposed that the previous "final audit" was too narrowly Creative-focused and lacked a whole-console route smoke matrix. A production route matrix smoke was added after the user reported `/channels` showing a 500 in their browser.

Dynamic workflow runs:

```text
codex-flow run .codex-flow/generated/creative-goal-attainment-final-audit-20260617.workflow.ts
journal: .codex-flow/journal/creative-goal-attainment-final-audit-20260617.jsonl
result: 3/4 branches completed, frontend branch timed out
verdict: pass_with_risks

codex-flow run .codex-flow/generated/creative-frontend-final-audit-supplement-20260617.workflow.ts
journal: .codex-flow/journal/creative-frontend-final-audit-supplement-20260617.jsonl
result: 0/2 branches completed, both timed out

codex-flow run .codex-flow/generated/creative-frontend-final-audit-focused-20260617.workflow.ts
journal: .codex-flow/journal/creative-frontend-final-audit-focused-20260617.jsonl
result: 1/2 branches completed
verdict: pass_with_risks
```

Material findings selected for immediate fix:

- Frontend dry-run `success=true` but `noProviderCall=false` still displayed the success copy "without provider calls". Save remained disabled, but the safety feedback was wrong.
- `GET /api/creative/model-bindings` business failure / missing data could render a blank page instead of an actionable error/retry state.
- Backend `PUT /api/creative/model-bindings` validated but did not internally require dry-run `noProviderCall=true`, so a custom client could bypass the UI's validate+dry-run gate.
- Admin Creative API responses did not consistently set `private, no-store` outside `/creative/api` and `/creative/relay`.
- Sensitive `canaryGroups` validation errors could echo the raw group value.
- Dry-run preview did not expose locked channel / final provider model mapping diagnostics for admin review.

Implemented in new-api commit:

```text
a9a2cec fix(creative): harden model bindings admin gate
```

Files changed:

```text
controller/creative_model_bindings.go
controller/creative_model_bindings_test.go
router/api-router.go
service/creative_model_capability.go
service/creative_model_capability_test.go
web/default/src/features/system-settings/models/creative-model-bindings-section.tsx
web/default/src/features/system-settings/types.ts
```

Fix summary:

- Frontend now treats `noProviderCall=false` as an error/warning and keeps save disabled.
- Frontend now renders a destructive load error with Retry when model-bindings response is `success=false` or has no `data`.
- `/api/creative/*` admin routes now use no-store cache middleware; model-bindings controllers also set `Cache-Control: private, no-store` and `Pragma: no-cache`.
- `PUT /api/creative/model-bindings` now builds the dry-run preview and requires `noProviderCall=true` before persisting.
- `canaryGroups` sensitive/forbidden validation errors now reference `canaryGroups[index]` without echoing the raw value.
- Dry-run preview now includes safe diagnostics for `lockedChannelId`, `finalProviderModelId`, and `channelModelId` when a locked channel/model mapping is involved.

Verification before commit:

```bash
cd /mnt/f/code/project/new-api
go test -count=1 ./service ./controller ./router

cd /mnt/f/code/project/new-api/web/default
pnpm exec eslint src/features/system-settings/models/creative-model-bindings-section.tsx src/features/system-settings/types.ts
pnpm typecheck
pnpm build:check
```

Result: PASS.

Trellis check sub-agent:

- Reviewed the final-audit fix diff.
- Re-ran targeted eslint, `git diff --check`, `pnpm typecheck`, and `go test -count=1 ./service ./controller ./router`.
- Result: PASS; no remaining findings.

## Production `/channels` report investigation and route-matrix smoke

Date: 2026-06-17

User report:

- User screenshot showed `https://console.se7endot.top/channels` rendering the generic `500` error page.

Investigation result:

- This was **not** covered by the previous Creative-focused production smoke or final audit.
- Local temporary SQLite smoke against `/channels` passed.
- Read-only production DB inspection showed 5 channels and no server panic/fatal around `/api/channel`.
- A production temporary root smoke user accessed `/channels` successfully with real Chromium and the production channel data; no browser `pageerror`, no console error, and `/api/channel/?tag_mode=false&id_sort=false&p=1&page_size=20` returned 200.
- The stored `.admin_user` / `.admin_pass` files on VPS-A did not successfully authenticate, so real-admin repro via those files was not usable.

Temporary production smoke cleanup:

```text
TurnstileCheckEnabled=true
smoke_users=0
container=new-api-creative-embed:ac65d7f-creative-bindings-ui running restart=0
```

Production route-matrix smoke added after the report:

- Used a temporary root smoke user with random password.
- Temporarily disabled Turnstile, then restored it and deleted the smoke user.
- Real Chromium visited the core authenticated routes.

Routes checked:

```text
/dashboard -> OK, redirected/rendered /dashboard/overview
/channels -> OK
/models -> OK, redirected/rendered /models/metadata
/users -> OK
/system-settings -> OK, redirected/rendered /system-settings/site/system-info
/system-settings/models/creative-model-bindings -> OK
/creative/ -> OK
```

Final cleanup after route-matrix smoke:

```text
TurnstileCheckEnabled=true
smoke_users=0
container=new-api-creative-embed:ac65d7f-creative-bindings-ui running restart=0
```

Conclusion:

- The reported `/channels` 500 was not reproduced with a fresh production root browser session and appears likely tied to the reporter's current browser/session/localStorage/cache state rather than a globally failing route.
- The audit process gap is real: final audit must include both goal-attainment review and a whole-console route smoke matrix, not only the Creative target surfaces.
