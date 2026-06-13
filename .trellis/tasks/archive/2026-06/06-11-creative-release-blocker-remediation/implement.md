# Implementation Plan — Creative Release Blocker Remediation

## Phase 1 — Planning Gate

- [x] Create parent task and four child tasks.
- [x] Record merged audit/arbitration findings in parent PRD.
- [x] Record dynamic workflow verification strategy.
- [x] Review/approve this parent plan before starting implementation children.

## Phase 2 — Recommended Execution Order

1. Start `06-11-creative-backend-security-boundary-hardening` first.
   - Rationale: H5/H9/H1 are high-impact and relatively localized; they stop privacy and deployment-route failures early.
2. Start `06-11-creative-frontend-session-broker-asset-sync-hardening` in parallel or immediately after backend security boundary work.
   - Rationale: H9 needs both frontend and backend defense; H7/H8 are frontend-local but contract-critical.
3. Start `06-11-creative-async-task-billing-consistency` after backend security branch has stabilized or in an isolated worktree/sub-agent if available.
   - Rationale: highest complexity and likely schema/outbox design; requires careful TDD.
4. Start `06-11-creative-asset-quota-delete-lifecycle-hardening` after asset sync frontend behavior is clear.
   - Rationale: quota/delete/ref transaction changes may involve schema and product/spec reconciliation.
5. Run parent integration verification and dynamic workflow check.

## Required Dynamic Workflow Use

Use dynamic workflows only for verification/check branches unless a later child plan explicitly opts into a read-only investigation workflow.

Post-fix check command to run from `new2fly` after child fixes and deterministic tests:

```bash
codex-flow run .codex-flow/generated/creative-release-blocker-postfix-check.workflow.ts
```

If interrupted, rerun the same command to resume. The workflow must use read-only agents and must journal under `.codex-flow/journal/`.

## Deterministic Validation Commands

Backend targeted tests from `../new-api`:

```bash
GOCACHE=/mnt/f/code/project/new2fly/.cache/go-build \
GOTMPDIR=/mnt/f/code/project/new2fly/.cache/go-tmp \
GOMODCACHE=/home/windc0x/go/pkg/mod \
go test ./middleware ./router ./model ./service ./relay/constant ./relay/common ./relay/channel/task/mj ./controller \
  -run 'Creative|Suno|MJ|Midjourney|Task|Asset|Billing|Idempotency|Relay|Router|Nonce|Cache|Proxy|Forwarded' \
  -count=1
```

Frontend targeted tests from `../opentu`:

```bash
pnpm exec vitest run \
  packages/drawnix/src/services/__tests__/video-api-service.session-broker.test.ts \
  packages/drawnix/src/services/__tests__/audio-api-service.test.ts \
  packages/drawnix/src/services/model-adapters/mj-image-adapter.test.ts \
  packages/drawnix/src/services/creative-document-assets.test.ts \
  packages/drawnix/src/services/provider-routing/provider-transport.session-broker.test.ts \
  apps/web/src/sw/creative-asset-pass-through.spec.ts \
  --no-file-parallelism --maxWorkers=1 --minWorkers=1
```

## Parent Final Check

- [x] All child tasks complete or accepted-risk items documented.
- [x] Deterministic backend/frontend tests pass.
- [x] Dynamic workflow post-fix checks attempted/used across child tasks; latest asset-lifecycle workflow backend timed out and was triaged with deterministic tests/manual review.
- [x] `.trellis/spec` updates made if implementation changes durable contracts.
- [x] User receives final release-readiness summary with fixed / remaining / risk-accepted categories.
