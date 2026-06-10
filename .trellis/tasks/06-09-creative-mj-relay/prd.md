# Creative MJ Relay Follow-up

## Goal

Implement or explicitly scope `/creative` Midjourney relay support with task permission, CAS refund, and channel/key affinity guarantees.

## Requirements

- Define canonical `/creative` MJ submit/fetch/action paths.
- Preserve session-broker and forbidden-field controls.
- Ensure task ownership/fetch permission is enforced for browser session users.
- Cover async task settlement, CAS refunds, and original channel/key affinity.
- Do not mount global legacy MJ routes directly under `/creative` without a creative session-broker wrapper and explicit async billing/ownership tests.
- Choose one canonical path contract with opentu before implementation, for example `/creative/relay/v1/mj/...`; remove or redirect divergent `/creative/relay/mj/...` assumptions.
- Submit must have an idempotency strategy using a client mutation/request id or a clearly documented no-idempotency policy plus frontend duplicate-submit prevention.
- Result/image proxy semantics must be redesigned or guarded so embedded browser users cannot fetch another user's generated content.

## Acceptance Criteria

- [ ] opentu embedded MJ requests use `/creative` session broker, not direct upstream credentials.
- [ ] new-api routes submit/fetch MJ tasks safely.
- [ ] Tests cover permission, CAS/refund, channel/key affinity, and unsupported route failures.
- [ ] Path contract tests prove opentu and new-api agree on submit/fetch/action/result URLs.
- [ ] Route tests cover browser session, same-origin, CSRF/nonce, forbidden body/query/header fields, and no browser upstream key/baseUrl/provider/channel override leakage.
- [ ] Submit tests cover pre-consume, upstream submit failure refund, idempotent retry, and task persistence with selected model/group/channel/key affinity.
- [ ] Action/fetch tests cover same-user success, cross-user rejection/non-leaky not-found, unsupported action failure, and no direct fallback.
- [ ] Polling/settlement tests prove CAS-guarded once-only success/failure transitions and once-only refund/settle behavior for wallet and subscription/session-broker sources.
- [ ] Channel/key affinity tests prove action/fetch/polling reuse submit-time selected channel/key or stored key fingerprint.
- [ ] Result/image proxy tests prove ownership checks and private response headers before exposing any generated binary/content URL to embedded creative.
- [ ] Opentu MJ adapter tests prove embedded requests are same-origin and do not send upstream `Authorization`, `apiKey`, `baseUrl`, `provider`, channel, or selected key material.

## Split Decision Evidence

- Parent evidence: `.trellis/tasks/06-09-newapi-opentu-creative-remediation/research/media-relay-continuation-2026-06-10.md`.
- Dynamic workflows:
  - `.codex-flow/generated/creative-media-relay-continuation.workflow.ts`
  - `.codex-flow/journal/creative-media-relay-continuation.jsonl`

The parent task may mark MJ relay as `split`, not `fixed`, until every acceptance criterion above has passing evidence.
