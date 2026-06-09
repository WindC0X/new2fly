# Design: Cross-repo development goal audit

## Architecture of the Audit

The audit is read-only and spans three evidence sources:

1. **Trellis orchestration evidence** in `/mnt/f/code/project/new2fly/.trellis/tasks/`.
   - Reconstruct intended goals, phases, known risks, and prior decisions.
2. **Backend repository** `/mnt/f/code/project/new-api`.
   - Review Go routes/controllers/middleware/models/services/tests and embedded `web/creative/dist` artifact.
3. **Frontend repository** `/mnt/f/code/project/opentu`.
   - Review React/TypeScript source, provider-routing/session-broker/model-selection changes, tests, and build output.

## Constraints

- Current Codex mode is inline: do not dispatch implement/check sub-agents.
- The original user asked for “完整动态工作流”. To honor that while respecting inline mode, the main session will emulate the dynamic-workflow fan-out as explicit audit sections/phases, not by spawning sub-agents.
- No production code changes during the audit.
- No secret values in logs or final report.

## Audit Branches

### Branch A — Goal and baseline reconstruction

Inputs:
- `.trellis/tasks/06-07-opentu-new-api/prd.md`
- `.trellis/tasks/06-07-opentu-new-api/integration-assessment.md`
- `.trellis/tasks/06-07-opentu-new-api/phase-0-summary.md`
- `.trellis/tasks/06-08-add-return-to-console-button-in-opentu/*`
- Archived prior audit PRD correction.

Output:
- A normalized goal matrix: required now, optional now, known later-phase gap.

### Branch B — new-api backend/host review

Review areas:
- `/creative/` static serving, SPA fallback, cache-control and no-route ordering.
- Creative API/controller/middleware/model/service additions.
- Billing/funding-source/text-quota behavior and tokenless/session assumptions.
- Model-list/meta/ability changes.
- Regression risk to `/api`, `/v1`, admin frontend, and existing relay modes.
- Backend tests and build.

### Branch C — opentu frontend review

Review areas:
- Embedded-mode detection and return navigation behavior.
- Session broker / provider transport / model preference flow.
- Model dropdown/selector UX and tests.
- Creative document sync/cloud status/display policy changes.
- Standalone Opentu compatibility.
- Service worker/base-path/virtual media URL risks.
- Frontend tests, type checks, and build.

### Branch D — Cross-repo contract review

Review areas:
- Route/path compatibility between Opentu client calls and new-api creative endpoints.
- Auth/session/CSRF/header expectations.
- Model list/selection response contract.
- Asset/document sync payload and persistence expectations.
- Deployed artifact parity: Opentu source build vs copied `new-api/web/creative/dist`.

### Branch E — Validation and verdict

Review areas:
- Run targeted test suites before broad suites where possible.
- Record skipped checks and why.
- Convert evidence into severity-ranked findings.
- Provide two final baseline verdicts and next-step recommendations: one for Phase 0.5/current integration, one for Phase 1–3 product readiness.

## Reporting Contract

Final report should include:

- Baseline A and Baseline B definitions.
- Executive verdict.
- Evidence table with paths and command outcomes.
- Findings grouped by severity:
  - Blocker: prevents baseline from being met.
  - High: likely user-visible breakage, money/security/data risk, or core contract gap.
  - Medium: maintainability or later-phase readiness risk.
  - Low: polish or documentation gap.
- Explicit split between Baseline A blockers and Baseline B blockers.
- Exact commands run and any checks that could not be run.
