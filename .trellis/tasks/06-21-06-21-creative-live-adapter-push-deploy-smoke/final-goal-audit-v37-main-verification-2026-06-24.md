# Final goal audit v37 — main-session verification

Date: 2026-06-24
Scope: current project goal attainment / new issue discovery for embedded OpenTU Creative in new-api, after local Docker staging repair and smoke.

## Evidence sources used

- Current source in `/mnt/f/code/project/new-api` and `/mnt/f/code/project/opentu`.
- Current task artifacts under `.trellis/tasks/06-21-06-21-creative-live-adapter-push-deploy-smoke/`.
- Fresh local Docker staging smoke from 2026-06-24.
- `fast-context` and `codegraph` for file/symbol discovery.
- Dynamic workflow attempts were journaled but **not counted as pass** because of timeout/null/empty branches.

## Dynamic workflow status

Invalid / not counted:

- `creative-final-goal-audit-v37.workflow.ts`: backend branch completed; frontend returned empty object; runtime/staging/security timed out; synthesis/verifier null.
- `creative-final-goal-audit-v37b-missing.workflow.ts`: all focused branches timed out; interrupted before invalid synthesis.
- `creative-final-goal-audit-v37c-targeted.workflow.ts`: all targeted branches timed out; interrupted before invalid synthesis.

Verdict: dynamic workflow was attempted with fan-out and split retries, but did not produce a valid complete final audit. Main-session verification below is therefore the controlling evidence for this report.

## Main-session goal verdict

Staging/runtime goal is currently **staging-verified by main-session evidence**, with no new application-level blocker found in the inspected source/runtime paths.

Not production-ready yet because:

1. Production/VPS deployment is explicitly a separate gate and has not been authorized/executed in this step.
2. `new-api`, `opentu`, and `new2fly` worktrees remain dirty and must be organized/committed before release hygiene can be claimed.
3. Dynamic workflow final audit did not complete validly; if a dynamic-workflow-backed final audit is mandatory, it remains open.

## Cross-layer state machine verification

Current state machine evidence:

1. UI parameter schema and dropdown:
   - `opentu/packages/drawnix/src/components/ai-input-bar/ParametersDropdown.tsx` renders all compatible runtime schema params as grouped sections and options.
   - Staging browser smoke verified one panel with `图片尺寸`, `图片分辨率`, `质量`, including `21:9 超宽`, `1K`, and quality options.
2. UI submit payload:
   - `model-config.ts:2931-2961` builds `CreativeUserParams` only from runtime schema params.
   - `generation-api-service.ts:515-524` rejects schema-backed Creative requests from the legacy image route and forces the managed task route.
   - `media-executor.test.ts:828-865` verifies managed submit body contains `userParams` and omits legacy `params`.
3. Backend submit/idempotency/billing:
   - `controller/creative_image_tasks.go:318-355` persists durable task with selected key, endpoint, idempotency key, billing context, and target dimensions before provider submit.
   - `controller/creative_image_tasks.go:363-373` submits to provider with stored resolved userParams.
   - `controller/creative_image_tasks.go:445-479` uses billing outbox for submit settle/refund.
4. Slow provider / recovery:
   - `service/task_polling.go:78` defers global timeout sweep for Creative ambiguous/in-flight tasks.
   - `service/task_polling.go:170-184` separates missing upstream id from ambiguous/in-flight submit states.
   - `service/task_polling.go:408-466` polls live image tasks using selected key and endpoint affinity.
   - `service/task_polling.go:486-523` materializes terminal success and processes billing outbox.
5. Content/cache/canvas:
   - `useAutoInsertToCanvas.ts` verifies generated images before canvas insert and fails post-processing instead of inserting a blank image when content cannot load.
   - Prior v36 local embedded E2E and this staging UI smoke cover slow-provider/no-provider lifecycle and UI parameter path; no live provider call was made in post-repair smoke.
6. Security/session boundary:
   - `/creative/api/bootstrap` and `/creative/api/models` unauthenticated return 401 JSON/no-store.
   - `/creative/relay/v1/images/tasks` wrong-method GET returns JSON 404/no-store, not SPA HTML.
   - Admin model-binding validate/dry-run requires dashboard session + `New-Api-User` + Creative CSRF/nonce.
   - Dry-run returned `noProviderCall=true` with 3 bindings.
7. SQLite preserved-data staging blocker:
   - Initial new image exposed SQLite `ALTER TABLE ... ADD UNIQUE COLUMN` startup failure.
   - `model/main.go` now manually adds nullable column then ensures unique index.
   - `model/log_migration_test.go` covers legacy SQLite `logs` table migration.
   - Rebuilt staging image `sha256:93bdeee160637d7a6a22398550b4596e73d427080dc5e62dc0b0d2dd2de46cbe` is healthy with preserved named volumes.

## Fresh verification commands/results

```bash
go test -count=1 ./model -run TestEnsureSQLiteLogTaskBillingOutboxColumnAllowsAutoMigrateExistingLogs
# PASS

go test -count=1 ./controller ./service ./relay
# PASS
```

Fresh staging status:

```text
Image=new-api-creative-embed:staging-current
ID=sha256:93bdeee160637d7a6a22398550b4596e73d427080dc5e62dc0b0d2dd2de46cbe
Health=healthy
RestartCount=0
Mounts=newapi-opentu-staging_newapi_opentu_staging_data:/data newapi-opentu-staging_newapi_opentu_staging_logs:/app/logs
```

Fresh staging smoke passed:

- `/api/status` 200.
- `/creative/` 200.
- `/creative/version.json` 200.
- unauth `/creative/api/bootstrap` and `/creative/api/models` 401 JSON/no-store.
- wrong relay GET returned 404 JSON/no-store.
- authenticated bootstrap/models 200.
- model bindings GET/validate/dry-run 200, `valid=true`, `noProviderCall=true`.
- browser parameter panel and model dropdown verified.

## Findings

### Must-fix before production/release

1. **Release hygiene is not closed.** Current dirty counts: `new-api=218`, `opentu=149`, `new2fly=43`. These include source, generated artifacts, task docs, and test files. Need review/stage/commit or intentionally discard before any production deploy/push claim.
2. **Dynamic workflow final audit is not valid.** If final acceptance requires codex-flow-backed audit, rerun with a working profile or much smaller single-file branches until synthesis/verifier complete. Current timeout/null attempts are recorded but invalid.
3. **Production/VPS gate remains closed.** This report only covers local Docker staging. Production deploy requires separate authorization, backup/rollback posture, and production smoke.

### Should-fix / follow-up

1. Add the SQLite preserved-logs migration test to the normal release gate or backend package gate so this startup class is caught before staging.
2. Add a stable Playwright no-provider submit smoke to the repo scripts, not `/tmp`, covering `21:9 + 1K + quality` and asserting `userParams`/canvas ratio.
3. Document rate-limit behavior for repeated smoke attempts; rapid repeated login/UI smoke can transiently show model unavailable due 429.

## Final main-session conclusion

- Application goal on local Docker staging: **met by main-session evidence**.
- Dynamic workflow final audit: **attempted but not completed; not counted as pass**.
- Production readiness: **not yet**, because production deployment is separate and repository hygiene is still open.
