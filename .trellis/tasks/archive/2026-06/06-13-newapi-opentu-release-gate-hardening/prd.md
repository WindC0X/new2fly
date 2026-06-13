# New API / OpenTU Release Gate Hardening

## Goal

Move the New API + OpenTU Creative release gate from the previous `mostly_ready` state toward a repeatable local `release_ready` gate for the no-secrets scope.

The work hardens the known remaining gates after the 2026-06-13 readiness review:

1. cold browser smoke readiness for OpenTU,
2. embedded `new-api` `/creative/` smoke coverage,
3. generated Creative dist artifact policy,
4. repeatable artifact sync / verification automation.

## Requirements

- Keep validation local and secret-safe:
  - do not read or print secrets,
  - do not call provider, payment, CDN, or production endpoints,
  - localhost servers, source inspection, generated artifacts, and local tests are allowed.
- Preserve the embedded release contract:
  - OpenTU release build uses `VITE_BASE_URL=/creative/`,
  - `opentu/dist/apps/web`, `new-api/web/creative/dist`, and `new-api/router/web/creative/dist` stay byte-identical after sync,
  - embedded `index.html` must reference `/creative/assets/...`, not `./assets/...` entry chunks,
  - `/creative/api/*` and `/creative/relay/v1/*` must remain API/relay boundaries, not SPA/static fallbacks.
- Make the official OpenTU smoke gate robust against cold app startup instead of depending on a prewarmed browser/server.
- Add or provide an embedded `/creative/` browser smoke path that can be run locally without real provider/payment/CDN credentials.
- Add a repeatable script/check that rebuilds or verifies the Creative artifact contract and documents generated artifact handling.
- Treat generated dist whitespace/sourcemap findings as release-policy findings; do not hand-edit only one embedded copy in a way that breaks artifact identity.
- Use dynamic workflow during the verification/review phase for independent cross-checking of the finished gates.

## Acceptance Criteria

- [ ] OpenTU smoke waits for app readiness in a reusable, cold-start-tolerant way; repeated hardcoded 10s `.drawnix` waits are removed or centralized.
- [ ] A cold `pnpm e2e:smoke` run in `/mnt/f/code/project/opentu` is attempted and any remaining failure is investigated and documented with evidence.
- [ ] Embedded `/creative/` smoke coverage exists and verifies, at minimum, app shell readiness plus API/relay static-boundary behavior under a local embedded `new-api` URL or equivalent local harness.
- [ ] A repeatable release-gate script or command exists to build/sync/check Creative artifacts across OpenTU and both `new-api` dist trees.
- [ ] Artifact checks assert same relative file list and hashes for all three dist trees and assert `/creative/assets/` entry references in embedded `index.html`.
- [ ] The generated artifact policy is documented in code comments/docs/spec/task artifacts: source diff whitespace checks are separated from generated dist identity checks, and sourcemap policy is explicit.
- [ ] Relevant `new-api` Go tests/build checks and OpenTU build/typecheck/smoke checks are run where feasible.
- [ ] A dynamic workflow final review is run after implementation and its findings are integrated or explicitly documented.

## Out of Scope

- Reading production secrets or validating real production S3/NPM/CDN/provider/payment endpoints.
- Changing provider/payment business logic unrelated to local release gates.
- Publishing packages or deploying services.
- Making a final production readiness claim for secrets-dependent infrastructure.
