# Creative Cloud Binary Asset Sync

## Goal

Implement binary asset cloud sync for new-api embedded Opentu `/creative` so generated or locally cached image/audio/video assets survive cross-device document sync without exposing credentials or exhausting the current VPS-A root disk.

## User value

A user can create or generate media in Opentu inside new-api, let document cloud sync save the board, then open `/creative` on another browser/device and still see/play the referenced media instead of broken local `blob:`, Cache Storage, or IndexedDB-only URLs.

## Confirmed facts

- new-api already has `/creative/api/documents` for owner-scoped JSON snapshot sync, but no `/creative/api/assets` binary storage path.
- new-api creative documents currently store only JSON snapshot/metadata/revision, not binary bytes or asset references.
- opentu `creative-document-sync.ts` uploads sanitized board snapshots and handles create/update/delete/409 conflict freeze.
- opentu local media can be represented as `/__aitu_cache__/...`, `/asset-library/...`, `/__aitu_generated__/audio/...`, `blob:...`, and `data:image|audio|video/...` values inside board elements or nested media metadata.
- opentu `unifiedCacheService` can read cached blobs by virtual URL and write content-addressed local cache URLs.
- Existing JSON export/import has embedded-media traversal logic, but creative cloud sync currently does not use binary upload/hydration.
- VPS-A is the current public new-api host. Its capacity runbook documents a 40G root disk, `system_disk_overloaded` risk above 90% root usage, and a recommendation to keep at least 4G free.
- `new-api.db` and automatic DB backups live on VPS-A. Storing media bytes in DB would grow both online DB and backup footprint on the same constrained root disk.

## Confirmed product decisions

- 2026-06-09: Full layered planning initially proposed DB-backed blob MVP.
- 2026-06-09: After reviewing current VPS docs and rerunning the dynamic workflow, production-safe MVP scope is upgraded: **generic S3-compatible object storage is in scope for any current VPS-A/public production rollout**.
- DB-backed blob storage remains only for local development, tests, and explicitly capped tiny VPS-A canary/emergency mode. DB-only must not be presented as current VPS-A broad-production ready.
- Opentu snapshot/API shape remains stable regardless of backend: Opentu only stores `/creative/api/assets/:id/content`; new-api enforces session/owner auth and streams bytes from the configured backend.
- Cloudflare R2 may be the preferred first deployment candidate, but implementation must be generic S3-compatible and provider pricing/limits/TOS must be rechecked before provider freeze/production.
- 2026-06-09: User accepted the recommended planning target: `approvedDeploymentTarget=vps-a-production-s3`. Implementation must treat S3-compatible storage as the required production path for current VPS-A/public rollout.
- 2026-06-09: User accepted the recommended Opentu OpenSpec path. `add-creative-cloud-asset-sync` was created in `/mnt/f/code/project/opentu/openspec/changes/`, strict validation passed, and the user approved it as the Opentu implementation basis.
- 2026-06-09: User approved the current `prd.md`, `design.md`, and `implement.md` planning set as the implementation basis.

## Requirements

### Backend: new-api asset API and storage

- Add owner-scoped creative asset storage under `/creative/api/assets`.
- Mutating asset calls must require the same creative session + nonce protections as creative document mutations.
- Asset content retrieval must require an authenticated browser session and must never be public-by-default.
- Store at least: owner user id, stable asset id, content hash, media type, MIME type, byte size, storage backend, created/updated/accessed timestamps, and reference metadata needed for document linkage.
- new-api may persist an internal opaque `CreativeAsset.ObjectKey` for `StorageBackend=s3-compatible`; it must be non-URL, non-secret, not content-hash-only, and never returned to Opentu, snapshots, asset API JSON, localStorage, or logs.
- Implement `CreativeAssetStorage` with both:
  - `s3-compatible` adapter for production/public VPS-A rollout.
  - `database` adapter for local/test and explicit tiny canary/emergency mode only.
- Production/broad VPS-A rollout requires `CREATIVE_ASSET_STORAGE=s3-compatible` and complete S3 config. Missing or unhealthy S3 config must fail closed; do not silently fall back to DB.
- DB-backed mode requires explicit canary enablement, low global/user caps, disk/inode/backup headroom guards, monitoring, and kill switch.
- Upload must deduplicate by `(user_id, content_hash)` and return the existing owner-scoped asset when content already exists.
- Enforce limits:
  - per asset: 64 MiB hard cap; over limit returns 413.
  - logical per user maximum: 2 GiB total creative asset bytes across metadata/backends; over limit returns a stable `creative_asset_quota_exceeded` quota error.
  - VPS-A DB-backed canary defaults: `CreativeAssetDatabaseGlobalMaxBytes <= 1 GiB`, `CreativeAssetDatabaseUserMaxBytes <= 256 MiB`, plus reserved free-space guard before writes.
  - per user asset count: 10,000 assets.
  - per document asset refs: 1,000 refs.
- Server MIME allowlist:
  - images: `image/png`, `image/jpeg`, `image/webp`, `image/gif`.
  - audio: `audio/mpeg`, `audio/mp3`, `audio/wav`, `audio/ogg`, `audio/webm`, `audio/mp4`, `audio/aac`.
  - video: `video/mp4`, `video/webm`, `video/quicktime`, `video/x-m4v`.
- SVG is disabled for the MVP. Supporting SVG later requires a separate sanitizer/sandbox/CSP/attachment strategy and tests.
- Server validates/sniffs content and treats client MIME/mediaType as hints only; unsupported or mismatched final media type returns 400.
- Provide stable content URLs suitable for cloud snapshots, e.g. `/creative/api/assets/:id/content`.
- new-api must proxy/stream content from the selected backend and support Range/206 for audio/video. It must never redirect to provider URLs or return bucket URLs/signed URLs/ObjectKey.
- Asset metadata/JSON responses must override global caches with `Cache-Control: private, no-store` or equivalent; asset content responses must include private cache headers, `Vary: Cookie` or `no-store`, and `X-Content-Type-Options: nosniff`.
- Access-token/API-token mode must not grant asset access; asset APIs are for authenticated browser sessions.
- Do not accept or persist raw `sourceUrl`. Any retained URL-like metadata must be non-secret sanitized metadata and must reject/strip credential-bearing query params.
- Backend document create/update must sanitize snapshot and metadata as well as asset metadata: direct POST/PUT containing credential-bearing URL/query values must reject or strip them before persistence.
- Track document→asset references when creative documents are created/updated/deleted.
- Deletion/GC policy: referenced assets cannot be hard-deleted; unreferenced assets can be deleted/garbage-collected owner-scoped.
- S3 object write + verification must complete before visible DB metadata commit. DB commit failure, duplicate race, or delete failure must not leave a committed broken referenced asset; orphan cleanup must be retryable and non-secret.

### Frontend: opentu upload, rewrite, hydrate

- Before document snapshot create/update, detect local binary media references in board elements and selected nested metadata fields.
- For local `data:`, `blob:`, and virtual cache URLs, resolve bytes to `Blob`, upload once by content hash, and rewrite snapshot references to stable new-api cloud asset refs/content URLs.
- Remote URL MVP policy: upload only local `data:`, `blob:`, and virtual cache/media URLs by default. Stable credential-free `http(s)` URLs may remain as an explicit product exception after sanitizer approval. Signed/credentialed remote URLs must not be persisted raw; anonymous fetch may upload bytes if it succeeds, otherwise document sync must remain pending/block with a recoverable non-secret error.
- Opentu service worker must pass through `/creative/api/assets/*` for image/audio/video/ordinary fetch and must not place private asset responses into static/media/app-shell caches.
- Outbound asset preparation must be pure: it must deep-copy and rewrite only the payload sent to new-api, never mutate the live board, queued snapshot, or conflict-pending snapshot.
- URL traversal fields must include at least: `url`, `urls[]`, `imageUrl`, `videoUrl`, `audioUrl`, `poster`, `src`, `thumbnail`, `thumbnailUrl`, `thumbnailUrls[]`, `previewImageUrl`, `coverUrl`, `clips[].audioUrl`, `clips[].imageUrl`, `clips[].imageLargeUrl`.
- Preserve existing sanitizer behavior: API keys, base URLs, provider settings, tokens, auth headers, upstream bucket endpoints, object keys, and other credentials must not be synced.
- On remote/cold-start document load, download cloud asset refs/content URLs into local `unifiedCacheService`, rewrite the local board to content-addressed local cache URLs, and save/import the board locally.
- Do not mutate the local board to cloud URLs during ordinary outbound sync unless explicitly needed; cloud URL rewriting is for outbound snapshot payloads.
- Continue to honor 409 document conflict freeze; asset upload success must not cause stale document overwrite.
- Opentu must honor `assetSyncEnabled`/disabled bootstrap state: if disabled and local-only/signed media exists, keep document sync pending/sanitized rather than saving broken cloud docs.

## Acceptance criteria

- [ ] S3-compatible storage adapter is implemented behind `CreativeAssetStorage`, covered by fake/local S3 tests for Put/Get/Head/Range/Delete without real credentials.
- [ ] `database` adapter remains available only for local/test/explicit canary and is protected by low caps, disk/inode/backup reserve guard, and kill switch.
- [ ] Production mode with missing/unhealthy S3 config fails closed and does not silently fall back to DB.
- [ ] Asset API JSON, snapshots, logs, localStorage, and frontend state never expose bucket URLs, signed URLs, ObjectKey, access key id, secret, provider endpoint secrets, or raw source URL.
- [ ] S3 upload success + DB metadata failure, duplicate upload race, object delete failure, and missing object paths leave no committed broken referenced asset; orphan cleanup is retryable.
- [ ] Asset content is streamed through new-api with Range/206 and cancellation support without buffering full objects in long-lived memory.
- [ ] A simulated device A board containing image/audio/video local virtual URLs is saved; simulated device B imports/loads the remote document and sees hydrated local cache URLs backed by downloaded blobs.
- [ ] `data:` and `blob:` media values are uploaded and rewritten in outbound cloud snapshots.
- [ ] `/__aitu_cache__/`, `/asset-library/`, and `/__aitu_generated__/audio/` values are uploaded from `unifiedCacheService` and rewritten in outbound cloud snapshots.
- [ ] Stable credential-free remote `http(s)` URLs are covered by tests and do not leak credentials; signed/credentialed remote URLs either upload successfully via anonymous fetch or block/pending without persisting the original URL.
- [ ] new-api asset upload/download/delete are session-authenticated, owner-scoped, nonce-protected where mutating, and reject cross-user access.
- [ ] new-api deduplicates same-user identical bytes by content hash without double-counting quota.
- [ ] Document create/update/delete refreshes document→asset refs; deletion/GC tests cover referenced vs unreferenced assets.
- [ ] 409 document conflict tests prove asset pre-upload does not overwrite remote document state or leak remote conflict content into persisted status.
- [ ] Secret sanitizer tests still prove API keys/tokens/base URLs/provider settings are not persisted in document snapshots or asset metadata.
- [ ] Server rejects oversized assets, unsupported MIME, missing session, access-token-only auth, missing/invalid nonce on mutations, and cross-user access.
- [ ] Asset metadata/content responses assert private cache behavior, `Vary: Cookie` or `no-store`, `Content-Type`, `Content-Length`, and `X-Content-Type-Options: nosniff`; no wildcard public CORS header is emitted.
- [ ] Signed/credentialed remote URLs are not persisted in document snapshots, document metadata, or asset metadata, including direct document POST/PUT paths.
- [ ] Asset preparation is pure: original board/pending snapshot stays local after outbound rewrite and after 409 conflict.
- [ ] Cold-start import preserves remote document id as local board id, does not emit an immediate outbound update, and handles same/different/missing local revision without silent overwrite.
- [ ] Hydration failures (401/404/network/MIME/size/quota) do not save broken local-only URLs and record only non-sensitive status.
- [ ] Rollback/kill-switch can disable asset prepare/hydrate and backend asset routes without deleting DB rows or bucket objects.
- [ ] Target checks pass or are explicitly recorded as pre-existing debt.

## Out of scope for this child task

- Implementing Video/Suno/MJ creative relay functionality.
- Direct browser-to-bucket upload or direct browser download from bucket URLs.
- Public share links for assets.
- User-visible asset library redesign.
- Provider procurement, final pricing commitment, billing UI, or account setup automation.
- Destructive migration/cleanup of existing DB blobs or bucket objects.
- Global quota/billing product beyond local server-side limits and safe rollout guards.
