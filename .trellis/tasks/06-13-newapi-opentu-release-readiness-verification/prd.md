# New API / OpenTU Release Readiness Verification

## Goal

Verify whether the current `new-api` + `opentu` + Trellis orchestration state is ready for a controlled release after the Creative Embed goal-attainment audit. This task is not a repair-checklist replay; it must evaluate remaining project/release risks in the current worktree.

## Scope

Repositories:

- Orchestration/Trellis: `/mnt/f/code/project/new2fly`
- Backend: `/mnt/f/code/project/new-api`
- Frontend: `/mnt/f/code/project/opentu`

In scope:

1. Real browser smoke for Creative Embed/session-broker/asset-sync behavior.
2. Cross-repo production build/package chain, especially `opentu` build artifacts consumed by `new-api` creative web serving.
3. Production configuration readiness from examples/docs/code paths, without reading secrets.
4. Release freeze review: verify only intentional dirty/untracked artifacts remain.
5. Record evidence, gaps, and release-gate verdict.

Out of scope / safety constraints:

- Do not read or print secrets.
- Do not call provider, payment, CDN, or production endpoints.
- Do not push commits or deploy.
- Do not delete local cache/tool artifacts unless separately authorized.

## Acceptance Criteria

- [ ] Browser smoke is executed locally or a clear blocker is documented with exact missing prerequisite.
- [ ] Backend and frontend production build/package commands are executed or a precise local blocker is documented.
- [ ] Config readiness matrix is produced for required Creative/S3/session-broker/env flags, based on code/docs/examples only.
- [ ] Dynamic workflow is used for at least one independent verification pass and its journal/result is recorded.
- [ ] Final release-readiness report classifies blockers as HIGH/MEDIUM/LOW and states `release_ready`, `mostly_ready`, or `not_ready`.
- [ ] Remaining dirty/untracked files are classified as intentional local artifacts or task output.
