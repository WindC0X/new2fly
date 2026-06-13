# Design — Staging UI / Model List / Crash Fix

## Debugging Approach

Use evidence-first debugging:

1. Validate process health and logs before assuming crash.
2. Reproduce/trace `429` source to rate limiter and route scope.
3. Trace `回到控制台` button component/CSS and embedded toolbar layout.
4. Trace model/provider list data flow from new-api `/creative/api/bootstrap`/models to OpenTU runtime discovery and each affected selector.

## Suspected Fix Areas

### 1. Web/Creative 429

Likely backend fix or staging config:

- Prefer backend route-level fix: do not apply `GlobalWebRateLimit` to static/app-shell assets such as `/creative/`, `/creative/assets/*`, `/creative/sw.js`, `/creative/version.json`, and default static chunks.
- Keep API/critical limits unchanged.
- If risk is too high for generic web, at minimum exempt Creative static/app-shell paths from global web limiter because they are required for embedded app boot and do not mutate state.

### 2. `回到控制台` overlap

Likely frontend CSS/layout fix:

- Locate embedded console/back button component.
- Ensure embedded chrome top-left area is offset from the vertical toolbar width or has safe spacing/z-index.
- Avoid covering or disabling toolbar interactions.

### 3. Model list / provider policy

Likely frontend+backend contract fix:

- New-api should be the source of truth for embedded session-broker model availability.
- OpenTU default provider profiles are acceptable as standalone fallback but should not dominate embedded UI.
- Model selectors in settings/model benchmark/batch image tools should consume runtime/session-broker discovered model lists or a new-api-provided display policy.
- If backend lacks enough data, document current setting path and implement a minimal embedded policy to filter/default to new-api broker profiles.

## Verification Plan

- Backend unit/router tests for Creative static paths not being web-rate-limited, if feasible.
- Frontend typecheck and targeted tests for runtime model/session-broker behavior where feasible.
- Rebuild OpenTU web artifact with `/creative/` base, sync to new-api, run release gate.
- Rebuild `new-api-creative-embed:staging-current`, restart compose staging.
- Verify:
  - `/creative/` smoke passes.
  - route/header table has no `429` for checked Creative static/API/relay paths.
  - container remains healthy.
  - manual/browser-accessible URL remains available.

## Safety

- Do not read/print existing secrets.
- Do not call provider/payment/S3/CDN endpoints.
- Do not run generation jobs.
- Do not push Docker image or deploy public service.
