# Creative Runtime Lifecycle Postfix Recheck v5 — Result And Follow-up

Date: 2026-06-22
Workflow: `.codex-flow/generated/creative-runtime-lifecycle-postfix-recheck-v5-2026-06-22.workflow.ts`
Journal: `.codex-flow/journal/creative-runtime-lifecycle-postfix-recheck-v5-2026-06-22.jsonl`

## Workflow result

`codex-flow` completed all branches and synthesis. Final synthesis verdict: **fail**.

The main session verified the material findings against current source before acting. Findings split into:

## Fixed after v5

### 1. `NEWAPI-SERVER-DURABLE-CONTENT`

Problem: first successful live image content read could fetch provider bytes and return 200 even if Creative asset materialization failed or asset runtime was disabled, leaving `Task.PrivateData.ResultURL` as an expiring provider URL.

Fix in `/mnt/f/code/project/new-api`:

- `CreativeRelayImageTaskContent` now requires ready `CreativeAssetRuntime` for live adapter content.
- Provider-backed first read materializes to `CreativeAssetRuntime.CreateOrGet` before returning success.
- Materialization failure returns controlled asset error instead of success.
- Materialized asset reads use owner-scoped `/creative/api/assets/:assetId/content` via `OpenContent`.
- First `Range` request is served through the materialized asset path for consistent 206/416 semantics.

Tests:

- `TestCreativeImageTaskContentProxiesLiveResultPrivately`
- `TestCreativeImageTaskContentFailsClosedWhenAssetRuntimeDisabled`

### 2. `NEWAPI-CREATIVE-HISTORY-DTO`

Problem: generic `/api/task/self` used `TaskModel2Dto`, which could expose internal `channel_id` and rewrite creative image result URLs to `/v1/videos/:task/content`, which is wrong for creative image tasks.

Fix in `/mnt/f/code/project/new-api`:

- `dto.TaskDto.channel_id` now uses `omitempty`.
- `TaskModel2Dto` suppresses `channel_id` for `TaskPlatformCreativeImage`.
- `taskResultURLForDTO` maps successful creative image tasks to `/creative/relay/v1/images/tasks/:task_id/content`.

Test:

- `TestGetUserTaskRedactsCreativeImageChannelMetadata`

### 3. `OTU-CREATIVE-TTD-PARAMS`

Problem: OpenTU TTD single-image and batch-image dialogs stored runtime schema selections only in legacy `params`; schema-backed Creative execution ignores legacy params and submits `userParams ?? {}`. User-selected aspect ratio/resolution/quality could be lost.

Fix in `/mnt/f/code/project/opentu`:

- Added `buildCreativeImageRuntimeTaskParams` helper.
- TTD single-image and multi-count paths now pass schema-backed selections as `userParams` plus `creativeManaged: true`.
- Batch image generation does the same per row.
- Legacy `params` remains only for non schema-backed non-MJ adapters.

Test:

- `creative-image-task-params.test.ts`

## Open risks after v5

### `NEWAPI-CREATIVE-AMBIGUOUS-LATE-SUCCESS` — still open

Finding: if provider submit transport times out/interrupted before an upstream task id is received, backend marks `ProviderSubmitAmbiguous` and waits until expiry. Without provider-side correlation/idempotency or a list/query-by-client-id API, backend cannot discover a late-accepted upstream task.

Current mitigation:

- Durable task exists before provider submit.
- Ambiguous submit does not retry blindly, avoiding duplicate provider jobs.
- Task expires after configured ambiguous window and refunds.

Required real fix:

- Confirm Duomi/GrsAI support for client-supplied idempotency/correlation or list/query-by-client-id.
- If supported, persist that correlation and add recovery polling.
- If unsupported, keep current fail-safe behavior and document provider limitation.

### Medium risks still open

- Submit-side provider 429/5xx classification: currently terminal fail/refund, not retryable/ambiguous.
- Nano-banana binding schema contract is weaker than GPT image templates.
- Frontend timeout-after-90m late success recovery could first try old `remoteId` before fresh retry.
- Component-level coverage for dialog/panel contentUrl-missing rehydrate remains desirable.

## Validation run after fixes

Backend:

```bash
cd /mnt/f/code/project/new-api
go test -count=1 ./controller -run 'TestCreativeImageTaskContentProxiesLiveResultPrivately|TestCreativeImageTaskContentFailsClosedWhenAssetRuntimeDisabled|TestGetUserTaskRedactsCreativeImageChannelMetadata'
go test -count=1 ./controller -run 'TestCreativeImageTaskContentProxiesLiveResultPrivately|TestCreativeImageTaskContentFailsClosedWhenAssetRuntimeDisabled|TestGetUserTaskRedactsCreativeImageChannelMetadata|TestCreativeImageTaskSubmitLiveTimeoutStaysPendingAndReplaysTask|TestCreativeImageTaskSubmitLiveBindingUsesLockedChannelAndSanitizedDTO|TestCreativeImageTaskFetchFailClosesMissingLiveAffinityAndRefundsOnce|TestCreativeImageTaskFetchPollsLiveTaskWithCASBillingAndPrivateDTO'
go test -count=1 ./service -run 'TestDispatchPlatformUpdateCreativeImagePollsLiveTaskToSuccess|TestCollectPollingTaskBuckets|TestCreativeImageProviderTransportTimeoutIsAmbiguous|TestMarkTasksFailedWithCASAndRefundNullUpstreamOnlyOnce'
go test -count=1 ./model ./relay ./relay/common ./relay/constant
```

All passed.

Frontend:

```bash
cd /mnt/f/code/project/opentu
pnpm vitest run --no-file-parallelism --maxWorkers=1 --minWorkers=1 \
  packages/drawnix/src/components/ttd-dialog/creative-image-task-params.test.ts \
  packages/drawnix/src/services/__tests__/media-executor.test.ts \
  packages/drawnix/src/services/__tests__/task-queue-service-image-retry.test.ts
pnpm nx run drawnix:typecheck
pnpm nx run web:typecheck
```

All passed.

## Dispatch/tool note

The current Codex tool surface does not expose a Trellis Agent/Task dispatch tool for `trellis-implement`/`trellis-check`. The main session therefore performed the implementation/check directly and used `codex-flow` for the dynamic workflow review.
