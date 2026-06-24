# Runtime lifecycle postfix v7 result — 2026-06-22

## Scope

This note records the main-session verification and remediation after dynamic workflow v7/v7b/v7c on the Creative image runtime lifecycle. The review target is end-to-end runtime correctness, not merely whether previous patch items were touched.

Repositories:

- `new-api`: `/mnt/f/code/project/new-api`
- `opentu`: `/mnt/f/code/project/opentu`
- orchestration/docs: `/mnt/f/code/project/new2fly`

## Workflow inputs reviewed

- `.codex-flow/generated/creative-runtime-lifecycle-v7.workflow.ts`
- `.codex-flow/generated/creative-runtime-lifecycle-v7b.workflow.ts`
- `.codex-flow/generated/creative-runtime-lifecycle-v7c-synthesis.workflow.ts`
- `.codex-flow/journal/creative-runtime-lifecycle-v7.jsonl`
- `.codex-flow/journal/creative-runtime-lifecycle-v7b.jsonl`
- `.codex-flow/journal/creative-runtime-lifecycle-v7c-synthesis.jsonl`

Main-session verification status: v7c findings were not accepted blindly; code paths were checked in `new-api` and `opentu` before remediation.

## Findings handled in this round

| Finding | Main-session verdict | Remediation |
|---|---:|---|
| `ERROR-RAW-ORIGINAL` | confirmed HIGH | Sanitized task error persistence in `useTaskExecutor`; added UI-level legacy sanitization in `TaskItem`, `batch-image-generation`, and `image-generation-anchor-view-model` so previously stored raw `originalError` cannot be rendered directly. |
| `F2` missing selected-key fail-closed for Creative image rows without idempotency | confirmed MEDIUM | `creativeTaskRequiresStoredKey` now treats managed live Creative image tasks as selected-key-affinity required even without idempotency. Added polling test for missing stored key without idempotency. |
| `F1` successful historical live provider URL not repaired by status fetch | confirmed MEDIUM | `creativeReconcileLiveImageTask` now repairs successful managed live image tasks whose private result URL is still a provider URL by materializing into the asset-backed content path. Added fetch repair test. |
| `OTU-TASK-001` restore emits only first restored task | confirmed MEDIUM | `restoreTasks` now emits `taskCreated` for every restored PENDING/PROCESSING task, so each resumable task can be picked up after refresh. Added regression test. |
| `PARAM-EDIT-USERPARAMS` edit dialog drops runtime schema params | confirmed MEDIUM | `handleEditTask` now merges sanitized editable `userParams` into the parameter popup state via `normalizeCreativeImageEditableUserParams`. Added helper test. |
| `PARAM-CANVAS-TARGET` canvas ignores backend target dimensions | confirmed MEDIUM | `useAutoInsertToCanvas` now falls back to `targetWidth/targetHeight` when decoded actual dimensions are not available. Added regression test. |
| `CACHE-REMOTE-GATE` non-cache generated image URLs bypass readiness | confirmed MEDIUM | Generated image readiness now runs whenever a task has a safe broker/content URL or a generated cache URL. Non-cache same-origin content URLs are fetched and decoded before canvas post-processing is marked complete. Added `/creative/api/assets/.../content` regression test. |
| `COMPLETED-ANCHOR-RETRY` completed post-processing failure regenerates provider task | confirmed MEDIUM | Anchor retry for completed task + failed post-processing now retries the local post-processing/canvas insertion path only; it no longer calls `retryTask(... allowCompleted)`. Added regression test. |
| `INSERTPROMPT-DIMS` grouped insertPrompt path uses one dimension for all images | confirmed LOW | Grouped insertPrompt image item dimensions now use per-item verified/fallback dimensions. Covered by existing grouped dimension regression path. |
| `MEDIA-LIB-THUMBNAILURLS` media-library projection drops thumbnail URLs | confirmed LOW | Asset projection now preserves `thumbnailUrls[0] || thumbnailUrl || previewImageUrl`. Added projection test. |
| `CANVAS-REHYDRATE` canvas node does not itself store all remote metadata | reduced MEDIUM | Existing cache-miss recovery still depends on task storage matching. This round improved content URL compatibility and rehydrate readiness, but durable per-node metadata remains a broader follow-up if task storage is later cleaned. |
| `PROMPT-PREVIEW-REHYDRATE` prompt preview example lacks rehydrate metadata | LOW follow-up | Not changed in this round; preview/media-library paths are now covered, prompt preview can be handled as a small follow-up if still user-visible. |

## Verification run

### NewAPI

```bash
cd /mnt/f/code/project/new-api
gofmt -w controller/creative_image_tasks.go controller/creative_test.go service/task_polling.go service/task_polling_affinity_test.go
go test -count=1 ./controller -run 'TestCreativeImageTaskFetchRepairsSuccessfulLiveProviderURL|TestCreativeImageTaskFetchPollsLiveTaskWithCASBillingAndPrivateDTO|TestCreativeImageTaskContentProxiesLiveResultPrivately|TestCreativeImageTaskContentFailsClosedWhenAssetRuntimeDisabled'
go test -count=1 ./service -run 'TestDispatchPlatformUpdateCreativeImageMissingStoredKeyWithoutIdempotencyFailsClosed|TestDispatchPlatformUpdateCreativeImagePollsLiveTaskToSuccess|TestUpdateVideoSingleTaskCreativeMissingStoredKeyFailsClosed|TestUpdateSunoTasksCreativeMissingStoredKeyFailsClosed'
go test -count=1 ./model ./relay ./relay/common ./relay/constant
git diff --check
```

Result: passed.

### OpenTU

```bash
cd /mnt/f/code/project/opentu
pnpm vitest run --no-file-parallelism --maxWorkers=1 --minWorkers=1 \
  packages/drawnix/src/hooks/__tests__/useTaskExecutor.test.ts \
  packages/drawnix/src/hooks/__tests__/useAutoInsertToCanvas.test.ts \
  packages/drawnix/src/services/__tests__/task-queue-service-image-retry.test.ts \
  packages/drawnix/src/services/__tests__/media-library-projection.test.ts \
  packages/drawnix/src/components/ttd-dialog/creative-image-task-params.test.ts \
  packages/drawnix/src/services/__tests__/media-executor.test.ts
pnpm nx run drawnix:typecheck
pnpm nx run web:typecheck
git diff --check
```

Result: passed. The `.npmrc` `${NPM_TOKEN}` warnings and existing crypto/indexedDB stderr in tests did not fail the commands.

### Orchestration repo

```bash
cd /mnt/f/code/project/new2fly
git diff --check
```

Result: passed.

## Remaining required gate

Run another dynamic workflow after this remediation. The workflow must not only verify the above patches; it must re-audit the whole slow-provider / refresh / retry / cache / canvas / task-history / dock lifecycle and force synthesis to reconstruct the cross-layer state machine.
