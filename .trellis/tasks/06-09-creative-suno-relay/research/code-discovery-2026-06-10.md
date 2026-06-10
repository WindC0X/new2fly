# Creative Suno Relay Code Discovery — 2026-06-10

## Scope

Evidence pass for `06-09-creative-suno-relay` before implementation. ACE search was unavailable due quota; codegraph was not initialized for sibling repos, so this pass used `fast-context` and focused `rg/sed` inspection.

## new-api backend findings

### Existing public legacy Suno routes

- `new-api/router/relay-router.go` mounts legacy token-auth routes under `/suno`:
  - `POST /suno/submit/:action` -> `controller.RelayTask`
  - `POST /suno/fetch` -> `controller.RelayTaskFetch`
  - `GET /suno/fetch/:id` -> `controller.RelayTaskFetch`
- These routes use `middleware.TokenAuth(), middleware.Distribute()` and therefore are not safe to expose directly to embedded `/creative` browser users.

### Existing creative relay framework

- `new-api/router/web-router.go` mounts `/creative/relay/v1` with:
  - `CreativeSessionHeaderBridge`, `UserAuth`
  - `CreativeRequireSameOrigin`
  - `CreativeRequireNonce`
  - `CreativeRejectForbiddenRelayFields`
- Existing creative routes include chat/images and video. Video is currently under `/creative/relay/v1/videos` with idempotency and a fail-closed env gate.

### Existing task relay behavior

- `controller.RelayTask` delegates submit to `relay.RelayTaskSubmit`, buffers the upstream success response, inserts `model.Task`, completes scoped idempotency, settles billing, logs consumption, and only then flushes the buffered response.
- On submit error it refunds via `relayInfo.Billing.Refund(c)` and deletes the current creative idempotency record when an idempotency key was used.
- `relay.RelayTaskFetch` has Suno response builders for `RelayModeSunoFetch` and `RelayModeSunoFetchByID` that query tasks by `user_id + task_id`, which is the right owner boundary for embedded fetch.

### Suno distributor/model behavior

- `middleware.Distribute.getModelRequest` has a `/suno/` branch:
  - derives relay mode with `Path2RelaySuno(method, path)`;
  - for submit, sets `modelRequest.Model = service.CoverTaskActionToModelName(TaskPlatformSuno, c.Param("action"))`, e.g. `suno_music`;
  - sets `platform = suno` and `relay_mode`.
- Because `CreativeRelaySessionBroker` runs before `Distribute`, a no-model Suno body currently leaves the broker group at the user's default group. The creative Suno wrapper should server-side infer the model/action before or during session-broker group selection so group selection cannot be bypassed or accidentally under-selected.

### Suno adaptor and polling gap

- `relay/channel/task/suno/adaptor.go` validates `music` and `lyrics`, defaults `mv` for music, submits to upstream `/suno/submit/<ACTION>`, and returns the public `info.PublicTaskID` to the client while returning the upstream task ID to backend persistence.
- `service.UpdateSunoTasks` currently batch polls with `adaptor.FetchTask(*ch.BaseURL, ch.Key, { ids: taskIds }, proxy)` and updates tasks via `task.Update()`.
- Unlike video polling, Suno polling currently does not use `Task.PrivateData.Key`, does not CAS-guard terminal transitions, and refunds inside the update loop without a single-winner guard. This is the primary backend correctness gap for this task.

### Existing reusable primitives

- `model.Task.PrivateData` already supports:
  - selected key affinity: `Key`
  - public/upstream split: `UpstreamTaskID`
  - scoped idempotency key: `IdempotencyKey`
  - billing source/subscription/token/context fields
- `model.CreativeVideoIdempotency` is already scoped by `user + scope + request`. The table name is video-specific, but the shape is generic enough for a low-risk Suno submit implementation if wrapped with Suno-specific scopes.
- `model.Task.UpdateWithStatus(fromStatus)` provides CAS guarded updates. `service.updateVideoSingleTask` demonstrates the required terminal success/failure single-winner settlement/refund shape.

## opentu frontend findings

### Existing audio adapter behavior

- `packages/drawnix/src/services/audio-api-service.ts` implements Suno-style submit/fetch polling:
  - submit path defaults to `/suno/submit/music` or `/suno/submit/lyrics`;
  - poll path defaults to `/suno/fetch/{taskId}`;
  - it uses `providerTransport.send` with a provider context resolved from route/model binding.
- Current `submitAudioGeneration` and `queryAudioTask` reject when `providerContext.apiKey` is empty. This is wrong for embedded session-broker, whose contract intentionally uses `apiKey: ""` and auth type `session-broker`.

### Existing session-broker transport behavior

- `provider-transport.ts` treats `authType === "session-broker"` specially:
  - canonical base URL must be `/creative/relay/v1`;
  - request paths must be relative;
  - credentials are `same-origin`;
  - creative CSRF/nonce headers are applied;
  - upstream Authorization/API-key/provider/channel/baseUrl routing material is stripped or rejected.
- `creative-session-broker.ts` already bootstraps the managed provider profile with `baseUrl: /creative/relay/v1`, `apiKey: ""`, `authType: "session-broker"`, and route types including `audio`.

## Planning consequences

1. Canonical Suno creative paths should be relative to `/creative/relay/v1`:
   - `POST /suno/submit/:action`
   - `GET /suno/fetch/:id`
   - optional backend compatibility: `POST /suno/fetch`
2. Backend must not directly mount legacy `/suno` with token auth; it needs a creative wrapper reusing session/same-origin/nonce/forbidden-field guards, session-broker token setup, and distributor.
3. Backend must infer `suno_<action>` server-side for group/channel selection even when the browser body has no `model`.
4. Backend polling must use stored selected key affinity and CAS-guarded terminal refund/settlement before embedded Suno is considered enabled.
5. Frontend audio service must allow empty API key only for `session-broker` and must add tests proving no credential leakage and no direct fallback.
