# Implementation Plan — Local/Intranet Staging Deploy and Live Route Checks

## Phase 1 — Planning update

1. Rewrite PRD/design/implementation artifacts to reflect that no deployed environment exists yet.
2. Curate `implement.jsonl` and `check.jsonl` with relevant specs and prior reports.
3. Validate the Trellis task and start it.

## Phase 2 — Preflight and local staging

1. Confirm candidate artifact state with:
   - `python3 scripts/creative_release_gate.py check --source-diff-check`
2. Extract current existing asset paths from `new-api/web/creative/dist/index.html`.
3. Pick an unused local port, defaulting to `39082` if free.
4. Start `new-api` from `/mnt/f/code/project/new-api` with sanitized `env -i`, temporary SQLite, release mode, and disabled background update jobs.
5. Capture the local staging command in the report with no secret values.

## Phase 3 — Local live checks

1. Run embedded smoke through the release gate against `http://localhost:<port>/creative/`:
   - `python3 scripts/creative_release_gate.py check --embedded-smoke-url http://localhost:<port>/creative/ --drawnix-ready-timeout-ms 60000`
2. Run a local route/header checker against the target paths:
   - `/creative/`
   - `/creative/sw.js`
   - `/creative/version.json`
   - current JS/CSS hashed assets
   - `/creative/assets/__missing_release_check__.js`
   - `/creative/api/bootstrap`
   - `/creative/api/missing`
   - `/creative/relay/v1/chat/completions`
3. Save redacted status/header observations only; do not save response bodies.
4. Stop the staging server and clean temporary files after evidence is captured.

## Phase 4 — Independent check and report

1. Run a dynamic-workflow read-only sidecar over the redacted observations and relevant specs/reports.
2. Write `check.md` summarizing:
   - staging setup,
   - release gate result,
   - embedded smoke result,
   - route/header table,
   - dynamic workflow findings,
   - production-only `not-run` items.
3. Run Trellis validation.
4. Archive the task, update journal, commit, and push `new2fly` using Windows-host GitHub credentials if needed.

## Rollback / safety

- Use `pkill` only for the specific local staging PID if cleanup is required; do not kill unrelated services.
- Do not run provider/payment/storage/CDN/publish/deploy commands.
- Do not read or print secret files or environment values.
- If staging fails to start, write the failure evidence and stop rather than falling back to production-like credentials.
