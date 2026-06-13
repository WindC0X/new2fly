# Implementation Plan — Staging UI / Model List / Crash Fix

## Phase 1 — Context and root cause

1. Save staging health/log evidence.
2. Trace backend rate limiter and route registration.
3. Trace OpenTU embedded console button component/CSS.
4. Trace model/provider selectors and runtime model discovery/session-broker data flow.
5. Curate context manifests and start task.

## Phase 2 — Fixes

1. Fix Creative/static `429` root cause without weakening API/critical limits.
2. Fix embedded `回到控制台` layout overlap.
3. Fix or configure embedded model/provider selector source to use new-api/session-broker model policy.
4. Add/update tests where feasible.

## Phase 3 — Rebuild and deploy

1. Run OpenTU checks/build.
2. Sync OpenTU dist into new-api using existing release gate workflow.
3. Run new-api relevant tests.
4. Rebuild `new-api-creative-embed:staging-current`.
5. Restart compose staging.

## Phase 4 — Verify and finish

1. Run smoke and route/header checks.
2. Confirm service healthy and no `429` on normal route checks.
3. Run dynamic workflow read-only review over evidence.
4. Write `check.md` with root cause, fixes, and model-list configuration answer.
5. Update specs if durable rule learned.
6. Commit, archive, journal, push.
