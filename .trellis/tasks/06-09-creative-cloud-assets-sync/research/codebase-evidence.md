# Codebase Evidence — Creative Cloud Binary Asset Sync

Date: 2026-06-09

## Confirmed facts from inspection

### new-api

- `/creative/api` currently exposes bootstrap, models, model preference, and document CRUD under `router/web-router.go`.
- Document CRUD is implemented in `controller/creative.go` and stores safe JSON snapshots via `model.CreativeDocument` in `model/creative.go`.
- `CreativeDocument` persists `SnapshotJSON`, `MetadataJSON`, `Revision`, and `ClientMutationId`; it does not store binary asset bytes or asset references separately.
- `/creative/api/documents` is owner-scoped by session user and mutating calls use `middleware.CreativeRequireNonce()`.
- Current `/creative/api` has no `/assets` or blob/content route.
- The repo has disk/body cache helpers, but no durable object-storage abstraction for user uploads. Existing creative state is DB-backed.

### opentu

- `creative-document-sync.ts` serializes a board into `{ id, title, snapshot: { elements, viewport, theme }, metadata }`, sanitizes secrets, and pushes it to `/creative/api/documents`.
- The sync service listens for board create/update/delete events and handles create/put/delete plus 409 conflict freezing.
- Current cloud sync does not upload `Blob`, Cache Storage, IndexedDB media bytes, or asset-library bytes.
- Local media URLs appear as:
  - `/__aitu_cache__/...`
  - `/asset-library/...`
  - `/__aitu_generated__/audio/...`
  - `blob:...`
  - `data:image|audio|video/...`
- `unified-cache-service.ts` can read/write cached blobs by virtual URL and can create content-addressed local URLs.
- `embedded-media.ts` already traverses element trees for `url`, `imageUrl`, `videoUrl`, `poster`, and `src`, but only for JSON export/import embedding, not cloud sync.
- `virtual-media-url.ts` centralizes virtual media URL prefixes and detection.
- Workspace persistence supports local board save/load via `workspace-storage-service.ts`; current cloud sync has no cold-start remote import/hydration path.

## Planning implications

- The minimum reliable implementation needs both sides:
  1. new-api owner-scoped asset storage and content retrieval.
  2. opentu pre-upload + snapshot rewrite before document sync.
  3. opentu cold-start remote document import + local cache hydration to prove cross-device survival.
- Asset refs should be stable server refs in cloud snapshots and rehydrated into local virtual cache URLs on remote load.
- DB-backed blobs are the lowest-dependency MVP because current creative persistence is DB-backed and no object storage adapter exists.
- Ref/GC policy must be explicit. The safest MVP is to track document→asset refs on document create/update/delete, reject deletion of still-referenced assets, and allow deletion/GC only for unreferenced owner-scoped assets.

## 2026-06-09 VPS capacity re-plan superseding note

Earlier planning favored the lowest-dependency DB-backed blob MVP. After reviewing current VPS documentation and rerunning a dynamic workflow, that recommendation is superseded for production scope: DB-backed blobs remain useful for local development, tests, and explicitly capped tiny canary, but current VPS-A/public production rollout now requires `S3CompatibleCreativeAssetStorage` plus DB metadata/ref tracking. Opentu snapshot/API shape remains unchanged and must continue to use only `/creative/api/assets/:id/content`.
