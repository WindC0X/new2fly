# Research: opentu dirty file ownership after cloud-assets archive

- Query: Inspect `/mnt/f/code/project/opentu` working tree and classify current dirty files as ReturnButton, embedded provider gateway, provider/model acceptance, cloud-assets already committed, unrelated WIP, or unknown; recommend commit grouping and exact verification commands. Do not edit target repo files.
- Scope: internal
- Date: 2026-06-09

## Findings

### Context read first

- `python3 ./.trellis/scripts/task.py current --source` returned no active task in this shell; the user/developer-provided active task path was used for this research output: `.trellis/tasks/06-09-newapi-opentu-creative-remediation/research/`.
- Parent PRD requires provider gateway enforcement, return-to-console UX, cloud sync boundaries, and broad validation (`.trellis/tasks/06-09-newapi-opentu-creative-remediation/prd.md:35`, `:41`, `:46`, `:52`, `:66`, `:67`, `:68`, `:69`).
- Parent design states opentu responsibilities: detect `/creative`, use `new-api-creative` session-broker by default, own model display policy, send generation through same-origin `/creative/relay/v1/*`, and provide return UX (`.trellis/tasks/06-09-newapi-opentu-creative-remediation/design.md:24-32`).
- Parent implement plan specifically validates gateway with creative session-broker tests and targeted opentu Vitest/typecheck (`.trellis/tasks/06-09-newapi-opentu-creative-remediation/implement.md:59-74`, `:105-130`).
- Prior ReturnButton PRD requires a button visible only in embedded `/creative`, `window.location.href = '/dashboard'`, standalone hidden, and dedicated utility/component files (`.trellis/tasks/06-08-add-return-to-console-button-in-opentu/prd.md:27-36`, `:46-65`, `:77-79`, `:210-222`).
- Cloud-assets child is archived/completed. Its verification says opentu OpenSpec validation, creative document asset Vitest, SW pass-through Vitest, `drawnix:typecheck`, `web:typecheck`, and `web:build-sw` passed; full `build:web` was intentionally not run because it updates version/dist artifacts (`.trellis/tasks/archive/2026-06/06-09-creative-cloud-assets-sync/research/implementation-verification-2026-06-09.md:25-39`).

### Dirty-file classification table

`/mnt/f/code/project/opentu` currently has no staged changes. The status source was read-only `git status --short --untracked-files=all`; no stage/commit/reset/checkout was run.

| file/path | belongs_to | evidence | recommended commit grouping | exact verification commands needed |
|---|---|---|---|---|
| `apps/web/src/app/app.tsx` | return-button | Imports `ReturnButton` and renders it above `<Drawnix />` (`apps/web/src/app/app.tsx:27`, `:916-919`), matching prior ReturnButton PRD source-file plan. | `opentu-return-button` with `ReturnButton.tsx`, `ReturnButton.test.tsx`, `embed-detection.ts`. | `cd /mnt/f/code/project/opentu && pnpm exec vitest run apps/web/src/components/ReturnButton.test.tsx --environment jsdom --pool=threads --maxWorkers=1 --minWorkers=1`; `cd /mnt/f/code/project/opentu && NX_DAEMON=false pnpm exec nx run web:typecheck`. |
| `apps/web/src/components/ReturnButton.tsx` | return-button | Embedded check is memoized with `useState`; click handler sets `window.location.href = '/dashboard'`; button has `aria-label="返回控制台"` and visible text (`apps/web/src/components/ReturnButton.tsx:6-15`, `:18-48`). | `opentu-return-button`. | Same ReturnButton commands above; browser smoke after deployment: authenticated new-api `/creative/` shows button and click reaches `/dashboard`. |
| `apps/web/src/components/ReturnButton.test.tsx` | return-button | Tests embedded `/creative/board/demo` renders the button and standalone `/board/demo` does not (`apps/web/src/components/ReturnButton.test.tsx:14-31`). | `opentu-return-button`. | Same ReturnButton Vitest command above. |
| `apps/web/src/utils/embed-detection.ts` | return-button | Detects embedded mode by `/creative` or `/creative/` prefix (`apps/web/src/utils/embed-detection.ts:1-3`), matching prior PRD FR1. | `opentu-return-button`. | Same ReturnButton Vitest and `web:typecheck` commands above. |
| `packages/drawnix/src/services/async-image-api-service.ts` | gateway | `inferAuthType(route)` now preserves `route.authType || 'bearer'` instead of forcing bearer (`packages/drawnix/src/services/async-image-api-service.ts:71-72`), which prevents session-broker routes from degrading to bearer auth. | `opentu-embedded-gateway-auth-inheritance` with the other four media/Gemini authType files. | `cd /mnt/f/code/project/opentu && pnpm exec tsc -p packages/drawnix/tsconfig.lib.json --noEmit`; `cd /mnt/f/code/project/opentu/packages/drawnix && ../../node_modules/.bin/vitest run src/services/creative-session-broker.test.ts src/services/provider-routing/provider-transport.session-broker.test.ts src/utils/gemini-api/auth.creative-embedded.test.ts --config vitest.config.ts --pool=threads --maxWorkers=1 --minWorkers=1`. |
| `packages/drawnix/src/services/audio-api-service.ts` | gateway | Audio provider context now passes the resolved route into `inferAuthType(route)` and returns `route.authType || 'bearer'` (`packages/drawnix/src/services/audio-api-service.ts:107-128`). | `opentu-embedded-gateway-auth-inheritance`. | Same gateway commands above. |
| `packages/drawnix/src/services/media-executor/fallback-executor.ts` | gateway | Fallback executor inherits `route.authType || 'bearer'` (`packages/drawnix/src/services/media-executor/fallback-executor.ts:77-80`), preserving session-broker fallback execution. | `opentu-embedded-gateway-auth-inheritance`. | Same gateway commands above. |
| `packages/drawnix/src/services/video-api-service.ts` | gateway | Video provider context now preserves `route.authType || 'bearer'` (`packages/drawnix/src/services/video-api-service.ts:102-103`). | `opentu-embedded-gateway-auth-inheritance`. | Same gateway commands above. |
| `packages/drawnix/src/utils/gemini-api/services.ts` | gateway | Gemini/image service provider context now preserves `route.authType || 'bearer'` (`packages/drawnix/src/utils/gemini-api/services.ts:45-48`). | `opentu-embedded-gateway-auth-inheritance`. | Same gateway commands above. |
| `packages/drawnix/src/components/ai-input-bar/AIInputBar.tsx` | provider-model | Wires unavailable model marker storage/listeners and passes marker props into dropdowns (`packages/drawnix/src/components/ai-input-bar/AIInputBar.tsx:162-170`, `:785-837`, `:1124-1127`, `:4678-4681`, `:4706-4708`, `:4734-4736`, `:4762-4763`). This is model/provider UX acceptance, not cloud-assets. | `opentu-provider-model-acceptance` with `model-dropdown.scss`, `constants/storage.ts`, `ModelSelector.test.tsx`. | `cd /mnt/f/code/project/opentu/packages/drawnix && ../../node_modules/.bin/vitest run src/utils/__tests__/ai-model-selection-storage.test.ts src/components/ai-input-bar/ModelDropdown.test.tsx src/components/ai-input-bar/ModelSelector.test.tsx src/services/creative-display-policy.test.ts src/services/creative-session-broker.test.ts --config vitest.config.ts --pool=threads --maxWorkers=1 --minWorkers=1`; `cd /mnt/f/code/project/opentu && NX_DAEMON=false pnpm exec nx run drawnix:typecheck`. |
| `packages/drawnix/src/components/ai-input-bar/model-dropdown.scss` | provider-model | Adds styles for `model-dropdown__unavailable-marker` and `model-dropdown__unavailable-notice`, including dark theme variants (`packages/drawnix/src/components/ai-input-bar/model-dropdown.scss:159-182`, `:677-685`). | `opentu-provider-model-acceptance`. | Same provider-model commands above; add visual/browser smoke for unavailable marker if possible. |
| `packages/drawnix/src/constants/storage.ts` | provider-model | Defines `AI_MODEL_UNAVAILABLE_SELECTION_MARKERS_KEY` and includes it in `ALL_STORAGE_KEYS` (`packages/drawnix/src/constants/storage.ts:44-46`, `:59-71`). Current HEAD `ai-model-selection-storage.ts` imports this symbol, so this dirty file is required for the provider-model code to typecheck. | `opentu-provider-model-acceptance`. | Same provider-model commands above; especially `NX_DAEMON=false pnpm exec nx run drawnix:typecheck`. |
| `packages/drawnix/src/components/ai-input-bar/ModelSelector.test.tsx` | provider-model | Tests local creative default-visible policy, stripped server UI policy, More Models search, and selection (`packages/drawnix/src/components/ai-input-bar/ModelSelector.test.tsx:42-151`). | `opentu-provider-model-acceptance`. | Same provider-model Vitest command above. |
| `apps/web/public/version.json` | unknown | Only dirty field is generated-like `buildTime: 2026-06-09T03:17:19.444Z` (`apps/web/public/version.json:1-7`). This timestamp matches the parent sprint1 opentu build evidence, but it is not itself a ReturnButton/gateway/provider-model/cloud-assets source contract. | Hold separately as `opentu-build-metadata`; include only if final build/dist sync intentionally regenerates version metadata. Do not mix into cloud-assets commit because cloud-assets commit already exists. | If intentionally keeping build metadata: `cd /mnt/f/code/project/opentu && NX_DAEMON=false VITE_BASE_URL=/creative/ pnpm build:web`, then sync new-api dist and rerun production dist checks from parent. If not, ask/decide before commit; no code test proves this file alone. |
| `.ace-tool/index.bin` | unrelated | Binary `data`, 299K, under `.ace-tool`; no task/spec reference and no source-level creative acceptance evidence. | `do-not-commit-unrelated-wip`. | No remediation verification; if preserving local tooling, keep out of remediation commit. |
| `packages/drawnix/audio-test.pptx` | unrelated | Empty `pptx` file, 0 bytes, no task/spec reference; cloud-assets verification explicitly warned not to touch unrelated `audio-test.pptx`. | `do-not-commit-unrelated-wip`. | No remediation verification; keep out of commit. |

### Cloud-assets status

- No currently dirty opentu file needs `belongs_to=cloud-assets` based on current status.
- The cloud-assets implementation is already committed in opentu as `ea89858c feat(creative): sync cloud binary assets`. The commit contains the cloud asset OpenSpec/SW/service files, including `apps/web/src/sw/creative-asset-pass-through.ts`, `packages/drawnix/src/services/creative-document-assets.ts`, `packages/drawnix/src/services/creative-document-sync.ts`, `packages/drawnix/src/services/creative-session-broker.ts`, provider-routing files, and related tests.
- Because those cloud-assets files are clean relative to HEAD, do not include them again in ReturnButton/gateway/provider-model commit grouping unless a new diff appears.

### Recommended commit grouping

1. **ReturnButton UI group**: `apps/web/src/app/app.tsx`, `apps/web/src/components/ReturnButton.tsx`, `apps/web/src/components/ReturnButton.test.tsx`, `apps/web/src/utils/embed-detection.ts`. Optional: include `apps/web/public/version.json` only if final build metadata is intentionally regenerated as part of production dist sync.
2. **Embedded gateway auth inheritance group**: `packages/drawnix/src/services/async-image-api-service.ts`, `packages/drawnix/src/services/audio-api-service.ts`, `packages/drawnix/src/services/media-executor/fallback-executor.ts`, `packages/drawnix/src/services/video-api-service.ts`, `packages/drawnix/src/utils/gemini-api/services.ts`.
3. **Provider/model acceptance group**: `packages/drawnix/src/components/ai-input-bar/AIInputBar.tsx`, `packages/drawnix/src/components/ai-input-bar/model-dropdown.scss`, `packages/drawnix/src/constants/storage.ts`, `packages/drawnix/src/components/ai-input-bar/ModelSelector.test.tsx`.
4. **Cloud-assets group**: no current dirty files; already committed as opentu `ea89858c`.
5. **Exclude/unrelated WIP**: `.ace-tool/index.bin`, `packages/drawnix/audio-test.pptx`.

### Exact verification command set

Run only after the relevant group is ready; this research run did not execute tests.

#### ReturnButton UI

```bash
cd /mnt/f/code/project/opentu
pnpm exec vitest run apps/web/src/components/ReturnButton.test.tsx --environment jsdom --pool=threads --maxWorkers=1 --minWorkers=1
NX_DAEMON=false pnpm exec nx run web:typecheck
```

#### Embedded gateway/session-broker auth inheritance

```bash
cd /mnt/f/code/project/opentu
pnpm exec tsc -p packages/drawnix/tsconfig.lib.json --noEmit
cd /mnt/f/code/project/opentu/packages/drawnix
../../node_modules/.bin/vitest run \
  src/services/creative-session-broker.test.ts \
  src/services/provider-routing/provider-transport.session-broker.test.ts \
  src/utils/gemini-api/auth.creative-embedded.test.ts \
  --config vitest.config.ts --pool=threads --maxWorkers=1 --minWorkers=1
```

#### Provider/model acceptance

```bash
cd /mnt/f/code/project/opentu/packages/drawnix
../../node_modules/.bin/vitest run \
  src/utils/__tests__/ai-model-selection-storage.test.ts \
  src/components/ai-input-bar/ModelDropdown.test.tsx \
  src/components/ai-input-bar/ModelSelector.test.tsx \
  src/services/creative-display-policy.test.ts \
  src/services/creative-session-broker.test.ts \
  --config vitest.config.ts --pool=threads --maxWorkers=1 --minWorkers=1
cd /mnt/f/code/project/opentu
NX_DAEMON=false pnpm exec nx run drawnix:typecheck
```

#### Cloud-assets regression check if needed

```bash
cd /mnt/f/code/project/opentu
POSTHOG_DISABLED=1 openspec validate add-creative-cloud-asset-sync --strict
cd /mnt/f/code/project/opentu/packages/drawnix
../../node_modules/.bin/vitest run \
  src/services/creative-document-assets.test.ts \
  src/services/creative-document-sync.test.ts \
  src/services/creative-session-broker.test.ts \
  src/hooks/use-creative-document-sync-status.test.tsx \
  --config vitest.config.ts --pool=threads --maxWorkers=1 --minWorkers=1
cd /mnt/f/code/project/opentu
pnpm exec vitest run apps/web/src/sw/creative-asset-pass-through.spec.ts --config apps/web/vite.config.ts --pool=threads --maxWorkers=1 --minWorkers=1
NX_DAEMON=false pnpm exec nx run drawnix:typecheck
NX_DAEMON=false pnpm exec nx run web:typecheck
NX_DAEMON=false pnpm exec nx run web:build-sw
```

#### Hygiene / final build caveats

```bash
cd /mnt/f/code/project/opentu
GIT_OPTIONAL_LOCKS=0 git diff --check
```

If final production dist must be regenerated/synced after opentu source changes:

```bash
cd /mnt/f/code/project/opentu
NX_DAEMON=false VITE_BASE_URL=/creative/ pnpm build:web
```

Then sync the resulting `opentu/dist/apps/web` to the new-api production/router creative dist paths and rerun the new-api production dist contract test from the parent implementation plan.

## Caveats / Not Found

- `task.py current --source` reported no active task in this shell, so this research used the explicit task path supplied by the user/developer rather than a runtime active-task pointer.
- Read-only git inspection was used to identify dirty files; no staging, commit, reset, checkout, or file edit was performed in `/mnt/f/code/project/opentu`.
- No currently dirty opentu file is classified as `cloud-assets`; cloud-assets appears already committed and clean in opentu HEAD.
- `apps/web/public/version.json` is classified `unknown` rather than source-owned because it only changes build metadata. It should be handled intentionally during a final build/dist sync decision.
- Tests were not run in this research-only sidecar; commands above are the exact rerun set recommended before commit grouping.
- Full `packages/drawnix/tsconfig.spec.json` is known to have pre-existing/mixed spec type debt; do not use it as a green gate unless that debt is separately fixed or explicitly split.
