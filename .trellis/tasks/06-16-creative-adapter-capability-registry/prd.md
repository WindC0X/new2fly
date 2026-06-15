# Creative Adapter Capability Registry PRD

## Goal

Build a safe, mock-first plan and implementation path for a `new-api` backed Creative Adapter Capability Registry so embedded OpenTU can render runtime model parameters and submit provider-specific Creative image requests without owning provider credentials, routing, billing, or task semantics.

## User Problem

OpenTU currently shows model lists from new-api, but image model parameters still depend on OpenTU static config. Providers such as Duomi and GrsAI expose the same model names through incompatible APIs, fields, async polling, and result formats. The system needs a model-variant capability layer that can distinguish provider/channel presets, expose safe parameters, and keep all auth, channel, billing, task, and URL privacy logic inside new-api.

## Requirements

1. Freeze a cross-repo contract:
   - catalog `id` is raw backend `bindingId`;
   - `providerModelId` is the upstream model name;
   - `priceModelId` controls billing;
   - OpenTU sends `model=bindingId` and typed `userParams` only.
2. Keep OpenTU free of provider credentials, arbitrary URLs, headers, and provider protocol logic.
3. Add backend-owned parameter schemas and OpenTU runtime schema rendering.
4. Separate user schema params from internal adapter options such as callbacks, idempotency, and modelRef.
5. Add admin validation/dry-run before any production config write.
6. Use fixture-first and mock-first provider development.
7. Do not enable real Duomi/GrsAI calls without explicit later authorization and fixture evidence.
8. Preserve existing Creative security boundaries: session auth, same-origin, nonce, owner-scope fetch, forbidden field guards, no API-key relay.
9. Preserve task billing/idempotency/CAS/outbox/refund guarantees.
10. Ensure image result URLs are sanitized and privatized before browser exposure.

## Out of Scope for Phase A/B/C1

- Real provider calls that consume quota.
- Production rollout beyond disabled/canary/mock bindings.
- Arbitrary admin-configurable URL/header/body DSL.
- Enabling cloud asset sync unless storage mode and production health gates are separately closed.
- Full management UI before validator/dry-run API exists.

## Acceptance Criteria

- [ ] v3 design and implementation plan include all Critical/High findings from the v2 codex-flow audit as hard gates.
- [ ] codex-flow short audit of v3 finds no remaining Critical findings and no unresolved High design blockers for Phase A/B/C1.
- [ ] Phase A implementation is limited to DTO/catalog/schema preview and OpenTU rendering/payload contract; no provider calls.
- [ ] Phase B implementation is limited to admin validator/dry-run and provider fixtures; no provider calls.
- [ ] Phase C1 implementation uses mock upstream only and verifies task/billing/idempotency/CAS/URL-private paths.
- [ ] Duomi presets remain disabled until local captured fixtures exist.
- [ ] GrsAI presets remain dry-run/mock until fixture coverage and explicit real-call authorization exist.
