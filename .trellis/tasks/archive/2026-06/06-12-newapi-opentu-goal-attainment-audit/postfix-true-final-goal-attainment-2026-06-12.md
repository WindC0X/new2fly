# Post-Fix True Final Goal-Attainment Audit

Date: 2026-06-12

## Scope

This is the requested post-fix **true final** audit. It answers the product/project question:

> Based on current source-of-truth files and current code/tests/docs, has the project achieved its development goals, and what current project problems remain?

It is **not** a fix-completion checklist and does not rely on previous reports.

Evidence exclusions used in the workflow:

- `.trellis/tasks/archive/**`
- `.trellis/workspace/*audit*.md`
- `.trellis/tasks/**/report*.md`
- `.trellis/tasks/**/current-final*.md`
- `.trellis/tasks/**/final-remediation*.md`
- `.trellis/tasks/**/remediation*.md`
- `.trellis/tasks/**/arbitration*.md`
- `.trellis/tasks/**/workflow-output*.json`
- `.codebuddy/**`
- `.codex-flow/journal/**`

No secrets, production services, provider endpoints, CDN/npm endpoints, or payment endpoints were called.

## Dynamic workflow evidence

- Workflow: `.codex-flow/generated/newapi-opentu-postfix-true-final-goal-attainment-2026-06-12.workflow.ts`
- Journal: `.codex-flow/journal/newapi-opentu-postfix-true-final-goal-attainment-2026-06-12.jsonl`
- Branches: 6/6 usable:
  1. goals/docs/governance
  2. new-api backend/runtime
  3. opentu frontend/runtime
  4. cross-repo contract/e2e consistency
  5. quality/release/ops
  6. adversarial business-logic

## Final verdict

**Overall verdict: `partial` — current project has not fully achieved its development goals.**

The Creative Embed/session-broker/asset/CDN direction is mostly implemented and much stronger than before, but the true final audit found confirmed current blockers. These are not merely release-readiness gaps.

## Confirmed current blockers after main-thread verification

### 1. `new-api` billing outbox owner-isolation / wrong-task risk

Evidence:

- `../new-api/model/task.go:47-53` — `Task.TaskID` is indexed but not unique; it is an upstream/third-party id.
- `../new-api/model/task.go:585-589` — `TaskBillingOutbox` records `TaskRowID`, `TaskID`, and `UserId`.
- `../new-api/model/task.go:595-597` — outbox `FirstOrCreate` de-dupes only by `task_id + operation`.
- `../new-api/service/task_billing.go:221-223` — `ProcessTaskBillingOutbox` loads the task only by `task_id = ?`, ignoring `TaskRowID` and `UserId`.

Impact:

If duplicate/historical/cross-user `task_id` rows exist, settlement/refund can be applied to the wrong row/user, violating owner isolation and billing/refund correctness.

Recommended fix:

- Process outbox by `task_row_id + user_id` first, not `task_id` only.
- Change outbox de-dupe to `task_row_id + operation` or at least `user_id + task_id + operation`.
- Add regression test with two users/tasks sharing the same `task_id`.

### 2. `opentu` `VideoAPIService` validates idempotency too late

Evidence:

- `../opentu/packages/drawnix/src/services/video-api-service.ts:162-180` — helper can throw if session-broker idempotency key is missing.
- `../opentu/packages/drawnix/src/services/video-api-service.ts:319-329` — LLM API log starts before idempotency validation.
- `../opentu/packages/drawnix/src/services/video-api-service.ts:372-394` and `407-426` — reference-image cache reads / fetches can occur before idempotency validation.
- `../opentu/packages/drawnix/src/services/video-api-service.ts:450-457` — idempotency validation only happens while building headers for the provider submit request.

Impact:

Missing stable idempotency key may still create logging/cache/network side effects before fail-fast. This violates the current frontend relay goal: stable idempotency before side effects.

Recommended fix:

- Compute/validate session-broker submit headers immediately after provider context resolution and API-key check, before `startLLMApiLog`, FormData construction, cache reads, or image fetches.
- Add test proving missing key calls none of: `startLLMApiLog`, `unifiedCacheService.getImageForAI`, `fetch`, provider transport.

### 3. `new-api` Stripe webhook logs raw signature/body before verification

Evidence:

- `../new-api/controller/topup_stripe.go:155-163` — reads raw request body and logs `signature=%q body=%q`.
- `../new-api/controller/topup_stripe.go:164-166` — signature verification happens after the raw log.

Impact:

Payment callback payloads and signature material can be written to logs, including unverified attacker-supplied payloads. This violates the broader new-api security/payment boundary and log-safety goal.

Recommended fix:

- Do not log raw body or signature before verification.
- After successful verification, log only minimal safe metadata such as event id/type and client IP.
- On verification failure, log only sanitized failure reason; never raw payload/signature.
- Add webhook logging regression test.

## Confirmed project / governance problems

1. **Spec conflict:**
   - `.trellis/spec/backend/creative-async-task-billing-consistency.md:28-36` says provider-submit success followed by local finalization failure must not delete idempotency guard.
   - `.trellis/spec/backend/creative-async-mj-relay.md:58-60` says local persistence/idempotency completion failure after upstream success deletes scoped idempotency record.
   - These are contradictory source-of-truth rules.

2. **Two frontend video paths drift:**
   - `media-api/video-api.ts` has earlier/cleaner session-broker idempotency and sanitized error handling.
   - `video-api-service.ts` still validates idempotency too late.

3. **Release/deploy documentation and governance gaps remain:**
   - Some generic Trellis backend/frontend guideline docs remain `To fill`.
   - CDN docs still contain wording such as “zero server traffic cost” that conflicts with HTML/SW/metadata/API origin-first architecture.
   - `new-api/go.mod` has Heroku `goVersion` and Go directive mismatch according to the workflow branch.

## Release-readiness gaps

These are not application blockers by themselves but must be cleared before release sign-off:

- `new2fly`, `new-api`, and `opentu` all have many modified/untracked files.
- Full current gates were not run in this final audit pass:
  - `new-api`: full `go test ./...` / race if required.
  - `opentu`: full `pnpm check`, build, test/e2e.
  - browser smoke for `/creative` session bootstrap, relay, asset upload/hydrate, SW/CDN behavior.
- Runtime deployment config was not verified:
  - `CREATIVE_VIDEO_RELAY_ENABLED`
  - `CREATIVE_ASSET_SYNC_ENABLED`
  - S3-compatible asset storage settings
  - real Redis/S3/provider/payment callback behavior

## Current answer to the user’s final-audit question

- **Has the project achieved its development goals?** Not fully. It is materially closer, but current blockers remain.
- **Does the project still have problems?** Yes. The three confirmed blockers above are current code/security/business-logic issues; additional governance and release-readiness gaps remain.
- **Can it be treated as ready for release?** No.

## Recommended next order

1. Fix `new-api` billing outbox owner-isolation.
2. Fix `new-api` Stripe webhook raw logging.
3. Fix `opentu` `VideoAPIService` idempotency-before-side-effects ordering.
4. Resolve the Trellis spec conflict for upstream-success/local-finalization-failure idempotency behavior.
5. Re-run targeted tests for those fixes.
6. Run another true final goal-attainment audit only after those fixes land.
