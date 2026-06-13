# Staging UI / Model List / Crash Fix

## Goal

Fix the issues observed on the persistent local staging deployment:

1. The embedded OpenTU `回到控制台` button is visually covered by the left toolbar/menu area.
2. `new-api` appears to "crash" after initialization, but initial evidence shows the container remains healthy while web/Creative routes hit `429` rate limits.
3. Settings/model-selection UIs still show OpenTU's original default provider/model lists instead of a new-api-managed list suitable for embedded/session-broker usage.

## User Evidence

- Screenshot 1: `回到控制台` button is partially hidden behind the left toolbar/menu.
- Screenshot 2: model benchmark/batch tool selectors show providers/models such as default/OpenAI/Gemini/Qwen/Doubao/Kling/Flux/Midjourney and models such as `gpt-image-2-vip`, `gpt-image-2`, `GPT-4o Image`, indicating OpenTU defaults rather than new-api staging policy.
- User reports new-api seems to crash shortly after initialization.

## Confirmed Facts From Initial Investigation

- Staging container did **not** crash at the time of inspection:
  - `running=true`
  - `restartCount=0`
  - `health=healthy`
  - `/api/status=200`
- Logs show many `429` responses after setup, including static/default routes and `/creative/*` routes/chunks.
- This strongly suggests perceived frontend breakage is caused by global web rate limiting applied to static/Creative assets, not process death.
- `GlobalWebRateLimit()` is mounted before web/static/Creative route handling in `new-api/router/web-router.go`.
- OpenTU model/provider UI code imports default model config and provider profiles, plus runtime discovery/session-broker hooks that need deeper tracing.

## Requirements

1. Fix or configure staging so Creative/static assets are not 429-limited during normal app boot/chunk loading.
2. Preserve protective rate limiting for real API/critical endpoints; do not simply disable all API security limits globally.
3. Fix `回到控制台` button layout so it is fully visible/clickable in the embedded `/creative/` canvas with the left toolbar present.
4. Make embedded/session-broker model lists use new-api-managed data/policy where available, and avoid showing irrelevant OpenTU default provider profiles as the primary selection source.
5. Clarify how model list configuration works for this integration and document the answer in the final report.
6. Rebuild OpenTU artifact, sync into new-api, rebuild staging image, restart staging, and verify.
7. Confirm the staging container remains healthy and no `429` appears for normal `/creative/` route/header checks after the fix.

## Out of Scope Unless Separately Confirmed

- Public/LAN exposure.
- Provider/payment/S3/CDN health checks.
- Production deployment or image push.
- Redesigning the full provider settings UX beyond embedded/new-api policy correctness.
- Creating real generation tasks or spending provider quota.

## Acceptance Criteria

- [ ] Root cause of perceived crash is documented with log evidence.
- [ ] Static/Creative resource 429 issue is fixed or staging config is adjusted with a safe documented reason.
- [ ] `回到控制台` button no longer overlaps with the left toolbar in embedded mode.
- [ ] Model selector/provider list behavior is traced and changed or configured so embedded staging uses new-api/session-broker model policy instead of OpenTU defaults where applicable.
- [ ] User-facing answer explains where/how the model list is configured.
- [ ] Relevant tests or targeted verifications pass.
- [ ] Staging is rebuilt/restarted and `http://localhost:39084/creative/` remains healthy.
- [ ] Smoke + route/header checks pass.
