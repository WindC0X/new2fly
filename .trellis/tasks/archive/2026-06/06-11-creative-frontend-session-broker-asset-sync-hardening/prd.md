# Creative frontend session broker and asset sync hardening

## Goal

Fix Opentu frontend Creative session-broker and asset sync contract violations in `../opentu` before release.

## Source Findings

- Codex H7: asset URL discovery misses generated image/video and nested poster/cover/clips string arrays.
- Codex H8: hydrate returns early when no cloud asset ref exists, bypassing unsafe URL sanitizer.
- Codex H9: Suno lyrics session-broker forwards `notifyHook` / `notify_hook` to backend/upstream.
- Codex M7: video session-broker unsupported errors read/log raw response body before sanitizing.
- Codex M8: missing CSRF/nonce does not locally fail-fast before unsafe session-broker requests.
- Claude arbitration confirms H7/H8/H9 and keeps M7/M8 as hardening.

## Requirements

- Session-broker audio/Suno request bodies must be whitelist-built and must not include notify/callback/webhook material from top-level or nested params.
- Asset prepare must detect local media URL candidates in all required fields and arrays, including generated image/video virtual URLs, `posterUrl`, `posters`, `cover`, `covers`, and clips structures.
- Hydration/import must run unsafe URL sanitizer even if the payload contains no `/creative/api/assets/*/content` refs.
- Unsupported backend `404/405/501` handling must throw sanitized errors before reading/logging response body.
- Unsafe session-broker methods must fail locally when required Creative CSRF/nonce material is missing.

## Acceptance Criteria

- [ ] Vitest proves Suno lyrics/music session-broker does not send `notifyHook`, `notify_hook`, `callback`, or `webhook` from top-level or nested params.
- [ ] Vitest proves generated image/video URLs and poster/cover/clips fields upload or fail closed.
- [ ] Vitest proves remote payload with only signed/object-storage URL and no cloud ref is rejected during hydrate/import.
- [ ] Vitest proves video submit/status/content unsupported responses do not expose raw body or log credentials.
- [ ] Provider transport tests prove missing nonce/CSRF for unsafe session-broker request fails before fetch.
