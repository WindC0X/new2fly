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
