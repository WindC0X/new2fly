# Implementation Plan — Remote-backed RC Verification

1. Confirm remotes/branches:
   - `opentu` local `newapi-embed-release-gate` / `fork/newapi-embed-release-gate` at `39e0fe23`.
   - `new-api` local `feat/creative-embed` / `fork/feat/creative-embed` at `c9f318c`.
   - `new2fly` local `master` / `origin/master` at latest pushed journal commit.
2. Run no-mutation artifact/source checks:
   - `python3 scripts/creative_release_gate.py check --source-diff-check --run-new-api-tests`.
3. Run OpenTU checks:
   - `pnpm nx run drawnix:typecheck`.
   - `pnpm e2e:smoke`.
4. Start temporary local `new-api` with a temporary SQLite DB and no provider/payment/CDN calls.
5. Run embedded smoke through release gate:
   - `python3 scripts/creative_release_gate.py check --embedded-smoke-url http://localhost:<port>/creative/ --drawnix-ready-timeout-ms 60000`.
6. Stop temporary server, confirm no unintended tracked diffs.
7. Write `check.md`, archive task, journal session, push new2fly task record if checks are complete.
