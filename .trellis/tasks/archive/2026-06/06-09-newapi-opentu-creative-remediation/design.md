# Design — new-api / opentu Creative Integration Remediation

## Scope Shape

This is a parent remediation task for cross-repository work in sibling repos:

- `/mnt/f/code/project/new-api`
- `/mnt/f/code/project/opentu`

The orchestration repo `/mnt/f/code/project/new2fly` stores Trellis artifacts and dynamic workflow journals only.

## Architecture Boundaries

### new-api responsibilities

- Serve `/creative` production opentu assets from the actual embedded path used by `main.go`.
- Expose session-authenticated `/creative/api/*` bootstrap, model, preference, and document APIs.
- Expose protected `/creative/relay/v1/*` routes for supported generation endpoints.
- Re-check user/session/group/model/quota on every relay call.
- Inject upstream credentials server-side only.
- Enforce CSRF, nonce, same-origin, and forbidden-field rejection for unsafe relay/API requests.
- Own billing/refund/idempotency semantics for creative relay calls.

### opentu responsibilities

- Detect `/creative` embedded mode.
- Use managed `new-api-creative` session-broker provider by default.
- Own model display policy, default visible subset, default active selection, ordering, grouping, and full-pool search UX.
- Avoid URL API key/settings persistence in embedded mode.
- Send generation requests through same-origin `/creative/relay/v1/*` unless an explicit safe exception exists.
- Maintain local-first document state and synchronize safe document/preference payloads only.
- Provide return-to-console UX when embedded in new-api.

## Key Design Corrections From Prior Work

1. **Production embed path must be authoritative.** Previous Sprint8 verification copied to and tested `new-api/router/web/creative/dist`, but `main.go` embeds `new-api/web/creative/dist`. The remediation must eliminate this split or explicitly make one path authoritative.
2. **Route mounting must match opentu callers.** Trimming `/creative/relay` in relay info is insufficient if gin never routes `/creative/relay/v1/images/generations` to a handler.
3. **Provider gateway safety is runtime behavior, not just data shape.** Tests must prove embedded generation cannot fall through to direct upstream providers with local API keys/base URLs.
4. **Document sync is not binary asset sync.** Asset references and binary persistence require separate audit and possibly separate storage design.

## Proposed Implementation Strategy

### Phase A — Dynamic evidence refresh

Run a read-only dynamic workflow that fans out over:

- production embed/dist path and build artifacts;
- opentu generation endpoint callers and provider fallback paths;
- new-api creative relay route coverage;
- cloud document/preference/asset sync boundaries;
- return-to-console UX;
- validation/typecheck state.

Output a structured findings matrix to the task research directory and journal.

### Phase B — Fix production dist path

Preferred option: make `new-api/web/creative/dist` the authoritative production embed path and copy the latest `/creative` opentu build there. Update router tests or add main/embed tests so the production path is covered.

Alternative option: change `main.go` embed to use a shared router-owned path only if that better fits repository conventions. This is riskier because existing Docker/build scripts mention `web/creative/dist`.

### Phase C — Implement minimal image relay route

If opentu image generation uses OpenAI-compatible `/images/generations`, mount:

- `POST /creative/relay/v1/images/generations`

with the same middleware chain as chat:

- route tag / cleanup / performance check;
- creative session header bridge;
- user auth;
- nonce;
- forbidden field rejection;
- creative relay session broker;
- distribution / relay dispatch.

Then test:

- route exists;
- missing/wrong nonce rejected;
- forbidden fields rejected before relay;
- relay mode maps to image generation after trimming `/creative/relay`;
- billing/refund behavior is either covered or not needed for the route shape.

### Phase D — Audit/split video, Suno, MJ

Do not blindly mount async task routes without idempotency/refund evidence. For each family:

- identify opentu caller path(s);
- identify new-api relay mode and async task semantics;
- determine whether existing billing/refund/CAS/multi-key affinity tests cover creative mode;
- implement only if minimal safe route + tests are clear;
- otherwise create child tasks with precise acceptance criteria.

### Phase E — Embedded gateway enforcement and return UX

- Ensure embedded opentu initializes and selects `new-api-creative` for generation routes.
- Prevent or visibly disable direct legacy provider route usage in `/creative` unless explicitly allowed.
- Add/complete return-to-console button through the existing linked task.

### Phase F — Cloud asset sync boundary

- Audit board element types and current document snapshot payloads for binary/blob/data URL/local asset references.
- If current boards need binary persistence to survive cross-device cloud sync, design a minimal session-backed asset upload/download/reference API.
- If not immediate, document this as a child task and ensure current JSON sync does not claim asset sync completion.

## Compatibility / Rollback

- Asset dist copy is reversible by replacing the creative dist directory from opentu build output.
- New routes should be additive under `/creative/relay/v1`; rollback removes route registration and tests.
- Provider gateway changes must be guarded by `isCreativeEmbeddedMode()` so standalone opentu remains compatible.
- Cloud sync schema changes must be allowlist-based and backward compatible with existing local cache.

## Security Invariants

- Browser never receives upstream API key/base URL/channel credentials from new-api creative APIs.
- Browser cannot supply provider/channel/baseUrl/apiKey/Authorization fields through creative relay body/headers.
- Unsafe creative API/relay requests require valid session + CSRF/nonce + same-origin checks.
- Cloud sync must not persist secrets or auth material.
