# PRD — Creative live adapter push / deploy / smoke

## Objective

Move the completed Creative Duomi/GrsAI live image adapter from local verified commits to remote branches, deploy it to staging first, verify staging, and only then decide whether production deployment is allowed.

## Current baseline

- `new-api` implementation commit exists locally: `ed0fea4 feat(creative): add live image provider adapters` on `/mnt/f/CODE/Project/new-api` branch `feat/creative-embed`.
- `new2fly` planning/spec/journal commits exist locally on `master`:
  - `0c6a46d docs(creative): record live image adapter contract`
  - `d5007c8 chore(task): record creative live adapter validation`
  - `848c837 chore(task): archive 06-21-06-21-creative-duomi-grsai-live-image-adapter`
  - `c23bbaa chore: record journal`
- `opentu` has no code diff for this adapter task.
- Local verification already passed: targeted Go tests, frontend typecheck/touched eslint, disposable staging smoke, browser smoke, and dynamic workflow final audit with `mustFix: []`.

## Requirements

1. Preserve repository hygiene.
   - Confirm worktrees are clean before and after operations.
   - Do not mix unrelated local changes into pushes/deploys.
2. Push local commits safely.
   - Use host GitHub credentials where required; do not read, print, or persist secrets.
   - Prefer pushing `new-api` branch `feat/creative-embed` and `new2fly` `master` documentation/task commits.
3. Deploy/update staging before any production-affecting environment.
   - Staging is the mandatory first deployment target for this task.
   - Do not mutate production DB/schema/data outside the deployed application migration behavior without separate confirmation.
   - Do not wipe existing user/channel/config data.
4. Configure Creative live adapters through `new-api` admin surfaces after deployment.
   - Provider keys/BaseURLs remain in `new-api` Channels.
   - Creative Model Bindings reference channels by `channelId` and choose adapter preset/template.
5. Run smoke checks in escalating stages, with staging as the required runtime gate.
   - No-provider smoke first: auth, `/creative`, model catalog, parameter schema, admin validate/dry-run/save if safe.
   - Mock/no-provider task smoke where appropriate.
   - Real Duomi/GrsAI provider smoke only after explicit authorization, test keys/channels, and cost acceptance.
6. Record results and unresolved risks.
   - Clearly separate local/staging/production evidence.
   - Redact credentials, cookies, CSRF/nonce, provider keys, signed URLs, raw provider outputs if sensitive.

## Non-goals

- Do not redesign the adapter implementation in this task unless deploy/smoke reveals a blocker.
- Do not perform live provider calls by default.
- Do not change standalone OpenTU fork/release policy unless required for deployment.

## Acceptance criteria

- Local branch/commit status is documented before push.
- Required commits are pushed or the push blocker is documented.
- Staging environment update plan is documented before execution.
- Staging deployment/update is completed with evidence or explicitly blocked/deferred with reason.
- Smoke result table exists with status for:
  - `/creative` app shell
  - `/creative/api/bootstrap`
  - `/creative/api/models`
  - Creative Model Bindings admin validate/dry-run/save path when safe
  - logged-in browser catalog/parameter schema
  - optional provider smoke if separately authorized
- Final state identifies whether the live adapter is staging-verified, production-ready, staging-only, or blocked.
- Production deployment is not attempted until staging smoke passes and the user gives a separate production confirmation.
