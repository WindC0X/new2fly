# Verification

## Static and unit checks

- `go test ./service ./controller -run 'Creative(ModelBindings|Adapter)|ParseCreativeModelBindings|ValidateCreativeModelBindings|StoredCreativeModelBindings'` — PASS.
- `go test ./router -run TestDoesNotExist` — PASS, router package compiles with the new route.
- `bun run typecheck` in `new-api/web/default` — PASS.
- `./node_modules/.bin/eslint src/features/system-settings/models/creative-model-bindings-section.tsx src/features/system-settings/api.ts src/features/system-settings/types.ts` — PASS.
- `bun run build` in `new-api/web/default` — PASS.
- `git diff --check` in `new-api` and `new2fly` — PASS.
- `python3 scripts/creative_release_gate.py check --source-diff-check` — PASS.

## Dynamic workflow review

- Initial workflow: `.codex-flow/generated/creative-adapter-manifest-review.workflow.ts`
  - Journal: `.codex-flow/journal/creative-adapter-manifest-review.jsonl`
  - Completed 2/4 branches; found backend/frontend issues around offline-only gating, manifest self-validation, route coverage, fail-closed manifest fetch, hard-coded UI paths, disabled statuses, template constraints, misleading channel id, and i18n.
  - Findings were triaged and fixed.
- Post-fix workflow: `.codex-flow/generated/creative-adapter-manifest-postfix-review.workflow.ts`
  - Journal: `.codex-flow/journal/creative-adapter-manifest-postfix-review.jsonl`
  - Completed 1/3 branches; found two frontend issues: `defaultTemplate` bypass of `allowedTemplates`, and stale `draftAdapterPreset` writes. Both fixed.
- Post-fix frontend re-review: `.codex-flow/generated/creative-adapter-manifest-postfix2-frontend.workflow.ts`
  - Journal: `.codex-flow/journal/creative-adapter-manifest-postfix2-frontend.jsonl`
  - PASS, no remaining frontend findings.
- Post-fix backend re-review: `.codex-flow/generated/creative-adapter-manifest-postfix2-backend.workflow.ts`
  - Journal: `.codex-flow/journal/creative-adapter-manifest-postfix2-backend.jsonl`
  - Timed out without output. Backend closure was covered by main-session code inspection plus Go/controller/router tests.

## Local staging

- Built image: `new-api-creative-embed:staging-current`, image id `sha256:82f3c839ccdc3eb3170692f650ca3b0475ea7de0b60ae7542719281b3b319a69`.
- Recreated local staging container: `newapi-opentu-staging-new-api`, bound to `127.0.0.1:39084`.
- `GET http://127.0.0.1:39084/api/status` — healthy.
- Logged in as local staging admin and fetched `GET /api/creative/adapter-manifests` with dashboard cookie + `New-Api-User: 1`:
  - status `200`, `Cache-Control: private, no-store`, `Pragma: no-cache`.
  - manifests include `mock_image_task:available:true`, `grsai_gpt_image_dryrun:available:false`, `duomi_image_live:future:false`, `grsai_image_live:future:false`.
  - parameter templates expose `quality` label as `质量`.
  - response scan did not contain `sk-`, `apiKey`, `baseUrl`, `credential`, `callback`, or `webhook`.
- `python3 scripts/creative_release_gate.py check --embedded-smoke-url http://127.0.0.1:39084/creative/` — PASS, Playwright embedded smoke `1 passed`.

## Known limits

- Phase A intentionally does not implement real Duomi/GrsAI provider transport, polling, billing, or result parsing.
- The backend post-fix dynamic workflow branch timed out, so final backend closure relies on main-session verification and automated tests rather than a completed workflow branch.
