# Implementation Plan — Creative Adapter Capability Registry

## Phase 0 — Planning and Review

- [x] Archive completed origin hotfix task.
- [x] Create follow-up Trellis task for Creative Adapter Capability Registry.
- [x] Capture v2 plan and v2 codex-flow audit report.
- [x] Write v3 PRD/design/implementation artifacts.
- [x] Run codex-flow v3 short audit.
- [x] First v3 codex-flow short audit found planning-level Critical/High blockers; update design/implement before coding.
- [x] Run revised v3.1/v3.1.2 codex-flow gate audit and require no Critical/High Phase A/B/C1 blockers before coding.

## Phase A — Contract and Schema Preview Only

No provider calls.

1. [x] new-api: add frozen Go/JSON `CreativeParameterSchemaItem` contract with typed defaults/options, `enum|string|number|integer|boolean`, order, hidden, validation, and tests.
2. [x] new-api: add mock binding/template service behind disabled global flag and canary filter.
3. [x] new-api tests: binding id, provider id, and price id are distinct and preserved through bootstrap catalog.
4. [x] OpenTU: add matching TypeScript `CreativeParameterSchemaItem` contract and schema-to-runtime-param conversion tests.
5. [x] OpenTU: preserve runtime `providerModelId` and `parameterSchema` in creative session broker/runtime catalog.
6. [x] OpenTU: add schema-to-UI conversion for enum/string/number/integer/boolean with typed default/options and cast tests.
7. [x] OpenTU: make runtime schema override static `model-config` params.
8. [x] OpenTU: introduce explicit typed `userParams` carrier through parsed params, workflow args, generation service, and adapter request boundaries; cut schema-backed models off from legacy `params`透传.
9. [x] OpenTU: disable legacy size/aspect/duration rewrite for schema-backed models unless server derives provider fields.
10. [x] OpenTU negative tests: serialized schema-backed request contains `model=bindingId` and typed `userParams` only; does not contain onProgress/onSubmitted/idempotencyKey/modelRef/sourceProfileId/provider/channel/callback/webhook/headers/control URLs.
11. [x] OpenTU preference tests: two bindings sharing one provider model keep separate parameters/preferences; A→B→A does not fallback B to A params; B defaults come from B schema.

## Phase B — Admin Validator and Dry-Run Only

No provider calls.

1. [ ] new-api: add versioned binding config parser and shared forbidden-key normalizer.
2. [ ] new-api: add admin-only model-bindings validate/dry-run endpoints with CSRF/same-origin gates.
3. [ ] new-api: block generic option write path for `creative.model_bindings`.
4. [ ] new-api: add dry-run redacted request preview for mock and GrsAI fixture-backed presets.
5. [ ] new-api admin security tests: non-admin denied, API-token-only denied, missing/bad CSRF/nonce denied for writes/dry-run, generic option write blocked, PUT emits sanitized audit event.
6. [ ] new-api validator tests: duplicate id, unknown preset/template, wrong group/channel/modality, disabled channel, forbidden schema id, hidden user-submitted field, raw option bypass.
7. [ ] shared normalizer matrix tests: same dangerous-key corpus across admin JSON, schema id, hidden fields, legacy params, relay JSON, query, form, multipart field names, multipart file-part names, and dry-run preview.
8. [ ] fake-secret corpus tests: validator/dry-run/logs/diagnostics do not emit API keys, Authorization, baseURL secrets, signed URL query, base64, object keys, cookies, CSRF, nonce, or raw provider URLs.
9. [ ] Provider fixtures: mark Duomi blocked; add GrsAI request/parser/redaction fixtures from local evidence only.
10. [ ] No-provider-call gate: dry-run/fixture code uses mock transport or panic-on-provider-call test hooks; Phase B cannot reach Duomi/GrsAI network endpoints.

## Phase C1 — Mock Image Task Full Chain

No provider calls.

1. [ ] new-api: add Creative image task submit/fetch route using mock upstream preset only.
2. [ ] new-api: add binding resolver before broker/distribute/pricing for image task route.
3. [ ] new-api: add explicit relay/task metadata for binding/provider/price/preset/template/channel/userParams.
4. [ ] new-api: make pricing use explicit price model, tested with distinct binding/provider/price ids.
5. [ ] new-api: add durable accepted-task recovery state/outbox or equivalent pending recovery record for provider/mock accepted followed by local failure.
6. [ ] new-api: add owner-scoped private image task DTO; do not reuse generic TaskDto.
7. [ ] new-api: add mock private image URL sanitizer/proxy contract.
8. [ ] new-api sync-route privacy gate: schema-backed Creative adapter bindings are rejected/hidden/forced to task route until sync ImageHelper response interception/private rewrite exists; add negative test proving no sync adapter binding can expose raw provider URL/signed query to browser.
9. [ ] new-api route-boundary tests: no session, API-token-only, cross-origin, missing/bad nonce, missing Idempotency-Key, JSON/query/form/multipart forbidden material all fail before mock/upstream call.
10. [ ] new-api recovery/idempotency tests: accepted + insert fail, accepted + idempotency complete fail, accepted + settle fail all create durable recovery/pending state and never release guard; duplicate retry returns recoverable state/task and does not second-submit.
11. [ ] new-api task tests: double poller CAS, missing selected key fail-closed, fetch cross-user denied, DTO allowlist excludes generic TaskDto internals.
12. [ ] new-api kill-switch tests: disabled global/per-binding hides catalog, rejects submit, and prevents polling/cache from starting new managed provider/mock work.
13. [ ] fake-secret corpus tests: submit/poll/fetch/logs/metrics/task DTO/Trellis artifacts/build outputs do not contain secret corpus.
14. [ ] No-provider-call gate: mock upstream is the only transport reachable in C1; any provider host call fails tests.

## Phase C2+ — Real Provider Canary

Blocked until explicit authorization.

- [ ] Select one preset and one canary group/user.
- [ ] Confirm fixture coverage and test key/quota cap.
- [ ] Run kill switch and rollback rehearsal.
- [ ] Record no-secret evidence.
- [ ] Only then enable real provider call.

## Verification Commands Placeholder

Exact commands will be filled after implementation files exist. Minimum expected gates:

```bash
# new-api
cd /mnt/f/code/project/new-api
go test -count=1 ./controller ./middleware ./service ./relay/...
go build ./...

# OpenTU
cd /mnt/f/code/project/opentu
pnpm test -- --run
pnpm typecheck

# release/no-provider gate
cd /mnt/f/code/project/new2fly
python3 scripts/creative_release_gate.py check --source-diff-check --run-new-api-tests
```
