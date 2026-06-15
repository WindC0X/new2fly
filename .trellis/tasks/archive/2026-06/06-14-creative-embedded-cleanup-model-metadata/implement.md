# Implementation Plan — Creative Embedded Standalone Cleanup And Model Metadata

## Phase 1 — Planning

- [x] Create Trellis task after user consent.
- [x] Inspect code for standalone UI remnants and model metadata paths.
- [x] Write PRD with requirements and acceptance criteria.
- [x] Write technical design.
- [x] Curate `implement.jsonl` / `check.jsonl` context manifests.
- [ ] Ask for planning review and explicit implementation start approval.

## Task Decomposition Decision

This is a multi-deliverable task, but the deliverables are intentionally kept in one Trellis task for this implementation pass because they share one embedded-release contract and must be staged/verified together:

1. OpenTU embedded standalone cleanup.
2. new-api Creative-safe model catalog enrichment.
3. OpenTU managed catalog metadata consumption.
4. new-api Creative model policy guided admin UX.

Implementation and check work should still be split by these slices in sub-agent prompts or main-thread checkpoints. The ordering dependency is explicit: backend catalog enrichment should land before final OpenTU metadata smoke verification, and all slices must pass the final embedded release gate/staging smoke before completion.

## Phase 2 — OpenTU embedded UI cleanup

1. Add focused embedded-mode tests around:
   - feedback button hidden;
   - GitHub toolbar button hidden;
   - Cloud Sync menu/status hidden;
   - API-key-template toolbox tools blocked without settings redirect.
2. Implement hiding/gating:
   - `FeedbackButton` or its caller;
   - embedded branch of `AppToolbar`;
   - `AppToolbar` menu composition for `CloudSync`;
   - `SyncStatusIndicator` if needed;
   - `BackupRestoreDialog` environment/secrets options in embedded mode;
   - `ToolboxDrawer` / toolbox filtering for `${apiKey}` tools.
3. Ensure standalone OpenTU behavior remains unchanged.

## Phase 3 — new-api Creative model metadata

1. Add Creative-specific DTO / builder for safe enriched catalog items.
2. Add metadata lookup from `model.Model` / pricing metadata without exposing secrets or channel internals.
3. Update `creativeModelsForUser`, `CreativeBootstrap`, `CreativeListModels`, and `creativeEffectiveModelPolicyForRequest` typing as needed.
4. Add tests for safe fields and redaction.
5. Keep generic `/v1/models` / enabled model list behavior unchanged.

## Phase 4 — OpenTU model metadata consumption

1. Extend Creative model endpoint item types and normalization.
2. Merge server metadata with static config and fallback inference.
3. Ensure runtime catalog state preserves `shortLabel`, `shortCode`, `vendor`, `type`, tags, defaults.
4. Add tests for:
   - exact static model preserves static metadata;
   - unknown server-enriched model uses server label/short code/type/vendor/tags;
   - unknown metadata-poor model has conservative fallback;
   - generation guard still rejects models absent from managed catalog.

## Phase 5 — new-api admin policy UI optimization

1. Add/adjust frontend tests where the project already has suitable patterns, or keep changes type-safe with targeted build checks if no local component harness is available.
2. Refactor `CreativeModelPolicySection` from raw-JSON-first into guided policy builder:
   - draft policy state helpers;
   - modality default selector;
   - modality recommended selector;
   - per-group override editor;
   - diagnostics/cleanup panel;
   - advanced JSON panel.
3. Update `web/default/src/features/system-settings/types.ts` if enriched model metadata changes `modelPools` shape.
4. Add i18n strings for new labels/help text.
5. Preserve dedicated endpoint save flow and unsafe-field validation.

## Phase 6 — Build, sync, local staging verify

1. Run targeted OpenTU tests and typecheck.
2. Run targeted new-api Go tests.
3. Run release gate:

```bash
cd /mnt/f/code/project/new2fly
python3 scripts/creative_release_gate.py build-sync-check --run-new-api-tests
```

4. Rebuild local staging image:

```bash
docker build --pull=false --progress=plain \
  -t new-api-creative-embed:staging-current \
  /mnt/f/code/project/new-api
```

5. Restart local staging without deleting data:

```bash
STAGING_BIND_ADDR=127.0.0.1 STAGING_PORT=39084 \
  docker compose -f ops/newapi-opentu-staging/docker-compose.yml \
  -p newapi-opentu-staging up -d
```

6. Run Playwright smoke/screenshots for embedded UI cleanup and model selector display.
7. Run a dynamic-workflow assisted final check for this task scope: embedded standalone cleanup, safe model metadata contract, OpenTU selector/parameter behavior, admin policy UX, and regression/new-issue scan. Record the workflow summary in `check.md`.

## Phase 7 — Check / record / finish

1. Write `check.md` with test commands, staging evidence, screenshots summary, and remaining caveats.
2. Run final `git diff --check` in all touched repos.
3. Commit OpenTU and new-api changes separately with focused messages.
4. Run Trellis validate and commit/archive new2fly task artifacts.
5. Record journal.

## Risk / Rollback Points

- If enriched model DTO causes backend compatibility risk, keep it Creative-specific and do not alter generic model endpoints.
- If parameter inference is too broad, prefer conservative no-param fallback over showing wrong provider-specific params.
- Do not introduce browser-visible provider secrets or channel selection authority.
- Do not run provider generation tasks during verification.
- Do not push to upstream remotes; user fork push remains host-side if WSL auth is unavailable.
