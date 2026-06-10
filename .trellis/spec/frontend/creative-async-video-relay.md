# Creative Async Video Relay Frontend Contract

## Scenario: Opentu embedded async video via session-broker

### 1. Scope / Trigger

- Trigger: implementing embedded Opentu video generation against `new-api` creative browser-session relay.
- This is cross-layer work: provider routing, transport credential stripping, submit/status/content paths, idempotency, cache/download, and unsupported-backend fallback behavior must stay aligned with backend routes.

### 2. Signatures

- Session-broker provider context:
  - `baseUrl: "/creative/relay/v1"`
  - `authType: "session-broker"`
  - `apiKey: ""` is allowed only for session-broker.
- Video paths relative to session-broker base:
  - submit: `/videos`
  - status: `/videos/:taskId`
  - content: `/videos/:taskId/content`
- Submit idempotency:
  - stable key per local task, e.g. `opentu-video-${taskId}`.
  - adapter/fallback paths must pass the same key to `videoAPIService` / `generateVideoWithPolling`.

### 3. Contracts

- Embedded session-broker video never sends browser upstream credentials: no `Authorization`, `apiKey`, provider/base URL, channel/group, or model override header/query material.
- Direct/non-session-broker video still requires a real API key and must fail before fetch if empty.
- Session-broker transport uses same-origin credentials and creative CSRF/nonce material for unsafe submit requests.
- Unsupported creative video status/content responses (`404`, `405`, `501`) surface a sanitized unsupported-backend error and must not fall back to direct provider transport.
- Content retrieval uses `/videos/:taskId/content`; do not synthesize direct upstream URLs or double-version paths.

### 4. Validation & Error Matrix

- `authType !== "session-broker"` and empty `apiKey` -> throw before fetch.
- Session-broker submit without stable idempotency key -> test failure; production code should generate or propagate one.
- Session-broker path absolute URL or non-canonical base URL -> reject/strip before fetch.
- Session-broker header/query credential override -> strip or reject before fetch.
- Status/content `404`/`405`/`501` -> unsupported embedded video error; no direct fallback request.

### 5. Good/Base/Bad Cases

- Good: `videoAPIService.generateVideoWithPolling` submits to `/creative/relay/v1/videos` with `Idempotency-Key: opentu-video-<taskId>` and no upstream authorization header.
- Base: repeated execution of the same local task id reuses the same idempotency key.
- Bad: adapter route drops the idempotency key, status `501` falls back to direct provider, or session-broker request includes `baseUrl`, `provider`, `channel`, or `Authorization` overrides.

### 6. Tests Required

- Provider transport tests proving session-broker strips credential/routing headers/query and rejects absolute/non-canonical upstream paths.
- Video API service tests for empty API key behavior, canonical submit/status/content paths, stable idempotency header, unsupported no-fallback behavior, and no credential leakage.
- Media executor / adapter route tests proving fallback adapter video paths pass `opentu-video-${taskId}` to adapters and downstream video service.
- Typecheck (`tsconfig.spec.json`) must include these tests; prefer precise Vitest mock typings over `any` or suppressions.

### 7. Wrong vs Correct

#### Wrong

```typescript
await adapter.generateVideo(context, { prompt, model }); // drops stable idempotency key
fetch('/creative/relay/v1/videos/task_1', { headers: { Authorization: apiKey } });
// 501 -> retry direct provider
```

#### Correct

```typescript
await adapter.generateVideo(context, {
  prompt,
  model,
  idempotencyKey: `opentu-video-${taskId}`,
});
// session-broker fetch uses same-origin credentials, nonce, and no upstream credentials
// 501 -> sanitized unsupported-backend error, no fallback
```
