# Creative Model Policy Unification Implementation Plan

## Current Status

Implementation and baseline verification completed locally. Final dynamic-workflow goal-attainment audit is still pending; any findings from that audit must be fixed and rechecked before wrap-up.

## Work Packages

### P0 — Planning and contracts

- [x] Clarify ownership: `new-api` owns channel routing and policy; OpenTU owns embedded presentation only.
- [x] Decide admin default/recommended policy scope: global + per-user-group overrides in `new-api`.
- [x] After implementation, add/update Trellis specs for backend/frontend Creative model policy contract.

### P1 — new-api backend policy service

- Add normalized policy types and helpers, likely in a dedicated service/model file:
  - parse `creative.model_policy` from `common.OptionMap` / `options`;
  - normalize schema;
  - reject unsafe keys/structures;
  - filter policy by available model set;
  - calculate `modelPolicyVersion`.
- Add tests for:
  - empty policy;
  - global defaults;
  - group override;
  - unavailable/stale model filtering;
  - unsafe field rejection;
  - dedupe/order preservation.

### P2 — new-api session/admin APIs

- Extend `GET /creative/api/bootstrap` with `modelPolicy` and optional `modelPolicyVersion`.
- Keep `GET /creative/api/models` backward compatible.
- Add root/admin-only endpoints:
  - `GET /api/creative/model-policy`;
  - `PUT /api/creative/model-policy`.
- Return group/model-pool data needed by the admin UI.
- Add router/controller tests for:
  - no channel/secret leakage;
  - browser session bootstrap effective filtering;
  - admin save validation;
  - stale diagnostics.

### P3 — new-api admin UI

- Add `Creative Model Policy` section under system settings models.
- Add API client types for the dedicated policy endpoints.
- Implement at minimum a validated policy editor with group/model-pool preview; prefer dropdown/multiselect controls per modality if time allows.
- Ensure stale saved entries are visible and cleanup is possible.
- Add TypeScript/unit tests where existing patterns support them.

### P4 — OpenTU central resolver

- Add central embedded policy resolver.
- Update `creative-session-broker.ts` to ingest bootstrap `modelPolicy` and rerun reconciliation on catalog refresh.
- Update `creative-display-policy.ts` so embedded mode no longer uses static OpenTU defaults as fallback.
- Add tests covering:
  - admin default wins after user preference missing;
  - user preference wins only when still available;
  - static-only defaults are ignored;
  - empty catalog returns unavailable state.

### P5 — OpenTU selector/component migration

Update primary selectors and model boxes to use the resolver in embedded mode:

- dock / AI input model selectors and dropdowns;
- ChatDrawer model selector;
- settings model list/defaults;
- benchmark/workbench/tool windows;
- video analyzer model dropdowns;
- MCP/canvas operation defaults.

Acceptance for every migrated surface: static-only OpenTU models must not appear when absent from `/creative/api/models`.

### P6 — OpenTU generation fail-closed migration

- Update generation services/adapters so embedded mode requires a validated `new-api-creative` model ref.
- Block before relay/provider calls if no valid model exists for the modality.
- Add regression tests for image/video/audio/text submit paths.

### P7 — Cross-repo artifact sync and specs

- Build OpenTU embedded artifact with `VITE_BASE_URL=/creative/ pnpm build:web`.
- Sync `opentu/dist/apps/web/` into both `new-api` Creative dist trees.
- Run `python3 scripts/creative_release_gate.py check` from `new2fly` after sync.
- Update Trellis specs:
  - backend Creative model policy/security boundary;
  - frontend Creative embedded release/model policy contract.

### P8 — Verification and final audit

Baseline checks:

- new-api targeted Go tests for Creative/model policy/router/controller.
- OpenTU targeted Vitest/unit tests for resolver/session broker/selectors/services.
- OpenTU typecheck/build for changed packages.
- Creative artifact identity gate in `new2fly`.

Dynamic workflow checks requested by user:

- Run a dynamic workflow after implementation and basic tests to independently audit model policy unification across `new-api` + `opentu`.
- Run final dynamic workflow after all fixes/checks with prompt equivalent to:

```text
使用动态工作流全面深度审查当前项目，主要是是否达成开发目标（当前目录是项目编排、项目代码具体在同级目录的new-api和opentu），不要依赖于之前的报告
```

The final audit target is **goal attainment and new/regression problems**, not merely whether the listed fixes were touched.

## Risk Points

- Existing OpenTU static defaults are widely referenced; partial migration can leave hidden executable fallbacks.
- Changing `/creative/api/models` shape could break existing broker tests; prefer adding policy to bootstrap.
- Admin policy validation must not accidentally leak channel IDs or encourage raw channel selection.
- Empty catalog behavior must be consistent across UI and service submit paths.
- Generated dist sync can hide source/runtime mismatch if not rebuilt and checked.

## Suggested Sub-agent Split After Approval

1. Backend policy/API agent: P1 + P2 tests.
2. new-api admin UI agent: P3.
3. OpenTU resolver/session broker agent: P4.
4. OpenTU component/service migration agent: P5 + P6.
5. Verification/audit agent: P7 + P8, including dynamic workflow outputs.

Dependencies:

- P3 depends on P1/P2 API contract.
- P5/P6 depend on P4 resolver contract.
- P7 depends on OpenTU source changes.
- P8 depends on all implementation work and artifact sync.

## Approval Gate

Before implementation starts, user should review:

- `prd.md`;
- `design.md`;
- `implement.md`;
- `implement.jsonl`;
- `check.jsonl`.

Then explicitly approve starting the Trellis task.


## Implementation Progress Summary

- [x] P1/P2 new-api backend policy service, bootstrap extension, admin endpoints, and tests implemented.
- [x] P3 new-api admin UI JSON editor/preview and locale/API wiring implemented.
- [x] P4 OpenTU central policy resolver/session broker integration implemented.
- [x] P5 primary OpenTU selectors/settings/static-fallback migration implemented for embedded mode.
- [x] P6 embedded generation fail-closed guard wired into services, task queue, MCP tools, and canvas operations.
- [x] P7 OpenTU embedded build and new-api Creative dist sync verified by release gate.
- [x] P8 final audit/check pass completed: usable earlier dynamic findings fixed; final dynamic reruns timed out with no usable branch output, so final evidence is targeted code review + tests/typecheck + release gate (documented in verification.md).
