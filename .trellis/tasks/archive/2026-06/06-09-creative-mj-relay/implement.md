# Creative MJ Relay Implementation Plan

## Phase A — Backend contract tests first

1. Add focused backend route/middleware tests for `/creative/relay/v1/mj`:
   - canonical submit/fetch/result proxy paths exist;
   - API-token-only or missing browser session is rejected;
   - same-origin and nonce checks are enforced;
   - forbidden headers/query/body fields are rejected;
   - browser `model` and `notifyHook` are rejected for submit;
   - unsupported creative MJ legacy actions return explicit unsupported errors.
2. Add backend submit idempotency tests:
   - missing idempotency key -> `400`;
   - same key + same payload replay -> same public task id;
   - same key + different payload -> `409`;
   - upstream submit failure and local persistence/idempotency completion failure refund and cleanup.
3. Add backend owner-scope tests:
   - same user can fetch public task id;
   - cross-user and missing task are non-leaky;
   - result/image proxy is owner-scoped and private/no-store.
4. Add backend polling/billing/key-affinity tests:
   - stored selected key is used for polling;
   - terminal success CAS settles once;
   - terminal failure CAS refunds once for wallet;
   - terminal failure CAS refunds once for subscription/session-broker billing source.

## Phase B — Backend implementation

1. Add MJ creative constants/guards in `controller/creative.go`:
   - `creativeMJSubmitScopeImagine = "mj.submit.imagine"`;
   - model/action derivation for `imagine -> mj_imagine`;
   - MJ-specific forbidden submit fields including top-level `model` and `notifyHook`;
   - scoped idempotency preparation using existing scoped creative idempotency helpers.
2. Add creative MJ handlers in `controller/creative.go` or a small dedicated controller file:
   - `CreativeRelayMJSubmitImagine` delegates to `RelayTask` after `creativeSetupSessionBrokerToken`;
   - `CreativeRelayMJFetch` loads/responds with owner-scoped MJ-compatible task DTO;
   - `CreativeRelayMJImage` streams owner-scoped result content with SSRF validation and private headers;
   - `CreativeRelayMJUnsupported` returns a sanitized unsupported error.
3. Add route registration in `router/web-router.go` under the existing creative relay group, not in legacy `relay-router.go`.
4. Add an MJ task adaptor under `relay/channel/task/mj`:
   - validate imagine request and set `info.Action = IMAGINE`;
   - build upstream `/mj/submit/imagine` request body/header;
   - parse upstream `dto.MidjourneyResponse`;
   - write MJ-compatible submit response with public task id;
   - implement `FetchTask` to call upstream task status/list-by-condition with selected key;
   - implement `ParseTaskResult` mapping upstream statuses to `model.TaskStatus*` and image URL(s).
5. Register the MJ task adaptor in `relay/relay_adaptor.go` for Midjourney channel types and/or `constant.TaskPlatformMidjourney`.
6. Update task polling dispatch so creative MJ generic tasks are polled through the generic per-task CAS/key-affinity path rather than the legacy `controller.UpdateMidjourneyTaskBulk` no-op branch.
7. Ensure `RelayTask` response buffering and idempotency completion semantics cover the MJ adaptor. If a missing helper is found, add the smallest shared helper instead of duplicating video/Suno logic.

## Phase C — Frontend contract tests first

1. Add Opentu MJ adapter tests proving session-broker mode:
   - empty `apiKey` is allowed only for `authType: "session-broker"`;
   - submit goes to `/creative/relay/v1/mj/submit/imagine`;
   - fetch goes to `/creative/relay/v1/mj/task/{taskId}/fetch`;
   - `/creative/relay/v1` is not trimmed to `/creative/relay`;
   - `Idempotency-Key` is stable from the local image task id;
   - unsupported backend responses are sanitized and no direct fallback request is attempted.
2. Extend provider transport tests so session-broker MJ paths strip model/provider/baseUrl/channel/API-key material the same way video/Suno do.
3. Add/update generation API tests proving image generation passes `opentu-image-<taskId>` (or the agreed MJ key prefix) into the MJ adapter.

## Phase D — Frontend implementation

1. Update `ImageGenerationRequest` or nested `params` handling so image adapters can receive stable idempotency material.
2. Update `generation-api-service.ts` image path to pass the local task id idempotency key.
3. Update `mj-image-adapter.ts`:
   - preserve session-broker base URL;
   - add `Idempotency-Key` for submit;
   - use canonical relative submit/fetch paths;
   - allow empty key only via provider transport/session-broker context;
   - sanitize unsupported backend errors and avoid direct fallback.
4. Update provider transport server-selected-model path detection to include `/mj` if needed.

## Phase E — Validation

Backend targeted validation:

```bash
cd /mnt/f/code/project/new-api
go test ./middleware ./router ./controller ./service ./model ./relay/constant ./relay/common ./relay/channel/task/mj

git diff --check
```

Frontend targeted validation:

```bash
cd /mnt/f/code/project/opentu
pnpm exec vitest run \
  packages/drawnix/src/services/model-adapters/mj-image-adapter.test.ts \
  packages/drawnix/src/services/provider-routing/provider-transport.session-broker.test.ts \
  packages/drawnix/src/services/__tests__/image-routing-adapter-integration.test.ts
pnpm exec tsc -p packages/drawnix/tsconfig.spec.json --noEmit
pnpm nx run drawnix:typecheck

git diff --check
```

If full suites are run, record known unrelated failures separately rather than weakening the MJ acceptance criteria.

## Phase F — Finish

1. Update backend/frontend specs with the final MJ creative async relay contract.
2. Update this task PRD evidence checkboxes and add an evidence markdown file with exact commands and results.
3. Commit backend, frontend, and Trellis docs separately if changes span multiple repositories.
4. Run `trellis-check` as an agent for the completed child task before archiving.
5. Archive `creative-mj-relay` only after all acceptance criteria are either passing or explicitly re-scoped with user approval.
