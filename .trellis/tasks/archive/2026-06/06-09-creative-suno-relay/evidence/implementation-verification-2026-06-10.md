# Creative Suno Relay Implementation Verification — 2026-06-10

## Dynamic workflow runs

- Planning workflow: `.codex-flow/generated/creative-suno-relay.workflow.ts`
  - Journal: `.codex-flow/journal/creative-suno-relay.jsonl`
  - Outcome: backend polling/billing branch completed; backend route/idempotency and frontend audio branches timed out; integration review did not complete.
- Implementation workflow: `.codex-flow/generated/creative-suno-relay-implement.workflow.ts`
  - Journal: `.codex-flow/journal/creative-suno-relay-implement.jsonl`
  - Outcome: backend and frontend workspace-write branches completed and reported changed files/tests.

## Sub-agent check

- Agent: `trellis-check` / `019eb215-931b-7c20-838e-5dcc06b247a7`
- Fixed findings:
  - Added Suno fetch owner-scope/missing-task regression coverage.
  - Propagated stable `opentu-audio-<taskId>` idempotency from generation/task queue paths.
  - Fixed targeted lint in a touched task queue file.

## Backend evidence (`/mnt/f/code/project/new-api`)

Main-session verification command:

```bash
GOCACHE=/tmp/go-build-cache go test ./middleware ./router ./controller ./service ./model ./relay/constant ./relay/common ./relay/channel/task/suno
```

Result: pass.

Observed output summary:

```text
ok github.com/QuantumNous/new-api/middleware
ok github.com/QuantumNous/new-api/router
ok github.com/QuantumNous/new-api/controller
ok github.com/QuantumNous/new-api/service
ok github.com/QuantumNous/new-api/model
ok github.com/QuantumNous/new-api/relay/constant
ok github.com/QuantumNous/new-api/relay/common
?  github.com/QuantumNous/new-api/relay/channel/task/suno [no test files]
```

Main-session diff check:

```bash
git diff --check
```

Result: pass.

Sub-agent broad check note:

- `go test ./...` still fails in unrelated pre-existing packages:
  - `relay/channel/claude`
  - `relay/helper`

## Frontend evidence (`/mnt/f/code/project/opentu`)

Main-session verification command:

```bash
pnpm exec vitest run \
  packages/drawnix/src/services/provider-routing/provider-transport.session-broker.test.ts \
  packages/drawnix/src/services/__tests__/provider-routing.test.ts \
  packages/drawnix/src/services/__tests__/audio-api-service.test.ts \
  packages/drawnix/src/services/__tests__/video-api-service.session-broker.test.ts
```

Result: pass — `4 passed`, `55 passed`.

Main-session type checks:

```bash
pnpm exec tsc -p packages/drawnix/tsconfig.spec.json --noEmit
pnpm nx run drawnix:typecheck
```

Result: pass. `nx` output: `Successfully ran target typecheck for project drawnix`.

Main-session targeted lint:

```bash
pnpm exec eslint --quiet \
  packages/drawnix/src/services/audio-api-service.ts \
  packages/drawnix/src/services/generation-api-service.ts \
  packages/drawnix/src/services/task-queue-service.ts \
  packages/drawnix/src/services/provider-routing/provider-transport.ts \
  packages/drawnix/src/services/provider-routing/provider-transport.session-broker.test.ts \
  packages/drawnix/src/services/__tests__/audio-api-service.test.ts
```

Result: pass.

Main-session diff check:

```bash
git diff --check
```

Result: pass.

Known non-task dirty/unrelated state:

- `.gitignore` was already dirty before the dynamic implementation run; it adds `.ace-tool/` and is not included as task work.
- `packages/drawnix/audio-test.pptx` remains untracked and untouched.
- `pnpm nx run drawnix:lint` still fails repo-wide with pre-existing lint debt per `trellis-check` report.

## Acceptance mapping

- `/creative/relay/v1/suno/submit/:action`, `GET /creative/relay/v1/suno/fetch/:id`, and `POST /creative/relay/v1/suno/fetch` implemented with session-broker route stack.
- Server-side Suno action/model inference covers no-browser-model submit flow.
- Scoped idempotency uses `suno.submit.music` / `suno.submit.lyrics` and preserves video idempotency behavior.
- Suno polling uses stored selected key affinity and CAS-guarded terminal refund/settlement.
- Opentu audio session-broker allows empty API key only for session-broker, strips credentials/routing overrides, uses canonical Suno paths, propagates stable task idempotency, and does not direct-fallback on unsupported embedded backend responses.
