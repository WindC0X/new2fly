# Creative MJ Relay Follow-up

## Goal

Implement or explicitly scope `/creative` Midjourney relay support so embedded Opentu can use new-api as the only browser-facing session broker for MJ image generation. The work must provide a single path contract, browser-session security controls, task ownership, idempotency, CAS-safe settlement/refund, and channel/key affinity before any MJ route is exposed under `/creative`.

## User Value

A logged-in new-api user opening embedded `/creative` should be able to run the currently supported Opentu Midjourney image flow without configuring upstream MJ credentials in the browser, without leaking upstream task/key material, and without another user being able to fetch task metadata or generated image content.

## Confirmed Facts

- Parent evidence: `.trellis/tasks/06-09-newapi-opentu-creative-remediation/research/media-relay-continuation-2026-06-10.md` marked MJ as `split` because no safe creative MJ backend existed and legacy MJ billing/ownership/key-affinity were not proven.
- Backend `new-api/router/web-router.go` currently mounts creative chat, images, videos, and Suno routes under `/creative/relay/v1`; it does not mount `/creative/relay/v1/mj/...`.
- Backend legacy MJ routes are mounted under `/mj` and `/:mode/mj` in `new-api/router/relay-router.go`, protected by token auth rather than the creative browser-session middleware chain.
- Backend legacy MJ submit/fetch/image logic lives in `new-api/relay/mjproxy_handler.go` and `new-api/controller/midjourney.go` using the `model.Midjourney` table.
- Legacy MJ fetch uses `model.GetByMJId(userId, mjId)` for task fetch, but the image proxy uses `model.GetByOnlyMJId(mjId)` and is not owner-scoped.
- Legacy MJ submit currently post-consumes quota after a 200 upstream submit and does not prove insert/idempotency safety before charging. Legacy polling refunds wallet quota on failure through `IncreaseUserQuota`, not the creative BillingSession wallet/subscription lifecycle.
- Legacy MJ stores only `ChannelId`; action and polling fetch current `channel.Key`, so selected multi-key/channel affinity is not durable.
- Backend generic async task flow (`RelayTask`, `model.Task`, `TaskPollingLoop`, video/Suno task code) already supports pre-consume/settle/refund via `BillingSession`, scoped idempotency records, selected-key persistence in `Task.PrivateData.Key`, owner-scoped task fetch, and CAS terminal updates.
- Opentu MJ image support currently lives in `packages/drawnix/src/services/model-adapters/mj-image-adapter.ts` and calls `/mj/submit/imagine` then `/mj/task/{taskId}/fetch`.
- Opentu session-broker transport requires `baseUrl === "/creative/relay/v1"`, same-origin relative paths, credential stripping, and nonce/CSRF injection. The current MJ adapter trims a trailing `/v1`, which would break session-broker MJ unless fixed.
- Opentu currently needs only MJ imagine + task fetch for embedded MJ image generation. No current Opentu code path was found that calls legacy MJ action/change/image-seed/upload/swap-face routes from embedded `/creative`.

## Canonical Contract

Use the same relative Opentu paths under the session-broker base URL:

- `POST /creative/relay/v1/mj/submit/imagine`
- `GET /creative/relay/v1/mj/task/:task_id/fetch`
- `POST /creative/relay/v1/mj/task/list-by-condition` (optional compatibility for batched/local polling only if needed)
- `GET /creative/relay/v1/mj/image/:task_id` or an equivalent owner-scoped content proxy for generated binary/image content

The first implementation tranche should enable only `submit/imagine`, owner-scoped `task fetch`, and owner-scoped result/image proxy if generated image bytes are proxied. Legacy MJ action/change/modal/upload/swap-face/image-seed routes must remain unsupported under `/creative` until there is an Opentu caller and action-specific owner/idempotency/key-affinity tests.

## Requirements

### R1 — Creative route boundary

- Do not mount legacy `/mj` handlers directly under `/creative`.
- Every creative MJ route must pass through route tag, body storage cleanup, system performance check, creative session header bridge, user auth, same-origin enforcement, nonce enforcement, forbidden relay-field rejection, session-broker channel selection, and distribution.
- Browser/API-token-only auth must be rejected for creative MJ.
- Browser-supplied upstream `Authorization`, API keys, base URLs, provider/channel/group/model overrides, selected keys, task owner/user IDs, callback URLs, and `notifyHook` must be rejected or stripped before upstream relay.

### R2 — Server-side action/model inference

- Backend derives `mj_imagine` from `/mj/submit/imagine`; the browser must not provide a `model` override for creative MJ.
- Unsupported creative MJ actions return an explicit not-supported error and do not fall back to legacy token-auth routes.
- Distribution uses the server-derived model for group/model availability and channel selection.

### R3 — Idempotent submit and safe local task persistence

- `POST /creative/relay/v1/mj/submit/imagine` requires `Idempotency-Key` or `X-Creative-Request-Id`.
- Scope idempotency at least as `mj.submit.imagine`; same key + same payload replays the public task id, while same key + different payload returns conflict.
- The response returned to Opentu should use the new-api public task id as `result`; the upstream MJ id stays private in server task state.
- Upstream submit success must be buffered until local task insert, idempotency completion, and billing state are safe. If upstream succeeds but local persistence/idempotency completion fails, the pre-consume must be refunded and the idempotency record removed.

### R4 — Billing and CAS settlement/refund

- Creative MJ must use the generic async BillingSession lifecycle, not legacy one-off MJ post-consume/refund-only-wallet behavior.
- Pre-consume occurs before upstream submit for the selected model/group.
- Terminal success/failure transitions must use CAS (`UpdateWithStatus`) so only one poller settles/refunds.
- Failure refund must support both wallet and subscription/session-broker sources exactly once.
- Per-call MJ pricing may settle to the pre-consumed amount at terminal success unless an adaptor proves a different final quota.

### R5 — Channel/key affinity

- Submit persists selected channel id and selected key in task private data.
- Fetch/action/polling/content proxy use the submit-time channel/key where upstream access requires it, falling back to current channel key only for legacy/no-key tasks if an explicit compatibility path remains.
- Multi-key polling must group by stored key, not only by channel id.

### R6 — Ownership and result proxy safety

- Task fetch must load by `user_id + public_task_id` and return non-leaky not-found style errors for cross-user and missing tasks.
- Browser-facing task results must not expose stored upstream keys, upstream base URLs, selected channel ids, internal billing context, or upstream task ids unless explicitly necessary and safe.
- Generated image/content proxy must be owner-scoped and must set private/no-store style headers before streaming binary content. It must not use `GetByOnlyMJId` for browser creative requests.
- SSRF protections from the legacy proxy remain required when fetching upstream image URLs.

### R7 — Opentu session-broker behavior

- Embedded MJ requests use the session-broker provider context (`baseUrl: "/creative/relay/v1"`, `authType: "session-broker"`, empty `apiKey` allowed).
- MJ adapter must not trim `/creative/relay/v1` to `/creative/relay`; canonical submit/fetch paths resolve to `/creative/relay/v1/mj/...`.
- Opentu must send stable submit idempotency (`Idempotency-Key: opentu-image-<localTaskId>` or an MJ-specific equivalent) for the local task.
- Opentu must not send upstream `Authorization`, API-key headers/query, `baseUrl`, provider/channel/group/model override, selected key, or `notifyHook` material on session-broker MJ requests.
- Unsupported creative MJ responses (`404`, `405`, `501`) surface a sanitized unsupported-backend error and do not retry direct provider credentials.

## Acceptance Criteria

- [ ] Backend route tests prove canonical `/creative/relay/v1/mj/submit/imagine`, `/creative/relay/v1/mj/task/:task_id/fetch`, and result proxy paths are mounted only through creative middleware.
- [ ] Backend tests cover browser session success plus API-token-only/session-missing rejection, same-origin rejection, missing/invalid nonce rejection, and forbidden header/query/body field rejection.
- [ ] Backend tests cover server-derived `mj_imagine`, browser `model`/`notifyHook` rejection, unsupported action failure, and no legacy direct fallback under `/creative`.
- [ ] Backend submit tests cover pre-consume, upstream submit failure refund, local persistence failure refund, idempotent replay, idempotency conflict, public task id response, and selected channel/key persistence.
- [ ] Backend fetch/result tests cover same-user success, cross-user non-leaky rejection, missing task, private response headers, and no upstream key/channel/billing leakage.
- [ ] Backend polling/settlement tests cover CAS single-winner success settlement, CAS single-winner failure refund for wallet and subscription/session-broker billing sources, and no double refund/settlement from concurrent pollers.
- [ ] Backend channel/key affinity tests prove polling/action-compatible fetches use submit-time selected key for multi-key channels.
- [ ] Opentu adapter/transport tests prove embedded MJ uses `/creative/relay/v1/mj/submit/imagine` and `/creative/relay/v1/mj/task/{taskId}/fetch`, allows empty API key only for session broker, sends stable idempotency, strips credentials/routing/model material, and does not fall back on unsupported backend responses.
- [ ] Cross-layer path contract tests prove Opentu and new-api agree on submit/fetch/result URLs.
- [ ] Targeted backend and frontend test/typecheck commands are recorded with pass/fail evidence before the child task is archived.

## Out of Scope For First MJ Tranche

- Enabling creative MJ action/change/modal/shorten/upload/swap-face/image-seed routes before an embedded Opentu caller exists and action-specific tests are written.
- Rewriting the global token-auth `/mj` API for non-creative users, except where shared task adaptor/key-affinity helpers are needed safely.
- Full binary cloud-sync or asset persistence redesign beyond ensuring browser MJ result proxy ownership and private headers.
- Production deployment, remote push, or destructive git cleanup.

## Open Product/Scope Decisions

None currently blocking planning. Recommended implementation scope is the first MJ tranche above: imagine submit, owner-scoped task fetch, owner-scoped image/result proxy, and explicit unsupported failures for all other creative MJ legacy routes.
