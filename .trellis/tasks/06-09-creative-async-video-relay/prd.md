# Creative Async Video Relay Follow-up

## Goal

Define and implement `/creative` video relay support after the parent remediation proves that video routes require async task semantics beyond simple route mounting.

## Requirements

- Decide canonical embedded video path(s): `/creative/relay/v1/videos`, `/creative/relay/v1/v1/videos`, or a normalized alternative.
- Preserve new-api session-broker, CSRF/nonce, same-origin, and forbidden-field controls.
- Cover async task submit/fetch/content semantics, idempotency, CAS refunds, and channel/key affinity.
- Ensure opentu embedded mode does not require direct API keys for video calls.

## Acceptance Criteria

- [ ] opentu embedded video requests use the chosen `/creative` path and never direct upstream credentials.
- [ ] new-api routes map video submit/fetch/content to existing relay task modes or documented equivalents.
- [ ] Tests cover submit, fetch, refund/CAS behavior, and channel/key affinity.
- [ ] Unsupported video endpoints fail safely without direct fallback.
