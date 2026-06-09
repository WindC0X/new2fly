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
  - `CreativeAsset(UserId, AssetId, ContentHash, MediaType, MimeType, SizeBytes, StorageBackend, ObjectKey, ObjectETag, ObjectVersion, Data, CreatedTime, UpdatedTime, LastAccessedTime)`.
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
- Use project JSON wrappers (`common.Marshal` / `common.Unmarshal`) in business code.

### 4. Validation & Error Matrix

- Missing browser session -> 401/403 non-leaky error.
- Access-token/API-token-only auth -> reject; creative asset API is browser-session only.
- Missing/invalid nonce on mutating requests -> reject.
- Cross-user asset access -> 404 or equivalent non-leaky owner-scoped error.
- Oversized asset -> 413.
- Unsupported or mismatched MIME, including SVG in MVP -> 400.
- Missing/unhealthy production S3 config -> fail closed and do not route bytes to DB.
- Referenced asset delete -> 409.
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
  - credential-bearing URLs rejected/stripped before persistence.

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
