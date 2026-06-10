# Opentu Drawnix tsconfig.spec Type Debt Resolution — 2026-06-10

## Scope

Resolved the follow-up task for `/mnt/f/code/project/opentu/packages/drawnix/tsconfig.spec.json --noEmit` after the creative remediation split.

Product repo: `/mnt/f/code/project/opentu`
Branch: `feat/creative-embed`

## Dynamic workflow runs

Implementation and verification were performed through codex-flow dynamic workflows, split to avoid over-broad edits and to keep creative security assertions isolated:

1. `.codex-flow/generated/opentu-tsconfig-spec-type-debt-batch1.workflow.ts`
   - Journal: `.codex-flow/journal/opentu-tsconfig-spec-type-debt-batch1.jsonl`
   - Result: shared/UI/analyzer/hook target fixture errors removed; remaining groups documented.
2. `.codex-flow/generated/opentu-tsconfig-spec-type-debt-batch2a-utils-ppt.workflow.ts`
   - Journal: `.codex-flow/journal/opentu-tsconfig-spec-type-debt-batch2a-utils-ppt.jsonl`
   - Result: utils/mcp/ppt target errors removed.
3. `.codex-flow/generated/opentu-tsconfig-spec-type-debt-batch2b-services.workflow.ts`
   - Journal: `.codex-flow/journal/opentu-tsconfig-spec-type-debt-batch2b-services.jsonl`
   - Result: non-creative service fixture errors removed.
4. `.codex-flow/generated/opentu-tsconfig-spec-type-debt-batch2c-creative.workflow.ts`
   - Journal: `.codex-flow/journal/opentu-tsconfig-spec-type-debt-batch2c-creative.jsonl`
   - Result: creative service mock/call typing errors removed while preserving no-secret/no-provider-leak assertions.
5. `.codex-flow/generated/opentu-tsconfig-spec-type-debt-serial-typecheck.workflow.ts`
   - Journal: `.codex-flow/journal/opentu-tsconfig-spec-type-debt-serial-typecheck.jsonl`
   - Result: typecheck gates passed.
6. `.codex-flow/generated/opentu-tsconfig-spec-type-debt-serial-vitest.workflow.ts`
   - Journal: `.codex-flow/journal/opentu-tsconfig-spec-type-debt-serial-vitest.jsonl`
   - Result: creative/security targeted Vitest subset passed.

A broader final verification workflow hit Codex 429 limits in non-Trellis branches:

- `.codex-flow/generated/opentu-tsconfig-spec-type-debt-final-verification.workflow.ts`
- `.codex-flow/journal/opentu-tsconfig-spec-type-debt-final-verification.jsonl`

That run was not used as success evidence except for the Trellis validation branch; the successful evidence is the smaller serial typecheck and Vitest workflows above.

## Implementation summary

Changed 28 Drawnix test files only. No production source, `tsconfig`, or new-api files were modified by this child task.

Patterns applied:

- Updated stale fixtures to satisfy current required fields and literal unions.
- Replaced stale provider/model fixture shapes with current `ModelVendor`, `ProviderProfile`, and `ProviderCapabilities` contracts.
- Added narrow helper functions for `fetch`/provider catalog mock-call access instead of broad suppressions.
- Preserved existing creative embedded/session-broker assertions, including browser-side no-secret/no-provider-leak coverage.

## Verification evidence

Dynamic typecheck verification (`opentu-tsconfig-spec-type-debt-serial-typecheck.workflow.ts`) reported:

- `git diff --check`: exit 0.
- `NX_DAEMON=false pnpm exec nx run drawnix:typecheck`: exit 0.
- `NX_DAEMON=false pnpm exec nx run web:typecheck`: exit 0.
- `cd packages/drawnix && TMPDIR=/dev/shm pnpm exec tsc -p tsconfig.spec.json --noEmit --pretty false`: exit 0.

Dynamic Vitest verification (`opentu-tsconfig-spec-type-debt-serial-vitest.workflow.ts`) reported:

- 7 test files passed.
- 34 tests passed.
- Command exit 0.

Command:

```bash
cd /mnt/f/code/project/opentu/packages/drawnix
../../node_modules/.bin/vitest run \
  src/services/creative-session-broker.test.ts \
  src/services/provider-routing/provider-transport.session-broker.test.ts \
  src/utils/gemini-api/auth.creative-embedded.test.ts \
  src/utils/__tests__/ai-model-selection-storage.test.ts \
  src/components/ai-input-bar/ModelDropdown.test.tsx \
  src/components/ai-input-bar/ModelSelector.test.tsx \
  src/services/creative-display-policy.test.ts \
  --config vitest.config.ts --pool=threads --maxWorkers=1 --minWorkers=1
```

Non-fatal warnings observed:

- `.npmrc` `${NPM_TOKEN}` replacement warning during pnpm/nx/tsc commands.
- Expected test-console warnings about unavailable crypto and invalid creative bootstrap auth scenarios.
- Browserslist staleness warning.

## Status

Child task acceptance criteria are satisfied:

- `tsconfig.spec.json --noEmit` passes.
- Drawnix and web typechecks pass.
- Creative targeted Vitest subset passes.
- Creative embedded security assertions remain present and meaningful.

Parent creative remediation still has independent media relay follow-up children; this child only closes the spec type debt gate.
