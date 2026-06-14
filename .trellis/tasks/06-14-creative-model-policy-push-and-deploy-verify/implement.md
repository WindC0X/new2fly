# Implementation Plan — Creative Model Policy Push And Deploy Verify

## Phase 1 — Planning artifacts

- [x] Create Trellis task.
- [x] Capture PRD requirements, constraints, and acceptance criteria.
- [x] Confirm local-only staging deployment target.
- [x] Write deployment/push design.
- [x] Curate `implement.jsonl` and `check.jsonl`.
- [x] Ask for planning review / `task.py start` approval.

## Phase 2 — Pre-push hygiene

1. Re-check known repository state:
   - `git -C /mnt/f/code/project/opentu status --short`
   - `git -C /mnt/f/code/project/new-api status --short`
   - `git -C /mnt/f/code/project/new2fly status --short`
2. Confirm only known local noise remains:
   - OpenTU: `packages/drawnix/audio-test.pptx`.
   - new-api: `.codegraph/`, `.codex-flow/`.
   - new2fly: `.cache/` plus this active task until committed.
3. Verify commit heads:
   - OpenTU `b206848e` on `feat/creative-embed`.
   - new-api `3cca3ac` on `feat/creative-embed`.
   - new2fly current planning commits will be committed before final archive/journal.

## Phase 3 — Push

Preferred push commands from this environment if ambient auth works:

```bash
git -C /mnt/f/code/project/opentu push -u fork feat/creative-embed
git -C /mnt/f/code/project/new-api push fork feat/creative-embed
git -C /mnt/f/code/project/new2fly push origin master
```

If authentication fails, stop retrying and provide equivalent host-side commands:

```bash
cd F:\code\project\opentu
git push -u fork feat/creative-embed
cd F:\code\project\new-api
git push fork feat/creative-embed
cd F:\code\project\new2fly
git push origin master
```

Then verify remote refs with safe commands such as:

```bash
git -C /mnt/f/code/project/opentu ls-remote fork refs/heads/feat/creative-embed
git -C /mnt/f/code/project/new-api ls-remote fork refs/heads/feat/creative-embed
git -C /mnt/f/code/project/new2fly ls-remote origin refs/heads/master
```

## Phase 4 — Build local staging image

1. Optionally run a quick release gate check if source changed since last gate:

```bash
cd /mnt/f/code/project/new2fly
python3 scripts/creative_release_gate.py check --source-diff-check
```

2. Build candidate image:

```bash
docker build --pull=false --progress=plain \
  -t new-api-creative-embed:staging-current \
  /mnt/f/code/project/new-api
```

## Phase 5 — Start/restart local staging

```bash
cd /mnt/f/code/project/new2fly
STAGING_BIND_ADDR=127.0.0.1 STAGING_PORT=39084 \
  docker compose -f ops/newapi-opentu-staging/docker-compose.yml \
  -p newapi-opentu-staging up -d
```

Wait for health:

```bash
docker inspect -f '{{json .State.Health}}' newapi-opentu-staging-new-api
curl -fsS http://localhost:39084/api/status
```

Do not run `down -v`.

## Phase 6 — Read-only staging checks

Run a small route/header smoke script or equivalent commands:

- `GET /api/status`.
- `HEAD/GET /creative/`.
- Parse `/creative/` entry refs and fetch representative `/creative/assets/*.js` and `*.css`.
- Confirm no normal route returns 429 or 5xx.
- Check expected no-secret behavior for admin endpoints without credentials if useful.

Suggested sanitized commands:

```bash
curl -sS -D /tmp/creative_headers.txt -o /tmp/creative_index.html http://localhost:39084/creative/
python3 - <<'PY'
from pathlib import Path
import re
html = Path('/tmp/creative_index.html').read_text(errors='replace')
print(sorted(set(re.findall(r'/creative/assets/[^"\']+\.(?:js|css)', html)))[:10])
PY
```

Record only status codes, paths, and sanitized observations.

## Phase 7 — Documentation and finish

1. Write `.trellis/tasks/06-14-creative-model-policy-push-and-deploy-verify/check.md` with:
   - push result or host-side command fallback;
   - deployment URL;
   - image/container health;
   - route/header table;
   - stop/restart commands;
   - warnings/not-run.
2. Run final hygiene:
   - `git diff --check` in touched repos;
   - `python3 ./.trellis/scripts/task.py validate` if context manifests changed.
3. Commit Trellis planning/check/report files.
4. Archive task and record journal.

## Risk / Rollback Points

- Push wrong remote: stop before pushing; if already pushed, ask before remote branch deletion/force push.
- Docker build fails: do not deploy stale image as if current; record failure.
- Staging unhealthy: capture sanitized logs/status, stop/restart only if non-destructive.
- Secret exposure risk: do not run commands that print env values; redact accidental sensitive output from reports.
