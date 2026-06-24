# Runtime lifecycle postfix v6 result — 2026-06-22

## Scope

This record covers the v6 repair pass after the runtime lifecycle re-audit identified two must-fix issues in the Creative live image lifecycle.

Repositories touched:

- `new-api`: backend task terminalization, provider content materialization, polling tests.
- `opentu`: frontend task executor refresh/resume timeout gate.
- `new2fly`: Trellis/spec/audit records only.

## v6 re-audit verdict

The v6 workflow verdict was **fail** because it found two material runtime lifecycle defects:

1. `MUST-001-DURABLE-PROVIDER-URL`
   - Live image success paths could persist provider `ResultURL` directly in `Task.PrivateData.ResultURL`.
   - If the first browser content read happened after a provider signed URL expired, a `SUCCESS` task could not be recovered.
2. `MUST-002-REFRESH-EXPIRED-REMOTE-RESUME`
   - OpenTU refresh could resume `PROCESSING + remoteId` image tasks that had already exceeded the remote timeout budget.
   - The timeout interval could then mark the same task failed, creating an inconsistent late-success/failed race.

Main-session verification used `fast-context + codegraph` for area location, then direct file/test inspection. Both findings were confirmed.

## Fix summary

### Backend: terminal success requires durable asset URL

Changed files:

- `new-api/service/creative_image_adapter.go`
- `new-api/controller/creative_image_tasks.go`
- `new-api/service/task_polling.go`
- `new-api/controller/creative_test.go`
- `new-api/service/task_polling_affinity_test.go`

Contract now enforced:

- A live image task may reach backend `SUCCESS` only after provider result content is materialized into Creative asset storage.
- The durable task result source is `/creative/api/assets/:assetId/content`, not a provider signed URL.
- If provider content materialization fails, the task remains non-terminal and can be retried by poll/reconcile instead of recording `SUCCESS` with an expiring provider URL.
- Historical provider URLs in content endpoint fallback can still be materialized on first read, but new terminal success paths no longer rely on that fallback.

Implementation notes:

- Added shared service helper `MaterializeCreativeImageProviderResult`.
- Moved asset-content URL parsing to service helper `CreativeAssetContentURLAssetID`.
- Submit immediate-success path, fetch reconcile path, and background polling terminal path all call materialization before success persistence.
- Polling test now verifies persisted `PrivateData.ResultURL` is an asset content URL and provider image content is fetched once.

### Frontend: expired remote resume fail-fast

Changed files:

- `opentu/packages/drawnix/src/hooks/useTaskExecutor.ts`
- `opentu/packages/drawnix/src/hooks/__tests__/useTaskExecutor.test.ts`

Contract now enforced:

- A `PROCESSING` task with remote identity that already exceeded the remote timeout budget is not resumed during refresh restore.
- Timeout marking cancels local request state, aborts managed resume state, removes the task from the executing map, and writes `FAILED/TIMEOUT` once.
- A late generic generation success is also prevented from overwriting a timed-out failed task.

## Local verification evidence

Backend targeted regression:

```bash
cd /mnt/f/code/project/new-api
go test -count=1 ./controller -run 'TestCreativeImageTaskFetchPollsLiveTaskWithCASBillingAndPrivateDTO|TestCreativeImageTaskContentProxiesLiveResultPrivately|TestCreativeImageTaskContentFailsClosedWhenAssetRuntimeDisabled'
# ok github.com/QuantumNous/new-api/controller 0.084s

go test -count=1 ./service -run 'TestDispatchPlatformUpdateCreativeImagePollsLiveTaskToSuccess'
# initially failed: missing creative asset quota test-table cleanup path
# fixed test helper to use GORM model deletes instead of hard-coded plural table name
# ok github.com/QuantumNous/new-api/service 1.042s

go test -count=1 ./controller -run 'TestCreativeImageTaskContent|TestCreativeImageTaskFetchPollsLiveTaskWithCASBillingAndPrivateDTO|TestCreativeImageTaskSubmitLive'
go test -count=1 ./service -run 'TestDispatchPlatformUpdateCreativeImagePollsLiveTaskToSuccess|TestCollectPollingTaskBuckets'
go test -count=1 ./model ./relay ./relay/common ./relay/constant
# ok controller/service/model/relay/relay/common/relay/constant
```

Frontend targeted regression:

```bash
cd /mnt/f/code/project/opentu
pnpm vitest run --no-file-parallelism --maxWorkers=1 --minWorkers=1 \
  packages/drawnix/src/hooks/__tests__/useTaskExecutor.test.ts \
  packages/drawnix/src/components/ttd-dialog/creative-image-task-params.test.ts \
  packages/drawnix/src/services/__tests__/media-executor.test.ts \
  packages/drawnix/src/services/__tests__/task-queue-service-image-retry.test.ts
# Test Files 4 passed; Tests 45 passed

pnpm nx run drawnix:typecheck
# Successfully ran target typecheck for project drawnix

pnpm nx run web:typecheck
# Successfully ran target typecheck for project web
```

Whitespace checks:

```bash
git -C /mnt/f/code/project/new-api diff --check
git -C /mnt/f/code/project/opentu diff --check
git -C /mnt/f/code/project/new2fly diff --check
# all exit 0
```

## Remaining risks / explicit non-fixes

- Ambiguous submit late-success recovery without an upstream task id still depends on provider capabilities such as client-id lookup/list/search. It was not blindly implemented because forcing a generic retry could double-submit provider jobs.
- This pass is local verification only. No push, deployment, staging smoke, production smoke, or live provider call was performed in this pass.
- A post-fix dynamic workflow v7 re-audit is still required before treating the runtime lifecycle repair as complete.

## Next gate

Run a dynamic workflow v7 re-audit focused on runtime lifecycle, with mandatory cross-layer state-machine synthesis:

1. Live Creative image terminal success must not persist provider signed URLs.
2. Durable DB result source must be `/creative/api/assets/:id/content`.
3. Asset runtime disabled/materialization failure must fail closed and not record `SUCCESS`.
4. Refresh/expired remote image task must not resume before timeout failure.
5. Slow provider / retry / refresh / Cache Storage / canvas display chain must be examined end-to-end, not as isolated branches.
