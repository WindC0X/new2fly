# Creative production hardening after final audit

## Goal

Harden the embedded OpenTU Creative integration after the 2026-06-19 final goal-attainment audit so Phase 1 can be treated as a reviewable, evidence-backed production candidate rather than merely a code-level implementation.

## User Value

- Existing New API users, channels, quotas, tokens, and model configuration remain protected during Creative rollout.
- OpenTU Creative users stay inside a managed New API session-broker surface without browser-visible provider credentials or misleading standalone/provider UI.
- Operators get reliable release gates, smoke checks, rollback/provenance evidence, and fail-closed runtime behavior before expanding to cloud sync, video relay, or live provider adapters.

## Confirmed Facts

- Final verified synthesis produced 13 verified findings:
  - Code-level Phase 1 is basically in place.
  - Production-level readiness is conditional because several runtime checks and release-hardening issues remain.
- Must-fix items from verified synthesis:
  1. Release/docker CI must enforce Creative release gate, Go tests, and embedded browser smoke.
  2. Production smoke scripts must not silently skip TLS validation and must have realistic curl timeouts.
  3. Relay `copy_header` / `move_header` must not forward sensitive browser/session headers upstream.
  4. Creative video content proxy must fail closed by platform/video allowlist before any broader video relay expansion.
  5. Asset sync must not allow accidental DB-backed production enablement by setting only `CREATIVE_ASSET_SYNC_ENABLED=true`.
- Should-fix items in scope for this task where they are small enough to include:
  - Runbook candidate refs/provenance must be updated to current refs or explicitly marked as example/stale-sensitive.
  - `FRONTEND_BASE_URL` trap should be guarded by docs/smoke assertions, not silently accepted.
  - Embedded model parameter behavior should not silently drop user-selected params for managed models without runtime schema.
- Accepted risk:
  - `providerModelId` / `priceModelId` are allowed public Creative model/price metadata under current spec, provided channel IDs, provider URLs, API keys, upstream task IDs, and private result URLs stay hidden.

## Requirements

### R1 — Release gate and CI hardening

- Add or update repository release automation so New API image/release paths cannot skip Creative-specific checks.
- The gate must include at minimum:
  - relevant Go tests for Creative backend/router/service paths;
  - embedded dist contract check;
  - embedded Playwright smoke when a candidate server URL is available;
  - source diff / no accidental generated drift checks.
- If CI cannot stand up the full production candidate server, document the exact manual required gate and make the CI gap explicit.

### R2 — Production smoke reliability

- Update `ops/newapi-opentu-production/creative-route-check.sh` and `creative-cloud-sync-smoke.sh` so public checks have:
  - sane connection and total timeouts;
  - no unconditional `curl -k` for public HTTPS;
  - an explicit opt-in insecure mode only for controlled/private targets;
  - no secret/cookie/body leakage.
- Update the runbook with the strict TLS/default timeout behavior.

### R3 — Relay sensitive header safety

- Prevent `copy_header` / `move_header` param override paths from forwarding sensitive browser/session headers upstream.
- Reuse or centralize the same sensitive-header denylist used by pass-through headers where practical.
- Add regression tests for `Cookie`, `Authorization`, `X-Creative-CSRF`, `X-Creative-Nonce`, and at least one safe header.

### R4 — Video content proxy platform fail-closed

- Ensure `/creative/relay/v1/videos/:task_id/content` only serves owner-scoped video-platform tasks.
- Same-user non-video success tasks must return a safe error instead of attempting proxy/content lookup.
- Add regression tests.

### R5 — Asset sync production config hard-fail

- If `CREATIVE_ASSET_SYNC_ENABLED=true`, production-like rollout must require non-database storage unless explicitly non-production/local.
- Production enablement must require `CREATIVE_ASSET_ROLLOUT_MODE=production`, `CREATIVE_ASSET_STORAGE=s3-compatible`, and complete S3-compatible config.
- Misconfigured production cloud sync must fail closed early with a clear, non-secret error.
- Existing Phase 1 disabled mode must remain unchanged.

### R6 — Embedded model parameter behavior

- Avoid silent dropping of selected parameters for managed models without runtime `parameterSchema`.
- Prefer one of:
  - backend supplies schema for exposed managed models; or
  - frontend treats no-schema managed models as legacy/static-parameter compatible rather than schema-backed.
- Add targeted tests for gpt-image-2/nano-banana-like image params and `#img` fallback behavior.

### R7 — Documentation and provenance

- Update production runbook candidate refs/provenance guidance to the current branch realities and image digest expectations.
- Keep `.codex/config.toml` local drift out of commits.

## Acceptance Criteria

- [ ] Relevant backend tests pass for Creative relay/header, video content, asset config, model policy/bindings, and router paths.
- [ ] Relevant frontend tests pass for embedded model params and standalone surface guards.
- [ ] `python3 scripts/creative_release_gate.py check --source-diff-check --run-new-api-tests` passes, or the runbook explains any intentionally separate gate command.
- [ ] Production ops scripts lint with `bash -n` and include default strict TLS + timeouts.
- [ ] New/updated tests would fail on the verified audit regressions.
- [ ] Runbook documents current candidate refs/provenance, strict smoke behavior, runtime-only checks, and rollback expectations.
- [ ] No secrets, `.env`, DB contents, cookies, CSRF tokens, or provider credentials are printed or committed.

## Out of Scope

- Enabling production cloud sync with real S3/R2/OSS credentials.
- Implementing real Duomi/GrsAI live provider adapters.
- Changing accepted public metadata policy for `providerModelId` / `priceModelId`.
- Destructive DB/schema rollback.
- Production credential smoke unless separately authorized.

## Open Questions

None blocking planning. The verified audit already establishes scope and priority.
