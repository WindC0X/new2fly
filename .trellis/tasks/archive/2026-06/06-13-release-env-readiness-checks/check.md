# Check Report — Release Environment Readiness Checks

Date: 2026-06-13 (Asia/Shanghai)

Scope executed in this task: **Tier A static/offline checks only**. No real `.env`/secret store values were read, no provider/payment/CDN/production endpoints were called, and no publish/deploy/upload commands were executed.

## Baseline RC Evidence

The no-secrets local RC gate had already passed in `.trellis/tasks/archive/2026-06/06-13-remote-backed-newapi-opentu-rc-verification/check.md`:

- OpenTU `WindC0X/opentu:newapi-embed-release-gate` at `39e0fe23180ffcfc98a767043869c4a90171356d`.
- new-api `WindC0X/new-api:feat/creative-embed` at `c9f318c4210fc47b7454750b610945df5f0ddec4`.
- Artifact identity/source/new-api Go tests/build passed.
- OpenTU typecheck and cold smoke passed.
- Embedded `/creative/` smoke passed against sanitized local SQLite `new-api`.

This task did not repeat the full RC gate; it focused on release-environment-only surfaces.

## Commands Executed

### Static sourcemap policy probe

```bash
cd /mnt/f/code/project/new2fly
python3 scripts/creative_release_gate.py check --sourcemap-policy forbid
```

Result: expected policy failure, exit `1`.

Evidence:

```text
[check] opentu embedded index refs: 2 /creative/assets entries
[check] new-api:web embedded index refs: 2 /creative/assets entries
[check] new-api:router embedded index refs: 2 /creative/assets entries
[check] opentu file count: 223
[check] new-api:web matches opentu: 223 files
[check] new-api:router matches opentu: 223 files
sourcemap policy forbids generated maps; found first entries: ['sw.js.map']
```

Interpretation: artifact identity still holds, but production must explicitly decide whether `sw.js.map` is allowed. If production forbids maps, the artifact source must be rebuilt/stripped consistently before release.

### Static syntax/format checks

```bash
node --check /mnt/f/code/project/opentu/scripts/deploy-hybrid.js
node --check /mnt/f/code/project/opentu/scripts/publish-npm.js
node --check /mnt/f/code/project/opentu/scripts/upload-and-deploy.js
node --check /mnt/f/code/project/opentu/scripts/create-deploy-package.js
node -e "JSON.parse(require('fs').readFileSync('/mnt/f/code/project/opentu/package.json','utf8'))"
python3 - <<'PY'
from pathlib import Path
import yaml
for p in [
    Path('/mnt/f/code/project/new-api/.github/workflows/docker-build.yml'),
    Path('/mnt/f/code/project/new-api/.github/workflows/docker-image-alpha.yml'),
    Path('/mnt/f/code/project/new-api/.github/workflows/docker-image-nightly.yml'),
]:
    yaml.safe_load(p.read_text(encoding='utf-8'))
PY
```

Result: pass, all exit `0`.

### Presence-only local env-file check

```bash
for p in \
  /mnt/f/code/project/new-api/.env \
  /mnt/f/code/project/new-api/.env.local \
  /mnt/f/code/project/opentu/.env \
  /mnt/f/code/project/opentu/.env.local; do
  test -e "$p" && echo "present: $p" || echo "absent: $p"
done
```

Result: all four were absent. No env values were read.

### Dynamic-workflow sidecar review

Commands:

```bash
codex-flow run .codex-flow/generated/release-env-readiness-check.workflow.ts
codex-flow run .codex-flow/generated/release-env-publish-provider-check.workflow.ts
```

Journals:

```text
/mnt/f/code/project/new2fly/.codex-flow/journal/release-env-readiness-check.jsonl
/mnt/f/code/project/new2fly/.codex-flow/journal/release-env-publish-provider-check.jsonl
```

Result:

- `release-env-readiness-check.workflow.ts`: two read-only branches completed; one publish/provider branch timed out.
- `release-env-publish-provider-check.workflow.ts`: the timed-out publish/provider surface was rerun as a narrower read-only workflow and completed.

## Surface Status Matrix

| Surface | Status | Evidence | Risk / Follow-up |
| --- | --- | --- | --- |
| Planning / safety boundary | pass | `prd.md`, `design.md`, `implement.md` define Tier A static/offline vs Tier B live read-only boundaries. | Tier B still requires explicit target environment and operation authorization. |
| Env/secrets injection | warn | `.env.example` documents expected keys; `common/init.go` rejects `SESSION_SECRET=random_string`; `SQL_DSN` missing/local falls back to SQLite; release env was not inspected. | Need redacted presence-only check in staging/production. Do not print full env. |
| Dangerous defaults | warn | `docker-compose.yml` example enables `SQL_DSN` and `REDIS_CONN_STRING` with `123456`; `image: calciumion/new-api:latest`; `SESSION_SECRET` is only commented. | Example compose is not production-safe without overrides. Pin image/tag and rotate defaults. |
| Creative static `/creative/` route/cache/SW | warn | `SetWebRouter` serves local `/creative/`, assets immutable, API/relay no-store, missing assets static 404. Tests cover this. | If `NODE_TYPE=slave` and `FRONTEND_BASE_URL` is set, `SetRouter` registers only Creative API/relay and redirects `/creative/` static paths externally. Live target must confirm this deployment mode. |
| Creative API/relay boundary | pass (static) | `/creative/api` and `/creative/relay/v1` use session auth, no-store, same-origin/nonce where required, and forbidden relay field filters per docs/specs/tests. | Live route checks still needed for CDN/reverse-proxy behavior. |
| Object storage / S3-compatible assets | warn | `CreativeAssetRuntime` fails closed for production DB storage or incomplete S3 config; public DTO returns `/creative/api/assets/:id/content` and not S3 object keys. | Need redacted env presence and a separately authorized object-storage health probe; no live S3 call was made here. |
| Provider/channel background tasks | warn | `CHANNEL_UPSTREAM_MODEL_UPDATE_TASK_ENABLED` defaults true and starts an upstream model update task; `UPDATE_TASK` defaults true. | Release owner must decide if background provider/task polling is allowed on startup and ensure only master runs it. |
| Payment/provider/channel health | not-run | Routes exist for `/api/status`, admin channel tests, and payment callbacks, but safe health credentials/target were not provided. | Requires explicit target and read-only policy. Do not trigger paid generation, payment, refund, webhook, or channel mutation in this task. |
| Docker publish path | warn | `new-api/Dockerfile` copies prebuilt `web/creative/dist`; tracked dist exists. Docker workflows push multi-arch images and sign/SBOM stable/alpha builds. | Dockerfile does not build OpenTU; CI/release must guarantee synced `web/creative/dist` before image build. Stable tag workflow pushes `latest`. |
| NPM/hybrid publish path | warn | Opentu scripts support npm/hybrid release; `.npmrc` uses `${NPM_TOKEN}` placeholder; `node --check` passed. | `release:dry` / `npm:publish:dry` are not pure offline checks: they may access npm registry and/or mutate `dist`. Do not run without explicit approval. |
| Sourcemap policy | warn | Hybrid `deploy-hybrid.js` excludes `.map`; embedded new-api gate currently allows `sw.js.map`; `--sourcemap-policy forbid` fails on `sw.js.map`. | Production must choose: allow known generated map with rationale or forbid and rebuild/strip at source while preserving artifact identity. |
| CDN provider consistency | warn | `deploy-hybrid.js` has `runtimeCdnProvider='jsdelivr'` but fixed `cdnProvider='unpkg'` in some paths, per sidecar/static grep. | Standalone/hybrid OpenTU release path may have provider mismatch; embedded new-api path should not rely on external CDN for core `/creative/` assets. |
| Secrets/publish credentials | not-run | Workflow files reference `DOCKERHUB_USERNAME`, `DOCKERHUB_TOKEN`, `GITHUB_TOKEN`; Opentu `.npmrc` references `${NPM_TOKEN}`. | Verify presence by secret name only in CI/host tooling; never read values. |

## Tier B Live Read-only Runbook (Not Run Here)

Run only after the user provides the target environment/base URL and explicitly authorizes read-only checks.

### 1. Redacted env presence-only check

Run inside the authorized release shell/container. It reports only states, not values.

```bash
python3 - <<'PY'
import os, re
required = [
    'SESSION_SECRET', 'SQL_DSN', 'FRONTEND_BASE_URL', 'TRUSTED_REDIRECT_DOMAINS',
    'CREATIVE_VIDEO_RELAY_ENABLED', 'CREATIVE_ASSET_SYNC_ENABLED',
    'UPDATE_TASK', 'CHANNEL_UPSTREAM_MODEL_UPDATE_TASK_ENABLED', 'NODE_TYPE', 'NODE_NAME',
]
asset = [
    'CREATIVE_ASSET_ROLLOUT_MODE', 'CREATIVE_ASSET_STORAGE',
    'CREATIVE_ASSET_S3_ENDPOINT', 'CREATIVE_ASSET_S3_REGION', 'CREATIVE_ASSET_S3_BUCKET',
    'CREATIVE_ASSET_S3_PREFIX', 'CREATIVE_ASSET_S3_ACCESS_KEY_ID',
    'CREATIVE_ASSET_S3_SECRET_ACCESS_KEY', 'CREATIVE_ASSET_S3_FORCE_PATH_STYLE',
    'CREATIVE_ASSET_USER_MAX_BYTES', 'CREATIVE_ASSET_USER_MAX_ASSETS',
]
extra = [
    'CRYPTO_SECRET', 'LOG_SQL_DSN', 'REDIS_CONN_STRING', 'TLS_INSECURE_SKIP_VERIFY',
    'ENABLE_PPROF', 'DEBUG', 'PYROSCOPE_URL', 'PYROSCOPE_BASIC_AUTH_USER',
    'PYROSCOPE_BASIC_AUTH_PASSWORD', 'RELAY_TIMEOUT', 'RELAY_IDLE_CONN_TIMEOUT',
    'BATCH_UPDATE_ENABLED', 'POLLING_INTERVAL',
    'CHANNEL_UPSTREAM_MODEL_UPDATE_TASK_INTERVAL_MINUTES',
    'CHANNEL_UPSTREAM_MODEL_UPDATE_MIN_CHECK_INTERVAL_SECONDS',
    'DIFY_DEBUG', 'GENERATE_DEFAULT_TOKEN',
]
unsafe_exact = {
    'SESSION_SECRET': {'random_string', 'change-me', 'changeme'},
    'CREATIVE_ASSET_S3_ACCESS_KEY_ID': {'change-me', 'changeme'},
    'CREATIVE_ASSET_S3_SECRET_ACCESS_KEY': {'change-me', 'changeme'},
}
unsafe_re = {
    'SQL_DSN': [r':123456@', r'^local$'],
    'LOG_SQL_DSN': [r':123456@'],
    'REDIS_CONN_STRING': [r':123456@'],
    'RELAY_TIMEOUT': [r'^0$'],
}
def val(name): return os.environ.get(name)
def state(name):
    v = val(name)
    if v is None: return 'missing'
    if v.strip() == '': return 'empty'
    if v.strip() in unsafe_exact.get(name, set()): return 'unsafe-default'
    if any(re.search(pattern, v) for pattern in unsafe_re.get(name, [])): return 'unsafe-default'
    if name in {'TLS_INSECURE_SKIP_VERIFY', 'ENABLE_PPROF', 'DEBUG', 'GENERATE_DEFAULT_TOKEN'} and v.lower() == 'true': return 'unsafe-enabled'
    return 'present'
for name in required:
    print(f'{name}\t{state(name)}')
if (val('CREATIVE_ASSET_SYNC_ENABLED') or '').lower() == 'true':
    for name in asset:
        print(f'{name}\t{state(name)}')
    ok = val('CREATIVE_ASSET_ROLLOUT_MODE') == 'production' and val('CREATIVE_ASSET_STORAGE') == 's3-compatible'
    print('CREATIVE_ASSET_PRODUCTION_CONTRACT\t' + ('present' if ok else 'unsafe-or-missing'))
for name in extra:
    print(f'{name}\t{state(name)}')
PY
```

### 2. Read-only HTTP route/CDN check

Replace `BASE` after explicit authorization.

```bash
BASE='https://example.invalid'
for path in \
  '/creative/' \
  '/creative/sw.js' \
  '/creative/version.json' \
  '/creative/assets/index-Bs1ESiJC.js' \
  '/creative/assets/index-Bhsy9ZA3.css' \
  '/creative/assets/__missing_release_check__.js' \
  '/creative/api/bootstrap' \
  '/creative/api/missing' \
  '/creative/relay/v1/chat/completions'; do
  printf '\n### %s\n' "$path"
  curl -ksS -o /dev/null -D - -w 'status=%{http_code} url=%{url_effective}\n' "$BASE$path" \
    | sed -n -E '/^(HTTP\/|cache-control:|content-type:|location:|x-creative-|status=)/Ip'
done
```

Expected high-level behavior:

- `/creative/` returns HTML app shell and is not redirected to an external frontend unless that is an intentional deployment mode.
- Existing `/creative/assets/*` are static assets, preferably immutable cache.
- Missing `/creative/assets/*` is `404` and not HTML SPA.
- `/creative/api/*` and `/creative/relay/v1/*` do not return Creative app-shell HTML and are `private, no-store` or equivalent.

### 3. Object storage check

Not runnable from this workspace. For production asset sync, use only an explicitly authorized disposable object/prefix or provider-side read-only metadata check. Do not list unrelated keys and do not print bucket credentials.

### 4. Provider/payment/channel health

Not runnable from this workspace. Use only approved read-only status endpoints or admin health functions. Do not run paid generation, channel test calls, payment requests, refunds, or webhook delivery tests without separate confirmation.

### 5. Publish credentials

Verify by secret name/identity only:

- GitHub Actions: list required secret names, not values (`DOCKERHUB_USERNAME`, `DOCKERHUB_TOKEN`; GHCR uses `GITHUB_TOKEN`; Opentu standalone publish needs `NPM_TOKEN`).
- Docker/NPM: use non-mutating identity/session commands only after authorization. Do not run `npm publish`, `docker buildx ... --push`, `pnpm run release`, `deploy:upload`, or SSH deployment scripts.

## Findings Requiring Product/Ops Decision

1. **Sourcemap policy**: `sw.js.map` is present. Decide allow vs forbid before production.
2. **FRONTEND_BASE_URL / node mode**: single-node/master ignores `FRONTEND_BASE_URL`, but non-master with `FRONTEND_BASE_URL` will not serve local `/creative/` static assets. Target deployment mode must be confirmed.
3. **Creative asset storage**: if asset sync is enabled in production, require `CREATIVE_ASSET_ROLLOUT_MODE=production` and `CREATIVE_ASSET_STORAGE=s3-compatible` with complete S3 config.
4. **Background external tasks**: confirm whether `CHANNEL_UPSTREAM_MODEL_UPDATE_TASK_ENABLED` and `UPDATE_TASK` should run in the release environment.
5. **OpenTU standalone/hybrid vs embedded path**: do not conflate Opentu npm/CDN/hybrid release with the embedded new-api path; the current RC was for embedded new-api.

## Acceptance Criteria Status

- [x] Planning artifacts define safe vs live check boundaries.
- [x] Static/offline release-readiness checks are executed and recorded.
- [x] Dynamic-workflow sidecar check is executed for independent review.
- [x] Live endpoint/secret checks were not run because no target environment authorization was provided.
- [x] `check.md` lists pass/warn/fail/not-run status per surface.
- [x] Remaining manual release-environment checks are listed with exact runbook shape.
- [x] No tracked source changes outside Trellis/spec/reporting were introduced by this task.

## Conclusion

Tier A static/offline release readiness is complete. The release candidate is still blocked on Tier B operational confirmation before a real production/staging release claim can be made, chiefly: redacted env presence, target `/creative/` route/CDN behavior, S3-compatible asset storage health, provider/payment/channel read-only health, publish credential presence, and sourcemap policy decision.
