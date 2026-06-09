# Creative Suno Relay Follow-up

## Goal

Implement or explicitly scope `/creative` Suno relay support with session-broker safety and async billing correctness.

## Requirements

- Define canonical `/creative` Suno submit/fetch paths.
- Handle requests that may not include a standard `model` field.
- Preserve session, nonce, forbidden-field, and same-origin controls.
- Validate async task billing/refund/idempotency behavior.

## Acceptance Criteria

- [ ] opentu embedded Suno requests do not require direct API keys.
- [ ] new-api routes can submit and fetch Suno tasks through session broker.
- [ ] Tests cover no-model/group strategy, task settlement, refunds, and forbidden fields.
