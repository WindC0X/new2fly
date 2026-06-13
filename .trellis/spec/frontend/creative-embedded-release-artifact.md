# Creative Embedded Release Artifact Contract

## Scenario: Opentu build artifact embedded by new-api

### 1. Scope / Trigger

- Trigger: changing Opentu code that is shipped as the embedded Creative frontend under `new-api` `/creative/`.
- This is a cross-repo release contract: Opentu produces the static artifact, while `new-api` embeds and serves it from both `web/creative/dist` and `router/web/creative/dist`.
- Applies to Creative app-shell, service worker, release metadata, static chunks, and future generated files emitted by `pnpm build:web`.

### 2. Signatures

- Build command for embedded release artifacts:
  - `cd /mnt/f/code/project/opentu`
  - `VITE_BASE_URL=/creative/ pnpm build:web`
- Artifact source:
  - `opentu/dist/apps/web/`
- Artifact targets in `new-api`:
  - `new-api/web/creative/dist/`
  - `new-api/router/web/creative/dist/`
- Backend route contract:
  - `new-api` serves the SPA under `/creative/`.
  - `new-api` serves hashed chunks under `/creative/assets/*`.
  - `new-api` keeps `/creative/api/*` and `/creative/relay/v1/*` as API/relay routes, not SPA/static fallbacks.

### 3. Contracts

- Embedded Creative builds must use `VITE_BASE_URL=/creative/`; the default `base='./'` build is valid for standalone static serving but not for the `new-api` embedded contract.
- The embedded `index.html` must reference entry JS/CSS under `/creative/assets/...`.
- `opentu/dist/apps/web/`, `new-api/web/creative/dist/`, and `new-api/router/web/creative/dist/` must contain the same relative files with the same bytes after sync.
- `new-api/web/creative/dist/index.html`, `sw.js`, and `version.json` must match `new-api/router/web/creative/dist/*`.
- `sw.js` must register and run from `/creative/sw.js` when loaded from `/creative/`; runtime metadata (`version.json`, manifests, `sw.js`) stays same-origin.
- Generated artifact files may contain build-tool whitespace or sourcemaps; release gates must either accept generated-artifact policy exceptions or enforce normalization at the Opentu build-output source, not by manually editing only `new-api` copies.
- `apps/web/public/version.json` buildTime changes caused by local `pnpm build:web` are build side effects unless intentionally part of an Opentu source release; do not commit source timestamp churn blindly.

### 4. Validation & Error Matrix

- `index.html` references `./assets/...` after an embedded release build -> fail; rebuild with `VITE_BASE_URL=/creative/`.
- `new-api/web/creative/dist` differs from `new-api/router/web/creative/dist` -> fail; resync both targets from the same Opentu dist.
- `new-api` Go embed/static tests pass but Opentu source was changed after the dist sync -> fail release readiness; rebuild and resync before packaging.
- Full `git diff --check` fails only inside generated dist -> treat as release-policy risk; do not hand-normalize one target unless all artifact copies remain byte-identical.
- `pnpm e2e:smoke` cold-start fails before app readiness but prewarmed/long-wait runtime succeeds -> classify as E2E harness/readiness risk, not as proof of runtime failure.
- `sw.js.map` or other generated maps are emitted -> decide by production sourcemap policy; if forbidden, disable/strip at the Opentu artifact source and keep all embedded copies identical.

### 5. Good/Base/Bad Cases

- Good: run `VITE_BASE_URL=/creative/ pnpm build:web`, `rsync -a --delete dist/apps/web/` to both `new-api` targets, verify all three artifact trees have identical relative hashes, then run `go test -count=1 .` and selected `new-api` package tests.
- Base: source-only `git diff --check` passes while generated dist has known whitespace; the release gate documents the generated-artifact exception.
- Bad: copy a default `base='./'` Opentu build into `new-api`, producing `./assets/...` entry refs that do not satisfy the embedded `/creative/assets/*` route contract.

### 6. Tests Required

- Opentu build check: assert rebuilt `dist/apps/web/index.html` contains `/creative/assets/` entry JS/CSS and no `./assets/` entry refs for embedded releases.
- Cross-repo artifact check: assert source and both `new-api` target dist trees have identical relative path lists and hashes.
- `new-api` tests: run root Creative dist contract test and router static/API boundary tests after syncing artifacts.
- Browser smoke: run official smoke with a documented readiness strategy; if the app cold-starts after the hardcoded timeout, either prewarm in CI or increase/readiness-gate the wait.
- Release hygiene: run source-only diff checks and separately classify generated dist policy findings such as whitespace or sourcemaps.

### 7. Wrong vs Correct

#### Wrong

```text
pnpm build:web
rsync dist/apps/web/ new-api/web/creative/dist/
# index.html now references ./assets/... and only one backend dist tree was updated.
```

#### Correct

```text
VITE_BASE_URL=/creative/ pnpm build:web
rsync -a --delete dist/apps/web/ new-api/web/creative/dist/
rsync -a --delete dist/apps/web/ new-api/router/web/creative/dist/
verify all three dist trees have identical relative hashes
```
