# Implementation Plan: Dynamic Goal-Attainment Audit

## Checklist

1. Confirm `codex-flow doctor` passes.
2. Generate `.codex-flow/generated/newapi-opentu-goal-attainment-audit.workflow.ts`.
3. Ensure workflow is import-free and uses JSON Schema objects only.
4. Run `codex-flow run .codex-flow/generated/newapi-opentu-goal-attainment-audit.workflow.ts` from `/mnt/f/code/project/new2fly`.
5. If the workflow fails because of workflow-file/schema issues, fix only the generated workflow and rerun.
6. Save or summarize workflow output and journal path.
7. Produce final Chinese report with evidence, caveats, and prioritized next actions.

## Validation Commands

```bash
codex-flow doctor
codex-flow run .codex-flow/generated/newapi-opentu-goal-attainment-audit.workflow.ts
```

Optional, if time and dependencies allow during audit synthesis:

```bash
(cd ../new-api && git status --short && find . -maxdepth 2 -type f -name 'package.json' -o -name 'go.mod')
(cd ../opentu && git status --short && pnpm --version && pnpm check)
```

Do not run destructive commands or commands that require secrets/production endpoints.

## Risk / Rollback Points

- Workflow file generation is local and reversible.
- The audit is read-only; no application rollback is expected.
- If `codex-flow` sub-agents fail, inspect the error and rerun after fixing only prompt/schema issues.
