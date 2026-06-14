# Creative Model Policy Push And Deploy Verify

## Goal

Safely promote the completed Creative model-policy-unification work from local commits into the user's remote repositories and verify a running deployment candidate, without exposing secrets or accidentally deploying to an unintended public/production target.

## User Value

The previous task completed code, tests, release-gate rebuild, dist sync, Trellis archive, and journal commits. The user now needs the work pushed and deployed/verified so it is accessible outside the local working tree and can be checked in a running environment.

## Confirmed Facts

### Completed work commits

- OpenTU repo: `/mnt/f/code/project/opentu`, branch `feat/creative-embed`, commit `b206848e feat(creative): enforce embedded managed model policy`.
- new-api repo: `/mnt/f/code/project/new-api`, branch `feat/creative-embed`, commit `3cca3ac feat(creative): add admin model policy and embedded artifact`.
- orchestration/Trellis repo: `/mnt/f/code/project/new2fly`, branch `master`, commits:
  - `0f4d7b7 docs(creative): record model policy unification`
  - `55403fb chore(task): archive 06-14-creative-model-policy-unification`
  - `48185db chore: record journal`

### Current remotes / local status

- `opentu` remotes:
  - `fork = https://github.com/WindC0X/opentu.git`
  - `origin = https://github.com/ljquan/opentu.git`
  - branch `feat/creative-embed` currently has no upstream tracking branch.
  - untracked local file remains: `packages/drawnix/audio-test.pptx` and must not be pushed.
- `new-api` remotes:
  - `fork = https://github.com/WindC0X/new-api.git`
  - `origin = https://github.com/QuantumNous/new-api`
  - branch `feat/creative-embed` tracks `fork/feat/creative-embed` and is ahead by 1.
  - untracked local directories remain: `.codegraph/`, `.codex-flow/` and must not be pushed.
- `new2fly` remote:
  - `origin = https://github.com/WindC0X/new2fly.git`
  - branch `master` tracks `origin/master` and is ahead by 3.
  - untracked `.cache/` remains and must not be pushed.

### Verification already completed before this task

- OpenTU typecheck passed.
- OpenTU targeted Vitest passed: 12 files / 46 tests.
- `python3 scripts/creative_release_gate.py build-sync-check --run-new-api-tests` passed.
- new-api Go tests and `go build ./...` passed via the release gate.
- `git diff --check` passed for all three repositories before commit.

### Deployment evidence / local staging capability

- Existing local staging runbook: `ops/newapi-opentu-staging/README.md`.
- Existing compose file: `ops/newapi-opentu-staging/docker-compose.yml`.
- Default staging URL: `http://localhost:39084/creative/`.
- Staging compose intentionally binds `127.0.0.1` by default and uses local-only SQLite/no provider/payment/CDN/S3 credentials.
- `ops/newapi-opentu-staging/.env.staging.local` exists, but must not be read or printed.
- Docker is available locally: `Docker version 29.5.2`; Docker Compose is available: `v5.1.4`.

## Requirements

1. Push the completed commits to the correct user-owned remotes, avoiding upstream/origin project remotes unless explicitly requested.
2. Do not read, print, or modify GitHub credentials or deployment secrets. GitHub credentials are on the host; if WSL push cannot authenticate, provide exact host-side push commands instead of trying to expose credentials.
3. Do not stage or commit local noise:
   - `opentu/packages/drawnix/audio-test.pptx`
   - `new-api/.codegraph/`
   - `new-api/.codex-flow/`
   - `new2fly/.cache/`
4. Preserve the two-route repo strategy:
   - current `opentu` fork already has platformization work on existing branch(es);
   - embedded OpenTU work should be pushed to a separate branch on the same fork rather than overwriting platformization work.
5. Build/rebuild a local staging candidate image from the committed `new-api` checkout after push planning is clear.
6. Restart or create the local staging compose project `newapi-opentu-staging` on `127.0.0.1:39084` unless the user explicitly chooses a different deployment target.
7. Verify deployment with non-secret checks only:
   - container running and healthy;
   - `/api/status` reachable;
   - `/creative/` reachable;
   - key embedded assets use `/creative/assets/...` references;
   - no normal `/creative/` route/header check returns 429 or 5xx;
   - admin/model-policy endpoint presence can be checked only with safe unauthenticated/expected-auth behavior, not by using secrets.
8. Record sanitized deployment evidence and final commands in this task.

## Out of Scope Unless Separately Confirmed

- Pushing to upstream/origin repos owned by upstream projects.
- Production/public deployment, DNS, TLS, reverse proxy, CDN, or LAN bind (`0.0.0.0`).
- Reading existing `.env` values, GitHub tokens, provider credentials, payment credentials, S3/CDN secrets, or browser session cookies.
- Creating real provider generation tasks or consuming provider quota.
- Modifying application code unless deployment verification finds a release-blocking defect.
- Resetting staging volumes with `docker compose down -v` unless explicitly confirmed because it destroys local staging data.

## Acceptance Criteria

- [ ] Push plan clearly identifies remote/branch for each repo.
- [ ] Required commits are pushed or exact host-side push commands are provided if local auth blocks push.
- [ ] No local noise files/directories are pushed.
- [ ] Local staging image is built from the committed candidate checkout.
- [ ] Local staging compose service is running and healthy at `http://localhost:39084`.
- [ ] `/creative/` smoke/route checks pass with sanitized evidence.
- [ ] Any deployment problem is captured with root cause and next action.
- [ ] Task records final push/deploy/stop/restart commands.
- [ ] No secrets are printed or committed.

## Scope Decision

The user confirmed continuing with the recommended safe local staging path for this task. Deployment target is local-only Docker Compose staging on `127.0.0.1:39084` / `http://localhost:39084/creative/`. Public/production deployment, LAN binding, DNS/TLS/reverse-proxy work, and secret-bearing environment promotion remain out of scope unless a separate explicit confirmation creates a new task.
