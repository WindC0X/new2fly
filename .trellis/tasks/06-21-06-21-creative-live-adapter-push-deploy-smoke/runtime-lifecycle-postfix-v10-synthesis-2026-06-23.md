# Runtime lifecycle postfix v10 synthesis — 2026-06-23

Status: `finding`

## Cross-layer verdict

finding: Backend slow-provider and billing/outbox lifecycle is largely sound, and the normal frontend remoteId resume/cache path has evidence. Cross-layer sign-off should not pass yet because three runtime-lifecycle edges remain: refresh during submit before remoteId can lose the original idempotency path, client poll-budget expiry can terminalize a still-running remote task, and several verified insertion paths drop durable generated-media metadata needed for cache-miss recovery after refresh/history cleanup. Refresh/retry semantics also need UI/action separation between resume and regenerate.

## Must fix

- RLC-001 Creative managed poll timeout must remain resumable.
- RLC-002 Refresh during submit must preserve/replay the original idempotency path.
- RLC-003 All generated image insertion paths must preserve durable rehydrate metadata.

## Should fix

- RLC-004 Retry/resume/regenerate UI semantics should be separated before user-facing smoke sign-off.

## Deduplicated findings

### RLC-001 — Creative managed poll timeout can become nonrecoverable local failure

Severity: HIGH

Sources: F-CROSS-001, OTU-LIFECYCLE-001

Why it matters: A slow provider task with a known remoteId can be marked failed locally. Refresh recovery may not resume it, and retry clears remoteId/idempotency scope, risking orphaned provider work and duplicate billing intent.

Recommended fix: Make Creative managed poll-budget expiry non-terminal, or persist a stable recoverable TIMEOUT state that restore/resume treats as resumable while preserving remoteId. Add timeout -> refresh -> resume -> late completion coverage using the same remoteId.

### RLC-002 — Refresh during managed submit can regenerate with a new idempotency key

Severity: HIGH

Sources: F1

Why it matters: If the tab closes after backend durable submit but before frontend stores remoteId, restore marks the task failed/nonresumable and retry uses a retry-scoped key, which can duplicate the backend/provider task.

Recommended fix: Persist the initial Creative image idempotency key before submit completes. Treat managed SUBMITTING tasks without remoteId as recoverable by replaying the same key once, then attach/resume the original backend task. Add a refresh-during-submit regression test.

### RLC-003 — Generated image insertion paths drop durable rehydrate metadata

Severity: HIGH

Sources: OTU-LIFECYCLE-002, GIML-001, GIML-002, GIML-003, GIML-004

Why it matters: Canvas nodes can be inserted successfully after cache verification but lack contentUrl/remoteTaskId/providerTaskId. After refresh, task-history cleanup, or Cache Storage miss, those images may not be recoverable from backend content.

Recommended fix: Pass generated-media rehydrate metadata through every insertion caller after readiness verification: TaskQueuePanel, MediaViewport quick insert, MediaLibraryGrid viewer insert, and grouped PPT frame insertion. Add tests that evict /__aitu_cache__ or remove task records and verify canvas-node metadata rehydrates content.

### RLC-004 — Retry action does not distinguish resume from regenerate

Severity: MEDIUM

Sources: UI-RETRY-SEMANTICS-001

Why it matters: A generic retry button can silently discard remote identity and start a new provider submission, making user-visible state inconsistent with billing/resume expectations.

Recommended fix: Split recoverable remote failure actions from fresh regeneration. For isRecoverableRemoteTaskFailure, route to a resume/poll action that preserves remoteId, or label/confirm the action as regenerate when it intentionally clears remote identity.

### RLC-005 — GrsAI nano-banana schema validation permits configuration drift

Severity: LOW

Sources: F2

Why it matters: Current built-in template appears correct, but live stored bindings can drift and still pass backend validation; frontend will render the drift because runtime schema is authoritative.

Recommended fix: Add a required schema contract for grsai_nano_banana or explicitly document/admin-gate allowed live-schema subsets. Add tests for expected ratio/options including extended nano variants if supported.

## Passed gates

- Slow provider backend lifecycle: durable task is created before provider submit; selected key/endpoint/idempotency/billing context are stored; ambiguous/no-upstream states are held; temporary poll/materialization errors remain non-terminal; terminal settlement uses CAS plus billing outbox.
- Cross-layer normal path: UI creates local task, submit uses stable idempotency after normal creation, backend stores provider task id, frontend stores remoteId, IndexedDB restores processing remote tasks, and useTaskExecutor resumes processing remote image tasks.
- Content/cache normal path: backend exposes broker content URLs rather than raw provider URLs; frontend writes generated blobs to Cache API plus IndexedDB; SW passes private Creative API through and serves /__aitu_cache__ virtual media; cache-miss recovery can rehydrate from safe content URLs when metadata exists.
- Canvas/history/viewport normal path: auto-insert/dialog/history paths have cache/readiness verification and some metadata propagation; stale retryAttempt guards prevent old completions overwriting newer attempts; viewport persistence flushes on pagehide/visibilitychange/beforeunload.

## Contradictions / scope notes

- The refresh/reopen branch reported pass, but generated-media branches found cache-rehydrate metadata gaps in dock/media preview/media library/grouped PPT insertion paths. Treat the pass as covering the normal restore/cache machinery, not every insertion caller.
- The same Creative managed poll-budget issue was reported as MEDIUM in F-CROSS-001 and HIGH in OTU-LIFECYCLE-001. Synthesis keeps HIGH because it can orphan a known remote task and cause duplicate generation/billing.

## Needs main verification

- Run targeted frontend tests after fixes for poll-budget timeout recovery, refresh-during-submit idempotency replay, retry/resume UI semantics, and metadata persistence across TaskQueuePanel/MediaViewport/MediaLibraryGrid/grouped PPT insertion.
- Run targeted backend tests for Creative idempotency replay, slow-provider reconciliation, CAS billing/outbox settlement, and fail-closed malformed terminal result behavior.
- Perform browser-level refresh/reopen smoke after fixes: submit -> refresh before/after remoteId -> resume, cache eviction of /__aitu_cache__, thumbnail/cache miss, canvas reload, task dock/history restore, retry vs regenerate, and viewport persistence. No live provider calls are needed; use mocked provider/backend where possible.