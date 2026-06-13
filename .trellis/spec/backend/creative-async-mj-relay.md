# Creative Async MJ Relay Backend Contract

## Scenario: `/creative/relay/v1/mj` async Midjourney relay

### 1. Scope / Trigger

- Trigger: implementing embedded Opentu Midjourney image generation through `new-api` browser-session creative relay.
- This is cross-layer/infra work: it adds creative browser-session route signatures, server-side action/model inference, scoped submit idempotency, owner-scoped task/result fetch, selected-key affinity, and async task billing/CAS behavior.
- Do not expose or remount legacy token-auth `/mj` routes directly under `/creative`.
- The first supported tranche is MJ imagine submit + fetch + image proxy. Legacy action/change/modal/shorten/blend/describe/edits/video/upload/swap/image-seed routes are explicit unsupported terminal paths until there is an embedded Opentu caller and action-specific tests.

### 2. Signatures

- API:
  - `POST /creative/relay/v1/mj/submit/imagine` — submit an MJ imagine task.
  - `GET /creative/relay/v1/mj/task/:task_id/fetch` — fetch owner-scoped task status/result by public local task id.
  - `POST /creative/relay/v1/mj/task/list-by-condition` — batch fetch compatibility by public local task ids; still owner-scoped.
  - `GET /creative/relay/v1/mj/image/:task_id` — owner-scoped generated image proxy.
- Unsupported creative routes:
  - `/creative/relay/v1/mj/submit/action`, `/submit/change`, `/submit/simple-change`, `/submit/modal`, `/submit/shorten`, `/submit/blend`, `/submit/describe`, `/submit/edits`, `/submit/video`, `/submit/upload-discord-images`, `/insight-face/swap`, `/task/:task_id/image-seed`.
- Server-side model/action inference:
  - `submit/imagine -> action=IMAGINE -> model=mj_imagine`.
- Submit idempotency:
  - request id from `Idempotency-Key` or `X-Creative-Request-Id`.
  - scope: `mj.submit.imagine`.
- Storage:
  - `model.Task.TaskID` is the public id returned to browser as MJ `result` / fetch `id`.
  - `Task.PrivateData.UpstreamTaskID` stores upstream MJ id.
  - `Task.PrivateData.Key` stores submit-time selected upstream key for polling/fetch affinity.
  - `Task.PrivateData.ResultURL` stores upstream image URL only after successful polling; browser sees the owner-scoped `/creative/relay/v1/mj/image/:task_id` proxy URL.

### 3. Contracts

- Route boundary:
  - supported submit/fetch/list/image routes must run through creative session bridge, user auth, same-origin, forbidden relay-field rejection, session broker, and distribution where upstream/model selection is needed.
  - unsafe methods (`POST`, `PUT`, `PATCH`, `DELETE`) must also validate bootstrap CSRF/nonce material; owner-scoped `GET` fetch/image routes remain session + same-origin protected without nonce.
  - unsupported action routes must still require browser-session creative auth and return a terminal unsupported error without legacy fallback or upstream distribution.
- Browser requests must not provide upstream `Authorization`, API keys, base URL, provider, group/channel, selected key, owner/user id override, `model`, or `notifyHook`.
- Backend derives `mj_imagine` internally before creative session-broker group/model availability and channel selection.
- The MJ task adaptor must call upstream MJ submit/fetch with `mj-api-secret`, not `Authorization: Bearer`.
- Submit buffers the upstream success response until local task insert, scoped idempotency completion, settlement/logging path, and task state are safe.
- The browser-facing submit response uses the public local task id as `result`; upstream MJ ids remain server-private.
- Fetch and image proxy load tasks by `user_id + public task_id`; cross-user and missing tasks return non-leaky not-found style errors.
- MJ success with no `imageUrl` must not fall back to generic video proxy URLs such as `/v1/videos/:task_id/content`.
- Polling uses stored selected key affinity (`Task.PrivateData.Key` when present). Multi-key channels must not drift by using the current raw channel key pool.
- Terminal polling updates must use CAS (`UpdateWithStatus`) before billing mutation. Only the CAS winner settles success or refunds failure.

### 4. Validation & Error Matrix

- Missing browser session/API-token-only auth -> `401/403` before upstream relay.
- Missing/invalid nonce on unsafe requests -> `403` before upstream relay.
- Forbidden header/query/body/form/multipart credential or routing material -> `400` before upstream relay.
- Browser-supplied submit `model` or `notifyHook` -> `400` before upstream relay.
- Missing submit idempotency key -> `400`.
- Same idempotency key + different payload hash -> `409`.
- Same idempotency key + same payload hash + completed task record -> replay public MJ task id without second charge.
- Unsupported creative MJ action -> sanitized unsupported error; no legacy fallback.
- Upstream submit failure before the provider accepts a task -> refund pre-consume once and delete the scoped idempotency record so the caller may retry.
- Local persistence, scoped-idempotency completion, or submit-settle failure after upstream success/acceptance -> do not delete the scoped idempotency guard merely to permit retry; preserve local task/idempotency knowledge, leave a durable billing-recovery path when possible, and fail closed rather than allowing a second upstream MJ submit.
- Missing/cross-user fetch or image proxy -> non-leaky not-found style error.
- Image proxy on non-success/no-result task -> error; do not expose upstream/private state.
- Terminal failure/success poll -> only CAS winner mutates billing; CAS losers skip refund/settle.

### 5. Good/Base/Bad Cases

- Good: browser submits `POST /creative/relay/v1/mj/submit/imagine` with nonce and `Idempotency-Key`; backend infers `mj_imagine`, selects channel/key server-side, stores upstream id and selected key, completes `mj.submit.imagine`, returns `{code:1,result:"task_xxx"}`, and polling later exposes `/creative/relay/v1/mj/image/task_xxx` only to the owner.
- Base: `GET /creative/relay/v1/mj/task/task_xxx/fetch` for same user returns public MJ task DTO; another user receives non-leaky not-found.
- Bad: mounting legacy `registerMjRouterGroup()` under `/creative`, trusting body `model`/`notifyHook`, calling upstream with browser `Authorization`, returning upstream MJ id to browser as the canonical task id, polling with current `channel.Key` instead of stored selected key, or returning `/v1/videos/...` as an MJ image URL.

### 6. Tests Required

- Route/middleware tests for canonical MJ paths, browser-session enforcement, same-origin/nonce, forbidden fields, browser model/notifyHook rejection, and unsupported action failure.
- Idempotency tests for missing key, replay, conflict, action-scope separation, and cleanup on downstream/session-broker reject.
- Submit/adaptor tests proving server-derived `mj_imagine`, public task id response, upstream `mj-api-secret`, no upstream `Authorization`, selected key/task persistence, and no credential leakage.
- Fetch/list/image tests for same-user success, cross-user rejection, missing task, owner-scoped image proxy, private/no-store headers, SSRF validation, and no upstream key/channel/billing leakage.
- Polling tests proving stored-key affinity, MJ no-video-proxy fallback, CAS single-winner failure refund for wallet/subscription, and CAS single-winner success settlement.
- Run targeted Go tests for `middleware`, `router`, `controller`, `service`, `model`, `relay/constant`, `relay/common`, and `relay/channel/task/mj`.

### 7. Wrong vs Correct

#### Wrong

```text
POST /creative/relay/v1/mj/submit/imagine with {"model":"mj_other","notifyHook":"https://..."} -> accepted
MJ adaptor -> Authorization: Bearer <selected-key>
Submit response -> {"result":"upstream_mj_id"}
Poll success without imageUrl -> /v1/videos/task_xxx/content
```

#### Correct

```text
POST /creative/relay/v1/mj/submit/imagine -> server infers mj_imagine; model/notifyHook are forbidden
MJ adaptor -> mj-api-secret: <selected-key>; Authorization is removed
Submit response -> {"result":"task_xxx"}
Poll success without imageUrl -> no MJ image proxy URL until an image URL exists
```
