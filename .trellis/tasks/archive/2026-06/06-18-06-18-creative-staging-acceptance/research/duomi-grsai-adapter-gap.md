# Research: Duomi / GrsAI live image adapter gap

- Query: Where should the Duomi and GrsAI image channels be configured, why does Creative Model Bindings only show mock / GrsAI dry-run, and what is missing before live `gpt-image-2` / `nano-banana` adapter support can be claimed?
- Scope: internal
- Date: 2026-06-18

## Findings

### Files found

- `.trellis/workflow.md` — Trellis phase/guardrail source; active research must be persisted as task artifacts before implementation claims.
- `.trellis/tasks/06-18-06-18-creative-staging-acceptance/prd.md` — active staging task scope explicitly excludes real Duomi/GrsAI provider calls and secrets.
- `.trellis/spec/backend/creative-backend-security-boundary.md` — backend contract for Creative binding parser, mock image task route, and sanitized channel-summary picker.
- `.trellis/spec/frontend/creative-embedded-release-artifact.md` — embedded OpenTU contract for managed model catalog and schema-backed `userParams` boundary.
- `/mnt/f/CODE/Project/new-api/service/creative_model_capability.go` — binding config parser/validator, allowlists, channel summary helper, catalog exposure, resolver, dry-run preview, fixture parser.
- `/mnt/f/CODE/Project/new-api/controller/creative_model_bindings.go` — root admin endpoints for bindings validate/dry-run/save and channel summaries.
- `/mnt/f/CODE/Project/new-api/controller/creative_image_tasks.go` — current managed image task submit/fetch/content implementation; mock-only.
- `/mnt/f/CODE/Project/new-api/web/default/src/features/system-settings/models/creative-model-bindings-section.tsx` — admin UI for Creative Model Bindings; only mock and GrsAI dry-run presets.
- `/mnt/f/CODE/Project/new-api/model/channel.go` — channel storage for key/base URL/models/model mapping; confirms credentials live in Channel, not binding JSON.
- `/mnt/f/CODE/Project/new-api/router/web-router.go` and `/mnt/f/CODE/Project/new-api/router/api-router.go` — route registration for Creative relay/image task and admin endpoints.
- `/mnt/f/CODE/Project/new-api/relay/channel/adapter.go`, `/mnt/f/CODE/Project/new-api/relay/relay_adaptor.go`, `/mnt/f/CODE/Project/new-api/relay/relay_task.go` — existing generic task-adaptor contract and billing/polling path that live adapters would need to align with or consciously bypass.
- `/mnt/f/CODE/Project/new-api/controller/creative_test.go`, `/mnt/f/CODE/Project/new-api/service/creative_model_capability_test.go` — tests documenting current no-provider-call and mock/dry-run boundaries.

### Related specs

- `.trellis/spec/backend/creative-backend-security-boundary.md:185-279` — binding parser/admin endpoint/dry-run contract: validate/dry-run only, no provider calls, no secret leakage, dedicated endpoint only.
- `.trellis/spec/backend/creative-backend-security-boundary.md:281-360` — current managed image task route contract: Phase C1 is mock-only and must not call provider relay.
- `.trellis/spec/backend/creative-backend-security-boundary.md:365-425` — channel-summary picker contract: browser sees only sanitized channel identity/model availability.
- `.trellis/spec/frontend/creative-embedded-release-artifact.md:169-229` — embedded OpenTU uses only the managed new-api catalog and must fail closed before network calls when a model is absent/stale.
- `.trellis/spec/frontend/creative-embedded-release-artifact.md:252-322` — schema-backed image `userParams` boundary: OpenTU submits only `model=<bindingId>` plus typed `userParams`; no provider credentials or legacy params.

### External references

- None used. Provider-specific Duomi/GrsAI endpoint paths, auth headers, status/result schemas, rate limits, and billing units were not verified from external docs in this pass and must be confirmed before any live adapter implementation.

### Code patterns

- Credentials/transport data are Channel-owned (`model/channel.go:23-42`, `model/channel.go:491-507`); Creative binding config references `channelId` and safe schema metadata only (`service/creative_model_capability.go:93-112`).
- Binding parser/validator is allowlist-first and forbidden-key-first (`service/creative_model_capability.go:37-70`, `service/creative_model_capability.go:847-933`, `service/creative_model_capability.go:1030-1128`).
- Public catalog/runtime resolver is mock-only today (`service/creative_model_capability.go:264-285`, `service/creative_model_capability.go:441-489`).
- Managed image task route is local mock storage/content, not provider transport (`controller/creative_image_tasks.go:114-199`, `controller/creative_image_tasks.go:241-259`, `controller/creative_image_tasks.go:377-380`).
- Existing generic task infrastructure has the live-provider shape (build request, submit, parse, fetch/poll, billing hooks), but Duomi/GrsAI are not registered (`relay/channel/adapter.go:34-79`, `relay/relay_adaptor.go:136-168`, `relay/relay_task.go:141-258`).

### Current state: what is configurable today

1. **Global Creative adapter preview gates are configurable, but only as preview gates.** Backend reads `creative.adapter.enabled`, `creative.adapter.canary_groups`, and `creative.model_bindings` from the option map (`service/creative_model_capability.go:21-24`, `service/creative_model_capability.go:1310-1326`). The active task PRD says staging acceptance must not make real provider calls (`.trellis/tasks/06-18-06-18-creative-staging-acceptance/prd.md:17-22`).

2. **`creative.model_bindings` can store versioned binding JSON through dedicated root admin endpoints.** The accepted binding shape is `version + bindings[]`, with fields such as `id`, `providerModelId`, `priceModelId`, `modality`, `enabled`, `canaryGroups`, optional `channelId`, `adapterPreset`, `parameterTemplate`, and `parameterSchema` (`service/creative_model_capability.go:93-112`). The admin endpoints validate, dry-run, and persist via `/api/creative/model-bindings*` (`controller/creative_model_bindings.go:13-24`, `controller/creative_model_bindings.go:62-126`), and generic `/api/option` explicitly rejects direct writes to this option key (`controller/option.go:147-152`).

3. **The admin UI can help create binding drafts from sanitized channel summaries, not full Channel DTOs.** The summary endpoint returns only `id`, `name`, `group`, `status`, and `models[]` (`service/creative_model_capability.go:124-137`, `service/creative_model_capability.go:355-420`; `controller/creative_model_bindings.go:26-60`). The UI calls `getCreativeChannelSummaries()` and blocks disabled/no-model/provider-model-mismatch draft creation (`creative-model-bindings-section.tsx:386-424`, `creative-model-bindings-section.tsx:606-663`).

4. **Only two adapter presets are accepted today: mock and GrsAI dry-run.** Backend allowlists contain `mock_image_task` and `grsai_gpt_image_dryrun`; parameter templates contain `mock_gpt_image` and `grsai_gpt_image` (`service/creative_model_capability.go:37-49`). The frontend type is likewise `type SupportedAdapterPreset = 'mock_image_task' | 'grsai_gpt_image_dryrun'` (`creative-model-bindings-section.tsx:149-182`). There is no `duomi_*` preset in the allowlists or frontend picker.

5. **GrsAI is admin dry-run/fixture only.** Backend dry-run for `grsai_gpt_image_dryrun` returns `transport: fixture`, `offline: true`, and a redacted request/response shape; `BuildCreativeModelBindingsDryRun` always returns `NoProviderCall: true` (`service/creative_model_capability.go:671-704`, `service/creative_model_capability.go:706-730`). UI copy says “GrsAI is dry-run/fixture only” and “Live Duomi/GrsAI calls remain blocked until the real adapter phase” (`creative-model-bindings-section.tsx:719-727`, `creative-model-bindings-section.tsx:757-763`).

6. **Only mock bindings become user-visible/executable managed Creative image models.** Stored catalog exposure filters out anything that is not `adapterPreset == "mock_image_task"` and `parameterTemplate == "mock_gpt_image"` (`service/creative_model_capability.go:264-285`). Runtime resolver also rejects any non-mock preset/template with “not available for mock image tasks” (`service/creative_model_capability.go:441-489`). Therefore a saved GrsAI dry-run binding can be validated/dry-run/saved for admin diagnostics, but it will not appear in `/creative/api/models` and will not execute from `/creative/relay/v1/images/tasks`.

7. **Current managed image task submit/fetch/content is mock-only.** `CreativeRelayImageTaskSubmit` validates the binding, creates a local `creative_image` task with `Status: TaskStatusSuccess`, `Quota: 0`, `UpstreamTaskID: "mock_..."`, and a private `mock://...token=secret` URL, then returns a public DTO (`controller/creative_image_tasks.go:114-199`). Content always returns a hard-coded 1x1 PNG (`controller/creative_image_tasks.go:241-259`, `controller/creative_image_tasks.go:377-380`). Reference images are rejected (`controller/creative_image_tasks.go:128-131`).

8. **The sync image route intentionally rejects managed image binding IDs before provider relay.** `/creative/relay/v1/images/generations` installs `CreativeRejectManagedImageBindingSyncRoute()` before `CreativeRelaySessionBroker()` / `Distribute()` (`router/web-router.go:106-108`), and the middleware returns `creative managed image bindings must use /creative/relay/v1/images/tasks` when a managed image binding ID is detected (`controller/creative_image_tasks.go:91-111`).

### What is not configurable today

1. **There is no live Duomi adapter.** No non-test source file outside translations/UI copy contains Duomi runtime code; `duomi` only appears in explanatory UI strings and test forbidden-source assertions, while no `duomi` file/adaptor was found under `relay/channel` or `relay/channel/task`. Backend allowlists reject any `duomi_live_call`-style preset (`service/creative_model_capability_test.go:694-709`).

2. **There is no live GrsAI adapter.** The only GrsAI backend logic is dry-run preview / fixture response summarization (`service/creative_model_capability.go:706-730`, `service/creative_model_capability.go:800-845`). The controller test explicitly asserts the image task source must not contain provider transport references including `Duomi`, `GrsAI`, `duomi`, or `grsai` (`controller/creative_test.go:2330-2353`).

3. **There is no live provider submit/fetch/poll implementation for managed Creative images.** Current image tasks do not call `CreativeRelaySessionBroker`, `Distribute`, `http.NewRequest`, `DoRequest`, channel base URL, API key, or Authorization; tests require that absence (`controller/creative_test.go:1771-1779`, `controller/creative_test.go:2330-2353`). Existing generic task adaptor support has request/body/response/fetch/polling hooks (`relay/channel/adapter.go:34-79`) and `RelayTaskSubmit` handles model mapping, pre-consume, submit, response parsing, and billing adjustment (`relay/relay_task.go:141-258`), but `GetTaskAdaptor` has no Duomi/GrsAI task adaptor registration (`relay/relay_adaptor.go:136-168`).

4. **There is no live billing/refund/settlement path wired for managed image bindings.** Mock image tasks set `Quota: 0` and `PreConsumedQuota: 0` while only storing a billing context for metadata (`controller/creative_image_tasks.go:154-180`). Generic live task flow expects pre-consume before submit and controller-managed refund/settle after provider acceptance (`relay/relay_task.go:141-145`, `relay/relay_task.go:207-258`); polling avoids terminal updates outside the billing path to prevent skipped refunds/settlement (`relay/relay_task.go:560-568`). Managed image task route does not yet participate in that lifecycle.

5. **There is no live parameter mapping for `gpt-image-2` or `nano-banana` families.** Backend currently validates `userParams` against visible schema fields and typed values (`service/creative_model_capability.go:562-605`, `service/creative_model_capability.go:1190-1308`), but only maps mock dry-run keys or GrsAI fixture `aspectRatio` preview (`service/creative_model_capability.go:706-730`). No code maps schema-backed `userParams` into Duomi/GrsAI request payloads, status values, result URLs, error codes, or billing ratios.

### Where configuration should live

1. **Provider credentials and transport config belong in New API Channels.** `model.Channel` stores `Key`, `BaseURL`, `Models`, `Group`, and `ModelMapping` (`model/channel.go:23-42`). It also supplies key selection, model-list parsing, base URL defaults, and model mapping accessors (`model/channel.go:175-205`, `model/channel.go:289-294`, `model/channel.go:491-507`). This is where Duomi/GrsAI API keys, base URLs, channel group, and provider model list should live.

2. **The Creative binding JSON should contain safe server-owned routing metadata, not secrets.** `creative.model_bindings` should reference `channelId`, logical binding `id`, server-side `providerModelId`, `priceModelId`, allowlisted `adapterPreset`, allowlisted `parameterTemplate`, and safe `parameterSchema` (`service/creative_model_capability.go:93-112`). It should never contain API key/base URL/header/callback material; raw parser and forbidden normalizer reject unknown/forbidden keys (`service/creative_model_capability.go:847-933`, `service/creative_model_capability.go:1364-1428`).

3. **OpenTU/browser should receive only the logical model ID and typed user parameters.** Backend catalog keeps `binding.id` as executable model ID while exposing distinct `providerModelId`, `priceModelId`, and visible `parameterSchema` (`service/creative_model_capability.go:508-532`, `service/creative_model_capability.go:535-547`). Frontend spec requires embedded OpenTU to submit the backend catalog ID as `model` and only typed `userParams`, with no provider credentials, URLs, headers, callbacks, channel/provider overrides, or legacy `params` (`.trellis/spec/frontend/creative-embedded-release-artifact.md:271-279`).

4. **Admin UI should remain a binding/schema editor and channel picker, not a credential editor.** The current UI warning is correct: “Provider keys, Base URLs, and upstream credentials are configured in Channels. This page only binds a Creative-visible model ID to a channel, provider model, adapter preset, and safe parameter schema” (`creative-model-bindings-section.tsx:707-717`).

### Why live Duomi/GrsAI adapters are not yet implemented

- **Allowlists:** Backend and frontend only accept `mock_image_task` and `grsai_gpt_image_dryrun`; no Duomi live or GrsAI live preset/template can pass validation (`service/creative_model_capability.go:37-49`, `service/creative_model_capability.go:789-798`, `creative-model-bindings-section.tsx:149-182`).
- **Catalog and resolver gates:** Public catalog and runtime resolver are hard-coded to mock-only (`service/creative_model_capability.go:264-285`, `service/creative_model_capability.go:441-489`).
- **Submit path:** Current managed image submit writes a local success task and mock result; it neither loads a channel key/base URL nor invokes relay distribution/provider HTTP (`controller/creative_image_tasks.go:114-199`).
- **Fetch/content/polling path:** Current fetch returns stored mock DTO and content returns a static PNG; no provider status polling, terminal-state normalization, result proxy/rewrite, or result storage exists (`controller/creative_image_tasks.go:224-259`, `controller/creative_image_tasks.go:340-380`).
- **Routing:** Sync `/images/generations` rejects managed binding IDs before broker/distribute; task route intentionally avoids provider routing (`router/web-router.go:106-114`, `controller/creative_image_tasks.go:91-111`).
- **Billing/refund:** Live adapter support must implement pre-consume, provider-accepted idempotency, submit-failure refund, terminal settlement/refund, and CAS-safe polling; mock route uses quota zero and bypasses the generic live task lifecycle (`controller/creative_image_tasks.go:154-180`, `relay/relay_task.go:141-258`, `relay/relay_task.go:560-568`).
- **Parameter mapping:** Existing schema validation is only a boundary; no Duomi/GrsAI request converter exists for prompt, size/aspect ratio, quality, reference images, output format, provider-specific status, provider result URL, or billing inputs (`service/creative_model_capability.go:562-605`, `service/creative_model_capability.go:706-730`).
- **Provider registration:** No Duomi/GrsAI task adaptor is registered in `GetTaskAdaptor`, and no provider files named Duomi/GrsAI were found under the relay channel/task directories (`relay/relay_adaptor.go:136-168`).

### Recommended phased implementation plan

#### Phase 0 — keep staging honest

- Keep current staging/user messaging explicit: channel credentials can be prepared in Channels, but Creative Model Bindings are mock/dry-run only for now.
- Do not claim that `gpt-image-2` / `nano-banana` Duomi or GrsAI live bindings are configurable in Creative today.
- Acceptance smoke remains no-real-provider: admin page loads, channel summaries are sanitized, validate/dry-run says `noProviderCall=true`, and `/creative/` can submit only the mock binding.

#### Phase 1 — define the live adapter contract without real provider calls

- Add a written design/spec update before code: exact adapter families, supported provider model families (`gpt-image-2`, `nano-banana` variants), request schemas, status model, billing model, idempotency, result proxying, and rollback gates.
- Decide whether managed Creative images should reuse `relay/channel.TaskAdaptor` + `RelayTaskSubmit` or introduce a smaller `CreativeImageProviderAdapter` registry that still reuses channel key selection, billing, logging, and task polling patterns.
- Add only offline/dry-run presets first, e.g. Duomi dry-run and GrsAI dry-run with provider-family-specific parameter schemas. Keep `NoProviderCall=true` mandatory.
- Backend source of truth: extend allowlists in `service/creative_model_capability.go`, not only frontend UI.

#### Phase 2 — fake-transport smoke, still no real provider

- Implement provider-family adapters against an injectable HTTP client / `httptest.Server` / fixture transport. This tests real mapping and task lifecycle while prohibiting external provider domains.
- Add server-side channel lookup by `channelId`; fetch key/base URL from `model.Channel`, never from binding JSON or browser payload.
- Map typed `userParams` into provider request bodies, normalize provider responses into a safe internal task shape, and prove no secrets or signed URLs reach public DTO/logs.
- Wire idempotency and local failure behavior so provider-accepted + local persistence failures keep the idempotency guard, matching the current mock safety invariant.

#### Phase 3 — live canary behind explicit gates

- After provider docs/contracts and staging keys are verified out-of-band, add live presets such as `duomi_gpt_image_live` and `grsai_gpt_image_live` behind a separate live flag plus canary groups, not merely `creative.adapter.enabled`.
- Enable one channel/model/canary group at a time; start with disabled binding drafts, then validate, dry-run, fake-transport smoke, and only then live canary.
- Live task route must pre-consume quota before the provider call, store only sanitized private provider state, poll provider status server-side, settle/refund on terminal state, and expose only owner-scoped `/content` URLs.
- Add kill switch / rollback: hide live presets from catalog immediately, disable channel, refund pending accepted tasks when safe, and preserve no-store/private response behavior.

#### Phase 4 — production readiness

- Add monitoring/audit logs that record actor, binding id, channel id, provider family, status, duration, and quota, but never raw keys/base URLs/headers/provider result bodies.
- Add auto-disable/error-budget behavior for repeated provider failures or billing/polling inconsistencies.
- Only after successful canary should the frontend picker expose live presets; even then, UI remains credential-free.
- If reference-image workflows are needed, implement explicit asset-to-provider image upload/proxy rules; current managed image task route rejects reference images.

### Specific code paths likely needed

- `service/creative_model_capability.go`
  - Add provider-family/preset/template allowlists for Duomi dry-run/fake/live and GrsAI live only when backend contract exists.
  - Separate catalog exposure policy: mock, dry-run, fake, and live should have explicit flags; live should require a live-specific gate and canary.
  - Add binding validation for provider family, channel support, model mapping, schema compatibility, and provider-specific safe parameter templates.
  - Keep `CreativeForbiddenKey`, raw JSON key validation, `ValidateCreativeUserParamsForSchema`, and dry-run redaction as shared boundaries.

- `controller/creative_image_tasks.go`
  - Replace mock-only submit branch with a dispatcher that still fails closed for unsupported presets.
  - Server-side resolve `channelId` → `Channel` → selected key/base URL; do not accept any of this from request JSON.
  - Implement accepted/pending/submitted/succeeded/failed task state transitions rather than immediate `TaskStatusSuccess` for live tasks.
  - Preserve route-specific DTO and private/no-store content endpoint; route must still hide `channelId`, quota internals, private URLs, selected keys, and raw provider payloads.

- `relay/channel/task/...` or a new `service/creative_image_provider_*` package
  - Implement provider-specific request body builders, response parsers, polling fetchers, status mapping, result extraction, redaction, and billing hooks.
  - Prefer reusing existing `TaskAdaptor` interface where practical because it already defines `BuildRequestBody`, `DoResponse`, `FetchTask`, `ParseTaskResult`, and billing adjustment hooks (`relay/channel/adapter.go:34-79`).

- `router/web-router.go` / route middleware
  - Keep `/images/generations` rejection until sync response interception and private URL rewriting are fully implemented.
  - Ensure task route keeps browser-session, same-origin, nonce, forbidden-field, and idempotency guards (`router/web-router.go:90-114`).

- `web/default/src/features/system-settings/models/creative-model-bindings-section.tsx`
  - Add live presets only after backend validates/exposes them.
  - Keep “keys/base URLs live in Channels” copy; never add credential fields to Creative Model Bindings.
  - Add warning badges for dry-run/fake/live and require backend validate + dry-run for exact drafts before save.

- OpenTU embedded code (not modified here)
  - Keep schema-backed requests as `model=<bindingId>` + typed `userParams` only; no legacy `params`, provider overrides, callbacks, or credentials (`.trellis/spec/frontend/creative-embedded-release-artifact.md:271-303`).

### Tests likely needed

- **Service binding tests:** unknown live preset rejected until implemented; supported Duomi/GrsAI dry-run/fake/live presets validate only under correct flags; channel must exist, be enabled, and support `providerModelId`/model mapping; forbidden schema/userParams remain rejected.
- **Admin endpoint tests:** validate/dry-run/save for new presets remain root/dashboard/nonce gated; dry-run for dry/fake modes never contacts providers; no key/base URL/header/signed URL appears in response or logs.
- **Channel-summary tests:** summary endpoint still omits `key`, `base_url`, overrides, settings, `model_mapping`, org IDs, balance/quota, and selected-key material for Duomi/GrsAI channels.
- **Image task controller tests:** live-enabled route uses server-side channel credentials, rejects request-supplied credentials/control aliases, maintains idempotency, handles provider-accepted/local-failure without duplicate upstream tasks, and hides private data in DTOs.
- **Provider adapter tests:** request mapping for `gpt-image-2` and `nano-banana` families, status/result/error parsing, polling transitions, timeout/error handling, response redaction, and SSRF/redirect safeguards.
- **Billing tests:** pre-consume on submit, refund on provider/local failure, settle/supplement/refund on terminal polling result, CAS/idempotency under retry/concurrency, and correct `PriceModelId` usage distinct from `ProviderModelId`.
- **Frontend tests:** picker exposes only backend-supported presets, blocks invalid channel/model drafts, never imports generic Channel DTO or generic `/api/channel`, gates save on exact-draft validate + no-provider-call dry-run, and warns that live calls require live adapter phase.
- **Embedded OpenTU tests:** invalid/stale bindings fail before provider network; schema-backed requests serialize `userParams` and never send legacy `params` or provider credentials.

## Caveats / Not Found

- No external Duomi or GrsAI provider documentation was consulted in this research. Exact endpoint paths, authentication header names, status values, result payloads, rate limits, and billing units must be verified from provider documentation/contracts before implementing live adapters.
- No source file named for Duomi or GrsAI live adapters was found under `/mnt/f/CODE/Project/new-api/relay/channel` or `/mnt/f/CODE/Project/new-api/relay/channel/task`; current GrsAI logic is fixture/dry-run only.
- This research intentionally did not modify OpenTU or new-api code. It records a gap analysis and implementation plan only.
- Current staging acceptance scope explicitly says “No real Duomi/GrsAI provider calls,” so any live canary belongs to a later task/design after provider docs and secrets handling are approved.
