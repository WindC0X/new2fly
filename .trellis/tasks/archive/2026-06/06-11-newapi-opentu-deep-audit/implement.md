# Implementation Plan — Dynamic Deep Audit

## Preconditions

- [x] User approved creation of a Trellis task and entry into planning.
- [x] `codex-flow doctor` passes.
- [x] Target repositories discovered: `../new-api`, `../opentu`.
- [x] Initial repository conventions inspected: `new-api/AGENTS.md`, `opentu/AGENTS.md`, package manifests/README files.
- [x] Corrected development-goal source: current project is `new2fly`; primary goal sources are `new2fly/.trellis/spec/backend/creative-*.md` and `new2fly/.trellis/spec/frontend/creative-*.md`. Sibling repo README/docs are secondary implementation context only.
- [ ] User approves starting execution after reviewing this plan.

## Steps

1. Generate `.codex-flow/generated/newapi-opentu-deep-audit.workflow.ts`.
   - Import-free TypeScript workflow.
   - Use JSON Schema, not zod.
   - Use `ctx.parallel` for independent audit branches.
   - Use read-only sandbox for all target code review agents.
   - Explicitly instruct agents not to rely on prior reports.
   - Include one or more goal-conformance branches that extract `new2fly` Creative integration contracts and compare them to implementation/test evidence in `new-api` and `opentu`.
2. Start the Trellis task with `python3 ./.trellis/scripts/task.py start .trellis/tasks/06-11-newapi-opentu-deep-audit` after user approval.
3. Run:
   ```bash
   codex-flow run .codex-flow/generated/newapi-opentu-deep-audit.workflow.ts
   ```
4. If the workflow fails due to workflow syntax/schema/prompt issues, fix only the generated workflow file and rerun the same command to resume.
5. Inspect generated journal/output and synthesize final report into:
   ```text
   .trellis/tasks/06-11-newapi-opentu-deep-audit/audit-report.md
   ```
6. Run safe validation commands when feasible:
   - `go test` targeted packages in `../new-api` if dependencies/environment permit.
   - `pnpm`/Nx checks in `../opentu` if dependencies are installed and command cost is acceptable.
   - `new2fly` Trellis spec inspection for goal-conformance evidence; OpenSpec in `opentu` is secondary and should not replace `new2fly` contracts.
7. Update the final report with validation evidence and residual gaps.
8. Run Trellis quality check / finish steps as appropriate for a report-only task.

## Risk Controls

- Do not modify `../new-api` or `../opentu` during audit execution.
- Do not read or print real secrets.
- Do not call production endpoints or external payment/provider APIs.
- Avoid generated `dist/`, cache, and historical report directories unless needed for deployment context; never use old reports as evidence.
- Keep findings evidence-based and mark uncertain issues as requiring runtime verification.
- Do not treat `new2fly` Trellis contracts as automatically satisfied; require code/test/wiring evidence in `new-api` and `opentu`.

## Rollback Points

- Generated workflow can be deleted or regenerated if it is malformed.
- Journal/report artifacts are isolated to `new2fly` task/workflow directories.
- No target repository code changes are planned.

## Review Gate Before Start

Proceed only after user confirms this plan is acceptable. Starting execution means running multiple read-only sub-agents via `codex-flow` against `new-api` and `opentu`.
