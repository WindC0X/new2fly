# Opentu `tsconfig.spec.json` Verification — 2026-06-10

## Commands

Baseline comparison with HEAD config:

```bash
cd /mnt/f/code/project/opentu
TMP_CFG=packages/drawnix/tsconfig.spec.head-compare.json
git show HEAD:packages/drawnix/tsconfig.spec.json > "$TMP_CFG"
TMPDIR=/dev/shm pnpm exec tsc -p "$TMP_CFG" --noEmit --pretty false > /tmp/opentu-tsconfig-spec-head.log 2>&1
rm -f "$TMP_CFG"
```

Current working tree config:

```bash
cd /mnt/f/code/project/opentu/packages/drawnix
TMPDIR=/dev/shm pnpm exec tsc -p tsconfig.spec.json --noEmit --pretty false
```

## Result

- HEAD config exit code: `2`.
- Current config exit code: `2`.
- HEAD config `error TS` lines: `143`.
- Current config `error TS` lines: `85`.

The current `packages/drawnix/tsconfig.spec.json` change reduces the failure surface by switching spec compilation to an `import.meta`-compatible module target and adding Vitest/Vite test types:

- `module: "esnext"`
- `types: ["node", "vitest/globals", "vite/client"]`

## Remaining failure classification

The remaining failures are broad spec/test fixture type debt across many unrelated tests, not a single creative integration blocker. Representative groups:

- Workflow converter and workflow record test fixtures missing newly required fields or literal narrowing.
- Music/video analyzer fixtures missing required analysis fields.
- Prompt/history/shared workflow tests using older mock signatures and narrower inferred return types.
- GPT image adapter / creative-session-broker tests with Vitest mock tuple inference issues.
- Model vendor/capability fixture drift in model selection/grouping tests.
- Workspace rename validation tests with outdated create options.

Current failure files include:

- `src/components/ai-input-bar/__tests__/workflow-converter.test.ts`
- `src/components/shared/workflow/*.test.ts`
- `src/components/ttd-dialog/shared/*.test.ts*`
- `src/components/video-analyzer/*.test.ts`
- `src/services/__tests__/*.test.ts`
- `src/services/creative-session-broker.test.ts`
- `src/services/prompt-history-service.test.ts`
- `src/utils/__tests__/*.test.ts`

## Parent task impact

The parent acceptance criterion requiring `tsconfig.spec.json --noEmit` has been run and remains failing. The current config change is a partial cleanup, but completing this gate requires a separate broad test-fixture type-debt task or a follow-up sweep outside the immediate new-api/opentu `/creative` integration remediation.
