# Design — Release Readiness Verification

## Verification model

Use two complementary tracks:

1. Deterministic local checks in the main session:
   - inspect package scripts and build contracts
   - run selected build/type/test commands
   - verify git dirty state
   - collect logs under this task's `verification/` directory
2. Dynamic workflow cross-check:
   - independent agents evaluate browser/E2E feasibility, build-chain readiness, and configuration readiness from current source and logs
   - agents must not rely on previous audit conclusions as authoritative

## Evidence directories

Store command logs under:

- `.trellis/tasks/06-13-newapi-opentu-release-readiness-verification/verification/`

Expected report:

- `.trellis/tasks/06-13-newapi-opentu-release-readiness-verification/release-readiness-report-2026-06-13.md`

## Release-gate dimensions

1. Browser runtime behavior
   - session broker starts and maintains session state
   - asset sync/hydrate sanitizer paths execute in browser-like environment
   - service worker/app-shell routing does not hijack creative API/static paths
2. Build/package chain
   - frontend production build artifact expectations
   - backend static creative route and fallback behavior
   - no missing generated assets required by docs/code
3. Configuration readiness
   - env examples and docs expose required switches
   - default-off is safe
   - missing production config can be detected fail-closed
4. Repository state
   - committed work hashes are known
   - remaining untracked artifacts are local-only and excluded from release

## Constraints

No production network calls. Localhost-only runtime checks are allowed when dependencies are available.
