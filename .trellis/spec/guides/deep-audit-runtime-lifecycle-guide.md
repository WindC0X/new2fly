# Deep Audit Runtime Lifecycle Guide

> Purpose: prevent deep audits from missing dynamic, cross-layer lifecycle bugs that only appear after slow async work, retry, refresh, or browser cache recovery.

Use this guide for any deep audit involving async provider tasks, browser-local persistence, service workers, Cache Storage, task queues, generated media, canvas/workspace state, or embedded cloud sync.

## Mandatory Audit Gates

### Gate 1: Slow Provider Timing

Do not rely only on fast mocks or static review. Audit at least these timing cases:

- Provider succeeds quickly.
- Provider remains `in_progress` longer than the frontend's normal polling window, then succeeds.
- Provider returns temporary 429/5xx during polling, then recovers.
- Provider succeeds but content/cache write initially fails.
- Provider terminal failure returns a user-safe reason.

Expected audit output:

- Where timeout is configured.
- Whether frontend and backend use the same timeout/TTL contract.
- Whether local timeout marks the task terminal or leaves it resumable.
- Whether late provider success can be recovered.

### Gate 2: Cross-Layer State Machine Synthesis

Parallel audit branches are not enough. The final synthesis must reconstruct the full state machine:

```
UI action
  -> frontend task creation
  -> local task storage
  -> backend submit/idempotency
  -> provider accepted/upstream task id
  -> backend task row/billing/outbox
  -> frontend polling/resume
  -> content download/cache
  -> canvas/task-history/dock display
  -> refresh/retry/reopen behavior
```

For each state transition, answer:

- What is the durable source of truth?
- What field carries the identity needed for resume?
- What happens if the browser refreshes here?
- What happens if the backend returns 429/5xx here?
- Is the user-facing state accurate, or does it say failed while provider is still running?

### Gate 3: Refresh / Retry / Cache Storage End-to-End

Generated media audits must verify these as one chain, not isolated components:

- IndexedDB task restore.
- `remoteId` / upstream task id persistence.
- Idempotency key semantics.
- Distinction between "resume existing task" and "start a new generation".
- `/__aitu_cache__/...` image/video URL lifetime.
- Service Worker readiness and Cache Storage miss behavior.
- Thumbnail cache generation and fallback.
- Canvas node image load verification before marking post-processing success.
- Task history and dock thumbnail behavior after page refresh.
- Workspace viewport persistence after pan/zoom + refresh.
- E2E runner cache behavior: if an earlier skipped run can be cached, disable cache (for example `NX_SKIP_NX_CACHE=true`) or prove the browser tests actually executed.

## Required Report Shape

For each material finding include:

1. Symptom / user-visible effect.
2. Reproduction path or mock scenario.
3. Evidence: files/functions/line ranges.
4. Root cause.
5. Impact and severity.
6. Fix direction.
7. Verification case.

## Wrong vs Correct

### Wrong

- Split audit into backend/frontend/cache branches and only paste branch summaries.
- Use only a fast mock provider.
- Treat browser local cache URLs as durable media URLs.
- Treat retry as a single operation without distinguishing resume vs regenerate.
- Mark task/canvas success before generated media is load-verified.

### Correct

- Run or design slow-provider scenarios.
- Synthesize branch results into one state machine.
- Verify refresh/retry/cache/canvas/viewport as an end-to-end lifecycle.
- Require durable remote identity for every resumable async task.
- Require safe failure reason propagation without leaking secrets.
