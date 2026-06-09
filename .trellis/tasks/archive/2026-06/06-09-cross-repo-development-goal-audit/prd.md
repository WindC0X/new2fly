# Cross-repo development goal audit for new-api and opentu

## Goal

Run a complete, evidence-based, read-only deep audit of the sibling repositories `/mnt/f/code/project/new-api` and `/mnt/f/code/project/opentu` to determine whether the current `feat/creative-embed` implementation meets the intended development goals for embedding Opentu into new-api.

## User Request

- Original request: “使用完整动态工作全面深度审查当前项目是否达成开发目标 （当前目录是项目编排目录、代码项目是在项目同级目录new-api和opentu中）”。
- Follow-up request: archive the previous audit task and create a fresh task.
- Previous task archived: `.trellis/tasks/archive/2026-06/06-08-dynamic-deep-project-audit/`.

## Confirmed Facts

- The Trellis orchestration directory is `/mnt/f/code/project/new2fly`; it is not itself a Git repository.
- The code repositories under audit are siblings:
  - backend / host app: `/mnt/f/code/project/new-api`
  - frontend / creative workspace: `/mnt/f/code/project/opentu`
- Both code repositories are on branch `feat/creative-embed` and currently contain uncommitted working-tree changes.
- Existing Trellis evidence says Phase 0 proved `/creative/` static embedding is technically feasible, but not a complete usable product.
- Existing Phase 0/0.5 documentation says the current integration already targeted:
  - mounting Opentu under new-api at `/creative/`;
  - adding Creative Workspace navigation from new-api to Opentu;
  - rebuilding Opentu with `VITE_BASE_URL=/creative/`;
  - adding return navigation from Opentu back to new-api;
  - preparing for a follow-up dual-model/deep audit.
- Existing integration assessment says full product completion requires later phases beyond static embedding, especially session/bootstrap relay, provider gateway behavior, billing, idempotency, model restrictions, and asset sync.
- Current environment instruction requires Codex inline mode: the main session performs implementation/checks directly and must not dispatch implement/check sub-agents. Therefore the audit should use the dynamic-workflow decomposition pattern but execute in the main session unless a higher-priority instruction changes.

## Requirements

### Scope

- Audit only the current local working trees of `new-api` and `opentu`, plus relevant Trellis planning artifacts in `new2fly`.
- Treat source code, tests, docs, route behavior, build artifacts, and local service behavior as evidence.
- Do not modify production code during the audit.
- Do not print secrets or credential values. If secret-like material is encountered, report only path/key class and redact values.

### Audit Lenses

The audit must cover at least:

1. **Goal reconstruction** — reconstruct the intended deliverables from Trellis docs, task docs, code diffs, commits/history when useful, and repository docs.
2. **Backend integration** — verify new-api creative routes, static `/creative/` serving, SPA fallback, no-cache behavior, session/auth/billing/model-list/relay-related changes, and regression risk to `/api`, `/v1`, and admin UI.
3. **Frontend integration** — verify Opentu embedded-mode detection, return-to-console UX, provider/session-broker/model-selection changes, cloud/document sync changes, standalone-mode compatibility, and service-worker/base-path risk.
4. **Cross-repo contract** — verify that Opentu’s client expectations match new-api routes, response shapes, auth/session behavior, and deployed `web/creative/dist` artifact behavior.
5. **Tests and quality gates** — run feasible targeted tests/builds/type checks for both repositories, record exact commands and outcomes.
6. **Product-readiness verdict** — state whether the implementation meets the selected development-goal baseline, and separately list gaps to the next higher baseline.

## Audit Baselines

User confirmed on 2026-06-09: **审查两个基准**. The final report must therefore provide two separate pass/fail verdicts:

1. **Baseline A — Phase 0.5 / current-sprint integration goal**
   - Opentu is embedded under `/creative/`.
   - new-api → Opentu navigation works.
   - Opentu → new-api return navigation works.
   - Embedded-mode/session/provider preference changes do not break standalone Opentu.
   - Source, deployed artifact, targeted tests/builds, and route smoke checks support the claim.

2. **Baseline B — Phase 1–3 product-readiness goal**
   - Authenticated creative bootstrap/session relay exists and works without exposing long-lived API keys.
   - Opentu generation calls route through new-api as the only provider gateway.
   - Model/provider selection, billing, tokenless/session funding, retries/failover, idempotency, async task handling, and asset/document sync are coherent enough for usable product behavior.
   - Known higher-phase risks from the integration assessment are either implemented, intentionally deferred with safe UX, or clearly blocking.

The final answer must not collapse these baselines into one verdict. It should explicitly say whether the implementation meets Baseline A and whether it meets Baseline B.

## Acceptance Criteria

- [ ] Old task is archived under `.trellis/tasks/archive/2026-06/` and the fresh task owns the current audit.
- [ ] Audit target repositories and branches are recorded.
- [ ] Development goals are reconstructed with citations to local docs/code paths.
- [ ] Backend, frontend, and cross-repo contracts are reviewed separately.
- [ ] Feasible tests/builds/type checks are run and exact commands/results are recorded.
- [ ] Final report classifies findings by severity and includes evidence paths.
- [ ] Final verdict gives separate results for Baseline A and Baseline B, each one of: `meets baseline`, `partially meets baseline`, or `does not meet baseline`.
- [ ] Final report distinguishes current-sprint blockers from higher-phase/product-complete blockers.
- [ ] No secret values are printed.

## Out of Scope

- Making implementation fixes during the audit unless the user explicitly asks after receiving findings.
- Pushing commits or performing destructive Git operations.
- Auditing unrelated sibling repositories.
- Calling production endpoints or external services.

## Open Questions

- None blocking. User chose to audit both Baseline A and Baseline B.
