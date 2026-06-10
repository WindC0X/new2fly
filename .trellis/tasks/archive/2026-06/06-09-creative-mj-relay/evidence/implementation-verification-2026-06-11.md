# Creative MJ Relay Implementation Verification — 2026-06-11

## Dynamic workflow runs

Primary implementation workflow:

- Workflow: `.codex-flow/generated/creative-mj-relay-implementation.workflow.ts`
- Journal: `.codex-flow/journal/creative-mj-relay-implementation.jsonl`
- Outcome: partial. Frontend branch completed and passed validation. Backend branch timed out. Integration review identified backend blockers around MJ upstream `mj-api-secret`, missing/focused backend coverage, and MJ result URL fallback risk.

Backend repair workflow:

- Workflow: `.codex-flow/generated/creative-mj-relay-backend-repair.workflow.ts`
- Journal: `.codex-flow/journal/creative-mj-relay-backend-repair.jsonl`
- Outcome: completed. Repaired backend upstream auth header, MJ result URL fallback, and added focused backend tests. Read-only reviews reported conditional pass with remaining note that local task insert/idempotency-completion failure is covered by the generic `RelayTask` cleanup path rather than an MJ-only injected failure test.

Trellis check agent:

- Agent: `trellis-check` / Huygens (`019eb2a5-e6c7-7ac1-a75b-f6c3a320cc58`)
- Outcome: completed and self-fixed.
- Self-fixes:
  - `new-api/controller/creative.go`: unsupported Creative MJ action rejects API-token-only access at handler boundary.
  - `new-api/controller/creative_test.go`: added `TestCreativeRelayMJUnsupportedRejectsAPITokenOnly`.
  - `new-api/service/task_polling_affinity_test.go`: added MJ subscription failure refund single-winner and MJ success settlement single-winner coverage.

## Backend implementation evidence

Implemented in `new-api`:

- Creative MJ routes under `/creative/relay/v1/mj`:
  - `POST /submit/imagine`
  - `GET /task/:task_id/fetch`
  - `POST /task/list-by-condition`
  - `GET /image/:task_id`
  - explicit unsupported handlers for legacy MJ actions.
- MJ-specific creative submit guard:
  - derives `mj_imagine` server-side;
  - rejects browser `model`, `notifyHook`, credentials, provider/base URL/channel/group/selected-key fields;
  - requires scoped idempotency `mj.submit.imagine`.
- New `relay/channel/task/mj` adaptor:
  - calls upstream with `mj-api-secret`, not `Authorization`;
  - returns public local task id as browser `result`;
  - stores upstream task id privately via generic `model.Task` flow;
  - parses MJ fetch results without falling back to video proxy URLs.
- Owner-scoped fetch/list/image proxy uses `user_id + public task_id`; image proxy sets private/no-store headers and uses SSRF URL validation.
- Generic async task billing/CAS path handles pre-consume, settle/refund, and idempotency cleanup; MJ-specific polling tests now cover stored-key affinity and wallet/subscription CAS single-winner behavior.

## Frontend implementation evidence

Implemented in `opentu`:

- MJ adapter preserves session-broker base `/creative/relay/v1` and does not trim it to `/creative/relay`.
- Session-broker MJ allows empty `apiKey`, while direct/non-session-broker MJ still fails fast without an API key.
- Submit path resolves to `/creative/relay/v1/mj/submit/imagine` and fetch resolves to `/creative/relay/v1/mj/task/{taskId}/fetch`.
- Stable image idempotency key `opentu-image-<localTaskId>` is propagated from generation/task execution into the MJ adapter.
- Provider transport strips credential/routing/model material on `/mj` session-broker paths.
- `404/405/501` unsupported creative MJ responses are sanitized and do not fall back to direct provider credentials.

## Verification commands

Backend:

```bash
cd /mnt/f/code/project/new-api
GOCACHE=/tmp/go-build go test -count=1 ./middleware ./router ./controller ./service ./model ./relay/constant ./relay/common ./relay/channel/task/mj
# PASS

git diff --check
# PASS
```

Frontend:

```bash
cd /mnt/f/code/project/opentu
pnpm exec vitest run \
  packages/drawnix/src/services/model-adapters/mj-image-adapter.test.ts \
  packages/drawnix/src/services/provider-routing/provider-transport.session-broker.test.ts \
  packages/drawnix/src/services/__tests__/image-routing-adapter-integration.test.ts \
  packages/drawnix/src/services/__tests__/generation-api-service.mj.test.ts \
  packages/drawnix/src/services/__tests__/media-executor.test.ts
# PASS — 5 files / 34 tests

pnpm exec tsc -p packages/drawnix/tsconfig.spec.json --noEmit
# PASS

pnpm nx run drawnix:typecheck
# PASS

git diff --check
# PASS
```

Notes:

- `pnpm` printed existing `.npmrc` warnings for missing `${NPM_TOKEN}` substitution; commands exited successfully.
- Some Vitest suites printed existing `localStorage is not defined` crypto initialization stderr; commands exited successfully.

## Excluded dirty paths

Do not include these in MJ commits:

- `/mnt/f/code/project/opentu/.gitignore` — unrelated pre-existing dirty file.
- `/mnt/f/code/project/opentu/packages/drawnix/audio-test.pptx` — unrelated untracked binary.
- `/mnt/f/code/project/new-api/.codegraph/` — generated/untracked codegraph data.
