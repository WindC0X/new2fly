# Creative Suno Relay Follow-up — Design

## Architecture decision

Implement Suno as a first-class embedded creative relay under the existing `/creative/relay/v1` browser-session gateway. Do **not** expose the legacy token-auth `/suno` routes directly under `/creative`.

Canonical contract:

```text
POST /creative/relay/v1/suno/submit/:action   # action = music | lyrics
GET  /creative/relay/v1/suno/fetch/:id        # owner-scoped task status/result
POST /creative/relay/v1/suno/fetch            # optional batch fetch compatibility
```

Opentu uses these as provider-transport paths relative to session-broker base URL `/creative/relay/v1`:

```text
/suno/submit/music
/suno/submit/lyrics
/suno/fetch/{taskId}
```

## Backend boundary

### Route stack

Add a `/creative/relay/v1/suno` group in `new-api/router/web-router.go` with the same outer creative relay protections already used by chat/images/videos:

- `CreativeSessionHeaderBridge`, `UserAuth`
- `CreativeRequireSameOrigin`
- `CreativeRequireNonce` for unsafe methods
- `CreativeRejectForbiddenRelayFields`
- creative session-broker token setup
- `middleware.Distribute()`

The group must not accept access-token/API-key auth directly. Browser-supplied upstream credentials/routing overrides must be rejected before channel distribution.

### Server-side model/group inference

Suno submit bodies may not include `model`. The server must infer a safe model from the route action:

```text
music  -> suno_music
lyrics -> suno_lyrics
```

That inferred model must be used for creative model availability and group selection before channel distribution. Browser-provided `model`, `provider`, `baseUrl`, `channel`, selected key, owner, or Authorization material remains forbidden.

Recommended implementation shape:

- introduce a small creative Suno route helper/middleware that validates `:action`, derives the model name, and makes it available to the creative session broker / distributor path;
- keep `middleware.Distribute()` responsible for actual channel selection after the creative broker has established the correct server-side group context.

### Idempotency

Submit must require a durable browser request id, using `Idempotency-Key` or `X-Creative-Request-Id`. Scope it by user and action:

```text
suno.submit.music
suno.submit.lyrics
```

The existing scoped idempotency storage (`CreativeVideoIdempotency`) can be reused behind Suno-specific wrappers for the MVP because it is already unique on `user + scope + request`. The implementation should avoid widening the default video scope or breaking existing video replay behavior.

Success response must remain buffered until all of the following succeed:

1. upstream submit succeeded and produced an upstream task id;
2. local `Task` row is inserted with public task id and upstream task id split;
3. selected channel/key affinity is stored in `Task.PrivateData.Key`;
4. scoped idempotency record is completed;
5. billing settlement/logging succeeds or is at least attempted with existing task semantics.

If any post-upstream local step fails, refund pre-consumed quota and delete the scoped idempotency record so a retry is not stuck behind a stale pending record.

## Polling, settlement, and affinity

Existing Suno polling must be hardened before enabling embedded Suno:

- Use `Task.PrivateData.Key` when polling if present; do not use a freshly resolved multi-key channel pool value.
- Poll by upstream IDs (`Task.GetUpstreamTaskID()`), but map responses back to the public task rows safely.
- Terminal status transitions (`SUCCESS`, `FAILURE`) must use `Task.UpdateWithStatus(previousStatus)` or an equivalent CAS guard.
- Only the CAS winner may refund or settle. CAS losers must not double-refund or double-settle.
- Failure refund must work for wallet and subscription/session-broker billing contexts.
- Success must not accidentally charge twice; if Suno remains per-call billing after submit, record that explicitly in `Task.PrivateData.BillingContext.PerCallBilling` and skip completion delta settlement unless a future Suno adaptor supplies actual usage.

## Frontend boundary

### Session-broker audio transport

`opentu/packages/drawnix/src/services/audio-api-service.ts` must allow an empty API key only when `providerContext.authType === "session-broker"`. Direct/non-session-broker providers must still fail before fetch if the API key is empty.

Provider transport already owns same-origin credentials, CSRF/nonce headers, and credential stripping for `session-broker`; audio service should not add Authorization or upstream key headers manually.

### No fallback to direct provider

When embedded session-broker Suno submit/fetch returns unsupported backend statuses such as `404`, `405`, or `501`, the frontend should surface a sanitized unsupported-backend error and must not retry a direct legacy provider path.

### Stable idempotency

For generated audio tasks, opentu should send a stable idempotency header scoped to the local generation attempt. Preferred format:

```text
Idempotency-Key: opentu-audio-<localTaskId or generated request id>
```

The key must be reused for retries of the same local user action and must not include prompt text or credentials.

## Security contract

Reject or strip these from body, query, headers, nested JSON keys, form fields, and multipart file part names before upstream relay:

- `Authorization`, `Proxy-Authorization`, `X-API-Key`, `apiKey`, `api_key`
- `baseUrl`, `base_url`, upstream URL overrides
- `provider`, `providerOverride`, `channel`, selected key/fingerprint
- `userId`, `owner`, or other ownership override material

Fetch/status must use `user_id + task_id`; cross-user access should return non-leaky not-found or equivalent safe error.

## Compatibility and rollout

- Keep existing legacy `/suno` token routes unchanged.
- Add creative routes only under `/creative/relay/v1/suno`.
- Preserve existing video creative idempotency behavior while reusing/generalizing scoped idempotency helpers.
- If an explicit feature gate is added, it must be fail-closed by default and tests must enable it. If no new gate is added, route safety depends on the session-broker guards and tests.

## Validation expectations

Backend:

- route/middleware tests for canonical Suno paths, nonce/same-origin/session, forbidden fields, unsupported/double-version paths;
- idempotency tests for replay, conflict, scope-by-action, cleanup on session-broker/distributor rejection;
- submit tests for pre-consume, task persistence, selected key storage, upstream failure refund;
- fetch tests for same-user success, cross-user rejection, missing task;
- polling tests for stored key affinity and CAS single-winner refund/settlement.

Frontend:

- audio service tests for session-broker empty-key success and direct empty-key rejection;
- submit/fetch path tests for `/creative/relay/v1/suno/...`;
- tests proving no upstream Authorization/API-key/baseUrl/provider/channel leakage;
- unsupported backend errors do not trigger direct fallback.
