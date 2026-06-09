# Deep Goal Audit for new-api and opentu

## Goal

使用只读的完整动态工作流，全面审查当前本地项目状态是否已经达成 `new-api` + `opentu` 创意工作台集成开发目标，并输出可复核的差距、风险、证据和下一步建议。

本任务的代码项目不在当前编排目录内，而在同级目录：

- `../new-api`：Go/Gin + React 的 AI API gateway / 管理系统；当前分支 `feat/creative-embed`，含未提交集成改动。
- `../opentu`：React/Nx/pnpm 的画布优先 AI 应用；当前分支 `feat/creative-embed`，含未提交集成改动。
- `.` / `new2fly`：Trellis 编排与审查产物目录。

## Confirmed Source Requirements

审查基准来自既有 Trellis 产物与本地项目文档：

- `.trellis/tasks/06-07-opentu-new-api/prd.md`
- `.trellis/tasks/06-07-opentu-new-api/product-decisions.md`
- `.trellis/tasks/06-07-opentu-new-api/integration-assessment.md`
- `.trellis/tasks/06-08-add-return-to-console-button-in-opentu/*`
- `../new-api/AGENTS.md`
- `../opentu/AGENTS.md`
- `../opentu/openspec/AGENTS.md`
- `../opentu/docs/README.md` and key coding/flow docs

Key intended outcomes to evaluate:

1. `new-api` exposes a same-origin `/creative/` entry that serves the Opentu build and supports refresh/deep-link fallback.
2. `new-api` sidebar/navigation includes Creative Workspace and returns users to a working embedded Opentu surface.
3. Opentu is built for `/creative/`; static asset paths and Service Worker scope do not escape into the `new-api` root app.
4. Creative bootstrap/session-auth relay exists or is accurately identified as incomplete; browser should not need long-lived API keys for embedded mode.
5. Initial Creative Gateway path should route generation through `new-api`, not direct upstream keys; at minimum OpenAI-compatible image generation should be assessed.
6. New-api billing/session-tokenless behavior must not panic, bypass quota incorrectly, or double-charge/refund incorrectly.
7. Async provider pathways (video/Suno/MJ where present) should not duplicate submit/retry/charge logic or silently bypass gateway decisions.
8. Asset/document cloud sync, if implemented, must provide user isolation, metadata/binary persistence, lazy restoration, sanitization, and no obvious secret/PII leaks.
9. Opentu embedded UI should provide a return-to-console affordance if that task has been implemented.
10. Both repositories should pass relevant lightweight static/test/build verification where feasible without destructive operations.

## Requirements

### R1. Evidence-first review

- Inspect actual current working trees, including uncommitted changes in `../new-api` and `../opentu`.
- Do not rely solely on previous summaries; previous documents are source requirements, not proof of current completion.
- Record evidence as file paths, commands, and observed behavior.

### R2. Full dynamic workflow

- Use `codex-flow` with multiple read-only sub-agents.
- Split review into independent branches covering backend routing/auth/billing, frontend embed/navigation, Opentu provider/runtime behavior, asset/cloud sync, tests/build/deployment, and adversarial gap validation.
- Synthesize branch outputs into a single completion matrix.

### R3. Completion judgment

- Produce an explicit verdict for each target: `done`, `partial`, `not_done`, or `blocked/unverified`.
- Distinguish implemented code from compiled/deployed build artifacts.
- Distinguish functional acceptance, security acceptance, and maintainability acceptance.

### R4. Non-destructive constraints

- Default to read-only inspection.
- Do not delete files, reset git state, or mutate `../new-api` / `../opentu` code.
- It is acceptable to create review artifacts in this Trellis task directory and `.codex-flow/generated/` / `.codex-flow/journal/`.

### R5. Output shape

- Write an audit report under this task directory.
- Include: executive verdict, acceptance matrix, critical gaps, evidence, verification commands, and recommended next steps.
- Include the workflow file path and journal path so the run can be resumed or audited.

## Acceptance Criteria

- [x] Trellis planning artifacts (`prd.md`, `design.md`, `implement.md`) exist for this complex review task.
- [x] A `codex-flow` workflow file is generated and run successfully or its failure is analyzed with a fallback evidence path.
- [x] At least six independent review branches inspect the two codebases from different angles.
- [x] The final report compares current state against the `06-07` product decisions and future implementation acceptance criteria.
- [x] The final report identifies whether Phase 0.5 / Creative embed / return button / gateway / sync goals are achieved, partial, or missing.
- [x] The final report includes concrete file-level evidence and command-level verification notes.
- [x] No destructive operations are performed against `../new-api` or `../opentu`.

## Out of Scope

- Implementing missing features or fixing code defects.
- Committing code changes in `../new-api` or `../opentu`.
- Calling production endpoints or requiring real upstream provider credentials.
- Full browser E2E against external production sites.

## Open Questions

No user-facing product decision blocks this audit. If a target cannot be verified locally because credentials, services, or browser state are missing, mark it as `blocked/unverified` with the exact missing prerequisite.
