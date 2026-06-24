# Runtime lifecycle v8b fix result — 2026-06-22

## Scope

Fixes applied after main-session arbitration of the v8/v8b dynamic workflow findings. This is a patch result record, not the final audit.

## Fixed in OpenTU

1. Managed Creative image resume writeback now uses the same retry-attempt/start/remote-id guard as ordinary execution.
   - Regression: `useTaskExecutor.test.ts` stale managed resume completion cannot overwrite a newer retry attempt.
2. Prompt History failed previews now pass through the shared Creative error sanitizer.
   - Safe provider rejection text remains visible.
   - URLs/Authorization/Bearer/token material falls back to a generic safe message.
3. Frontend Creative error sanitizer was narrowed.
   - Removed broad `provider/upstream/channel` matches that hid actionable safe errors.
   - Kept URL, credential, callback/webhook/notify hook, signature, object/bucket style material blocked.
4. `TaskItem` memo comparator now includes rendered `error.details.originalError`.
5. Media-library toolbar image insertion now calls a shared generated-image cache readiness helper before inserting generated cache URLs.
6. Selected-image metadata propagation was extended.
   - Selection extraction preserves `contentUrl`, `remoteTaskId`, `providerTaskId`, `mimeType` from canvas image nodes.
   - AI input selected content forwards those fields to preview/reference preparation.
7. Generated image canvas insertion now has a small metadata whitelist helper and passes generated image rehydrate metadata through quick image insertion paths.
8. Editing Creative image tasks now centralizes editable parameter merge and lets schema-backed `userParams` override stale top-level legacy fields.

## Fixed in NewAPI

1. GrsAI nano-banana aspect-ratio validation is now provider-model aware.
   - Common nano/pro models accept the common ratio set up to `21:9`.
   - `nano-banana-2*` models additionally accept `1:4`, `4:1`, `1:8`, `8:1`.
2. Channel lookup errors now have explicit not-found classification.
   - Missing memory-cache channels wrap `ErrChannelNotFound`.
   - `gorm.ErrRecordNotFound` is classified as not-found.
   - Creative image polling/fetch paths no longer terminal-fail tasks for non-not-found lookup errors; transient errors are returned/deferred.

## Explicit unresolved item

- Ambiguous provider submit late-success remains a design gap. The safe fix needs provider-supported idempotency/query-by-client-id or a product decision for explicit recovery-needed/cancel semantics. Blind re-submit was intentionally not implemented because it can double-submit provider jobs.

## Verification run

OpenTU targeted regression tests:

```bash
pnpm vitest run --no-file-parallelism --maxWorkers=1 --minWorkers=1 \
  packages/drawnix/src/hooks/__tests__/useTaskExecutor.test.ts \
  packages/drawnix/src/services/creative-error-sanitizer.test.ts \
  packages/drawnix/src/services/prompt-history-service.test.ts \
  packages/drawnix/src/utils/__tests__/media-library-image-insert.test.ts \
  packages/drawnix/src/utils/__tests__/generated-image-canvas-metadata.test.ts \
  packages/drawnix/src/utils/__tests__/selection-utils-generated-metadata.test.ts \
  packages/drawnix/src/components/ttd-dialog/creative-image-task-params.test.ts \
  packages/drawnix/src/components/task-queue/TaskItem.memo.test.ts
```

Result: 8 files / 29 tests passed.

OpenTU type checks:

```bash
pnpm nx run drawnix:typecheck
pnpm nx run web:typecheck
```

Result: both passed.

NewAPI targeted tests:

```bash
go test -count=1 ./model -run 'TestChannelNotFoundErrorClassification|TestCacheGetChannelMissingMemoryCacheIsClassifiedNotFound'
go test -count=1 ./service -run 'TestCreativeLiveBindingRejectsUnsupportedNanoBananaAllowedValues|TestCreativeLiveBindingRejectsUnsupportedDuomiAllowedValues'
go test -count=1 ./controller -run 'TestCreativeImageTask|TestCreativeRelayImage'
```

Result: all passed.

Broader NewAPI check:

```bash
go test -count=1 ./model ./service ./controller
```

Result: `./model` and `./service` passed; `./controller` still has an existing unrelated failure in `TestCreativeRelayMJImageFallbackClientBlocksUnsafeRedirect` expecting 500 but receiving 502. This is outside the files changed in this patch and should be handled separately or re-baselined if expected behavior changed earlier.

Whitespace gate:

```bash
git diff --check
```

Result: passed for `new-api` and `opentu`.
