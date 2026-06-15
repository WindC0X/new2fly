# Implementation Plan — Creative Reverse-Proxy Origin Hotfix

## Phase 1 — Planning

- [x] Create task from user-confirmed production bug.
- [x] Capture production symptom and hypothesis.
- [x] Define test/security requirements.
- [x] Start task before code changes.

## Phase 2 — Code Fix

1. [x] Edit `/mnt/f/code/project/new-api/middleware/creative.go`:
   - add proxy scheme parser for `Forwarded` and `X-Forwarded-Proto`;
   - keep `Request.Host` as host source;
   - only accept `http`/`https` schemes.
2. [x] Add/extend tests under `/mnt/f/code/project/new-api/middleware` or existing Creative controller tests:
   - reverse proxy HTTPS referer accepted;
   - reverse proxy HTTPS origin accepted;
   - mismatched origin rejected;
   - no proxy header fallback remains current behavior.
3. [x] Run targeted Go tests.
4. [x] Run release gate or at minimum `go test`/`go build` before deployment.

## Phase 3 — Deploy Hotfix

1. [x] Build candidate image from `/mnt/f/code/project/new-api`.
2. [x] Record local image ID.
3. [x] Stream-load image to VPS-A and verify remote image ID.
4. [x] Update compose image from `new-api-creative-embed:bfef310-prod` to hotfix tag.
5. [x] Restart production container.

## Phase 4 — Verify

1. [x] Existing baseline:
   - `https://api.se7endot.top/v1/models -> 401`
   - `https://console.se7endot.top/login -> 200`
2. [x] Unauthenticated `/creative/api/bootstrap -> 401`.
3. [x] Route/header assertion still passes.
4. [ ] Ask user/browser to re-run sanitized bootstrap console snippet or use a safe authenticated smoke flow if credentials are provided without logging secrets.
5. [ ] Confirm model dropdown has text models.

## Phase 5 — Finish

- [x] Record sanitized check evidence.
- [x] Commit `new-api` code change (`21f675f`).
- [x] Commit/record Trellis task in `new2fly` (`91f8c61`, pushed to `WindC0X/new2fly`).
- [ ] Archive and journal.
- [x] Push `new-api` `feat/creative-embed` to fork with host credentials (`WindC0X/new-api`, `21f675f`).
