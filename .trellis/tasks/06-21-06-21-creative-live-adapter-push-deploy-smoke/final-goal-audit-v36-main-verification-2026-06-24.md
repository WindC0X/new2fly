# v36 Final Goal Audit — Main-session Verification (2026-06-24)

Scope: verify dynamic workflow v35/v36 findings against current local source before further repair. This is a product-goal/new-issue audit verification, not merely a "fix completed" checklist.

Rules applied:

- Dynamic workflow findings are not accepted without source evidence.
- Timeout/null branches are not counted as pass.
- No live provider calls were made.
- Evidence below is source/static only unless explicitly marked otherwise.

## Verdict

`needs-fix`.

I accept 11 current gates/findings and reject 1 stale/overbroad finding from v35. Release/staging readiness remains blocked until provenance, release-gate, and current-candidate staging smoke are closed.

## Accepted findings

### REL-PROV-001 — HIGH — Cross-repo release provenance is not closed

Evidence:

- Current `new2fly`, `opentu`, and `new-api` checkouts are dirty/untracked.
- Task plan still leaves v31 provenance/staging gate open in `implement.md`.
- `new-api` embedded dist has many deleted/modified files, so the current artifact candidate is not reproducible as a clean release candidate.

Impact: staging/production could package stale or uncommitted artifacts; readiness claims would not be reproducible.

Fix direction: freeze a candidate, rebuild OpenTU embedded dist from a recorded ref, sync both `new-api` embedded dist targets, record hashes/refs, and make dirty/untracked status explicit.

Verification: clean or explicitly exempted statuses; matching dist hashes; `version.json.gitCommit` matches recorded OpenTU ref; remote refs verified.

### REL-GATE-001 — HIGH — Release gate can still false-positive publish readiness

Evidence:

- Existing release checks mostly prove build/sync/test behavior, not a publish-ready clean provenance state.
- Dirty checkout can still pass portions of release gate that do not require clean source/artifact state.

Impact: release gate may allow stale/broken embedded artifacts into a deploy path.

Fix direction: add/require a publish-ready gate that checks dirty/untracked source, dist deletion/addition state, version ref, build-sync-check, new-api tests, and embedded smoke.

Verification: current dirty checkout should fail the publish-ready gate; a clean rebuilt/synced candidate should pass.

### REL-STAGE-001 — HIGH — Current candidate lacks staging smoke/provenance evidence

Evidence:

- No current-candidate staging smoke/provenance record was found after the v31/v35/v36 changes.
- Earlier local gates do not substitute for current staging evidence.

Impact: cannot claim staging readiness or production readiness for the embedded Creative product.

Fix direction: run no-provider staging smoke: `/creative/` shell, assets, bootstrap/models, relay/admin no-provider paths, browser catalog/parameter panel, and mock lifecycle.

Verification: produce a redacted smoke table for the current candidate.

### IMG-DURABLE-SUBMIT-RECOVERY — HIGH — Live image ambiguous submit recovery gap

Evidence:

- `new-api/controller/creative_image_tasks.go:355-364`: durable task row is inserted before synchronous provider submit.
- `new-api/controller/creative_image_tasks.go:747-759`: task with no upstream id and `ProviderSubmitInFlight`/`ProviderSubmitAmbiguous` only waits until expiry, then fails closed.
- No durable submit outbox/worker or provider-side idempotent lookup path is present for late provider acceptance without saved upstream id.

Impact: if provider accepts after browser/server interruption but upstream id is not stored, a late success can be unrecoverable and user-visible as timeout/failure.

Fix direction: introduce durable submit outbox/recovery, or a provider-side idempotency query/manual recovery path; ambiguous no-upstream tasks must enter a clear auditable state rather than silently timing out.

Verification: simulate row-created/no-upstream-id/late-accepted scenario and prove recovery or explicit audited failure/refund.

### creative-bootstrap-login-recovery — HIGH — Login recovery does not reliably reinitialize broker/catalog

Evidence:

- `opentu/packages/drawnix/src/drawnix.tsx:362-366`: `initializeCreativeManagedSessionBroker()` runs only once on mount.
- `opentu/packages/drawnix/src/services/creative-session-broker.ts:696-713`: failed initialization can be retried only if the function is called again.
- Existing test covers manual second call, not automatic logged-out→logged-in recovery.

Impact: opening `/creative` while logged out can leave the page with empty/unavailable model catalog after login unless the user hard refreshes.

Fix direction: retry broker/bootstrap/catalog initialization on session/auth material change or 401 recovery.

Verification: E2E or component/integration test: logged-out `/creative` → login without hard refresh → catalog/profile/model selectors recover.

### SUNO-RAW-DATA-CONTENT-URL — HIGH — Suno fetch returns raw provider data/content URLs

Evidence:

- `new-api/service/task_polling.go:684-685`: provider `responseItem.Data` is persisted to `task.Data`.
- `new-api/relay/relay_task.go:394-408`: `SunoTaskModel2Dto` returns `Data: task.Data` to clients.

Impact: provider media URLs/raw payload can reach the browser and bypass the controlled content proxy/cache lifecycle.

Fix direction: sanitize/rewrite Suno task data before returning DTOs; expose only controlled content endpoints or safe DTO fields.

Verification: unit/integration test asserting Suno fetch responses do not contain signed/raw provider URLs or raw provider payload; playback/cache uses controlled endpoint.

### MF-005-VIDEO-DISPLAY-REHYDRATE-GAP — HIGH — Video display paths do not consume rehydrate metadata

Evidence:

- Metadata now reaches projection layer, but display paths still use raw URLs.
- `opentu/packages/drawnix/src/components/shared/VideoPosterPreview.tsx` props do not include generated-video rehydrate metadata and render with raw `src`.
- `opentu/packages/drawnix/src/components/shared/media-preview/MediaViewport.tsx:745-748` renders `<video src={mediaUrl}>` without rehydrate recovery.
- Consumers include media library, task history, selected/dock previews, and viewers.

Impact: after browser Cache Storage cleanup or reload, completed generated videos can show blank/broken preview/playback even when durable content URL exists.

Fix direction: route generated-video metadata through video preview/viewer components and perform cache-miss recovery on load error.

Verification: clear `/__aitu_cache__/video/...` and assert each display entry recovers from `contentUrl`.

### MF-005-VIDEO-CANVAS-METADATA-LOSS — HIGH — Some video canvas insertion paths still drop durable metadata

Evidence:

- `opentu/packages/drawnix/src/hooks/useAutoInsertToCanvas.ts:816-823`: metadata is set for image/audio but video receives `undefined`.
- `opentu/packages/drawnix/src/hooks/useAutoInsertToCanvas.ts:931-941`: frame insertion passes `{ metadata: imageMetadata }` only.
- `opentu/packages/drawnix/src/services/canvas-operations/canvas-insertion.ts:168-173`: `insertVideoToCanvas` has no metadata parameter.
- `opentu/packages/drawnix/src/services/canvas-operations/canvas-insertion.ts:392-397`: video item metadata is ignored.

Impact: video nodes may lack durable content metadata, so canvas reload/recovery cannot rehydrate from a cloud/content endpoint if local cache and task history are missing.

Fix direction: add a unified generated-video metadata pipeline for auto insert, frame insert, multi-video insertion, quick insert, and low-level video insertion.

Verification: insertion tests assert video nodes persist allowlisted rehydrate metadata and can recover after cache/task-history loss.

### OPENTU-VIDEO-POLL-ABORT-LOST — MEDIUM — Video submit-to-poll loses AbortSignal

Evidence:

- `opentu/packages/drawnix/src/services/model-adapters/default-adapters.ts` passes `request.signal` to `generateVideoWithPolling`.
- `opentu/packages/drawnix/src/services/video-api-service.ts:668-685` uses the signal through submit/onSubmitted/progress.
- `opentu/packages/drawnix/src/services/video-api-service.ts:697-703` calls `pollUntilComplete` without passing `signal`.
- `pollUntilComplete` supports `signal` at `video-api-service.ts:769-773` and `sleep(interval, signal)`.

Impact: after user cancellation/unmount, polling can continue and later state may drift.

Fix direction: pass `signal` into `pollUntilComplete` and test submit-success-then-abort stops polling.

Verification: unit test proving no status/content requests after abort at the submit-to-poll boundary.

### OT-AUDIO-CACHE-WARNING-HIDDEN — MEDIUM — Audio cache-miss warning is hidden

Evidence:

- `opentu/packages/drawnix/src/components/media-library/AssetItem.tsx:75-81`: `useUnifiedCache` and warning only apply to IMAGE/VIDEO.
- `opentu/packages/drawnix/src/components/task-queue/TaskItem.tsx:368-373`: audio tasks explicitly skip cache warning.

Impact: audio cache/content failures are not communicated, so users see broken playback/insert behavior without actionable status.

Fix direction: allow audio asset/task entries to consume and show cache warnings, with safe disabled/limited actions where appropriate.

Verification: component tests for audio asset/task with `cacheWarning`.

### NA-CREATIVE-SYNC-GATE-001 — MEDIUM — new-api sync image route managed-binding gate is semantically inconsistent

Evidence:

- `new-api/controller/creative_image_tasks.go:147-162`: sync route rejects any binding returned by raw `GetCreativeModelBindingByID` with `Modality == image`.
- `new-api/service/creative_model_capability.go:998-1013`: `GetCreativeModelBindingByID` does not enforce `Enabled`, canary group, channel readiness, or executable adapter semantics.
- `new-api/service/creative_model_capability.go:899-935`: task route resolver does enforce enabled, image modality, adapter/channel readiness, and canary group.

Impact: sync route can reject unavailable/disabled config differently from catalog/task route, and managed preview/binding semantics can drift.

Fix direction: make sync route gate use the same availability semantics as resolver/catalog for determining executable managed image bindings.

Verification: route tests for disabled/canary/unready bindings and enabled managed image binding rejection from sync route.

## Rejected / stale / duplicate findings

### IMG-PROVIDER-SUCCESS-MATERIALIZATION — rejected as stale/overbroad

Reason:

- Current code keeps materialization failure retryable through status fetch/reconcile rather than immediately terminalizing success loss.
- Existing test `TestCreativeImageTaskFetchKeepsLiveSuccessMaterializeFailureRetryable` covers this behavior.

Caveat:

- A narrower scenario may still need testing: provider success URL available only once and materialization fails before the durable result source is saved. That is not proven by the v35 finding as written and should be tested separately if prioritized.

### Duplicate/stale branch outputs

- v33 `MUST-002` is merged into `OPENTU-VIDEO-POLL-ABORT-LOST`.
- v33 `MUST-001` is merged into `IMG-DURABLE-SUBMIT-RECOVERY`.
- v34 `opentu-ui-video-rehydrate-gap` and `MF-005-VIDEO-MEDIA-LIBRARY-PREVIEW-NO-REHYDRATE` are merged into `MF-005-VIDEO-DISPLAY-REHYDRATE-GAP`.
- Older v32/v33 null/timeout branches are not counted as pass; where v34 covered the same scope, they are treated as superseded, not successful.

## Repair order

1. OpenTU contained repairs:
   - `OPENTU-VIDEO-POLL-ABORT-LOST`
   - `MF-005-VIDEO-CANVAS-METADATA-LOSS`
   - `MF-005-VIDEO-DISPLAY-REHYDRATE-GAP`
   - `OT-AUDIO-CACHE-WARNING-HIDDEN`
   - `creative-bootstrap-login-recovery`
2. new-api repairs:
   - `NA-CREATIVE-SYNC-GATE-001`
   - `SUNO-RAW-DATA-CONTENT-URL`
   - `IMG-DURABLE-SUBMIT-RECOVERY` (largest; likely requires separate design/TDD slice)
3. Release gates:
   - rebuild/sync embedded artifact, source/artifact gate, staging smoke/provenance.
4. Final dynamic workflow re-audit:
   - must include slow-provider timing, cross-layer state-machine synthesis, refresh/retry/Cache Storage E2E.
   - no timeout/null branch may count as pass.
