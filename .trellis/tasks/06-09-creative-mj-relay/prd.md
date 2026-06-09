# Creative MJ Relay Follow-up

## Goal

Implement or explicitly scope `/creative` Midjourney relay support with task permission, CAS refund, and channel/key affinity guarantees.

## Requirements

- Define canonical `/creative` MJ submit/fetch/action paths.
- Preserve session-broker and forbidden-field controls.
- Ensure task ownership/fetch permission is enforced for browser session users.
- Cover async task settlement, CAS refunds, and original channel/key affinity.

## Acceptance Criteria

- [ ] opentu embedded MJ requests use `/creative` session broker, not direct upstream credentials.
- [ ] new-api routes submit/fetch MJ tasks safely.
- [ ] Tests cover permission, CAS/refund, channel/key affinity, and unsupported route failures.
