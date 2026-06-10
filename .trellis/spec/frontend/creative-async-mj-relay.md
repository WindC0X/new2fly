# Creative Async MJ Relay Frontend Contract

## Scenario: Opentu embedded MJ image generation via session-broker

### 1. Scope / Trigger

- Trigger: implementing Opentu Midjourney image generation against `new-api` creative browser-session relay.
- This is cross-layer work: provider routing, adapter base URL handling, credential stripping, submit/fetch paths, submit idempotency, unsupported-backend behavior, and task queue propagation must align with backend `/creative/relay/v1/mj`.
- This contract applies only to embedded session-broker mode. Standalone/direct MJ provider behavior remains available outside embedded mode and still requires a real upstream API key.

### 2. Signatures

- Session-broker provider context:
  - `baseUrl: "/creative/relay/v1"`
  - `authType: "session-broker"`
  - `apiKey: ""` is valid only for session-broker.
- MJ paths relative to session-broker base:
  - submit imagine: `/mj/submit/imagine`
  - fetch: `/mj/task/{taskId}/fetch`
  - image result URL is returned by backend fetch as `/creative/relay/v1/mj/image/{taskId}` when available.
- Submit idempotency:
  - header: `Idempotency-Key`
  - preferred value: `opentu-image-<localTaskId>`.
- Adapter request shape:
  - body includes `botType: "MID_JOURNEY"`, `prompt`, and optional `base64Array` with data URL prefixes stripped.

### 3. Contracts

- Embedded session-broker MJ must preserve base URL exactly as `/creative/relay/v1`; do not trim the final `/v1` to `/creative/relay`.
- Embedded session-broker MJ never sends browser upstream credentials or routing material: no `Authorization`, API-key headers/query, provider/base URL/channel/group/model overrides, selected key, or `notifyHook`.
- Provider transport strips `model` and related server-selected model overrides on `/mj` paths, matching video/Suno behavior.
- Direct/non-session-broker MJ still requires a real API key and fails before fetch when empty.
- Submit idempotency must be stable for a local image task. `generation-api-service` and fallback adapter routes pass `opentu-image-<taskId>` into MJ adapter requests.
- The MJ adapter calls `params.onSubmitted(taskId)` when submit returns the public task id so local task resume metadata can be updated.
- Unsupported creative MJ backend responses (`404`, `405`, `501`) produce a sanitized unsupported-backend error and must not retry direct provider transport.

### 4. Validation & Error Matrix

- `authType !== "session-broker"` and empty `apiKey` -> throw before fetch.
- `authType === "session-broker"` and empty `apiKey` -> allowed; provider transport adds creative CSRF/nonce and same-origin credentials.
- Session-broker absolute request path or non-canonical base URL -> reject in provider transport.
- Session-broker credential/routing/model query or headers -> strip before fetch.
- Session-broker MJ submit without local task id -> generate opaque `opentu-image-*` idempotency key; never include prompt text or credentials in the key.
- Session-broker `404/405/501` submit/fetch -> sanitized unsupported MJ backend error; no direct fallback request.
- MJ fetch failure status from backend -> throw sanitized task failure reason, not upstream secrets.

### 5. Good/Base/Bad Cases

- Good: task queue calls image generation with local task id `abc`; generation service passes `idempotencyKey: "opentu-image-abc"`; MJ adapter posts to `/creative/relay/v1/mj/submit/imagine` with same-origin credentials and no upstream auth headers, then polls `/creative/relay/v1/mj/task/task_xxx/fetch`.
- Base: direct MJ provider with configured API key continues using legacy base URL normalization and `/mj/submit/imagine` / `/mj/task/{taskId}/fetch` behavior.
- Bad: session-broker empty API key throws, adapter trims `/creative/relay/v1` to `/creative/relay`, query contains `model=...` or `provider=...`, `notifyHook` is sent, or unsupported backend falls back to direct provider credentials.

### 6. Tests Required

- MJ adapter tests for session-broker empty-key submit/fetch success, canonical submit/fetch paths, stable `Idempotency-Key`, `onSubmitted`, direct empty-key fail-fast, and sanitized unsupported-backend errors.
- Provider transport tests proving `/mj` session-broker paths strip model/provider/baseUrl/channel/group/API-key/notifyHook material and reject non-canonical base URLs.
- Generation API / media executor tests proving `opentu-image-<taskId>` propagates from local task id into MJ adapter requests.
- Existing image-routing integration tests continue to route MJ models to the dedicated MJ adapter.
- Typecheck via `packages/drawnix/tsconfig.spec.json`, `nx run drawnix:typecheck`, and targeted Vitest for MJ adapter/provider-routing/generation/media-executor suites.

### 7. Wrong vs Correct

#### Wrong

```typescript
const baseUrl = context.baseUrl.replace(/\/v1$/, ''); // breaks /creative/relay/v1
await sendAdapterRequest(ctx, { path: '/mj/submit/imagine?model=mj-imagine' });
// 501 -> retry direct provider profile
```

#### Correct

```typescript
const baseUrl = isSessionBroker ? '/creative/relay/v1' : trimLegacyV1(context.baseUrl);
await sendAdapterRequest(ctx, {
  path: '/mj/submit/imagine',
  headers: { 'Idempotency-Key': `opentu-image-${taskId}` },
});
// 501 -> unsupported creative MJ error, no fallback
```
