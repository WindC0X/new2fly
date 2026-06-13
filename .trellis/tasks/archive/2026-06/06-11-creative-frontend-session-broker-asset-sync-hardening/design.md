# Design — Creative frontend session broker and asset sync hardening

## Affected Areas

- `../opentu/packages/drawnix/src/services/audio-api-service.ts`
- `../opentu/packages/drawnix/src/services/generation-api-service.ts`
- `../opentu/packages/drawnix/src/services/provider-routing/provider-transport.ts`
- `../opentu/packages/drawnix/src/services/creative-document-assets.ts`
- `../opentu/packages/drawnix/src/services/video-api-service.ts`
- related Vitest suites.

## Session-Broker Request Design

For session-broker mode, build request payloads from explicit allowlists. Drop callback/notify/webhook/routing/provider material rather than passing through nested `params` wholesale. Backend remains the final defense, but frontend must avoid emitting known-forbidden material.

## Asset Discovery Design

There are two complementary detection layers:

1. Field/key-based rewriting for known required media fields.
2. Value-based local media detection for virtual/local media URL patterns in nested media structures when field names are known to contain media lists.

Extend virtual media support from generated audio only to generated image/video/audio, or generalize `isAIGeneratedVirtualUrl` to all `/__aitu_generated__/` media subpaths.

## Hydration Sanitizer Design

Hydration should always run `assertNoUnsafeRemoteUrls(copy)` before any early return. Then, if no cloud refs exist, return the sanitized copy. This preserves safe payloads but blocks signed/bucket/credential URLs even without cloud asset refs.

## Error/Nonce Design

- For session-broker unsupported statuses, check status first and throw sanitized unsupported errors without consuming body.
- For unsafe methods in session-broker auth, require Creative auth material before fetch.
