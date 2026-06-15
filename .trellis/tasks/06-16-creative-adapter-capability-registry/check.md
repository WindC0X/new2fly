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
