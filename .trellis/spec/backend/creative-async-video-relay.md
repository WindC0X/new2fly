# Creative Async Video Relay Backend Contract

## Scenario: `/creative/relay/v1/videos` async video relay

### 1. Scope / Trigger

- Trigger: implementing browser-session async video relay in `new-api` for embedded Opentu.
- This is cross-layer/infra work: it adds public route signatures, env gating, task/idempotency DB state, billing/refund lifecycle, owner-scoped status/content, and provider channel/key affinity.
- Suno/MJ are out of scope unless a separate task adds and verifies their contracts.

### 2. Signatures

- API:
  - `POST /creative/relay/v1/videos` — submit async video task.
  - `GET /creative/relay/v1/videos/:task_id` — fetch owner-scoped task status/result.
  - `GET /creative/relay/v1/videos/:task_id/content` — fetch owner-scoped generated content.
- Env:
  - `CREATIVE_VIDEO_RELAY_ENABLED=false` by default; production/canary enablement must be explicit.
- DB/task state:
  - `Task.UserId`, `Task.TaskID`, `Task.ChannelId`, `Task.PrivateData.UpstreamTaskID`, `Task.PrivateData.Key`, `Task.PrivateData.IdempotencyKey`, billing context, model/action metadata.
  - `CreativeVideoIdempotency(UserID, Scope, RequestID, PayloadHash, TaskID)` with uniqueness scoped by user + scope + request id.

### 3. Contracts

- Public embedded routes are canonical under `/creative/relay/v1/videos`; do not expose `/creative/relay/v1/v1/videos`.
- The route boundary must be browser-session only: session header bridge + user auth + same-origin + nonce for unsafe methods + forbidden-material validation before session-broker distribution.
- Submit requires a durable request id (`Idempotency-Key` or documented equivalent) and buffers upstream success response until task insert, idempotency completion, and settlement/log bookkeeping have succeeded.
- Status/content must load tasks by `user_id + task_id`; cross-user access returns non-leaky not-found style errors.
- Status/content provider calls use stored channel/key affinity (`Task.PrivateData.Key` or equivalent). They must not silently perform fresh random channel/key selection for an accepted task.

### 4. Validation & Error Matrix

- Gate disabled or unsupported route -> safe 404/405/501 before upstream relay or billing mutation.
- Missing browser session/API-token-only auth -> 401/403 non-leaky error.
- Missing/invalid nonce on `POST` -> 403 before upstream relay.
- Forbidden header/query/body/form/file part credential or routing material -> 400 before upstream relay.
- Missing submit idempotency key -> 400.
- Same idempotency key + different payload hash -> 409.
- Same idempotency key + same payload hash + completed task record -> replay existing task response.
- Upstream submit failure before accepted task persistence -> refund once and clean idempotency if no task was created.
- Terminal poll/update success/failure -> exactly one CAS winner settles or refunds; CAS losers do not double-settle/refund.

### 5. Good/Base/Bad Cases

- Good: browser submits `POST /creative/relay/v1/videos` with same-origin nonce and `Idempotency-Key`; backend selects a channel once, stores the selected key, persists task, then flushes the success response.
- Base: repeated submit with same key/payload returns the same public task id without a second charge.
- Bad: returning upstream success before task persistence, allowing `headers.Authorization` as a multipart file part name, using a fresh random key during poll/content, or exposing selected channel/key/base URL in client errors.

### 6. Tests Required

- Route/middleware tests for canonical paths, double-version rejection, session/same-origin/nonce, GET nonce policy, forbidden header/query/JSON/multipart field and file-part names, and body replay.
- Idempotency tests for replay, conflict, cleanup on downstream reject, and user + scope + request uniqueness.
- Billing/CAS tests for submit failure refund once, terminal failure refund once, success settle once, and concurrent terminal transition single-winner behavior.
- Affinity tests proving polling and content use stored selected key, not channel current key.
- Owner-scope tests proving cross-user status/content cannot fetch tasks.

### 7. Wrong vs Correct

#### Wrong

```text
POST /creative/relay/v1/videos -> upstream success flushed -> task insert fails
GET /creative/relay/v1/videos/:id/content -> selects fresh channel key
multipart file part name: headers.Authorization -> accepted
```

#### Correct

```text
POST /creative/relay/v1/videos -> buffer upstream success -> insert task + complete idempotency + settle -> flush
GET /creative/relay/v1/videos/:id/content -> load owner task -> use Task.PrivateData.Key
multipart file part name: headers.Authorization -> 400 forbidden field before relay
```
