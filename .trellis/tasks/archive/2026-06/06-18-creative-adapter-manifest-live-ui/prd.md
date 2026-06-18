# Creative adapter manifest and live binding UI

## Goal

Build a manifest-driven Creative adapter binding management foundation so New API can add Duomi, GrsAI, and later image-generation providers without hard-coding each provider into the admin UI or exposing provider credentials to OpenTU/browser clients.

This task's implementation scope is Phase A: backend adapter/parameter manifest as the source of truth, generic admin UI driven by that manifest, corrected parameter copy such as `quality` = “质量”, and validation/dry-run gates that remain no-provider-call. Real Duomi/GrsAI live transport, billing, polling, and provider response parsing are designed here but implemented in follow-up tasks unless explicitly promoted later.

## Confirmed Facts

- Provider API key, base URL, and upstream credentials belong in New API Channels, not in Creative model bindings and not in OpenTU local settings.
- Current Creative binding UI has provider/preset/template knowledge hard-coded in `creative-model-bindings-section.tsx`.
- Current backend capability service only allows `mock_image_task` and `grsai_gpt_image_dryrun`; GrsAI is dry-run/fixture only, not live.
- Current managed image task submission is mock-only; `/images/generations` rejects managed binding ids and requires `/images/tasks`.
- OpenTU should render Creative parameters from backend-provided schema, not provider-specific hard-coded UI.
- Different image models and channels can support different parameter sets, labels, allowed values, and defaults.

## Requirements

1. Backend exposes a Creative adapter manifest/catalog endpoint for admin UI use.
   - Manifests include adapter preset id, display label, description, modality, support status, transport mode, default parameter template, allowed parameter templates, and rollout/safety metadata.
   - Manifests may include disabled/live-future presets so the UI can show planned adapters without allowing unsafe saves.
2. Backend owns parameter templates and emits parameter schemas with model-specific labels, options, defaults, and descriptions.
   - `quality` must use Chinese copy “质量” where localized Chinese labels are emitted or rendered.
   - The system must support different parameter schemas per model/provider binding.
3. Admin UI for Creative Model Binding must be manifest-driven.
   - UI must not contain a closed TypeScript union of provider presets such as only mock/GrsAI dry-run.
   - UI flow should guide: choose Channel → choose Adapter Manifest → choose channel model/provider model → choose parameter template/schema → validate/dry-run → save disabled-by-default or canary/enable explicitly.
   - UI copy must clearly explain: Channel stores credentials/Base URL; Adapter defines protocol; Binding exposes a Creative model and safe parameter schema.
4. Validation and save behavior must remain fail-closed.
   - Unknown adapter presets/templates are rejected by backend validation.
   - Disabled or future live presets cannot be saved as enabled.
   - `PUT /api/creative/model-bindings` must continue to require no-provider-call dry-run validation for this phase.
5. OpenTU/browser clients must not receive credentials or provider control fields.
   - Public catalog/runtime APIs expose only resolved Creative model metadata and parameter schema needed for rendering.
   - No API key, base URL, callback URL, webhook/notifyHook, owner id, or provider secret appears in Creative binding JSON.
6. Design must explicitly define how Duomi and GrsAI live adapters will be added later.
   - Adding a provider should require a manifest entry, request mapper, response/status parser, billing/refund policy tests, and provider-specific parameter templates, with minimal or no admin UI changes.

## Non-goals

- Do not call real Duomi or GrsAI provider endpoints in this task.
- Do not store provider keys, base URLs, or secret headers in Creative binding JSON.
- Do not let OpenTU users choose raw New API channel ids, API keys, or provider base URLs.
- Do not make generic `/api/option` the supported editor for Creative bindings.
- Do not implement full live billing, polling, channel-key affinity, or terminal-state refund logic for Duomi/GrsAI in Phase A.

## Acceptance Criteria

- [ ] Admin can fetch adapter manifests through an authenticated no-store API endpoint.
- [ ] Creative binding UI builds its adapter/template choices from backend manifest data rather than a hard-coded provider union/map.
- [ ] The guided binding builder can create mock and GrsAI dry-run bindings from manifests and shows Duomi/GrsAI live presets as unavailable/future if included.
- [ ] `quality` is presented as “质量” in Chinese UI/schema contexts, and templates can express provider/model-specific parameter differences.
- [ ] Backend validation rejects unknown presets/templates and rejects enabling unsupported/live-future presets in Phase A.
- [ ] Save remains protected by validate + no-provider-call dry-run, with no real provider calls.
- [ ] Browser/public catalog responses do not expose credentials, base URLs, provider callbacks, owner ids, or channel secrets.
- [ ] Unit/type tests or focused checks cover manifest serialization, validation, UI manifest rendering, and schema label behavior.
- [ ] Local smoke confirms Creative settings still loads, model binding admin UI works, and embedded Creative parameter rendering is not regressed.

## Open Scope Decisions

- Phase A is assumed approved by the user's “那好，继续”: implement manifest-driven foundation now, defer real live transport to follow-up tasks.
- Live Duomi/GrsAI rollout will require a separate task with provider fixtures, mapper/parser tests, billing tests, and explicit staging authorization before any real provider calls.
