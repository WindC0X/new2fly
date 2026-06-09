# Creative Asset Sync Frontend Contract

## Scenario: Opentu cloud asset prepare and hydrate

### 1. Scope / Trigger

- Trigger: embedded Opentu must sync image/audio/video bytes with new-api document snapshots.
- This is cross-layer work: it touches snapshot traversal, same-origin API calls, local cache hydration, service worker routing, and secret-safe status/log behavior.

### 2. Signatures

- Outbound prepare:
  - input: board/document snapshot object.
  - output: deep-copied snapshot where local media URLs are replaced with `/creative/api/assets/:id/content`.
- Asset adapter:
  - `upload(blob, metadata) -> /creative/api/assets/:id/content`
  - `download(/creative/api/assets/:id/content) -> Blob`
- Hydration:
  - input: remote document snapshot.
  - output: deep-copied local board where cloud refs are cached and replaced with local `unifiedCacheService` URLs.
- Service worker:
  - `/creative/api/assets/*` must pass through before static/media/app-shell caches.

### 3. Contracts

- Opentu never stores or sends object-storage implementation details:
  - no bucket URL, signed URL, `ObjectKey`, provider endpoint, access key, secret, API key, Authorization header, upstream base URL, or raw `sourceUrl`.
- Upload requests use same-origin browser session credentials and creative nonce/CSRF material only.
- Outbound prepare is pure:
  - live board, queued snapshot, and conflict-pending snapshot remain local.
  - only the request payload sent to new-api is rewritten to cloud refs.
- `assetSyncEnabled=false` is fail-closed:
  - local-only/signed media keeps document sync pending/sanitized.
  - do not save broken cloud documents.

### 4. Validation & Error Matrix

- Local media URL with asset sync enabled -> resolve Blob, upload, rewrite outbound copy.
- Local media URL with asset sync disabled -> pending/recoverable sanitized status; no document mutation.
- Signed/credentialed remote URL -> reject or upload via safe anonymous fetch; never persist the original URL.
- Hydration 401/404/network/MIME/size/quota failure -> do not save unresolved refs; record sanitized status.
- 409 document conflict after asset upload -> keep local board and pending snapshot unchanged.
- Service worker request to `/creative/api/assets/*` -> pass through; no static/media/app-shell cache write.

### 5. Good/Base/Bad Cases

- Good: `/__aitu_cache__/image/a.png` uploads to new-api and outbound payload contains `/creative/api/assets/asset_x/content`; local board still contains `/__aitu_cache__/image/a.png`.
- Base: remote document with `/creative/api/assets/asset_x/content` hydrates into a content-addressed local cache URL before local save/import.
- Bad: mutating the live board to cloud URLs, logging signed URLs, sending `Authorization` or provider keys to `/creative/api/assets`, or caching private asset responses in the service worker.

### 6. Tests Required

- Pure outbound rewrite tests for:
  - `data:`, `blob:`, `/__aitu_cache__/`, `/asset-library/`, `/__aitu_generated__/audio/`.
  - nested fields: `url`, `urls[]`, `imageUrl`, `videoUrl`, `audioUrl`, `poster`, `src`, thumbnails, covers, clips.
- Sanitizer tests proving signed URLs, bucket URLs, object keys, provider credentials, and raw source URLs do not persist.
- Conflict tests proving asset upload success does not override 409 document freeze.
- Hydration tests for successful cache rewrite and safe failures.
- Service worker pass-through tests for image/audio/video/fetch destinations.
- Typecheck/build checks for changed packages when feasible.

### 7. Wrong vs Correct

#### Wrong

```typescript
board.elements[0].imageUrl = '/creative/api/assets/asset_x/content';
localStorage.setItem('last-error', signedUrl);
fetch('/creative/api/assets', { headers: { Authorization: apiKey } });
```

#### Correct

```typescript
const outbound = await prepareCreativeDocumentAssetsForSync(board, options);
// board remains local; outbound is cloud-safe.
await documentAdapter.put(board.id, outbound);
// status/log values contain sanitized error codes only.
```
