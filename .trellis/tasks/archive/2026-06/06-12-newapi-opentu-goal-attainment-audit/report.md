# New API / OpenTU Goal Attainment Audit Report

Date: 2026-06-12
Scope:

- Orchestration/Trellis workspace: `/mnt/f/code/project/new2fly`
- Backend/API gateway: `/mnt/f/code/project/new-api`
- Frontend/product: `/mnt/f/code/project/opentu`

Evidence rule: current files, configs, docs, tests, workflow outputs, and fresh verification commands only. Prior reports, archived task reports, `.codebuddy` reports, and prior assistant conclusions were excluded as authoritative evidence.

## Workflow Runs

1. Primary dynamic workflow:
   - File: `.codex-flow/generated/newapi-opentu-goal-attainment-audit.workflow.ts`
   - Journal: `.codex-flow/journal/newapi-opentu-goal-attainment-audit.jsonl`
   - Result: completed synthesis with two returned branches; five broad branches timed out, so their incomplete results were not treated as sufficient.
2. Supplemental dynamic workflow:
   - File: `.codex-flow/generated/newapi-opentu-goal-attainment-supplement.workflow.ts`
   - Journal: `.codex-flow/journal/newapi-opentu-goal-attainment-supplement.jsonl`
   - Result: five focused branches completed: backend, frontend, end-to-end compatibility, quality verification, and ops/deployment.

Rerun commands:

```bash
codex-flow run .codex-flow/generated/newapi-opentu-goal-attainment-audit.workflow.ts
codex-flow run .codex-flow/generated/newapi-opentu-goal-attainment-supplement.workflow.ts
```

## Fresh Verification Commands

```bash
(cd ../new-api && go test ./router ./middleware ./controller ./model ./service ./relay/...)
```

Exit: 1. Failures observed:

- `relay/channel/claude`: `TestRequestOpenAI2ClaudeMessage_IgnoresUnsupportedFileContent`, `TestRequestOpenAI2ClaudeMessage_SupportsPDFFileContent`, `TestRequestOpenAI2ClaudeMessage_ConvertsTextFileContentToText`.
- `relay/helper`: `TestStreamScannerHandler_StreamStatus_PreInitialized`.

```bash
(cd ../opentu && pnpm nx run drawnix:typecheck)
```

Exit: 0. `NX Successfully ran target typecheck for project drawnix`.

```bash
(cd ../opentu && pnpm --filter @aitu/drawnix exec vitest run \
  src/services/provider-routing/provider-transport.session-broker.test.ts \
  src/services/__tests__/audio-api-service.test.ts \
  src/services/__tests__/video-api-service.session-broker.test.ts \
  src/services/model-adapters/mj-image-adapter.test.ts \
  src/services/creative-document-assets.test.ts)
```

Exit: 1. Failure observed:

- `src/services/creative-document-assets.test.ts > creative document asset preparation > recognizes only query-free same-origin creative asset content refs`
  - expected `isCreativeAssetContentUrl('http://localhost/creative/api/assets/asset_123/content')` to be `true`; received `false`.

## Overall Verdict

Status: **partial / not yet fully achieved**.

The current project appears directionally aligned with the development goal: `new-api` and `opentu` now contain substantial current-code evidence for a `/creative` embedded AI creation workflow with session-broker routing, asset sync, async video/Suno/MJ relay, idempotency, owner-scope, and credential-stripping/security boundaries.

However, it cannot be considered fully achieved because:

1. Fresh verification has failing backend and frontend tests.
2. Several cross-repo contract and deployment/documentation gaps remain.
3. The strongest evidence is still mostly static source/test coverage, not a passing end-to-end `/creative` runtime validation.

## Area Statuses

| Area | Status | Approx. score | Key reason |
| --- | --- | ---: | --- |
| Goal/source reconstruction | Partial | 70/100 | Goal and acceptance contract can be reconstructed from README + active Trellis specs + code, but runtime proof is missing. |
| Backend implementation/security | Partial | 74/100 | Core routes/session/asset/billing/key-affinity are present; remaining concerns are storage/redirect hardening and other narrower contract gaps. |
| Frontend implementation | Partial | 78/100 | Main session-broker, credential stripping, no-fallback, asset prepare/hydrate, SW pass-through are present, but several fail-fast/canonical/idempotency issues remain. |
| End-to-end compatibility | Partial | 63/100 | Route/header/path contracts mostly align, but video capability gating and GET same-origin assumptions can still break real flows. |
| Quality/verification readiness | Partial | 58/100 | Test files exist; opentu has stronger CI. Fresh checks still fail, and cross-repo e2e gate is missing. |
| Operations/deployment readiness | Partial | 52/100 | Critical Creative env/config/deploy docs are missing or stale. |
| Documentation/spec drift | Partial | 58/100 | Current implementation has outpaced README/OpenAPI/Opentu architecture docs/Trellis indexes. |

## Highest-Priority Findings and Peer-Review Corrections

### 1. Fresh verification fails

Evidence:

- `go test ./router ./middleware ./controller ./model ./service ./relay/...` failed in `../new-api`.
- Targeted `@aitu/drawnix` Vitest suite failed in `../opentu`.
- `pnpm nx run drawnix:typecheck` passed.

Impact: project cannot be marked as achieved or release-ready while current verification commands fail.

### 2. Correction: Creative route no-store / NoRoute is covered in current code

Follow-up verification after peer review found this original finding was not supported by current code.

Evidence:

- `../new-api/middleware/cache.go:21-25` sets `Cache-Control: private, no-store` and `Pragma: no-cache` for `/creative/api*` and `/creative/relay*` before routing.
- `../new-api/router/main.go:36-44` sets Creative no-store headers for `/creative/api*` and `/creative/relay*` `NoRoute` handling when `FRONTEND_BASE_URL` is used.
- `../new-api/router/web_router_test.go:160-196` covers missing, wrong-method, and trailing-slash Creative API/relay paths and asserts `no-store`.

Impact: this item should not be treated as a release blocker unless future code removes those guards or tests fail.

### 3. S3 asset storage uses `http.DefaultClient`, bypassing managed redirect/SSRF policy

Evidence:

- `../new-api/service/http_client.go` defines managed redirect-sensitive-header behavior.
- `../new-api/service/creative_asset.go` initializes S3-compatible storage with `http.DefaultClient`.

Impact: signed S3-compatible asset operations may not inherit the same redirect/secret stripping policy as other outbound fetch paths.

### 4. Correction: MJ `image_url` / `imageUrl` mismatch is not supported by current code

Follow-up verification after peer review found this original finding was based on the legacy `MidjourneyWithoutStatus` DTO, not the Creative DTO returned by the current route.

Evidence:

- `../new-api/dto/midjourney.go:47-60` defines `MidjourneyDto.ImageUrl` with JSON tag `imageUrl`.
- `../new-api/controller/creative.go:1058-1097` returns `dto.MidjourneyDto` from Creative MJ fetch and sets `ImageUrl` to the Creative image proxy URL on success.
- `../new-api/controller/creative.go:1150-1164` normalizes task data keys, so raw `image_url` / `imageUrl` style differences in stored task data are tolerated.
- `../opentu/packages/drawnix/src/services/model-adapters/mj-image-adapter.ts:16-20,229-235` expects `imageUrl`, matching the Creative DTO.

Impact: this item should be removed from the blocker list; MJ still deserves end-to-end testing, but not because of this field-name mismatch.

### 5. Video relay capability can be disabled while frontend still routes to it

Evidence:

- `../new-api/controller/creative.go` gates video relay with `CREATIVE_VIDEO_RELAY_ENABLED`, defaulting false.
- `../opentu/packages/drawnix/src/services/video-api-service.ts` routes session-broker video submit/fetch/content to `/creative/relay/v1/videos*`.

Impact: if bootstrap/model pool exposes video models while the backend gate is disabled, Opentu video generation fails by configuration rather than capability-aware UX.

### 6. Frontend asset content URL recognition currently fails a targeted test

Evidence:

- `creative-document-assets.test.ts` expected `http://localhost/creative/api/assets/asset_123/content` to be recognized as same-origin creative asset content URL but received false.

Impact: asset hydrate/prepare behavior can reject or mishandle valid same-origin absolute URLs in current test conditions.

### 7. Opentu architecture docs still describe old Service Worker execution model

Evidence from documentation branch:

- `../opentu/docs/FEATURE_FLOWS.md`, `../opentu/docs/SW_ARCHITECTURE.md`, and `../opentu/docs/CONCEPTS.md` still describe AI task execution in Service Worker.
- Current source comments in task queue code indicate LLM task execution has moved to the main thread.

Impact: maintainers can implement against stale architecture, causing regressions.

### 8. Creative deployment/configuration docs are incomplete

Evidence:

- `../new-api/service/creative_asset.go` and `../new-api/controller/creative.go` define `CREATIVE_*` gates/configs.
- `../new-api/.env.example`, README, Docker Compose, and OpenAPI docs do not document the full Creative configuration matrix.
- `../opentu/docs/CDN_DEPLOYMENT.md` includes deploy commands that do not match current `../opentu/package.json` scripts.

Impact: current code may be difficult to deploy, enable, rollback, or support safely.

## Recommended Next Actions

1. Fix current verification blockers first:
   - new-api Claude relay conversion tests;
   - new-api stream scanner status test;
   - opentu creative asset same-origin URL recognition test.
2. Add/repair cross-repo contract tests for:
   - video relay disabled capability filtering;
   - Creative no-route/no-method no-store behavior;
   - session-broker GET with absent/limited Referer/Origin.
3. Harden backend asset storage HTTP client redirect policy.
4. Make frontend session-broker transport reject or ignore `baseUrlStrategy` and make asset upload fail-fast when CSRF/nonce material is unavailable.
5. Add a real local `/creative` smoke test: bootstrap, model pool, asset upload/hydrate, video/Suno/MJ submit/fetch/content, browser no-upstream-key check.
6. Update docs before release handoff:
   - new-api Creative env/deploy/OpenAPI docs;
   - opentu FEATURE_FLOWS/SW_ARCHITECTURE/CONCEPTS;
   - opentu CDN/deploy scripts docs;
   - Trellis backend index for billing consistency spec.

## Confidence and Caveats

- Confidence: medium-high for static code/doc findings; high for fresh command outputs.
- Runtime caveat: no service was launched; no production/local HTTP endpoint was called.
- The result is about current local state, including uncommitted changes in all involved repos.
