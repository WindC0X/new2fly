# Design: Independent Dynamic Goal-Attainment Audit

## Audit Boundaries

This is a read-only, evidence-based audit. The dynamic workflow runs from `new2fly` and inspects:

- `.` (`new2fly`): Trellis orchestration, active specs, workflow state, and cross-repo governance.
- `../new-api`: backend/API gateway implementation, route contracts, billing/quota/security boundaries, tests/configuration.
- `../opentu`: frontend/product implementation, AI creative flows, service worker/cache behavior, model/task/provider routing, tests/configuration.

Previous reports and archived task conclusions are explicitly non-authoritative and should be ignored except for avoiding accidental reuse.

## Evidence Model

Each sub-agent must return structured evidence:

- area name;
- reconstructed goal(s);
- status: `met`, `partial`, `not_met`, or `unknown`;
- confidence score;
- exact evidence file paths;
- findings and risks;
- recommended next checks/fixes.

The main workflow then runs a synthesis agent that compares independent branches and produces a consolidated status and top risks.

## Parallel Audit Lenses

1. **Goal/source-of-truth reconstruction**: README/docs/specs/configs only, excluding prior reports.
2. **Backend contract audit**: `new-api` creative relay/assets/security/billing/idempotency implementation vs active backend specs.
3. **Frontend contract audit**: `opentu` creative generation/assets/service-worker/provider routing implementation vs active frontend specs.
4. **End-to-end flow audit**: cross-repo request/response DTOs, auth/session broker, asset lifecycle, async task lifecycle, callbacks/polling/proxy behavior.
5. **Quality/build/test readiness audit**: package scripts, tests, type/lint/build feasibility, skipped/fragile tests, obvious quality gates.
6. **Security/ops/deployment readiness audit**: secret boundaries, credential stripping, origin/cache/proxy hardening, deploy docs/configs.
7. **Documentation/spec drift audit**: active Trellis specs and project docs vs code evidence, including missing or stale acceptance coverage.

## Tooling Constraints

- `codex-flow` backend remains default `codex-sdk` membership mode.
- Sub-agents use `sandbox: "read-only"`.
- No application-code edits are made.
- The final report may be recorded in the task directory for traceability.

## Output Shape

The workflow returns JSON-like structured results and logs a journal under `.codex-flow/journal/`. The assistant final response summarizes:

- overall attainment verdict;
- per-area scores/status;
- critical blockers;
- confidence and verification gaps;
- rerun command and journal path.
