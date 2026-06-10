# Creative Async Video Relay Implementation Plan

Implementation is blocked until `task.py start` changes this task status from `planning` to `in_progress`. Do not edit product code while the task remains in planning.

First implementation target: async-video only. Suno and MJ remain separate follow-up children.

## Phase 1 — Red tests

Write failing tests before production changes.

Backend red tests:

- Canonical creative paths: `POST /creative/relay/v1/videos`, `GET /creative/relay/v1/videos/:taskId`, `GET /creative/relay/v1/videos/:taskId/content`.
- Unsupported aliases fail closed: double-version paths, normal API-token video paths under creative, and provider-direct fallback attempts.
- Creative session chain: browser session, same-origin, CSRF/nonce for POST, GET nonce skip without skipping session/origin.
- Forbidden material matrix for headers, query, recursive JSON fields, multipart form fields/file-part names, and body replay.
- Async lifecycle: submit, status, content, durable idempotency, ownership, non-leaky errors.
- Billing/refund CAS: submit failure refunds once; terminal failure refunds once; success settles once; concurrent poll/update has exactly one CAS winner.
- Channel/key affinity: status/content polling uses the original selected channel/key or stored equivalent.

Opentu red tests:

- Embedded video route resolution uses `/videos`, `/videos/:taskId`, and `/videos/:taskId/content` relative to `/creative/relay/v1`.
- Empty `apiKey` is allowed only for `authType === "session-broker"`.
- Session-broker video strips upstream `Authorization`, `apiKey`, `baseUrl`, `provider`, model override query/header material, and channel/group overrides.
- Submit includes a stable idempotency request id.
- Unsupported creative video capability fails safely without direct provider fallback.

Initial red-test commands:

```bash
(cd /mnt/f/code/project/new-api && go test ./middleware ./router ./controller ./service ./model)
(cd /mnt/f/code/project/opentu/packages/drawnix && pnpm test -- src/services/__tests__/async-image-api-service.test.ts src/services/provider-routing/provider-transport.session-broker.test.ts src/services/__tests__/media-api-routing.test.ts)
```

## Phase 2 — new-api backend route/middleware

- Add the gated creative video route group for the canonical paths only.
- Keep normal API-token video routes unchanged and outside the creative browser-session boundary.
- Extend creative forbidden-material validation to headers/query for all methods and content-type-aware JSON/multipart validation for submit.
- Preserve body forwarding after validation via a replayable request body.
- Bind server-side media action and whitelisted video model before session-broker group/channel selection.
- Ensure disabled/unsupported routes stop before upstream calls, billing mutation, or credential lookup.

## Phase 3 — async billing/task persistence

- Add durable idempotency handling for creative video submit, scoped by user/action/request id/payload hash.
- Persist task owner, request id, billing context, safe action/model, upstream task id, and selected channel/key affinity.
- Make submit failures refund exactly once.
- Make status/content task updates use CAS for every terminal billing/refund transition.
- Enforce owner checks before status/content result exposure.
- Scrub provider secrets, base URLs, channel/key details, and unrelated task/user existence from client-visible errors.

## Phase 4 — opentu adapter/client

- Switch embedded async video calls from image route resolution to the video route contract.
- Allow empty browser `apiKey` only for session-broker video; preserve direct-key requirements for non-session-broker transports.
- Keep provider transport same-origin and credential stripping behavior.
- Add submit idempotency request id propagation.
- Prevent direct fallback when the backend creative video capability is disabled or unsupported.
- Keep preparatory video changes scoped to async-video; do not implement Suno/MJ behavior here.

## Phase 5 — verification

Run targeted checks first, then broader package gates.

Backend verification:

```bash
(cd /mnt/f/code/project/new-api && go test ./middleware ./router ./controller ./service ./model)
(cd /mnt/f/code/project/new-api && go test ./...)
```

Opentu verification:

```bash
(cd /mnt/f/code/project/opentu/packages/drawnix && pnpm test -- src/services/__tests__/async-image-api-service.test.ts src/services/provider-routing/provider-transport.session-broker.test.ts src/services/__tests__/media-api-routing.test.ts)
(cd /mnt/f/code/project/opentu && pnpm exec tsc -p packages/drawnix/tsconfig.spec.json --noEmit)
(cd /mnt/f/code/project/opentu && pnpm nx run drawnix:typecheck)
(cd /mnt/f/code/project/opentu && pnpm nx run drawnix:lint)
```

Completion evidence must include the exact command output or a clearly documented blocker. If an unrelated existing Opentu spec-type debt remains, split or document it separately; do not mark async-video complete without proving the async-video tests above.

## Phase 6 — rollback

Rollback must fail closed.

- Disable the creative video feature gate to remove submit/status/content exposure without affecting normal API-token video routes.
- Revert Opentu session-broker video capability advertising or route resolution so embedded video reports unsupported instead of direct-falling back.
- Keep idempotency/task rows safe to read; do not delete task history as part of rollback.
- Preserve tests that assert disabled/unsupported creative video routes do not leak credentials or bypass browser-session controls.
