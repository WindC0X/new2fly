# Design — Creative Cloud Binary Asset Sync

## Summary

Use new-api as the owner-scoped asset authority for embedded `/creative`. Opentu uploads local binary media before saving a cloud document, rewrites only the outbound snapshot to stable new-api asset URLs, and hydrates those URLs back into local `unifiedCacheService` on cold-start import.

After VPS capacity review, production-safe MVP includes a generic S3-compatible storage adapter. DB-backed blob storage remains available only for local development, tests, and explicit tiny VPS-A canary/emergency mode. Opentu never talks to the bucket and never stores bucket URLs; it only sees `/creative/api/assets/:id/content`.

## Boundaries

### new-api responsibilities

- Authenticate and authorize all `/creative/api/assets` calls by current browser session user.
- Require creative nonce for mutating upload/delete calls.
- Persist asset metadata, ownership, content hash, storage backend, and document references.
- Store bytes through `CreativeAssetStorage`: `s3-compatible` for production, `database` for local/test/canary.
- Deduplicate same-user bytes by SHA-256 hash.
- Serve asset content by streaming/proxying from the selected backend with private cache headers and Range support.
- Maintain document→asset refs from creative document snapshots/metadata.
- Block hard deletion of referenced assets and allow delete/GC only for unreferenced owner-scoped assets.

### opentu responsibilities

- Discover local binary media references in outbound board snapshots.
- Resolve local references to blobs using existing cache/URL helpers.
- Upload blobs through new-api `/creative/api/assets` with session auth headers.
- Rewrite outbound snapshot URLs from local-only refs to stable new-api cloud content URLs.
- Preserve and continue running existing secret sanitizer.
- On remote/cold-start load, fetch server asset refs, store blobs in local `unifiedCacheService`, and rewrite the local board to local content-addressed URLs.

## Backend contract

### Tables / model concepts

`CreativeAsset`

- `UserId int` — owner scope.
- `AssetId string` — stable opaque random id, e.g. `asset_<base62-random>`. It must not be derived from raw content hash because ids appear in browser-visible URLs.
- `ContentHash string` — SHA-256 hex.
- `MediaType string` — `image | audio | video`.
- `MimeType string` — allowlisted MIME.
- `SizeBytes int64`.
- `StorageBackend string` — `s3-compatible` or `database`.
- `ObjectKey string` — required for `s3-compatible`, empty for `database`. It is internal-only, non-URL, non-secret, and never returned to Opentu.
- `ObjectETag string` — optional backend ETag/version hint for audit/cleanup; internal-only.
- `ObjectVersion string` — optional backend version hint for object stores that support versioning; internal-only.
- `Data []byte` — DB blob payload, populated only when `StorageBackend=database`.
- `CreatedTime int64`, `UpdatedTime int64`, `LastAccessedTime int64`.
- Unique constraints: `(user_id, asset_id)`, `(user_id, content_hash)`.

`CreativeDocumentAssetRef`

- `UserId int`
- `DocumentId string`
- `AssetId string`
- `CreatedTime int64`
- Primary/unique key: `(user_id, document_id, asset_id)`.

### VPS-A deployment capacity constraints

- VPS-A is the current `new-api` production host and has documented root-disk sensitivity: root usage above 90% can trigger `system_disk_overloaded`, and the runbook recommends at least 4G free on its 40G root disk.
- Live `new-api.db` and automatic DB backups are on the same constrained host. Storing asset bytes in DB increases both live DB and backup footprint.
- Broad/current VPS-A production rollout requires `s3-compatible` storage. DB upload is canary-only, default disabled, and requires caps, kill switch, fresh capacity evidence, disk/inode guard, and backup-aware reserve.
- Before accepting a DB-backed upload, check aggregate creative DB asset bytes and injected disk-headroom stats. Refuse writes if caps would be exceeded, root usage approaches the documented threshold, inodes are risky, or free space would drop below configured reserve.

### Storage adapter contract

Define a streaming `CreativeAssetStorage` boundary used by upload/download/delete handlers. Handlers must not directly depend on a DB blob or S3 SDK.

Required behavior:

- `Store(ctx, objectKey, reader, size, mime, hash) -> etag/version` or equivalent.
- `OpenRange(ctx, objectKey, range) -> stream + metadata/contentRange/status` or equivalent.
- `Head(ctx, objectKey) -> size/etag/version/exists`.
- `Delete(ctx, objectKey) -> result`.

Adapters:

- `S3CompatibleCreativeAssetStorage`: production path, private bucket/prefix, no public ACL/policy, supports R2/B2/Tigris or other S3-compatible providers through config.
- `DatabaseCreativeAssetStorage`: local/test/canary fallback, stores bytes in `CreativeAsset.Data`, guarded by low caps and disk headroom.
- Tests use fake/local S3 client; normal tests must not need real credentials/network.

Object key rules:

- Opaque and owner-scoped, e.g. `creative-assets/u/<opaque-owner-prefix>/<asset-id>/<random>`.
- Do not use email, username, raw user id, content-hash-only key, public URL, signed URL, or provider-specific URL.

### Configuration matrix

- `CREATIVE_ASSET_SYNC_ENABLED=true|false`.
- `CREATIVE_ASSET_ROLLOUT_MODE=local|canary|production`.
- `CREATIVE_ASSET_STORAGE=database|s3-compatible`.
- `CREATIVE_ASSET_DATABASE_CANARY_ENABLED=true|false`.
- `CREATIVE_ASSET_DB_GLOBAL_MAX_BYTES`.
- `CREATIVE_ASSET_DB_USER_MAX_BYTES`.
- `CREATIVE_ASSET_DB_RESERVED_FREE_BYTES`.
- `CREATIVE_ASSET_S3_ENDPOINT`.
- `CREATIVE_ASSET_S3_REGION`.
- `CREATIVE_ASSET_S3_BUCKET`.
- `CREATIVE_ASSET_S3_PREFIX`.
- `CREATIVE_ASSET_S3_ACCESS_KEY_ID`.
- `CREATIVE_ASSET_S3_SECRET_ACCESS_KEY`.
- `CREATIVE_ASSET_S3_FORCE_PATH_STYLE=true|false`.

Rules:

- `production` mode requires `s3-compatible` and complete S3 config; missing/unhealthy config fails closed.
- `production` must not auto-fallback to DB.
- `database` mode on VPS-A requires explicit canary flag and caps/reserve.
- Real secrets must not be written to repo, Trellis artifacts, logs, test fixtures, snapshots, or frontend state.

### API endpoints

All endpoints are under existing `/creative/api` route group.

- `POST /creative/api/assets`
  - Auth: session + creative nonce.
  - Request: `multipart/form-data` with `file`, optional `mediaType` and `clientAssetId`. Raw `sourceUrl` is not accepted.
  - Server computes content hash; client hash is only an optimization hint if added later.
  - Response data excludes `StorageBackend`, `ObjectKey`, bucket URL, signed URL, and provider metadata:
    ```json
    {
      "asset": {
        "id": "asset_...",
        "contentHash": "sha256hex",
        "mediaType": "image",
        "mimeType": "image/png",
        "size": 1234,
        "url": "/creative/api/assets/asset_.../content",
        "createdTime": 1710000000,
        "updatedTime": 1710000000
      }
    }
    ```

- `GET /creative/api/assets/:id`
  - Auth: session.
  - Response: metadata only with `Cache-Control: private, no-store` or equivalent.

- `GET /creative/api/assets/:id/content`
  - Auth: session.
  - new-api streams bytes from the configured storage backend.
  - Response: raw bytes, `Content-Type`, `Content-Length`, `Cache-Control: private, max-age=31536000, immutable` or safer `no-store`, `Vary: Cookie`, and `X-Content-Type-Options: nosniff`.
  - Support Range: valid range returns 206 with `Accept-Ranges: bytes` and `Content-Range`; invalid range returns 416.
  - Never redirect to provider URL and never return signed URL/ObjectKey.
  - Cross-user, missing asset, or missing backend object returns non-leaky 404/asset error.

- `DELETE /creative/api/assets/:id`
  - Auth: session + creative nonce.
  - If referenced by any owner document: return 409.
  - If unreferenced: remove/disable visible metadata first, then best-effort delete backend object/DB bytes.

### Upload consistency ordering

1. Stream multipart with request cap, part count cap, field size cap, and `io.LimitReader(max+1)` for the file part.
2. Compute hash, sniff MIME, media type, and size within bounded memory/temp-spool limits.
3. Check same-user dedupe before object write when possible.
4. Reserve quota atomically.
5. For `s3-compatible`: write object, then `Head`/verify size/hash or equivalent before committing visible DB metadata.
6. For `database`: write bytes only after DB canary caps and disk-headroom checks pass.
7. If object write succeeds but DB commit fails, duplicate race occurs, or request is canceled, best-effort delete the orphan object and record scrubbed retryable debt.
8. Do not commit visible metadata pointing to a missing object.

### Document reference refresh

On successful creative document create/update:

1. Normalize/sanitize snapshot and metadata as today.
2. Recursively extract asset ids from `/creative/api/assets/:id/content` and optional future `creativeAssetId` / `cloudAssetId` fields.
3. Verify every referenced id belongs to current user. Missing, foreign, malformed, query-bearing, or cross-origin refs return HTTP 400 and do not save the document mutation.
4. In the same transaction or equivalent atomic service boundary, replace refs for `(user_id, document_id)`.

On document delete:

- Delete document refs for `(user_id, document_id)`.

GC policy:

- MVP provides deterministic delete for unreferenced assets.
- Optional orphan cleanup can retry object deletes and remove unreferenced backend objects owner-scoped.

## Frontend contract

### Asset reference discovery

Create a shared traversal helper, not a one-off in document sync. Reuse `virtual-media-url.ts` and extend field coverage from `embedded-media.ts`.

Candidate URL fields:

- `url`
- `urls[]`
- `imageUrl`
- `videoUrl`
- `audioUrl`
- `poster`
- `src`
- `thumbnail`
- `thumbnailUrl`
- `thumbnailUrls[]`
- `previewImageUrl`
- `coverUrl`
- nested `clips[].audioUrl`, `clips[].imageUrl`, `clips[].imageLargeUrl`

Local upload candidates:

- `data:image/*`, `data:audio/*`, `data:video/*`
- `blob:*`
- `isVirtualMediaUrl(value) === true`, including `/__aitu_cache__/`, `/asset-library/`, `/__aitu_generated__/audio/`

Cloud refs:

- Relative or absolute same-origin `/creative/api/assets/:id/content` are already cloud refs and must not be re-uploaded.
- Reject query strings, hashes, cross-origin URLs, protocol-relative URLs, encoded slash/path traversal, malformed ids, and overlong ids.

Remote refs:

- Credential-free `http(s)` URLs may remain unchanged only as an explicit product exception after URL sanitizer approval.
- Credential-bearing or signed `http(s)` URLs must not be saved raw. Implementation may anonymously fetch and upload bytes; if that fails, document mutation stays pending/blocked with a non-sensitive recoverable error.

### Outbound flow

```
Board -> build snapshot -> sanitize -> prepare assets -> upload blobs -> rewrite outbound snapshot -> final signed URL guard -> document create/put
```

Important: local board state remains local. Only the payload sent to new-api contains cloud content URLs.

### Hydration / cold-start load flow

```
list documents -> get remote document -> hydrate cloud URLs -> cache blobs locally -> rewrite to local virtual URLs -> save/import board locally -> store revision
```

MVP target is fresh browser/device where local board id is absent. If a local board exists and revisions differ, do not overwrite silently; record/freeze conflict using existing conflict status mechanisms.

### Workspace integration

Current `CreativeDocumentCloudSyncService` only observes local workspace events. Add a small workspace import/apply abstraction so tests can simulate cold-start without relying on private `WorkspaceService` maps.

Suggested interface:

```ts
interface CreativeWorkspaceCloudRepository {
  hasBoard(boardId: string): Promise<boolean>;
  getStoredRevision(boardId: string): Promise<string | number | null>;
  upsertBoardFromCloud(board: Board, revision: string | number, options?: { suppressOutboundSync?: boolean }): Promise<void>;
}
```

Default implementation can use workspace storage/reload or a purpose-built public WorkspaceService method. It must not emit ordinary outbound `boardCreated/boardUpdated` sync during import.

### Bootstrap / feature flag

- new-api bootstrap or equivalent exposes non-secret `assetSyncEnabled` and disabled/config reason.
- Opentu prepares/hydrates assets only when enabled.
- If disabled and a board contains local-only or signed/credentialed media, document sync remains pending with sanitized status rather than saving a broken snapshot.

## Error handling and consistency

- Asset upload failures for required local binary refs block document mutation and keep the board pending locally.
- Fetch failure for credentialed/signed URLs blocks/keeps pending; preserving the original URL would leak secrets or create expiring snapshots.
- If asset upload succeeds but document PUT later gets 409, keep uploaded asset available but do not change document refs; orphan cleanup can remove it later once unreferenced.
- Existing document conflict behavior remains authoritative: never overwrite remote documents after stale base revision.
- Sanitized conflict/status payloads must not include remote document content, raw media URLs, bucket URLs, ObjectKey, or secret values.

## Security and privacy

- Asset bytes are user-private by default; no public unauthenticated content URLs.
- Buckets/prefixes are private. No public read ACL/policy.
- Asset metadata must not include provider API keys, upstream base URLs, auth headers, tokens, ObjectKey, public object URLs, signed URLs, or bucket secrets.
- Direct document snapshot/metadata saves and asset metadata saves must reject or strip signed/credential-bearing URLs before DB persistence.
- MIME sniffing/allowlist is server-side; client-provided MIME is not trusted.
- Access-token/API-token mode is rejected for all asset endpoints.
- All S3 errors/logs/status values must be scrubbed before surfacing to frontend or persisted status.

## Compatibility and migration

- Existing documents without cloud assets continue to load normally.
- Existing local boards keep local URLs; cloud URLs appear only in remote snapshot payloads and hydrated imports.
- Existing JSON export/import embedded media behavior remains separate.
- DB canary rows can later migrate to object storage by copying bytes, setting `StorageBackend/ObjectKey`, verifying hash/size, then clearing `Data` only under a separate migration/rollback plan.

## Rollback

- Backend rollback: disable `/creative/api/assets` routes and feature entry points; keep additive schema, DB rows, refs, and bucket objects intact unless separate destructive-operation approval is obtained.
- If S3 config is unhealthy, production asset sync stays disabled. Do not silently route production bytes into DB.
- Frontend rollback: disable asset preparation/hydration behind a single feature flag/service injection point while keeping JSON document sync operational for boards with no local-only/signed media.

## Planning fixes retained from earlier dynamic workflow

- MVP image allowlist excludes `image/svg+xml`.
- Asset API calls use same-origin credentials and never send Authorization, API keys, upstream base URLs, or provider settings.
- Metadata/mutation JSON responses use private/no-store or equivalent; content responses use private cache plus `Vary: Cookie` or no-store and `nosniff`.
- Multipart upload must avoid `FormFile`, `ParseMultipartFormReusable`, and full-body `BodyStorage.Bytes()` as the primary asset path.
- Quota/concurrency tests must cover same-hash dedupe, distinct upload over-quota, and `creative_asset_quota_exceeded`.
- Opentu service worker/static asset layer must pass through `/creative/api/assets/*` before image/audio/video/static caches.
- Cold-start import converts new-api seconds timestamps to Opentu milliseconds, applies folder fallback, stores only non-sensitive import status, and never saves a broken board on hydration failure.
