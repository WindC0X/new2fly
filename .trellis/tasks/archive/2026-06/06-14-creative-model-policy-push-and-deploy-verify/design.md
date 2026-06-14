# Design — Creative Model Policy Push And Deploy Verify

## 1. Scope / Trigger

This task promotes already-committed Creative model-policy-unification work into remote branches and verifies a local Docker Compose staging deployment. It is operational/release work, not feature development.

The design is intentionally conservative:

- push only to user-owned fork remotes;
- deploy only to local staging bound to `127.0.0.1`;
- do not read or print secrets;
- do not create provider tasks or call provider/payment/CDN/S3 integrations;
- do not alter source code unless deployment verification discovers a release-blocking defect.

## 2. Repository / Branch Contract

### OpenTU

- Local path: `/mnt/f/code/project/opentu`.
- Current branch: `feat/creative-embed`.
- Commit to publish: `b206848e feat(creative): enforce embedded managed model policy`.
- User-owned remote: `fork` -> `https://github.com/WindC0X/opentu.git`.
- Upstream remote: `origin` -> `https://github.com/ljquan/opentu.git`.
- Push target: `fork feat/creative-embed`.
- Do not push to upstream `origin`.
- Preserve the user's platformized OpenTU branch by keeping this embedded work on `feat/creative-embed` (or another explicit embedded branch), not by overwriting platformization work.

### new-api

- Local path: `/mnt/f/code/project/new-api`.
- Current branch: `feat/creative-embed`.
- Commit to publish: `3cca3ac feat(creative): add admin model policy and embedded artifact`.
- User-owned remote: `fork` -> `https://github.com/WindC0X/new-api.git`.
- Upstream remote: `origin` -> `https://github.com/QuantumNous/new-api`.
- Push target: `fork feat/creative-embed`.
- Do not push to upstream `origin`.

### new2fly orchestration

- Local path: `/mnt/f/code/project/new2fly`.
- Current branch: `master`.
- Commits to publish:
  - `0f4d7b7 docs(creative): record model policy unification`
  - `55403fb chore(task): archive 06-14-creative-model-policy-unification`
  - `48185db chore: record journal`
- User-owned remote: `origin` -> `https://github.com/WindC0X/new2fly.git`.
- Push target: `origin master`.

## 3. Credentials / Secret Boundary

- GitHub credentials live on the host. This task must not inspect credential stores, tokens, auth config, or secret values.
- If `git push` from this environment succeeds using ambient host/credential-helper auth, record only remote/branch and commit hashes.
- If `git push` fails due to auth, do not ask for tokens. Provide exact host-side commands to run from a credentialed terminal.
- `.env.staging.local` exists for staging but must not be printed or committed. Only file existence may be checked.
- Do not print Docker env, container env, `.env`, session secret, provider keys, payment keys, S3/CDN credentials, or browser cookies.

## 4. Local Staging Deployment Contract

Use existing safe local staging assets:

- `ops/newapi-opentu-staging/docker-compose.yml`.
- `ops/newapi-opentu-staging/README.md`.
- Compose project: `newapi-opentu-staging`.
- Image tag: `new-api-creative-embed:staging-current`.
- Default bind: `127.0.0.1:39084:3000`.
- Default URL: `http://localhost:39084/creative/`.

Deployment steps:

1. Confirm release gate / source cleanliness from the committed state.
2. Build image from `/mnt/f/code/project/new-api`:
   `docker build --pull=false --progress=plain -t new-api-creative-embed:staging-current /mnt/f/code/project/new-api`.
3. Start/recreate compose project without destroying volumes:
   `STAGING_BIND_ADDR=127.0.0.1 STAGING_PORT=39084 docker compose -f ops/newapi-opentu-staging/docker-compose.yml -p newapi-opentu-staging up -d`.
4. Wait for healthcheck and `/api/status`.
5. Verify `/creative/` and asset routes.

Do not run `docker compose down -v` unless the user explicitly confirms data reset.

## 5. Verification Contract

### Push verification

- `git status --short` in each repo shows only known local noise after commit/push.
- `git log --oneline -1` matches expected commit.
- `git branch -vv` or `git ls-remote` confirms remote branch contains expected commit when possible.

### Staging verification

Use only safe unauthenticated/read-only checks:

- `docker ps` / `docker inspect` health state for `newapi-opentu-staging-new-api`.
- `curl -fsS http://localhost:39084/api/status` returns success JSON.
- `curl -I http://localhost:39084/creative/` returns 200/3xx as expected, not 429/5xx.
- Fetch `http://localhost:39084/creative/` and verify entry refs include `/creative/assets/...`.
- Check representative asset URLs from `index.html` return 200 and sane content type.
- Optional expected-auth checks for admin/model-policy endpoints may only verify safe status shape (401/403/redirect/200 without credentials); do not bypass auth with cookies/tokens.

### Evidence recording

Record in `check.md`:

- commit hashes pushed / host-side push commands if push not possible;
- image build status;
- compose project/container status;
- sanitized curl status table;
- final URL;
- stop/restart commands;
- any warnings or not-run checks.

## 6. Rollback / Recovery

### Push rollback

- If wrong remote/branch is targeted before push completes: abort and correct command.
- If a push accidentally targets wrong remote but succeeds, do not force-push or delete remote branches without separate confirmation. Record the issue and ask for explicit remediation.

### Staging rollback

- Stop without deleting data:
  `docker compose -f ops/newapi-opentu-staging/docker-compose.yml -p newapi-opentu-staging down`.
- Revert to previous staging image only if a prior tag exists and user asks; otherwise leave failed image stopped and record logs sanitized.
- Data reset is destructive and requires explicit confirmation:
  `docker compose ... down -v`.

## 7. Trade-offs

- Local staging gives strong artifact/container/route verification with no secret exposure, but does not prove public DNS/TLS/reverse-proxy behavior.
- Pushing to fork branches preserves upstream safety and the two-route OpenTU strategy, but does not create upstream PRs unless a later task does so.
- Avoiding secrets means provider-backed generation is not validated here; this is intentional and belongs to a separate credentialed staging/production validation task.
