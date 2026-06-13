# Design — New API / OpenTU Release Gate Hardening

## Boundaries

This task spans three sibling repositories:

- `opentu`: Creative frontend source, build output, and Playwright smoke tests.
- `new-api`: embedded `/creative/` artifact copies and backend route/static boundary tests.
- `new2fly`: Trellis orchestration docs/specs and release-gate helper scripts.

All checks must be local/no-secrets. Provider, payment, CDN, and production endpoint validation remains a separate release-environment gate.

## Design Decisions

### 1. Cold smoke readiness

The previous official smoke waited for `.drawnix` with a hardcoded 10s timeout. Cold diagnostics showed `.drawnix` can appear around 18s while prewarmed smoke passes.

Design:

- Add a reusable Playwright readiness helper for Drawnix/OpenTU app shell readiness.
- Use a longer explicit timeout suitable for cold local startup (default around 45s, env-overridable if practical).
- Replace duplicated hardcoded `.drawnix` waits in smoke tests with the helper.
- Prefer readiness signal / visible `.drawnix` over arbitrary sleeps.

### 2. Embedded `/creative/` browser smoke

The existing OpenTU smoke targets the standalone dev server `/`. It does not prove that `new-api` serves the embedded build under `/creative/` while preserving API/relay route boundaries.

Design:

- Add a local embedded smoke path that can target a caller-provided `CREATIVE_EMBEDDED_BASE_URL` (for example `http://localhost:<port>/creative/`).
- Keep the test independent of real provider credentials: assert route shape, headers, and non-SPA behavior rather than successful upstream calls.
- Verify app-shell readiness under `/creative/` and static-boundary behavior for `/creative/api/...` and `/creative/relay/v1/...` paths.
- If starting full `new-api` is too environment-heavy, the release-gate script may support a check-only mode and document the server precondition; backend route tests remain the non-browser fallback.

### 3. Artifact sync/check automation

Manual sync is error-prone: the embedded contract needs a specific `VITE_BASE_URL`, two byte-identical `new-api` copies, and entry refs under `/creative/assets/`.

Design:

- Add a script in the orchestration repo that knows the sibling repo layout by default but accepts path overrides.
- Provide modes:
  - build OpenTU with `VITE_BASE_URL=/creative/`,
  - sync `opentu/dist/apps/web/` into both `new-api` Creative dist targets,
  - check relative file lists and SHA-256 hashes across all three artifact trees,
  - check embedded entry references,
  - optionally run selected `new-api` Go tests/build.
- The script must avoid reading secrets and must not call external endpoints.

### 4. Generated artifact policy

Generated dist can contain tool-emitted whitespace and `sw.js.map`. Release policy should not encourage hand-editing a single copied dist file.

Design:

- Treat generated dist integrity as byte identity across source and both embedded targets.
- Treat source whitespace separately via source-only diff checks.
- If production sourcemaps are forbidden, remove/disable them at OpenTU build-output source and sync identically; otherwise record them as an accepted generated artifact.

### 5. Verification / final review

After implementation:

- Run focused local commands for changed areas.
- Run a dynamic workflow with read-only sub-agents to independently review:
  - readiness smoke changes,
  - embedded route/static boundary coverage,
  - artifact script/policy completeness.
- Integrate any real findings before declaring the task complete.

## Rollback Shape

- OpenTU test helper/spec changes can be reverted without runtime app impact.
- New release-gate scripts are additive and can be removed independently.
- Artifact sync should be re-run from OpenTU build output instead of manually edited.
