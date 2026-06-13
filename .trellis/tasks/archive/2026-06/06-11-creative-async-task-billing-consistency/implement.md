# Implementation Plan — Creative async task billing consistency

## Steps

1. Inspect current task/idempotency/billing models and decide the smallest durable pending/outbox schema.
2. Add red tests for H2/H3/H4/M9 before implementation where feasible.
3. Implement submit persistence/idempotency/billing safe-flush behavior.
4. Implement terminal CAS billing/refund pending/outbox behavior.
5. Replace bulk failure paths for null upstream id/channel lookup failure with per-task CAS + refund.
6. Narrow stored-key fallback for Creative tasks.
7. Run targeted Go tests.
8. Add this child to the parent post-fix dynamic workflow verification scope.

## Suggested Tests

- `controller` tests for submit failure injection around task insert/idempotency/settle.
- `service` tests for terminal CAS + billing failure/retry.
- `model` tests for outbox idempotency if schema is introduced.
- `service/task_polling` tests for channel missing/null upstream id refund exactly once.

## Validation

```bash
cd /mnt/f/code/project/new-api
GOCACHE=/mnt/f/code/project/new2fly/.cache/go-build \
GOTMPDIR=/mnt/f/code/project/new2fly/.cache/go-tmp \
GOMODCACHE=/home/windc0x/go/pkg/mod \
go test ./controller ./service ./model ./relay/common ./relay/constant \
  -run 'Creative|Task|Billing|Idempotency|CAS|Refund|Settle|Channel|Key' -count=1
```
