# New API Opentu Creative Integration Remediation

## Goal

Turn the external deep-goal audit feedback into an evidence-driven remediation plan and implementation path for the new-api / opentu `/creative` integration. The task must not repeat the previous too-narrow success definition: completion requires the actual production embed path, multimodal relay coverage decisions, embedded provider-gateway enforcement, cloud sync boundaries, return-to-console UX, and broad validation to be addressed or explicitly split with traceable acceptance criteria.

## User Value

An authenticated new-api user should be able to open `/creative`, use opentu through new-api as the secure session-broker gateway, generate supported content without configuring upstream API keys, return to the main new-api console, and rely on safe cloud sync without leaking secrets or silently losing assets.

## Confirmed Facts

See `research/external-audit-fact-check.md` for evidence. Current confirmed facts:

- `new-api/main.go` embeds `web/creative/dist`, while the latest copied opentu production build is in `new-api/router/web/creative/dist` and matches `opentu/dist/apps/web`.
- `new-api/web/creative/dist` is not fixture, but it is stale relative to the latest opentu dist and router test fixture path.
- `/creative/relay/v1` currently registers `POST /chat/completions`; `/creative/relay/v1/images/generations` is not mounted.
- Return-to-console UX is not confirmed implemented; existing task `.trellis/tasks/06-08-add-return-to-console-button-in-opentu` should be reused.
- Previous verification covered targeted Go/Vitest/typecheck subsets, not full `tsconfig.spec.json`, full builds, or E2E.

## Requirements

### R1 — Production embed path consistency

- The actual production embed path used by `new-api/main.go` must be updated to the latest `/creative` opentu production build, or the architecture must be changed so production and tests share one authoritative creative dist path.
- Tests must cover the same path that production embeds, not only a router-local fixture path.
- The embedded dist must contain no stale fixture markers and must use `/creative/assets/...` for entry JS/CSS.

### R2 — Creative relay endpoint coverage

- At minimum, image generation must have a working creative relay route if opentu uses `/creative/relay/v1/images/generations` or an equivalent image endpoint in embedded mode.
- Chat route coverage must remain intact.
- Video, Suno, and MJ must be dynamically audited against opentu callers and new-api relay capabilities, then either implemented with tests or split into explicit follow-up child tasks if they require larger async/idempotency/CAS work.

### R3 — Embedded mode provider gateway enforcement

- In `/creative` embedded mode, generation traffic must use the new-api session-broker provider by default and must not silently fall back to direct legacy upstream API key/base URL paths.
- Direct/legacy provider UI may remain available only if it cannot bypass the embedded gateway unintentionally; any exception must be explicit, visible, and safe.
- URL API key/settings material must remain ignored/stripped in embedded mode.

### R4 — Return-to-console UX

- Opentu embedded `/creative` must expose a clear way to return to the main new-api console.
- Reuse or link the existing `06-08-add-return-to-console-button-in-opentu` task; do not duplicate divergent UX work.

### R5 — Cloud sync boundaries and asset handling

- Existing JSON document snapshot sync must remain safe: allowlist schema, revision/baseRevision, conflict freeze, and secret sanitizer.
- Binary/media/audio/image asset references must be audited. If true binary cloud sync is required for current opentu boards, design and implement a minimum viable asset persistence path, or create a separate child task with blockers and acceptance criteria.
- No API keys, upstream tokens, Authorization headers, cookies, CSRF, nonce, baseUrl overrides, provider settings, or internal new-api tokens may be cloud-synced.

### R6 — Validation scope

- Re-run targeted tests from prior work after fixes.
- Add validation for production embed path identity.
- Run or explain blockers for broader validation: new-api relevant/full Go suites, opentu spec typecheck, opentu build, opentu full/targeted Vitest, and browser E2E smoke for fresh `/creative`.

## Acceptance Criteria

- [x] Dynamic workflow produces a fresh evidence pack for all seven external audit items, with each item marked `confirmed`, `fixed`, `split`, or `not applicable` with file/command evidence.
- [x] Production `new-api/web/creative/dist` and the authoritative opentu build are synchronized, or one authoritative embed path is used by both production and tests.
- [x] Tests fail on stale production creative dist and pass after synchronization.
- [x] `/creative/relay/v1/images/generations` or the implemented image relay equivalent is mounted, protected by the same session-broker / CSRF / nonce / forbidden-field controls, and covered by tests.
- [x] Chat route tests remain passing.
- [x] Video/Suno/MJ relay scope is either implemented with async/idempotency/refund tests or explicitly split into child task(s) with documented blockers.
- [x] Embedded mode cannot unintentionally bypass new-api as provider gateway; tests cover direct provider fallback prevention or an explicit safe exception.
- [x] Return-to-console task is linked or implemented and validated in opentu.
- [x] Asset sync gap is either closed for the MVP asset types or split into a child task with acceptance criteria; existing document sync safety tests still pass.
- [x] `pnpm exec tsc -p packages/drawnix/tsconfig.spec.json --noEmit` is run; failures are fixed or logged as separate scoped follow-up only if unrelated to this integration.
- [x] Final report lists exact commands run, pass/fail status, remaining child tasks, and rerun commands.

## Final Closure

Final parent closure evidence is recorded in `research/final-parent-closure-2026-06-11.md`. All six child deliverables are archived and no parent-scoped follow-up remains.

## Out of Scope Unless Explicitly Pulled In

- Full real-time multiplayer collaboration / CRDT.
- Complete redesign of opentu provider settings unrelated to embedded gateway safety.
- Broad new-api relay refactors outside routes and guards needed for creative paths.
- Production deployment, remote push, or destructive git cleanup.

## Open Product/Scope Decisions

- Whether video/Suno/MJ are required in the immediate fix tranche or may be child tasks after image relay + gateway enforcement. Recommended default: split if the dynamic workflow confirms they require async idempotency/CAS refund work beyond simple route mounting.
- Whether asset binary cloud sync is a hard blocker for initial `/creative` release or can be a follow-up after JSON document sync and asset-reference safety are proven. Recommended default: audit first; implement only minimum asset path needed by current board elements.
