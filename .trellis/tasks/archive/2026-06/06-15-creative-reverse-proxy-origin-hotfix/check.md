# Check — Creative Reverse-Proxy Origin Hotfix

Date: 2026-06-15

Code commit: `21f675f fix(creative): respect forwarded proto for origin checks` pushed to `WindC0X/new-api feat/creative-embed`.

## Code / Local Verification

- `go test -count=1 ./middleware -run 'TestCreativeOrigin|TestCreativeRejectCrossOriginWhenPresent|TestCreativeRequireNonce'`
  - Result: PASS
- `python3 /mnt/f/code/project/new2fly/scripts/creative_release_gate.py check --source-diff-check --run-new-api-tests`
  - Result: PASS
  - Covered artifact parity, `git diff --check`, new-api Go tests, and `go build ./...`.

## Deployment Verification

Current production container on VPS-A:

```text
new-api-relay new-api-creative-embed:bfef310-originfix Up
image id: sha256:13195b0d9eee788f35e599e1b342e3b20ed46c3b50e096c926e5a65485d20e47
```

Public endpoint baseline after deploy:

```text
https://api.se7endot.top/v1/models              -> 401 application/json
https://console.se7endot.top/login              -> 200 text/html
https://console.se7endot.top/creative/api/bootstrap -> 401 application/json when unauthenticated
```

Route/header assertion after deploy:

- `/creative/` app shell -> 200, `no-cache`
- `/creative/sw.js` -> 200, `no-cache`
- `/creative/version.json` -> 200, `no-cache`
- existing Creative asset -> 200, immutable cache
- missing Creative asset -> 404, non-SPA
- `/creative/api/bootstrap` unauth -> 401, private/no-store
- wrong-method relay GET -> 404, private/no-store
- existing `/v1/models` unauth -> 401
- existing `/login` -> 200

## Production Log Observation

Recent `/creative/api/bootstrap` calls after the hotfix are returning `401` for unauthenticated sessions, not the previous reported `403` same-origin failure. This indicates the request now reaches auth/session handling rather than being blocked by the origin scheme mismatch.

## Authenticated Browser Verification

Direct CLI login smoke was not completed because production password login requires a Turnstile token. No password, cookie, CSRF token, nonce, or access token was recorded in this check file.

Browser-side confirmation was later provided from an authenticated production session:

```js
fetch('/creative/api/bootstrap', { credentials: 'include' })
  .then(async r => {
    const j = await r.json().catch(() => ({}))
    const d = j.data || {}
    console.log({
      status: r.status,
      success: j.success,
      models: Array.isArray(d.models) ? d.models.length : null,
      firstModels: Array.isArray(d.models) ? d.models.slice(0, 5).map(m => ({
        id: m.id,
        type: m.type,
        modality: m.modality,
        endpoints: m.supportedEndpointTypes
      })) : null,
      policyText: d.modelPolicy?.modelsByModality?.text?.length ?? null,
      assetSyncEnabled: d.assetSyncEnabled
    })
  })
```

Observed logged-in result: `status: 200`, `success: true`, `models: 234`. This satisfies the origin hotfix acceptance criterion that authenticated bootstrap reaches session/model handling instead of same-origin 403.

## Final Status

Origin hotfix scope is complete. Remaining Creative model capability/provider-parameter work is intentionally moved to a separate follow-up planning task.

## Known Separate Observation

`creative_release_gate.py check --embedded-smoke-url https://console.se7endot.top/creative/` reached the app shell but failed its settings-dialog assertion: after clicking app menu → 设置, the expected settings dialog text was not visible. This is separate from the reverse-proxy origin hotfix and should be handled as a follow-up UI/e2e issue if reproducible by users.
