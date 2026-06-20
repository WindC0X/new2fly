# Creative Duomi / GrsAI live image adapter

## Goal

Enable real asynchronous Creative image generation for Duomi and GrsAI through `new-api` Channels and Creative Model Bindings, while preserving the embedded OpenTU contract: users select safe logical Creative models and typed parameters; provider credentials, channel routing, raw provider URLs, callbacks, and billing authority stay entirely server-side.

## User value

- Admins can configure Duomi / GrsAI image models once in `new-api` Channels + Creative Model Bindings.
- Embedded OpenTU users can generate images through those configured models without entering API keys or selecting provider channels.
- Different image providers and models can expose different parameter controls from backend schemas, so future providers can be added without hardcoding OpenTU UI defaults.

## Confirmed facts

- Current Phase 1 production only supports mock Creative image tasks; Duomi and GrsAI live manifests are intentionally marked future/blocked.
- OpenTU embedded mode already consumes `/creative/api/models` catalog entries and renders runtime `parameterSchema` into image model parameters.
- `creative.model_bindings` already separates:
  - `id`: executable logical Creative model id submitted by OpenTU.
  - `providerModelId`: upstream model id sent to provider.
  - `priceModelId`: billing model id used for pricing/policy; not UI parameter authority.
  - `channelId`: locked `new-api` Channel for provider key/base URL/model support.
- Channel keys/base URLs are configured in `new-api` Channels, not OpenTU.
- Provider contract differences are documented in `research/provider-api-contracts.md`.
- Current security/billing contracts are documented in `.trellis/spec/backend/creative-backend-security-boundary.md`, `.trellis/spec/backend/creative-async-task-billing-consistency.md`, and `.trellis/spec/frontend/creative-embedded-release-artifact.md`.

## Requirements

### R1. Provider configuration boundary

- Provider API keys, base URLs, model lists, and model mappings must remain in `new-api` Channels.
- Creative Model Bindings must reference a locked channel and provider model; no provider key/base URL/header/callback/webhook fields may be stored in binding JSON or exposed to OpenTU.
- Admin UI must make this configuration path clear: channel first, then model binding, then defaults/recommended model policy.

### R2. Live adapter support

- Implement backend-owned live image adapters for:
  - Duomi `gpt-image-2` via `POST /v1/images/generations?async=true` + `GET /v1/tasks/{id}`.
  - GrsAI `gpt-image-2` / `gpt-image-2-vip` via `POST /v1/api/generate` + `GET /v1/api/result?id={id}`.
  - GrsAI `nano-banana` family via the same GrsAI generate/result endpoints with nano-specific parameter schema.
- Adapters must force async mode server-side. Browser/user parameters must not choose sync/stream/callback behavior.
- Adapters must use selected-key/channel affinity from submit through poll/fetch.

### R3. Parameter schema strategy

- Backend manifests/templates must expose provider/model-specific `parameterSchema`.
- OpenTU sends only `model=<bindingId>`, `prompt`, optional allowed reference images if supported, and typed `userParams` from schema.
- Backend validates `userParams` against the binding schema before provider submission.
- Different provider/model bindings may have different schemas even when they share an upstream model family.
- `quality` label should be standardized as `质量` in UI/schema copy; avoid “画质” unless provider docs explicitly define it.

### R4. Async task lifecycle and idempotency

- Submit must be idempotent and must not flush success until:
  1. provider accepted and returned an upstream task id;
  2. local `Task` row was inserted;
  3. scoped idempotency was completed;
  4. submit billing settle completed or a durable outbox was queued.
- If provider accepted but local persistence/finalization fails, the idempotency guard must remain so retry cannot create a second upstream task.
- Public task id remains a local `task_*` id; upstream provider id is stored privately.

### R5. Billing and refunds

- Live image task submit must integrate with existing pre-consume/settle billing semantics or an equivalent durable billing session.
- Terminal success/failure must use status CAS and enqueue/process exactly one terminal settle or refund outbox.
- Channel missing, provider polling error that becomes terminal, missing selected key, or missing upstream task id must fail closed and refund exactly once.

### R6. Result handling and privacy

- Public task fetch DTO must remain owner-scoped and route-specific.
- Public DTO must not expose `channel_id`, raw `PrivateData`, `quota`, selected key, provider base URL, provider task URL, raw provider result URL, signed URL query, or raw provider response body.
- Result content must be returned through owned `/creative/relay/v1/images/tasks/:task_id/content` URLs or a safe asset-proxy/storage path, not raw provider URLs.
- Content fetch must remain owner-scoped, `private, no-store`, and SSRF-safe.

### R7. Admin enablement and rollout

- Live manifests must become enableable only after live transport, parser, billing, polling, privacy, and regression tests exist.
- Live bindings should support canary groups and disabled-by-default rollout.
- Staging/smoke must be possible without calling production providers unless explicit provider credentials and authorization are supplied.
- Production enablement/deployment remains out of scope until separately authorized.

### R8. Extensibility

- The implementation must add a small provider-adapter abstraction so future image providers can be added with:
  - manifest/preset registration;
  - parameter template/schema;
  - submit mapper;
  - poll parser;
  - result URL extractor;
  - tests/fixtures.
- Avoid baking Duomi/GrsAI-specific branches directly into OpenTU.

## Acceptance criteria

- [ ] `duomi_image_live` and `grsai_image_live` can be saved/enabled only when valid channel, supported provider model, schema, canary group, and live-adapter gates pass.
- [ ] `/creative/api/models` exposes enabled live image bindings only to matching user groups and includes correct runtime `parameterSchema`.
- [ ] Embedded OpenTU renders provider/model-specific controls from backend schema and submits typed `userParams` without provider credentials or routing fields.
- [ ] Creative image task submit calls the correct provider adapter and creates a local pending/running `creative_image` task with private upstream id and selected-key affinity.
- [ ] Idempotent replay of the same request returns the same task; same key with different payload returns conflict; accepted-but-local-failure does not resubmit provider work.
- [ ] Poll/fetch updates terminal state with CAS and durable billing settle/refund exactly once.
- [ ] Fetch/content routes remain owner-scoped, platform-scoped, no-store, and do not leak raw provider internals.
- [ ] Duomi and GrsAI parser tests cover running, succeeded, failed, violation/error, malformed, missing id, missing result, and sensitive result/url redaction cases.
- [ ] Backend tests cover binding validation, channel lock/support, forbidden `userParams`, idempotency, billing outbox, DTO privacy, and sync-route rejection.
- [ ] Frontend/admin tests or type checks cover live manifest labels/templates, channel-backed draft generation, schema rendering expectations, and no generic channel DTO/key exposure.
- [ ] Staging smoke verifies model catalog + parameter panel + mock/no-provider dry-run path; live provider smoke is documented and run only with explicit credentials/authorization.
- [ ] Dynamic workflow final audit is run after implementation and staging checks, assessing goal attainment and newly introduced problems, not merely whether listed fixes were applied.

## Out of scope for this task

- Direct OpenTU provider-key configuration for Duomi/GrsAI.
- Letting users choose arbitrary `new-api` channel IDs from OpenTU.
- Provider callbacks/webhooks/notify hooks.
- Synchronous/streaming image generation surfaces for these bindings.
- Production deployment or live provider-cost smoke without explicit later authorization.
- Enabling Duomi “upcoming” nano-banana endpoints until Duomi docs show a ready live contract.
