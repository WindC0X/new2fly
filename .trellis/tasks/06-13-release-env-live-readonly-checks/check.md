# Check — Local/Intranet Staging Deploy and Live Route Checks

Date: 2026-06-13 (Asia/Shanghai)
Task: `.trellis/tasks/06-13-release-env-live-readonly-checks`

## Result

**PASS for local/intranet staging route readiness.**

A temporary local `new-api` staging instance was started with sanitized environment and temporary SQLite, the embedded OpenTU artifact gate passed, browser embedded smoke passed, and redacted `GET`/`HEAD` route/header checks passed for the local `/creative/` static/API/relay boundary.

This is **not** a production deployment verdict. Production/CDN/S3/provider/payment/publish checks remain explicitly `not-run` until a real target and authorization exist.

## Safety / Scope Statement

- No production/staging public domain was called.
- No provider, payment, CDN, production S3, deploy, publish, SSH, remote rsync/scp, or quota-spending channel test was run.
- No secret values were read, printed, copied, or persisted.
- HTTP checks sent no cookies/auth/provider credentials and recorded only status + selected headers, not response bodies.
- Local server was short-lived and stopped after checks.

## Candidate Baseline

- OpenTU candidate: `39e0fe23180ffcfc98a767043869c4a90171356d`
- new-api candidate: `c9f318c4210fc47b7454750b610945df5f0ddec4`
- new2fly baseline before this task: `af00982fb12a5fd5a7e0c7365b45a137442d5392`

## Local Staging Setup

Staging target:

```text
http://localhost:39082
```

Command shape used, with only non-secret local values:

```bash
cd /mnt/f/code/project/new-api
tmpdir=$(mktemp -d /tmp/new-api-local-staging.XXXXXX)
env -i \
  PATH="$PATH" \
  HOME="$HOME" \
  USER="${USER:-windc0x}" \
  GOCACHE="$(go env GOCACHE)" \
  GOMODCACHE="$(go env GOMODCACHE)" \
  CGO_ENABLED="$(go env CGO_ENABLED)" \
  PORT=39082 \
  SQLITE_PATH="$tmpdir/one-api.db?_busy_timeout=30000" \
  SESSION_SECRET="creative-staging-local-session-secret" \
  GIN_MODE=release \
  SYNC_FREQUENCY=3600 \
  UPDATE_TASK=false \
  CHANNEL_UPSTREAM_MODEL_UPDATE_TASK_ENABLED=false \
  go run . --log-dir "$tmpdir/logs"
```

Observed startup evidence:

- `SQL_DSN not set, using SQLite as database`
- `REDIS_CONN_STRING not set, Redis is not enabled`
- `upstream model update task disabled by CHANNEL_UPSTREAM_MODEL_UPDATE_TASK_ENABLED`
- server ready at `http://localhost:39082/`

Cleanup:

- local server stopped after checks.
- temporary directory removed: `/tmp/new-api-local-staging.rIEVaq`.

Note: the local process still started internal scheduled tasks such as subscription quota reset and Codex credential auto-refresh. Because the process used temporary SQLite and sanitized env, no production/provider/payment/CDN credentials were present. Long-running scheduler policy remains a production deployment item.

## Gate 1 — Embedded Artifact / Source Diff Check

Command:

```bash
cd /mnt/f/code/project/new2fly
python3 scripts/creative_release_gate.py check --source-diff-check
```

Result: **PASS**

Key output:

- `opentu embedded index refs: 2 /creative/assets entries`
- `new-api:web embedded index refs: 2 /creative/assets entries`
- `new-api:router embedded index refs: 2 /creative/assets entries`
- `new-api:web matches opentu: 223 files`
- `new-api:router matches opentu: 223 files`
- `sourcemap-policy=allow; generated maps present: 1`
- `Creative embedded artifact contract holds`
- source-only `git diff --check` passed for `new2fly`, `opentu`, and `new-api` with generated artifact exclusions.

Production note: the generated map (`sw.js.map`) remains a production sourcemap policy decision.

## Gate 2 — Embedded Browser Smoke Against Local Staging

Command:

```bash
cd /mnt/f/code/project/new2fly
python3 scripts/creative_release_gate.py check \
  --embedded-smoke-url http://localhost:39082/creative/ \
  --drawnix-ready-timeout-ms 60000
```

Result: **PASS**

Key output:

- artifact contract checks passed again.
- `pnpm e2e:creative-embedded` ran Playwright project `creative-embedded`.
- `1 passed (18.5s)`.
- `NX Successfully ran target e2e for project web-e2e`.
- `no-secrets Creative release gate completed`.

Observed warning:

- pnpm printed `.npmrc` substitution warnings for `${NPM_TOKEN}` being unset. No token value was printed, and no publish/deploy command was run.

## Gate 3 — Local Route/Header Checks

Raw redacted table: [`route-check.md`](./route-check.md)

Summary:

| Surface | Result | Evidence |
|---|---|---|
| `/creative/` app shell | PASS | HEAD/GET `200`, `text/html`, `Cache-Control: no-cache`, no `Location`, `nosniff` |
| `/creative/sw.js` | PASS | HEAD/GET `200`, `text/javascript`, `no-cache`, no `Location`, `nosniff` |
| `/creative/version.json` | PASS | HEAD/GET `200`, `application/json`, `no-cache`, no `Location`, `nosniff` |
| existing JS asset | PASS | `/creative/assets/index-Bs1ESiJC.js` HEAD/GET `200`, `text/javascript`, `public, max-age=31536000, immutable`, no `Location`, `nosniff` |
| existing CSS asset | PASS | `/creative/assets/index-Bhsy9ZA3.css` HEAD/GET `200`, `text/css`, `public, max-age=31536000, immutable`, no `Location`, `nosniff` |
| missing asset | PASS | `/creative/assets/__missing_release_check__.js` HEAD/GET `404`, `text/plain`, `no-cache`, no `Location`, `nosniff`; not SPA fallback |
| API bootstrap | PASS | HEAD `404` and GET `401`, both `application/json`, `private, no-store`, no `Location`; GET unauthenticated fail-closed, HEAD wrong-method/static miss fail-closed |
| missing API | PASS | HEAD/GET `404`, `application/json`, `private, no-store`, no `Location`; not SPA fallback |
| relay GET/HEAD | PASS | `/creative/relay/v1/chat/completions` HEAD/GET `404`, `application/json`, `private, no-store`, no `Location`; GET/HEAD wrong-method fail-closed, not SPA fallback |

Important nuance:

- The route/header checker intentionally used only `GET`/`HEAD`. Relay POST unauthenticated behavior was exercised by the embedded smoke and local server log as `401`, but this check does not claim a separate POST route table.
- Non-SPA conclusions are based on status/content-type/cache/location and existing route contract; response bodies were intentionally not captured.

## Dynamic Workflow Independent Review

Dynamic workflow was used for independent read-only review over redacted observations.

Commands:

```bash
codex-flow run .codex-flow/generated/local-staging-route-review.workflow.ts
codex-flow run .codex-flow/generated/local-staging-static-review.workflow.ts
```

Journals:

- `.codex-flow/journal/local-staging-route-review.jsonl`
- `.codex-flow/journal/local-staging-static-review.jsonl`

Results:

| Branch | Verdict | Notes |
|---|---|---|
| `api_relay_security_boundary` | PASS | API/relay observations are JSON, `private, no-store`, empty `Location`, and fail closed rather than SPA fallback. |
| `no_secrets_and_production_gap` | WARN | Planning and route observations match no-secrets local staging, but final report must not overclaim production/CDN/S3/provider/payment readiness. |
| focused static route review | PASS | App shell, service worker, version metadata, hashed assets, and missing asset static miss match the embedded artifact contract. |
| original `route_static_cache_boundary` branch | TIMEOUT | Re-run still replayed timeout; covered by focused static route review. |

Required notes incorporated from dynamic review:

- `HEAD /creative/api/bootstrap = 404` should be treated as wrong-method fail-closed, not as a failure to match `GET 401`.
- Local route checks do not prove production CDN/reverse-proxy/S3/provider/payment behavior.
- `GET /creative/api/bootstrap` lacked `x-content-type-options` in the observation; not a release-blocking issue for this gate, but can be considered for response-header consistency hardening.

## Production-only Not-run Items

These remain out of scope and were not executed:

- Production/public base URL route/CDN/DNS checks.
- Redacted production env presence-only checks.
- S3-compatible asset storage health or object probes.
- Provider/payment/channel health.
- Publish credential identity/presence checks.
- NPM/Docker publish, Docker image push, deploy upload, SSH, rsync/scp.
- Final production sourcemap policy decision (`sw.js.map` currently present under allow policy).
- Production `FRONTEND_BASE_URL`/node-mode behavior.
- Long-running production scheduler/background-task policy.

## Acceptance Criteria Status

- [x] Planning artifacts reflect local/intranet staging rather than a pre-existing live target.
- [x] `implement.jsonl` and `check.jsonl` are curated.
- [x] Trellis task started before execution.
- [x] Release gate ran without inheriting provider/payment/CDN/production env.
- [x] Temporary local staging `new-api` process started with temporary SQLite and sanitized env.
- [x] Embedded browser smoke passed against `http://localhost:39082/creative/`.
- [x] Route/header checks ran and saved redacted observations only.
- [x] Dynamic-workflow sidecar reviewed redacted observations.
- [x] Production-only remaining items are listed as `not-run`.
- [x] No tracked source changes outside Trellis/spec/reporting were introduced.

## Final Verdict

Local/intranet staging route readiness for the embedded OpenTU/new-api candidate is **passed**.

Next release stage, if desired, should be a separate authorized task for either:

1. Docker image/container staging parity, or
2. real environment production/staging readiness with redacted env checks and explicit public route/CDN/S3/provider/payment authorization.
