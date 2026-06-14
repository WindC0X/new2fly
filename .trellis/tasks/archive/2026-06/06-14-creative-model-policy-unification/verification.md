# Verification Log — Creative Model Policy Unification

## Completed baseline checks

### OpenTU targeted Vitest

```bash
cd /mnt/f/code/project/opentu
pnpm vitest run \
  packages/drawnix/src/services/creative-session-broker.test.ts \
  packages/drawnix/src/services/creative-model-policy-resolver.test.ts \
  packages/drawnix/src/services/creative-display-policy.test.ts \
  packages/drawnix/src/services/creative-display-policy.embedded.test.ts \
  packages/drawnix/src/utils/runtime-model-discovery.creative-embedded.test.ts \
  packages/drawnix/src/utils/__tests__/settings-manager.test.ts \
  packages/drawnix/src/services/__tests__/generation-api-service.creative-embedded.test.ts \
  packages/drawnix/src/services/__tests__/generation-api-service.mj.test.ts \
  packages/drawnix/src/components/ai-input-bar/ModelDropdown.test.tsx \
  packages/drawnix/src/components/ai-input-bar/ModelSelector.test.tsx
```

Result: 10 files passed, 38 tests passed.

### OpenTU typecheck

```bash
cd /mnt/f/code/project/opentu
pnpm nx run drawnix:typecheck
```

Result: passed.

### OpenTU embedded build

```bash
cd /mnt/f/code/project/opentu
VITE_BASE_URL=/creative/ pnpm build:web
```

Result: passed. Existing warnings: npm token env-substitution warning, Sass deprecation warnings, large chunk warning.

### Cross-repo release gate and new-api checks

```bash
cd /mnt/f/code/project/new2fly
python3 scripts/creative_release_gate.py build-sync-check --run-new-api-tests
```

Result: passed. The gate rebuilt OpenTU, synced both new-api Creative dist trees, verified artifact identity, checked `/creative/assets` refs, allowed generated sourcemap policy, and ran new-api Go tests/build.

## Local hygiene

- Restored `opentu/apps/web/public/version.json` after build-time timestamp churn.
- Do not commit `new-api/.codegraph/`, `new-api/.codex-flow/`, `new2fly/.cache/`, or `opentu/packages/drawnix/audio-test.pptx`.

## Pending

- Historical note from the first pass: final dynamic workflow audit and any findings were still pending at that point. Follow-up dynamic attempts, static review, fixes, and rerun checks are recorded below.

## 2026-06-14 follow-up static fallback audit and fixes

### Additional manual/script review after handoff

A follow-up scan found additional embedded-mode static fallback surfaces not covered by the earlier notes:

- TTD dialog parent and child image/video/batch model state could initialize or resync to standalone defaults (`gemini-*-image*`, `veo3`) when the managed Creative catalog was empty.
- Tool plugin initialization and image generation messages could still pass standalone image defaults into tool config/task creation.
- Shared workflow model-selection storage returned standalone fallback/legacy profile selections in embedded mode, which could rehydrate stale workflow model IDs.
- Video Analyzer / MV Creator generation pages relied on stored/record model IDs and needed embedded-mode reconciliation to the managed selectable catalog.

Fixes applied:

- TTD image/video/batch selection now uses `''` in embedded mode when no managed model exists, disables submit/generate locally, and shows a local New API Creative unavailable message.
- `plugins/with-tool.ts` now sends only the embedded managed route model (or empty) to tools and fails locally before task creation if no image model exists.
- `components/shared/workflow/model-selection-storage.ts` now ignores standalone fallback and non-`new-api-creative` persisted refs in embedded mode.
- Video Analyzer and MV Creator generation pages reconcile stale image/video selections to the managed selectable catalog in embedded mode, or clear them when empty.

### OpenTU checks after follow-up fixes

```bash
cd /mnt/f/code/project/opentu
pnpm nx run drawnix:typecheck
```

Result: passed.

```bash
cd /mnt/f/code/project/opentu
pnpm vitest run \
  packages/drawnix/src/services/creative-session-broker.test.ts \
  packages/drawnix/src/services/creative-model-policy-resolver.test.ts \
  packages/drawnix/src/services/creative-display-policy.test.ts \
  packages/drawnix/src/services/creative-display-policy.embedded.test.ts \
  packages/drawnix/src/utils/runtime-model-discovery.creative-embedded.test.ts \
  packages/drawnix/src/utils/__tests__/settings-manager.test.ts \
  packages/drawnix/src/services/__tests__/generation-api-service.creative-embedded.test.ts \
  packages/drawnix/src/services/__tests__/generation-api-service.mj.test.ts \
  packages/drawnix/src/components/ai-input-bar/ModelDropdown.test.tsx \
  packages/drawnix/src/components/ai-input-bar/ModelSelector.test.tsx \
  packages/drawnix/src/components/shared/workflow/model-selection-storage.test.ts
```

Result: 11 files passed, 41 tests passed.

### Cross-repo gate after rebuilt embedded artifact

```bash
cd /mnt/f/code/project/new2fly
python3 scripts/creative_release_gate.py build-sync-check --run-new-api-tests
```

Result: passed. The gate rebuilt OpenTU, synced `dist/apps/web` into both `new-api` Creative dist trees, verified artifact identity and `/creative/assets` entry refs, allowed generated sourcemap policy, and ran new-api Go tests/build.

`opentu/apps/web/public/version.json` build timestamp churn was restored after the gate.

### Targeted backend check after follow-up

```bash
cd /mnt/f/code/project/new-api
go test -count=1 ./service ./middleware ./controller -run 'Creative(ModelPolicy|RelaySessionBroker|Bootstrap)'
```

Result: passed.

### Dynamic-workflow final audit attempts

The requested final dynamic-workflow audit was attempted after fixes:

```bash
cd /mnt/f/code/project/new2fly
codex-flow run .codex-flow/generated/creative-model-policy-final-targeted-audit.workflow.ts
codex-flow run .codex-flow/generated/creative-model-policy-micro-final-audit.workflow.ts
```

Result: both workflows completed with all sub-agent branches timing out and no usable branch output:

- `.codex-flow/journal/creative-model-policy-final-targeted-audit.jsonl` — usable branches 0/4.
- `.codex-flow/journal/creative-model-policy-micro-final-audit.jsonl` — usable branches 0/2.

Do not count these timed-out final dynamic runs as independent pass evidence. Earlier dynamic workflow output that produced usable findings was fixed, and the final confidence currently rests on direct code review, targeted tests, typecheck, and the full release gate above.

## 2026-06-14 direct Gemini runtime fallback follow-up

### Additional finding

A final static pass over embedded model defaults found a cross-cutting residual fallback path: direct `sendChatWithGemini` callers still built runtime config with static fallback model names (for example `gpt-4o-mini`) when embedded Creative had no managed text model. This could affect task-queue chat subflows and knowledge/text utilities that call the Gemini service wrapper directly rather than going through `generation-api-service`.

### Fix

- `packages/drawnix/src/utils/gemini-api/services.ts` now resolves every direct text/image/video runtime config through `resolveCreativeEmbeddedModelForGeneration` before calling provider transport.
- In embedded mode, invalid requested models and empty managed pools throw the existing local Creative unavailable error before `callApiWithRetry` / stream / provider calls.
- Added regression coverage in `packages/drawnix/src/utils/gemini-api/auth.creative-embedded.test.ts` proving an empty embedded catalog rejects direct chat calls and does not call the API transport.

### Checks after this follow-up

```bash
cd /mnt/f/code/project/opentu
pnpm vitest run packages/drawnix/src/utils/gemini-api/auth.creative-embedded.test.ts -t 'fails closed for direct chat calls'
```

Result: failed before the fix because `sendChatWithGemini` resolved successfully through the mocked API transport instead of rejecting; passed after the fix.

```bash
cd /mnt/f/code/project/opentu
pnpm vitest run packages/drawnix/src/utils/gemini-api/auth.creative-embedded.test.ts
```

Result: passed, 5 tests.

```bash
cd /mnt/f/code/project/opentu
pnpm nx run drawnix:typecheck
```

Result: passed.

```bash
cd /mnt/f/code/project/opentu
pnpm vitest run \
  packages/drawnix/src/services/creative-session-broker.test.ts \
  packages/drawnix/src/services/creative-model-policy-resolver.test.ts \
  packages/drawnix/src/services/creative-display-policy.test.ts \
  packages/drawnix/src/services/creative-display-policy.embedded.test.ts \
  packages/drawnix/src/utils/runtime-model-discovery.creative-embedded.test.ts \
  packages/drawnix/src/utils/__tests__/settings-manager.test.ts \
  packages/drawnix/src/utils/gemini-api/auth.creative-embedded.test.ts \
  packages/drawnix/src/services/__tests__/generation-api-service.creative-embedded.test.ts \
  packages/drawnix/src/services/__tests__/generation-api-service.mj.test.ts \
  packages/drawnix/src/components/ai-input-bar/ModelDropdown.test.tsx \
  packages/drawnix/src/components/ai-input-bar/ModelSelector.test.tsx \
  packages/drawnix/src/components/shared/workflow/model-selection-storage.test.ts
```

Result: passed, 12 files / 46 tests.

```bash
cd /mnt/f/code/project/new2fly
python3 scripts/creative_release_gate.py build-sync-check --run-new-api-tests
```

Result: passed. The gate rebuilt OpenTU, synced both new-api Creative dist trees, verified artifact identity and `/creative/assets` refs, allowed generated sourcemap policy, ran new-api Go tests, and ran `go build ./...`.

```bash
git -C /mnt/f/code/project/opentu diff --check
git -C /mnt/f/code/project/new-api diff --check
git -C /mnt/f/code/project/new2fly diff --check
```

Result: passed for all three repositories.
