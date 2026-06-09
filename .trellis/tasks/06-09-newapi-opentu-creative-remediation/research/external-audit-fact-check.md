# External Audit Fact Check — new-api / opentu `/creative`

Date: 2026-06-09

## Source feedback evaluated

An external Codex review reported the overall integration status as `partial` and listed seven material gaps:

1. Production embedded dist is stale / inconsistent.
2. Image minimal relay path is missing under `/creative/relay/v1/images/generations`.
3. Video / Suno / MJ creative relay paths are incomplete; async idempotency, CAS refunds, and multi-key affinity remain unresolved.
4. Return-to-console button is missing.
5. Asset binary cloud sync is not implemented; current sync is document JSON snapshot oriented.
6. Embedded mode does not force new-api as the only provider gateway; legacy/direct provider paths remain possible.
7. Opentu spec typecheck fails; full build / full test / E2E are not verified.

## Local fact-check performed before planning

Commands / inspections performed in the main session:

- Compared `/mnt/f/code/project/new-api/web/creative/dist`, `/mnt/f/code/project/new-api/router/web/creative/dist`, and `/mnt/f/code/project/opentu/dist/apps/web` file counts, size, fixture markers, version metadata, and key-file hashes.
- Inspected `/mnt/f/code/project/new-api/main.go` embed directives.
- Inspected `/mnt/f/code/project/new-api/router/web-router.go` creative API and relay route registration.
- Searched new-api for `/creative/relay`, `images/generations`, video, MJ, and Suno relay path handling.
- Searched opentu for return-to-console / console navigation strings.
- Confirmed `packages/drawnix/tsconfig.spec.json` exists in opentu.

## Confirmed facts

### Production dist path split is real

`new-api/main.go` embeds:

- `web/creative/dist`
- `web/creative/dist/index.html`

Current checked directories:

- `new-api/web/creative/dist`: 218 files, 34M, no fixture markers, index asset refs `/creative/assets/index-Blrpm-7x.js` and `/creative/assets/index-C2C9RW9e.css`, `buildTime=2026-06-07T23:46:42.001Z`.
- `new-api/router/web/creative/dist`: 218 files, 35M, no fixture markers, index asset refs `/creative/assets/index-DPE6xIll.js` and `/creative/assets/index-Bhsy9ZA3.css`, `buildTime=2026-06-08T17:30:07.747Z`.
- `opentu/dist/apps/web`: 218 files, 35M, key files hash-identical to `new-api/router/web/creative/dist`.

Therefore the previous verification covered the router test fixture path but not the actual production `main.go` embed path.

### Creative relay only mounts chat today

`new-api/router/web-router.go` mounts:

- `POST /creative/relay/v1/chat/completions`

No corresponding `/creative/relay/v1/images/generations` route is registered in the creative relay group. Existing generic relay router has `/v1/images/generations`, and `relay/common/relay_info.go` trims `/creative/relay` from creative relay paths, but the route must be explicitly mounted before that can be used.

### Return-to-console is not confirmed implemented

A source search did not find an obvious `return to console` / `返回控制台` implementation in opentu. There is already an active Trellis task:

- `.trellis/tasks/06-08-add-return-to-console-button-in-opentu`

The remediation parent should reuse/link this task instead of duplicating it.

### Spec/full validation gap remains

Prior validation proved targeted Go suites and targeted opentu Vitest/tsc, but not `packages/drawnix/tsconfig.spec.json --noEmit`, full opentu build, full new-api tests, or browser E2E.

## Claims needing deeper dynamic-workflow verification

- Whether opentu still exposes legacy/direct provider routes in embedded mode in a way that can bypass new-api.
- Exact API path coverage needed for image/video/Suno/MJ in opentu current generation clients.
- Exact binary asset sync requirements for current board/media/audio/image elements.
- Whether video/Suno/MJ should be in the same release tranche or split into follow-up children after image path and provider-gateway enforcement.
