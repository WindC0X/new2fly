# Creative Async Suno Relay Frontend Contract

## Scenario: Opentu embedded Suno audio via session-broker

### 1. Scope / Trigger

- Trigger: implementing Opentu audio/Suno generation against `new-api` creative browser-session relay.
- This is cross-layer work: provider routing, transport credential stripping, submit/fetch paths, idempotency, unsupported-backend behavior, and task queue propagation must align with backend `/creative/relay/v1/suno`.

### 2. Signatures

- Session-broker provider context:
  - `baseUrl: "/creative/relay/v1"`
  - `authType: "session-broker"`
  - `apiKey: ""` is valid only for session-broker.
- Suno paths relative to session-broker base:
  - submit music: `/suno/submit/music`
  - submit lyrics: `/suno/submit/lyrics`
  - fetch: `/suno/fetch/{taskId}`
- Submit idempotency:
  - header: `Idempotency-Key`
  - preferred value: `opentu-audio-<localTaskId>`.

### 3. Contracts

- Embedded session-broker audio never sends browser upstream credentials: no `Authorization`, API-key headers, provider/base URL/channel/group/selected-key overrides, or model override query material.
- Embedded session-broker audio submit bodies are allowlist-built. They must drop `notifyHook`, `notify_hook`, `callback`, and `webhook` from both top-level params and nested `params`; direct/non-session-broker lyrics may still send `notify_hook` for legacy provider compatibility.
- Direct/non-session-broker audio still requires a real API key and must fail before fetch when empty.
- For session-broker audio, ignore binding `baseUrlStrategy` that would trim `/creative/relay/v1`; paths remain same-origin and relative.
- Session-broker unsafe methods (`POST`, `PUT`, `PATCH`, `DELETE`) require Creative CSRF + nonce material before `fetch`; fail locally if bootstrap auth is absent.
- Submit idempotency must be stable for a local task. Generation/task queue paths must pass the local task id/idempotency source into audio generation.
- Unsupported creative Suno backend responses (`404`, `405`, `501`) surface a sanitized unsupported-backend error and must not retry direct provider transport.

### 4. Validation & Error Matrix

- `authType !== "session-broker"` and empty `apiKey` -> throw before fetch.
- `authType === "session-broker"` and empty `apiKey` -> allowed; transport adds creative CSRF/nonce and same-origin credentials.
- Session-broker absolute path or non-canonical base URL -> reject in provider transport.
- Session-broker credential/routing query or headers -> strip before fetch.
- Session-broker unsafe method with missing CSRF/nonce -> throw before fetch; do not send a same-origin relay mutation without bootstrap auth.
- Session-broker submit without local task id / stable idempotency source -> throw before fetch; never generate opaque/random idempotency keys for relay submissions.
- Session-broker `404/405/501` submit/fetch -> sanitized unsupported error; no direct fallback request.
- Session-broker non-unsupported submit/fetch errors -> sanitized status-only error; do not read/log/expose raw backend bodies.

### 5. Good/Base/Bad Cases

- Good: task queue calls audio generation with `params.idempotencyKey = "opentu-audio-<taskId>"`; audio service posts to `/creative/relay/v1/suno/submit/music` with same-origin credentials and no upstream auth headers.
- Base: direct Tuzi/Suno provider with configured API key continues using legacy `/suno/submit/music` and `/suno/fetch/{taskId}` behavior.
- Bad: empty session-broker API key throws, submit uses `/creative/relay/v1/v1/suno/...`, unsupported backend falls back to direct provider, or `model/provider/baseUrl/channel/notifyHook/callback/webhook` leaks into session-broker URL/header/body.

### 6. Tests Required

- Audio service tests for session-broker empty-key submit/fetch success and direct empty-key fail-fast.
- Audio service tests proving session-broker lyrics and music submit bodies strip top-level and nested `notifyHook`, `notify_hook`, `callback`, and `webhook`, plus a direct-provider lyrics compatibility test for legacy `notify_hook`.
- Tests for canonical submit/fetch paths and stable `Idempotency-Key` propagation from local task id.
- Provider transport tests proving Suno session-broker strips model/provider/baseUrl/channel/API-key query and headers.
- Provider transport tests proving unsafe session-broker methods without CSRF/nonce fail before fetch.
- Unsupported-backend tests proving `404/405/501` does not retry or fallback.
- Typecheck via `packages/drawnix/tsconfig.spec.json` and targeted Vitest for audio/provider-routing/session-broker suites.

### 7. Wrong vs Correct

#### Wrong

```typescript
if (!providerContext.apiKey) throw new Error('API Key 未配置');
await providerTransport.send(ctx, { path: binding.pollPathTemplate }); // may include model/provider query
// 501 -> retry direct provider profile
```

#### Correct

```typescript
if (!apiKey && authType !== 'session-broker') throw new Error('API Key 未配置');
await providerTransport.send(sessionBrokerCtx, {
  path: `/suno/fetch/${encodeURIComponent(taskId)}`,
});
// 501 -> unsupported creative Suno error, no fallback
// session-broker lyrics body omits notify/callback/webhook fields
```
