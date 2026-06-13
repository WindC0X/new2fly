# Implementation Plan — Creative asset quota delete lifecycle hardening

## Steps

1. Decide quota reservation strategy after inspecting current DB model/migration patterns.
2. Add concurrent quota red test.
3. Implement quota reservation/write atomicity.
4. Add delete failure red test.
5. Implement tombstone/outbox or equivalent recoverable delete lifecycle.
6. Add document delete/ref transaction red test.
7. Implement document/ref consistency changes.
8. Reconcile PRD/spec decisions for metadata/tombstone/byte quota/rate limit.
9. Run targeted Go tests and parent dynamic workflow branch.

## Validation

```bash
cd /mnt/f/code/project/new-api
GOCACHE=/mnt/f/code/project/new2fly/.cache/go-build \
GOTMPDIR=/mnt/f/code/project/new2fly/.cache/go-tmp \
GOMODCACHE=/home/windc0x/go/pkg/mod \
go test ./service ./model ./controller \
  -run 'CreativeAsset|Asset|Quota|Delete|Tombstone|Document|Refs|Concurrency' -count=1
```

## Dynamic Workflow Check Branch

Parent post-fix workflow branch `asset-lifecycle-review` must independently inspect H6/M2/M3 and spec reconciliation.
