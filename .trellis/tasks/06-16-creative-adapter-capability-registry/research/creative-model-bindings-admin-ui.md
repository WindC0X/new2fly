# Research: Creative model bindings admin UI

- Query: Locate `new-api` `web/default` routing/sidebar/API/form patterns for a new root-only Creative model bindings management page.
- Scope: mixed (internal codebase + package-version references)
- Date: 2026-06-16

## Findings

### Files found

- `/mnt/f/code/project/new-api/web/default/src/routes/_authenticated/system-settings/route.tsx` — root-only guard for all system settings pages.
- `/mnt/f/code/project/new-api/web/default/src/routes/_authenticated/system-settings/models/$section.tsx` — path-section route for model settings; validates section ids from model settings registry.
- `/mnt/f/code/project/new-api/web/default/src/features/system-settings/models/section-registry.tsx` — Models & Routing section registry; best place to add a `creative-model-bindings` section.
- `/mnt/f/code/project/new-api/web/default/src/features/system-settings/models/index.tsx` — wraps registry with generic `SettingsPage` and loads generic system options.
- `/mnt/f/code/project/new-api/web/default/src/features/system-settings/models/creative-model-policy-section.tsx` — closest UI/API pattern for a dedicated Creative admin page with React Query, diagnostics, guided editor, advanced JSON, nonce-protected save.
- `/mnt/f/code/project/new-api/web/default/src/features/system-settings/api.ts` — central system-settings API client; already has Creative policy endpoints and a private `getCreativeNonceHeaders()` helper.
- `/mnt/f/code/project/new-api/web/default/src/features/system-settings/types.ts` — existing system-settings DTO types; add Creative model bindings request/response/dry-run types here.
- `/mnt/f/code/project/new-api/web/default/src/components/layout/config/system-settings.config.ts` — nested System Settings sidebar automatically includes model section nav items.
- `/mnt/f/code/project/new-api/web/default/src/hooks/use-sidebar-data.ts` and `/mnt/f/code/project/new-api/web/default/src/hooks/use-sidebar-view.ts` — root sidebar and admin-group visibility; System Settings root item already exists.
- `/mnt/f/code/project/new-api/web/default/src/components/json-editor.tsx` — shared object-map JSON editor; not a good fit for `bindings: []` array editing.
- `/mnt/f/code/project/new-api/router/api-router.go` — backend routes for `/api/creative/model-bindings` already registered under `RootAuth` with nonce on writes/validate/dry-run.
- `/mnt/f/code/project/new-api/controller/creative_model_bindings.go` — backend response/request shapes and access-token rejection behavior.
- `/mnt/f/code/project/new-api/service/creative_model_capability.go` — authoritative binding config, admin state, and dry-run DTO shapes.

### Code patterns

#### Route and permission model

- The authenticated layout guard lives at `_authenticated`: it requires `auth.user`, verifies the browser session once through `getSelf()`, and redirects to `/sign-in` when absent/invalid (`web/default/src/routes/_authenticated/route.tsx:27`, `web/default/src/routes/_authenticated/route.tsx:31`, `web/default/src/routes/_authenticated/route.tsx:40`).
- All `/system-settings/*` UI routes are root-only, not merely admin: `auth.user?.role !== ROLE.SUPER_ADMIN` redirects to `/403` (`web/default/src/routes/_authenticated/system-settings/route.tsx:24`, `web/default/src/routes/_authenticated/system-settings/route.tsx:28`). `ROLE.SUPER_ADMIN` is `100`, while `ROLE.ADMIN` is `10` (`web/default/src/lib/roles.ts:21`).
- The model settings path route validates `$section` against `MODELS_SECTION_IDS`; adding a new section to `MODELS_SECTIONS` is enough for the route to accept `/system-settings/models/<new-section>` (`web/default/src/routes/_authenticated/system-settings/models/$section.tsx:26`, `web/default/src/routes/_authenticated/system-settings/models/$section.tsx:29`).
- TanStack file routes are used; route files are under `web/default/src/routes` and generated route output is ignored by knip (`web/default/package.json:29`, `web/default/package.json:83`, `web/default/knip.config.ts:4`). Do not hand-edit generated `routeTree.gen.ts`.

#### Sidebar/menu placement

- The root sidebar already has an `Admin` group and `System Settings` item pointing to `/system-settings/site` (`web/default/src/hooks/use-sidebar-data.ts:123`, `web/default/src/hooks/use-sidebar-data.ts:151`).
- Root sidebar admin group visibility is `role >= ROLE.ADMIN`, but actual System Settings route remains `SUPER_ADMIN`-only (`web/default/src/hooks/use-sidebar-view.ts:52`, `web/default/src/hooks/use-sidebar-view.ts:53`, `web/default/src/routes/_authenticated/system-settings/route.tsx:28`).
- `useSidebarConfig` maps `/system-settings` and `/system-settings/site` to the admin `setting` module (`web/default/src/hooks/use-sidebar-config.ts:116`, `web/default/src/hooks/use-sidebar-config.ts:117`), and unmapped URLs default visible (`web/default/src/hooks/use-sidebar-config.ts:172`). A new nested `/system-settings/models/creative-model-bindings` does not need a new root-sidebar map because nested views bypass this filter.
- System Settings uses a nested sidebar view for `/system-settings/*` (`web/default/src/components/layout/config/system-settings.config.ts:98`, `web/default/src/components/layout/config/system-settings.config.ts:100`). The `Models & Routing` group takes `getModelsSectionNavItems(t)` from the model section registry (`web/default/src/components/layout/config/system-settings.config.ts:67`, `web/default/src/components/layout/config/system-settings.config.ts:69`).
- `createSectionRegistry` generates sidebar nav items from each section’s `titleKey` and path-style basePath (`web/default/src/features/system-settings/utils/section-registry.ts:66`, `web/default/src/features/system-settings/utils/section-registry.ts:70`). Therefore, adding a model section automatically adds a nested sidebar item.

#### Existing model settings structure

- `ModelSettings` uses generic `SettingsPage` with `routePath='/_authenticated/system-settings/models/$section'`, `defaultSettings`, and model section registry callbacks (`web/default/src/features/system-settings/models/index.tsx:75`, `web/default/src/features/system-settings/models/index.tsx:77`).
- Existing `MODELS_SECTIONS` includes `creative-model-policy` with `build: () => <CreativeModelPolicySection />` (`web/default/src/features/system-settings/models/section-registry.tsx:146`, `web/default/src/features/system-settings/models/section-registry.tsx:149`). This is the best precedent: a dedicated API-backed Creative section can ignore generic option settings.
- The registry’s base path is `/system-settings/models` and urlStyle is `path` (`web/default/src/features/system-settings/models/section-registry.tsx:167`, `web/default/src/features/system-settings/models/section-registry.tsx:170`, `web/default/src/features/system-settings/models/section-registry.tsx:171`). Suggested new route URL: `/system-settings/models/creative-model-bindings`.

#### API client and nonce pattern

- `api` is a same-origin Axios instance with `withCredentials: true` and no base URL (`web/default/src/lib/api.ts:38`, `web/default/src/lib/api.ts:42`, `web/default/src/lib/api.ts:44`).
- Creative policy GET uses `/api/creative/model-policy`; writes call `getCreativeNonceHeaders()` first and send `X-Creative-CSRF`/`X-Creative-Nonce` from `/creative/api/bootstrap` (`web/default/src/features/system-settings/api.ts:43`, `web/default/src/features/system-settings/api.ts:50`, `web/default/src/features/system-settings/api.ts:59`, `web/default/src/features/system-settings/api.ts:64`, `web/default/src/features/system-settings/api.ts:70`).
- Backend model-bindings routes already exist: `GET`, `PUT`, `POST validate`, `POST dry-run` under `/api/creative/model-bindings` (`router/api-router.go:201`, `router/api-router.go:206`). `PUT`, `validate`, and `dry-run` all require `CreativeRequireNonce()` (`router/api-router.go:207`, `router/api-router.go:208`, `router/api-router.go:209`).
- Generic option writes reject both `creative.model_policy` and `creative.model_bindings`; the UI must not use `updateSystemOption`/`/api/option` for this page (`controller/option.go:147`, `controller/option.go:150`).
- Controller accepts payload as direct config, `{ config }`, `{ bindings, version }`, or `{ value }` (`controller/creative_model_bindings.go:102`, `controller/creative_model_bindings.go:107`, `controller/creative_model_bindings.go:110`, `controller/creative_model_bindings.go:113`). Prefer `{ config }` in UI for clarity.
- Controller rejects API access-token-only usage even though routes are root-only (`controller/creative_model_bindings.go:77`, `controller/creative_model_bindings.go:78`).

#### Backend DTOs the UI should mirror

- Stored/admin config is `{ version: number, bindings: CreativeModelBindingConfig[] }` (`service/creative_model_capability.go:91`). Binding fields are `id`, `providerModelId`, `priceModelId`, `displayName`, `modality`, `enabled`, `canaryGroups`, `channelId`, `adapterPreset`, `parameterTemplate`, `recommendedScore`, `sortOrder`, and `parameterSchema` (`service/creative_model_capability.go:96`).
- Admin state response contains `{ config, configJSON }` (`service/creative_model_capability.go:112`).
- Dry-run response contains `noProviderCall` and per-binding preview items (`service/creative_model_capability.go:117`). Each item includes ids, modality/enabled/preset/template, and `requestPreview` (`service/creative_model_capability.go:122`).
- Dry-run is explicitly no-provider-call and redacts sensitive values before returning (`service/creative_model_capability.go:519`, `service/creative_model_capability.go:525`, `service/creative_model_capability.go:538`). GRS AI dry-run preview is fixture/offline only (`service/creative_model_capability.go:544`, `service/creative_model_capability.go:547`, `service/creative_model_capability.go:550`).
- Backend allows only image modality today (`service/creative_model_capability.go:35`) and presets/templates are limited to `mock_image_task`/`mock_gpt_image` and `grsai_gpt_image_dryrun`/`grsai_gpt_image` (`service/creative_model_capability.go:39`, `service/creative_model_capability.go:44`, `service/creative_model_capability.go:588`).
- Raw JSON key validation rejects unsupported/forbidden top-level, binding, schema, and option keys (`service/creative_model_capability.go:637`, `service/creative_model_capability.go:662`, `service/creative_model_capability.go:679`, `service/creative_model_capability.go:696`).

#### Form/JSON editing patterns

- `CreativeModelPolicySection` uses React Query for load/save and local builder state keyed by server `policyJSON` (`web/default/src/features/system-settings/models/creative-model-policy-section.tsx:822`, `web/default/src/features/system-settings/models/creative-model-policy-section.tsx:825`, `web/default/src/features/system-settings/models/creative-model-policy-section.tsx:861`, `web/default/src/features/system-settings/models/creative-model-policy-section.tsx:863`).
- It uses `useMutation` with `queryClient.setQueryData`, invalidation, and toast success/error (`web/default/src/features/system-settings/models/creative-model-policy-section.tsx:882`, `web/default/src/features/system-settings/models/creative-model-policy-section.tsx:889`, `web/default/src/features/system-settings/models/creative-model-policy-section.tsx:891`).
- It has a default guided save and an advanced JSON editor with format/load/save actions (`web/default/src/features/system-settings/models/creative-model-policy-section.tsx:920`, `web/default/src/features/system-settings/models/creative-model-policy-section.tsx:964`, `web/default/src/features/system-settings/models/creative-model-policy-section.tsx:1133`, `web/default/src/features/system-settings/models/creative-model-policy-section.tsx:1148`, `web/default/src/features/system-settings/models/creative-model-policy-section.tsx:1180`).
- Page-level actions are inserted through `SettingsPageFormActions`, which portals buttons into `SettingsPage` action area (`web/default/src/features/system-settings/components/settings-page-context.tsx:114`, `web/default/src/features/system-settings/components/settings-page-context.tsx:121`).
- `SettingsCard`, `SettingsSection`, `Alert`, `Badge`, `Textarea`, `NativeSelect`, and `Button` are existing local UI primitives already used by Creative policy (`web/default/src/features/system-settings/models/creative-model-policy-section.tsx:24`, `web/default/src/features/system-settings/models/creative-model-policy-section.tsx:36`, `web/default/src/features/system-settings/models/creative-model-policy-section.tsx:38`, `web/default/src/features/system-settings/models/creative-model-policy-section.tsx:40`).
- Shared `JsonEditor` converts object key/value maps and is not suitable as the main editor for `creative.model_bindings` because the config is an object with a `bindings` array and nested `parameterSchema` arrays (`web/default/src/components/json-editor.tsx:27`, `web/default/src/components/json-editor.tsx:75`, `web/default/src/components/json-editor.tsx:102`). Use a monospaced `Textarea` for the minimal implementation.

### Recommended minimal implementation shape

1. Add DTO types in `web/default/src/features/system-settings/types.ts`:
   - `CreativeParameterSchemaItem` / option type matching the task contract.
   - `CreativeModelBindingsConfig`, `CreativeModelBindingConfig`, `CreativeModelBindingsState`, `CreativeModelBindingsDryRunResult`, and response/request types.
2. Add API functions in `web/default/src/features/system-settings/api.ts`:
   - `getCreativeModelBindings()` → `GET /api/creative/model-bindings`.
   - `validateCreativeModelBindings(config)` → nonce headers + `POST /api/creative/model-bindings/validate` with `{ config }`.
   - `dryRunCreativeModelBindings(config)` → nonce headers + `POST /api/creative/model-bindings/dry-run` with `{ config }`.
   - `updateCreativeModelBindings(config)` → nonce headers + `PUT /api/creative/model-bindings` with `{ config }`.
   - Reuse the existing private `getCreativeNonceHeaders()` in the same file; do not add a second bootstrap helper unless it is shared deliberately.
3. Add `web/default/src/features/system-settings/models/creative-model-bindings-section.tsx`:
   - Query key e.g. `['creative-model-bindings']`.
   - Load state from `state.configJSON`; local editor string starts as pretty JSON.
   - Provide buttons: Format JSON, Validate, Dry Run, Save. Save should parse JSON and call update endpoint; validate/dry-run should parse and call dedicated endpoints before production write.
   - Render summary cards: binding count, enabled count, canary-only count, dry-run `noProviderCall` status.
   - Render validation/dry-run panels with redacted `requestPreview` in read-only `<pre>`/Textarea style.
   - Keep guided field editing optional; JSON-first is acceptable because backend owns validation and this page is root-only.
4. Register the section in `web/default/src/features/system-settings/models/section-registry.tsx`:
   - import `CreativeModelBindingsSection`.
   - add `{ id: 'creative-model-bindings', titleKey: 'Creative Model Bindings', build: () => <CreativeModelBindingsSection /> }` next to `creative-model-policy`.
   - Route `/system-settings/models/creative-model-bindings` and nested sidebar item should then work through existing `MODELS_SECTION_IDS` and `getModelsSectionNavItems`.
5. Do not change root sidebar unless product wants a top-level item. Current System Settings -> Models & Routing nested nav is the least invasive and inherits root-only route guarding.

### Validation commands

Run from `/mnt/f/code/project/new-api/web/default`:

```bash
pnpm typecheck
pnpm lint
pnpm build:check
```

If generated routes are not updated automatically by the build/typecheck flow, run the repo’s normal TanStack router generation path through the existing build tooling rather than editing `src/routeTree.gen.ts` manually.

For backend contract confidence from `/mnt/f/code/project/new-api`:

```bash
go test ./controller ./service -run 'CreativeModelBindings|UpdateOptionRejectsCreativeModelBindingsGenericWrite'
```

## External references

- Dependency versions from `web/default/package.json`: `@tanstack/react-router` `^1.170.8`, `@tanstack/react-query` `^5.100.14`, React `^19.2.6`, TypeScript `~6.0.3`, Rsbuild `^2.0.7` (`web/default/package.json:29`, `web/default/package.json:30`, `web/default/package.json:51`, `web/default/package.json:78`, `web/default/package.json:90`).
- No live external documentation lookup was required; behavior was inferred from current source and package versions.

## Related specs

- Task design requires `creative.model_bindings` be writable only through dedicated admin APIs, not generic option editing (`.trellis/tasks/06-16-creative-adapter-capability-registry/design.md:98`, `.trellis/tasks/06-16-creative-adapter-capability-registry/design.md:100`).
- Task design defines required admin endpoints and gates: session/admin auth, same-origin + nonce for writes/dry-run, no API-token-only, generic option block, sanitized audit, redacted dry-run (`.trellis/tasks/06-16-creative-adapter-capability-registry/design.md:126`, `.trellis/tasks/06-16-creative-adapter-capability-registry/design.md:135`).
- Parameter schema contract and allowed field types are frozen cross-repo (`.trellis/tasks/06-16-creative-adapter-capability-registry/design.md:62`, `.trellis/tasks/06-16-creative-adapter-capability-registry/design.md:84`).
- Backend security boundary forbids browser-provided upstream credentials/routing authority and requires redaction of provider/private URL material (`.trellis/spec/backend/creative-backend-security-boundary.md:33`, `.trellis/spec/backend/creative-backend-security-boundary.md:39`).
- Existing Creative model policy spec allows expert JSON editor only when save/read flow goes through the dedicated Creative endpoint (`.trellis/spec/backend/creative-backend-security-boundary.md:134`, `.trellis/spec/backend/creative-backend-security-boundary.md:136`).
- Frontend spec files for directory/components/hooks are currently placeholders, so codebase-local patterns above are more authoritative (`.trellis/spec/frontend/directory-structure.md:19`, `.trellis/spec/frontend/component-guidelines.md:19`, `.trellis/spec/frontend/hook-guidelines.md:19`).

## Caveats / Not Found

- No `web/default` unit-test pattern exists for system-settings Creative policy/bindings; only a UI dropdown test was found. Validation will likely be typecheck/lint/build unless implementer adds new tests.
- The root sidebar shows the `Admin` group to `ROLE.ADMIN`, while `/system-settings` itself is `ROLE.SUPER_ADMIN` only. This existing mismatch can show a link that 403s for non-root admins; not introduced by the bindings page.
- `JsonEditor` is object-map oriented and should not be used as the primary editor for nested binding arrays.
- I did not inspect or modify generated route files; route generation should be left to existing TanStack/Rsbuild tooling.
