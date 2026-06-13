# Implementation Plan — Creative frontend session broker and asset sync hardening

## Steps

1. Add failing audio session-broker tests for top-level/nested notify/callback/webhook stripping.
2. Implement whitelist payload construction for Suno lyrics/music session-broker bodies.
3. Add failing asset sync tests for generated image/video and poster/cover/clips field variants.
4. Extend virtual media recognition and URL field/array discovery.
5. Add hydrate no-cloud-ref unsafe URL test and move sanitizer before early return.
6. Add video unsupported raw-body sanitization tests and fix submit/status/content handling.
7. Add provider transport missing CSRF/nonce fail-fast tests and implementation.
8. Run targeted Vitest suites.

## Validation

```bash
cd /mnt/f/code/project/opentu
pnpm exec vitest run \
  packages/drawnix/src/services/__tests__/audio-api-service.test.ts \
  packages/drawnix/src/services/creative-document-assets.test.ts \
  packages/drawnix/src/services/__tests__/video-api-service.session-broker.test.ts \
  packages/drawnix/src/services/provider-routing/provider-transport.session-broker.test.ts \
  --no-file-parallelism --maxWorkers=1 --minWorkers=1
```

## Dynamic Workflow Check Branch

Parent post-fix workflow branch `frontend-session-assets-review` must independently inspect H7/H8/H9/M7/M8 coverage and report any remaining local/signed URL persistence path.
