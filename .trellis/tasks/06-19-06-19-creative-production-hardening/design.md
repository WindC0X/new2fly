# Design — Creative production hardening after final audit

## Scope and Repositories

This task spans three sibling repositories:

- `new2fly` — orchestration, production runbook, release-gate script, ops smoke scripts.
- `new-api` — backend route/security/runtime behavior and CI/release automation.
- `opentu` — embedded frontend behavior and tests for managed model parameters / standalone surface guards.

## Design Principles

1. **Fail closed before provider calls or storage writes.** Misconfiguration must block early rather than falling back to browser credentials, database binary storage, or unsafe upstream headers.
2. **Do not rely on operator memory.** Release gates and smoke scripts must encode the minimum safety checks from the final audit.
3. **Keep Phase 1 explicit.** Route/UI cutover is allowed; cloud sync/video relay remain disabled unless deliberately configured and tested.
4. **Use shared denylist logic.** Sensitive header/body/query filtering should be centralized enough to avoid copy/move/pass-through drift.
5. **Preserve existing data.** No production DB/data/log deletion or destructive rollback behavior.

## Technical Design

### 1. Release gate and CI

- Add CI/release hooks in `new-api` where image/release publishing currently occurs.
- The gate should run targeted Creative Go tests and, where feasible, the cross-repo release gate from `new2fly`.
- Because CI may not have sibling `opentu/new2fly` checkouts by default, document any CI job assumptions explicitly:
  - either checkout all three repos before running the full gate;
  - or at minimum fail unless embedded dist provenance is present and Go tests pass.
- Keep manual production smoke in `new2fly` runbook for public route and authenticated smoke.

### 2. Ops smoke scripts

- Introduce curl defaults such as:
  - `--connect-timeout <seconds>`;
  - `--max-time <seconds>`;
  - `--fail-with-body` where safe;
  - strict TLS by default.
- Add an explicit flag/env (for example `--insecure` or `CREATIVE_SMOKE_INSECURE=1`) to opt into `-k` only when the operator intentionally targets a private/self-signed endpoint.
- Preserve redaction behavior; never print cookies, nonce, CSRF, password, token, response body, or storage credentials.

### 3. Relay header copy/move hardening

- Locate param override functions for `copy_header` and `move_header` in `new-api/relay/common/override.go`.
- Apply the same sensitive-header predicate used by pass-through filtering, or extract a shared predicate if needed.
- Deny sensitive source headers and sensitive target headers.
- Allow safe custom headers where existing behavior is expected.
- Add tests for denied and allowed cases.

### 4. Video content platform fail-closed

- In the Creative video content path, require task platform or relay mode to be an allowed video platform before `VideoProxy` can open content.
- Keep owner scoping and status checks unchanged.
- Non-video same-user tasks should return 404/400 without leaking private data or attempting upstream fetch.

### 5. Asset sync production config hard-fail

- Adjust `CreativeAssetRuntime` config normalization/ready validation so production enablement cannot default to database storage.
- Expected behavior:
  - disabled mode remains okay with no S3 config;
  - local/test rollout may use database only where explicitly non-production;
  - production rollout requires `s3-compatible` and complete S3 settings;
  - misconfiguration returns a scrubbed startup/runtime error.
- Add tests covering disabled, local/database, production/database rejection, production/missing-S3 rejection, and production/S3 accepted.

### 6. Embedded model parameter behavior

- Inspect OpenTU runtime model discovery and workflow conversion around managed models and `parameterSchema`.
- Avoid treating all Creative managed models as schema-backed if no runtime schema exists.
- Preserve schema-backed behavior for mock/stored binding manifests.
- Add tests demonstrating selected gpt-image-2/nano-banana style params survive the conversion path, or are hidden/disabled when unsupported.

### 7. Runbook/provenance

- Update current candidate refs, image ID/digest recording, and strict smoke commands.
- Make stale ref risk explicit: candidate table must be refreshed before deployment.
- Keep rollback instructions image/compose-only; do not delete Creative tables.

## Compatibility and Rollback

- Header filtering may break channels that intentionally copy browser session headers upstream; this is a desired security break.
- Asset sync production hard-fail may block an accidental config that previously started; this is desired.
- Release CI additions may initially fail until CI checkout assumptions are met; document the expected setup.
- Rollback for code changes is normal git/image rollback; no data migration rollback is required.

## Validation Strategy

- Backend targeted tests first, then broader package tests where feasible.
- Frontend targeted tests for model params / embedded surfaces.
- Bash syntax checks for ops scripts.
- Cross-repo release gate.
- Public production route/auth smoke only after code is built/deployed and explicit runtime authorization exists.
