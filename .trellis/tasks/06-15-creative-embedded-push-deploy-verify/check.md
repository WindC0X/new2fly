# Check — Creative Embedded Push And Deployment Verification

Date: 2026-06-15

## Scope decision

- Deployment scope for this task: push and verify remote refs, then verify the existing local staging target.
- No production/public deployment was attempted because no real deployment URL/host and no production S3-compatible Creative asset storage were provided.
- Local staging target: `http://127.0.0.1:39084/creative/`.
- Local staging storage mode: `CREATIVE_ASSET_STORAGE=database`; accepted for local smoke only, not production.

## Git / push verification

### WSL credential boundary

Command class: WSL `git push --dry-run` with prompts disabled.

Result:

```text
fatal: could not read Username for 'https://github.com': terminal prompts disabled
```

Conclusion: WSL does not have usable GitHub credentials. Pushes were run through host Windows Git so host credential manager could be used without printing or copying tokens.

### Host dry-run

Host Windows Git dry-run succeeded for all three intended refs:

```text
opentu  fork   feat/creative-embed:feat/creative-embed  dc252529..bc938728
new-api fork   feat/creative-embed:feat/creative-embed  932ffbf..bfef310
new2fly origin master:master                            c56fa4c..525b5b3
```

`new2fly` was not pushed at this dry-run point because this task record was still uncommitted.

### Code repository pushes completed

Pushed with host Windows Git:

```text
opentu fork feat/creative-embed:feat/creative-embed
new-api fork feat/creative-embed:feat/creative-embed
```

Verified live remote refs:

```text
bc938728754f7acbfbe8043a717c823bcedcacf0 refs/heads/feat/creative-embed  # WindC0X/opentu
bfef3101603837088f011112101038bbcde01b14 refs/heads/feat/creative-embed  # WindC0X/new-api
```

`new2fly` final work-record push was completed after this task record commit:

```text
08c498f6e555e6d4feb3195809fd575c2ff3e359 refs/heads/master  # WindC0X/new2fly, work-record commit
```

Follow-up archive/journal commits may move `origin/master` again after this check record, but this verifies the task work-record commit was published.

## Local staging route/header matrix

Target: `http://127.0.0.1:39084`
Container state at check time: `newapi-opentu-staging-new-api` using `new-api-creative-embed:staging-current`, healthy, bound to `127.0.0.1:39084->3000/tcp`.

Read-only route/header checks:

| Method | Path | Status | Content-Type | Cache-Control | Classification |
|---|---:|---:|---|---|---|
| GET | `/creative/` | 200 | `text/html; charset=utf-8` | `no-cache` | app shell served by new-api |
| GET | `/creative/sw.js` | 200 | `text/javascript; charset=utf-8` | `no-cache` | service worker served in Creative scope |
| GET | `/creative/version.json` | 200 | `application/json` | `no-cache` | metadata JSON served |
| GET | `/creative/assets/index-Bhsy9ZA3.css` | 200 | `text/css; charset=utf-8` | `public, max-age=31536000, immutable` | hashed static asset served |
| GET | `/creative/assets/__missing_release_check__.js` | 404 | `text/plain; charset=utf-8` | `no-cache` | static miss; not SPA HTML fallback |
| GET | `/creative/api/bootstrap` | 401 | `application/json; charset=utf-8` | `private, no-store` | API boundary; unauthenticated request rejected |
| GET | `/creative/relay/v1/chat/completions` | 404 | `application/json; charset=utf-8` | `private, no-store` | relay boundary; wrong-method/non-SPA path |

All checked responses included an `X-Oneapi-Request-Id`. Static/app responses included `X-Content-Type-Options: nosniff` where expected.

## Embedded release gate / browser smoke

Command:

```bash
python3 scripts/creative_release_gate.py check --embedded-smoke-url http://127.0.0.1:39084/creative/
```

Result:

```text
[ok] Creative embedded artifact contract holds
1 passed (creative-embedded Playwright smoke)
[done] no-secrets Creative release gate completed
```

Notes:

- The command emitted `.npmrc` warnings about missing `NPM_TOKEN`; no token was printed and the warning did not affect the smoke.
- Artifact identity checks passed across `opentu/dist/apps/web`, `new-api/web/creative/dist`, and `new-api/router/web/creative/dist`.

## Authenticated Creative cloud-sync smoke

Credential handling:

- Used previously authorized local admin credential via stdin into a transient child process environment.
- Did not write password/token to files, command-line args, task records, or output.

Command shape:

```bash
CREATIVE_BASE_URL=http://127.0.0.1:39084 node /tmp/creative-cloud-sync-smoke.cjs
```

Result summary:

```text
login: 200 success=true
bootstrap: 200 success=true assetSyncEnabled=true csrfTokenLength=48 nonceLength=48
document-create: 201 success=true
document-list: 200 success=true listed=true
document-get: 200 success=true
document-bad-nonce: 403
document-update: 200 success=true revision=2
asset-upload: 201 success=true url=/creative/api/assets/<asset-id>/content size=66
asset-content: 206 contentType=image/png bytes=8
asset-delete: 200 success=true
document-delete: 200 success=true
done: ok=true
```

Security assertions covered by the smoke:

- Creative bootstrap returns auth nonce/CSRF only for logged-in browser session.
- Bad nonce is rejected with 403.
- Uploaded asset response uses same-origin `/creative/api/assets/:id/content` URL.
- Upload response did not leak storage/provider internals according to the smoke's denylist.
- Ranged content streaming returns 206.

## Dynamic workflow review

Command:

```bash
codex-flow run .codex-flow/generated/creative-embedded-push-deploy-check.workflow.ts
```

Journal:

```text
.codex-flow/journal/creative-embedded-push-deploy-check.jsonl
```

Parallel branches:

1. Remote refs and push safety: `pass`. Verified evidence is coherent for OpenTU/new-api pushed refs and new2fly final push deferral. Required follow-up: after task commit, push `new2fly` and record final `git ls-remote origin refs/heads/master`.
2. Local staging route and smoke evidence: `warn` only because the read-only sub-agent environment could not reconnect to `127.0.0.1:39084`; main-session route/header, release gate, and authenticated smoke evidence were already recorded above. Required follow-up applies only if claiming production/public readiness.
3. Production boundary and cloud-sync risk: `warn` with no blocking finding. It found no secret leakage, no missing S3-compatible caveat, and no production-readiness overclaim. It flagged a low-severity wording risk in the PRD top-level goal, which was corrected to state that this run is local staging only and real deployment remains blocked pending target/S3.

Overall result: no blocking finding; proceed to final new2fly commit/push after quality checks.

Main-session liveness follow-up after the workflow warning:

```text
creative_status=200
bootstrap_unauth_status=401
```

## Production readiness status

Not run / not claimed:

- Public route/CDN/DNS checks.
- Production deployment to private/public host.
- Production S3-compatible asset storage health.
- Provider/payment/channel health.
- Docker registry or NPM publishing.
- Production `FRONTEND_BASE_URL` mode.

Production cloud sync remains blocked until a real target and private S3-compatible storage env are provided.

## Rollback notes

- Code refs are pushed as branch updates, not force-pushed over unrelated platformization refs.
- If a later deployment fails, rollback by redeploying the previous `new-api` image/ref.
- If storage health is questionable, set `CREATIVE_ASSET_SYNC_ENABLED=false` and restart; do not delete object storage contents during rollback.
