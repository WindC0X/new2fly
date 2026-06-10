# Implementation Plan — new-api / opentu Creative Integration Remediation

## Pre-implementation Gate

1. Review `prd.md`, `design.md`, and this `implement.md`.
2. Confirm task activation with the user, then run:
   ```bash
   python3 .trellis/scripts/task.py start .trellis/tasks/06-09-newapi-opentu-creative-remediation
   ```
3. Use dynamic workflows and/or Trellis sub-agents for implementation/check work; main session coordinates and synthesizes.

## Dynamic Workflow 1 — Fresh Findings Matrix

Generate `.codex-flow/generated/newapi-opentu-creative-remediation-audit.workflow.ts` with read-only branches:

- Dist/embed branch: compare `new-api/web/creative/dist`, `new-api/router/web/creative/dist`, `opentu/dist/apps/web`, `main.go`, Docker/build scripts, router tests.
- Relay branch: map `/creative/relay/v1/*` routes to new-api relay modes and opentu callers for chat/image/video/Suno/MJ.
- Provider branch: trace opentu embedded mode provider initialization and generation transports for direct provider fallback risk.
- Cloud sync branch: trace document/preference sync schemas and asset/binary references.
- UX/validation branch: return-to-console state and full validation/typecheck blockers.

Expected output: structured JSON with one row per external audit item: status, evidence, fix/split recommendation, files/tests impacted.

## Fix Order

### 1. Production dist path consistency

- Rebuild opentu with `/creative` base if needed:
  ```bash
  cd /mnt/f/code/project/opentu
  NX_DAEMON=false VITE_BASE_URL=/creative/ pnpm build:web
  ```
- Copy/sync latest `opentu/dist/apps/web` into the actual new-api production embed path `new-api/web/creative/dist`.
- Decide whether to also keep `new-api/router/web/creative/dist` synchronized or refactor tests to use the production path.
- Add/update tests proving the production embed path is non-fixture and `/creative` compatible.

Validation:

```bash
cd /mnt/f/code/project/new-api
git diff --check
GOCACHE=/tmp/go-build-cache go test ./router -run 'Test.*Creative.*(Production|Fixture|Cache|Provenance|Asset|WebRouter)' -count=1
```

### 2. Minimal image relay

- Add route registration under `/creative/relay/v1` for image generation if confirmed required.
- Reuse chat creative middleware chain.
- Ensure `relay/constant.Path2RelayMode` maps trimmed creative image path correctly.
- Add tests for route, nonce/CSRF, forbidden fields, and relay mode.

Validation:

```bash
cd /mnt/f/code/project/new-api
GOCACHE=/tmp/go-build-cache go test ./router ./controller ./middleware ./relay/common ./relay/constant ./service -run 'Test(.*Creative.*|.*RelayMode.*|.*Image.*|.*Forbidden.*|.*Nonce.*|.*Billing.*)' -count=1
```

### 3. Gateway enforcement in opentu

- Trace generation services and provider routing in embedded mode.
- Add tests ensuring embedded generation uses `new-api-creative` session-broker and does not use direct API key/base URL fallback.
- Preserve standalone opentu provider behavior outside `/creative`.

Validation:

```bash
cd /mnt/f/code/project/opentu/packages/drawnix
../../node_modules/.bin/vitest run \
  src/services/creative-session-broker.test.ts \
  src/services/provider-routing/provider-transport.session-broker.test.ts \
  src/utils/gemini-api/auth.creative-embedded.test.ts \
  --config vitest.config.ts --pool=threads --maxWorkers=1 --minWorkers=1
```

### 4. Return-to-console

- Reuse linked task `.trellis/tasks/06-08-add-return-to-console-button-in-opentu`.
- Implement UI in the embedded opentu surface only, unless product design says otherwise.
- Validate route/link target against new-api console/home path.

### 5. Cloud asset sync audit/fix or split

- Audit board snapshot payloads for binary/blob/data URL/asset refs.
- If minimal binary asset sync is feasible, add new-api session-backed asset API + opentu upload/reference handling and tests.
- If not feasible within this tranche, create child task with blockers, schema, and acceptance criteria; update parent PRD to mark split.

### 6. Video/Suno/MJ scope decision

- If dynamic workflow shows simple route mounting is safe, implement with tests.
- If async idempotency/CAS refund/multi-key affinity is required, create child tasks rather than shipping unsafe mounts.

### 7. Broad validation

Run final validation commands and record exact outputs:

new-api:

```bash
cd /mnt/f/code/project/new-api
git diff --check
GOCACHE=/tmp/go-build-cache go test ./controller ./middleware ./model ./relay/common ./relay/constant ./router ./service -count=1
```

opentu targeted:

```bash
cd /mnt/f/code/project/opentu
pnpm exec tsc -p packages/drawnix/tsconfig.lib.json --noEmit
cd packages/drawnix
../../node_modules/.bin/vitest run \
  src/utils/__tests__/ai-model-selection-storage.test.ts \
  src/components/ai-input-bar/ModelDropdown.test.tsx \
  src/components/ai-input-bar/ModelSelector.test.tsx \
  src/services/creative-session-broker.test.ts \
  src/services/creative-display-policy.test.ts \
  src/services/creative-document-sync.test.ts \
  src/services/creative-model-preference-sync.test.ts \
  src/services/provider-routing/provider-transport.session-broker.test.ts \
  src/hooks/use-creative-document-sync-status.test.tsx \
  src/utils/gemini-api/auth.creative-embedded.test.ts \
  --config vitest.config.ts --pool=threads --maxWorkers=1 --minWorkers=1
```

opentu broader validation:

```bash
cd /mnt/f/code/project/opentu/packages/drawnix
pnpm exec tsc -p tsconfig.spec.json --noEmit
```

If broader validation fails due unrelated legacy tests, capture failures and split only after verifying they are unrelated.

## Rollback Points

- Before replacing new-api creative dist, snapshot file counts and hashes.
- For route additions, keep changes isolated to creative relay route registration and focused tests.
- For opentu provider enforcement, keep `isCreativeEmbeddedMode()` guards so standalone mode rollback is low-risk.

## Completion Criteria

- All PRD acceptance criteria either passed or explicitly split into child tasks with acceptance criteria.
- Dynamic workflow journal and final synthesis are attached in task research or referenced in final report.
- No secret values are printed in artifacts.
