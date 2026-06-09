# Implementation Plan — Creative Cloud Binary Asset Sync

## Pre-start review checklist

- [x] PRD/design/implementation plan accepted by user on 2026-06-09.
- [x] 2026-06-09 VPS capacity re-plan completed with dynamic workflow. Result archive: `.trellis/tasks/06-09-creative-cloud-assets-sync/research/creative-cloud-assets-sync-vps-replan.json`.
- [x] Revised scope: S3-compatible storage is required for any VPS-A/public production rollout; DB-backed storage is local/test/explicit tiny canary fallback only.
- [x] Record `approvedDeploymentTarget` before start: `approvedDeploymentTarget=vps-a-production-s3`. DB-only must not start for this broad VPS-A/public production target.
- [x] Opentu OpenSpec proposal created and strict-validated: `/mnt/f/code/project/opentu/openspec/changes/add-creative-cloud-asset-sync/`; `openspec validate add-creative-cloud-asset-sync --strict` passed.
- [x] OpenSpec approval gate before Opentu implementation: user approved `add-creative-cloud-asset-sync` as the Opentu implementation basis on 2026-06-09.
- [x] Provider precheck completed for planning: Cloudflare R2 Standard is the first production configuration target, while implementation remains generic S3-compatible. Final bucket/IAM/secret injection and pricing/TOS recheck are still required before production enablement.
- [x] Task status moved to `in_progress` via Trellis before editing sibling repos. Start was run in degraded mode from shell, but `task.json.status` is now `in_progress`. Implementation should be run via a dynamic workflow with disjoint writable branches.

## Context and specs to load before editing

1. `.trellis/spec/guides/cross-layer-thinking-guide.md`
2. `.trellis/spec/guides/code-reuse-thinking-guide.md`
3. `.trellis/spec/backend/index.md`
4. `.trellis/spec/frontend/index.md`
5. `.trellis/tasks/06-09-creative-cloud-assets-sync/research/codebase-evidence.md`
6. `.trellis/tasks/06-09-creative-cloud-assets-sync/research/vps-capacity-evidence.md`
7. `.trellis/tasks/06-09-creative-cloud-assets-sync/research/object-storage-options.md`
8. `.trellis/tasks/06-09-creative-cloud-assets-sync/research/creative-cloud-assets-sync-vps-replan.json`
9. `.trellis/tasks/06-09-creative-cloud-assets-sync/research/full-layered-planning-review.json`
10. `.trellis/tasks/06-09-creative-cloud-assets-sync/research/openspec-prestart-gate.md`
11. `/mnt/f/code/project/opentu/openspec/changes/add-creative-cloud-asset-sync/proposal.md`
12. `/mnt/f/code/project/opentu/openspec/changes/add-creative-cloud-asset-sync/design.md`
13. `/mnt/f/code/project/opentu/openspec/changes/add-creative-cloud-asset-sync/specs/creative-cloud-asset-sync/spec.md`
14. Parent sprint result: `.trellis/tasks/06-09-newapi-opentu-creative-remediation/research/sprint1-implementation-result.json`
15. `/mnt/f/code/project/new-api/AGENTS.md` if present.
16. `/mnt/f/code/project/opentu/AGENTS.md`
17. `/mnt/f/code/project/opentu/openspec/AGENTS.md`
18. `/mnt/f/code/project/opentu/openspec/project.md`

## Phase A — Backend TDD: asset model, S3-compatible storage, DB fallback, and API

1. Add failing model/storage tests in `new-api/model` and/or `new-api/service` for:
   - `CreativeAsset` / `CreativeDocumentAssetRef` migrations with `StorageBackend`, `ObjectKey`, optional `ObjectETag/ObjectVersion`, and DB `Data` only for `database` backend.
   - storage mode matrix: `production+s3-compatible` works with complete config; production missing/unhealthy S3 config fails closed; production does not auto-fallback to DB.
   - database adapter works only for local/test or explicit canary with caps, disk/inode/backup reserve, and kill switch.
   - same-user content hash dedupe.
   - concurrent same-hash upload returns one asset and does not double-count quota.
   - concurrent distinct uploads cannot oversubscribe user byte/count quota.
   - fake/local S3 `Put/Get/Head/Range/Delete` behavior.
   - S3 object key opacity: no email, username, raw user id, content-hash-only key, URL, or provider-specific URL.
   - S3 write success + DB commit failure cleanup; duplicate race orphan cleanup; delete ordering; object delete retry/GC; missing object fail-closed.
   - no bucket URL, signed URL, ObjectKey, access key, secret, endpoint secret, or raw source URL appears in API JSON, logs, status, or persisted document/asset metadata.
   - cross-DB migration/blob type coverage for SQLite/MySQL/PostgreSQL migration definitions; verify MySQL 64 MiB-capable blob type, PostgreSQL bytea, SQLite blob, and no blob index.
2. Add `CreativeAsset` and `CreativeDocumentAssetRef` to `model/creative.go` and AutoMigrate paths.
3. Add a streaming `CreativeAssetStorage` service boundary and implement:
   - `S3CompatibleCreativeAssetStorage` for production path.
   - `DatabaseCreativeAssetStorage` for local/test/explicit canary fallback.
   - fake/local S3 client tests; no real credentials/network in normal tests.
   - config validation and secret-scrubbed error/log handling.
4. Add service/model helpers:
   - `CreateOrGetCreativeAsset(userId, bytes/stream, mime, mediaType, metadata)`
   - `GetCreativeAsset(userId, assetId)`
   - `OpenCreativeAssetContent(userId, assetId, range)`
   - `DeleteCreativeAssetIfUnreferenced(userId, assetId)`
   - `RefreshCreativeDocumentAssetRefs(userId, documentId, snapshotJSON, metadataJSON)`
5. Add failing controller/router tests in `new-api/controller` and/or `router` for:
   - `POST /creative/api/assets` requires browser session + nonce.
   - access-token/API-token-only auth is rejected on all asset endpoints.
   - upload returns stable `/creative/api/assets/:id/content` and no backend-specific fields.
   - `GET content` streams bytes/MIME for owner and supports Range/206; invalid range returns 416 without cross-user leaks.
   - metadata/content cache headers include private/no-store or `Vary: Cookie`, `X-Content-Type-Options: nosniff`, and no wildcard public CORS.
   - oversized body, missing `Content-Length`, huge ordinary fields, too many multipart parts, and malformed multipart are rejected without full buffering.
   - unsupported MIME, client/server MIME mismatch, and SVG are rejected.
   - cloud asset URL parser/ref extraction accepts relative and absolute same-origin `/creative/api/assets/:id/content`; rejects query, hash, cross-origin, protocol-relative, encoded slash/path traversal, malformed id, and oversized id.
   - cross-user access returns 404 or non-leaky asset error.
   - delete referenced returns 409; delete unreferenced removes visible metadata before best-effort backend delete.
   - direct creative document POST/PUT sanitizer rejects or strips signed/credentialed URLs before persistence.
   - asset upload metadata rejects raw `sourceUrl`.
6. Implement routes in `router/web-router.go` under `/creative/api`.
7. Implement controller handlers in `controller/creative.go` or focused creative asset controller files.
8. Wire document create/update/delete to refresh/remove asset refs only after successful mutations.
9. Run focused Go checks.

## Phase B — Frontend TDD: asset preparation and rewrite

1. Add tests in a new `creative-document-assets.test.ts` or extend `creative-document-sync.test.ts` for:
   - `assetSyncEnabled` bootstrap gate: enabled prepares/hydrates; disabled keeps local-only/signed media pending and sanitized instead of saving broken docs.
   - virtual cache URL -> `getCachedBlob` -> upload -> outbound URL rewrite.
   - `data:` URL -> Blob -> upload -> rewrite.
   - `blob:` URL -> fetch/blob -> upload -> rewrite.
   - all URL fields discovered: `url`, `urls[]`, `imageUrl`, `videoUrl`, `audioUrl`, `poster`, `src`, `thumbnail`, `thumbnailUrl`, `thumbnailUrls[]`, `previewImageUrl`, `coverUrl`, `clips[].audioUrl`, `clips[].imageUrl`, `clips[].imageLargeUrl`.
   - same original URL uploads once and rewrites every occurrence.
   - credential-free remote `https://...` remains stable and no credentials are synced.
   - signed/credentialed remote URL first tries existing cache/local blob resolution; only then may anonymously fetch/upload; otherwise block/pending without saving the raw URL.
   - relative and absolute same-origin cloud asset refs are recognized as existing cloud refs, normalized as needed, and not re-uploaded.
   - final outbound guard rejects raw signed URLs in snapshot body, metadata, unknown fields, and traversal misses.
   - partial upload/prepare failure leaves document mutation pending, rejects flush safely, and does not call document create/put.
   - status, localStorage, and console warnings/log arguments never contain raw `data:`, `blob:`, signed query params, bucket URLs, ObjectKey, or provider URLs.
2. Implement shared traversal helper using existing `isVirtualMediaUrl` and embedded-media patterns.
3. Implement `CreativeAssetCloudAdapter` for new-api `/creative/api/assets`:
   - multipart upload with creative session headers.
   - metadata unwrap compatible with new-api response wrapper.
   - content download helper for hydration.
   - calls use `credentials: 'same-origin'` and never send Authorization, API keys, upstream base URLs, provider settings, bucket endpoints, ObjectKey, or S3 credentials.
4. Integrate asset preparation into `CreativeDocumentCloudSyncService.flushSnapshot` before `adapter.create/put`.
5. Keep existing sanitizer plus signed/credentialed URL scanning as the final outbound guard.
6. Add RED service-worker/static-cache tests or assertions proving `/creative/api/assets/*` is pass-through for image/audio/video/ordinary fetch and is not written to app-shell/static/media caches.

## Phase C — Frontend TDD: hydration / cold-start remote load

1. Add tests proving a simulated fresh repository imports remote document snapshots with `/creative/api/assets/:id/content` refs and rewrites them to local content-addressed `unifiedCacheService` URLs.
2. Add workspace repository abstraction with:
   - `hasBoard(boardId)`
   - `getStoredRevision(boardId)` or equivalent
   - `upsertBoardFromCloud(board, revision, { suppressOutboundSync: true })`
3. Implement `hydrateCreativeDocumentAssets(document)`:
   - detect cloud content URLs.
   - download blobs through new-api with same-origin credentials.
   - validate MIME/size.
   - cache via `unifiedCacheService.cacheLocalMediaByContent`.
   - rewrite to local virtual URLs.
   - cover same URL field matrix as outbound traversal.
   - reject invalid cloud refs and degrade without saving a broken board.
4. Add `syncRemoteDocumentsForColdStart()` / equivalent service method:
   - list documents.
   - import missing local boards for MVP.
   - if local board exists with unknown/stale revision, do not overwrite silently; record conflict/freeze.
   - convert new-api seconds timestamps to Opentu milliseconds.
   - apply default/fallback folder id when remote metadata omits it.
   - avoid immediate outbound sync on import.
5. Start cold-start sync from `initializeCreativeDocumentCloudSync` after workspace initialization when embedded.

## Phase D — Integration and regression verification

Run at minimum:

```bash
cd /mnt/f/code/project/new-api
GOCACHE=/tmp/go-build-cache go test ./service ./controller ./model ./router -run 'Test.*Creative.*Asset|Test.*Creative.*Storage|Test.*S3' -count=1
GOCACHE=/tmp/go-build-cache go test ./controller ./middleware ./model ./relay/common ./relay/constant ./router ./service -count=1
```

```bash
cd /mnt/f/code/project/opentu/packages/drawnix
../../node_modules/.bin/vitest run \
  src/services/creative-document-sync.test.ts \
  src/services/creative-document-assets.test.ts \
  src/hooks/use-creative-document-sync-status.test.tsx \
  --config vitest.config.ts --pool=threads --maxWorkers=1 --minWorkers=1
```

Add/run a focused Service Worker pass-through test or static assertion for `apps/web/src/sw/index.ts` before cache handlers.

After any opentu TS/TSX implementation change:

```bash
cd /mnt/f/code/project/opentu
NX_DAEMON=false VITE_BASE_URL=/creative/ pnpm build:web
```

If build output changes, sync new-api creative dist and run:

```bash
cd /mnt/f/code/project/new-api
GOCACHE=/tmp/go-build-cache go test . -run TestCreativeProductionRootDistMatchesRouterDistAndContract -count=1
```

Always run:

```bash
git -C /mnt/f/code/project/new-api diff --check
git -C /mnt/f/code/project/opentu diff --check
git -C /mnt/f/code/project/new2fly diff --check
```

Known existing debt to record, not hide:

```bash
cd /mnt/f/code/project/opentu/packages/drawnix
TMPDIR=/dev/shm pnpm exec tsc -p tsconfig.spec.json --noEmit --pretty false
```

This currently fails from pre-existing/mixed spec type debt; do not claim full typecheck closure unless fixed.

Optional live scratch-bucket smoke may run only when explicit environment variables are provided outside repo artifacts. It must create/get/range/delete a disposable object and must not print credentials or return public URLs.

## Risk and rollback points

- If S3 config is unhealthy, production asset sync stays disabled; do not silently route production bytes into DB.
- DB canary can be enabled only explicitly with caps, disk/inode/backup reserve, and kill switch.
- Backend schema changes are additive; default rollback disables routes/feature flags and preserves asset/ref tables, DB bytes, and bucket objects.
- If VPS-A disk guard trips, safe rollback is to disable DB-backed asset upload/hydration, not delete live DB data.
- Dropping tables, deleting blobs, clearing DB `Data`, deleting bucket objects, or migrating/cleanup is destructive and requires separate confirmation.
- Asset pre-upload before document PUT can create orphans; object cleanup/GC must be retryable and non-secret.
- Cold-start import must not overwrite local boards without revision agreement.
- Do not touch unrelated existing WIP such as opentu `.ace-tool/` or `audio-test.pptx`.
- Do not commit real provider credentials, bucket URLs, signed URLs, ObjectKey values from production, or secrets to repo/Trellis/logs/fixtures.

## Dynamic workflow plan after `task.py start`

After planning is accepted and `task.py start` succeeds, run a second dynamic workflow for implementation. Every sub-agent prompt must begin with:

```text
Active task: .trellis/tasks/06-09-creative-cloud-assets-sync
```

Recommended shape:

1. Phase 0 serial preflight: confirm current task, record `approvedDeploymentTarget`, capture new-api/opentu WIP status, OpenSpec gate status, provider-neutral config contract, no real credentials in artifacts, and fresh `tsconfig.spec` baseline.
2. Phase 1 parallel writable branches with disjoint cwd:
   - Backend branch in `/mnt/f/code/project/new-api`: asset DB/model/controller/router/ref/GC/security tests, storage interface, S3-compatible adapter, DB fallback, config fail-closed matrix, Range/streaming, multipart hardening.
   - Frontend branch in `/mnt/f/code/project/opentu`: asset adapter, outbound rewrite, sanitizer/traversal, hydration/cold-start, bootstrap gate, service worker pass-through tests.
3. Phase 2 serial integration: align API contract, ensure no bucket/signed URLs leak, run frontend build, sync dist if build output changes, run production dist regression.
4. Phase 3 parallel read-only checks: backend storage/security headers/secret scrubbing, frontend hydration/SW/sanitizer, migration/rollback checklist, cross-repo diff ownership.
5. Phase 4 main-session synthesis and Trellis check.
