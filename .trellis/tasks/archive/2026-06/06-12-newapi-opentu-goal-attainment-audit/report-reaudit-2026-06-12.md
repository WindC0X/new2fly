# Fresh Dynamic Workflow Re-Audit: New API / OpenTU Goal Attainment

Date: 2026-06-12

Scope:

- Orchestration/Trellis workspace: `/mnt/f/code/project/new2fly`
- Backend/API gateway: `/mnt/f/code/project/new-api`
- Frontend/product: `/mnt/f/code/project/opentu`

Evidence rule: this report is based on **current files and fresh workflow/verification outputs only**. It excludes prior reports, archived Trellis task reports, `.codebuddy` reports, older `.codex-flow` journals, and prior assistant conclusions as authoritative evidence.

## Dynamic Workflow Runs

1. Main re-audit workflow
   - File: `.codex-flow/generated/newapi-opentu-goal-attainment-reaudit-2026-06-12.workflow.ts`
   - Journal: `.codex-flow/journal/newapi-opentu-goal-attainment-reaudit-2026-06-12.jsonl`
   - Substantive returned areas: goals/scope, new2fly governance, cross-repo compatibility, quality gates, operations/deployment, synthesis.
   - Missing/timeout coverage was supplemented below.
2. Implementation/security supplement workflow
   - File: `.codex-flow/generated/newapi-opentu-goal-attainment-reaudit-impl-supplement-2026-06-12.workflow.ts`
   - Journal: `.codex-flow/journal/newapi-opentu-goal-attainment-reaudit-impl-supplement-2026-06-12.jsonl`
   - Returned areas: backend implementation/security, frontend implementation/security, cross-repo compatibility, security abuse-boundary.
3. Extracted workflow JSON
   - `.trellis/tasks/06-12-newapi-opentu-goal-attainment-audit/workflow-output-reaudit-2026-06-12.json`

Rerun commands:

```bash
codex-flow run .codex-flow/generated/newapi-opentu-goal-attainment-reaudit-2026-06-12.workflow.ts
codex-flow run .codex-flow/generated/newapi-opentu-goal-attainment-reaudit-impl-supplement-2026-06-12.workflow.ts
```

## Fresh Verification Evidence

Verification logs are under:

`.trellis/tasks/06-12-newapi-opentu-goal-attainment-audit/verification/`

Commands and results:

```bash
(cd ../new-api && go test -count=1 ./router ./middleware ./controller ./model ./service ./relay/...)
```

- Exit: `0`
- Result: passed for targeted backend packages.
- Log: `verification/new-api-go-test-count1-reaudit-2026-06-12.log`

```bash
(cd ../opentu && pnpm nx run drawnix:typecheck)
```

- Exit: `0`
- Result: `NX Successfully ran target typecheck for project drawnix`.
- Log: `verification/opentu-drawnix-typecheck-reaudit-2026-06-12.log`

```bash
(cd ../opentu && pnpm --filter @aitu/drawnix exec vitest run \
  src/services/provider-routing/provider-transport.session-broker.test.ts \
  src/services/__tests__/audio-api-service.test.ts \
  src/services/__tests__/video-api-service.session-broker.test.ts \
  src/services/model-adapters/mj-image-adapter.test.ts \
  src/services/creative-document-assets.test.ts)
```

- Exit: `0`
- Result: 5 test files passed, 50 tests passed.
- Log: `verification/opentu-drawnix-target-vitest-reaudit-2026-06-12.log`
- Note: command emitted known local-test warnings about missing `${NPM_TOKEN}`, crypto fallback, and `indexedDB` in Node test environment, but exited 0.

## Overall Verdict

Status: **partial / not fully accepted as goal-attained**.

Compared with the previous report, fresh verification is materially better: targeted backend Go tests, Opentu Drawnix typecheck, and targeted Opentu Vitest suites now pass. However, the dynamic workflow still found enough confirmed governance, documentation, deployment, security, and implementation risks that the combined project should not be considered fully achieved/release-accepted yet.

Approximate overall score from workflow synthesis: **~58/100**.

## Area Statuses

| Area | Status | Evidence summary |
| --- | --- | --- |
| Goals/scope reconstruction | Partial | Combined goal is reconstructable, but no single authoritative acceptance index exists; docs conflict with active route specs. |
| new2fly/Trellis governance | Partial | Trellis works, but still runs as single-repo; new-api/opentu are not package/git-governed; base specs remain placeholders. |
| Backend implementation/security | Partial | Many Creative boundaries are implemented and tests pass, but idempotency cleanup after provider acceptance is a high-risk confirmed issue. |
| Frontend implementation/security | Partial | Session-broker and asset paths mostly exist; transport/base URL, nonce fail-fast, and audio idempotency fallback issues remain. |
| Cross-repo compatibility | Partial-to-good | Core route matrix mostly aligns; one likely multipart/FormData compatibility risk remains. |
| Quality/CI | Partial | Fresh local targeted checks pass, but CI gates do not yet prove those checks automatically. |
| Operations/deployment/docs | Partial | Current docs/OpenAPI/deployment runbooks are stale or inconsistent with code. |
| Security abuse boundary | Partial | Several strong controls exist, but raw MJ `videoUrl`, cookie `Secure:false`, and CORS defaults remain concerns. |

## Confirmed / High-Priority Findings

### 1. Cross-repo Trellis governance is incomplete

- `new2fly` still operates in single-repo Trellis mode.
- `new-api` and `opentu` are not configured as governed package/git scopes.
- Base backend/frontend specs still contain many scaffolding placeholders.
- `creative-async-task-billing-consistency.md` exists but is not consistently indexed/injected.

Impact: sub-agents and future tasks can miss sibling repo state and high-risk billing/idempotency contracts.

### 2. CI/test gate does not prove goal attainment

Fresh local verification passed, but workflow audit found:

- `new-api` PR/Push CI does not visibly run the same meaningful `go test` gate.
- Opentu CI does not fully cover active spec-required typecheck/lint paths.
- Coverage thresholds and cross-repo e2e acceptance are still missing.

Impact: local checks passing is useful, but the project lacks automated proof that future changes preserve the goal.

### 3. Creative API docs and route matrix conflict with current code/specs

Dynamic workflow found current documentation drift:

- Creative Embed API matrix describes stale or wrong Suno/MJ paths such as `/music*` / `/images/*` style routes.
- Active specs and source use canonical `/creative/relay/v1/suno/...` and `/creative/relay/v1/mj/...` routes.
- Machine-readable OpenAPI/route docs lag behind current Creative routes.

Impact: integration, SDK generation, and acceptance tests can be written against wrong routes.

### 4. Opentu deployment runbook is not reliable

Findings include:

- Deployment docs list commands/envs that do not match current `package.json` scripts.
- NPM/CDN docs still promise artifacts or behavior not reflected by current scripts/runtime.
- Multi-CDN documentation is inconsistent with current jsDelivr-only runtime behavior.

Impact: deployment operators following docs can fail or validate the wrong behavior.

### 5. Backend idempotency cleanup after provider acceptance is risky

Backend supplement confirmed:

- Video/Suno/MJ submit guards delete scoped idempotency rows on any final response status `>=400` after `c.Next()`.
- The billing/idempotency contract requires keeping safe replay/recovery state if provider accepted the task but local insert/settle/idempotency completion later fails.

Impact: retry can create duplicate upstream tasks, double external cost, or inconsistent billing/task state.

### 6. Frontend session-broker base URL invariant can be broken after validation

Frontend supplement confirmed:

- `provider-transport.ts` validates session-broker base URL as `/creative/relay/v1`, but later still applies `request.baseUrlStrategy`.
- A `trim-v1` strategy can turn `/creative/relay/v1` into `/creative/relay` after validation.

Impact: future or misconfigured session-broker calls can hit wrong routes.

### 7. Frontend unsafe asset/document mutations do not fail fast without CSRF/nonce

Frontend supplement confirmed:

- `getCreativeSessionAuthHeaders()` returns `{}` if auth material is missing.
- Asset/document POST/PUT/DELETE paths can still attempt fetch without local fail-fast.
- Relay transport already has the stricter fail-fast behavior, so asset/document paths are inconsistent.

Impact: backend should reject, but frontend violates the desired “do not send mutation without Creative auth material” contract.

### 8. MJ fetch DTO may expose raw provider `videoUrl`

Security supplement confirmed:

- MJ image result is proxied through owner-scoped Creative proxy.
- But `creativeMJTaskDTO` still copies task data `videoUrl` into the public DTO.

Impact: if upstream/provider `videoUrl` contains signed/private URL material, browser-visible DTO can leak raw provider URL.

### 9. Session cookie and CORS defaults need hardening

Security supplement found:

- session cookie uses `Secure: false` in current code.
- global CORS is wildcard + credentials style, while Creative relies on stricter same-origin/nonce controls.

Impact: mitigated partly by SameSite/Creative middleware, but not an ideal production security posture.

### 10. Cross-repo multipart/FormData compatibility is likely risky

Cross-repo supplement found a likely issue:

- Backend may pre-read multipart model fields and clean FormData before downstream processing.
- This can break frontend reference-image/multipart requests if the downstream expects the form body/files intact.

Impact: possible media/reference-image request breakage; needs targeted reproduction or test.

## Verified Non-Issues / Corrections

The fresh workflow and follow-up checks also confirmed several earlier suspected problems are **not current blockers**:

1. Creative NoRoute/no-store is covered by current cache/router code and tests.
2. MJ `image_url` / `imageUrl` mismatch is not supported by current Creative DTO behavior; Creative returns `imageUrl` and normalizes stored keys.
3. Suno/MJ canonical frontend/backend paths are aligned with active specs.
4. Video relay disabled path returns unsupported behavior rather than direct-provider fallback.
5. Creative unsafe requests have same-origin + nonce/CSRF boundary.
6. Forbidden relay material is checked before distribution.
7. Creative API/relay and private content paths have no-store controls.
8. Outbound redirect SSRF validation and sensitive header stripping are implemented for the managed HTTP client.
9. Creative asset production/S3 fail-closed and owner-scope baseline are present.
10. Targeted backend/frontend tests now pass locally.

## Recommended Next Actions

1. Fix/backend harden Creative async submit idempotency after provider acceptance.
2. Add a regression test for multipart/FormData frontend reference-image flow through backend relay.
3. Remove raw provider `videoUrl` from Creative MJ public DTO or route it through owner-scoped proxy.
4. Make session-broker transport ignore/reject `baseUrlStrategy` for `/creative/relay/v1`.
5. Make asset/document unsafe mutations fail fast when CSRF/nonce material is missing.
6. Add `new-api` and `opentu` as governed Trellis package/git scopes, or create an explicit cross-repo governance mechanism.
7. Index/inject `creative-async-task-billing-consistency.md` everywhere relevant.
8. Fix Creative route docs/OpenAPI and Opentu deployment/CDN/NPM docs.
9. Move the fresh verification commands into CI gates and publish artifacts/coverage thresholds.
10. Add a single combined Creative Embed acceptance index mapping specs → routes → tests → deployment checks.

## Caveats

- No production or external endpoint was called.
- No secrets were read or printed.
- Build/deploy/docker commands were not run; only targeted backend/frontend tests and typecheck were executed.
- Some workflow branches used static source review; runtime behavior still needs e2e smoke validation.
