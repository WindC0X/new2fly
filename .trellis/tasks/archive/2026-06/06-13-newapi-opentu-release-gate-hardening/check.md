# Check Report — New API / OpenTU Release Gate Hardening — 2026-06-13

## Implemented Gates

- OpenTU smoke readiness now uses `waitForDrawnixReady()` with a 45s default and `DRAWNIX_READY_TIMEOUT_MS` override.
- Added OpenTU `creative-embedded` Playwright project/spec and `pnpm e2e:creative-embedded` script.
- Added local no-secrets artifact gate: `python3 scripts/creative_release_gate.py`.
- Hardened `new-api` embedded static boundary:
  - root admin static middleware skips `/creative` so future admin files cannot shadow Creative API/relay/app routes;
  - missing `/creative/assets/*` is a static 404, not SPA HTML fallback.
- Strengthened `new-api` Creative dist test to compare full root/router dist file lists and SHA-256 hashes.
- Updated `.trellis/spec/frontend/creative-embedded-release-artifact.md` with the script, generated artifact policy, embedded smoke command, and missing-asset 404 contract.

## Local Validation Evidence

Passed:

```bash
cd /mnt/f/code/project/new2fly
python3 scripts/creative_release_gate.py check --source-diff-check
python3 scripts/creative_release_gate.py check --embedded-smoke-url http://localhost:39080/creative/ --drawnix-ready-timeout-ms 60000
python3 -m py_compile scripts/creative_release_gate.py
```

Passed:

```bash
cd /mnt/f/code/project/opentu
pnpm nx run drawnix:typecheck
pnpm e2e:creative-embedded   # no URL: compiles and skips safely
pnpm e2e:smoke               # cold smoke: 2 passed
```

Passed:

```bash
cd /mnt/f/code/project/new-api
go test -count=1 .
go test -count=1 . ./router
go test -count=1 ./router ./middleware ./controller ./model ./service ./relay/... && go build ./...
```

Embedded smoke was run against a temporary local no-secrets `new-api` server using a temporary SQLite DB under `/tmp` and `PORT=39080`.

## Dynamic Workflow Evidence

- Initial final review:
  - workflow: `.codex-flow/generated/newapi-opentu-release-gate-hardening-final-review.workflow.ts`
  - journal: `.codex-flow/journal/newapi-opentu-release-gate-hardening-final-review.jsonl`
  - findings: LOW coverage gaps; integrated.
- Post-fix final review:
  - workflow: `.codex-flow/generated/newapi-opentu-release-gate-hardening-final-review-v2.workflow.ts`
  - journal: `.codex-flow/journal/newapi-opentu-release-gate-hardening-final-review-v2.jsonl`
  - findings integrated or accounted for:
    - embedded smoke now includes real POST relay boundary;
    - `new2fly` source diff-check included in release gate;
    - `new-api` Go test now compares full root/router dist trees;
    - `CREATIVE_EMBEDDED_BASE_URL` no longer changes normal smoke baseURL/webServer behavior;
    - root static skip and missing `/creative/assets/*` 404 boundary implemented;
    - browser smoke separately checks JS and CSS `/creative/assets/` refs and rejects standalone `./assets` or `/assets` entry refs.

## Known Remaining Release Constraints

- No production/provider/payment/CDN/S3/NPM-token validation was performed; this remains an external release-environment gate.
- `sw.js.map` is still present and allowed by the default local policy. Use `--sourcemap-policy forbid` to turn this into a blocking gate if production policy forbids sourcemaps.
- Local `.npmrc` still warns about missing `${NPM_TOKEN}` during pnpm commands; this is expected in the no-secrets environment.
