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
