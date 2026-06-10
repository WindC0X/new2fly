# Research: new-api dirty file Sprint1 parent classification

- Query: Inspect `/mnt/f/code/project/new-api` working tree and classify currently dirty files into Sprint1 parent acceptance items: production dist path consistency, image relay, broad validation, or unrelated WIP after the cloud-assets child was archived.
- Scope: internal
- Date: 2026-06-09

## Findings

### Context read first

- Parent PRD: `.trellis/tasks/06-09-newapi-opentu-creative-remediation/prd.md`
  - R1 production dist path consistency requires the actual `main.go` embedded path to be current and test-covered (lines 23-27).
  - R2 requires `/creative/relay/v1/images/generations` or equivalent image relay route coverage (lines 29-31, 61-63).
  - R6 requires production embed identity validation plus broader new-api/opentu validation or blocker notes (lines 52-56).
- Parent design: `.trellis/tasks/06-09-newapi-opentu-creative-remediation/design.md`
  - Production embed path split is the first remediation boundary (lines 36, 56-60).
  - Image relay route mounting must match opentu callers, not only relay-info trimming (lines 37, 62-83).
- Parent implementation plan: `.trellis/tasks/06-09-newapi-opentu-creative-remediation/implement.md`
  - Dist branch validation commands are listed at lines 37-42.
  - Minimal image relay validation command is listed at lines 52-56.
  - Broad validation commands are listed at lines 93-130.
- Sprint1 result: `.trellis/tasks/06-09-newapi-opentu-creative-remediation/research/sprint1-implementation-result.json`
  - Sprint1 synthesis marks Item 1 dist and Item 2 image relay as fixed, Item 6 gateway/validation partially covered, and opentu `tsconfig.spec.json` still failing.
  - Post-workflow checks recorded `new-api-broad-go-test` exit 0, `opentu-targeted-vitest-full` exit 0, and `opentu-tsconfig-spec` exit 2.
- Cloud-assets child: `.trellis/tasks/archive/2026-06/06-09-creative-cloud-assets-sync/task.json` has `status=completed`; no currently dirty new-api files are clearly attributable to that archived child. Asset routes in `router/web-router.go` are present in the clean tracked code, not dirty.

### Dirty snapshot

Read-only working-tree inspection used `GIT_OPTIONAL_LOCKS=0 git status --porcelain=v1 -z -uall` and did not stage or commit.

- Total dirty entries: 339
- Status counts: `M=15`, `D=48`, `??=276`
- No staged/cached changes were reported by `GIT_OPTIONAL_LOCKS=0 git diff --cached --name-status`.
- Prefix counts:
  - `web/creative/dist/**`: 101 dirty entries (`48 D`, `48 ??`, `5 M`)
  - `router/web/creative/dist/**`: 222 untracked entries
  - `router/web/default/dist/index.html`: 1 untracked entry
  - `router/web/classic/dist/index.html`: 1 untracked entry
  - Non-dist code/test/local-tooling entries: 15 files

### Classification table

| file/path pattern | belongs_to | evidence | recommended commit grouping | exact verification commands needed |
|---|---|---|---|---|
| `web/creative/dist/**` | dist | `main.go` embeds `web/creative/dist` (`main.go:50-54`); current tree has 222 files / 137 assets; `index.html` references `/creative/assets/index-Bhsy9ZA3.css` and `/creative/assets/index-DFFdajJX.js`; no fixture markers found; `version.json` is `0.9.6`, `buildTime=2026-06-09T03:17:19.444Z`. | Commit group A: `sprint1-production-creative-dist-sync`; include deletions of old hashed assets, new hashed assets, and modified manifests/index/stats/version together. | `cd /mnt/f/code/project/new-api && GOCACHE=/tmp/go-build-cache go test . -run TestCreativeProductionRootDistMatchesRouterDistAndContract -count=1`; `cd /mnt/f/code/project/new-api && GOCACHE=/tmp/go-build-cache go test ./router -run 'Test.*Creative.*(Production|Fixture|Cache|Provenance|Asset|WebRouter)' -count=1`; run the hash/marker script in the verification section below. |
| `router/web/creative/dist/**` | dist | Router test copy is currently untracked but byte-identical to `web/creative/dist` for all 222 files; `main_creative_dist_test.go` embeds it (`main_creative_dist_test.go:17-18`) and compares root/router hashes (`main_creative_dist_test.go:35-70`). | Commit group A with `web/creative/dist/**`; do not leave router copy untracked if the test embeds it. | Same dist commands as above; specifically the root-vs-router hash script must report `missing=0 diff=0`. |
| `main_creative_dist_test.go` | dist | New production-root regression test checks `creativeIndexPage` equals `web/creative/dist/index.html`, root/router `index.html`, `sw.js`, `version.json`, entry JS/CSS hashes, `/creative/assets` references, and fixture-marker absence (`main_creative_dist_test.go:35-70`, `main_creative_dist_test.go:89-118`). | Commit group A. | `cd /mnt/f/code/project/new-api && GOCACHE=/tmp/go-build-cache go test . -run TestCreativeProductionRootDistMatchesRouterDistAndContract -count=1`. |
| `relay/constant/relay_mode.go`, `relay/constant/relay_mode_test.go` | image-relay | Dirty code maps `/creative/relay/v1/chat/completions` and `/creative/relay/v1/images/generations` to relay modes (`relay/constant/relay_mode.go:57-73`); tests cover both creative chat and image paths (`relay/constant/relay_mode_test.go:9-18`). | Commit group B: `sprint1-creative-image-relay-mode`. | `cd /mnt/f/code/project/new-api && GOCACHE=/tmp/go-build-cache go test ./relay/constant -run 'TestCreativeRelayMode(ChatCompletions|ImagesGenerations)' -count=1`; also run the full image-relay regex suite below. |
| `relay/common/relay_info.go`, `relay/common/relay_info_test.go` | image-relay | Dirty code treats `/creative/relay/v1` as playground/session-broker traffic, normalizes `RequestURLPath` by trimming `/creative/relay`, and derives relay mode if still unknown (`relay/common/relay_info.go:507-512`); tests cover chat and image normalization (`relay/common/relay_info_test.go:46-69`). | Commit group B with relay-mode files. | `cd /mnt/f/code/project/new-api && GOCACHE=/tmp/go-build-cache go test ./relay/common -run 'TestCreative.*RelayMode.*' -count=1`; also run the full image-relay regex suite below. |
| `router/web_router_test.go` | validation | Untracked router test covers `/creative/relay/v1/images/generations` auth/route behavior (`router/web_router_test.go:76-91`) and production build contract / fixture-marker absence (`router/web_router_test.go:181-202`). | Commit group C: `sprint1-router-validation`; can be grouped with dist if reviewer wants all embed tests together, but it is test-only validation. | `cd /mnt/f/code/project/new-api && GOCACHE=/tmp/go-build-cache go test ./router -run 'TestSetWebRouterKeepsCreativeRoutesGinSafe|TestCreativeEmbedded.*' -count=1`. |
| `router/web/default/dist/index.html`, `router/web/classic/dist/index.html` | validation | Untracked 57-byte fixtures are required by `router/web_router_test.go` `//go:embed web/default/dist` and `//go:embed web/classic/dist` (`router/web_router_test.go:16-25`); they are not production dist artifacts. | Commit group C with `router/web_router_test.go`; keep them clearly as router test fixtures, not production builds. | Same router test command as above. |
| `controller/model_list_test.go` | validation | Dirty test sets `ContextKeyUserGroup=default` before token-limit model-list assertions (`controller/model_list_test.go:213-229`); supports broad controller validation after group-aware model owner logic. | Commit group D: `sprint1-broad-validation-model-list-and-creative-model-pool`. | `cd /mnt/f/code/project/new-api && GOCACHE=/tmp/go-build-cache go test ./controller -run TestListModelsTokenLimitIncludesTieredBillingModel -count=1`; plus broad validation command below. |
| `model/ability.go`, `model/model_meta.go` | validation | Dirty helper `abilityGroupCol()` guards group-column quoting when `commonGroupCol` is unset in isolated tests (`model/ability.go:41-56`) and model owner lookup now uses it (`model/model_meta.go:177-180`); creative model pool depends on `GetGroupEnabledModels` (`service/creative.go:12-17`). | Commit group D with controller model-list validation. | `cd /mnt/f/code/project/new-api && GOCACHE=/tmp/go-build-cache go test ./model -run 'Test(GetPreferredModelOwnerChannelTypes|.*Creative.*|.*Ability.*)' -count=1`; plus broad validation command below. |
| `service/funding_source.go`, `service/text_quota.go`, `service/task_billing_test.go`, `service/creative_billing_test.go` | validation | Dirty service code makes subscription refund idempotent in one DB transaction (`service/funding_source.go:114-158`), treats nil text usage as zero usage rather than estimated prompt usage (`service/text_quota.go:177-183`), eagerly cleans billing test tables (`service/task_billing_test.go:58-70`), and adds creative session billing tests using `/creative/relay/v1/chat/completions` context (`service/creative_billing_test.go:24-70`, `service/creative_billing_test.go:203-240`, `service/creative_billing_test.go:349-379`, `service/creative_billing_test.go:469-485`). | Commit group E: `sprint1-broad-validation-creative-billing`; keep separate from route/dist to make billing behavior reviewable. | `cd /mnt/f/code/project/new-api && GOCACHE=/tmp/go-build-cache go test ./service -run 'Test(.*CreativeSessionBilling.*|PostTextCreativeBillingMissingUsage|.*TaskBilling.*)' -count=1`; plus image-relay regex suite and broad validation command below. |
| `.gitignore` | unrelated | Only dirty line adds `.ace-tool/`; this is local tooling hygiene, not mentioned in PRD R1/R2/R6 or Sprint1 result. | Hold out or make a separate local-tooling commit only if desired; do not mix with Sprint1 acceptance commits. | None for parent acceptance. If kept, only run `cd /mnt/f/code/project/new-api && GIT_OPTIONAL_LOCKS=0 git diff --check -- .gitignore`. |

No `unknown` dirty files were found after grouping by status prefix and inspecting the non-dist code/test diffs.

### Current dist identity evidence

- `new-api/web/creative/dist` vs `new-api/router/web/creative/dist`: 222 relative files, `missing=0`, `diff=0`.
- Both new-api dist roots have no fixture marker matches for `creative fixture`, `creativeServiceWorkerFixture`, `9.9.9-test`, or `creative-test-commit`.
- `new-api/web/creative/dist` vs `/mnt/f/code/project/opentu/dist/apps/web`: 222 relative files, `missing=0`, `diff=1`; the differing file is `sw.js`.
  - This is a caveat for the word “latest”: the new-api root/router copies are internally consistent, but opentu's current local `dist/apps/web/sw.js` has changed since the new-api sync.

### Verification commands

#### Dist / production embed path

```bash
cd /mnt/f/code/project/new-api
GOCACHE=/tmp/go-build-cache go test . -run TestCreativeProductionRootDistMatchesRouterDistAndContract -count=1
GOCACHE=/tmp/go-build-cache go test ./router -run 'Test.*Creative.*(Production|Fixture|Cache|Provenance|Asset|WebRouter)' -count=1
python3 - <<'PY'
from pathlib import Path
import hashlib
pairs=[('/mnt/f/code/project/new-api/web/creative/dist','/mnt/f/code/project/new-api/router/web/creative/dist'),('/mnt/f/code/project/new-api/web/creative/dist','/mnt/f/code/project/opentu/dist/apps/web')]
for a,b in pairs:
    A=Path(a); B=Path(b)
    rels=sorted({str(p.relative_to(A)) for p in A.rglob('*') if p.is_file()} | {str(p.relative_to(B)) for p in B.rglob('*') if p.is_file()})
    miss=[]; diff=[]
    for rel in rels:
        pa=A/rel; pb=B/rel
        if not pa.exists() or not pb.exists(): miss.append((rel,pa.exists(),pb.exists()))
        elif hashlib.sha256(pa.read_bytes()).digest()!=hashlib.sha256(pb.read_bytes()).digest(): diff.append(rel)
    print(f'{A} vs {B}: rels={len(rels)} missing={len(miss)} diff={len(diff)}')
    if miss: print('missing sample', miss[:20])
    if diff: print('diff sample', diff[:20])
markers=['creative fixture','creativeServiceWorkerFixture','9.9.9-test','creative-test-commit']
for root in [Path('/mnt/f/code/project/new-api/web/creative/dist'), Path('/mnt/f/code/project/new-api/router/web/creative/dist')]:
    found=[]
    for p in root.rglob('*'):
        if p.is_file():
            s=p.read_text(errors='ignore')
            for marker in markers:
                if marker in s: found.append((str(p.relative_to(root)), marker))
    print(root, 'fixture markers', found)
PY
```

#### Image relay

```bash
cd /mnt/f/code/project/new-api
GOCACHE=/tmp/go-build-cache go test ./relay/constant -run 'TestCreativeRelayMode(ChatCompletions|ImagesGenerations)' -count=1
GOCACHE=/tmp/go-build-cache go test ./relay/common -run 'TestCreative.*RelayMode.*' -count=1
GOCACHE=/tmp/go-build-cache go test ./router ./controller ./middleware ./relay/common ./relay/constant ./service -run 'Test(.*Creative.*|.*RelayMode.*|.*Image.*|.*Forbidden.*|.*Nonce.*|.*Billing.*)' -count=1
```

#### Broad new-api validation

```bash
cd /mnt/f/code/project/new-api
git diff --check
GOCACHE=/tmp/go-build-cache go test ./controller ./middleware ./model ./relay/common ./relay/constant ./router ./service -count=1
GOCACHE=/tmp/go-build-cache go test ./... -count=1
```

#### Parent-level opentu validation / “latest dist” check

Because current `/mnt/f/code/project/opentu/dist/apps/web/sw.js` differs from both new-api dist copies, rerun this if opentu is still the authoritative “latest” build source before committing dist artifacts:

```bash
cd /mnt/f/code/project/opentu
NX_DAEMON=false VITE_BASE_URL=/creative/ pnpm build:web
cd /mnt/f/code/project/opentu/packages/drawnix
TMPDIR=/dev/shm pnpm exec tsc -p tsconfig.spec.json --noEmit --pretty false
../../node_modules/.bin/vitest run \
  src/utils/__tests__/ai-model-selection-storage.test.ts \
  src/components/ai-input-bar/ModelDropdown.test.tsx \
  src/components/ai-input-bar/ModelSelector.test.tsx \
  src/services/creative-session-broker.test.ts \
  src/services/creative-display-policy.test.ts \
  src/services/creative-document-sync.test.ts \
  src/services/creative-model-preference-sync.test.ts \
  src/services/provider-routing/provider-transport.session-broker.test.ts \
  src/hooks/use-creative-document-sync-status.test.tsx \
  src/utils/gemini-api/auth.creative-embedded.test.ts \
  --config vitest.config.ts --pool=threads --maxWorkers=1 --minWorkers=1
```

#### Browser smoke / E2E acceptance

```text
fresh authenticated new-api session:
1. Open /creative and verify embedded app loads current dist.
2. Trigger image generation and confirm request path is /creative/relay/v1/images/generations.
3. Confirm request does not carry Authorization/apiKey/baseUrl/provider override fields.
4. Confirm nonce/CSRF protections reject missing nonce.
5. Click Return-to-console and confirm navigation to /dashboard.
```

## Files found

- `/mnt/f/code/project/new-api/main.go` — production embed path for creative root dist (`web/creative/dist`).
- `/mnt/f/code/project/new-api/main_creative_dist_test.go` — untracked production root/router creative dist identity regression test.
- `/mnt/f/code/project/new-api/web/creative/dist/**` — dirty production embedded opentu dist copy.
- `/mnt/f/code/project/new-api/router/web/creative/dist/**` — untracked router/test creative dist copy; byte-identical to production root copy.
- `/mnt/f/code/project/new-api/router/web_router_test.go` — untracked router validation for creative SPA, relay image route, cache/provenance/security headers, and production build contract.
- `/mnt/f/code/project/new-api/relay/constant/relay_mode.go` and `relay/constant/relay_mode_test.go` — dirty creative relay mode mapping and tests.
- `/mnt/f/code/project/new-api/relay/common/relay_info.go` and `relay/common/relay_info_test.go` — dirty creative relay request-path normalization and tests.
- `/mnt/f/code/project/new-api/service/creative_billing_test.go`, `service/funding_source.go`, `service/text_quota.go`, `service/task_billing_test.go` — dirty broad validation / billing idempotency and nil-usage handling around creative session-broker flows.
- `/mnt/f/code/project/new-api/controller/model_list_test.go`, `model/ability.go`, `model/model_meta.go` — dirty broad validation around group-aware model listing/model ownership, relevant to creative model pools.
- `/mnt/f/code/project/new-api/router/web/default/dist/index.html`, `router/web/classic/dist/index.html` — untracked minimal fixtures needed by router test embeds.
- `/mnt/f/code/project/new-api/.gitignore` — unrelated local tooling ignore for `.ace-tool/`.

## Code patterns

- Production embed path: `main.go:50-54` uses `//go:embed web/creative/dist` and `web/creative/dist/index.html`.
- Production dist test pattern: `main_creative_dist_test.go:35-70` compares root/router dist hashes and `main_creative_dist_test.go:51-60` walks root dist for fixture markers.
- Image relay route exists in clean tracked code: `router/web-router.go:76-87` registers `POST /creative/relay/v1/images/generations` under the same creative session-broker/nonce/forbidden-field middleware chain.
- Image relay handler exists in clean tracked code: `controller/creative.go:383-389` dispatches chat as `RelayFormatOpenAI` and images as `RelayFormatOpenAIImage`.
- Dirty relay mode mapping: `relay/constant/relay_mode.go:57-73` maps creative chat/images paths to existing relay modes.
- Dirty relay info normalization: `relay/common/relay_info.go:507-512` marks `/creative/relay/v1` as playground/session-broker traffic and normalizes request path.
- Dirty billing validation: `service/funding_source.go:123-158` refunds subscription preconsume in a single idempotent transaction; `service/text_quota.go:177-183` settles nil usage as zero; `service/creative_billing_test.go:469-485` creates a creative relay test context.

## External references

- None. This was an internal working-tree and task-artifact inspection only; no web lookup was needed.

## Related specs

- `.trellis/spec/backend/index.md` — backend spec index; creative asset sync is active but not represented by current dirty new-api files.
- `.trellis/spec/backend/creative-asset-sync.md` — archived cloud-assets child contract; useful caveat for asset API boundaries, but no current dirty files in new-api are attributable to this child.
- `.trellis/spec/frontend/creative-asset-sync.md` — parent-level asset sync contract; not part of current dirty new-api Sprint1 dist/image-relay/validation grouping.
- `new-api/AGENTS.md` — project conventions: Go layered architecture, JSON wrapper rule, cross-DB support, Bun for frontend, and protected project identity.

## Caveats / Not Found

- `python3 ./.trellis/scripts/task.py current --source` returned `Current task: (none)` in this shell. I used the task directory explicitly provided by the user: `.trellis/tasks/06-09-newapi-opentu-creative-remediation`.
- I used read-only git inspection with `GIT_OPTIONAL_LOCKS=0` to classify the working tree because the task explicitly asks for dirty files. I did not stage, commit, or edit files outside this research output.
- New-api root/router creative dist copies are internally byte-identical, but current opentu `dist/apps/web/sw.js` differs from them. If opentu is still the source of truth for “latest,” rebuild/resync before committing dist artifacts.
- `controller/creative.go` and `router/web-router.go` contain the core image route/handler evidence but are not currently dirty; they should not be part of the dirty-file commit unless future edits change them.
- No dirty files were classified as `unknown` after grouping all 339 dirty status entries.
