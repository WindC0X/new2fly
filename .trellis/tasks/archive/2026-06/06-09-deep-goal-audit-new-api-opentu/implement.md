# Implement Plan: Deep Goal Audit for new-api and opentu

## Phase 1: Planning

- [x] Create Trellis task after user approval.
- [x] Record PRD requirements and acceptance criteria.
- [x] Record technical audit design.
- [x] Record execution plan.

## Phase 2: Dynamic Workflow Execution

1. [x] Generate `.codex-flow/generated/deep-goal-audit-new-api-opentu.workflow.ts`.
2. [x] Ensure workflow is import-free and uses JSON Schema structured outputs.
3. [x] Run:

   ```bash
   codex-flow run .codex-flow/generated/deep-goal-audit-new-api-opentu.workflow.ts
   ```

4. [x] If workflow fails due prompt/schema issues, fix only the generated workflow and rerun. (No fix needed; first run completed.)
5. [x] Preserve journal path under `.codex-flow/journal/`.

## Phase 3: Coordinator Verification

- [x] Capture current git status for `new-api`, `opentu`, and `new2fly`.
- [x] Run safe targeted verification commands if feasible, for example:

  ```bash
  git -C ../new-api status --short --branch
  git -C ../opentu status --short --branch
  # Targeted tests to be chosen after workflow findings.
  ```

- [x] Do not run destructive commands.
- [x] Do not mutate `../new-api` or `../opentu` source.

## Phase 4: Report

[x] Write `.trellis/tasks/06-09-deep-goal-audit-new-api-opentu/audit-report.md` with:

- Executive verdict.
- Completion matrix against intended goals.
- Branch summaries.
- Critical gaps and severity.
- Evidence and verification notes.
- Recommended next actions.
- Workflow file and journal references.

## Phase 5: Finish

- [x] Run relevant Trellis/check verification for generated artifacts.
- [ ] Update task journal if appropriate.
- [ ] Summarize result to user in Simplified Chinese.

## Rollback

Only review artifacts are created in `new2fly`; rollback is deleting the task directory or generated workflow/journal after explicit user confirmation. No rollback should be needed for sibling codebases because the audit is read-only.
