# Check — Creative Embedded Production Deployment Preparation

Date: 2026-06-15  
Scope: runbook/preflight artifact verification only. No real production deployment, container restart, DB mutation, S3 setup, provider call, payment flow, or quota-consuming request was executed.

## Local quality gates

### Shell syntax

```bash
bash -n ops/newapi-opentu-production/creative-route-check.sh
bash -n ops/newapi-opentu-production/creative-cloud-sync-smoke.sh
```

Result: passed.

### Trellis context validation

```bash
python3 ./.trellis/scripts/task.py validate 06-15-creative-embedded-production-deploy-prep
```

Result: passed for `implement.jsonl` and `check.jsonl`.

### Whitespace / patch sanity

```bash
git diff --check -- \
  ops/newapi-opentu-production \
  ops/newapi-opentu-staging/README.md \
  .trellis/tasks/06-15-creative-embedded-production-deploy-prep
```

Result: passed.

### Secret-ish scan

A local placeholder scan over the production runbook, env checklist, route checker, cloud-sync smoke helper, and staging README reported:

- `potential_secret_value_hits=0`
- hits were placeholder names, policy text, generated-runtime variable names, or no-print/no-log guidance only.

No real GitHub token, S3 credential, provider key, payment credential, admin password, cookie, CSRF, nonce, `SESSION_SECRET`, or production `.env` value was printed or committed.

## Current production route baseline

Command:

```bash
ops/newapi-opentu-production/creative-route-check.sh \
  https://console.se7endot.top \
  https://api.se7endot.top
```

Observed current baseline before deploying the embedded candidate:

- existing public baseline remains healthy:
  - `https://api.se7endot.top/v1/models` -> 401 JSON
  - `https://console.se7endot.top/login` -> 200 HTML
- `/creative/*` is not yet the embedded Creative route contract:
  - `/creative/` redirects/falls back;
  - `/creative/sw.js`, `/creative/version.json`, missing assets, `/creative/api/bootstrap`, and `/creative/relay/v1/chat/completions` return console HTML fallback behavior;
  - no real `/creative/assets/*` reference could be discovered.

Assertion mode was also run:

```bash
ops/newapi-opentu-production/creative-route-check.sh --assert \
  https://console.se7endot.top \
  https://api.se7endot.top
```

Result: failed as expected for pre-deploy production, because the current host has not yet been cut over to the embedded Creative candidate. This is a baseline, not a regression in the runbook.

## Dynamic workflow reviews

### v2 production runbook review

Command:

```bash
codex-flow run .codex-flow/generated/creative-prod-runbook-review-v2.workflow.ts
```

Journal: `.codex-flow/journal/creative-prod-runbook-review-v2.jsonl`

Initial result: failed with blockers. Fixed items:

- mapped container `SQLITE_PATH=/data/...` to host `/home/admin/apps/new-api/data/...` before SQLite backup/rehearsal;
- changed row-count snapshot to operate on the DB backup artifact;
- made DB-copy rehearsal localhost-only instead of host-network public exposure;
- generated rehearsal secrets at runtime instead of fixed example values;
- added explicit abort path to restart the old service if backup/row-count/rehearsal fails;
- added concrete no-secret authenticated Creative 云同步 smoke helper/procedure;
- removed stale new2fly runbook commit identity from the verified-input table.

### v3 production runbook review

Command:

```bash
codex-flow run .codex-flow/generated/creative-prod-runbook-review-v3.workflow.ts
```

Journal: `.codex-flow/journal/creative-prod-runbook-review-v3.jsonl`

Result: warnings only. Follow-up fixes:

- added `umask 077` around backup/rehearsal artifacts;
- removed production DB path values from error messages;
- added expected SHA/ref comparison examples;
- added image identity transfer gate guidance;
- updated `implement.md` to record runbook/preflight-only scope.

### v4 final blocker check

Command:

```bash
codex-flow run .codex-flow/generated/creative-prod-runbook-final-check-v4.workflow.ts
```

Journal: `.codex-flow/journal/creative-prod-runbook-final-check-v4.jsonl`

Result: one blocker found. Fixed item:

- changed `creative-cloud-sync-smoke.sh` so passwords, CSRF, and nonce values are not passed in subprocess argv; the helper now uses a 0700/077 temporary workspace and curl config/request files, then cleans them via trap.

### v5 final blocker check

Command:

```bash
codex-flow run .codex-flow/generated/creative-prod-runbook-final-check-v5.workflow.ts
```

Journal: `.codex-flow/journal/creative-prod-runbook-final-check-v5.jsonl`

Result: pass/pass from both read-only branches; `mustFix=[]`.

Remaining non-blocking note: image identity transfer gate could later be expanded with more copy/paste command templates for each transfer path.

## Final verification status

- Production runbook exists and is separate from local staging docs.
- Production env checklist exists and is placeholder-only.
- Production Creative 云同步 requires S3-compatible storage; DB storage is explicitly forbidden for production.
- Runbook includes pre-deploy ref/artifact/image gates, route/header checks, embedded smoke, authenticated cloud-sync smoke, rollback, DB-copy migration rehearsal, and data-preservation gates.
- No production deployment has been performed in this task.
