# Current Evidence Pack for Fresh True-Final Goal-Attainment Audit (2026-06-13)

This evidence pack is built from the current worktree only. It is not copied from prior reports. It summarizes file-path evidence and current verification logs for the final dynamic workflow to judge whether the project meets its development goals.

## Scope and reconstructed goals

- Orchestration workspace: `/mnt/f/code/project/new2fly`.
- Backend: `/mnt/f/code/project/new-api` — README describes a lawful/private LLM gateway with authentication, multi-provider/model routing, usage/cost accounting, analytics, AI asset management, and deployment support.
- Frontend: `/mnt/f/code/project/opentu` — README describes a canvas-centric AI application platform with multi-model generation, task/material flows, tools, assets, knowledge/content workflows, and deployment support.
- Current cross-repo focus in active Trellis specs is Creative Embed/session-broker/asset sync/async video+Suno+MJ relay/security/billing consistency.
- Severity calibration for final verdict: HIGH = concrete current code/deploy release blocker (privacy leak, auth bypass, double charge/lost result, build/test failure, production unsafe default that directly exposes users). Governance/spec coverage gaps are MEDIUM unless directly blocking runtime.

## Backend current evidence

### Async task submit/idempotency/billing

- `new-api/controller/relay.go:539-595`: retry loop wraps only upstream `relay.RelayTaskSubmit`; local persistence/settle/flush occur after the loop, so accepted upstream tasks are not resubmitted by local post-work retries.
- `new-api/controller/relay.go:520-530`: deferred refund uses `shouldRefundTaskSubmitBilling(taskErr, result, taskPersisted)`.
- `new-api/controller/relay.go:603-647`: on success, task row is inserted, selected upstream id/billing context persisted, idempotency completion attempted, `SettleSubmittedTaskBillingDurably` called before `LogTaskConsumption` and buffered success flush.
- `new-api/controller/relay.go:632-636` and `681-685`: if submit-settle outbox enqueue fails, controller sets `settle_task_billing_failed` and does not flush success.
- `new-api/controller/relay.go:650-679`: local idempotency is deleted only when task is not persisted; refund happens when result is nil or accepted result has no persisted local task.
- `new-api/service/task_billing.go:168-180`: submit settle first enqueues `TaskBillingOutbox`, then processes; process failure is logged as durable retry, not returned as enqueue failure.
- `new-api/service/task_billing.go:183-204`, `293-323`, `401-410`: pending/failed/stale-processing outboxes are retried with claim and failed status update.
- `new-api/model/task.go:527-621`: `TaskBillingOutbox` has unique owner/task/operation key and `UpdateWithStatusAndBillingOutbox` creates terminal outbox inside CAS transaction.
- Tests: `new-api/controller/relay_task_test.go:14-57` covers idempotency delete/refund/fail-closed settle helper. Verification log `verification/new-api-v5-high-targeted-tests-2026-06-13-rerun-after-settle-failclosed.log` shows these tests passed.

### Creative asset lifecycle/quota/privacy

- `new-api/model/creative_asset.go:82-97`: `CreativeAssetLifecycleOutbox` persists only internal object identifiers and retry status; fields are `json:"-"`.
- `new-api/model/creative_asset.go:223-277`: `CreateCreativeAssetWithQuota` dedupes by user/content hash and inserts metadata with quota reservation in a transaction.
- `new-api/model/creative_asset.go:279-342`: delete first marks active asset `pending_delete`; delete failure keeps metadata/object key and sanitized delete_error.
- `new-api/model/creative_asset.go:344-392`: finalize deletes metadata and decrements quota only after storage delete succeeds and refs remain absent.
- `new-api/model/creative_asset.go:395-512`: lifecycle outbox enqueue/list/claim/done/failed plus pending_delete listing.
- `new-api/service/creative_asset.go:317-345`: after S3 upload, metadata/quota/dedupe failure or duplicate calls cleanup.
- `new-api/service/creative_asset.go:382-486`: pending delete, lifecycle outbox processing, pending_delete retry, and cleanupStoredObjectOrEnqueue are implemented.
- `new-api/service/task_polling.go:100-109`: polling loop runs task billing outboxes and creative asset lifecycle/pending delete processors.
- Tests: `new-api/service/creative_asset_test.go:295-377` covers delete failure retry and orphan S3 upload cleanup. Verification logs show targeted service tests passed.

### Backend creative security boundary

- `new-api/middleware/creative.go` defines session CSRF/nonce material, session header bridge, same-origin checks, and nonce checks for mutating session-broker requests.
- `new-api/controller/creative.go` bootstrap exposes creative capabilities/session auth and assetSync status.
- `new-api/relay/relay_task.go` owner-scoped fetch builders verify `originTask.Platform` for Suno and video/MJ paths; DTOs avoid leaking provider keys.
- `new-api/service/http_client.go` strips sensitive redirect headers and validates redirects with fetch SSRF settings.
- `new-api/middleware/cache.go` and related tests were previously modified so creative endpoints are not cached as public app-shell/static responses.

## Frontend current evidence

### Session broker and credential stripping

- `opentu/packages/drawnix/src/services/creative-session-broker.ts:168-192`: bootstrap auth must be `session-broker` and must include csrfToken and nonce.
- `creative-session-broker.ts:238-252`: assetSync enabled/disabled state is derived from backend bootstrap.
- `creative-session-broker.ts:400-405`: initialization fetches bootstrap and applies auth/asset config.
- `provider-routing/provider-transport.ts:89`, `216`, `358-363`, `422`, `459-461`: session-broker requires canonical `/creative/relay/v1`, relative paths, CSRF+nonce for unsafe requests, and same-origin credentials.
- `provider-routing/provider-transport.ts:328-333` and tests: session-broker strips `api_key`/`key` query/auth material.
- `provider-transport.session-broker.test.ts` covers same-origin credentials, stripping path/query/header auth, rejecting absolute paths/baseUrls, canonical base, and missing nonce fail-fast.

### Video/audio/MJ failure sanitization and idempotency

- `creative-error-sanitizer.ts:1-33`: failure messages redact authorization/api key/secret/token/signature/provider/channel/baseurl/callback/webhook/notifyHook/URLs/S3 markers.
- `creative-error-sanitizer.test.ts:9-20`: verifies callback/webhook/notify hook redaction.
- `video-api-service.ts:148-203`: session-broker video submit requires stable idempotency key and emits `Idempotency-Key`.
- `video-api-service.ts:626-647`, `705-773`: failed terminal video statuses are sanitized via `sanitizeCreativeFailureObjectMessage`.
- `audio-api-service.ts:160-195`: session-broker Suno submit requires stable idempotency key.
- `audio-api-service.ts:768`: terminal audio failed raw payload is sanitized; failed submit logging uses sanitized raw (`audio-api-service.ts` around `1121`).
- `provider-transport.session-broker.test.ts:241-321`: strips server-selected model and MJ selected-key/notifyHook material from session-broker paths.
- Targeted Vitest suite passed after current fixes: `verification/opentu-targeted-vitest-2026-06-13-post-v5-high-fixes.log` (10 files, 137 tests passed).

### Asset discovery/hydration/sync and SW routing

- `creative-document-assets.ts:585-667`: outbound snapshot upload rewrites required URL fields, rejects unsafe URL values, and uploads local/virtual assets when asset sync is enabled.
- `creative-document-assets.ts:675-743`: inbound hydration rewrites cloud asset content URLs into local cached URLs and rejects unsafe URL values.
- `creative-document-sync.ts:200-211`, `468-478`, `556-632`, `1097-1225`: document payloads are sanitized, unsafe asset persistence refs are asserted/stripped, upload and cold-start hydration use the asset adapter.
- `apps/web/src/sw/creative-asset-pass-through.ts:1`: creative asset API path prefix is identified for pass-through.
- `apps/web/src/sw/creative-asset-pass-through.spec.ts`: verifies `/creative/api/assets` is pass-through and branch ordering is before virtual/static/debug cache handlers.
- `apps/web/src/sw/app-shell-routing.ts:13` and spec: HTML and release metadata are origin-first/preload rather than stale cached app shell.

## Current verification evidence

Backend:

- `verification/new-api-v5-high-targeted-tests-2026-06-13-rerun-after-settle-failclosed.log`: targeted controller/service tests passed.
- `verification/new-api-controller-service-model-2026-06-13-post-v5-high-fixes-rerun.log`: `go test -count=1 ./controller ./service ./model` passed.
- `verification/new-api-quality-gate-2026-06-13-post-v5-high-fixes.log`: `go test -count=1 ./router ./middleware ./controller ./model ./service ./relay/...` passed.
- `verification/new-api-diff-check-2026-06-13-post-v5-high-fixes.log`: `git diff --check` passed.

Frontend:

- `verification/opentu-drawnix-typecheck-2026-06-13-post-v5-high-fixes.log`: `pnpm nx run drawnix:typecheck` passed.
- `verification/opentu-targeted-vitest-2026-06-13-post-v5-high-fixes.log`: targeted creative Vitest suite passed, 10 files / 137 tests.
- `verification/opentu-diff-check-2026-06-13-post-v5-high-fixes.log`: `git diff --check` passed.
- Known frontend test stderr remains: WebCrypto decrypt failure in Node test environment, sensitive data plain-text fallback warning, and IndexedDB missing warning. Tests still pass; this remains a browser-runtime smoke/coverage gap rather than a proven code failure.

Dynamic workflow evidence:

- Focused HIGH recheck workflow: `.codex-flow/generated/newapi-opentu-v5-high-focused-recheck-2026-06-13-v2.workflow.ts`.
- Focused HIGH recheck journal: `.codex-flow/journal/newapi-opentu-v5-high-focused-recheck-2026-06-13-v2.jsonl`.
- Focused synthesis: `blockerCount=0`; Branch A async submit and Branch B S3 lifecycle closed; remaining risk was theoretical crash window after S3 upload before compensation enqueue.
- Fresh true-final v6/v7 attempts exist but had timeout/null branches and are insufficient alone. v8 is the evidence-pack terminal pass.

## Current known risks/gaps for final severity calibration

- No provider/payment/CDN/production endpoint was called; no secrets were read.
- No real browser E2E smoke was run. Node tests expose WebCrypto/IndexedDB warnings, so browser runtime storage/crypto behavior remains a MEDIUM verification gap.
- Creative production availability depends on runtime env flags and S3-compatible configuration (`CREATIVE_VIDEO_RELAY_ENABLED`, `CREATIVE_ASSET_SYNC_ENABLED`, S3 envs). Default disabled state is safe but not proof of production readiness.
- Cross-repo packaging still depends on CI/build pipeline providing `new-api/web/creative/dist` from opentu; no production pipeline was executed in this session.
- Current repositories contain many uncommitted changes by design; release freeze/commit review remains necessary.
- S3 orphan cleanup has a theoretical crash window after upload success but before cleanup/outbox enqueue on metadata failure; normal failure paths now have durable retry.
- Trellis generic backend/frontend guideline files still include placeholders; this is a governance/spec coverage risk, not by itself a runtime HIGH blocker for Creative Embed.
