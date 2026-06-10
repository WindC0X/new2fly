# Creative Suno Relay Follow-up

## Goal

Implement or explicitly scope `/creative` Suno relay support with session-broker safety and async billing correctness.

## Requirements

- Define canonical `/creative` Suno submit/fetch paths.
- Handle requests that may not include a standard `model` field.
- Preserve session, nonce, forbidden-field, and same-origin controls.
- Validate async task billing/refund/idempotency behavior.
- Do not directly expose existing API-token `/suno` routes under `/creative` without a creative session-broker wrapper and tests.
- Route/action must infer a safe server-side model/group before distribution and billing; browser-supplied model/provider/baseUrl/key override fields must be rejected or stripped.
- Persist and reuse the selected channel/key or key fingerprint for submit/fetch/polling so multi-key channels do not drift.
- Fix or prove Suno polling refund/settlement idempotency before enabling embedded creative Suno.

## Acceptance Criteria

- [ ] opentu embedded Suno requests do not require direct API keys.
- [ ] new-api routes can submit and fetch Suno tasks through session broker.
- [ ] Tests cover no-model/group strategy, task settlement, refunds, and forbidden fields.
- [ ] Creative Suno routes are namespaced under the chosen `/creative/relay/v1/suno/...` contract and protected by the same browser-session, same-origin, CSRF/nonce, forbidden-field, and server-side group selection controls as chat/images.
- [ ] Browser requests cannot pass upstream `Authorization`, `apiKey`, `baseUrl`, `provider`, `channel`, selected key, or owner override material in body, query, or headers.
- [ ] Submit tests cover pre-consume, task creation, upstream submit failure refund, and duplicate-submit/idempotency behavior.
- [ ] Fetch/status tests cover same-user success, cross-user rejection/non-leaky not-found, and missing task behavior.
- [ ] Polling tests prove CAS-guarded status transitions; concurrent failure/success polling cannot double-refund or double-settle.
- [ ] Refund tests cover wallet and subscription/session-broker billing sources with durable idempotency keys or equivalent once-only guarantees.
- [ ] Multi-key affinity tests prove fetch/status uses the submit-time selected key, not the raw multi-line channel key pool.
- [ ] Opentu audio/Suno tests prove embedded session-broker requests work with empty browser upstream `apiKey` while still stripping upstream credentials.

## Split Decision Evidence

- Parent evidence: `.trellis/tasks/06-09-newapi-opentu-creative-remediation/research/media-relay-continuation-2026-06-10.md`.
- Dynamic workflows:
  - `.codex-flow/generated/creative-media-relay-continuation.workflow.ts`
  - `.codex-flow/journal/creative-media-relay-continuation.jsonl`

The parent task may mark Suno relay as `split`, not `fixed`, until every acceptance criterion above has passing evidence.
