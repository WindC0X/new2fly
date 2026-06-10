# Creative Async Video Relay Design

## 1. Scope and non-goals

Scope: define the first embedded async media relay contract for video only, covering submit, status fetch, content fetch, session-broker auth, forbidden material controls, idempotency, billing/refund CAS, ownership, and channel/key affinity.

This child task is the first implementation target for async-video only. Suno and MJ remain separate follow-up children and must not be treated as enabled or fixed by this plan.

Non-goals:

- Do not change normal API-token video routes or make Opentu depend on direct upstream credentials.
- Do not mount unsafe creative video routes until tests prove async billing, ownership, validation, and key-affinity controls.
- Do not implement Suno/MJ or broaden the common media relay contract beyond what async-video needs.

Implementation remains blocked until `task.py start` changes this task from `planning` to `in_progress`.

## 2. Canonical embedded video path contract

Canonical browser-facing contract under the creative session-broker base URL:

| Operation | Method + path | Notes |
| --- | --- | --- |
| Submit video task | `POST /creative/relay/v1/videos` | Requires browser session, same-origin, CSRF/nonce, forbidden-material validation, and a durable idempotency request id. |
| Fetch task status/result metadata | `GET /creative/relay/v1/videos/:taskId` | Requires browser session and owner check. Nonce is skipped per existing GET policy, but query/header override material is still rejected. |
| Fetch generated content | `GET /creative/relay/v1/videos/:taskId/content` | Requires browser session and owner check. Streams/proxies content without leaking upstream credentials or channel details. |

Explicitly non-canonical for embedded Opentu:

- No public `/creative/relay/v1/v1/videos` double-version path.
- No direct fallback to normal `/v1/videos`, `/v1/video/generations`, or upstream provider URLs.
- Unsupported aliases must fail closed unless backend tests explicitly normalize them before any auth, billing, or upstream call can be bypassed.

The backend may internally adapt the canonical creative path to existing video relay/task modes, but the public embedded contract remains the three paths above.

## 3. new-api backend boundaries and middleware order

The creative video routes must live inside the existing creative relay boundary and use browser-session authority, not API-token authority.

Required request order:

1. Match only the canonical creative video routes while the feature gate is enabled.
2. Establish browser session/user identity and same-origin expectations.
3. Apply CSRF/nonce validation for unsafe methods; keep GET/HEAD/OPTIONS nonce behavior consistent with existing creative middleware while still requiring session and origin policy.
4. Reject forbidden headers and query parameters for every method.
5. For unsafe methods, run content-type-aware body validation and restore the body for downstream forwarding.
6. Resolve the server-side media action and safe video model before group/channel selection. A body `model` may be used only as a whitelisted video model selector; provider/base URL/channel/key routing metadata is never trusted from the browser.
7. Run the session-broker group/channel/key selection using the server-side action/model context.
8. Submit handler persists task, billing context, idempotency request id, owner, upstream task id, and selected channel/key affinity.
9. Status/content handlers load the persisted task by owner and task id, then use the stored channel/key affinity; they must not perform a fresh random channel/key selection.

Any validation, session, ownership, or feature-gate failure must stop before upstream relay, billing mutation, or credential lookup.

## 4. opentu embedded client boundaries

Opentu embedded mode must use the session-broker profile with base URL `/creative/relay/v1`, empty browser `apiKey`, and same-origin credentials.

Required client behavior:

- Resolve video submit/status/content through the video route contract: `/videos`, `/videos/:taskId`, and `/videos/:taskId/content` relative to the session-broker base URL.
- Allow an empty browser `apiKey` only when `authType === "session-broker"`; non-session-broker transports keep their existing direct-key requirements.
- Strip or refuse upstream `Authorization`, `apiKey`, `baseUrl`, `provider`, channel/group, and model override query/header material before transport.
- Add only creative session auth material from bootstrap, including CSRF/nonce for unsafe methods, plus a stable idempotency request id for submit.
- Never fall back to direct upstream video APIs when the creative video contract is disabled or unsupported; surface a sanitized unsupported-backend error instead.

## 5. Forbidden material validation matrix for JSON, multipart, query, and headers

Validation must be content-type aware and must not break body forwarding.

| Surface | Applies to | Required behavior |
| --- | --- | --- |
| Headers | All routes | Reject upstream credential/routing headers such as `Authorization`, `Proxy-Authorization`, `X-API-Key`, provider API-key aliases, base URL aliases, channel/group aliases, and model override headers. Allow only normal browser/session headers, content headers, creative CSRF/nonce headers, and idempotency/request-id headers. |
| Query | All routes | Reject `apiKey`, `api_key`, `key`, `token`, `access_token`, `baseUrl`, `base_url`, `provider`, `channel`, `channelId`, `group`, `model`, `endpoint`, `url`, `proxy`, and equivalent override aliases. Task id must come from the path, not query override material. |
| JSON body | Unsafe submit routes | Recursively reject credential/routing fields such as `authorization`, API-key aliases, base URL aliases, provider/endpoint/proxy fields, channel/group fields, and arbitrary nested upstream header bags. Top-level `model` is allowed only as a whitelisted video model selector for submit; nested/provider-routing `model` overrides are rejected. Body must be re-readable after validation. |
| `multipart/form-data` | Unsafe submit routes | Validate every non-file field name against the same forbidden set. Reject file or form parts named as credential/routing fields. Allow expected media/file fields and a whitelisted top-level video `model` selector only when the backend can bind it to the server-side action/model context. Preserve the original body for downstream relay via a replayable buffer or temp-file-backed body. |

GET status/content routes have no body contract; they still enforce header/query rejection and owner checks.

## 6. Async lifecycle, idempotency, billing/refund CAS

Submit lifecycle:

1. Opentu sends a durable request id, preferably `Idempotency-Key` or `X-Creative-Request-Id`, scoped to one user action.
2. Backend namespaces idempotency by user, route/action, request id, and sanitized payload hash.
3. Repeating the same request returns the existing task response. Reusing the same request id with a different payload fails with a non-leaky conflict.
4. Missing request id fails closed unless the implementation explicitly documents and tests a no-idempotency policy plus frontend duplicate-submit prevention.
5. Initial charge/task creation happens once for the idempotent submit.
6. If upstream submit fails before an accepted task is persisted, refund once and return a sanitized failure.
7. If upstream accepts a task, persist owner, billing context, upstream task id, safe model/action, idempotency metadata, and channel/key affinity.

Status/content lifecycle:

- Poll/update uses CAS from the current task status to the next status.
- Exactly one CAS winner may settle success, recalculate charge, or refund failure.
- CAS losers reload stored state and must not double-settle or double-refund.
- Success settles once, terminal failure refunds once, and repeated GET retries are read-idempotent.
- Content fetch may trigger or depend on status synchronization, but all terminal billing changes remain CAS guarded.

## 7. Ownership and non-leaky errors

Status, result, and content access are owner-scoped by the creative browser-session user id.

- Cross-user task/status/content access returns a generic not-found or equivalent non-leaky response.
- Responses and logs must not expose upstream API keys, base URLs, provider auth headers, selected channel id/key, object keys, or unrelated user/task existence.
- Upstream errors are mapped to sanitized client errors. Detailed upstream diagnostics can be logged only after secret scrubbing.
- Content responses should use private cache/no-sniff style headers appropriate for browser-session protected media.

## 8. Channel/key affinity

The selected channel/key is part of task state, not a per-poll decision.

- Submit records the selected channel id and key or an equivalent opaque affinity reference in private task data.
- Status/content polling uses the stored affinity to contact the provider.
- If stored affinity is missing, revoked, or unusable, the route fails closed with a sanitized recoverable error; it must not silently select a fresh random key.
- Tests must prove polling/content uses the original selected key and that concurrent updates do not create multiple terminal billing transitions.

## 9. Feature gating and unsupported-route fail-safe behavior

Creative video relay remains disabled until this child task has passing backend and Opentu tests.

- A single backend gate should protect submit/status/content together.
- Disabled or unsupported video routes return a safe 404/405/501-style response before upstream relay or billing mutation.
- Opentu treats unsupported session-broker video as a backend capability error and does not retry through direct API-key transport.
- Double-version, legacy video-generation, Suno, and MJ paths remain unsupported unless a later child task designs and tests them.
- Rollback can disable the gate without changing normal API-token video behavior.

## 10. Test strategy

Red tests must be written before implementation after this task is started.

Backend tests must cover:

- Canonical path acceptance and unsupported alias rejection.
- Browser session, same-origin, CSRF/nonce, and GET nonce policy.
- Forbidden header/query/JSON/multipart material, including safe body re-read/forwarding.
- Submit/status/content async flow, durable idempotency, and repeated retry behavior.
- Submit failure refund once, terminal failure refund once, success settle once, and concurrent CAS with exactly one winning terminal transition.
- Owner-scoped status/content access and sanitized errors.
- Stored channel/key affinity across submit, poll, and content fetch.

Opentu tests must cover:

- Session-broker video route resolution to `/videos` paths.
- Empty browser `apiKey` allowed only for session-broker video.
- No upstream `Authorization`, `apiKey`, `baseUrl`, `provider`, model override query/header, or channel override leakage.
- Stable idempotency request id on submit.
- Unsupported backend routes fail safely without direct fallback.
