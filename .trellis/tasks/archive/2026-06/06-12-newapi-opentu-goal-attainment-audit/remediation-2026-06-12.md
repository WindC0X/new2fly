# Creative 06-12 Remediation Evidence

Date: 2026-06-12

## Scope fixed in this pass

- Backend P0/P1: model/req_key override hardening, accepted-upstream refund guard, creative relay rate limit, S3 managed client, video relay capability bootstrap, Claude file-content conversion, stream scanner preinitialized status preservation.
- Frontend P0/P1: video capability parsing/filtering, asset URL same-origin test contract, session-broker video/MJ stable idempotency fail-fast.
- Backend P2 hardening:
  - `relay/relay_task.go` closes non-200 task submit response bodies through `taskSubmitNonOKResponseError`; regression test in `relay/relay_task_test.go`.
  - `service/creative_task_ids.go` adds Creative task-id list normalization/caps (`max=50`, `maxLen=191`); `controller/creative.go` MJ list-by-condition and `relay/relay_task.go` Suno fetch call it before `model.GetByTaskIds`; tests in `service/creative_task_ids_test.go`.
  - `relay/channel/api_request.go` and `relay/common/override.go` drop sensitive browser headers (`Cookie`, `Authorization`, `X-Creative-*`, API-key/secret variants, etc.) from wildcard/client-header/pass_headers forwarding; tests in `relay/channel/api_request_test.go` and `relay/common/override_test.go`.
  - `controller/video_proxy.go` logs redacted video URL authority only, and `service/task_polling.go` logs sanitized/truncated provider bodies; tests in `controller/video_proxy_test.go` and `service/task_polling_redaction_test.go`.
- Backend/frontend P3 docs:
  - `new-api/.env.example` documents Creative video/asset/S3 switches.
  - `new-api/docs/openapi/creative-embed.md` documents the embedded route/env/security matrix and is linked from `README.md` / `README.zh_CN.md`.
  - `opentu/docs/CREATIVE_EMBED_DEPLOYMENT.md` documents the session-broker/SW/CDN boundary and is linked from `README.md`, `docs/CDN_DEPLOYMENT.md`, and `docs/NPM_CDN_DEPLOY.md`.
  - Trellis specs updated: `.trellis/spec/backend/creative-backend-security-boundary.md` covers ID caps, sensitive header passthrough restrictions, and log redaction; `.trellis/spec/frontend/creative-asset-sync.md` covers Creative CDN/SW same-origin deployment exceptions.

## Dynamic workflow check

- Successful log-evidence workflow: `.codex-flow/generated/creative-0612-fix-log-verification.workflow.ts`
- Journal: `.codex-flow/journal/creative-0612-fix-log-verification.jsonl`
- Result: 2/2 branches returned `pass` for backend command evidence and targeted frontend command evidence.
- Broader read-only code-review workflows were also attempted but timed out:
  - `.codex-flow/generated/creative-0612-fix-verification.workflow.ts`
  - `.codex-flow/generated/creative-0612-fix-verification-mini.workflow.ts`
- P2 hardening verification workflows:
  - `.codex-flow/generated/creative-0612-p2p3-hardening-verification.workflow.ts` / `.codex-flow/journal/creative-0612-p2p3-hardening-verification.jsonl` attempted read-only/code-evidence branches; branch timeouts, not used as primary evidence.
  - `.codex-flow/generated/creative-0612-p2p3-log-evidence.workflow.ts` / `.codex-flow/journal/creative-0612-p2p3-log-evidence.jsonl` returned `pass` for backend command evidence; one code-evidence branch timed out.
  - `.codex-flow/generated/creative-0612-p2-change-evidence-mini.workflow.ts` / `.codex-flow/journal/creative-0612-p2-change-evidence-mini.jsonl` returned `pass` for concise P2 change-evidence coverage, with caveat that it checks evidence coverage, not code execution.

## Fresh verification commands

```bash
cd /mnt/f/code/project/new-api
go test ./router ./middleware ./controller ./model ./service ./relay/...
```

Result: exit 0.

P2 targeted regression command:

```bash
cd /mnt/f/code/project/new-api
go test ./relay ./service ./relay/channel ./relay/common ./controller \
  -run 'TestTaskSubmitNonOKResponseErrorClosesBody|TestNormalizeCreativeTaskIDList|TestProcessHeaderOverride_PassthroughSkipsSensitiveBrowserHeaders|TestProcessHeaderOverride_ClientHeaderPlaceholderSkipsSensitiveBrowserHeaders|TestApplyParamOverridePassHeadersSkipsSensitiveBrowserHeaders|TestRedactURLForLog|TestRedactTaskResponseBodyForLog'
```

Result: exit 0.

P2 touched-package command:

```bash
cd /mnt/f/code/project/new-api
go test ./relay ./service ./relay/channel ./relay/common ./controller
```

Result: exit 0.

```bash
cd /mnt/f/code/project/opentu
pnpm --filter @aitu/drawnix exec vitest run \
  src/services/creative-session-broker.test.ts \
  src/services/provider-routing/provider-transport.session-broker.test.ts \
  src/services/__tests__/audio-api-service.test.ts \
  src/services/__tests__/video-api-service.session-broker.test.ts \
  src/services/model-adapters/mj-image-adapter.test.ts \
  src/services/creative-document-assets.test.ts \
  --no-file-parallelism --maxWorkers=1 --minWorkers=1
```

Result: exit 0, 6 files / 60 tests passed.

```bash
cd /mnt/f/code/project/opentu
pnpm nx run drawnix:typecheck
```

Result: exit 0, `NX Successfully ran target typecheck for project drawnix`.

Whitespace checks:

```bash
cd /mnt/f/code/project/new-api && git diff --check
cd /mnt/f/code/project/opentu && git diff --check
cd /mnt/f/code/project/new2fly && git diff --check
```

Result: all exit 0.

## Remaining non-P0/P1 follow-up / caveats

- Closed in this P2 pass: upstream log redaction, task-submit non-200 body close, Suno/MJ list ID caps, and pass_headers sensitive forwarding restrictions.
- Existing asset-delete retry coverage: `service/creative_asset_test.go::TestCreativeAssetDeleteFailureKeepsMetadataRetryable` verifies failed S3 deletes keep metadata retryable and a later delete finalizes metadata/quota. A separate background sweeper for stale `pending_delete` rows is still a future operational hardening item, not required for request-time retry correctness.
- Still open/deferred: runtime integration verification against real DB/Redis/S3/provider-like services, optional `go test ./...` / lint / race gates, and a future background sweeper for stale `pending_delete` asset rows.
