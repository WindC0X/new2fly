# Final Remediation and Postfix Review Evidence

Date: 2026-06-12

## Additional fixes after final goal-attainment audit

### `new-api`

- Added Creative API safe-read cross-origin hardening:
  - `/creative/api/*` safe `GET` remains compatible with originless browser navigation/bootstrap.
  - Explicit cross-site `Origin` / `Referer` on `/creative/api/*` is rejected.
  - Unsafe `/creative/api/*` routes still require CSRF + nonce.
  - `/creative/relay/v1/*` remains same-origin/session protected, with nonce required only for unsafe methods.
- Updated `docs/openapi/creative-embed.md` to clarify the origin/nonce matrix.

### `opentu`

- Removed remaining random/opaque session-broker idempotency fallbacks:
  - Suno submit now requires stable task/idempotency source before fetch.
  - Shared media-api video submit now validates idempotency before reference image fetch or submit fetch.
- Added callback/webhook stripping for session-broker header/query/path material, including normalized `callback`, `webhook`, `callbackUrl`, `webhook_url`, and `X-*` variants.
- Sanitized session-broker non-unsupported error handling:
  - video submit/status/content;
  - shared `media-api/video-api` submit/content;
  - Suno submit/fetch.
- Fixed CDN/NPM docs to avoid stale `index.html` npm CDN examples; package remains static assets only.

### Trellis specs

- Updated frontend Suno/Video specs for stable idempotency and status-only error sanitization.
- Updated backend Creative security and MJ relay specs for safe-read origin policy and unsafe-method nonce semantics.

## Dynamic workflow evidence

- Initial final audit attempt timed out in broad branches:
  - `.codex-flow/generated/newapi-opentu-final-goal-attainment-review-2026-06-12.workflow.ts`
  - `.codex-flow/journal/newapi-opentu-final-goal-attainment-review-2026-06-12.jsonl`
- Successful mini final audit found remaining blockers:
  - `.codex-flow/generated/newapi-opentu-final-goal-attainment-mini-2026-06-12.workflow.ts`
  - `.codex-flow/journal/newapi-opentu-final-goal-attainment-mini-2026-06-12.jsonl`
- Postfix dynamic rechecks:
  - `.codex-flow/generated/newapi-opentu-postfix-blocker-recheck-2026-06-12.workflow.ts`
  - `.codex-flow/journal/newapi-opentu-postfix-blocker-recheck-2026-06-12.jsonl`
  - `.codex-flow/generated/newapi-opentu-postfix-blocker-recheck2-2026-06-12.workflow.ts`
  - `.codex-flow/journal/newapi-opentu-postfix-blocker-recheck2-2026-06-12.jsonl`
- Focused contract/docs dynamic rechecks:
  - `.codex-flow/generated/newapi-opentu-contract-docs-recheck-2026-06-12.workflow.ts`
  - `.codex-flow/journal/newapi-opentu-contract-docs-recheck-2026-06-12.jsonl`
  - `.codex-flow/generated/newapi-opentu-contract-docs-recheck2-2026-06-12.workflow.ts`
  - `.codex-flow/journal/newapi-opentu-contract-docs-recheck2-2026-06-12.jsonl`
- Final focused contract/docs recheck result: both branches `clear`, no remaining release blockers.

## Fresh verification commands

```bash
cd /mnt/f/code/project/opentu
pnpm --filter @aitu/drawnix exec vitest run \
  src/services/provider-routing/provider-transport.session-broker.test.ts \
  src/services/creative-session-broker.test.ts \
  src/services/__tests__/audio-api-service.test.ts \
  src/services/__tests__/video-api-service.session-broker.test.ts \
  src/services/__tests__/media-api-routing.test.ts \
  src/services/model-adapters/mj-image-adapter.test.ts \
  src/services/creative-document-assets.test.ts \
  src/services/creative-document-sync.test.ts \
  --no-file-parallelism --maxWorkers=1 --minWorkers=1
```

Result: exit 0; 8 files / 101 tests passed. Known local warnings: `${NPM_TOKEN}` placeholder, crypto fallback, and `indexedDB is not defined` in test environment.

```bash
cd /mnt/f/code/project/opentu
pnpm nx run drawnix:typecheck
```

Result: exit 0; `NX Successfully ran target typecheck for project drawnix`.

```bash
cd /mnt/f/code/project/new-api
go test -count=1 ./router ./middleware ./controller ./model ./service ./relay/...
```

Result: exit 0.

```bash
cd /mnt/f/code/project/opentu
node --check scripts/publish-npm.js
cd /mnt/f/code/project/new-api && git diff --check
cd /mnt/f/code/project/opentu && git diff --check
cd /mnt/f/code/project/new2fly && git diff --check
```

Result: all exit 0.

## Remaining caveats

- No production services, secrets, or provider endpoints were called.
- Full end-to-end browser/runtime verification with real Redis/S3/provider-like services remains a deployment-stage follow-up.
- CI/governance hardening such as full `go test ./...`, lint, race, and npm/CDN dry-run gates remains recommended but was not required to clear the confirmed release blockers in this pass.
