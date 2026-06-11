# Deep Audit new-api and opentu

## Goal

Use a freshly generated dynamic workflow to perform a complete deep review of the **current project in `new2fly`**. `new2fly` is the orchestration/specification project; its concrete implementation code lives in sibling repositories:

- `../new-api`: backend/session-broker/API/asset/relay implementation surface.
- `../opentu`: embedded Creative/Opentu frontend/runtime implementation surface.

The review must be independent of previous audit reports. Findings should be evidence-backed from current `new2fly` specs/planning contracts plus current `new-api` and `opentu` code, tests, and configs. It must judge whether the implementation in `new-api` and `opentu` actually achieves the **current project development goals defined by `new2fly`**, not merely whether each sibling repository meets its own standalone README promises.

## User Request

“使用动态工作流完全深度审查当前项目（当前目录是项目编排、项目代码具体在同级目录的new-api和opentu目录），不要依赖之前的报告”

## Confirmed Facts From Current Inspection

- Current orchestration repository: `/mnt/f/code/project/new2fly`.
- Target code repositories exist as siblings:
  - `/mnt/f/code/project/new-api`
  - `/mnt/f/code/project/opentu`
- `new-api/AGENTS.md` defines a layered Go architecture: `router -> controller -> service -> model`, plus `relay`, `middleware`, `setting`, `common`, `dto`, `oauth`, and frontend under `web/`.
- `new-api` has a Go module `github.com/QuantumNous/new-api`, Gin/GORM/Redis/JWT/WebAuthn/OAuth/payment-provider dependencies, and many tests under `controller/`, `dto/`, and `common/`.
- `opentu/package.json` identifies an Nx/pnpm React workspace with `apps/web`, `packages/drawnix`, `packages/react-board`, `packages/react-text`, `packages/utils`, Playwright E2E, Vitest, lint/typecheck scripts, and deployment scripts.
- `opentu/AGENTS.md` delegates planning/spec governance to `openspec/AGENTS.md` for substantial changes. This audit is read-only and should not create an OpenSpec change unless later remediation is requested.
- `new2fly/.trellis/spec/backend/index.md` and `frontend/index.md` identify the active current-project contracts. They center on embedding Opentu Creative into new-api through browser-session APIs and relays.
- Backend active contracts define `/creative/api/assets`, `/creative/relay/v1/videos`, `/creative/relay/v1/suno`, and `/creative/relay/v1/mj` behavior: browser-session-only boundaries, same-origin/nonce enforcement, forbidden credential/routing material, owner-scoped task/result access, idempotency, selected-key affinity, billing/refund CAS, and private asset storage.
- Frontend active contracts define Opentu Creative behavior for cloud asset prepare/hydrate and embedded async video/Suno/MJ session-broker flows: canonical `/creative/relay/v1` paths, empty-key session-broker mode, stable idempotency keys, credential stripping, service-worker pass-through, no direct fallback on unsupported backend, and sanitized errors.
- `new-api` and `opentu` standalone README/docs remain useful context, but they are secondary for this audit. The primary development goal is the `new2fly` cross-repo Creative integration contract.
- Workspace journals and old codex-flow/generated summaries show that prior reports exist, but they must not be used as evidence for this fresh audit.
- Existing working tree changes are present before this task:
  - `new2fly`: untracked `.trellis/workspace/WindC0X/creative-embed-audit-2026-06-11.md`.
  - `new-api`: branch `feat/creative-embed`, untracked `.codegraph/`.
  - `opentu`: branch `feat/creative-embed`, modified `.gitignore`, untracked `packages/drawnix/audio-test.pptx`.

## Requirements

1. Generate and run a `codex-flow` dynamic workflow rather than a single linear manual review.
2. Treat the audit as fresh:
   - Do not rely on previous reports, archived task outputs, `.codebuddy/code-review-report.md`, old Trellis reports, or prior assistant conclusions.
   - Use current source code, tests, configs, and only docs needed to understand intended behavior.
3. Keep target repositories read-only during the audit. Generated workflow/journal/report artifacts may be written under `new2fly` task/workflow directories.
4. Audit current-project development-goal conformance explicitly:
   - Treat `new2fly/.trellis/spec/backend/creative-*.md` and `new2fly/.trellis/spec/frontend/creative-*.md` as the primary goal/contract sources.
   - Compare those contracts against implemented code paths, route wiring, middleware, storage, task state, billing/CAS behavior, frontend provider transport, service-worker behavior, tests, and validation coverage in `new-api` and `opentu`.
   - Identify goal gaps: missing routes, partially implemented relays, unsafe auth/session boundaries, credential leakage, idempotency/key-affinity/billing gaps, asset sync/hydration drift, frontend/backend path mismatch, fallback behavior that violates the embedded contract, or tests that do not cover required scenarios.
   - Use standalone `new-api`/`opentu` README/docs only as supporting context, not as the primary current-project goal.
   - Separate goal-conformance findings from security/logic findings while still ranking impact.
5. Cover both repositories and cross-repo behavior:
   - `new-api` backend attack surface and business logic.
   - `opentu` frontend/runtime/workspace/task/material behavior.
   - Shared API/contract/integration assumptions between frontend and backend.
6. Review high-risk areas explicitly:
   - AuthN/AuthZ, admin and user isolation.
   - Billing/quota/top-up/subscription/payment webhooks/idempotency.
   - AI relay/provider routing, model pricing, streaming, request transformation, and explicit zero-value preservation.
   - External URL/file/media/proxy handling, SSRF/path traversal/content-type trust.
   - Async tasks, concurrency, cache/state consistency, retry/idempotency.
   - Frontend storage, service worker, postMessage/iframe/plugin/skill integrations, XSS/HTML injection, local persistence, and asset/task lifecycle.
   - Cross-database compatibility for `new-api` where relevant.
   - Tests and validation gaps.
7. Every material finding must include:
   - repository and file path(s), preferably line/function references;
   - severity and confidence;
   - impact and exploit/failure scenario;
   - evidence from current code;
   - suggested remediation and validation/test ideas;
   - whether it is confirmed, likely, or needs runtime verification.
8. The final report must distinguish:
   - confirmed defects;
   - plausible risks requiring runtime verification;
   - false-positive candidates or areas reviewed with no material finding;
   - validation commands run or not run.

## Acceptance Criteria

- [ ] A Trellis task contains `prd.md`, `design.md`, and `implement.md` for this audit.
- [ ] A generated workflow exists under `.codex-flow/generated/` and uses multiple parallel read-only agents.
- [ ] The workflow runs via `codex-flow run ...` and records a journal under `.codex-flow/journal/`.
- [ ] A final audit report is written under `.trellis/tasks/06-11-newapi-opentu-deep-audit/` with prioritized findings.
- [ ] The report explicitly states that prior reports were not used as evidence.
- [ ] The report covers both `new-api` and `opentu`, plus cross-repo contract risks.
- [ ] The report includes a dedicated section judging whether `new-api` + `opentu` achieve the `new2fly` Creative integration development goals, with evidence and gap severity.
- [ ] Findings include concrete file/function references and actionable remediation guidance.
- [ ] Validation status is clear, including any commands that could not be run and residual risk.

## Out of Scope

- Fixing code defects discovered by the audit.
- Destructive VCS operations, broad refactors, dependency upgrades, or production endpoint calls.
- Reading or printing secrets from local environment files; `.env.example` and non-secret config templates may be read.
- Treating generated/build artifacts such as `dist/` as the primary source unless needed to understand deployment behavior.

## Open Questions

None blocking. The user clarified that the project is the current `new2fly` directory, while concrete code lives in `new-api` and `opentu`. For execution, interpret development goals primarily as the current `new2fly/.trellis/spec` Creative integration contracts, not as prior audit reports and not merely as each sibling repository's standalone README goals.
