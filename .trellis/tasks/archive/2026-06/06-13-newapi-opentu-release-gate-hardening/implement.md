# Implementation Plan — New API / OpenTU Release Gate Hardening

## Step 0 — Context and guardrails

- Confirm current task status and applicable Trellis specs.
- Avoid committing local-only caches/artifacts: `.cache/`, `.codegraph/`, `.codex-flow/`, and unrelated test files.
- Do not read secrets or call production/provider/payment/CDN endpoints.

## Step 1 — OpenTU smoke readiness

- Inspect `apps/web-e2e/src/smoke/smoke.spec.ts` and related Playwright helpers.
- Add a reusable Drawnix readiness helper or constant in the web-e2e test area.
- Replace hardcoded 10s `.drawnix` waits with the helper.
- Run the smoke test cold and capture evidence.

## Step 2 — Embedded `/creative/` smoke coverage

- Add a Playwright smoke path or release-gate smoke command that targets `CREATIVE_EMBEDDED_BASE_URL`.
- Verify:
  - `/creative/` app shell loads and Drawnix becomes visible,
  - `/creative/api/...` does not return SPA HTML/static fallback,
  - `/creative/relay/v1/...` does not return SPA HTML/static fallback,
  - static asset entry refs are under `/creative/assets/`.
- If full server startup is not safely automatable, document the local server precondition in the script and keep backend route tests as fallback evidence.

## Step 3 — Artifact release-gate script and policy

- Add a repeatable script in `new2fly` for Creative release artifact build/sync/check.
- Implement path overrides and no-secrets defaults.
- Check file-list/hash identity across OpenTU dist and both `new-api` targets.
- Check embedded `index.html` entry refs.
- Document generated dist whitespace/sourcemap policy in the script help/spec/task notes.

## Step 4 — Validation

Run focused checks where feasible:

- In `opentu`:
  - `pnpm nx run drawnix:typecheck`
  - `pnpm e2e:smoke`
  - embedded smoke command when a local embedded server is available
- In `new-api`:
  - `go test -count=1 .`
  - selected router/middleware/controller/model/service/relay tests and `go build ./...` if time allows
- In `new2fly`:
  - script dry-run/check mode
  - source-only diff whitespace check

## Step 5 — Dynamic workflow final review

- Generate and run a read-only `codex-flow` workflow after implementation.
- Branches:
  1. OpenTU smoke readiness review.
  2. Embedded `/creative/` route/static boundary review.
  3. Artifact script and generated-artifact policy review.
- Integrate real findings or document why they are out of scope.

## Step 6 — Wrap-up

- Update task notes with evidence paths/commands.
- Update specs if a durable convention changed.
- Summarize changed files, checks run, remaining no-secrets limitations, and release-gate status.
