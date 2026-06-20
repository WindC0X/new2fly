# Creative production post-deploy browser acceptance

## Goal

Verify the deployed production Creative `/creative/` surface with a real browser/login session after candidate rollout: authenticated UI, model catalog, parameter panel, session-broker behavior, and standalone OpenTU surface cleanup without provider generation or cloud-sync enablement.

## User Value

- Confirms the production deployment works for a real logged-in New API user, not only unauthenticated route smoke.
- Catches regressions visible only in browser UI: missing models, missing parameters, old OpenTU settings/APIKey surfaces, GitHub/Gist standalone sync prompts, feedback/GitHub buttons, and loading stalls.
- Avoids accidental provider billing/generation while still validating model catalog and UI readiness.

## Confirmed Facts

- Production deployment is already on `new-api-creative-embed:53b8f54`.
- Public route smoke and production embedded Playwright smoke passed.
- `/creative/version.json` reports OpenTU commit `0b584e2cf7c622b9fa431b3bf39b4a86055699bc`.
- Production has Turnstile/auth constraints; CLI password login may not be viable.
- Phase 1 keeps `CREATIVE_ASSET_SYNC_ENABLED=false`; cloud sync/S3 smoke is out of scope.
- Duomi/GrsAI live adapters are not implemented and must not be treated as available.

## Requirements

### R1 — Authenticated browser acceptance

- Verify `/creative/` while logged in through the production console domain.
- Do not bypass auth with API tokens.
- Do not print cookies, session IDs, CSRF tokens, nonces, passwords, or localStorage/sessionStorage values.

### R2 — UI/product checks

- The app loads past the boot/loading screen.
- The left/bottom navigation does not obscure critical controls such as return-to-console.
- Embedded mode does not show standalone OpenTU provider setup, API key setup, GitHub/Gist cloud sync setup, feedback group image, or public GitHub button as user-facing required actions.
- Cloud sync copy, if visible, must be Phase 1-safe: disabled/unavailable/local-saved wording is acceptable; S3-backed sync must not appear enabled unless separately configured.

### R3 — Model catalog and parameter checks

- Authenticated `/creative/api/models` loads a non-empty managed catalog when production channels/policy expose models.
- Model selectors use `New API Creative` / managed session-broker catalog, not OpenTU standalone defaults.
- Image model parameter UI appears when backend runtime schema provides parameters.
- No accidental `#img`-only fallback or empty parameter panel for schema-backed image models.
- If no production binding is configured for a given modality, UI should fail closed with clear unavailable state rather than showing stale defaults.

### R4 — No provider mutation

- Do not click final generate/submit buttons that would call upstream providers or consume quota.
- Network inspection may verify catalog/bootstrap/UI resources, but not provider generation.

## Acceptance Criteria

- [ ] A real authenticated browser session reaches `/creative/` in production.
- [ ] App shell loads and UI controls are usable.
- [ ] Managed model catalog is observed or an intentional empty-catalog state is documented.
- [ ] Parameter panel behavior is verified for available managed image models.
- [ ] Standalone OpenTU setup/APIKey/GitHub/feedback surfaces are absent or non-blocking in embedded mode.
- [ ] No provider generation, payment, or cloud-sync mutation is triggered.
- [ ] Evidence is recorded without secrets.

## Out of Scope

- Implementing Duomi/GrsAI live adapters.
- Running actual image/video/audio generation.
- Enabling Creative cloud sync/S3.
- Modifying production channels/model policy unless a separate task is created.
- Debugging unrelated browser/device-specific UX issues beyond documenting them.

## Open Questions

- How will the authenticated production browser session be provided? Recommended: use an existing logged-in browser profile or user-driven browser session; do not handle raw session cookies in task files or chat.
