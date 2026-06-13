# Remote-backed new-api / OpenTU Release Candidate Verification

## Goal

Verify the release candidate formed by the pushed remote branches:

- `WindC0X/opentu:newapi-embed-release-gate`
- `WindC0X/new-api:feat/creative-embed`
- `WindC0X/new2fly:master`

The objective is to prove the pushed branches, not just local unpushed work, still satisfy the no-secrets embedded Creative release gate.

## Requirements

- Do not read or print secrets.
- Do not call provider/payment/CDN/production endpoints.
- Prefer read-only checks against the already-pushed candidate branches; avoid running build/sync commands that mutate generated artifacts unless a failure requires deeper investigation.
- Confirm local HEADs match the corresponding remote branch commits before verification.
- Verify:
  - Creative artifact identity and generated artifact policy via `scripts/creative_release_gate.py`.
  - `new-api` Go tests/build subset relevant to Creative embedded routes.
  - OpenTU typecheck and cold smoke readiness.
  - Embedded `/creative/` browser smoke against a temporary local no-secrets `new-api` server.
- Record command evidence and remaining release-environment-only checks.

## Acceptance Criteria

- [ ] Candidate remote branch commits are listed and match local verification heads.
- [ ] Artifact gate passes on the candidate branches.
- [ ] `new-api` selected tests/build pass.
- [ ] OpenTU typecheck and cold smoke pass or any failure is investigated and documented.
- [ ] Embedded `/creative/` smoke runs against local `new-api` and passes or any failure is investigated and documented.
- [ ] No unintended tracked diffs remain after verification.
- [ ] Verification report is written to this task.
