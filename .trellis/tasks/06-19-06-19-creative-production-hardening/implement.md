# Implement Plan — Creative production hardening after final audit

## Phase A — Prep / context

- [x] Read active specs:
  - `.trellis/spec/backend/creative-backend-security-boundary.md`
  - `.trellis/spec/backend/creative-asset-sync.md`
  - `.trellis/spec/backend/creative-async-video-relay.md`
  - `.trellis/spec/frontend/creative-embedded-release-artifact.md`
  - `.trellis/spec/frontend/creative-asset-sync.md`
  - `.trellis/spec/guides/cross-layer-thinking-guide.md`
  - `.trellis/spec/guides/code-reuse-thinking-guide.md`
- [x] Re-check git status in all three repos and keep `.codex/config.toml` uncommitted.

## Phase B — Backend safety fixes (`new-api`)

1. Relay sensitive headers
   - [x] Locate copy/move header override functions and existing pass-through denylist.
   - [x] Centralize/reuse sensitive-header predicate.
   - [x] Reject sensitive source and target names for `copy_header` / `move_header`.
   - [x] Add tests for denied Cookie/Authorization/X-Creative-* and safe header pass.

2. Video content fail-closed
   - [x] Add platform/relay-mode allowlist before Creative video content proxy opens task content.
   - [x] Add tests for same-user non-video success task returning safe non-proxy error.

3. Asset sync production config
   - [x] Add validation: enabled+production requires s3-compatible and complete S3 config.
   - [x] Preserve disabled and explicit local/test behavior.
   - [x] Add config validation tests.

4. CI/release gate
   - [x] Update `new-api` workflow/release scripts to enforce Creative tests/gates where feasible.
   - [x] If full cross-repo gate cannot run in CI, fail/document required sibling checkout or add a dedicated manual gate job.

## Phase C — Ops hardening (`new2fly`)

- [x] Update `creative-route-check.sh` with curl timeout defaults and strict TLS default.
- [x] Update `creative-cloud-sync-smoke.sh` similarly, preserving redaction.
- [x] Add explicit insecure opt-in mode only for controlled cases.
- [x] Update production README candidate refs/provenance guidance and smoke commands.
- [x] Run `bash -n` on both scripts.

## Phase D — Frontend model params (`opentu`)

- [x] Inspect managed-model schema-backed detection and workflow conversion.
- [x] Fix no-schema managed model parameter drop behavior.
- [x] Add tests for gpt-image-2/nano-banana-like params and `#img` fallback/empty-state behavior.
- [x] Ensure standalone/provider surfaces remain hidden in embedded mode.

## Phase E — Validation

Run as applicable:

- [x] `go test ./relay/common ./controller ./service ./router -run 'Creative|Header|Video|Asset|Model|Router'`
- [x] broader relevant `go test` packages if targeted tests pass.
- [x] OpenTU targeted tests for embedded model params and standalone surface guards.
- [x] `bash -n ops/newapi-opentu-production/creative-route-check.sh ops/newapi-opentu-production/creative-cloud-sync-smoke.sh`
- [x] `python3 scripts/creative_release_gate.py check --source-diff-check --run-new-api-tests`
- [x] If a local/staging candidate server is available: embedded browser smoke with `--drawnix-ready-timeout-ms 90000`.

## Phase F — Post-fix review

- [x] Run a focused dynamic-workflow verification on the fixed Must Fix list.
- [x] Then run a smaller final synthesis that checks goal attainment, not just fix completion.

## Rollback Points

- Backend changes are code-only; rollback via git/image.
- Ops script changes are code-only; rollback via git.
- Frontend model param changes affect generated dist only after rebuild; verify dist sync before deploy.
- No destructive DB or `.env` changes in this task.
