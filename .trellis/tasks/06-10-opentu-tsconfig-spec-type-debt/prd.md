# Opentu tsconfig.spec Type Debt Follow-up

## Goal

Make `/mnt/f/code/project/opentu/packages/drawnix/tsconfig.spec.json --noEmit` pass by fixing broad test fixture type debt that remains after the creative remediation partial configuration cleanup.

## Background

The parent creative remediation task requires the spec typecheck command to be run and either fixed or explicitly split with evidence. During final dynamic verification on 2026-06-10:

- `packages/drawnix/tsconfig.spec.json` was updated to use an `import.meta`-compatible test module target and Vitest/Vite types.
- `NX_DAEMON=false pnpm exec nx run drawnix:typecheck` passed.
- `NX_DAEMON=false pnpm exec nx run web:typecheck` passed.
- Full spec typecheck still exited `2` with many test fixture typing errors.

Evidence:

- Parent evidence: `.trellis/tasks/06-09-newapi-opentu-creative-remediation/research/opentu-tsconfig-spec-2026-06-10.md`
- Final workflow: `.codex-flow/generated/creative-remediation-final-dynamic-verification.workflow.ts`
- Final workflow journal: `.codex-flow/journal/creative-remediation-final-dynamic-verification.jsonl`

## Requirements

- Fix the remaining TypeScript errors reported by:

  ```bash
  cd /mnt/f/code/project/opentu/packages/drawnix
  TMPDIR=/dev/shm pnpm exec tsc -p tsconfig.spec.json --noEmit --pretty false
  ```

- Prefer low-risk test/fixture/type-helper fixes over broad production refactors.
- Preserve creative remediation behavior and existing targeted Vitest coverage.
- Do not weaken type checking by adding broad `any`, `skipLibCheck`, blanket excludes, or suppressions unless a suppression is narrowly justified in a test.
- Keep standalone opentu behavior and embedded `/creative` session-broker behavior unchanged.

## Known Failure Groups

The 2026-06-10 run showed errors across these groups:

- Workflow converter and workflow record fixtures missing required fields or literal narrowing.
- Music/video analyzer fixtures missing required analysis fields.
- Prompt/history/shared workflow tests using older mock signatures and narrow inferred return types.
- GPT image adapter and creative-session-broker tests with Vitest mock tuple inference issues.
- Model vendor/capability fixture drift in model selection/grouping tests.
- Workspace rename validation tests with outdated create options.

## Acceptance Criteria

- [ ] `TMPDIR=/dev/shm pnpm exec tsc -p packages/drawnix/tsconfig.spec.json --noEmit --pretty false` exits `0` from `/mnt/f/code/project/opentu`.
- [ ] `NX_DAEMON=false pnpm exec nx run drawnix:typecheck` exits `0`.
- [ ] `NX_DAEMON=false pnpm exec nx run web:typecheck` exits `0`.
- [ ] Creative targeted Vitest subset from the parent remediation still passes.
- [ ] No test fixture fix weakens the embedded session-broker security invariants: no browser upstream API key/baseUrl/provider override leakage.
- [ ] Remaining unrelated failures, if any, are documented in a narrower follow-up with exact file/error evidence.

## Parent Task Relationship

The parent task may reference this child to explain why `tsconfig.spec.json --noEmit` remains split/pending. The parent must not claim the spec typecheck gate is green until this child reaches completion.
