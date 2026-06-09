# Sprint1 Residual Verification — Creative Remediation Parent

Date: 2026-06-10

## Scope

Closed the Sprint1 residual work that was implemented before but not yet fully committed/metadata-aligned:

- Return-to-console UI in opentu embedded `/creative`.
- Embedded provider gateway auth inheritance for image/audio/video/Gemini/media fallback routes.
- Provider/model default-visible UX acceptance markers.
- new-api production creative dist synchronization across:
  - `new-api/web/creative/dist`
  - `new-api/router/web/creative/dist`
  - `opentu/dist/apps/web`
- new-api creative image relay mode/info/router/billing validation residue.

## Commands Run

### opentu ReturnButton / typecheck

```bash
cd /mnt/f/code/project/opentu
pnpm exec vitest run apps/web/src/components/ReturnButton.test.tsx --environment jsdom --pool=threads --maxWorkers=1 --minWorkers=1
NX_DAEMON=false pnpm exec nx run web:typecheck
NX_DAEMON=false pnpm exec nx run drawnix:typecheck
```

Result: passed. ReturnButton Vitest: `1 file / 2 tests passed`; both nx typecheck targets passed.

### opentu gateway/provider/model tests

```bash
cd /mnt/f/code/project/opentu
pnpm exec tsc -p packages/drawnix/tsconfig.lib.json --noEmit
cd /mnt/f/code/project/opentu/packages/drawnix
../../node_modules/.bin/vitest run \
  src/services/creative-session-broker.test.ts \
  src/services/provider-routing/provider-transport.session-broker.test.ts \
  src/utils/gemini-api/auth.creative-embedded.test.ts \
  src/utils/__tests__/ai-model-selection-storage.test.ts \
  src/components/ai-input-bar/ModelDropdown.test.tsx \
  src/components/ai-input-bar/ModelSelector.test.tsx \
  src/services/creative-display-policy.test.ts \
  --config vitest.config.ts --pool=threads --maxWorkers=1 --minWorkers=1
```

Result: passed. Vitest: `7 files / 34 tests passed`.

### opentu production build

```bash
cd /mnt/f/code/project/opentu
NX_DAEMON=false VITE_BASE_URL=/creative/ pnpm build:web
```

Result: passed. Build produced `/mnt/f/code/project/opentu/dist/apps/web` with `/creative` base assets and service worker.

### Dist sync and hash/marker verification

```bash
rsync -a --delete /mnt/f/code/project/opentu/dist/apps/web/ /mnt/f/code/project/new-api/web/creative/dist/
rsync -a --delete /mnt/f/code/project/opentu/dist/apps/web/ /mnt/f/code/project/new-api/router/web/creative/dist/
```

Hash/marker script result:

```text
/mnt/f/code/project/new-api/web/creative/dist vs /mnt/f/code/project/new-api/router/web/creative/dist: rels=222 missing=0 diff=0
/mnt/f/code/project/new-api/web/creative/dist vs /mnt/f/code/project/opentu/dist/apps/web: rels=222 missing=0 diff=0
/mnt/f/code/project/new-api/web/creative/dist fixture markers []
/mnt/f/code/project/new-api/router/web/creative/dist fixture markers []
```

### new-api image relay / dist / broad validation

```bash
cd /mnt/f/code/project/new-api
git diff --check
GOCACHE=/tmp/go-build-cache go test . -run TestCreativeProductionRootDistMatchesRouterDistAndContract -count=1
GOCACHE=/tmp/go-build-cache go test ./router -run 'Test.*Creative.*(Production|Fixture|Cache|Provenance|Asset|WebRouter)|TestSetWebRouterKeepsCreativeRoutesGinSafe|TestCreativeEmbedded.*' -count=1
GOCACHE=/tmp/go-build-cache go test ./controller ./middleware ./model ./relay/common ./relay/constant ./router ./service -count=1
```

Result: passed. Packages reported `ok` for main, router, controller, middleware, model, relay/common, relay/constant, and service.

### repo hygiene

```bash
cd /mnt/f/code/project/opentu && git diff --check
cd /mnt/f/code/project/new2fly && git diff --check
```

Result: passed.

## Notes / Warnings

- pnpm repeatedly warned that `.npmrc` could not replace `${NPM_TOKEN}`. This did not fail tests/builds.
- Sass/Vite chunk-size warnings remain build warnings, not failures.
- Full `packages/drawnix/tsconfig.spec.json --noEmit` is still known to contain broader spec/test type debt from Sprint1 evidence and is not claimed green here.
- Browser smoke/E2E has not been executed in this shell.
