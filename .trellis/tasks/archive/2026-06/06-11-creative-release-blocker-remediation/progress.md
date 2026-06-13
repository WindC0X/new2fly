# Progress — Creative Release Blocker Remediation

## Status

All four implementation child tasks are complete and archived as of 2026-06-12.

## Archived children

1. `.trellis/tasks/archive/2026-06/06-11-creative-backend-security-boundary-hardening`
2. `.trellis/tasks/archive/2026-06/06-11-creative-async-task-billing-consistency`
3. `.trellis/tasks/archive/2026-06/06-11-creative-frontend-session-broker-asset-sync-hardening`
4. `.trellis/tasks/archive/2026-06/06-11-creative-asset-quota-delete-lifecycle-hardening`

## Fixed release blockers

- H1: Creative API/relay route registration is independent of static web serving / `FRONTEND_BASE_URL`; Creative paths fail closed with same-origin JSON/private headers instead of frontend redirects.
- H2/H3/H4: async task submission, terminal CAS, billing/refund, idempotency, channel-failure, null-upstream, and stored-key fallback paths are covered by durable outbox/CAS semantics.
- H5: Suno fetch is owner-scoped and `Platform==Suno` scoped, returning sanitized Suno DTOs only.
- H6: asset upload quota is backed by transactional `CreativeAssetQuota` reservation rows, with concurrent regression coverage.
- H7/H8: Opentu asset URL discovery and hydrate/cold-start sanitizer coverage was expanded and fail-closed.
- H9/M6: notify/callback/webhook/owner/user/API-secret variants are stripped client-side and denied backend-side.
- Asset delete/document-ref mediums: delete is pending-delete/retryable and document/ref mutations are model transaction helpers.

## Deterministic final validation

Backend targeted release command passed in `/mnt/f/code/project/new-api`:

```bash
GOCACHE=/mnt/f/code/project/new2fly/.cache/go-build \
GOTMPDIR=/mnt/f/code/project/new2fly/.cache/go-tmp \
GOMODCACHE=/home/windc0x/go/pkg/mod \
go test ./middleware ./router ./model ./service ./relay/constant ./relay/common ./relay/channel/task/mj ./controller \
  -run 'Creative|Suno|MJ|Midjourney|Task|Asset|Billing|Idempotency|Relay|Router|Nonce|Cache|Proxy|Forwarded' -count=1
```

Passed.

Broader backend touched-package command passed:

```bash
GOCACHE=/mnt/f/code/project/new2fly/.cache/go-build \
GOTMPDIR=/mnt/f/code/project/new2fly/.cache/go-tmp \
GOMODCACHE=/home/windc0x/go/pkg/mod \
go test ./router ./middleware ./controller ./service ./model ./relay ./relay/common ./relay/constant -count=1
```

Passed.

Frontend targeted release command passed in `/mnt/f/code/project/opentu`:

```bash
pnpm exec vitest run \
  packages/drawnix/src/services/__tests__/video-api-service.session-broker.test.ts \
  packages/drawnix/src/services/__tests__/audio-api-service.test.ts \
  packages/drawnix/src/services/model-adapters/mj-image-adapter.test.ts \
  packages/drawnix/src/services/creative-document-assets.test.ts \
  packages/drawnix/src/services/provider-routing/provider-transport.session-broker.test.ts \
  apps/web/src/sw/creative-asset-pass-through.spec.ts \
  --no-file-parallelism --maxWorkers=1 --minWorkers=1
```

Passed: 6 files, 50 tests.

Frontend typecheck passed:

```bash
pnpm exec tsc -p packages/drawnix/tsconfig.spec.json --noEmit
```

Passed.

## Dynamic workflow usage / limitations

- Backend security, async billing, and frontend session/assets children each used read-only dynamic workflows; those workflows found additional gaps that were fixed and recorded in the child progress files.
- Asset lifecycle child attempted two post-fix dynamic workflows:
  - `/mnt/f/code/project/new-api/.codex-flow/generated/creative-asset-lifecycle-check.workflow.ts`
  - `/mnt/f/code/project/new-api/.codex-flow/generated/creative-asset-lifecycle-fast-check.workflow.ts`
- Both asset lifecycle workflows timed out in `codex-flow`/`codex-sdk` before producing business findings; journals are under `/mnt/f/code/project/new-api/.codex-flow/journal/`.
- The timed-out workflow results were not treated as pass evidence. Asset lifecycle closure rests on red/green regression tests, direct code inspection, and passing Go suites.

## Residual / risk notes

- No accepted HIGH release blocker remains open in the merged audit scope.
- Remaining medium-hardening risk is operational rather than code-local: DB-backed quota atomicity depends on the configured production database honoring transactional row updates/locks. SQLite regression tests cover the advisory-precheck race and serialize through the quota row.
- Existing unrelated dirty files remain outside this parent task scope and were not committed automatically.
