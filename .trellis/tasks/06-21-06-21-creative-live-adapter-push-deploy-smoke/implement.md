# Implementation plan — push / deploy / smoke

## Phase 1 — preflight

- [x] Confirm no unexpected dirty files in `new-api`, `new2fly`, and `opentu`.
- [x] Confirm expected commits and branches.
- [x] Confirm remote names/branches without printing credentials.

## Phase 2 — push

- [x] Push `new-api` branch `feat/creative-embed` containing `ed0fea4`.
- [x] Push `new2fly` `master` containing task/spec/journal commits.
- [x] Verify remote refs by commit hash where possible.

## Phase 3 — staging deployment planning gate

- [x] Identify exact staging environment and deploy method.
- [x] Confirm staging deployment command and data-preservation risk before execution.
- [x] Confirm staging uses preserved or disposable data according to the user's intent.

## Phase 4 — staging deploy/update

- [x] Update staging code/image to the verified commit.
- [x] Preserve existing staging users/channels/options/storage unless the user explicitly requests reset.
- [x] Verify staging service health and logs.

## Phase 5 — staging smoke

- [x] Run read-only route/header smoke.
- [x] Run authenticated `/creative/api/bootstrap` and `/creative/api/models` smoke.
- [x] Run Creative Model Bindings validate/dry-run smoke without provider call.
- [x] Run browser smoke for logged-in `/creative` model catalog and parameter panel.
- [x] Optional: run mock/no-provider image task smoke. (Playwright route-intercepted no-provider submit smoke run for 21:9 payload/canvas ratio)
- [x] Optional: run real Duomi/GrsAI provider smoke only after explicit authorization.

## Phase 6 — production decision gate

- [x] Summarize staging evidence.
- [x] Ask for separate production authorization only if staging passes. (current gate reached; pending user production decision)
- [ ] If authorized, create/continue a production deploy checklist; otherwise stop at staging-verified.

## Phase 7 — record and finish

- [x] Record pushed refs, deployed commit, smoke evidence, and open risks.
- [x] If code/docs changed, run Trellis check/update-spec/commit/finish-work. (Trellis check fallback run in main session on 2026-06-24; commit/finish-work still pending broader final audit / production decision.)

## Verification commands

Preflight:

```bash
git -C /mnt/f/CODE/Project/new-api status --short
git -C /mnt/f/code/project/new2fly status --short
git -C /mnt/f/CODE/Project/opentu status --short
```

Targeted local regression if needed:

```bash
cd /mnt/f/CODE/Project/new-api
go test -count=1 ./service ./controller ./model ./relay ./relay/common ./relay/constant
cd /mnt/f/CODE/Project/new-api/web/default
pnpm typecheck
pnpm exec eslint src/features/system-settings/models/creative-model-bindings-section.tsx
```

## Phase 8 — runtime lifecycle repair plan

- [x] Consolidate deep-audit findings and user repros into a repair plan.
- [x] Save detailed repair plan: `repair-plan-runtime-lifecycle-2026-06-22.md`.
- [ ] Dispatch Trellis implement sub-agents in the repair-plan order:
  1. backend contract + DTO/rate-limit/durable lifecycle;
  2. OpenTU executor/retry/resume;
  3. cache/canvas success gate;
  4. dimensions/provider contracts;
  5. viewport/minor insertion consistency.
- [ ] Dispatch Trellis check sub-agents after each implementation slice.
- [x] Repair v9c runtime lifecycle findings for generated-image metadata persistence, anchor error sanitization, TaskItem memo comparator, and unified cache metadata merge. Evidence: `runtime-lifecycle-fix-result-2026-06-23.md`.
- [x] Repair v10 postfix findings RLC-001 through RLC-005. Evidence: `runtime-lifecycle-fix-result-2026-06-23.md`.
- [x] Repair v13/v13b confirmed findings: backend Creative timeout sweep deferral, billing outbox log idempotency, frontend recoverable Creative timeout, live binding hidden-gate removal, default canary group, and selected-frame metadata propagation. Evidence: `runtime-lifecycle-fix-result-2026-06-23.md`.
- [x] Repair v14 confirmed findings: stored live binding POST route gate no longer depends on hidden preview flag; frontend recoverable polling timeout now schedules delayed resume. Evidence: `runtime-lifecycle-fix-result-2026-06-23.md`.
- [x] Run no-secrets release gate after v14 fixes: `python3 scripts/creative_release_gate.py check --run-new-api-tests --source-diff-check`.
- [x] Repair v17/v18 postfix findings: stale guarded Creative progress writes and missing embedded no-provider Playwright lifecycle E2E. Evidence: `runtime-lifecycle-fix-result-2026-06-23.md`.
- [x] Run isolated local new-api no-provider embedded E2E with Nx cache disabled: `NX_SKIP_NX_CACHE=true CREATIVE_EMBEDDED_BASE_URL=http://127.0.0.1:<temp-port>/creative/ pnpm e2e:creative-embedded` — PASS 3/3.
- [x] Repair v19 embedded E2E viewport persistence finding: cache-miss rehydrate board `onChange` no longer persists non-user runtime viewport noise over restored viewport. Evidence: `runtime-lifecycle-fix-result-2026-06-23.md`.
- [x] Rebuild/sync embedded dist after v19 and rerun isolated local no-provider embedded E2E with Nx cache disabled — PASS 4/4.
- [x] Run no-secrets release gate after v19 with embedded smoke URL: `python3 scripts/creative_release_gate.py check --run-new-api-tests --source-diff-check --embedded-smoke-url http://127.0.0.1:<temp-port>/creative/` — PASS.
- [x] Repair v20 final-audit priority findings: bounded Creative image submit interruption, transient status-fetch polling retry, and Creative binding helper model_mapping tolerance. Evidence: `runtime-lifecycle-fix-result-2026-06-23.md`.
- [x] Rebuild/sync embedded dist after v20 and rerun isolated local no-provider embedded E2E with Nx cache disabled — PASS 4/4.
- [x] Run no-secrets release gate after v20 with embedded smoke URL: `python3 scripts/creative_release_gate.py check --run-new-api-tests --source-diff-check --embedded-smoke-url http://127.0.0.1:<temp-port>/creative/` — PASS.
- [x] Main-session verify v21 final-audit findings and record verdicts: accepted OTU-ABORT-001, OTU-SYNC-001, OTU-IDEMP-001, OTU-CACHE-001, REL-PROV-001, REL-GATE-001, REL-STAGE-001; rejected OTU-VIDEO-001 as already covered. Evidence: `final-goal-audit-v21-main-verification-2026-06-23.md`.
- [x] Repair v21 accepted runtime findings: post-remote-accept abort remains recoverable, retry-scoped managed image idempotency key, stale storage sync attempt guard, bounded generated-image content rehydrate retry. Evidence: `runtime-lifecycle-fix-result-2026-06-23.md`.
- [x] Run v21 targeted/broader OpenTU tests and typechecks — PASS: media-executor, task-queue-service-image-retry, generated-media-cache, useAutoInsertToCanvas, useTaskExecutor, task-utils; spec tsc; drawnix/web typecheck.
- [x] Rebuild/sync embedded dist after v21 and run no-secrets release gate: `python3 scripts/creative_release_gate.py build-sync-check --run-new-api-tests --source-diff-check` — PASS.
- [x] Run isolated local no-provider embedded E2E after v21 with Nx cache disabled — PASS 4/4.
- [x] Run no-secrets release gate after v21 with embedded smoke URL: `python3 scripts/creative_release_gate.py check --run-new-api-tests --source-diff-check --embedded-smoke-url http://127.0.0.1:<temp-port>/creative/` — PASS, embedded E2E executed 4/4.
- [ ] Run final dynamic workflow re-audit with the runtime lifecycle gates before any production deployment. (v21 fixes, no-provider embedded E2E, typechecks, targeted unit tests, and release gate verified locally; final dynamic workflow audit pending)

## 2026-06-23 v22 final audit follow-up

- v22 dynamic workflow first run is not complete: synthesis/verifier require rerunning four timeout/null branches.
- Main-session verification accepted `RLC-FINAL-001` as HIGH: Creative live image submit currently uses the browser request context for provider submission, so a client cancel/timeout after provider acceptance can leave a durable task without `UpstreamTaskID`; polling/GET skip it until ambiguous timeout and cannot recover late success.
- Verification record: `final-goal-audit-v22-main-verification-2026-06-23.md`.
- [x] Repair `RLC-FINAL-001`: post-durable live Creative image provider submit now uses a detached bounded context; RED/GREEN regression added for client cancel after provider accept; backend controller/service/model/relay package tests passed. Evidence: `runtime-lifecycle-fix-result-2026-06-23.md`.
- Next slice: rerun four v22 timeout/null audit branches in smaller dynamic workflows, synthesize, verifier-check, then main-session verify any material findings.
- [x] Repair v22c/v22d accepted OpenTU findings: stale storage sync `updatedAt` monotonic guard, restore retry-attempt guard, task-storage `startedAt` guarded writes, and buffered generated image cache-miss recovery while task storage is not ready. Evidence: `runtime-lifecycle-fix-result-2026-06-23.md`.
- [x] Run v22c/v22d targeted and broader OpenTU verification: task queue/storage/cache-miss tests, media executor/auto insert/task executor/generated cache/task utils tests, spec tsc, drawnix typecheck, web typecheck.
- [ ] Run post-fix dynamic workflow re-audit for OpenTU retry/storage/cache-canvas lifecycle; split/resume timeout/null branches until verifier is valid, then main-session verify material findings.
- [x] Repair v23a accepted storage-writer propagation findings: guarded `updateStatus`, boolean guarded write results, resumed video stale callback suppression, and guarded status/progress propagation. Evidence: `runtime-lifecycle-fix-result-2026-06-23.md` and `final-goal-audit-v23-main-verification-2026-06-24.md`.
- [x] Run v23a targeted/split broader OpenTU verification: task-storage-writer/media-executor RED→GREEN, task-queue retry suite, 7-file lifecycle/cache/canvas suite, spec tsc, drawnix typecheck, web typecheck.
- [x] Main-session verify v23b cache/canvas dynamic workflow findings and record verdicts. Evidence: `final-goal-audit-v23b-main-verification-2026-06-24.md`.
- [x] Repair v23b accepted cache/canvas/runtime lifecycle findings: video cache-miss recovery, transient pending retry, bounded board-scoped pending buffer, durable workflow taskId persistence, and video history thumbnail fallback. Evidence: `runtime-lifecycle-fix-result-2026-06-23.md`.
- [x] Run v23b targeted/broader OpenTU verification: cache-miss recovery/history/video/workflow durable tests, generated-cache/asset-cleanup/retry-image/workflow tests, combined 13-file lifecycle/cache/canvas regression, spec tsc, drawnix typecheck, web typecheck.
- [x] Continue split dynamic workflow re-audit for v23c retry/resume state machine, then synthesize and main-session verify material findings. Evidence: `final-goal-audit-v23c-main-verification-2026-06-24.md`.


## 2026-06-24 v23c residual repair status

- [x] Repair confirmed v23c HIGH synthesis findings: submit-interrupted image retry reuses original idempotency key; workflow recovery emits `recovered`; video cache-miss recovery resets component error state, carries board scope, and treats incomplete video content as 409 retryable.
- [x] Repair confirmed video history `previewImageUrl` fallback gap.
- [x] Run targeted OpenTU Vitest, OpenTU spec/drawnix/web type gates, and new-api controller tests.
- [x] Repair residual same-writer `TaskStorageWriter` guarded write race with per-task serialization and first-terminal-wins regression.
- [x] Repair video side of residual non-image remoteId durable barrier: async `onSubmitted` contract, awaited video adapter submitted callbacks, and media-executor regression coverage.
- [x] Run combined v23c lifecycle regression suite after TaskStorageWriter/video durable-barrier repairs — PASS 7 files / 82 tests.
- [x] Re-run OpenTU spec/drawnix/web type gates after video durable-barrier repairs — PASS.
- [x] Repair residual audio remoteId durable barrier and audio stale/cancel paths: audio TIMEOUT+remoteId retry resumes existing remote task; audio polling submit/query/sleep consume AbortSignal; audio callbacks use top-level awaited contract; legacy audio generate/resume callbacks are attempt-guarded after retry; targeted lifecycle tests and type gates PASS. Evidence: `runtime-lifecycle-fix-result-2026-06-23.md`.
- [x] Run focused dynamic workflow re-audit for repaired blockers (IMG-001, IMG-002, VID-001, AUD-001/AUD-002); branches completed but synthesis failed/null. Main-session verified accepted findings and repaired IMG-002/AUD-001/AUD-002 residuals with RED→GREEN tests and type gates PASS. Evidence: `runtime-lifecycle-fix-result-2026-06-23.md`.
- [x] Resume or rerun focused workflow/synthesis after v25 repairs; split/resume timeout/null branches until verifier is valid, then main-session verify material findings. v27/v28 valid branch+synthesis outputs close IMG-002/AUD-001/AUD-002 with `mustFix=[]`; main-session verification agrees. Evidence: `runtime-lifecycle-fix-result-2026-06-23.md`.
- [x] Run Trellis check fallback after v27/v28 closure: OpenTU focused Vitest 7 files / 102 tests PASS, OpenTU `tsconfig.spec` + `drawnix:typecheck` + `web:typecheck` PASS, new-api Go regression PASS, new-api admin frontend typecheck/eslint PASS, no-secrets Creative release gate PASS. Evidence: `runtime-lifecycle-fix-result-2026-06-23.md`.
- [x] Run broader final goal audit with dynamic workflow, not relying on previous reports. v29/v30 had null/timeout synthesis gaps and were not counted as pass; v31 compact synthesis+verification completed with verdict `needs-fix`. Evidence: `runtime-lifecycle-fix-result-2026-06-23.md`.
- [x] Repair v31 high-priority video findings `MF-002`/`MF-003`/`MF-004`: video remoteId onSubmitted bridge, AbortSignal polling contract, and stable video cache URL materialization. Evidence: `runtime-lifecycle-fix-result-2026-06-23.md`.
- [x] Repair v31 medium findings `MF-005` and `MF-006`: generated media cache-miss coverage / durable video metadata propagation, ordinary SW cache-miss notification, and catalog bootstrap retry after transient unauthorized/error. Evidence: `runtime-lifecycle-fix-result-2026-06-23.md`.
- [x] Main-session verify v36 final-audit findings and repair accepted contained issues: OpenTU video display rehydrate consumers, new-api executable sync-route gate, Suno raw-data content proxying, explicit unrecoverable image submit expiry, and deterministic controller regression. Evidence: `final-goal-audit-v36-main-verification-2026-06-24.md` and `runtime-lifecycle-fix-result-2026-06-23.md`.
- [x] Run v36 targeted verification: OpenTU prompt-history/VideoPosterPreview Vitest, OpenTU `tsconfig.spec`, new-api controller/service/relay Go tests — PASS.
- [x] Run v36 local embedded smoke/provenance against disposable local new-api: release artifact check + source diff check + `pnpm e2e:creative-embedded` PASS 4/4, including slow-provider timing and refresh/Cache Storage E2E.
- [x] Close v31 provenance/staging gate (`MF-007`): rebuild/sync release artifacts, source/artifact diff gate, local embedded smoke, and post-migration local Docker staging smoke are PASS as of v36 plus 2026-06-24 SQLite migration repair. Production/VPS remains a separate gate.
