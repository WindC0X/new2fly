# Design — Creative async task billing consistency

## Affected Areas

- `../new-api/controller/relay.go`
- `../new-api/relay/relay_task.go`
- `../new-api/service/task_polling.go`
- `../new-api/service/task_billing.go`
- `../new-api/model/task.go`
- idempotency and optional billing/outbox model files/tests.

## Design Direction

Prefer a minimal durable outbox/pending-state design over trying to make upstream submit and local DB fully atomic, because upstream acceptance cannot be rolled back.

Expected shape:

- Submit path:
  - pre-consume as today;
  - send upstream;
  - persist local task and idempotency completion in a DB transaction where possible;
  - if billing/log cannot complete synchronously, write a durable pending billing/log record before flushing success;
  - failure after upstream acceptance must create a reconciliation marker rather than deleting all local knowledge.

- Terminal polling path:
  - update task terminal state with `UpdateWithStatus`;
  - CAS winner writes billing/refund outbox item or performs mutation and marks done;
  - retry worker or deterministic recovery method handles pending items idempotently.

- Channel failure/null upstream id:
  - iterate tasks and CAS from current non-terminal status to failure;
  - CAS winner enqueues/performs refund;
  - no `TaskBulkUpdateByID` in billable terminal transitions.

- Selected-key affinity:
  - new Creative tasks require `PrivateData.Key` for status/content provider calls;
  - fallback to channel current key only for explicitly recognized legacy tasks with tests and logs.

## Tradeoffs

- A full transaction over task/idempotency/billing log may require schema changes; outbox reduces coupling but requires retry semantics.
- Immediate synchronous settlement is simpler but cannot survive crashes after terminal CAS.
- Legacy fallback may preserve old tasks but weakens the Creative contract; default should be fail-closed for new tasks.
