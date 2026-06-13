# Creative Asset Sync Backend Contract

## Scenario: new-api creative binary asset authority

### 1. Scope / Trigger

- Trigger: implementing `/creative/api/assets` for embedded Opentu binary sync.
- This is infra/cross-layer work: it adds API routes, DB models, storage adapters, env config, secret handling, and frontend-facing URL contracts.

### 2. Signatures

- API:
  - `POST /creative/api/assets` — browser-session upload, nonce required.
  - `GET /creative/api/assets/:assetId` — owner-scoped metadata.
  - `GET /creative/api/assets/:assetId/content` — owner-scoped streaming content, supports `Range`.
  - `DELETE /creative/api/assets/:assetId` — nonce required; only unreferenced owner assets can be deleted.
- DB:
  - `CreativeAsset(UserId, AssetId, ContentHash, MediaType, MimeType, SizeBytes, StorageBackend, ObjectKey, ObjectETag, ObjectVersion, Data, Status, DeletingTime, DeleteError, CreatedTime, UpdatedTime, LastAccessedTime)`.
  - `CreativeAssetQuota(UserId, AssetCount, TotalSizeBytes, DatabaseSizeBytes, UpdatedTime)`.
  - `CreativeDocumentAssetRef(UserId, DocumentId, AssetId, CreatedTime)`.
- Storage boundary:
  - Store object bytes by internal object key.
  - Head object metadata.
  - Open ranged stream.
  - Delete object best-effort/retryable.

### 3. Contracts

- Public asset refs are always same-origin relative URLs:
  - `/creative/api/assets/:assetId/content`
- Public API JSON MUST NOT expose:
  - `ObjectKey`, bucket URL, signed URL, S3 endpoint, access key, secret key, raw `sourceUrl`, or storage provider internals.
- Production target:
  - `CREATIVE_ASSET_STORAGE=s3-compatible`
  - complete S3-compatible endpoint/region/bucket/prefix/credential config
  - missing/unhealthy S3 config fails closed; never silently fallback to DB.
- DB storage is local/test/canary only and requires explicit canary enablement, low caps, reserve checks, and kill switch.
- Asset quota is DB-authoritative, not an advisory pre-read:
  - uploads must create metadata through the quota transaction/reservation path.
  - per-user count/byte caps and DB-backend user/global byte caps are rechecked in the same transaction that inserts metadata.
  - same-user content-hash dedupe must return the existing active asset without double-counting quota.
  - delete finalization must decrement the same quota rows.
- Use project JSON wrappers (`common.Marshal` / `common.Unmarshal`) in business code.
- Delete lifecycle is two-phase:
  - mark unreferenced active assets `pending_delete` while retaining object key/backend metadata.
  - active asset lookup and document-ref validation must ignore `pending_delete` assets.
  - only after storage delete succeeds may metadata be finalized/deleted.
  - if storage delete fails, metadata stays retryable by asset id with a sanitized `DeleteError`.
- S3 upload cleanup is durable for normal failure paths:
  - if object upload succeeds but metadata/quota/dedupe finalization fails, the service must attempt immediate object cleanup.
  - if immediate S3 cleanup fails, enqueue a `CreativeAssetLifecycleOutbox` work item containing only internal object identifiers and retry status.
  - background polling/sweeper must retry `upload_cleanup` outboxes and `pending_delete` assets, marking success/failure without exposing object keys in public DTOs.
- Document snapshot create/update/delete and `CreativeDocumentAssetRef` refresh/delete must be performed by model-layer `WithAssetRefs` transaction helpers; controllers must not mutate the document and refs in separate calls.
- MVP product reconciliation:
  - user-supplied `name` / `prompt` / `model` asset metadata is not persisted as first-class columns for this release.
  - multipart upload accepts only the file, `mediaType`, and safe `clientAssetId`; source URLs and storage/provider fields are rejected.
  - independent asset byte quota is intentionally enforced via `CREATIVE_ASSET_USER_MAX_BYTES`; there is no separate per-user upload rate-limit beyond nonce/session/API gateway controls in this task.

### 4. Validation & Error Matrix

- Missing browser session -> 401/403 non-leaky error.
- Access-token/API-token-only auth -> reject; creative asset API is browser-session only.
- Missing/invalid nonce on mutating requests -> reject.
- Cross-user asset access -> 404 or equivalent non-leaky owner-scoped error.
- Oversized asset -> 413.
- Unsupported or mismatched MIME, including SVG in MVP -> 400.
- Missing/unhealthy production S3 config -> fail closed and do not route bytes to DB.
- Referenced asset delete -> 409.
- Delete storage failure -> non-success response, metadata remains in `pending_delete` retry state; a repeated DELETE may retry storage deletion.
- Invalid cloud asset ref in document snapshot/metadata -> reject/strip before persistence.

### 5. Good/Base/Bad Cases

- Good: upload `image/png`, return only `{ id, url, contentHash, mimeType, mediaType, sizeBytes }`, then stream via content URL with private headers.
- Base: repeated upload by the same user deduplicates by content hash without double-counting quota.
- Bad: returning `ObjectKey`, redirecting to bucket URL, accepting signed `sourceUrl`, or letting production use DB blobs when S3 config is missing.

### 6. Tests Required

- Model migration tests for `CreativeAsset` / `CreativeDocumentAssetRef` across supported DBs where feasible.
- Storage matrix tests:
  - production S3 works with complete fake/local config.
  - production S3 missing/unhealthy config fails closed.
  - DB backend works only for local/test/explicit canary.
- Controller/router tests:
  - session + nonce requirements.
  - owner scope.
  - Range 206/416.
  - private cache headers and `nosniff`.
  - no storage provider fields in JSON/log/status.
- Document mutation tests:
  - asset refs refresh after successful create/update/delete.
  - create/update/delete rollback or remain retryable if ref refresh/delete fails.
  - ref refresh revalidates active assets inside the document transaction.
  - credential-bearing URLs rejected/stripped before persistence.
- Lifecycle tests:
  - concurrent uploads under low per-user count/byte caps allow only quota-permitted metadata inserts.
  - S3/object delete failure leaves retryable metadata or tombstone state.
  - S3 upload orphan cleanup outbox deletes objects that could not be immediately cleaned after metadata/dedupe failure.
  - pending-delete sweeper retries storage deletion and finalizes metadata/quota only after delete succeeds.
  - quota rows are migrated, lazily reconciled, incremented on create, and decremented on final delete.

### 7. Wrong vs Correct

#### Wrong

```text
Opentu snapshot -> https://bucket.example/object?X-Amz-Signature=...
new-api production S3 missing -> silently store bytes in SQLite DB
```

#### Correct

```text
Opentu snapshot -> /creative/api/assets/asset_opaque/content
new-api -> session/owner checks -> private storage adapter stream
production S3 missing -> asset sync disabled/fail closed
```
