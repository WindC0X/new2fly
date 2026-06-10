# Creative MJ Relay Design

## Summary

Creative MJ should be implemented as a browser-session async task relay, not as a direct remount of legacy token-auth `/mj`. The backend should reuse the generic `model.Task` / `RelayTask` / `BillingSession` async infrastructure by adding an MJ task adaptor, because that path already has the properties the audit requires: scoped idempotency, pre-consume + settle/refund, task private data, selected-key persistence, and CAS terminal updates. The legacy `model.Midjourney` flow remains available for token-auth `/mj` but is not the safety foundation for embedded `/creative`.

## Architecture and Boundaries

### Backend boundary

- New canonical route group: `/creative/relay/v1/mj` in `new-api/router/web-router.go`.
- Creative middleware chain remains the outer boundary:
  - route tag + body storage cleanup + system performance check
  - `CreativeSessionHeaderBridge()` + `UserAuth()`
  - `CreativeRequireSameOrigin()`
  - `CreativeRequireNonce()`
  - `CreativeRejectForbiddenRelayFields()`
  - MJ-specific guard(s)
  - `CreativeRelaySessionBroker()` + `Distribute()`
  - creative MJ handlers
- Do not call `registerMjRouterGroup()` inside the creative router. Legacy handlers are token-auth oriented and include an image proxy that is not owner-scoped.

### Backend task model

Use `model.Task` for creative MJ tasks:

- `Platform`: either `constant.TaskPlatformMidjourney` or the selected channel type with an MJ adaptor case; choose one consistently and ensure `DispatchPlatformUpdate` polls it.
- `TaskID`: public new-api task id returned to Opentu as the MJ submit `result`.
- `PrivateData.UpstreamTaskID`: upstream MJ id returned by `/mj/submit/imagine`.
- `PrivateData.Key`: selected upstream key at submit time.
- `PrivateData.BillingSource`, `SubscriptionId`, `TokenId`, and `BillingContext`: existing async billing fields.
- `Data`: sanitized upstream task/status JSON enough to reconstruct an MJ-style fetch response.
- `PrivateData.ResultURL`: upstream image URL or owner-scoped proxy URL after terminal success.

Do not store selected keys in any public DTO. If the implementation introduces an MJ-specific private data struct, it must be omitted from browser JSON and follow the existing `TaskPrivateData` secrecy pattern.

### Frontend boundary

- The session-broker provider context remains `baseUrl: "/creative/relay/v1"`, `authType: "session-broker"`, `apiKey: ""`.
- The MJ adapter must preserve the canonical base for session-broker mode. Its current `normalizeBaseUrl()` trims a trailing `/v1`; that is safe for some legacy providers but wrong for `/creative/relay/v1` because the provider transport asserts the canonical base.
- Dedicated adapter paths stay relative to the session-broker base:
  - submit path `/mj/submit/imagine`
  - poll path `/mj/task/{taskId}/fetch`

## Contracts

### Submit: `POST /creative/relay/v1/mj/submit/imagine`

Request body accepted from Opentu:

```json
{
  "botType": "MID_JOURNEY",
  "prompt": "...",
  "base64Array": ["..."]
}
```

Rules:

- Server derives `action=IMAGINE` and `model=mj_imagine` from the route.
- Reject browser-supplied `model`, `provider`, `baseUrl`, `channel`, `group`, selected key fields, owner/user override fields, `Authorization`, API keys, and `notifyHook`.
- Require `Idempotency-Key` / `X-Creative-Request-Id`.
- Prepare scoped idempotency (`mj.submit.imagine`) using payload hash before distribution/upstream call.
- Relay upstream to selected channel `/mj/submit/imagine` with the selected server key only.
- For successful upstream codes (`1`, and compatible queued/existing codes if preserved), create/complete the local task before flushing the response.
- Return an MJ-compatible submit response where `result` is the public new-api task id, not the upstream MJ id.

### Fetch: `GET /creative/relay/v1/mj/task/:task_id/fetch`

Rules:

- Load local task by `user_id + public task_id`.
- Return MJ-compatible task JSON from local task state and sanitized `Data`:
  - `id`: public task id
  - `status`, `progress`, `failReason`, `imageUrl`, `imageUrls`, `videoUrl` if applicable
  - no upstream key/channel/base URL/billing/private data
- Cross-user and missing task return the same non-leaky not-found style error.

### Result proxy: `GET /creative/relay/v1/mj/image/:task_id`

Rules:

- Load local task by `user_id + public task_id`.
- Require terminal success and an available image/result URL.
- Preserve SSRF protections from the legacy proxy before fetching an upstream URL.
- Set private/no-store response headers and stream content type from upstream.
- Never use `model.GetByOnlyMJId` in the creative browser path.

### Unsupported legacy actions

For first tranche, these creative paths should return explicit unsupported errors under `/creative` and must not hit legacy routes:

- `/creative/relay/v1/mj/submit/action`
- `/creative/relay/v1/mj/submit/change`
- `/creative/relay/v1/mj/submit/simple-change`
- `/creative/relay/v1/mj/submit/modal`
- `/creative/relay/v1/mj/submit/shorten`
- `/creative/relay/v1/mj/submit/blend`
- `/creative/relay/v1/mj/submit/describe`
- `/creative/relay/v1/mj/submit/edits`
- `/creative/relay/v1/mj/submit/video`
- `/creative/relay/v1/mj/submit/upload-discord-images`
- `/creative/relay/v1/mj/insight-face/swap`
- `/creative/relay/v1/mj/task/:task_id/image-seed`

If a future Opentu caller needs action buttons, implement a second tranche that maps public origin task ids to upstream ids server-side, creates a new public action task, uses origin selected channel/key affinity, and repeats idempotency/billing/ownership tests.

## Data Flow

1. Opentu task queue creates a local image task id.
2. Generation API passes `params.idempotencyKey = "opentu-image-<localTaskId>"` (or `opentu-mj-<localTaskId>`) into image adapter requests.
3. MJ adapter submits to `/mj/submit/imagine` through provider transport with session-broker context.
4. Provider transport builds `/creative/relay/v1/mj/submit/imagine`, injects CSRF/nonce/same-origin credentials, strips upstream credentials/routing/model fields, and sets `Idempotency-Key`.
5. new-api creative guard derives `mj_imagine`, prepares idempotency, and rejects forbidden MJ-specific fields.
6. Creative session broker selects a server-side channel/key for `mj_imagine`.
7. MJ task adaptor pre-consumes through `BillingSession`, sends upstream `/mj/submit/imagine`, receives upstream MJ id, and returns a buffered MJ response with public task id.
8. Local `model.Task` insert stores upstream task id, selected key, billing context, and sanitized data. Idempotency is completed only after insert succeeds.
9. Task polling uses stored selected key and upstream task id to call upstream `/mj/task/list-by-condition` or equivalent fetch, then CAS-updates terminal state and settles/refunds exactly once.
10. Opentu polls `/mj/task/{publicTaskId}/fetch`; backend returns owner-scoped public MJ task status.
11. If image proxying is needed, Opentu consumes owner-scoped `/mj/image/{publicTaskId}` URL or backend returns a private/proxied image URL in fetch response.

## Compatibility Notes

- Existing global `/mj` routes should remain behavior-compatible for token-auth clients.
- The creative MJ response can remain MJ-compatible (`code`, `description`, `result`) while changing `result` to a public local task id. Opentu only uses it as the subsequent poll id.
- Legacy upstream codes `21`/`22` may be normalized similarly to current legacy code, but idempotency replay should prefer the local scoped idempotency record over trusting upstream duplicate behavior.
- Existing `TaskPollingLoop` currently reserves `TaskPlatformMidjourney` as no-op; implementation must either route MJ into the generic per-task polling path or provide an MJ-specific update path with identical CAS/key-affinity/billing semantics.

## Risk Areas

- `normalizeBaseUrl()` in Opentu MJ adapter can accidentally turn `/creative/relay/v1` into `/creative/relay`; tests must catch this.
- Returning upstream MJ ids to the browser would make owner scoping and action mapping harder; return public task ids instead.
- Local insert/idempotency completion errors after upstream success must refund pre-consume and must not leave a reusable idempotency record without a task.
- Legacy image proxy ownership bug must not be copied into creative result proxy.
- Multi-key channels must use stored key; grouping only by channel id is insufficient.
- MJ base64 references can be large; tests should avoid huge fixtures and use minimal base64 strings.

## Rollback / Operational Shape

- New creative MJ routes can be added behind explicit handlers without changing legacy `/mj` route registration.
- If backend support is disabled or incomplete, Opentu must surface sanitized unsupported-backend errors and not fall back to direct provider credentials in embedded mode.
- Reverting frontend session-broker MJ changes should leave legacy direct MJ provider behavior intact outside embedded mode.
