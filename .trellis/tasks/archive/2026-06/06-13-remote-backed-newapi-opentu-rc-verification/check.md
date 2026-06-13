# Check Report — Remote-backed new-api / OpenTU RC Verification

Date: 2026-06-13 (Asia/Shanghai)

## Candidate refs verified

| Repo | Candidate ref | Live remote commit | Local verification HEAD | Result |
| --- | --- | --- | --- | --- |
| OpenTU | `WindC0X/opentu:newapi-embed-release-gate` | `39e0fe23180ffcfc98a767043869c4a90171356d` | `39e0fe23180ffcfc98a767043869c4a90171356d` | match |
| new-api | `WindC0X/new-api:feat/creative-embed` | `c9f318c4210fc47b7454750b610945df5f0ddec4` | `c9f318c4210fc47b7454750b610945df5f0ddec4` | match |
| new2fly | `WindC0X/new2fly:master` | `e40508f1d13f6356bfb0f5dd2c8b30d4456f829d` | `e40508f1d13f6356bfb0f5dd2c8b30d4456f829d` | match |

Command evidence:

```bash
git -C /mnt/f/code/project/opentu ls-remote fork refs/heads/newapi-embed-release-gate
git -C /mnt/f/code/project/new-api ls-remote fork refs/heads/feat/creative-embed
git -C /mnt/f/code/project/new2fly ls-remote origin refs/heads/master
```

Output commits matched local `git rev-parse HEAD` for all three repos.

Note: OpenTU is currently checked out on local branch `feat/creative-embed`, but its HEAD matches both the intended live remote commit and the local `newapi-embed-release-gate` ref.

## Verification commands and results

### 1. Artifact/source/new-api release gate

Command:

```bash
cd /mnt/f/code/project/new2fly
python3 scripts/creative_release_gate.py check --source-diff-check --run-new-api-tests
```

Result: pass, exit 0.

Key evidence:

- `opentu`, `new-api:web`, and `new-api:router` embedded index files each contain `2` `/creative/assets` refs.
- Artifact identity passed by file list and hash:
  - OpenTU dist: `223` files.
  - `new-api:web` matches OpenTU: `223` files.
  - `new-api:router` matches OpenTU: `223` files.
- Sourcemap policy: default `allow`; generated maps present: `1` (`sw.js.map`).
- Source diff checks passed:
  - `new2fly`: `git diff --check -- :!.codex-flow/** :!.cache/**`
  - `opentu`: `git diff --check -- :!dist/**`
  - `new-api`: `git diff --check -- :!web/creative/dist/** :!router/web/creative/dist/**`
- `new-api` tests/build passed:
  - `go test -count=1 .`
  - `go test -count=1 ./router ./middleware ./controller ./model ./service ./relay/...`
  - `go build ./...`

### 2. OpenTU typecheck

Command:

```bash
cd /mnt/f/code/project/opentu
pnpm nx run drawnix:typecheck
```

Result: pass, exit 0.

Evidence: `NX Successfully ran target typecheck for project drawnix (2m)`.

Known local warning: `.npmrc` references `${NPM_TOKEN}`; the token was not read or printed.

### 3. OpenTU cold smoke

Command:

```bash
cd /mnt/f/code/project/opentu
NX_SKIP_NX_CACHE=true pnpm e2e:smoke
```

Result: pass, exit 0.

Evidence:

- Playwright smoke ran without Nx cache.
- `2 passed (2.1m)`.
- `NX Successfully ran target e2e for project web-e2e (2m)` with `--project=smoke`.

Known warnings: missing `${NPM_TOKEN}` interpolation, Sass deprecations, and stale Browserslist data. These did not fail the smoke.

### 4. Embedded `/creative/` smoke against temporary local new-api

Primary command was rerun with a sanitized process environment after dynamic-workflow review pointed out that inherited host environment should be avoided for no-secrets verification.

Server command shape:

```bash
cd /mnt/f/code/project/new-api
tmpdir=$(mktemp -d /tmp/new-api-creative-smoke-sanitized.XXXXXX)
env -i \
  PATH="$PATH" \
  HOME="$HOME" \
  USER="$USER" \
  GOCACHE="$(go env GOCACHE)" \
  GOMODCACHE="$(go env GOMODCACHE)" \
  CGO_ENABLED="$(go env CGO_ENABLED)" \
  PORT=39081 \
  SQLITE_PATH="$tmpdir/one-api.db?_busy_timeout=30000" \
  SESSION_SECRET="creative-smoke-local-session-secret" \
  GIN_MODE=release \
  SYNC_FREQUENCY=3600 \
  UPDATE_TASK=false \
  CHANNEL_UPSTREAM_MODEL_UPDATE_TASK_ENABLED=false \
  go run . --log-dir "$tmpdir/logs"
```

Server evidence:

- `.env` and `.env.local` were absent in `/mnt/f/code/project/new-api`.
- `SQL_DSN not set, using SQLite as database`.
- `REDIS_CONN_STRING not set, Redis is not enabled`.
- `upstream model update task disabled by CHANNEL_UPSTREAM_MODEL_UPDATE_TASK_ENABLED`.
- Local ready URL: `http://localhost:39081/`.

Smoke command:

```bash
cd /mnt/f/code/project/new2fly
python3 scripts/creative_release_gate.py check \
  --embedded-smoke-url http://localhost:39081/creative/ \
  --drawnix-ready-timeout-ms 60000
```

Result: pass, exit 0.

Evidence:

- Artifact identity rechecked and passed before smoke.
- `pnpm e2e:creative-embedded` ran with `CREATIVE_EMBEDDED_BASE_URL=http://localhost:39081/creative/` and `NX_SKIP_NX_CACHE=true` set by the gate script.
- Playwright result: `1 passed (20.3s)`.
- Gate result: `[done] no-secrets Creative release gate completed`.
- Observed local route boundary responses in server log:
  - `GET /creative/api/bootstrap` returned `401`.
  - `GET /creative/relay/v1/chat/completions` returned `404` instead of SPA fallback.
  - `POST /creative/relay/v1/chat/completions` returned `401`.

The temporary server was stopped after the smoke.

## Dynamic-workflow sidecar check

A read-only dynamic workflow was run for independent cross-checking of:

1. candidate refs and git hygiene,
2. release gate script and artifact policy,
3. embedded smoke acceptance coverage.

Command:

```bash
cd /mnt/f/code/project/new2fly
codex-flow run .codex-flow/generated/remote-backed-rc-check.workflow.ts
```

Journal:

```text
/mnt/f/code/project/new2fly/.codex-flow/journal/remote-backed-rc-check.jsonl
```

Sidecar verdicts were `warn`, not because executed checks failed, but because the sidecar was read-only and noted process gaps. Addressed items:

- Live remote refs were verified with `git ls-remote` after the sidecar noted remote-tracking refs can be stale.
- Embedded smoke was rerun with `env -i` after the sidecar noted inherited environment could violate no-secrets verification hygiene.
- Both release-gate command families were executed: `--source-diff-check --run-new-api-tests` and `--embedded-smoke-url`.

Remaining sidecar notes that are informational:

- OpenTU current branch name differs from the candidate branch name, but the commit is identical.
- Untracked local/tool files remain; no tracked diffs were introduced.

## Git hygiene after verification

Command:

```bash
git -C /mnt/f/code/project/opentu status --short
git -C /mnt/f/code/project/new-api status --short
git -C /mnt/f/code/project/new2fly status --short
```

Observed:

```text
opentu:
?? packages/drawnix/audio-test.pptx

new-api:
?? .codegraph/
?? .codex-flow/

new2fly:
?? .cache/
?? .trellis/tasks/06-13-remote-backed-newapi-opentu-rc-verification/
```

No unintended tracked diffs were observed. The listed items are existing/local tool or task artifacts.

## Remaining release-environment-only checks

Not exercised in this no-secrets local verification by design:

- Production secrets and secret injection.
- Provider/payment/channel health.
- S3/object storage and CDN/domain configuration.
- NPM token/publish path.
- Production sourcemap policy decision. Current gate default allows `sw.js.map`; run with `--sourcemap-policy forbid` if production policy forbids generated maps.
- Long-running scheduler behavior in the release environment.

## Acceptance criteria

- [x] Candidate remote branch commits are listed and match local verification heads.
- [x] Artifact gate passes on the candidate branches.
- [x] `new-api` selected tests/build pass.
- [x] OpenTU typecheck and cold smoke pass.
- [x] Embedded `/creative/` smoke runs against local `new-api` and passes.
- [x] No unintended tracked diffs remain after verification.
- [x] Verification report is written to this task.

## Conclusion

The pushed remote-backed RC formed by the three candidate refs passed the no-secrets Creative embedded release gate in local verification. Remaining checks are release-environment-only operational checks listed above.
