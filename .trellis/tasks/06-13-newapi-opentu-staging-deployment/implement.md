# Implementation Plan — New-api/OpenTU Staging Deployment

## Phase 1 — Planning and ops files

1. Write PRD/design/implement artifacts.
2. Curate context manifests.
3. Create `ops/newapi-opentu-staging/` compose/runbook files.
4. Generate ignored local env file with a new local session secret; do not print the value.
5. Validate and start Trellis task.

## Phase 2 — Build and deploy

1. Run `python3 scripts/creative_release_gate.py check --source-diff-check`.
2. Build/tag `new-api-creative-embed:staging-current` from `/mnt/f/code/project/new-api`.
3. Start Docker Compose project `newapi-opentu-staging`.
4. Wait for `/api/status` readiness.
5. Record sanitized deployment evidence.

## Phase 3 — Verify staging

1. Run embedded smoke against `http://localhost:39084/creative/`.
2. Run redacted `GET`/`HEAD` route/header table.
3. Run dynamic workflow read-only review.
4. Write `check.md` with final URL and stop/restart commands.

## Phase 4 — Finish

1. Run final checks:
   - `git diff --check`,
   - Trellis validate,
   - compose service running/healthy,
   - ignored env file not tracked.
2. Update specs if a durable deployment convention was learned.
3. Commit, archive, journal, and push.

## Rollback / safety

- If service starts printing secrets or unexpected external credentials, stop compose immediately and record sanitized failure.
- Do not use real provider/payment/CDN/S3 env.
- Do not bind to LAN/public addresses unless separately confirmed.
- Do not push images or run release workflows.
