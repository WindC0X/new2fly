# Runtime lifecycle v8/v8b workflow arbitration — 2026-06-22

## Scope

This is the main-session arbitration of the post-v7 dynamic workflow re-audit results. It is not a proof of completion. The goal is to identify current project runtime-lifecycle defects and decide what to fix next.

## Workflow status

- v8 broad workflow ran, but 4/6 branches timed out. Treat it as incomplete broad coverage, not a final audit.
- v8b targeted continuation completed branch work; the original synthesis node failed, then synthesis-only workflow produced a candidate list.
- Main session verified candidates against current disk state using `codegraph`, `fast-context`, and targeted source inspection. Findings below are not accepted solely because a workflow branch reported them.

## Confirmed material findings

| ID | Severity | Finding | Main-session evidence | Fix direction |
|---|---:|---|---|---|
| C1 | HIGH | Ambiguous provider submit can leave a task unrecoverable until timeout when provider accepted but no upstream id is stored. | `new-api/controller/creative_image_tasks.go` ambiguous submit path returns accepted without upstream id; reconcile/poll skip until timeout. Existing controller test documents current behavior. | Do not blindly re-submit. Requires provider idempotency/query capability or explicit recovery-needed/cancel semantics. Track as unresolved design gap unless provider-safe recovery is added. |
| C2 | MEDIUM/HIGH | Channel lookup transient errors are treated as terminal task failure/refund. | `service/task_polling.go` marks bucket failed when `CacheGetChannel` returns err/nil; fetch reconcile also fail-closes on `GetChannelById` err/nil. | Distinguish confirmed missing/deleted/disabled channels from transient DB/cache errors; defer transient without terminal state. |
| C3 | HIGH | Prompt History failed previews bypass frontend error sanitizer. | `prompt-history-service.ts` uses `task.error.message` directly for failed result preview; `PromptHistoryTool.tsx` renders preview text. | Apply shared sanitizer before persisting/rendering failure preview. |
| C4 | MEDIUM | Frontend error sanitizer is over-broad and hides actionable safe provider rejection text. | `creative-error-sanitizer.ts` broad regex matches ordinary words such as `provider`, `upstream`, `channel`. | Preserve safe plain-text provider errors; only suppress URLs, credentials, tokens, callback/webhook/notify hook material, and storage/provider internals. |
| C5 | LOW/MEDIUM | `TaskItem` memo comparator ignores `error.details.originalError`, so sanitized tooltip can remain stale. | `TaskItem.tsx` renders `originalError` but comparator only checks `task.error.message`. | Include rendered error detail fields in comparator or compare stable rendered error key. |
| C6 | HIGH | Media-library manual insert of generated images can bypass cache rehydrate. | Toolbar insert paths call `insertImageFromUrl(asset.url)` directly; queue insert path correctly calls `ensureGeneratedImageCacheUrlReady`. | Share/reuse generated-media ready helper for media-library inserts before canvas insertion. |
| C7 | MEDIUM | Selected dock reselect of generated image loses cache rehydrate metadata. | Selection watcher passes only `url/maskImage/name/type/width/height`; preview component supports richer `contentUrl/remoteTaskId/providerTaskId/mimeType`. | Propagate metadata from selected canvas/image element when available. |
| C8 | MEDIUM | GrsAI nano-banana extended ratios are not model-series scoped. | Provider contract distinguishes common ratios vs nano-banana-2 extended ratios; current template exposes extended ratios to all nano variants. | Validate/advertise extended ratios only for `nano-banana-2*` provider models. |
| C9 | MEDIUM | Editing a Creative image task can let stale top-level `size/resolution/quality` override schema-backed `userParams`. | `ai-image-generation.tsx` merge order applies top-level fields after normalized userParams. | Centralize edit-param merge and let schema/userParams win over legacy top-level fields. |
| C10 | HIGH | OpenTU has conflicting execution ownership for newly created tasks. | `TaskQueueService.createTask()` emits `taskCreated(PENDING)` and then auto-executes; `useTaskExecutor` subscribes to `taskCreated(PENDING)` and also calls generation API. Both reference the same singleton. | Make live-created tasks service-owned and prevent hook duplicate execution; keep restored/resumed tasks resumable. |
| C11 | MEDIUM | Managed resume writeback gate is weaker than ordinary execution gate. | Managed branch checks only remote id while ordinary branch checks retry attempt/start/remote id. | Apply attempt-aware guard to managed progress/completion/error writebacks. |

## Rejected / coverage-only candidates

| Candidate | Decision | Reason |
|---|---|---|
| RestoreTasks emits duplicate events causing duplicate execution by itself | Coverage-only | Hook enqueue has pending/executing de-dupe; still needs E2E coverage but not a proven defect alone. |
| Failed retry reuses old request without new attempt | Rejected | Retry increments attempt and clears remote/result; tests exist for idempotency key refresh. |
| Completed post-processing regenerate path in production | Rejected | No production `allowCompleted` path found; only tests. |
| Non-cache contentUrl fetch allows arbitrary remote URL | Rejected | `normalizeSafeCreativeContentUrl` is same-origin/path-whitelist gated. |
| targetWidth/targetHeight overrides decoded dimensions | Rejected | Decoded dimensions are preferred; existing tests cover fallback behavior. |
| Only one generated content endpoint accepted | Rejected | Both accepted prefixes are present and covered by tests. |

## Implementation posture

- Apply TDD: add failing tests first, verify red, then implement minimal fixes.
- Do not blind-resubmit ambiguous provider requests; recovery needs provider capability evidence.
- After fixes and local verification, run another dynamic workflow re-audit focused on full state machine, slow provider, refresh/retry/cache/canvas/history/dock lifecycle. If broad workflow times out, continue/split instead of marking it failed.
