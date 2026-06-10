# Media Relay Continuation Evidence — 2026-06-10

## Dynamic workflow runs

Primary workflow:

- Workflow: `.codex-flow/generated/creative-media-relay-continuation.workflow.ts`
- Journal: `.codex-flow/journal/creative-media-relay-continuation.jsonl`
- Outcome: partial/warn. Three audit branches returned structured results; two branches timed out; final synthesis node failed with upstream `502 Bad Gateway`.

Finalizer retry:

- Workflow: `.codex-flow/generated/creative-media-relay-continuation-finalizer.workflow.ts`
- Journal: `.codex-flow/journal/creative-media-relay-continuation-finalizer.jsonl`
- Outcome: failed due upstream `502/503 Service Unavailable`; rerunning the same workflow replayed failed terminal nodes and did not produce a valid synthesis.

This evidence must not be treated as a fully green workflow. It is still useful because the primary workflow produced multi-branch findings for Suno, MJ, and cross-layer/opentu media callers.

## Branch findings used

### Suno

Decision: split / do not enable unsafe creative route yet.

Evidence summary from dynamic workflow:

- `new-api` has normal `/suno` API-token task routes, not `/creative/relay/v1/suno/*` routes.
- Suno polling/refund path needs CAS/idempotency hardening before being exposed through embedded creative.
- Multi-key/channel affinity is not proven for submit/fetch/status.
- `opentu` embedded audio currently has empty-api-key client guard issues unless session-broker handling is explicitly allowed and tested.

Required follow-up acceptance:

- Creative routes under `/creative/relay/v1/suno/...` use the same session-broker, CSRF/nonce, forbidden-field, and server-side model/group selection chain.
- Submit/fetch/status use durable idempotency, CAS guarded settle/refund, and selected channel/key affinity.
- Frontend audio session-broker path does not require browser upstream API key and does not send upstream `Authorization`/`apiKey`/`baseUrl` overrides.

### MJ / Midjourney

Decision: split / blocked for current parent closure.

Evidence summary from dynamic workflow:

- `new-api` has no creative MJ route today.
- `opentu` currently targets a creative MJ-style path, but backend creative relay only supports chat/images.
- Existing global MJ flow is legacy async wallet/task handling and is not proven safe for embedded session-broker billing/refund/idempotency.
- Result/image proxy and task action/fetch need explicit owner checks before being used in embedded creative.

Required follow-up acceptance:

- A single path contract is chosen and implemented consistently by `opentu` and `new-api`.
- Submit/action/fetch routes are protected by the creative middleware chain.
- Submit has a request id / mutation id idempotency strategy.
- Polling/action/fetch reuse selected channel/key affinity.
- Fetch/action/result endpoints enforce user ownership.

### Video / Kling / generic media

Decision: split for backend enablement; allow only frontend preparatory tests/guards when backend contract exists.

Evidence summary from dynamic workflow:

- `new-api` creative relay currently does not expose video/Kling/content routes.
- Video routes may involve multipart/form-data, while current creative forbidden-field/model parsing is JSON-centric.
- GET/fetch/content routes need query/header override rejection, nonce/session policy, and ownership checks.
- Async task billing/refund/idempotency/CAS/channel affinity must be proven before enabling creative video routes.

Required follow-up acceptance:

- Content-type-aware creative validation rejects forbidden form fields, query fields, and headers without breaking body forwarding.
- Route/action model inference happens server-side before group/channel selection; browser-supplied model/provider/baseUrl/key overrides are not trusted.
- Async submit/status/content flow has tests for CAS guarded settle/refund, idempotency, channel/key affinity, and ownership.
- Opentu video session-broker path may allow empty browser upstream `apiKey` only when `authType === 'session-broker'` and backend contract is enabled.

## Parent task impact

The safe decision is to keep Video/Suno/MJ as explicit child tasks instead of silently mounting unsafe creative routes in the parent task. This satisfies the parent acceptance criterion only if the child tasks carry the above blockers and acceptance criteria and the final parent report marks them as `split`, not `fixed`.

Remaining parent gates after this evidence:

- Browser smoke/E2E still needs to be run or explicitly blocked.
- `opentu/packages/drawnix/tsconfig.spec.json --noEmit` still needs to be run/fixed or split with evidence if unrelated.
- The three media relay child tasks remain active planning work, not completed implementation.
