# Creative Async Suno Relay Backend Contract

## Scenario: `/creative/relay/v1/suno` async Suno relay

### 1. Scope / Trigger

- Trigger: implementing embedded Opentu Suno music/lyrics generation through `new-api` browser-session creative relay.
- This is cross-layer/infra work: it adds route signatures, server-side model/action inference, scoped idempotency, owner-scoped fetch, selected-key affinity, and async task billing/CAS behavior.
- Do not expose legacy token-auth `/suno` routes directly to embedded browser users.

### 2. Signatures

- API:
  - `POST /creative/relay/v1/suno/submit/:action` — submit Suno task; `:action` is `music` or `lyrics`.
  - `GET /creative/relay/v1/suno/fetch/:id` — fetch owner-scoped task status/result.
  - `POST /creative/relay/v1/suno/fetch` — optional batch fetch compatibility, still owner-scoped.
- Server-side model inference:
  - `music -> suno_music`
  - `lyrics -> suno_lyrics`
- Submit idempotency:
  - request id from `Idempotency-Key` or `X-Creative-Request-Id`.
  - scopes: `suno.submit.music`, `suno.submit.lyrics`.
- Task state:
  - public `Task.TaskID`, upstream `Task.PrivateData.UpstreamTaskID`, selected `Task.PrivateData.Key`, billing context, and idempotency key.

### 3. Contracts

- The route boundary must be browser-session only: session header bridge + user auth + same-origin + nonce for unsafe methods + forbidden-material validation before distribution.
- Browser requests must not provide upstream `Authorization`, API keys, base URL, provider, channel, selected key, owner override, or `model` for Suno submit. The backend derives the model from route action.
- The creative session broker must use the derived model for group/model availability before channel selection.
- Submit buffers the upstream success response until local task insert, scoped idempotency completion, settlement/logging path, and task state are safe.
- Fetch loads tasks by `user_id + task_id`; cross-user and missing tasks return non-leaky not-found style errors.
- Polling must use stored selected key affinity (`Task.PrivateData.Key` when present). Multi-key channels must not drift by using the current raw channel key pool during fetch.

### 4. Validation & Error Matrix

- Invalid action -> `400` before relay/distribution.
- Missing browser session/API-token-only auth -> `401/403` before upstream relay.
- Missing/invalid nonce on submit -> `403` before upstream relay.
- Forbidden header/query/body/form/multipart credential or routing material -> `400` before upstream relay.
- Browser-supplied submit `model` -> `400` before relay; server-side model override remains internal.
- Missing idempotency key on submit -> `400`.
- Same idempotency key + different payload hash -> `409`.
- Same idempotency key + same payload hash + completed task record -> replay public task id without second charge.
- Upstream submit/local persistence failure -> refund pre-consume once and delete the scoped idempotency record.
- Terminal poll success/failure -> exactly one CAS winner settles/refunds; CAS losers skip billing mutation.

### 5. Good/Base/Bad Cases

- Good: browser submits `POST /creative/relay/v1/suno/submit/music` with nonce and `Idempotency-Key`; backend infers `suno_music`, selects a channel server-side, stores selected key, persists task, completes `suno.submit.music` idempotency, then flushes public task id.
- Base: `GET /creative/relay/v1/suno/fetch/task_x` for same user returns task status; another user sees non-leaky not-found.
- Bad: mounting `/suno` token-auth handlers directly under `/creative`, trusting body `model`, polling with `channel.Key` instead of `Task.PrivateData.Key`, or calling refund without a terminal CAS win.

### 6. Tests Required

- Route/middleware tests for canonical Suno paths, invalid action, session/same-origin/nonce, forbidden fields, and browser model rejection.
- Idempotency tests for replay, conflict, action-scope separation, and cleanup on downstream reject.
- Submit tests proving server-side group/model inference and selected key/task persistence.
- Fetch tests for same-user success, cross-user rejection, and missing task.
- Polling tests proving stored-key grouping, `ch.GetBaseURL()` usage, CAS single-winner refund, and CAS single-winner success settlement/no double-settle.
- Run targeted Go tests for `middleware`, `router`, `controller`, `service`, `model`, `relay/constant`, `relay/common`, and `relay/channel/task/suno`.

### 7. Wrong vs Correct

#### Wrong

```text
POST /creative/relay/v1/suno/submit/music with {"model":"suno_lyrics"} -> accepted
Suno polling -> adaptor.FetchTask(channel.GetBaseURL(), channel.Key, ...)
Terminal FAILURE -> task.Update(); RefundTaskQuota(...)
```

#### Correct

```text
POST /creative/relay/v1/suno/submit/music -> server infers suno_music; browser model is forbidden
Suno polling -> group tasks by Task.PrivateData.Key, fallback to channel key only for old tasks
Terminal FAILURE/SUCCESS -> UpdateWithStatus(previousStatus); only CAS winner mutates billing
```
