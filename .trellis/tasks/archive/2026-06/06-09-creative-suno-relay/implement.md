# Creative Suno Relay Follow-up — Implementation Plan

## Preconditions

- Active task must be `06-09-creative-suno-relay`.
- Read context in this order before editing:
  1. `implement.jsonl`
  2. `prd.md`
  3. `design.md`
  4. this `implement.md`
  5. `research/code-discovery-2026-06-10.md`

## Work plan

### 1. Backend route contract and guards (`new-api`)

- Add `/creative/relay/v1/suno` route group in `router/web-router.go`.
- Reuse the existing creative relay outer middleware stack.
- Mount:
  - `POST /submit/:action` -> creative Suno submit wrapper -> `RelayTask`
  - `GET /fetch/:id` -> creative Suno fetch wrapper -> `RelayTaskFetch`
  - `POST /fetch` -> creative Suno batch fetch wrapper -> `RelayTaskFetch` if low-risk.
- Ensure unsupported creative Suno routes return safe 404/405 and do not fall through to SPA assets.

### 2. Backend server-side model/group inference

- Implement a Suno creative helper that validates `:action` (`music`, `lyrics`) and derives `suno_music` / `suno_lyrics`.
- Ensure the derived model participates in creative session-broker group selection even when the browser body has no `model` field.
- Do not trust browser-supplied model/group/provider/channel fields for Suno embedded mode.

### 3. Backend submit idempotency

- Reuse or generalize scoped idempotency helpers with scopes:
  - `suno.submit.music`
  - `suno.submit.lyrics`
- Require `Idempotency-Key` or `X-Creative-Request-Id` on Suno submit.
- Set `relayInfo.PublicTaskID` and `relayInfo.IdempotencyKey` before `RelayTask` submit.
- Complete/delete the scoped idempotency record with the same scope; do not accidentally call default video-scope helpers for Suno.
- Add tests for replay, conflict, action-scope separation, and cleanup on distributor/session-broker rejection.

### 4. Backend task polling/billing hardening

- Update Suno polling to use stored selected key affinity:
  - prefer `task.PrivateData.Key` over current `channel.Key`;
  - avoid exposing the key in logs/errors.
- CAS-guard terminal Suno transitions:
  - snapshot status before mutation;
  - use `UpdateWithStatus(previousStatus)` for `SUCCESS`/`FAILURE` transitions;
  - only CAS winner calls `RefundTaskQuota` or any completion settlement helper.
- Add tests for:
  - polling uses stored key;
  - concurrent failure refund only once;
  - concurrent success settlement/logging only once or explicitly no completion settlement if per-call billing;
  - wallet and subscription/session-broker refund contexts.

### 5. Frontend audio session-broker support (`opentu`)

- In `audio-api-service.ts`, allow empty `providerContext.apiKey` when `authType === "session-broker"`; keep direct providers fail-fast on empty key.
- Ensure submit/fetch use the relative paths from the binding under `/creative/relay/v1`.
- Add stable `Idempotency-Key` / `X-Creative-Request-Id` for submit, derived from local task id or generated request id.
- Ensure unsupported backend statuses surface a sanitized unsupported error and never fall back to direct credentials.

### 6. Frontend tests

- Add or extend tests around audio/session-broker behavior:
  - empty API key works only for session-broker;
  - direct provider empty API key still throws before fetch;
  - submit path `/creative/relay/v1/suno/submit/music` and poll path `/creative/relay/v1/suno/fetch/{taskId}`;
  - no `Authorization`, `X-API-Key`, `apiKey`, `baseUrl`, `provider`, or channel material in prepared/fetch calls;
  - unsupported backend response does not invoke direct fallback.

### 7. Verification commands

Backend target checks:

```bash
cd /mnt/f/code/project/new-api
go test ./middleware ./router ./controller ./service ./model ./relay/constant ./relay/common ./relay/channel/task/suno
```

If broad validation is affordable, additionally run:

```bash
go test ./...
```

Record any unrelated pre-existing package failures separately.

Frontend target checks:

```bash
cd /mnt/f/code/project/opentu
pnpm exec vitest run \
  packages/drawnix/src/services/provider-routing/provider-transport.session-broker.test.ts \
  packages/drawnix/src/services/__tests__/provider-routing.test.ts \
  packages/drawnix/src/services/audio-api-service.test.ts
pnpm exec tsc -p packages/drawnix/tsconfig.spec.json --noEmit
pnpm nx run drawnix:typecheck
```

If test file names differ, run the nearest scoped Vitest suite and record the exact command.

## Risk points / rollback

- Do not modify legacy token-auth `/suno` behavior except where shared polling correctness requires it.
- Do not regress `/creative/relay/v1/videos` idempotency scopes or fail-closed gate behavior.
- Avoid broad DB schema churn unless necessary; scoped idempotency can reuse the existing table in this tranche.
- Keep `opentu/packages/drawnix/audio-test.pptx` untracked and untouched unless explicitly requested.
