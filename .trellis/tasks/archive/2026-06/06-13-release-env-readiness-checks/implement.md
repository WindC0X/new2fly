# Implementation Plan — Release Environment Readiness Checks

## Phase 1 — Planning gate

1. Confirm task scope with the user:
   - Recommended default: Tier A static/offline checks now; Tier B live read-only checks only after explicit target environment + authorization.
2. Do not run `task.py start` until the user approves the planning artifacts and execution scope.

## Phase 2 — Static/offline checks

1. Re-read prior RC report and active specs.
2. Inspect release/deploy surfaces:
   - `new-api/.env.example`
   - `new-api/Dockerfile`
   - `new-api/docker-compose.yml`
   - `new-api/.github/workflows/*.yml`
   - `opentu/package.json`
   - `opentu/scripts/deploy-hybrid.js`
   - `opentu/scripts/upload-and-deploy.js`
   - `opentu/scripts/create-deploy-package.js`
3. Build a redacted environment matrix:
   - required variable names,
   - safe/unsafe defaults,
   - whether missing means fail/warn/not applicable.
4. Build static route/CDN policy checklist for `/creative/`.
5. Build publish-path checklist for Docker, GHCR, Docker Hub, NPM/hybrid release.
6. Run dynamic-workflow sidecar review with read-only agents over independent surfaces:
   - env/secrets matrix,
   - route/CDN/object storage,
   - provider/payment/publish path.

## Phase 3 — Optional live read-only checks

Only after explicit user confirmation:

1. Confirm target environment name and base URL.
2. Run read-only HTTP route checks against the target base URL:
   - `/creative/`
   - a known `/creative/assets/*` from the verified artifact,
   - missing `/creative/assets/__missing__...`,
   - `/creative/api/bootstrap`,
   - `/creative/relay/v1/chat/completions` with safe unauthenticated GET/OPTIONS/HEAD where applicable.
3. Run redacted secret presence checks only in the environment/tooling the user authorizes.
4. Run non-mutating object-storage/provider/payment/publish identity checks only where safe APIs exist.

## Phase 4 — Report / finish

1. Write `check.md` with pass/warn/fail/not-run per surface.
2. Record manual follow-ups and exact safe commands for checks that cannot be run here.
3. Update `.trellis/spec/` if new reusable release-readiness rules are learned.
4. Validate task, archive, journal, and push `new2fly` using the Windows-host GitHub credential path if changes need to be pushed.

## Rollback / safety

- Do not run publish/deploy/upload commands in this task unless separately confirmed.
- Do not read or print `.env` or secret store values.
- Do not remove local untracked tool/cache files unless separately confirmed.
