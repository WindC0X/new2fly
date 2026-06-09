# Implementation Plan: Cross-repo development goal audit

## Phase 1 — Planning gate

- [x] Archive previous mistaken/obsolete audit task.
- [x] Create fresh Trellis task.
- [x] Seed PRD with confirmed facts, requirements, and acceptance criteria.
- [x] Create technical audit design.
- [x] Create execution plan.
- [x] Confirm final pass/fail baseline with user: audit both Baseline A and Baseline B.
- [ ] After user approval, run `task.py start 06-09-cross-repo-development-goal-audit` before executing the audit.

## Phase 2 — Evidence collection

1. Record repository metadata:
   - `git -C ../new-api status --short --branch`
   - `git -C ../opentu status --short --branch`
   - `git -C <repo> diff --stat`
2. Reconstruct goal matrix from Trellis docs:
   - `06-07-opentu-new-api/prd.md`
   - `06-07-opentu-new-api/integration-assessment.md`
   - `06-07-opentu-new-api/phase-0-summary.md`
   - `06-08-add-return-to-console-button-in-opentu/*`
3. Inspect changed backend code and tests in `new-api`.
4. Inspect changed frontend code and tests in `opentu`.
5. Compare cross-repo API/path/auth/model/artifact contracts.

## Phase 3 — Validation commands

Run targeted checks first; broaden only if targeted checks pass or if failure diagnosis needs it.

### new-api candidate commands

- `go test ./controller ./middleware ./model ./relay/common ./relay/constant ./router ./service`
- `go test ./...` if targeted tests are feasible and not too slow.
- `go build ./...` or `go build -o /tmp/new-api-audit .`
- HTTP smoke if a local service is already safely running or can be started without production endpoints:
  - `/creative/`
  - `/creative/sw.js`
  - `/creative/assets/...`
  - `/api/status`
  - `/v1/models`

### opentu candidate commands

- `pnpm --filter @aitu/drawnix test -- --run` or package-local Vitest targeted tests if filter is unavailable.
- Targeted tests for session broker, model selector/dropdown, model preference sync, document sync, display policy.
- `pnpm nx run drawnix:typecheck` or project-local typecheck command if available.
- `VITE_BASE_URL=/creative/ pnpm run build:web` or the repo-native build command.

## Phase 4 — Analysis

- Build a requirement-to-evidence matrix.
- Mark each item as pass/fail/partial/unknown.
- Identify blockers to Baseline A.
- Identify blockers to Baseline B.
- Distinguish Baseline A pass/fail from Baseline B product-readiness gaps.
- Check for mismatches between source changes and deployed `new-api/web/creative/dist`.

## Phase 5 — Final report

- Provide final verdict.
- Include evidence paths and command results.
- Include severity-ranked findings.
- Include recommended next actions.
- Update Trellis task notes/artifacts if the audit learns durable process or spec information.

## Rollback / Safety

- Audit is read-only except Trellis task artifacts.
- Do not edit `new-api` or `opentu` source files in this task unless the user explicitly converts the audit into a fix task.
- Do not run destructive Git commands.
- Do not print secrets.
