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
- Session-broker transport uses same-origin credentials and creative CSRF/nonce material for unsafe submit requests; missing CSRF/nonce must throw before `fetch`.
- Unsupported creative video submit/status/content responses (`404`, `405`, `501`) surface a sanitized unsupported-backend error before reading/logging raw response bodies and must not fall back to direct provider transport.
- Other session-broker submit/status/content failures surface a sanitized status-only error; do not read/log/expose raw backend bodies.
- Content retrieval uses `/videos/:taskId/content`; do not synthesize direct upstream URLs or double-version paths.

### 4. Validation & Error Matrix

- `authType !== "session-broker"` and empty `apiKey` -> throw before fetch.
- Session-broker submit without stable idempotency key -> test failure; production code should generate or propagate one.
- Session-broker path absolute URL or non-canonical base URL -> reject/strip before fetch.
- Session-broker header/query credential override -> strip or reject before fetch.
- Session-broker unsafe submit with missing CSRF/nonce -> throw before fetch.
- Submit/status/content `404`/`405`/`501` -> unsupported embedded video error before `response.text()` / raw body logging; no direct fallback request.
- Submit/status/content other non-2xx statuses -> sanitized status-only error before `response.text()` / raw body logging.

### 5. Good/Base/Bad Cases

- Good: `videoAPIService.generateVideoWithPolling` submits to `/creative/relay/v1/videos` with `Idempotency-Key: opentu-video-<taskId>` and no upstream authorization header.
- Base: repeated execution of the same local task id reuses the same idempotency key.
- Bad: adapter route drops the idempotency key, status `501` falls back to direct provider, submit/status/content unsupported errors include upstream body text, or session-broker request includes `baseUrl`, `provider`, `channel`, or `Authorization` overrides.

### 6. Tests Required

- Provider transport tests proving session-broker strips credential/routing headers/query and rejects absolute/non-canonical upstream paths.
- Video API service and shared `media-api/video-api` tests for empty API key behavior, canonical submit/status/content paths, stable idempotency header, unsupported no-fallback behavior, no raw-body credential leakage, and missing nonce/CSRF fail-fast.
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
// 501 -> sanitized unsupported-backend error before reading/logging raw body; no fallback
```
