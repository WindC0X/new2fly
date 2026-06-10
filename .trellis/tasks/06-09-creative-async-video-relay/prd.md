# Creative Async Video Relay Follow-up

## Goal

Define and implement `/creative` video relay support after the parent remediation proves that video routes require async task semantics beyond simple route mounting.

## Requirements

- Decide canonical embedded video path(s): `/creative/relay/v1/videos`, `/creative/relay/v1/v1/videos`, or a normalized alternative.
- Preserve new-api session-broker, CSRF/nonce, same-origin, and forbidden-field controls.
- Cover async task submit/fetch/content semantics, idempotency, CAS refunds, and channel/key affinity.
- Ensure opentu embedded mode does not require direct API keys for video calls.
- Treat the parent workflow result as a safety constraint: do not enable backend creative video routes until async billing, ownership, and validation controls are proven by tests.
- Make creative validation content-type aware:
  - JSON bodies still recursively reject forbidden keys.
  - `multipart/form-data` rejects forbidden form fields, query fields, and headers without breaking body forwarding.
  - GET/status/content routes reject browser-supplied provider/baseUrl/apiKey/channel/model override query/header material.
- Infer or bind the server-side model/action before group/channel selection; do not trust browser-provided provider routing metadata.

## Acceptance Criteria

- [ ] opentu embedded video requests use the chosen `/creative` path and never direct upstream credentials.
- [ ] new-api routes map video submit/fetch/content to existing relay task modes or documented equivalents.
- [ ] Tests cover submit, fetch, refund/CAS behavior, and channel/key affinity.
- [ ] Unsupported video endpoints fail safely without direct fallback.
- [ ] Route tests cover session, same-origin, CSRF/nonce, forbidden JSON fields, forbidden multipart fields, forbidden query/header fields, and safe body re-read/forwarding.
- [ ] Async billing tests prove submit failure refunds once, terminal failure refunds once, success settles once, and concurrent poll/update CAS permits exactly one winning state transition.
- [ ] Idempotency tests cover repeated submit/status retry behavior using a durable request id or an explicit documented no-idempotency policy with frontend duplicate-submit prevention.
- [ ] Channel/key affinity tests prove status/content polling uses the original selected channel/key or stored equivalent, not a fresh random key.
- [ ] Ownership tests prove status/content/results cannot be fetched cross-user through browser-session creative routes.
- [ ] Opentu tests prove `authType === "session-broker"` video requests do not require a browser upstream `apiKey` and do not send upstream `Authorization`, `apiKey`, `baseUrl`, `provider`, or channel override fields.

## Split Decision Evidence

- Parent evidence: `.trellis/tasks/06-09-newapi-opentu-creative-remediation/research/media-relay-continuation-2026-06-10.md`.
- Dynamic workflows:
  - `.codex-flow/generated/creative-media-relay-continuation.workflow.ts`
  - `.codex-flow/journal/creative-media-relay-continuation.jsonl`

The parent task may mark video relay as `split`, not `fixed`, until every acceptance criterion above has passing evidence.
