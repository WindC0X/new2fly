# Runtime lifecycle fix result — 2026-06-23

## Scope

Continued the v9c runtime lifecycle repair after backend submit-in-flight guard and frontend remote TIMEOUT recovery.

This slice fixed:

1. Generated image rehydrate metadata end-to-end persistence.
2. Image generation anchor error sanitizer bypass.
3. TaskItem memo comparator drift.
4. Unified cache metadata wrapper/top-level merge drift.

## Changes

### Generated image metadata persistence

OpenTU now carries generated-image rehydrate metadata through:

- auto insert (`useAutoInsertToCanvas`)
- grouped image insertion (`insertImageGroup`)
- prompt+result insertion (`insertAIFlow` call sites)
- frame insertion (`insertMediaIntoFrame` / `insertMediaIntoSelectedFrame`)
- manual task-list insertion (`insertDialogTaskResultToBoard`)
- generation history thumbnails (`useGenerationHistory` + `RetryImage` props)
- cache miss recovery from durable canvas node metadata (`useGeneratedMediaCacheMissRecovery`)
- direct image insertion (`insertImageFromUrl` metadata final arg)
- quick media insertion (`quickInsertCanvasMedia` metadata final arg)

Canvas nodes persist only safe generated-image fields:

- `contentUrl`
- `remoteTaskId`
- `providerTaskId`
- `mimeType`

Task/history/cache rehydrate metadata may additionally carry safe local context such as `taskId`, `prompt`, `model`, and `params` where needed for IndexedDB/cache metadata.

### Anchor error sanitizer

`useImageGenerationAnchorSync` now sanitizes the selected anchor error source via `sanitizeTaskErrorDisplayMessage(..., '生成失败')` before it is stored back into the anchor state. This prevents provider URLs, authorization material, callback/webhook/notify-hook text, object storage hints, or token-like strings from being rendered by the anchor UI.

### TaskItem memo comparator

`areTaskItemPropsEqual` now uses immutable task-object identity plus all control/callback prop identities. This avoids stale rendering when fields such as `remoteId`, `params`, `result`, route metadata, or other rendered task fields change but the previous narrow comparator did not include them.

### Unified cache metadata merge

`unifiedCacheService.cacheMediaFromBlob` now normalizes both legacy top-level metadata calls and wrapped `{ metadata, cachedAt, lastUsed, contentHash }` calls. If callers pass both top-level `taskId`/`prompt`/`model`/`params` and nested `metadata`, the final persisted metadata merges the top-level safe fields into the nested metadata instead of silently dropping them.

## Verification

### Frontend targeted tests

Command:

```bash
cd /mnt/f/code/project/opentu
pnpm vitest run --no-file-parallelism --maxWorkers=1 --minWorkers=1 \
  packages/drawnix/src/hooks/__tests__/useGeneratedMediaCacheMissRecovery.test.tsx \
  packages/drawnix/src/hooks/__tests__/useAutoInsertToCanvas.test.ts \
  packages/drawnix/src/components/task-queue/dialog-task-insert.test.ts \
  packages/drawnix/src/hooks/__tests__/useGenerationHistory.test.ts
```

Result: PASS — 4 files, 28 tests.

Command:

```bash
cd /mnt/f/code/project/opentu
pnpm vitest run --no-file-parallelism --maxWorkers=1 --minWorkers=1 \
  packages/drawnix/src/hooks/__tests__/useImageGenerationAnchorSync.test.ts \
  packages/drawnix/src/components/task-queue/TaskItem.memo.test.ts
```

Result: PASS — 2 files, 12 tests.

Command:

```bash
cd /mnt/f/code/project/opentu
pnpm vitest run --no-file-parallelism --maxWorkers=1 --minWorkers=1 \
  packages/drawnix/src/hooks/__tests__/useTaskExecutor.test.ts \
  packages/drawnix/src/utils/__tests__/task-utils.test.ts \
  packages/drawnix/src/hooks/__tests__/useGeneratedMediaCacheMissRecovery.test.tsx \
  packages/drawnix/src/hooks/__tests__/useAutoInsertToCanvas.test.ts \
  packages/drawnix/src/components/task-queue/dialog-task-insert.test.ts \
  packages/drawnix/src/hooks/__tests__/useGenerationHistory.test.ts \
  packages/drawnix/src/hooks/__tests__/useImageGenerationAnchorSync.test.ts \
  packages/drawnix/src/services/creative-error-sanitizer.test.ts \
  packages/drawnix/src/components/task-queue/TaskItem.memo.test.ts
```

Result: PASS — 9 files, 52 tests.

Notes: pnpm emitted the existing `.npmrc` `${NPM_TOKEN}` warning. Some tests also emitted existing jsdom/crypto/indexedDB environmental warnings, but assertions passed.

### Frontend typecheck

Command:

```bash
cd /mnt/f/code/project/opentu
pnpm nx run drawnix:typecheck
```

Result: PASS.

Command:

```bash
cd /mnt/f/code/project/opentu
pnpm nx run web:typecheck
```

Result: PASS.

### Diff whitespace check for touched OpenTU files

Command:

```bash
git -C /mnt/f/code/project/opentu diff --check -- <touched runtime lifecycle files>
```

Result: PASS.

### Backend targeted checks

Command:

```bash
cd /mnt/f/code/project/new-api
go test -count=1 ./model ./service ./controller
```

Result:

- PASS: `./model`
- PASS: `./service`
- FAIL: `./controller` due to existing unrelated failure `TestCreativeRelayMJImageFallbackClientBlocksUnsafeRedirect` expecting 500 and receiving 502. This was already known before this slice.

Command:

```bash
cd /mnt/f/code/project/new-api
go test -count=1 ./controller -run 'TestCreativeImageTaskSubmitLive(BindingUsesLockedChannelAndSanitizedDTO|TimeoutStaysPendingAndReplaysTask|GrsAILiveForcesAsyncAndBearerAuth)'
```

Result: PASS.

## Remaining gate

Per user requirement, run a dynamic workflow re-audit after this repair and have the main session verify any findings rather than accepting them blindly.

## V10 postfix repair — 2026-06-23

Source audit artifacts:

- `runtime-lifecycle-postfix-v10-branch-results-2026-06-23.{json,md}`
- `runtime-lifecycle-postfix-v10-synthesis-2026-06-23.{json,md}`

Main-session verification confirmed RLC-001 through RLC-004 as real runtime lifecycle defects and RLC-005 as a low-risk config validation drift. All five were addressed in this slice.

### RLC-001 — managed image poll timeout is recoverable

- `fallback-adapter-routes.ts` now throws a typed `CreativeImageTaskTimeoutError` with `code/name = TIMEOUT` when the managed image polling budget expires.
- `executeCreativeManagedImageTask` persists timeout failures with `code: TIMEOUT` instead of generic `IMAGE_GENERATION_ERROR`.
- `useTaskExecutor` now preserves `error.code` before falling back to HTTP status/name, so failed remote tasks remain classified as recoverable.

### RLC-002 — refresh during submit reuses original idempotency path

- Added `isRecoverableCreativeManagedImageSubmissionTask`.
- `useTaskStorage` now requeues interrupted Creative managed image submissions from `PROCESSING/SUBMITTING` back to `PENDING/SUBMITTING` without creating a retry attempt. This preserves the original local task id and therefore the original `opentu-image-${task.id}` idempotency key.

### RLC-003 — generated-image insertion paths preserve durable rehydrate metadata

Metadata propagation was added for image insertion from:

- task queue manual insert;
- media viewport quick insert;
- media library insert;
- grouped PPT slide auto-insert.

These paths now pass safe generated-image metadata into canvas insertion/cache helpers so refresh and task-history restoration can recover generated assets instead of producing blank nodes or broken thumbnails.

### RLC-004 — retry action distinguishes resume from regenerate

`task-queue-service.retryTask` now detects recoverable failed Creative remote image tasks. For those tasks it:

- keeps `remoteId` and `retryAttempt` intact;
- moves the task back to `PROCESSING/POLLING`;
- avoids calling `generateImage` / creating a new provider task;
- lets the executor resume polling the existing remote task.

Fresh regeneration remains available for completed/manual retry paths.

### RLC-005 — GrsAI nano-banana schema contract drift closed

`creativeValidateRequiredAdapterParameterSchemaContract` now covers `grsai_live|grsai_nano_banana`:

- requires visible `aspectRatio` and `imageSize` fields;
- enforces labels (`比例`, `尺寸档位`);
- enforces exact option sets per provider model family;
- allows the extended `1:4/4:1/1:8/8:1` ratios only for `nano-banana-2` variants.

The allowed-values validation now shares the same ordered option source as the required contract.

### Additional test isolation fix

The backend broadened targeted suite exposed a deterministic-test bug in `TestCreativeRelayMJImageFallbackClientBlocksUnsafeRedirect`: it depended on overriding `http.DefaultTransport`, but the shared service HTTP client may already be initialized by earlier tests. The test now uses a local proxy server configured through channel settings, so redirect-block behavior is tested without real network access or suite-order dependence.

## V10 verification

Frontend targeted runtime lifecycle tests:

```bash
cd /mnt/f/code/project/opentu
pnpm vitest run --no-file-parallelism --maxWorkers=1 --minWorkers=1 \
  packages/drawnix/src/services/__tests__/media-executor.test.ts \
  packages/drawnix/src/utils/__tests__/task-utils.test.ts \
  packages/drawnix/src/hooks/__tests__/useTaskStorage.test.ts \
  packages/drawnix/src/services/__tests__/task-queue-service-image-retry.test.ts \
  packages/drawnix/src/hooks/__tests__/useAutoInsertToCanvas.test.ts
```

Result: PASS — 5 files, 71 tests.

Frontend typecheck:

```bash
cd /mnt/f/code/project/opentu
pnpm nx run drawnix:typecheck
pnpm nx run web:typecheck
```

Result: PASS for both targets.

Backend nano-banana contract tests:

```bash
cd /mnt/f/code/project/new-api
go test ./service -run 'TestCreativeLiveBindingRejectsUnsupportedNanoBananaAllowedValues|TestBuildCreativeModelBindingsDryRunMirrorsNanoBananaAutoOmission'
```

Result: PASS.

Backend Creative/Task/Channel targeted suite:

```bash
cd /mnt/f/code/project/new-api
go test ./service ./controller ./model ./relay -run 'Creative|Task|Channel|Polling|ModelCapability|ImageAdapter'
```

Result: PASS.

## Remaining gate

Run a post-v10 dynamic workflow re-audit focused on development-goal attainment and new runtime lifecycle regressions. Main session must verify any workflow findings before declaring this repair complete.

## V13 split / v13b synthesis repair — 2026-06-23

Source audit artifacts:

- `.codex-flow/generated/creative-runtime-lifecycle-postfix-v13-split-reaudit-2026-06-23.workflow.ts`
- `.codex-flow/journal/creative-runtime-lifecycle-postfix-v13-split-reaudit-2026-06-23.jsonl`
- `.codex-flow/generated/creative-runtime-lifecycle-postfix-v13b-synthesis-2026-06-23.workflow.ts`
- `.codex-flow/journal/creative-runtime-lifecycle-postfix-v13b-synthesis-2026-06-23.jsonl`

Main-session verification confirmed and fixed these material findings:

### B4-01 / RUNTIME-TIMEOUT-001 — backend global timeout must not preempt Creative provider-submit state

- `new-api/service/task_polling.go` now defers global `sweepTimedOutTasks` for Creative tasks in provider-submit in-flight / ambiguous states.
- Ownership of those states stays with the Creative image polling state machine, which has the longer provider-aware recovery window.
- Regression: `TestSweepTimedOutTasksDefersCreativeProviderSubmitStates`.

### B4-02 — billing outbox log/stats side effects are idempotent after crash windows

- `model.Log` now carries `TaskBillingOutboxID` with a unique index.
- `EnsureTaskBillingOutboxLog`/`buildTaskBillingLog` make log creation idempotent by outbox id.
- `completeTaskBillingOutboxLogEffects` updates user/channel used stats and `log_done` in one DB transaction.
- Regression: `TestTaskBillingOutboxConsumeLogCrashAfterLogBeforeStatsRecoversOnce` plus expanded settle tests.

### RUNTIME-TIMEOUT-001/002 — frontend Creative managed image timeout is recoverable, not terminal

- `isTaskTimeout` now excludes both Creative managed remote image tasks and Creative managed submit-interrupted image tasks.
- `executeCreativeManagedImageTask` and outer task execution keep Creative remote poll-budget expiry recoverable: they preserve the task as `PROCESSING/POLLING` with progress 95 and do not write terminal `FAILED`.
- `useTaskExecutor` now applies the same timeout handling on refresh/resume, so a slow provider can still be recovered by backend status/content routes after frontend polling budget expiry.
- Regressions added/updated in `task-utils.test.ts`, `media-executor.test.ts`, `useTaskExecutor.test.ts`, and `task-queue-service-image-retry.test.ts`.

### CFG-001 — stored live Creative bindings must not depend on hidden preview gate

- `GetStoredCreativeModelBindingsCatalogForGroup` no longer globally depends on `creative.adapter.enabled`.
- Stored live bindings are controlled by binding enabled state, modality, binding canary group, live adapter preset, locked channel id, and channel readiness.
- Mock/built-in preview bindings still require `creative.adapter.enabled` and mock route enablement.
- `ResolveCreativeImageModelBindingForGroup` mirrors this split: live stored bindings resolve without the hidden preview gate; mock/built-in preview remains fail-closed.
- Regression: `TestStoredLiveCreativeModelBindingDoesNotRequirePreviewGate` plus existing preview-gate tests.

### CFG-002 — admin binding template should default to a valid group

- `web/default/src/features/system-settings/models/creative-model-bindings-section.tsx` now defaults new binding templates to `canaryGroups: ['default']` instead of `['test']`.
- This avoids creating an enabled config that the backend validator rejects because the default usable groups are `default`/`vip`.

### FIND-003 — selected-frame insertion path preserves generated-image rehydrate metadata

- `executeCanvasInsertion` and the MCP canvas insertion path now pass `item.metadata` into `insertMediaIntoSelectedFrame`.
- Selected-frame image insertion stores safe generated-image metadata (`contentUrl`, `remoteTaskId`, `providerTaskId`, `mimeType`) on the canvas image node.
- Regressions: `canvas-insertion.test.ts` and `frame-insertion-utils.test.ts`.

### Explicit policy not changed in this slice

- Materialize failure remains fail-closed/refund by current backend policy. The v13 finding was confirmed as a product-policy decision, not fixed here, because changing transient storage/content failure semantics requires a separate design that preserves provider URL and signed URL security boundaries.

## V13 repair verification

Backend targeted tests:

```bash
cd /mnt/f/code/project/new-api
go test ./service -run 'TestSweepTimedOutTasksDefersCreativeProviderSubmitStates|TestTaskBillingOutboxSubmitSettleAdjustsPreConsumeDelta|TestTaskBillingOutboxConsumeLogCrashAfterLogBeforeStatsRecoversOnce'
go test ./service -run 'TaskBillingOutbox|SweepTimedOutTasks|CollectPollingTaskBuckets|CreativeImageSubmitInFlight|CreativeImageAmbiguous'
go test ./service ./controller ./model ./relay -run 'Creative|Task|Channel|Polling|ModelCapability|ImageAdapter'
go test ./service -run 'CreativeModelBindings|CreativeAdapter|LiveBinding|TaskBillingOutbox|SweepTimedOutTasks'
```

Result: PASS.

Frontend targeted runtime lifecycle tests:

```bash
cd /mnt/f/code/project/opentu
pnpm vitest run --no-file-parallelism --maxWorkers=1 --minWorkers=1 \
  packages/drawnix/src/utils/__tests__/task-utils.test.ts \
  packages/drawnix/src/services/__tests__/media-executor.test.ts \
  packages/drawnix/src/hooks/__tests__/useTaskExecutor.test.ts \
  packages/drawnix/src/hooks/__tests__/useTaskStorage.test.ts \
  packages/drawnix/src/services/__tests__/task-queue-service-image-retry.test.ts \
  packages/drawnix/src/utils/__tests__/frame-insertion-utils.test.ts \
  packages/drawnix/src/services/canvas-operations/__tests__/canvas-insertion.test.ts
```

Result: PASS — 7 files, 74 tests.

Frontend typecheck:

```bash
cd /mnt/f/code/project/opentu
pnpm nx run drawnix:typecheck
pnpm nx run web:typecheck
```

Result: PASS for both targets.

New API admin UI checks:

```bash
cd /mnt/f/code/project/new-api/web/default
pnpm typecheck
pnpm exec eslint src/features/system-settings/models/creative-model-bindings-section.tsx
```

Result: PASS.

Embedded dist/release gate:

```bash
cd /mnt/f/code/project/new2fly
python3 scripts/creative_release_gate.py build-sync-check
python3 scripts/creative_release_gate.py check --run-new-api-tests --source-diff-check
```

Result: PASS. The gate verified embedded artifact identity, no sourcemaps, source diff hygiene, `new-api` package tests, and `go build ./...`.

## Remaining gate

Run a new dynamic workflow final audit focused on development-goal attainment and new runtime lifecycle regressions. The workflow must include slow-provider timing, cross-layer state-machine synthesis, and refresh/retry/Cache Storage lifecycle gates. Main session must verify all material findings before declaring the project ready.

## V13/V14 follow-up repairs — 2026-06-23

Source audit artifact:

- `.codex-flow/generated/creative-runtime-lifecycle-final-goal-audit-v14-2026-06-23.workflow.ts`
- `.codex-flow/journal/creative-runtime-lifecycle-final-goal-audit-v14-2026-06-23.jsonl`

Main-session verification confirmed two additional material runtime defects from the v14 synthesis and repaired them in this slice.

### BACKEND-BINDING-001 — stored live bindings were still blocked by hidden preview gate

`controller/creative_image_tasks.go` now distinguishes live stored bindings from mock/builtin preview routes:

- GET status/content remains allowed through the image task route gate.
- POST submit is allowed when the submitted model resolves to a stored live Creative model binding whose adapter preset is live.
- Mock/builtin preview submits still require `creative.mock_image_tasks.enabled` or `creative.adapter.enabled`.

Regression evidence:

```bash
cd /mnt/f/code/project/new-api
go test ./controller -run 'TestCreativeImageTaskSubmitLiveBindingUsesLockedChannelAndSanitizedDTO|TestCreativeImageTaskRouteRejectsWhenMockPreviewDisabledByDefault|TestCreativeImageTaskRouteBoundariesAndResolverFailClosed'
```

Result: PASS.

### FE-EXEC-001 — frontend remote timeout preserved PROCESSING but did not reschedule polling

`packages/drawnix/src/hooks/useTaskExecutor.ts` now schedules a bounded delayed resume after a recoverable Creative managed image polling timeout:

- timeout leaves the task in `PROCESSING/POLLING` instead of terminal failure;
- a 30s timer re-enqueues only if the same task/remote id is still recoverable and not already executing;
- terminal success/failure/cancel and component cleanup clear pending timers.

Regression evidence:

```bash
cd /mnt/f/code/project/opentu
pnpm vitest run --no-file-parallelism --maxWorkers=1 --minWorkers=1 packages/drawnix/src/hooks/__tests__/useTaskExecutor.test.ts
```

Result: PASS.

Broader frontend lifecycle evidence:

```bash
cd /mnt/f/code/project/opentu
pnpm vitest run --no-file-parallelism --maxWorkers=1 --minWorkers=1 \
  packages/drawnix/src/utils/__tests__/task-utils.test.ts \
  packages/drawnix/src/services/__tests__/media-executor.test.ts \
  packages/drawnix/src/hooks/__tests__/useTaskExecutor.test.ts \
  packages/drawnix/src/hooks/__tests__/useTaskStorage.test.ts \
  packages/drawnix/src/services/__tests__/task-queue-service-image-retry.test.ts \
  packages/drawnix/src/utils/__tests__/frame-insertion-utils.test.ts \
  packages/drawnix/src/services/canvas-operations/__tests__/canvas-insertion.test.ts
```

Result: PASS — 7 files, 74 tests.

Frontend typecheck evidence:

```bash
cd /mnt/f/code/project/opentu
pnpm nx run drawnix:typecheck
pnpm nx run web:typecheck
```

Result: PASS for both targets.

Backend Creative/Task/Channel targeted evidence:

```bash
cd /mnt/f/code/project/new-api
go test ./service ./controller ./model ./relay -run 'Creative|Task|Channel|Polling|ModelCapability|ImageAdapter'
```

Result: PASS.

### Embedded artifact sync after frontend change

Because OpenTU source changed, the embedded Creative dist was rebuilt and synchronized.

```bash
cd /mnt/f/code/project/new2fly
python3 scripts/creative_release_gate.py build-sync-check
```

Result: PASS — OpenTU dist, `new-api/web/creative/dist`, and `new-api/router/web/creative/dist` are synchronized; no sourcemaps; embedded artifact contract holds.

## Release gate check — 2026-06-23

Fresh no-secrets release gate check after the V13/V14 follow-up repairs:

```bash
cd /mnt/f/code/project/new2fly
python3 scripts/creative_release_gate.py check --run-new-api-tests --source-diff-check
```

Result: PASS — embedded artifact contract, diff whitespace checks, new-api targeted tests, and `go build ./...` completed successfully.

Important remaining caveat: this gate does not resolve the release provenance finding that the OpenTU source tree is dirty while `version.json.gitCommit` points to a committed OpenTU HEAD. Treat that as a release-readiness/provenance blocker, not as a runtime lifecycle defect.

## Remaining gates after V13/V14 follow-up

- Run a split dynamic workflow continuation for the v14 branches that timed out: cache/canvas/refresh/display and model/params/channel UI.
- Run a separate verifier/synthesis pass for the repaired backend live-binding gate and frontend timeout resume behavior.
- Main session must verify any new workflow findings against code/tests before accepting them.
- `BACKEND-LIFECYCLE-001` remains a design item: if provider submit transport times out after the provider accepted the task but before the backend receives an upstream id, there is no safe generic retry without provider correlation/reconciliation. Do not patch this with blind resubmit logic.

## V17/V18 postfix repair and no-provider E2E gate — 2026-06-23

Main-session verification accepted the remaining v18 findings as real and closed the two code/test gaps in this slice.

### RLC-STALE-PROGRESS-001 — stale recoverable timeout progress writes

`packages/drawnix/src/services/media-executor/task-storage-writer.ts` now supports guarded `updateProgress(...)` writes. The managed Creative timeout recovery path passes the task retry-attempt guard so a late timeout/progress write from an older execution cannot overwrite a newer retry attempt or a terminal task.

Regression evidence:

```bash
cd /mnt/f/code/project/opentu
pnpm vitest run --no-file-parallelism --maxWorkers=1 --minWorkers=1 \
  packages/drawnix/src/services/__tests__/task-storage-writer.test.ts \
  packages/drawnix/src/services/__tests__/media-executor.test.ts \
  packages/drawnix/src/services/__tests__/task-queue-service-image-retry.test.ts
```

Result: PASS — 3 files, 47 tests.

### E2E-GATE-MISSING — embedded refresh/resume/cache lifecycle gate

Added `apps/web-e2e/src/embedded/creative-lifecycle.spec.ts`, a no-provider Playwright gate for the embedded `/creative/` build. It mocks only same-origin Creative broker endpoints and covers:

- refresh resumes a remote Creative image task without opening generation UI;
- completed content is materialized into Cache Storage `drawnix-images`;
- unified cache metadata preserves local task id plus remote/content metadata;
- completed canvas media cache-miss recovery rehydrates generated media;
- canvas image URL is cache-busted after rehydrate;
- board elements and viewport survive refresh instead of being overwritten by empty metadata fallback.

During the first real E2E run, the gate caught two test-harness issues before being accepted:

1. the original 1x1 PNG fixture could not be decoded by Chromium `createImageBitmap`, causing the runtime to correctly mark the task failed with `The source image could not be decoded`; the fixture was replaced with a generated PNG verified by Chromium;
2. the unified cache assertion incorrectly expected `metadata.taskId` to be the remote provider id; the product contract stores the local task id in `taskId` and the provider id in `remoteTaskId`, so the assertion was corrected.

E2E typecheck evidence:

```bash
cd /mnt/f/code/project/opentu
pnpm exec tsc --noEmit --project apps/web-e2e/tsconfig.json --pretty false
```

Result: PASS.

Full frontend local gate evidence after the stale-progress repair:

```bash
cd /mnt/f/code/project/opentu
pnpm exec tsc --noEmit --project packages/drawnix/tsconfig.spec.json --pretty false
pnpm exec tsc --noEmit --project apps/web-e2e/tsconfig.json --pretty false
pnpm vitest run --no-file-parallelism --maxWorkers=1 --minWorkers=1 \
  packages/drawnix/src/services/__tests__/task-storage-writer.test.ts \
  packages/drawnix/src/services/__tests__/media-executor.test.ts \
  packages/drawnix/src/services/__tests__/task-queue-service-image-retry.test.ts
pnpm nx run drawnix:typecheck
pnpm nx run web:typecheck
```

Result: PASS. Notes: pnpm emitted the existing `.npmrc` `${NPM_TOKEN}` warning; Vitest emitted existing `localStorage is not defined` crypto initialization warnings in media-executor tests, but assertions passed.

### No-secrets embedded release gate and E2E execution

Because OpenTU runtime source changed, the embedded Creative dist was rebuilt and synchronized again.

```bash
cd /mnt/f/code/project/new2fly
python3 scripts/creative_release_gate.py build-sync-check
python3 scripts/creative_release_gate.py check --run-new-api-tests --source-diff-check
```

Result: PASS — `build:web`, embedded dist sync, artifact contract, diff whitespace checks, new-api package tests, and `go build ./...` completed successfully.

The embedded Playwright gate was then run against an isolated local `new-api` binary with temporary SQLite/logs and no provider credentials. The first `pnpm e2e:creative-embedded` invocation reused an Nx cache entry from the previous skipped run, so it was discarded. The accepted run explicitly disabled Nx cache:

```bash
cd /mnt/f/code/project/opentu
NX_SKIP_NX_CACHE=true \
CREATIVE_EMBEDDED_BASE_URL=http://127.0.0.1:<temp-port>/creative/ \
pnpm e2e:creative-embedded
```

Result: PASS — 3/3 tests actually executed and passed. No live provider calls were configured or made.

## Remaining gates after V17/V18 postfix

- Run a fresh dynamic workflow final audit focused on development-goal attainment and new runtime lifecycle regressions, not merely patch completion.
- The workflow prompt must explicitly include slow-provider timing, cross-layer state-machine synthesis, and refresh/retry/Cache Storage lifecycle.
- If synthesis is empty/failed, continue or split verifier branches rather than treating it as complete.
- Main session must verify material findings against source/tests before accepting them.
- Dirty/provenance remains a release-readiness blocker: multiple repositories contain uncommitted source, generated dist, workflow, and task artifacts. Do not claim production/release-ready until this is resolved intentionally.

## V19 embedded E2E follow-up — viewport persistence under cache-miss rehydrate — 2026-06-23

After rebuilding and synchronizing the embedded Creative dist, the full no-provider embedded Playwright gate was rerun against a fresh isolated `new-api` process. It exposed a real cross-layer state issue in the refresh/cache-miss path:

- Cache-miss rehydrate succeeded and the canvas image URL was cache-busted.
- The stored board viewport was still overwritten from the restored viewport `{ zoom: 0.42, origination: [321, 654] }` to a runtime layout/scroll value similar to `{ zoom: 0.42, origination: [-639.52, -360.85] }`.

Root cause: the previous restore guard only covered `onViewportChange` for a short 1.5s window. The generated image cache-miss recovery/nudge path can later emit a board `onChange` that carries non-user viewport noise. That board change was persisted together with the image URL update, so the restored viewport was lost even though no user pan/zoom happened.

### Repair

`apps/web/src/app/app.tsx` and `apps/web/src/app/viewport-persistence.ts` now keep the restored viewport authoritative until an explicit user interaction is observed:

- `onViewportChange` ignores non-user viewport changes while the restore guard is active.
- `onChange` also sanitizes the incoming board-change viewport before persistence, preserving the restored viewport when the change is a non-user runtime/layout update.
- The guard is no longer an arbitrary 1.5s timeout. It remains active until user interaction or board/unmount cleanup.
- Added pure regression coverage for unbounded restore guard behavior and board-change viewport selection.

### Local verification evidence

Targeted unit evidence:

```bash
cd /mnt/f/code/project/opentu
pnpm vitest run --no-file-parallelism --maxWorkers=1 --minWorkers=1 \
  apps/web/src/app/viewport-persistence.test.ts \
  packages/drawnix/src/components/retry-image.test.tsx
```

Result: PASS — 2 files, 20 tests.

Embedded artifact rebuild/sync evidence:

```bash
cd /mnt/f/code/project/new2fly
python3 scripts/creative_release_gate.py build-sync-check
```

Result: PASS — OpenTU build succeeded and the embedded dist was synchronized to both `new-api/web/creative/dist` and `new-api/router/web/creative/dist`.

Fresh isolated embedded E2E evidence:

```bash
cd /mnt/f/code/project/opentu
NX_SKIP_NX_CACHE=true \
CREATIVE_EMBEDDED_BASE_URL=http://127.0.0.1:<temp-port>/creative/ \
pnpm e2e:creative-embedded
```

Result: PASS — 4/4 tests executed and passed against a fresh local `new-api` process using temporary SQLite and no provider credentials.

Full target regression evidence:

```bash
cd /mnt/f/code/project/opentu
pnpm vitest run --no-file-parallelism --maxWorkers=1 --minWorkers=1 \
  packages/drawnix/src/services/__tests__/task-queue-service-image-retry.test.ts \
  packages/drawnix/src/services/__tests__/media-executor.test.ts \
  packages/drawnix/src/services/media-executor/fallback-utils.test.ts \
  packages/drawnix/src/services/__tests__/video-generation-service.test.ts \
  apps/web/src/app/viewport-persistence.test.ts \
  packages/drawnix/src/components/retry-image.test.tsx
```

Result: PASS — 6 files, 70 tests. Existing non-fatal test warnings remain: `.npmrc` `${NPM_TOKEN}` substitution warning, media-executor `localStorage is not defined` crypto initialization warnings in Node test environment, and expected RetryImage 503 retry logs.

Typecheck evidence:

```bash
cd /mnt/f/code/project/opentu
pnpm exec tsc --noEmit --project packages/drawnix/tsconfig.spec.json --pretty false
pnpm exec tsc --noEmit --project apps/web-e2e/tsconfig.json --pretty false
pnpm nx run drawnix:typecheck
pnpm nx run web:typecheck
```

Result: PASS.

No-secrets release gate evidence with embedded smoke URL:

```bash
cd /mnt/f/code/project/new2fly
python3 scripts/creative_release_gate.py check \
  --run-new-api-tests \
  --source-diff-check \
  --embedded-smoke-url http://127.0.0.1:<temp-port>/creative/
```

Result: PASS — embedded artifact contract, whitespace/source diff checks, `new-api` Go tests, `go build ./...`, and embedded Playwright E2E 4/4 all passed.

### Remaining gate after V19

Run the final dynamic workflow audit focused on development-goal attainment and new regressions. The prompt must not rely on previous reports and must explicitly include:

1. real slow-provider dynamic timing;
2. synthesis-level cross-layer state-machine verification;
3. refresh / retry / Cache Storage lifecycle as one end-to-end chain.

Synthesis/verifier failure or empty output must not be treated as completion; split and continue if needed. Main session must verify material findings against source/tests before accepting them.

## V20 final-audit priority fixes — submit/polling recoverability and binding mapping UI — 2026-06-23

The final goal-attainment audit surfaced three material code issues after V19. Main-session verification confirmed them against source, then fixed the two OpenTU runtime lifecycle issues with TDD and the admin binding UI issue with a minimal backend-authoritative change.

### OTU-CREATIVE-001 — hung Creative managed image submit before `remoteId`

Root cause: `executeCreativeManagedImageTask(...)` awaited the initial `POST /creative/relay/v1/images/tasks` without a bounded local timeout. If the browser transport hung before a `remoteId` was persisted, the task could remain in `PROCESSING/SUBMITTING` with no same-page recovery path.

Repair:

- Added `CREATIVE_IMAGE_SUBMIT_TIMEOUT_MS`.
- Wrapped the initial submit fetch in a bounded timeout helper.
- A submit response timeout or submit-level network rejection is now persisted as `INTERRUPTED_DURING_SUBMISSION`, preserving retryability and the original `opentu-image-${taskId}` idempotency key semantics instead of hanging indefinitely.

TDD evidence: first run failed as expected — new submit-hang test timed out before the implementation.

### OTU-CREATIVE-002 — transient status polling fetch rejection became terminal failure

Root cause: `pollCreativeManagedImageTask(...)` retried temporary HTTP status codes, but a thrown status fetch error such as `TypeError('Failed to fetch')` escaped to the executor catch path and was persisted as `IMAGE_GENERATION_ERROR`.

Repair:

- Wrapped status polling fetch in `try/catch`.
- Non-abort fetch-level errors are treated as transient while the Creative remote timeout budget remains available.
- Abort/cancel semantics remain unchanged.
- On budget expiry the path still throws the recoverable Creative `TIMEOUT` error instead of terminal image generation failure.

TDD evidence: first run failed as expected — new status-fetch network retry test rejected with the transient `TypeError` before the implementation.

### CMB-UI-001 — Creative Model Binding helper blocked backend-supported `model_mapping`

Root cause: the admin guided binding builder rejected a `providerModelId` not directly present in sanitized channel `models[]`, while backend validation intentionally supports channels whose logical model is exposed through `model_mapping` and the sanitized summary endpoint does not expose raw mapping config to the browser.

Repair:

- The builder no longer hard-blocks this case.
- It shows a warning that the provider model is not directly listed and that backend validate/dry-run remain authoritative.
- Disabled channel and empty model-list checks remain hard blockers.

### Verification evidence

OpenTU RED/GREEN and regression tests:

```bash
cd /mnt/f/code/project/opentu
pnpm vitest run --no-file-parallelism --maxWorkers=1 --minWorkers=1 \
  packages/drawnix/src/services/__tests__/media-executor.test.ts
pnpm vitest run --no-file-parallelism --maxWorkers=1 --minWorkers=1 \
  packages/drawnix/src/services/__tests__/task-queue-service-image-retry.test.ts \
  packages/drawnix/src/hooks/__tests__/useTaskExecutor.test.ts \
  packages/drawnix/src/utils/__tests__/task-utils.test.ts
pnpm exec tsc --noEmit --project packages/drawnix/tsconfig.spec.json --pretty false
pnpm nx run drawnix:typecheck
pnpm nx run web:typecheck
```

Result: PASS. `media-executor.test.ts` first failed on the two new RED cases before implementation, then passed 28/28 after the fix. The grouped task queue / executor / task-utils regression passed 35/35. Existing non-fatal warnings remained: `.npmrc` `${NPM_TOKEN}` substitution warnings, Node test-environment crypto/localStorage/indexedDB warnings, and Sass/Vite build warnings.

new-api admin/backend verification:

```bash
cd /mnt/f/code/project/new-api/web/default
pnpm typecheck
pnpm exec eslint src/features/system-settings/models/creative-model-bindings-section.tsx
cd /mnt/f/code/project/new-api
go test -count=1 ./service ./controller
```

Result: PASS.

Embedded artifact and no-secrets local release gate:

```bash
cd /mnt/f/code/project/new2fly
python3 scripts/creative_release_gate.py build-sync-check --run-new-api-tests --source-diff-check
```

Result: PASS — OpenTU build, dist sync into both new-api Creative dist trees, artifact checks, source diff checks, new-api Go tests, and `go build ./...` completed.

Fresh isolated embedded E2E and full release gate with embedded smoke URL:

```bash
# isolated local new-api: temporary SQLite/logs, disabled upstream update jobs, no provider credentials
cd /mnt/f/code/project/opentu
NX_SKIP_NX_CACHE=true \
CREATIVE_EMBEDDED_BASE_URL=http://127.0.0.1:<temp-port>/creative/ \
pnpm e2e:creative-embedded

cd /mnt/f/code/project/new2fly
python3 scripts/creative_release_gate.py check \
  --run-new-api-tests \
  --source-diff-check \
  --embedded-smoke-url http://127.0.0.1:<temp-port>/creative/
```

Result: PASS — embedded Playwright E2E 4/4 executed and passed in both the direct E2E invocation and the release-gate invocation.

### Remaining gate after V20 fixes

Run a fresh dynamic workflow re-audit focused on development-goal attainment and new regressions. It must explicitly include:

1. slow-provider timing, including hung submit, status fetch network failures, long-running remote tasks, and late provider success;
2. cross-layer state-machine synthesis from UI task creation through backend idempotency, polling, content/cache materialization, canvas/history/dock display, refresh, and retry;
3. refresh / retry / Cache Storage lifecycle as one end-to-end chain.

Synthesis/verifier failure or empty output is not acceptable; split/continue the workflow if necessary. Main session must verify material findings before accepting them.

## V21 main-verified runtime lifecycle repairs

Source audit: `final-goal-audit-v21-main-verification-2026-06-23.md`.

Main-session verification accepted four runtime findings and rejected the video-resume finding as already covered by `DrawnixDeferredRuntime -> fallbackMediaExecutor.resumePendingTasks(...)`.

### OTU-ABORT-001 — remote-accepted Creative image abort remains recoverable

Root cause: after `executeCreativeManagedImageTask()` persisted a backend/provider `remoteId`, local `AbortError` during poll/content materialization still flowed into the generic catch path and persisted terminal `IMAGE_GENERATION_ERROR`.

Repair:

- `executeCreativeManagedImageTask()` now tracks whether a remote task id has been accepted.
- If the browser aborts after remote acceptance, the task is left recoverable at `processing/polling` by writing progress 95 instead of `failTask(...)`.
- The function throws a timeout-class recoverable error so `TaskQueueService` keeps the managed image task resumable using its existing remote-timeout branch.

Regression:

- `media-executor.test.ts` adds `keeps accepted managed Creative image tasks recoverable when aborted after remote id is persisted`.
- RED evidence: before the fix the test rejected with raw `AbortError` and called the terminal failure path.
- GREEN evidence: after the fix the accepted remote task has `updateRemoteId(...)`, no `failTask(...)`, and progress remains `polling`.

### OTU-IDEMP-001 — fresh managed image retries use retry-scoped idempotency keys

Root cause: `createCreativeImageTaskIdempotencyKey(taskId, retryAttempt)` already supported retry-scoped keys, but `executeCreativeManagedImageTask()` called it without `params.retryAttempt`.

Repair:

- Managed Creative image submit now uses `createCreativeImageTaskIdempotencyKey(taskId, params.retryAttempt)` when the caller did not provide an explicit idempotency key.
- Submit-interrupted resume remains on retryAttempt 0 and keeps the original `opentu-image-${taskId}` key.

Regression:

- `media-executor.test.ts` adds `uses retryAttempt in managed Creative image idempotency keys for fresh retries`.
- RED evidence: before the fix the submit header was `opentu-image-task-retry-key`.
- GREEN evidence: retryAttempt 2 now submits `opentu-image-task-retry-key-retry-2` with guarded storage writes.

### OTU-SYNC-001 — stale storage sync cannot overwrite a newer retry attempt

Root cause: executor writeback paths were guarded by `retryAttempt` + `startedAt`, but `syncTaskFromStorage()` merged IndexedDB task state into memory without the same late-attempt protection.

Repair:

- Added storage-attempt guard helpers in `task-queue-service.ts`.
- `syncTaskFromStorage()` now ignores a storage update when it carries a different `params.retryAttempt` or a different numeric `startedAt` from the current in-memory task.

Regression:

- `task-queue-service-image-retry.test.ts` adds `ignores stale storage sync updates from an older retry attempt`.
- RED evidence: before the fix a stale completed old attempt emitted `taskUpdated` and overwrote the current processing retry.
- GREEN evidence: stale sync emits no update and preserves current `status`, `remoteId`, `startedAt`, `retryAttempt`, and empty result.

### OTU-CACHE-001 — canvas/cache readiness tolerates slow content availability

Root cause: `ensureGeneratedImageCacheUrlReady()` and the canvas insertion readiness path attempted generated-image content rehydrate only once, while preview UI had its own retry path in `RetryImage`.

Repair:

- `generated-media-cache.ts` now uses bounded retry for Creative content fetch/rehydrate on cache misses and direct safe content URLs.
- Retry is limited to transient statuses (`404`, `408`, `409`, `425`, `429`, `5xx`) and network/empty-image errors, with short bounded delays.
- Canvas/manual insertion now shares the same slow-content tolerance without relying on image-element retry behavior.

Regression:

- `generated-media-cache.test.ts` adds `bounded-retries Creative content rehydrate before failing canvas readiness on slow content availability`.
- RED evidence: before the fix the first `503` rejected as `content rehydrate failed: 503`.
- GREEN evidence: two transient `503` responses followed by an image blob succeed, cache the blob, and return decoded dimensions.

### V21 verification evidence

Targeted RED/GREEN and regression tests:

```bash
cd /mnt/f/code/project/opentu
pnpm vitest run --no-file-parallelism --maxWorkers=1 --minWorkers=1 \
  packages/drawnix/src/services/__tests__/media-executor.test.ts \
  -t "uses retryAttempt in managed Creative image idempotency keys|keeps accepted managed Creative image tasks recoverable"
pnpm vitest run --no-file-parallelism --maxWorkers=1 --minWorkers=1 \
  packages/drawnix/src/services/__tests__/task-queue-service-image-retry.test.ts \
  -t "ignores stale storage sync"
pnpm vitest run --no-file-parallelism --maxWorkers=1 --minWorkers=1 \
  packages/drawnix/src/utils/__tests__/generated-media-cache.test.ts
```

Result: RED first, then PASS after implementation.

Broader OpenTU regression:

```bash
cd /mnt/f/code/project/opentu
pnpm vitest run --no-file-parallelism --maxWorkers=1 --minWorkers=1 \
  packages/drawnix/src/services/__tests__/media-executor.test.ts \
  packages/drawnix/src/services/__tests__/task-queue-service-image-retry.test.ts \
  packages/drawnix/src/utils/__tests__/generated-media-cache.test.ts \
  packages/drawnix/src/hooks/__tests__/useAutoInsertToCanvas.test.ts \
  packages/drawnix/src/hooks/__tests__/useTaskExecutor.test.ts \
  packages/drawnix/src/utils/__tests__/task-utils.test.ts
pnpm exec tsc --noEmit --project packages/drawnix/tsconfig.spec.json --pretty false
pnpm nx run drawnix:typecheck
pnpm nx run web:typecheck
```

Result: PASS — 6 Vitest files, 87 tests passed; spec tsc, drawnix typecheck, and web typecheck passed.

Embedded artifact / release gate:

```bash
cd /mnt/f/code/project/new2fly
python3 scripts/creative_release_gate.py build-sync-check --run-new-api-tests --source-diff-check
```

Result: PASS — rebuilt OpenTU, synced Creative dist into both new-api targets, artifact identity/hygiene checks passed, new-api Go tests and `go build ./...` passed.

Isolated local no-provider embedded smoke:

```bash
# temporary SQLite/logs, disabled upstream update jobs, no provider credentials
cd /mnt/f/code/project/opentu
NX_SKIP_NX_CACHE=true \
CREATIVE_EMBEDDED_BASE_URL=http://127.0.0.1:<temp-port>/creative/ \
pnpm e2e:creative-embedded

cd /mnt/f/code/project/new2fly
python3 scripts/creative_release_gate.py check \
  --run-new-api-tests \
  --source-diff-check \
  --embedded-smoke-url http://127.0.0.1:<temp-port>/creative/
```

Result: PASS — direct embedded Playwright E2E executed 4/4 and passed; release-gate embedded E2E executed 4/4 and passed.

### Remaining gate after V21 fixes

The worktree is still intentionally dirty across the orchestration, OpenTU, and new-api repositories. The accepted release/process findings remain valid until provenance is cleaned up and the candidate is redeployed/smoked in the target environment.

Before production deployment, run a fresh final dynamic workflow re-audit against the current post-V21 candidate. Empty/timeout synthesis or verifier is not acceptable; split and continue the workflow if needed, then main-session verify material findings.

## 2026-06-23 v22 RLC-FINAL-001 fix

### Finding

- `RLC-FINAL-001` accepted as HIGH in `final-goal-audit-v22-main-verification-2026-06-23.md`.
- Root cause: after the durable Creative image task row was created, live provider submission still used `c.Request.Context()`. A browser/client cancel after the upstream provider accepted the request but before new-api read the accepted id could turn the local submit into an ambiguous error. The task then retained no `PrivateData.UpstreamTaskID`, so GET/polling skipped it until ambiguous timeout and could not recover late provider success.

### Fix

- `new-api/controller/creative_image_tasks.go`
  - Added `creativeImageProviderSubmitContext`, using `context.WithoutCancel(requestCtx)` plus a bounded timeout.
  - The timeout uses `common.RelayTimeout` when configured; otherwise it uses a 120s default submit bound.
  - Live Creative image provider submit now uses this detached bounded context only after the durable task row is persisted.
  - Existing provider timeout behavior remains: actual submit timeout still marks task ambiguous rather than failing/refunding immediately.
- `new-api/controller/creative_test.go`
  - Added `TestCreativeImageTaskSubmitLiveClientCancelAfterProviderAcceptPersistsUpstreamID`.
  - RED evidence before implementation: the new test failed because stored `PrivateData.UpstreamTaskID` was empty after request cancellation.
  - GREEN evidence after implementation: upstream id is persisted, `ProviderSubmitAmbiguous` remains false, and subsequent GET can poll by the persisted upstream id.

### Validation

```bash
cd /mnt/f/code/project/new-api
go test -count=1 ./controller -run 'TestCreativeImageTaskSubmitLive(ClientCancelAfterProviderAcceptPersistsUpstreamID|TimeoutStaysPendingAndReplaysTask|BindingUsesLockedChannelAndSanitizedDTO)' -v
# PASS

go test -count=1 ./controller ./service ./model
# PASS

go test -count=1 ./controller ./service ./model ./relay ./relay/common ./relay/constant
# PASS
```

### Remaining gate

- v22 final audit is still not complete: four timeout/null branches from the first dynamic workflow run must be rerun in smaller workflows, then synthesized and verified.

## 2026-06-24 v22d/v22c OpenTU retry/storage/cache-miss follow-up

### Findings fixed

- `F1` / `F2`: stale IndexedDB task snapshots can no longer overwrite newer in-memory retry attempts:
  - `syncTaskFromStorage()` now rejects stale execution attempts and older `updatedAt` snapshots before emitting task updates.
  - `restoreTasks()` now rejects persisted rows from an older retry attempt even when their `updatedAt` is newer than the active in-memory task.
- `F3`: fallback task-storage guarded writes now include `startedAt` as part of the execution-attempt identity, not only `retryAttempt`.
  - `TaskStorageWriteGuard` supports `expectedStartedAt`.
  - task queue passes the current execution `startedAt` into image/video/text executor params.
  - fallback executor / adapter routes propagate `startedAt` into guarded IndexedDB writes.
- `opentu-generated-canvas-cache-miss-race`: generated image cache-miss events raised before task storage readiness are buffered and drained when `useGeneratedMediaCacheMissRecovery()` is enabled with a board, so refresh-time canvas broken-image recovery is not lost.
  - Added hook test cleanup to prevent stale event listeners from earlier tests masking the disabled-buffering assertion.

### Verification

```bash
cd /mnt/f/code/project/opentu
pnpm vitest run --no-file-parallelism --maxWorkers=1 --minWorkers=1 \
  packages/drawnix/src/services/__tests__/task-queue-service-image-retry.test.ts \
  packages/drawnix/src/services/__tests__/task-storage-writer.test.ts \
  packages/drawnix/src/hooks/__tests__/useGeneratedMediaCacheMissRecovery.test.tsx
# PASS: 3 files, 34 tests

pnpm vitest run --testTimeout=30000 --no-file-parallelism --maxWorkers=1 --minWorkers=1 \
  packages/drawnix/src/services/__tests__/media-executor.test.ts \
  packages/drawnix/src/services/__tests__/task-queue-service-image-retry.test.ts \
  packages/drawnix/src/services/__tests__/task-storage-writer.test.ts \
  packages/drawnix/src/hooks/__tests__/useGeneratedMediaCacheMissRecovery.test.tsx \
  packages/drawnix/src/hooks/__tests__/useAutoInsertToCanvas.test.ts \
  packages/drawnix/src/hooks/__tests__/useTaskExecutor.test.ts \
  packages/drawnix/src/utils/__tests__/generated-media-cache.test.ts \
  packages/drawnix/src/utils/__tests__/task-utils.test.ts
# PASS: 8 files, 98 tests

pnpm exec tsc --noEmit --project packages/drawnix/tsconfig.spec.json --pretty false
# PASS

pnpm nx run drawnix:typecheck
# PASS

pnpm nx run web:typecheck
# PASS
```

Notes:

- `.npmrc` emitted the existing `${NPM_TOKEN}` replacement warning; no secret value was read or printed.
- `media-executor.test.ts` emits existing localStorage/indexedDB crypto-environment warnings under Node; tests pass.
- A first broad Vitest run without an increased timeout hit the file's default 5s timeout in one already-slow test under the loaded 8-file serial suite. It was rerun with `--testTimeout=30000` and passed.


## 2026-06-24 v23a storage writer propagation fix

### Accepted findings fixed

- `WP-001` HIGH: stale resumed video completion/failure callbacks could bypass the guarded IndexedDB write and call `onTaskUpdate` anyway.
- `WP-002` MEDIUM: `taskStorageWriter.updateStatus` had no attempt guard and selected executor status/progress writes did not pass the available `retryAttempt`/`startedAt` guard.

### Code changes

OpenTU files changed:

- `packages/drawnix/src/services/media-executor/task-storage-writer.ts`
  - Exported `TaskStorageWriteGuard`.
  - `updateStatus`, `updateProgress`, `completeTask`, `failTask`, and `updateRemoteId` now return `Promise<boolean>` to report whether the write applied.
  - `updateStatus` now honors terminal-state, `expectedRetryAttempt`, and `expectedStartedAt` guards, preventing stale writes from reopening terminal tasks or overwriting a newer retry attempt.
- `packages/drawnix/src/services/media-executor/fallback-executor.ts`
  - Storage helper functions now propagate boolean write results.
  - image/video/text start/progress writes pass the available guard without changing unguarded call shape when no guard exists.
  - `resumeVideoTask()` now writes guarded resumed progress and only emits `onTaskUpdate` completion/failure/progress callbacks when the guarded storage write applies.
- `packages/drawnix/src/services/media-executor/fallback-adapter-routes.ts`
  - Shared remote-id/complete/fail storage helpers now propagate boolean write results for consistent guarded write semantics.
- `packages/drawnix/src/services/__tests__/task-storage-writer.test.ts`
  - Added `updateStatus` stale-startedAt, terminal no-reopen, and successful guarded-write assertions.
- `packages/drawnix/src/services/__tests__/media-executor.test.ts`
  - Added resumed-video stale completion callback suppression coverage.
  - Added no-callback resumed-video progress guard propagation coverage.
  - Added missing mock cleanup for fallback-utils/provider-routing to avoid cross-test pollution.

### Verification

RED before implementation:

```bash
cd /mnt/f/code/project/opentu
pnpm vitest run --no-file-parallelism --maxWorkers=1 --minWorkers=1 \
  packages/drawnix/src/services/__tests__/task-storage-writer.test.ts \
  packages/drawnix/src/services/__tests__/media-executor.test.ts
```

Expected pre-fix failures were observed: `updateStatus` returned `undefined` and did not guard, resumed video completion still emitted stale callback, and no-callback resumed progress omitted the guard.

GREEN after implementation:

```bash
pnpm vitest run --no-file-parallelism --maxWorkers=1 --minWorkers=1 \
  packages/drawnix/src/services/__tests__/task-storage-writer.test.ts \
  packages/drawnix/src/services/__tests__/media-executor.test.ts
```

Result: PASS, 2 files / 39 tests.

```bash
pnpm exec tsc --noEmit --project packages/drawnix/tsconfig.spec.json --pretty false
```

Result: PASS.

```bash
pnpm vitest run --no-file-parallelism --maxWorkers=1 --minWorkers=1 \
  packages/drawnix/src/services/__tests__/task-queue-service-image-retry.test.ts
```

Result: PASS, 1 file / 25 tests.

```bash
pnpm vitest run --testTimeout=30000 --no-file-parallelism --maxWorkers=1 --minWorkers=1 \
  packages/drawnix/src/services/__tests__/media-executor.test.ts \
  packages/drawnix/src/services/__tests__/task-storage-writer.test.ts \
  packages/drawnix/src/hooks/__tests__/useGeneratedMediaCacheMissRecovery.test.tsx \
  packages/drawnix/src/hooks/__tests__/useAutoInsertToCanvas.test.ts \
  packages/drawnix/src/hooks/__tests__/useTaskExecutor.test.ts \
  packages/drawnix/src/utils/__tests__/generated-media-cache.test.ts \
  packages/drawnix/src/utils/__tests__/task-utils.test.ts
```

Result: PASS, 7 files / 78 tests.

Note: one combined 8-file run had a single timeout in `task-queue-service-image-retry.test.ts` because the first test has an explicit 15000 ms timeout and ran slowly under the combined suite. The same file passed immediately afterward in isolation (25/25), and the remaining 7 files passed together (78/78).

```bash
pnpm nx run drawnix:typecheck
pnpm nx run web:typecheck
```

Result: both PASS.

## 2026-06-24 v23b cache/canvas/runtime lifecycle fix

### Accepted findings fixed

- `VIDEO_CACHE_MISS_NOT_RECOVERED` HIGH: generated video cache URLs under `/__aitu_cache__/video/*` now report cache-miss events and rehydrate from the same-origin Creative video content endpoint.
- `BUFFERED_MISS_DROPPED_ON_TRANSIENT_FAILURE` MEDIUM: generated media cache-miss recovery keeps pending entries until successful cache write plus canvas reload, and retries transient failures with bounded backoff.
- `PENDING_BUFFER_GLOBAL_UNBOUNDED` MEDIUM: pending generated media cache misses are now board-scoped when a board id is available, TTL-bound, attempt-bound, and capped.
- `F1` MEDIUM: workflow media steps now await durable `taskId` persistence in `onTaskCreated` before provider generation continues.
- `F2` MEDIUM: video history no longer renders a video URL as an image thumbnail when no real thumbnail exists; prompt preview creation skips missing preview sources.

### Code changes

OpenTU files changed in this slice:

- `packages/drawnix/src/utils/generated-media-cache.ts`
  - Added generated video cache URL detection, task-id extraction, same-origin video content URL normalization, video content URL resolution, and video cache rehydrate through `/creative/relay/v1/videos/:taskId/content`.
  - Kept image rehydrate semantics and shared retry behavior; video fetch uses `Accept: video/*,application/octet-stream`.
- `packages/drawnix/src/utils/asset-cleanup.ts`
  - Generated image cache miss events now include `mediaType`, `boardId`, and `mediaUrl` while preserving legacy `imageUrl`.
  - Reuses `extractGeneratedImageTaskId` from `generated-media-cache.ts` instead of duplicating parsing.
- `packages/drawnix/src/hooks/useGeneratedMediaCacheMissRecovery.ts`
  - Reworked recovery as a bounded image/video pending state machine.
  - Supports image and video task matching, board-scoped buffering, TTL/cap/max-attempt cleanup, transient retry, and success-only pending deletion.
  - Video cache misses rehydrate from Creative video content and retrigger canvas reload with `_retry` while preserving `#video` hash.
- `packages/drawnix/src/plugins/components/video.tsx`
  - Dispatches generated-video cache miss events on load error and deduplicates native/React error dispatch for the same URL.
- `packages/drawnix/src/plugins/components/image.tsx`
  - Existing video metadata propagation was verified: id/elementId/contentUrl/remoteTaskId/providerTaskId/mimeType are passed into `Video`.
- `packages/drawnix/src/hooks/useGenerationHistory.ts`
  - Video history image thumbnail uses only `thumbnailUrl` / `thumbnailUrls[0]`, never the video URL itself.
- `packages/drawnix/src/components/generation-history/generation-history.tsx`
  - `VideoHistoryItem.imageUrl` remains optional so missing thumbnails render a video placeholder.
- `packages/drawnix/src/components/ttd-dialog/shared/prompt-utils.ts`
  - Prompt preview generation skips missing preview sources and keeps optional video thumbnail typing safe.
- `packages/drawnix/src/services/media-generation/types.ts`
  - `onTaskCreated` may return `Promise<void>`.
- `packages/drawnix/src/services/media-generation/image-generation-service.ts`
- `packages/drawnix/src/services/media-generation/video-generation-service.ts`
  - Await `onTaskCreated` before continuing generation.
- `packages/drawnix/src/services/workflow-engine/engine.ts`
  - Image/video workflow `onTaskCreated` now awaits `workflowStorageWriter.saveWorkflow(workflow)`.
- Tests added/updated:
  - `packages/drawnix/src/hooks/__tests__/useGeneratedMediaCacheMissRecovery.test.tsx`
  - `packages/drawnix/src/hooks/__tests__/useGenerationHistory.test.ts`
  - `packages/drawnix/src/plugins/components/video.test.tsx`
  - `packages/drawnix/src/services/__tests__/workflow-engine-durable-taskid.test.ts`
  - `packages/drawnix/src/services/__tests__/workflow-engine.test.ts`

### Verification

RED before implementation:

```bash
cd /mnt/f/code/project/opentu
pnpm vitest run --testTimeout=30000 --no-file-parallelism --maxWorkers=1 --minWorkers=1 \
  packages/drawnix/src/hooks/__tests__/useGeneratedMediaCacheMissRecovery.test.tsx \
  packages/drawnix/src/hooks/__tests__/useGenerationHistory.test.ts \
  packages/drawnix/src/plugins/components/video.test.tsx \
  packages/drawnix/src/services/__tests__/workflow-engine.test.ts
```

Observed failures matched the intended v23b RED state: transient cache miss was dropped/timed out, board-scoped pending miss was incorrectly drained, video cache miss had no recovery path, video component imported missing video cache helpers, and the old workflow-engine test harness exposed missing runtime mocks.

Targeted GREEN:

```bash
pnpm vitest run --testTimeout=30000 --no-file-parallelism --maxWorkers=1 --minWorkers=1 \
  packages/drawnix/src/hooks/__tests__/useGeneratedMediaCacheMissRecovery.test.tsx \
  packages/drawnix/src/hooks/__tests__/useGenerationHistory.test.ts \
  packages/drawnix/src/plugins/components/video.test.tsx \
  packages/drawnix/src/services/__tests__/workflow-engine-durable-taskid.test.ts
```

Result: PASS, 4 files / 13 tests.

Broader GREEN:

```bash
pnpm vitest run --testTimeout=30000 --no-file-parallelism --maxWorkers=1 --minWorkers=1 \
  packages/drawnix/src/utils/__tests__/generated-media-cache.test.ts \
  packages/drawnix/src/utils/__tests__/asset-cleanup.test.ts \
  packages/drawnix/src/components/retry-image.test.tsx \
  packages/drawnix/src/services/__tests__/workflow-engine.test.ts
```

Result: PASS, 4 files / 24 tests.

Combined lifecycle/cache/canvas regression:

```bash
pnpm vitest run --testTimeout=30000 --no-file-parallelism --maxWorkers=1 --minWorkers=1 \
  packages/drawnix/src/services/__tests__/media-executor.test.ts \
  packages/drawnix/src/services/__tests__/task-storage-writer.test.ts \
  packages/drawnix/src/hooks/__tests__/useGeneratedMediaCacheMissRecovery.test.tsx \
  packages/drawnix/src/hooks/__tests__/useGenerationHistory.test.ts \
  packages/drawnix/src/plugins/components/video.test.tsx \
  packages/drawnix/src/services/__tests__/workflow-engine-durable-taskid.test.ts \
  packages/drawnix/src/hooks/__tests__/useAutoInsertToCanvas.test.ts \
  packages/drawnix/src/hooks/__tests__/useTaskExecutor.test.ts \
  packages/drawnix/src/utils/__tests__/generated-media-cache.test.ts \
  packages/drawnix/src/utils/__tests__/asset-cleanup.test.ts \
  packages/drawnix/src/utils/__tests__/task-utils.test.ts \
  packages/drawnix/src/components/retry-image.test.tsx \
  packages/drawnix/src/services/__tests__/workflow-engine.test.ts
```

Result: PASS, 13 files / 109 tests.

Type checks:

```bash
pnpm exec tsc --noEmit --project packages/drawnix/tsconfig.spec.json --pretty false
pnpm nx run drawnix:typecheck
pnpm nx run web:typecheck
```

Result: all PASS.

Notes:

- `.npmrc` emitted the existing `${NPM_TOKEN}` replacement warning; no secret value was read or printed.
- Some Node/jsdom tests emit existing crypto/localStorage/indexedDB environment warnings; the relevant assertions pass.
- No live provider call, push, deploy, or production/staging mutation was performed in this slice.

## 2026-06-24 v24 audio remote lifecycle repair

### Scope

Repaired the v23c/v24 residual audio runtime blockers:

- AUDIO `FAILED/TIMEOUT + remoteId` retry now resumes the existing provider task instead of starting a fresh Suno submit.
- Audio polling now carries `AbortSignal` through submit/query/poll sleep and rejects with `AbortError` before the next status request after cancellation.
- Audio adapter internal callbacks (`onProgress`, `onSubmitted`) and idempotency/signal are now top-level request fields, while legacy `params` callback fields remain tolerated and stripped before provider submit.
- Audio completion finalization is shared by fresh execution and resumed remote polling, preserving the durable `remoteId` as `providerTaskId` and suppressing stale/cancelled attempt writeback.

### Key files

- `opentu/packages/drawnix/src/services/task-queue-service.ts`
- `opentu/packages/drawnix/src/services/audio-api-service.ts`
- `opentu/packages/drawnix/src/services/model-adapters/types.ts`
- `opentu/packages/drawnix/src/services/model-adapters/default-adapters.ts`
- `opentu/packages/drawnix/src/utils/task-utils.ts`
- `opentu/packages/drawnix/src/services/__tests__/task-queue-service-image-retry.test.ts`
- `opentu/packages/drawnix/src/services/__tests__/audio-api-service.test.ts`

### Verification

Focused RED/GREEN for audio blockers:

```bash
pnpm vitest run --testTimeout=30000 --no-file-parallelism --maxWorkers=1 --minWorkers=1 \
  packages/drawnix/src/services/__tests__/task-queue-service-image-retry.test.ts \
  packages/drawnix/src/services/__tests__/audio-api-service.test.ts \
  -t "timed-out remote audio|aborts audio resume"
```

Result: PASS — 2 tests.

Focused lifecycle regression:

```bash
pnpm vitest run --testTimeout=30000 --no-file-parallelism --maxWorkers=1 --minWorkers=1 \
  packages/drawnix/src/services/__tests__/task-queue-service-image-retry.test.ts \
  packages/drawnix/src/services/__tests__/audio-api-service.test.ts \
  packages/drawnix/src/services/__tests__/media-executor.test.ts
```

Result: PASS — 3 files / 84 tests.

Type gates:

```bash
pnpm exec tsc --noEmit --project packages/drawnix/tsconfig.spec.json --pretty false
pnpm nx run drawnix:typecheck
pnpm nx run web:typecheck
```

Result: all PASS.

Notes:

- `.npmrc` emitted the existing `${NPM_TOKEN}` replacement warning; no secret value was read or printed.
- Existing Node/jsdom `localStorage` crypto initialization warnings appeared in `media-executor.test.ts`; assertions passed.
- No live provider call, push, deploy, or staging/production mutation was performed in this slice.

### Remaining gate

Run a focused dynamic workflow re-audit for the repaired blockers (`IMG-001`, `IMG-002`, `VID-001`, `AUD-001/AUD-002`) before claiming final runtime lifecycle closure.

## 2026-06-24 v24 AUD-002 stale audio callback follow-up

### Scope

The focused v24 dynamic workflow did not complete enough branches to count as a full review, but its one valid branch identified two audio cancellation/stale-attempt gaps that the main session verified against code and reproduced with RED tests:

- `audio-api-service.resumePolling()` could reject the outer resume promise on abort while the first in-flight status query later still emitted `onProgress`.
- Legacy audio paths in `generation-api-service` could write progress/submission callbacks directly after a retry attempt changed, bypassing the newer `useTaskExecutor` post-attempt guard.

Repairs:

- `resumePollingInternal()` now checks `AbortSignal` immediately after the first status response, after progress emission, and before entering the poll loop.
- Legacy audio generation now captures an execution-attempt snapshot and guards `onSubmitted` / `onProgress` before touching `taskQueueService`.
- Legacy audio resume now uses a per-resume `AbortController`, aborts on timeout, passes the signal into `audioAPIService.resumePolling()`, and guards progress writes by current attempt plus matching `remoteId`.
- `GenerationAPIService.generate()` only clears the current attempt's abort controller, avoiding a stale `finally` from deleting a newer retry controller.

### Key files

- `opentu/packages/drawnix/src/services/audio-api-service.ts`
- `opentu/packages/drawnix/src/services/generation-api-service.ts`
- `opentu/packages/drawnix/src/services/__tests__/audio-api-service.test.ts`
- `opentu/packages/drawnix/src/services/__tests__/generation-api-service.creative-embedded.test.ts`

### Verification

Focused RED/GREEN tests:

```bash
pnpm vitest run --testTimeout=30000 --no-file-parallelism --maxWorkers=1 --minWorkers=1 \
  packages/drawnix/src/services/__tests__/audio-api-service.test.ts \
  -t "first status response resolves after abort"
```

Result: PASS — abort-after-first-query progress is suppressed.

```bash
pnpm vitest run --testTimeout=30000 --no-file-parallelism --maxWorkers=1 --minWorkers=1 \
  packages/drawnix/src/services/__tests__/generation-api-service.creative-embedded.test.ts \
  -t "stale legacy audio"
```

Result: PASS — stale legacy generate/resume audio callbacks are suppressed after retry-attempt changes.

Focused lifecycle regression:

```bash
pnpm vitest run --testTimeout=30000 --no-file-parallelism --maxWorkers=1 --minWorkers=1 \
  packages/drawnix/src/services/__tests__/task-queue-service-image-retry.test.ts \
  packages/drawnix/src/services/__tests__/audio-api-service.test.ts \
  packages/drawnix/src/services/__tests__/generation-api-service.creative-embedded.test.ts \
  packages/drawnix/src/services/__tests__/media-executor.test.ts
```

Result: PASS — 4 files / 91 tests.

Type gates:

```bash
pnpm exec tsc --noEmit --project packages/drawnix/tsconfig.spec.json --pretty false
pnpm nx run drawnix:typecheck
pnpm nx run web:typecheck
```

Result: all PASS.

Notes:

- The previous v24 dynamic workflow remains invalid as a complete review because five branches and synthesis failed/null. It contributed verified `AUD-002` findings only.
- No live provider call, push, deploy, or staging/production mutation was performed in this slice.

### Remaining gate

Run a fresh focused dynamic workflow re-audit for the repaired blockers (`IMG-001`, `IMG-002`, `VID-001`, `AUD-001/AUD-002`) with split/resume handling until synthesis/verifier is valid, then main-session verify any material findings before claiming final runtime lifecycle closure.

## 2026-06-24 v25 focused re-audit follow-up repair

### Dynamic workflow result

Workflow:

```bash
codex-flow run .codex-flow/generated/creative-runtime-lifecycle-v25-focused-reaudit-2026-06-24.workflow.ts
```

Journal: `.codex-flow/journal/creative-runtime-lifecycle-v25-focused-reaudit-2026-06-24.jsonl`.

Result:

- Branches completed: `IMG-001`, `IMG-002`, `VID-001`, `AUD-001`, `AUD-002`.
- Synthesis failed/null, so this workflow is not a complete passing review.
- Main-session verification accepted these material findings:
  - `IMG-002`: managed Creative image direct task route called `onSubmitted` fire-and-forget before content fetch/completion.
  - `IMG-002`: default/legacy async image route callback contract still typed/called `onSubmitted` synchronously.
  - `AUD-001`: audio timeout errors could lose `TIMEOUT` code/name on real timeout paths.
  - `AUD-001`: TaskQueue audio `onSubmitted` awaited a callback, but that callback did not wait for durable IndexedDB remoteId persistence.
  - `AUD-002`: later `pollUntilComplete()` audio status responses could emit progress after abort.

### Repairs

- Added typed timeout errors (`code/name = TIMEOUT`) for audio polling exhaustion and legacy `GenerationAPIService` timeout races.
- Added a post-query abort check in the audio polling loop before progress/terminal callback handling.
- Made TaskQueueService expose and await its per-task persistence chain for submitted callbacks.
- Made TaskQueue image/audio submitted callbacks wait for remoteId/invocationRoute persistence before adapter polling/finalization can continue.
- Made managed Creative image direct route await `options.onSubmitted` after guarded `updateRemoteId` and before content fetch/completion.
- Propagated async `onSubmitted?: void | Promise<void>` through default/legacy async image APIs and awaited it before polling.

### Key files

- `opentu/packages/drawnix/src/services/audio-api-service.ts`
- `opentu/packages/drawnix/src/services/generation-api-service.ts`
- `opentu/packages/drawnix/src/services/task-queue-service.ts`
- `opentu/packages/drawnix/src/services/media-executor/fallback-adapter-routes.ts`
- `opentu/packages/drawnix/src/services/async-image-api-service.ts`
- `opentu/packages/drawnix/src/services/media-api/image-api.ts`
- `opentu/packages/drawnix/src/services/media-api/types.ts`
- `opentu/packages/drawnix/src/services/media-executor/fallback-utils.ts`

### Verification

RED tests were first confirmed failing for the v25 findings:

- audio later-poll abort stale progress;
- audio polling exhaustion missing `TIMEOUT` code/name;
- managed Creative image direct route content fetch crossing a pending `onSubmitted`;
- legacy audio resume timeout missing `TIMEOUT` code/name;
- TaskQueue audio finalization crossing pending remoteId persistence.

GREEN focused tests:

```bash
pnpm vitest run --testTimeout=30000 --no-file-parallelism --maxWorkers=1 --minWorkers=1 \
  packages/drawnix/src/services/__tests__/task-queue-service-image-retry.test.ts \
  packages/drawnix/src/services/__tests__/audio-api-service.test.ts \
  packages/drawnix/src/services/__tests__/generation-api-service.creative-embedded.test.ts \
  packages/drawnix/src/services/__tests__/media-executor.test.ts
```

Result: PASS — 4 files / 96 tests.

Async image contract regression:

```bash
pnpm vitest run --testTimeout=30000 --no-file-parallelism --maxWorkers=1 --minWorkers=1 \
  packages/drawnix/src/services/__tests__/async-image-api-service.test.ts \
  packages/drawnix/src/services/media-api/image-api.test.ts \
  packages/drawnix/src/services/media-executor/fallback-utils.test.ts
```

Result: PASS — 3 files / 6 tests.

Type gates:

```bash
pnpm exec tsc --noEmit --project packages/drawnix/tsconfig.spec.json --pretty false
pnpm nx run drawnix:typecheck
pnpm nx run web:typecheck
```

Result: all PASS.

Notes:

- Existing `.npmrc` `${NPM_TOKEN}` warnings and Node/jsdom `localStorage` crypto warnings appeared; assertions passed.
- No live provider call, push, deploy, or staging/production mutation was performed in this slice.

### Remaining gate

The v25 synthesis node failed/null. Resume or rerun a focused workflow/synthesis after these repairs and require a valid synthesis/verifier before final runtime lifecycle closure.

## 2026-06-24 v27/v28 post-fix focused workflow closure

### Workflow evidence

The initial v26 post-fix workflow failed due transient backend/tool execution issues (`high demand` / null branches), so it was not counted.

Valid post-fix workflow evidence:

- IMG-002:
  - Workflow: `.codex-flow/generated/creative-runtime-lifecycle-v27-focused-postfix-serial-2026-06-24.workflow.ts`
  - Journal: `.codex-flow/journal/creative-runtime-lifecycle-v27-focused-postfix-serial-2026-06-24.jsonl`
  - Result: valid branch output, `verdict=pass`, `mustFix=[]`, confidence `0.86`.
  - Note: the same v27 run had null AUD branches and null synthesis, so only the IMG branch is counted.
- AUD-001:
  - Workflow: `.codex-flow/generated/creative-runtime-lifecycle-v28-aud001-postfix-2026-06-24.workflow.ts`
  - Journal: `.codex-flow/journal/creative-runtime-lifecycle-v28-aud001-postfix-2026-06-24.jsonl`
  - Result: `verdict=pass`, `mustFix=[]`, confidence `0.86`.
- AUD-002:
  - Workflow: `.codex-flow/generated/creative-runtime-lifecycle-v28-aud002-postfix-2026-06-24.workflow.ts`
  - Journal: `.codex-flow/journal/creative-runtime-lifecycle-v28-aud002-postfix-2026-06-24.jsonl`
  - Result: `verdict=pass`, `mustFix=[]`, confidence `0.90`.
- Synthesis:
  - Workflow: `.codex-flow/generated/creative-runtime-lifecycle-v28-postfix-synthesis-2026-06-24.workflow.ts`
  - Journal: `.codex-flow/journal/creative-runtime-lifecycle-v28-postfix-synthesis-2026-06-24.jsonl`
  - Result: `overallVerdict=pass`, `mustFix=[]`, confidence `0.87`.

### Synthesis verdict

Valid synthesis result:

> IMG-002、AUD-001、AUD-002 均为 pass 且 mustFix 为空，证据覆盖 provider accepted -> onSubmitted -> durable remoteId/idempotency -> timeout/abort -> retry/resume -> stale callback -> finalization/storage 的跨层闭环。

### Main-session arbitration

Main session accepted the v27/v28 post-fix workflow closure because it matches direct code inspection and executable verification already run in this slice:

- Focused lifecycle regression: PASS — 4 files / 96 tests.
- Async image contract regression: PASS — 3 files / 6 tests.
- Type gates: `tsconfig.spec`, `drawnix:typecheck`, `web:typecheck` all PASS.

Known workflow/test-noise notes:

- v26 failed/null due transient backend/tool errors and is not counted.
- v27 full `media-executor` run inside the sub-agent reported a `Blob` matcher/environment issue under a different package-local invocation. The main session canonical command from repo root passed the same focused suite; this was treated as test-runner environment noise, not an implementation blocker.

### Remaining gate

Focused runtime lifecycle blockers (`IMG-001`, `IMG-002`, `VID-001`, `AUD-001`, `AUD-002`) are locally repaired and focused-workflow closed. The next required gate before production remains the broader final audit / staging decision workflow, not another focused blocker repair loop unless new evidence appears.

## 2026-06-24 Trellis check fallback after v27/v28 closure

The runtime did not expose a generic Trellis sub-agent dispatch tool in this session, so Phase 2.2 quality check was executed in the main session as a `trellis-check` fallback.

### Commands and results

OpenTU focused lifecycle and async image regressions:

```bash
cd /mnt/f/code/project/opentu
pnpm vitest run --testTimeout=30000 --no-file-parallelism --maxWorkers=1 --minWorkers=1 \
  packages/drawnix/src/services/__tests__/task-queue-service-image-retry.test.ts \
  packages/drawnix/src/services/__tests__/audio-api-service.test.ts \
  packages/drawnix/src/services/__tests__/generation-api-service.creative-embedded.test.ts \
  packages/drawnix/src/services/__tests__/media-executor.test.ts \
  packages/drawnix/src/services/__tests__/async-image-api-service.test.ts \
  packages/drawnix/src/services/media-api/image-api.test.ts \
  packages/drawnix/src/services/media-executor/fallback-utils.test.ts
```

Result: PASS — 7 files / 102 tests.

OpenTU type gates:

```bash
cd /mnt/f/code/project/opentu
pnpm exec tsc --noEmit --project packages/drawnix/tsconfig.spec.json --pretty false
pnpm nx run drawnix:typecheck
pnpm nx run web:typecheck
```

Result: all PASS.

new-api backend regression:

```bash
cd /mnt/f/code/project/new-api
go test -count=1 ./service ./controller ./model ./relay ./relay/common ./relay/constant
```

Result: PASS.

new-api admin frontend checks:

```bash
cd /mnt/f/code/project/new-api/web/default
pnpm typecheck
pnpm exec eslint src/features/system-settings/models/creative-model-bindings-section.tsx
```

Result: PASS.

No-secrets Creative release gate:

```bash
cd /mnt/f/code/project/new2fly
python3 scripts/creative_release_gate.py check --run-new-api-tests --source-diff-check
```

Result: PASS — embedded artifact contract holds, source-only `git diff --check` passes, selected new-api Go tests and `go build ./...` pass.

### Main-session static check

Manually rechecked the repaired runtime lifecycle edges:

- managed Creative image submit persists `remoteTaskId` and awaits `options.onSubmitted(...)` before polling/content fetch/completion;
- managed Creative image timeout or local abort after remote acceptance leaves the task recoverable/polling instead of writing terminal failure;
- submit-interrupted Creative image retry reuses the original idempotency key path;
- audio `onSubmitted` waits for TaskQueue persistence, polling timeout preserves `TIMEOUT`, and post-query abort is checked before progress/terminal handling;
- remote audio/video retry with durable `remoteId` uses resume instead of fresh provider submission.

Known non-failing noise:

- `.npmrc` `${NPM_TOKEN}` substitution warnings.
- Node/jsdom `localStorage` crypto initialization warnings in Vitest.

No live provider call, push, deploy, or staging/production mutation was performed in this check.

## 2026-06-24 v29/v30/v31 final goal audit and high-priority video repairs

### Dynamic final audit status

The broader final audit target was product goal attainment / new issue discovery, not just fix-completion review.

Workflow evidence:

- v29:
  - Workflow: `.codex-flow/generated/creative-final-goal-audit-v29-2026-06-24.workflow.ts`
  - Journal: `.codex-flow/journal/creative-final-goal-audit-v29-2026-06-24.jsonl`
  - Result: incomplete. Four branches produced useful current-code output, but `opentu-runtime-state-machine` and `cache-canvas-refresh-chain` timed out/null; synthesis and verification were null. Not counted as complete.
- v30:
  - Workflow: `.codex-flow/generated/creative-final-goal-audit-v30-missing-branches-2026-06-24.workflow.ts`
  - Journal: `.codex-flow/journal/creative-final-goal-audit-v30-missing-branches-2026-06-24.jsonl`
  - Result: six missing OpenTU runtime/cache branches completed, but synthesis and verification were null. Branch findings counted only after v31 compact synthesis/verification.
- v31:
  - Workflow: `.codex-flow/generated/creative-final-goal-audit-v31-synthesis-verify-2026-06-24.workflow.ts`
  - Journal: `.codex-flow/journal/creative-final-goal-audit-v31-synthesis-verify-2026-06-24.jsonl`
  - Compact input: `final-goal-audit-v29-v30-compact-results.json`
  - Result: valid synthesis and valid adversarial verification; final verdict `needs-fix`.

Confirmed material findings from v31 verification:

- `MF-002` HIGH: video adapter submit callback persisted `remoteId` to IndexedDB but did not call TaskQueue `onSubmitted`, so in-memory task state could miss `remoteId` and later failure writeback could destroy resume semantics.
- `MF-003` HIGH: video adapter / legacy video polling lacked first-class `AbortSignal` and post-response abort checks.
- `MF-004` HIGH: generated video remote URLs were not stabilized into Cache Storage / same-origin local URLs.
- Remaining medium items after this slice include cache recovery coverage, catalog bootstrap retry, and source/artifact/staging provenance gates.

### Repairs

- `executeVideoViaAdapter()` now:
  - records submitted video id;
  - writes guarded `remoteId` / invocation route;
  - awaits `options.onSubmitted(videoId, invocationRoute)` before adapter execution can continue;
  - caches generated video results as stable `/__aitu_cache__/video/<taskId>.<ext>` entries with `contentUrl`, `remoteTaskId`, and `providerTaskId` metadata.
- Default/legacy video adapter request contract now carries `signal`, `onProgress`, and `onSubmitted` as top-level fields while retaining legacy `params` callbacks for compatibility.
- `videoAPIService` now supports `AbortSignal` across submit, reference-image fetches, status query, resume polling, poll sleep/backoff, post-response handling, progress callbacks, and terminal handling.
- Video completion/resume paths in `FallbackMediaExecutor` now force remote video caching and persist recovery metadata.

### RED → GREEN verification

RED tests were first confirmed failing:

- `media-executor.test.ts -t "passes video adapter progress"` failed because `options.onSubmitted` was never called and video completion still returned the remote URL.
- `video-api-service.session-broker.test.ts -t "fails fast without querying"` failed because an already-aborted resume signal still entered the status query path.

GREEN targeted tests:

```bash
pnpm vitest run --testTimeout=30000 --no-file-parallelism --maxWorkers=1 --minWorkers=1 \
  packages/drawnix/src/services/__tests__/media-executor.test.ts -t "passes video adapter progress"

pnpm vitest run --testTimeout=30000 --no-file-parallelism --maxWorkers=1 --minWorkers=1 \
  packages/drawnix/src/services/__tests__/video-api-service.session-broker.test.ts -t "fails fast without querying"
```

Result: both PASS.

Broader verification:

```bash
pnpm vitest run --testTimeout=30000 --no-file-parallelism --maxWorkers=1 --minWorkers=1 \
  packages/drawnix/src/services/__tests__/media-executor.test.ts \
  packages/drawnix/src/services/__tests__/video-api-service.session-broker.test.ts
```

Result: PASS — 2 files / 49 tests.

```bash
pnpm vitest run --testTimeout=30000 --no-file-parallelism --maxWorkers=1 --minWorkers=1 \
  packages/drawnix/src/services/__tests__/task-queue-service-image-retry.test.ts \
  packages/drawnix/src/services/__tests__/generation-api-service.creative-embedded.test.ts \
  packages/drawnix/src/services/__tests__/media-executor.test.ts \
  packages/drawnix/src/services/__tests__/video-api-service.session-broker.test.ts
```

Result: PASS — 4 files / 86 tests.

Type gates:

```bash
pnpm exec tsc --noEmit --project packages/drawnix/tsconfig.spec.json --pretty false
pnpm nx run drawnix:typecheck
pnpm nx run web:typecheck
```

Result: all PASS.

Known non-failing noise:

- `.npmrc` `${NPM_TOKEN}` substitution warnings.
- Node/jsdom `localStorage` crypto initialization warnings in Vitest.

No live provider call, push, deploy, or staging/production mutation was performed in this slice.

## 2026-06-24 v31 medium repairs — MF-005 / MF-006

### Findings repaired

- `MF-006` catalog bootstrap retry: `initializeCreativeManagedSessionBroker()` no longer permanently caches an `error` bootstrap result. Failed initialization clears the singleton promise so a later logged-in/recovered session can retry `/creative/api/bootstrap` and `/creative/api/models`.
- `MF-005` generated media cache recovery coverage:
  - media library projection now carries durable generated video recovery metadata (`contentUrl`, `remoteTaskId`, `providerTaskId`, `mimeType`) into preview items, using the video content route resolver rather than the image resolver;
  - video canvas insertion paths now persist safe generated-video metadata on inserted video nodes, including direct insert, selected-frame insert, media-library viewer insert, task queue insert, and quick insert;
  - service worker ordinary virtual media cache misses now emit a cache-failure notification for image/video/audio virtual URLs before returning 404, instead of only notifying thumbnail fallback misses;
  - video metadata persisted on canvas nodes is intentionally allowlisted; callback/webhook/control fields are not copied.

### Verification

Targeted regression:

```bash
cd /mnt/f/code/project/opentu
pnpm vitest run --testTimeout=30000 --no-file-parallelism --maxWorkers=1 --minWorkers=1 \
  packages/drawnix/src/services/__tests__/media-library-projection.test.ts \
  packages/drawnix/src/data/video.test.ts \
  packages/drawnix/src/services/creative-session-broker.test.ts
```

Result: PASS — 3 files / 21 tests.

Broader OpenTU lifecycle regression after MF-005/MF-006 repairs:

```bash
pnpm vitest run --testTimeout=30000 --no-file-parallelism --maxWorkers=1 --minWorkers=1 \
  packages/drawnix/src/services/creative-session-broker.test.ts \
  packages/drawnix/src/services/__tests__/media-library-projection.test.ts \
  packages/drawnix/src/data/video.test.ts \
  packages/drawnix/src/hooks/__tests__/useGeneratedMediaCacheMissRecovery.test.tsx \
  packages/drawnix/src/services/__tests__/media-executor.test.ts \
  packages/drawnix/src/services/__tests__/video-api-service.session-broker.test.ts \
  packages/drawnix/src/services/__tests__/task-queue-service-image-retry.test.ts \
  packages/drawnix/src/services/__tests__/generation-api-service.creative-embedded.test.ts
```

Result: PASS — 8 files / 115 tests.

Type gates:

```bash
pnpm exec tsc --noEmit --project packages/drawnix/tsconfig.spec.json --pretty false
pnpm nx run drawnix:typecheck
pnpm nx run web:typecheck
```

Result: all PASS.

Known non-failing noise:

- `.npmrc` `${NPM_TOKEN}` substitution warnings.
- Node/jsdom `localStorage` crypto initialization warnings in Vitest.
- Sourcemap warning for `postmessage-duplex` package source map.

No live provider call, push, deploy, or staging/production mutation was performed in this slice.

Remaining before production decision:

- `MF-007` provenance/staging gate: rebuild/sync embedded artifact, run release/source diff gate, and run target staging smoke after explicit authorization for staging/prod mutation.
- Post-fix dynamic workflow re-audit must still be rerun; null/timeout branches must not be counted as pass.

## 2026-06-24 v36 repair slice — OpenTU display rehydrate consumers + new-api lifecycle fixes

### Findings repaired / narrowed

- `NA-CREATIVE-SYNC-GATE-001`: sync `/creative/relay/v1/images/generations` managed-binding rejection now uses executable availability semantics instead of raw binding existence. Disabled bindings, non-canary bindings, mock gate-off bindings, and live bindings without ready channels are allowed to fall through to normal provider relay; active executable managed image bindings are rejected with the task-route guidance.
- `SUNO-RAW-DATA-CONTENT-URL`: Suno fetch DTOs now sanitize raw persisted provider data. HTTP(S) `audio_url`, `video_url`, `image_url`, and `image_large_url` values are rewritten to owner/platform-scoped same-origin content endpoints; raw provider URLs are not returned in the fetch response.
- `IMG-DURABLE-SUBMIT-RECOVERY`: no-upstream-id Creative image submit expiry now becomes an explicit unrecoverable/auditable task state with refund/outbox path instead of a generic timeout. This is not a provider-side idempotent lookup/outbox recovery implementation; it makes the unrecoverable branch explicit and refunded.
- `MF-005-VIDEO-DISPLAY-REHYDRATE-GAP`: remaining `VideoPosterPreview` consumers now receive generated-video rehydrate props where durable metadata exists or can be derived from `/__aitu_cache__/video/<taskId>...`:
  - prompt history preview table and media-viewer items;
  - video-analyzer related task cards;
  - Markdown asset embeds;
  - video-analyzer shot generated-video previews;
  - MV creator shot generated-video previews.
- Prompt history tests now mock the current lazy `utils/message-plugin` wrapper rather than only `tdesign-react`, removing a stale test harness mismatch found during verification.
- `TestCreativeImageRelayRejectsNonceAndForbiddenFieldsBeforeSessionBroker` now uses an explicit image-hint test model so the route assertion is deterministic regardless of prior global endpoint-cache state.

### Verification

OpenTU type gate:

```bash
cd /mnt/f/code/project/opentu
pnpm exec tsc --noEmit --project packages/drawnix/tsconfig.spec.json --pretty false
```

Result: PASS. Non-failing warning: `.npmrc` `${NPM_TOKEN}` substitution warning.

OpenTU targeted regression:

```bash
pnpm vitest run --testTimeout=30000 --no-file-parallelism --maxWorkers=1 --minWorkers=1 \
  packages/drawnix/src/services/prompt-history-service.test.ts \
  packages/drawnix/src/components/prompt-history/PromptHistoryTool.test.tsx \
  packages/drawnix/src/components/shared/VideoPosterPreview.test.tsx
```

Result: PASS — 3 files / 24 tests. Non-failing warnings: `.npmrc` `${NPM_TOKEN}`, stale Browserslist data, and `postmessage-duplex` sourcemap warning.

new-api targeted and broader backend regression:

```bash
cd /mnt/f/code/project/new-api
go test -count=1 ./controller -run 'TestCreativeImageSyncRouteAllowsInactiveManagedBindingToProviderRelay|TestCreativeImageRelayRejectsNonceAndForbiddenFieldsBeforeSessionBroker' -v
go test -count=1 ./controller ./service ./relay
```

Result: PASS — `./controller`, `./service`, and `./relay` passed in the broader run.

Earlier v36 targeted commands also passed for:

```bash
go test -count=1 ./controller ./service -run 'TestCreativeImageSyncRoute|TestShouldRejectCreativeManagedImageBindingSyncRoute' -v
go test -count=1 ./relay -run TestSunoTaskModel2DtoRewritesRawProviderURLsToContentProxy -v
go test -count=1 ./controller -run 'TestCreativeImageSyncRoute|TestCreativeRelaySunoFetchIsOwnerScoped' -v
go test -count=1 ./service -run 'TestFailTaskWithCASAndRefundMarksCreativeImageSubmitUnrecoverable|TestCollectPollingTaskBucketsExpiresAmbiguousCreativeImageSubmit' -v
```

### Remaining gates before any readiness claim

- Rebuild/sync embedded Creative dist from the current OpenTU source into `new-api` artifacts.
- Run the release/source artifact gate after rebuild.
- Run staging smoke/provenance for the current candidate after explicit deployment/staging authorization.
- Run final dynamic workflow re-audit with the mandatory gates: slow-provider timing, cross-layer state-machine synthesis, and refresh/retry/Cache Storage E2E. Timeout/null branches still must not count as pass.

## 2026-06-24 v36 artifact/release gate

After the v36 code repairs, rebuilt OpenTU web and synced the embedded Creative artifact into both new-api artifact locations.

Command:

```bash
cd /mnt/f/code/project/new2fly
python3 scripts/creative_release_gate.py build-sync-check --run-new-api-tests --source-diff-check
```

Result: PASS.

Evidence from the gate:

- OpenTU `pnpm build:web` completed:
  - `web:typecheck` passed;
  - Vite app build passed;
  - SW build passed;
  - embedded postprocess completed.
- Sync completed:
  - `/mnt/f/code/project/opentu/dist/apps/web` -> `/mnt/f/code/project/new-api/web/creative/dist`
  - `/mnt/f/code/project/opentu/dist/apps/web` -> `/mnt/f/code/project/new-api/router/web/creative/dist`
- Artifact contract checks passed:
  - opentu/new-api web/new-api router index refs each contain 2 `/creative/assets` entries;
  - idle-prefetch manifest has 266 `/creative/assets` refs for each artifact location;
  - static brand contract holds for all three locations;
  - new-api web and router embedded dirs match OpenTU: 173 files each;
  - version provenance: `version=0.9.6`, `gitCommit=3f13916427a6234239db437fdf8db07966b343a5`;
  - no generated sourcemaps found;
  - embedded dist text hygiene holds.
- Source diff checks passed:
  - `new2fly`: `git diff --check -- :!.codex-flow/** :!.cache/**`
  - `opentu`: `git diff --check -- :!dist/**`
  - `new-api`: `git diff --check -- :!web/creative/dist/** :!router/web/creative/dist/**`
- new-api tests/build from release gate passed:
  - `go test -count=1 .`
  - `go test -count=1 ./router ./middleware ./controller ./model ./service ./relay/...`
  - `go build ./...`

Non-failing warnings observed during build: `.npmrc` `${NPM_TOKEN}` substitution warnings, Sass deprecation warnings, stale Browserslist data warning, dynamic/static import chunking warnings, and chunk-size warnings.

Remaining before readiness claim:

- Current staging/target smoke and provenance for this rebuilt artifact is still pending.
- Final dynamic workflow re-audit is still pending and must include slow-provider timing, cross-layer state-machine synthesis, and refresh/retry/Cache Storage E2E.

## 2026-06-24 v36 local embedded smoke/provenance

Ran a disposable local new-api instance with a temporary SQLite database and the current rebuilt embedded Creative artifact. This did not mutate staging or production.

Server shape:

- new-api path: `/mnt/f/code/project/new-api`
- temporary SQLite path under `/tmp/newapi-creative-smoke.*`
- random localhost port
- non-default temporary `SESSION_SECRET`

Command shape:

```bash
cd /mnt/f/code/project/new2fly
python3 scripts/creative_release_gate.py check \
  --source-diff-check \
  --embedded-smoke-url http://127.0.0.1:<temp-port>/creative/ \
  --drawnix-ready-timeout-ms 90000
```

Result: PASS.

Evidence:

- artifact contract rechecked: PASS;
- source diff checks rechecked: PASS;
- `pnpm e2e:creative-embedded` executed against the local new-api `/creative/` URL;
- Playwright result: PASS — 4 tests / 4 workers:
  1. app shell served and API/relay paths stay out of SPA fallback;
  2. refresh keeps board state and cache-miss recovery rehydrates generated canvas media;
  3. slow remote Creative image task remains resumable until provider completion;
  4. refresh resumes a remote Creative image task and materializes Cache Storage.

Non-failing warning: `.npmrc` `${NPM_TOKEN}` substitution warning and Node `NO_COLOR`/`FORCE_COLOR` warning.

Remaining gates:

- staging/target smoke and provenance are still pending for the deployed target environment;
- final dynamic workflow re-audit is still pending after staging/target verification.

## 2026-06-24 staging deploy blocker repair — SQLite Log unique column migration

During the local Docker staging refresh to image `sha256:28ba17f4cc20471b7d7e49c5045a57005cf341ea14aa0a80d950c39cea950214`, the preserved staging SQLite database failed application startup:

- failure class: SQLite existing-table migration incompatibility;
- failing operation: `ALTER TABLE logs ADD task_billing_outbox_id integer UNIQUE` generated by GORM `AutoMigrate(&Log{})`;
- user/channel/config data was not reset and volumes were not deleted.

Repair applied in `new-api`:

- `model/main.go`: before `AutoMigrate(&Log{})`, SQLite existing `logs` tables now receive nullable `task_billing_outbox_id` via plain `ALTER TABLE ... ADD COLUMN` without inline `UNIQUE`;
- after `AutoMigrate`, `idx_logs_task_billing_outbox_id` is ensured explicitly;
- same helper is used by normal DB migration, fast DB migration, and separate LOG_DB migration;
- `model/log_migration_test.go`: regression creates a legacy SQLite `logs` table without `task_billing_outbox_id`, runs the migration path, verifies the column/index, and verifies duplicate non-null outbox IDs are rejected.

Fresh verification:

```bash
cd /mnt/f/code/project/new-api
go test -count=1 ./model -run TestEnsureSQLiteLogTaskBillingOutboxColumnAllowsAutoMigrateExistingLogs
# ok github.com/QuantumNous/new-api/model 0.043s

go test -count=1 ./controller ./service ./relay
# ok github.com/QuantumNous/new-api/controller 3.360s
# ok github.com/QuantumNous/new-api/service 3.667s
# ok github.com/QuantumNous/new-api/relay 0.025s
```

Staging image rebuilt and deployed:

- image: `new-api-creative-embed:staging-current`
- image ID: `sha256:93bdeee160637d7a6a22398550b4596e73d427080dc5e62dc0b0d2dd2de46cbe`
- container: `newapi-opentu-staging-new-api`
- volumes preserved:
  - `newapi-opentu-staging_newapi_opentu_staging_data:/data`
  - `newapi-opentu-staging_newapi_opentu_staging_logs:/app/logs`
- no `down -v`; no DB/channel/user reset.

Fresh staging smoke after repair:

| Check | Result |
| --- | --- |
| container health | healthy |
| `GET /api/status` | HTTP 200 |
| `HEAD /creative/` | HTTP 200, `Cache-Control: no-cache` |
| `GET /creative/version.json` | HTTP 200, version `0.9.6`, OpenTU git commit `3f13916427a6234239db437fdf8db07966b343a5` |
| unauth `GET /creative/api/bootstrap` | HTTP 401, JSON, `private, no-store` |
| unauth `GET /creative/api/models` | HTTP 401, JSON, `private, no-store` |
| wrong-method relay GET `/creative/relay/v1/images/tasks` | HTTP 404 JSON, not SPA HTML |
| authenticated `/creative/api/bootstrap` | HTTP 200; CSRF/nonce present; values not recorded |
| authenticated `/creative/api/models` | HTTP 200; Duomi/GrsAI live schemas present |
| admin `GET /api/creative/model-bindings` | HTTP 200 with dashboard session + `New-Api-User` |
| admin `POST /api/creative/model-bindings/validate` | HTTP 200, `valid=true` |
| admin `POST /api/creative/model-bindings/dry-run` | HTTP 200, `noProviderCall=true`, 3 bindings |
| browser `/creative/` | loaded with title `New API Creative - 我的画板1` |
| browser parameter popup | verified groups `图片尺寸`, `图片分辨率`, `质量`; verified `21:9 超宽`, `1K`, and quality options |
| browser model dropdown | verified `Duomi GPT Image 2`, `GrsAI GPT Image 2`, `GrsAI GPT Image 2 VIP` |

Provider-call boundary:

- No live Duomi/GrsAI provider call was made in this post-migration staging smoke.
- Credentials, cookies, CSRF/nonce, provider keys, signed URLs, and raw provider payloads were not printed or persisted.
- A temporary 429 was observed during rapid repeated smoke attempts; after waiting for the rate-limit window, the UI panel smoke passed. This is recorded as smoke-run interference, not a provider failure.

## 2026-06-24 final goal dynamic workflow attempts after staging repair

Post-staging-repair dynamic workflow attempts were run but are **not counted as a valid final audit pass**:

1. `.codex-flow/generated/creative-final-goal-audit-v37.workflow.ts`
   - backend branch completed with material findings mostly around release hygiene / production gate;
   - frontend branch returned an empty object;
   - runtime lifecycle, staging/provenance, and security branches timed out;
   - synthesis and verifier failed/null.
2. `.codex-flow/generated/creative-final-goal-audit-v37b-missing.workflow.ts`
   - attempted to split missing branches;
   - all focused branches timed out;
   - workflow was interrupted before invalid synthesis could be treated as evidence.
3. `.codex-flow/generated/creative-final-goal-audit-v37c-targeted.workflow.ts`
   - attempted narrower file-scoped branch prompts after fast-context/codegraph file discovery;
   - all targeted branches timed out;
   - workflow was interrupted before invalid synthesis.

Conclusion: dynamic workflow execution was attempted and journaled, but timeout/null/empty branches are invalid by the project audit rules and do not prove final goal attainment. Main-session code/source/runtime verification continues separately; any final conclusion must explicitly separate main-session evidence from invalid codex-flow attempts.

Journals:

- `.codex-flow/journal/creative-final-goal-audit-v37.jsonl`
- `.codex-flow/journal/creative-final-goal-audit-v37b-missing.jsonl`
- `.codex-flow/journal/creative-final-goal-audit-v37c-targeted.jsonl`

## 2026-06-25 release gate rerun after staging migration repair

Fresh release/build gate command:

```bash
cd /mnt/f/code/project/new2fly
python3 scripts/creative_release_gate.py build-sync-check --run-new-api-tests --source-diff-check
```

Result: PASS, exit code 0.

Covered by this run:

- OpenTU web build, typecheck, service-worker build, and embedded postprocess.
- Dist sync into both new-api embedded Creative locations.
- Embedded artifact contract: route refs, idle-prefetch refs, static brand contract, 173-file parity, version provenance, sourcemap absence, text hygiene.
- `git diff --check` for new2fly/opentu/new-api with generated-output exclusions.
- new-api `go test -count=1 .`.
- new-api `go test -count=1 ./router ./middleware ./controller ./model ./service ./relay/...`.
- new-api `go build ./...`.

No live provider calls were made. Production deployment remains outside this validation.

## 2026-06-25 release gate rerun after committing OpenTU source

OpenTU source was committed as `57d328340acee6ba5d775296433d0d909cc6ddfe` before rebuilding embedded Creative artifacts, so the embedded dist provenance no longer points at a stale source commit.

Fresh gate command:

```bash
cd /mnt/f/code/project/new2fly
python3 scripts/creative_release_gate.py build-sync-check --run-new-api-tests --source-diff-check
```

Result: PASS, exit code 0.

Key evidence:

- Embedded artifact contract passed.
- Version provenance: `version=0.9.6`, `gitCommit=57d328340acee6ba5d775296433d0d909cc6ddfe`.
- `git diff --check` passed for new2fly/opentu/new-api with generated-output exclusions.
- new-api `go test -count=1 .` passed.
- new-api `go test -count=1 ./router ./middleware ./controller ./model ./service ./relay/...` passed.
- new-api `go build ./...` passed.

OpenTU `apps/web/public/version.json` was restored after the build because it is source-side build metadata churn. No live provider calls were made.
