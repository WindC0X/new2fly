# Implementation plan — push / deploy / smoke

## Phase 1 — preflight

- [x] Confirm no unexpected dirty files in `new-api`, `new2fly`, and `opentu`.
- [x] Confirm expected commits and branches.
- [x] Confirm remote names/branches without printing credentials.

## Phase 2 — push

- [x] Push `new-api` branch `feat/creative-embed` containing `ed0fea4`.
- [x] Push `new2fly` `master` containing task/spec/journal commits.
- [x] Verify remote refs by commit hash where possible.

## Phase 3 — staging deployment planning gate

- [x] Identify exact staging environment and deploy method.
- [x] Confirm staging deployment command and data-preservation risk before execution.
- [x] Confirm staging uses preserved or disposable data according to the user's intent.

## Phase 4 — staging deploy/update

- [x] Update staging code/image to the verified commit.
- [x] Preserve existing staging users/channels/options/storage unless the user explicitly requests reset.
- [x] Verify staging service health and logs.

## Phase 5 — staging smoke

- [x] Run read-only route/header smoke.
- [x] Run authenticated `/creative/api/bootstrap` and `/creative/api/models` smoke.
- [x] Run Creative Model Bindings validate/dry-run smoke without provider call.
- [x] Run browser smoke for logged-in `/creative` model catalog and parameter panel.
- [x] Optional: run mock/no-provider image task smoke. (Playwright route-intercepted no-provider submit smoke run for 21:9 payload/canvas ratio)
- [x] Optional: run real Duomi/GrsAI provider smoke only after explicit authorization.

## Phase 6 — production decision gate

- [x] Summarize staging evidence.
- [x] Ask for separate production authorization only if staging passes. (current gate reached; pending user production decision)
- [ ] If authorized, create/continue a production deploy checklist; otherwise stop at staging-verified.

## Phase 7 — record and finish

- [x] Record pushed refs, deployed commit, smoke evidence, and open risks.
- [ ] If code/docs changed, run Trellis check/update-spec/commit/finish-work.

## Verification commands

Preflight:

```bash
git -C /mnt/f/CODE/Project/new-api status --short
git -C /mnt/f/code/project/new2fly status --short
git -C /mnt/f/CODE/Project/opentu status --short
```

Targeted local regression if needed:

```bash
cd /mnt/f/CODE/Project/new-api
go test -count=1 ./service ./controller ./model ./relay ./relay/common ./relay/constant
cd /mnt/f/CODE/Project/new-api/web/default
pnpm typecheck
pnpm exec eslint src/features/system-settings/models/creative-model-bindings-section.tsx
```
