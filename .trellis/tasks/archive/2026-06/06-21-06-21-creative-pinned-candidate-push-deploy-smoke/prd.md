# Creative pinned candidate push deploy smoke

## Goal

Push the pinned OpenTU/new-api/new2fly Creative production-hardening candidate, verify remote refs, run staging/candidate validation first, then only after staging passes prepare authorized VPS/production deployment/smoke rollout with data-preserving runbook gates.

## User Value

- The already verified local candidate becomes reproducible from GitHub refs instead of existing only on local disks.
- Deployment work proceeds from immutable/pinned commits and a staging-validated candidate, reducing risk of stale dist, wrong branch, or untracked local changes.
- Staging catches route/UI/auth/model-catalog regressions before any VPS/production preflight or mutation.
- Production rollout preserves existing New API user data, channels, model/pricing options, quota state, tokens, and logs.
- Smoke evidence distinguishes local/ref verification, deployment rehearsal, production route smoke, cloud-sync smoke, and live provider smoke.

## Confirmed Facts

- Current local candidate commits:
  - OpenTU: `0b584e2cf7c622b9fa431b3bf39b4a86055699bc`
  - new-api: `53b8f54126214b4eac7b33619d45c097fe443e34`
  - new2fly: `645db425ffe4dcbf60cb747c5cba862b577dcc92`
- Production runbook currently pins OpenTU and new-api refs to the above OpenTU/new-api commits.
- All three local worktrees were clean at the end of the previous task.
- GitHub credentials are on the host, not necessarily available inside WSL.
- Real Duomi/GrsAI live image adapters remain out of scope and are not implemented.
- Production/live provider/S3 smoke requires explicit environment credentials and separate authorization.

## Requirements

### R1 — Push pinned refs safely

- Push OpenTU, new-api, and new2fly commits to their intended remote branches.
- If WSL Git cannot use host credentials, use host Git/PowerShell without copying tokens into WSL, docs, logs, or task files.
- Do not push `.codex-flow/`, local `.env`, credentials, DB files, logs, or production secrets.

### R2 — Verify remote refs

- Use remote ref verification (`git ls-remote`) after push.
- Confirm remote branches point to:
  - OpenTU `0b584e2cf7c622b9fa431b3bf39b4a86055699bc`
  - new-api `53b8f54126214b4eac7b33619d45c097fe443e34`
  - new2fly final commit after any task-planning/session commits
- If a remote ref mismatch occurs, stop and diagnose before deployment.

### R3 — Preserve release gates before deployment

- Re-run or cite fresh post-push local gates before deployment:
  - OpenTU targeted tests or build evidence as needed;
  - new-api `scripts/creative_ci_gate.sh`;
  - new2fly `creative_release_gate.py check --source-diff-check --sourcemap-policy forbid` with explicit repo paths.
- Confirm embedded dist provenance remains `version=0.9.6 gitCommit=0b584e2cf7c622b9fa431b3bf39b4a86055699bc`.

### R4 — Staging validation comes before VPS/production

- Before any VPS/production preflight or mutation, run a staging/candidate validation pass from the pushed refs.
- Staging must verify the embedded `/creative/` route/UI, `/creative/api/bootstrap`, `/creative/api/models`, model parameter visibility, session-broker behavior, route boundaries, and release-gate output.
- Staging evidence must be clearly labeled as staging, not production readiness.

### R5 — Deployment preflight is explicit and data-preserving

- After staging passes and before any production mutation, perform a read-only deployment preflight against the runbook target.
- Verify current production shape, backups path, compose env shape, image identity plan, and maintenance assumptions.
- Do not overwrite production `.env`; append/update only reviewed Creative keys.
- Do not alter/delete existing user/channel/token/quota/log data.

### R6 — Deployment/smoke execution requires explicit production authorization

- Building/loading a candidate image, stopping production containers, editing compose, restarting production, or running authenticated smoke against production must be explicitly authorized in the deployment step.
- Route smoke must redact cookies, CSRF, nonce, passwords, tokens, response bodies, storage credentials, and provider keys.
- Phase 1 route/UI rollout keeps `CREATIVE_ASSET_SYNC_ENABLED=false` unless separately authorized and S3-compatible config is present.

## Acceptance Criteria

- [ ] Local worktrees are clean before push.
- [ ] OpenTU, new-api, and new2fly commits are pushed or a credential limitation is documented with safe host-side fallback.
- [ ] Remote refs are verified with `git ls-remote` and match expected commits.
- [ ] Release gates are re-run or freshly verified after the pushed refs are fixed.
- [ ] Staging/candidate validation passes before any VPS/production preflight.
- [ ] Deployment preflight confirms data-preserving runbook assumptions before any mutation.
- [ ] Production mutation is not performed without explicit authorization at that step.
- [ ] If deployment is authorized, smoke results are recorded as redacted route/cloud-sync/provider categories with clear not-run items.
- [ ] No secrets, cookies, CSRF tokens, nonces, passwords, DB dumps, or provider credentials are committed or printed.

## Out of Scope

- Implementing Duomi/GrsAI live provider adapters.
- Enabling production Creative asset cloud sync without explicit S3-compatible credentials and authorization.
- Live provider/payment/channel generation smoke without explicit authorization and credentials.
- Destructive DB/schema rollback.
- Changing the previously verified production-hardening code candidate except for deployment/runbook task records.

## Open Questions

- Which staging target should be used for this run: local disposable container, existing staging service, or both? Recommended default: local disposable candidate first, then existing staging if available.
- Production mutation is not authorized by this planning artifact. It must be confirmed only after staging passes.
