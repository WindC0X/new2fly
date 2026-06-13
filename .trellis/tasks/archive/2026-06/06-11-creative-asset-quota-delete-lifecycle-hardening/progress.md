# Progress — Creative asset quota/delete lifecycle hardening

## Status

Implemented and locally verified on 2026-06-12.

## Backend changes in `../new-api`

- `model/creative_asset.go`, `model/main.go`
  - Added `CreativeAssetQuota` reservation rows and migrations in normal/fast migrate paths.
  - Added asset lifecycle status fields: `active` / `pending_delete`, `DeletingTime`, and sanitized `DeleteError`.
  - Added `CreateCreativeAssetWithQuota` so same-user content-hash dedupe, quota checks, metadata insert, and quota increments happen in one DB transaction.
  - Added pending-delete/finalize helpers so metadata is retained on object delete failure and quota is decremented only after finalization.
  - `GetCreativeAsset`, content-hash lookup, and document-ref validation only expose active assets; pending-delete assets remain retryable but cannot be newly referenced.
  - `RefreshCreativeDocumentAssetRefs` now revalidates active assets inside the ref transaction.
- `service/creative_asset.go`
  - `CreateOrGet` keeps existing validation/storage health checks but treats them as advisory; the authoritative quota gate is the DB transaction.
  - S3 objects created during failed quota/DB insert or duplicate races are cleaned up best-effort.
  - `DeleteIfUnreferenced` marks pending-delete before storage deletion, preserves metadata on storage failure, and finalizes metadata only after storage deletion succeeds.
- `model/creative.go`, `controller/creative.go`
  - Added and wired `CreateCreativeDocumentWithAssetRefs`, `UpdateCreativeDocumentSnapshotWithAssetRefs`, and `DeleteCreativeDocumentWithAssetRefs`.
  - Controllers no longer perform document mutation and asset-ref refresh/delete as separate calls.
- `.trellis/spec/backend/creative-asset-sync.md`
  - Reconciled durable contract for byte quota, quota rows, pending-delete retry lifecycle, document/ref transactions, and MVP metadata/rate-limit decisions.

## Regression tests added/updated

- `service/creative_asset_test.go`
  - Concurrent uploads with `UserMaxAssets=1` synchronize after the advisory precheck and prove only one metadata insert succeeds.
  - S3 delete failure keeps DB metadata/object key retryable; a later DELETE succeeds and removes metadata.
- `model/creative_test.go`
  - Document update rolls back when asset-ref refresh fails.
  - Document delete rolls back when ref cleanup fails.
- Test setup/migrations updated for `CreativeAssetQuota` across model/service/controller tests.

## Dynamic workflow verification

- Ran `.codex-flow/generated/creative-asset-lifecycle-check.workflow.ts` from `/mnt/f/code/project/new-api`.
  - Four read-only branches were started: quota, delete lifecycle, document refs, contract/regression surface.
  - All branches timed out in the local `codex-flow`/`codex-sdk` backend before producing business findings.
  - Journal: `/mnt/f/code/project/new-api/.codex-flow/journal/creative-asset-lifecycle-check.jsonl`.
- Ran smaller `.codex-flow/generated/creative-asset-lifecycle-fast-check.workflow.ts`.
  - It also timed out before producing findings (`input_tokens=0` in journal), so no conclusion was accepted from the workflow.
  - Journal: `/mnt/f/code/project/new-api/.codex-flow/journal/creative-asset-lifecycle-fast-check.jsonl`.
- Because the workflow backend was unstable, final judgment for this child is based on TDD red/green tests, direct code inspection, and deterministic Go suites below.

## Validation commands

Initial red tests failed on the old implementation as expected:

```bash
GOCACHE=/mnt/f/code/project/new2fly/.cache/go-build \
GOTMPDIR=/mnt/f/code/project/new2fly/.cache/go-tmp \
GOMODCACHE=/home/windc0x/go/pkg/mod \
go test ./service ./model \
  -run 'CreativeAssetConcurrentUploadsCannotBypassUserAssetQuota|CreativeAssetDeleteFailureKeepsMetadataRetryable|CreativeDocumentUpdateWithAssetRefsRollsBackOnRefFailure|CreativeDocumentDeleteWithAssetRefsRollsBackOnRefCleanupFailure' -count=1
```

Observed failures: concurrent quota allowed 3 successes; delete failure lost metadata; new atomic document/ref functions were undefined.

Post-fix targeted tests passed:

```bash
GOCACHE=/mnt/f/code/project/new2fly/.cache/go-build \
GOTMPDIR=/mnt/f/code/project/new2fly/.cache/go-tmp \
GOMODCACHE=/home/windc0x/go/pkg/mod \
go test ./service ./model ./controller \
  -run 'CreativeAsset|Asset|Quota|Delete|Tombstone|Document|Refs|Concurrency' -count=1
```

Passed.

Broader backend creative packages passed:

```bash
GOCACHE=/mnt/f/code/project/new2fly/.cache/go-build \
GOTMPDIR=/mnt/f/code/project/new2fly/.cache/go-tmp \
GOMODCACHE=/home/windc0x/go/pkg/mod \
go test ./router ./middleware ./controller ./service ./model ./relay ./relay/common ./relay/constant -count=1
```

Passed.

Parent backend target also passed:

```bash
GOCACHE=/mnt/f/code/project/new2fly/.cache/go-build \
GOTMPDIR=/mnt/f/code/project/new2fly/.cache/go-tmp \
GOMODCACHE=/home/windc0x/go/pkg/mod \
go test ./middleware ./router ./model ./service ./relay/constant ./relay/common ./relay/channel/task/mj ./controller \
  -run 'Creative|Suno|MJ|Midjourney|Task|Asset|Billing|Idempotency|Relay|Router|Nonce|Cache|Proxy|Forwarded' -count=1
```

Passed.

## Notes / residual

- Multi-node correctness relies on DB transaction/row-lock behavior of the configured database. SQLite test coverage serializes via the quota row and exercises the original advisory-precheck race.
- If storage deletion succeeds but DB finalization fails, metadata remains retryable and a repeated DELETE should finalize after idempotent storage delete.
