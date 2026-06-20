# Design — Creative production post-deploy browser acceptance

## Scope

This is an acceptance/verification task, not a code-change task. It verifies the already deployed production candidate via a real browser session.

## Approach

1. Keep automated CLI checks limited to unauthenticated route/API boundaries and version/provenance.
2. Use a real browser session for logged-in checks because production Turnstile may block raw password automation.
3. Capture only safe evidence: route statuses, UI observations, screenshots only if they do not expose secrets/account-sensitive data.
4. Stop before any provider submit/generation or cloud-sync mutation.

## Browser session options

Preferred order:

1. User operates an already logged-in production browser and reports/permits screenshot observations.
2. If a local browser profile is available to the agent with a logged-in session, use it read-only and avoid printing storage/cookies.
3. If neither is available, mark authenticated acceptance as blocked and keep production route smoke evidence separate.

## Checks

- Login/session: `/creative/api/bootstrap` returns authenticated bootstrap in browser context.
- Catalog: `/creative/api/models` returns managed catalog or documented empty state.
- UI: selectors and settings show embedded managed state, not standalone provider setup.
- Parameters: runtime schema-backed image models show parameter controls such as quality/size/ratio where configured.
- Safety: no generate submit; no S3/cloud sync enablement; no provider credentials displayed.

## Rollback / Escalation

- If UI is broken but production route health is fine, document finding and decide whether to rollback image or fix forward.
- If authenticated browser cannot be obtained, do not fabricate acceptance; mark that part blocked and ask for a session path.
