# Implementation Plan

## Phase A Scope

Implement the manifest-driven foundation only. Do not implement real Duomi/GrsAI provider transport in this task.

## Steps

1. Backend manifest registry
   - Add Creative adapter manifest/parameter template registry in `service/creative_model_capability.go` or a small adjacent file.
   - Reuse it for allowed adapter presets and template lookup instead of duplicate switches/maps.
   - Include current mock and GrsAI dry-run presets plus disabled future Duomi/GrsAI live entries.

2. Backend admin endpoint
   - Add `GET /api/creative/adapter-manifests` in the Creative model binding controller/router area.
   - Enforce dashboard-session admin auth and no-store response headers consistent with existing binding endpoints.
   - Return only safe manifest/template metadata.

3. Backend validation tightening
   - Ensure validate/dry-run/PUT reject unknown preset/template ids through the registry.
   - Reject enabling manifests where `CanBeEnabled=false` or status is future/disabled.
   - Keep `NoProviderCall=true` mandatory for save path.

4. Frontend API/types
   - Add typed client call for adapter manifests.
   - Add `CreativeAdapterManifest` / template summary types.
   - Remove closed `SupportedAdapterPreset` union and static `adapterPresetDraftMap` as the source of truth.

5. Frontend guided builder
   - Fetch manifests with current bindings and channel summaries.
   - Build adapter/template selects from manifest response.
   - Show Duomi/GrsAI live/future adapters as disabled choices with prerequisite copy.
   - Generate binding drafts from selected manifest/template/channel model.
   - Use “质量” for quality label in Chinese contexts and keep schema-specific parameter rendering.

6. OpenTU/schema regression check
   - Confirm embedded Creative still renders backend-managed `parameterSchema` for image models.
   - Ensure no OpenTU local key/channel picker is reintroduced.

7. Validation
   - Run focused backend tests if existing packages have tests for service/controller behavior.
   - Run frontend type/lint or targeted build for New API web default if feasible.
   - Run local/staging smoke: settings page loads, manifest fetch works, binding draft validates/dry-runs, Creative model parameters still appear.

8. Review
   - Run a dynamic workflow review after local fixes to audit goal attainment and new regressions.
   - Main session verifies reviewer findings before claiming completion.

## Risk Points

- Existing saved binding config must remain backward compatible.
- Frontend must fail closed if manifest fetch fails; do not silently fall back to stale hard-coded presets.
- Manifest metadata must not leak channel credentials or provider URLs.
- Future live adapter placeholders must not be accidentally enabled.
- Provider-specific parameter differences must live in backend templates/schema, not one-off UI branches.

## Rollback Plan

- Revert the manifest endpoint and UI manifest fetch changes.
- Keep binding JSON format unchanged so existing configs remain loadable.
- If a validation regression blocks admins, temporarily mark new future manifests unavailable while retaining current mock/dry-run presets.
