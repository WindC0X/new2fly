# Implementation Plan — Creative Embedded Push And Deployment Verification

## Phase 1 — Planning

- [x] Create Trellis task after user consent.
- [x] Inspect current remotes, branches, commits, and staging compose.
- [x] Draft PRD, design, and implementation plan.
- [x] Ask user to choose deployment target/scope. Decision: push + remote ref verification now; keep deployment local-only until real target and S3-compatible storage are provided.
- [ ] After user review, activate task with `task.py start`.

## Phase 2 — Push preparation

Status: completed for `opentu` and `new-api`; `new2fly` final push waits until this task record is committed.

1. Confirm working trees clean in all repos.
2. Prepare host-side push commands:

```bash
cd /path/to/opentu
git status --short
git log --oneline -1
git push fork feat/creative-embed:feat/creative-embed

git ls-remote fork refs/heads/feat/creative-embed

cd /path/to/new-api
git status --short
git log --oneline -1
git push fork feat/creative-embed:feat/creative-embed
git ls-remote fork refs/heads/feat/creative-embed

cd /path/to/new2fly
git status --short
git log --oneline -1
git push origin master:master
git ls-remote origin refs/heads/master
```

3. If WSL credentials work, run `git push --dry-run` first; otherwise instruct host-side execution.
4. Record pushed commit hashes in `check.md`.

## Phase 3 — Deployment preparation

1. Decide target:
   - local-only continuation;
   - private host/IP;
   - public domain;
   - CI/CD handoff.
2. Decide deploy mode:
   - Docker image local/registry;
   - direct checkout;
   - existing service runner.
3. Prepare env checklist:
   - no secret values in repo/logs;
   - stable `SESSION_SECRET`;
   - production S3-compatible storage if `CREATIVE_ASSET_SYNC_ENABLED=true`.
4. Prepare rollback commands for target.

## Phase 4 — Deploy / verify

Status: local staging verification completed; real deployment not run by scope decision.

1. Deploy selected target, or produce exact host commands if Codex cannot access credentials/host.
2. Run route/header matrix.
3. Run embedded smoke:

```bash
python3 scripts/creative_release_gate.py check --embedded-smoke-url <target>/creative/
```

4. Run authenticated cloud-sync smoke only with explicit credential handling.
5. Record all results in `check.md`.

## Phase 5 — Finish

1. Run final `git diff --check` for new2fly changes.
2. Update specs if a durable push/deploy rule was learned.
3. Commit task records and any runbook updates.
4. Archive task and record journal.

## Validation commands

- `git status --short` in all three repos.
- `git ls-remote <remote> <ref>` after push.
- `python3 scripts/creative_release_gate.py check --embedded-smoke-url <url>` for browser smoke.
- `/tmp/creative-cloud-sync-smoke.cjs` for authenticated cloud-sync smoke, with hidden password input.

## Rollback points

- Before any push: no remote mutation.
- After push: remote branches can be reset only with explicit force-push approval; otherwise push a revert/fix branch.
- Before deploy: no live service change.
- After deploy: rollback to previous image/ref and optionally disable `CREATIVE_ASSET_SYNC_ENABLED`.
