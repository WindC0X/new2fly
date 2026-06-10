# Final Dynamic Verification Matrix — 2026-06-10

## Dynamic workflow

- Workflow: `.codex-flow/generated/creative-remediation-final-dynamic-verification.workflow.ts`
- Journal: `.codex-flow/journal/creative-remediation-final-dynamic-verification.jsonl`
- Result: `overallStatus=fail`
- `dynamicWorkflowComplete=true`
- Parent archive decision: `canArchiveParent=false`

This final verification was run after the user explicitly required the remaining implementation/check work to continue through the dynamic workflow rather than a plain main-thread/Trellis-only path.

## Current status matrix

| Area | Status | Evidence / Notes |
| --- | --- | --- |
| Production `/creative` dist consistency | Fixed / committed earlier | `new-api` commit `f15202c feat(creative): finalize embedded relay remediation`; prior evidence in `sprint1-residual-verification-2026-06-10.md`. |
| Chat creative relay | Fixed / tested earlier | Covered by new-api router/relay tests in prior Sprint1 residual evidence. |
| Image creative relay | Fixed / tested | `/creative/relay/v1/images/generations` exists; local smoke confirms same-origin + CSRF/nonce + forbidden-field gate; allowed body reaches server-side model availability gate. |
| Embedded provider gateway | Partial / tested for supported paths | Opentu targeted tests and browser smoke show session-broker path and no browser upstream key/baseUrl/provider leakage for supported `/creative` requests. |
| Return-to-console UX | Done | Child task `06-08-add-return-to-console-button-in-opentu` archived; Playwright smoke saw button visible and click navigated to `/dashboard`. |
| Cloud binary assets | Done | Child task `06-09-creative-cloud-assets-sync` archived; evidence/commits already recorded. |
| Video relay | Split, not fixed | Child task `06-09-creative-async-video-relay` remains `planning`; PRD now contains acceptance criteria for async billing, CAS refund, idempotency, ownership, and key/channel affinity. |
| Suno relay | Split, not fixed | Child task `06-09-creative-suno-relay` remains `planning`; PRD now contains session-broker, no-model strategy, CAS/refund/idempotency, and key affinity criteria. |
| MJ relay | Split, not fixed | Child task `06-09-creative-mj-relay` remains `planning`; PRD now contains path contract, ownership, idempotency, CAS/refund, proxy, and key affinity criteria. |
| Browser smoke | Partial local pass | Local isolated SQLite smoke covered `/creative`, bootstrap, ReturnButton, image relay security gates, and no obvious `/creative` request credential leakage. It did not cover real upstream generation. |
| `opentu/packages/drawnix/tsconfig.spec.json --noEmit` | Failing | Re-run exits `2`. Current `tsconfig.spec.json` config change reduces failure surface but broad test fixture type debt remains. |

## Commit boundary from final workflow

Allowed to commit:

- `new2fly`:
  - `.trellis/tasks/06-09-creative-async-video-relay/prd.md`
  - `.trellis/tasks/06-09-creative-mj-relay/prd.md`
  - `.trellis/tasks/06-09-creative-suno-relay/prd.md`
  - `.trellis/tasks/06-09-newapi-opentu-creative-remediation/check.jsonl`
  - `.trellis/tasks/06-09-newapi-opentu-creative-remediation/research/browser-smoke-2026-06-10.md`
  - `.trellis/tasks/06-09-newapi-opentu-creative-remediation/research/opentu-tsconfig-spec-2026-06-10.md`
  - `.trellis/tasks/06-09-newapi-opentu-creative-remediation/research/final-dynamic-verification-2026-06-10.md`
- `opentu`:
  - `packages/drawnix/tsconfig.spec.json`

Must exclude:

- `new2fly/.gitignore`
- `new-api/.gitignore`
- `opentu/apps/web/public/version.json`
- `opentu/.ace-tool/`
- `opentu/packages/drawnix/audio-test.pptx`

## Remaining parent gates

The parent task must stay `in_progress` because:

1. Video/Suno/MJ are validly split but their child tasks are still `planning` and not implemented.
2. `opentu/packages/drawnix/tsconfig.spec.json --noEmit` still fails with broad test fixture type debt.
3. Browser smoke is local/no-upstream partial; real upstream generation E2E remains unverified.
4. The media dynamic workflow was sufficient for split evidence but not a green implementation workflow for Video/Suno/MJ.

## Rerun commands

Final dynamic workflow:

```bash
cd /mnt/f/code/project/new2fly
codex-flow run .codex-flow/generated/creative-remediation-final-dynamic-verification.workflow.ts
```

Opentu config/typecheck checks:

```bash
cd /mnt/f/code/project/opentu
git diff --check
NX_DAEMON=false pnpm exec nx run drawnix:typecheck
NX_DAEMON=false pnpm exec nx run web:typecheck
cd packages/drawnix
TMPDIR=/dev/shm pnpm exec tsc -p tsconfig.spec.json --noEmit --pretty false
```
