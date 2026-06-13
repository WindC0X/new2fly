# 2026-06-12 Codex / Claude Creative Audit Arbitration

## Scope

Compared and re-verified:

- Codex report: `.trellis/tasks/06-12-newapi-opentu-goal-attainment-audit/report.md`
- Claude Code report: `.trellis/workspace/WindC0X/creative-deep-audit-2026-06-12.md`
- Backend: `/mnt/f/code/project/new-api`
- Frontend: `/mnt/f/code/project/opentu`
- Trellis specs: `/mnt/f/code/project/new2fly/.trellis/spec`

No application code was modified by this arbitration.

## Dynamic workflow evidence

Dynamic workflow was used for part of verification/checking as requested.

- Generated workflow: `.codex-flow/generated/creative-0612-report-arbitration.workflow.ts`
- Journal: `.codex-flow/journal/creative-0612-report-arbitration.jsonl`
- Rerun command: `codex-flow run .codex-flow/generated/creative-0612-report-arbitration.workflow.ts`
- Result: 3/5 read-only branches completed, 2 branches timed out. Completed branches covered backend critical B1/B2/G1/G2, security hardening extras, and ops/docs/spec drift. Timed-out backend-contract/frontend-contract branches were compensated by main-thread source inspection and targeted test runs below.

## Fresh verification commands

```bash
cd /mnt/f/code/project/new-api
go test ./router ./middleware ./controller ./model ./service ./relay/...
```

Exit: 1. Confirmed failures:

- `relay/channel/claude`: `TestRequestOpenAI2ClaudeMessage_IgnoresUnsupportedFileContent`, `TestRequestOpenAI2ClaudeMessage_SupportsPDFFileContent`, `TestRequestOpenAI2ClaudeMessage_ConvertsTextFileContentToText`.
- `relay/helper`: `TestStreamScannerHandler_StreamStatus_PreInitialized`.

```bash
cd /mnt/f/code/project/opentu
pnpm --filter @aitu/drawnix exec vitest run src/services/creative-document-assets.test.ts --no-file-parallelism --maxWorkers=1 --minWorkers=1
```

Exit: 1. Confirmed failure:

- `creative-document-assets.test.ts > recognizes only query-free same-origin creative asset content refs`: expected `isCreativeAssetContentUrl('http://localhost/creative/api/assets/asset_123/content')` to be true, received false.

## Arbitration summary

Overall: both reports contain useful true findings. Claude is stronger on business/goal bugs B1/B2/G1/G2, but overstates some scope. Codex correctly calls out failing checks, S3/default-client and docs/deploy drift, but some backend route/MJ claims are not confirmed in current code.

### Confirmed release blockers / high-priority defects

| ID | Verdict | Severity | Evidence / scope |
| --- | --- | --- | --- |
| Claude B1 `metadata.model_name` billing/model-pool bypass | Confirmed, but affected-provider list overbroad | HIGH / P0 | `controller/creative.go:1646-1674` denylist lacks `modelname`; `_` is not a segment splitter. `taskcommon.UnmarshalMetadata` only deletes exact `model`. Kling initializes `ModelName` from `info.UpstreamModelName` then metadata can overwrite it (`relay/channel/task/kling/adaptor.go:266-287`). Pricing remains on `OriginModelName` (`relay/relay_task.go:162-182`). Jimeng has a similar `metadata.req_key` model-key risk (`relay/channel/task/jimeng/adaptor.go:381-403`). |
| Claude B2 upstream accepted then local persistence/idempotency failure refunds | Confirmed | HIGH / P0 | `controller/relay.go:520-523` refunds on any `taskErr`; after `RelayTaskSubmit` success, `task.Insert()` or `CompleteCreativeVideoIdempotencyScoped` failure sets `taskErr` (`controller/relay.go:594-620`) and skips durable settle. `SettleSubmittedTaskBillingDurably` itself is outbox-protected (`service/task_billing.go:172-184`), so the bug scope is insert/idempotency failure, not normal settle retry. |
| Creative per-user relay frequency limit | Confirmed gap | HIGH/P1 | Creative relay group in `router/web-router.go:89-130` does not mount `ModelRequestRateLimit`, unlike normal relay routes (`router/relay-router.go`). Current upload per-user rate-limit is intentionally waived in active asset spec, but creative relay cost endpoints still have no user-key rate limit. |
| Current quality gates | Confirmed failing | P0 quality | Backend broad test command fails in `relay/channel/claude` and `relay/helper`; frontend targeted creative asset test fails. |

### Product / spec decision, not hidden implementation bug

| ID | Verdict | Notes |
| --- | --- | --- |
| Claude G1 R5 tombstone + name/prompt/model | True versus old PRD, but current active spec intentionally diverges | `model/creative_asset.go:37-56` has no `name/prompt/model`; `FinalizeCreativeAssetDelete` hard-deletes after storage delete. However `.trellis/spec/backend/creative-asset-sync.md:44-53` explicitly defines pending-delete then final delete and says name/prompt/model are not first-class columns for this release. Treat as product/PRD acceptance item, not security blocker unless strict R5 is reinstated. |
| D1 server-driven UI policy | Acceptable tested deviation, needs spec/docs | Backend bootstrap lacks full UI/default/capability fields; frontend intentionally strips server UI policy and owns display/default logic. This is safer but should be written into active specs. |
| D2 signed URL -> same-origin content proxy; D3 byte quota | Accepted current spec decisions | Active asset spec requires `/creative/api/assets/:id/content` same-origin proxy and byte quota. Docs/env examples have not caught up. |

### Confirmed medium / hardening findings

| ID | Verdict | Severity | Evidence / scope |
| --- | --- | --- | --- |
| Codex S3 storage uses `http.DefaultClient` | Confirmed | P1 if S3 production, otherwise P2 | `service/creative_asset.go:641-645` sets `httpClient: http.DefaultClient`; active security spec requires managed client with redirect/SSRF policy. |
| Video relay disabled by default but frontend advertises video | Confirmed conditional risk | P1/P2 | Backend `CREATIVE_VIDEO_RELAY_ENABLED` defaults false (`controller/creative.go:50-63`); frontend managed session-broker profile hardcodes `supportsVideo: true` (`creative-session-broker.ts:277-294`). If model pool exposes video while backend gate is false, UX routes into disabled endpoint. |
| Header override/pass_headers sensitive forwarding | Partly confirmed | MEDIUM | Admin-configured pass-through can copy Cookie / X-Creative-CSRF / X-Creative-Nonce. Creative guard rejects Authorization in request material, so Claude's Authorization subclaim is not fully confirmed. |
| Logs before redaction | Confirmed | MEDIUM | Dynamic workflow found raw upstream body/URL logging in `service/task_polling.go` and `controller/video_proxy.go`. |
| Task submit non-200 body not closed | Confirmed | MEDIUM | `relay/relay_task.go:221-228` reads non-200 body and returns without closing. |
| Unbounded Suno/MJ list-by-condition IDs | Confirmed | MEDIUM | `controller/creative.go:575-585`, `relay/relay_task.go:313-324`, `model/task.go:454-461`. Parameterized but DoS-prone without count/length caps. |
| S3 Put before DB insert orphan risk | Confirmed with compensation | LOW/MEDIUM | `service/creative_asset.go:317-324` stores object before DB create; cleanup is attempted but crash/delete failure can leave orphan. |
| Asset quota race | Final quota bypass not confirmed | LOW residual | Current `CreateCreativeAssetWithQuota` uses transaction + quota row lock. Remaining issue is non-transactional precheck may waste S3 upload before final rejection. |
| Frontend session-broker random idempotency fallback | Confirmed for video/MJ; audio has taskId fallback first | MEDIUM | `video-api-service.ts:162-181`, `mj-image-adapter.ts:65-102`. Prefer fail-fast/stable task id for submit paths. |

### Codex findings not confirmed / downgraded

| Codex claim | Arbitration |
| --- | --- |
| Creative NoRoute/NoMethod no-store incomplete | Not confirmed in current code. `middleware/cache.go:21-24` sets `private, no-store` for `/creative/api`/`/creative/relay`; `router/main.go:36-45` also sets no-store under `FRONTEND_BASE_URL`; router tests assert no-store for missing/wrong/trailing slash paths. |
| MJ `image_url` vs `imageUrl` breaks frontend | Not confirmed. `dto.MidjourneyDto.ImageUrl` serializes as `imageUrl`; `creativeMJTaskDTO` returns proxy `imageUrl`; `creativeMJTaskDataString` normalizes keys so raw `image_url` can be read. Frontend expects `imageUrl`, matching the creative DTO. |
| Frontend asset URL failure is definitely runtime bug | Confirmed as test failure, root cause likely test/URL-origin contract mismatch. Implementation compares exact runtime origin (`creative-document-assets.ts:211-230`); Vitest jsdom origin is not explicitly set, while the test hardcodes `http://localhost`. Fix the contract/test explicitly; do not loosen origin equivalence casually. |

## Consolidated next actions

### P0 — fix before claiming release-ready

1. Close B1 model-key override: deny all model/upstream model aliases in recursive creative relay metadata (`model_name`, `modelName`, `req_key`, etc.), and after metadata merge force server-selected upstream model fields back onto adaptor payloads.
2. Close B2 accepted-upstream/local-failure refund: after upstream accepted, local insert/idempotency failure must not trigger normal pre-consume refund; persist a recovery/outbox record or equivalent durable reconciliation path.
3. Make quality gate green or formally quarantine unrelated failing suites: backend broad tests and frontend `creative-document-assets.test.ts` currently fail.

### P1 — high-priority before production enablement

4. Add user-key rate limiting to creative relay cost endpoints; decide separately whether to override current asset-spec waiver for upload rate limiting.
5. Replace S3-compatible asset client `http.DefaultClient` with managed redirect/SSRF-safe client, or a dedicated no-redirect/validated S3 client.
6. Align video capability gating: either backend bootstrap/model list exposes video relay enabled capability, or frontend filters/disables video routes when the gate is false.
7. Resolve frontend asset URL test contract by setting test origin or changing test expectation; keep strict same-origin semantics.

### P2/P3 — hardening/docs

8. Redact upstream bodies/presigned URLs before logging and add length limits.
9. Close response bodies on all task submit non-200 paths.
10. Cap and validate Suno/MJ list-by-condition IDs.
11. Add orphan-object GC or pre-create pending DB metadata/outbox for S3 uploads.
12. Restrict creative pass_headers/override from forwarding Cookie/X-Creative-* and similar browser-session material.
13. Update docs/spec discoverability: new-api `.env.example`/README/Docker/OpenAPI Creative matrix; opentu SW/main-thread docs and CDN deployment scripts; backend spec index should include `creative-async-task-billing-consistency.md`.
