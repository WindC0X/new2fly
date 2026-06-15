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

1. [x] new-api: add versioned binding config parser and shared forbidden-key normalizer.
2. [x] new-api: add admin-only model-bindings validate/dry-run endpoints with CSRF/same-origin gates.
3. [x] new-api: block generic option write path for `creative.model_bindings`.
4. [ ] new-api: add dry-run redacted request preview for mock and GrsAI fixture-backed presets. _(Partial: mock-only redacted preview added; GrsAI fixture-backed preset remains blocked.)_
5. [x] new-api admin security tests: non-admin denied, API-token-only denied, missing/bad CSRF/nonce denied for writes/dry-run, generic option write blocked, PUT emits sanitized audit event.
6. [ ] new-api validator tests: duplicate id, unknown preset/template, wrong group/channel/modality, disabled channel, forbidden schema id, hidden user-submitted field, raw option bypass. _(Partial: duplicate id, unknown preset/template, wrong modality, invalid channel id, forbidden canary/schema/raw admin keys, sensitive provider/price values, null-shape rejection, and raw option bypass covered; disabled-channel lookup and hidden user-submitted-field handling remain future resolver work.)_
7. [x] shared normalizer matrix tests: same dangerous-key corpus across admin JSON, schema id, hidden fields, legacy params, relay JSON, query, form, multipart field names, multipart file-part names, and dry-run preview. _(Controller matrix now covers service normalizer/schema/admin/userParams/dry-run and relay JSON/query/form/multipart field/file paths with the same key corpus.)_
8. [x] fake-secret corpus tests: validator/dry-run/logs/diagnostics do not emit API keys, Authorization, baseURL secrets, signed URL query, base64, object keys, cookies, CSRF, nonce, or raw provider URLs. _(Validator/admin-state/dry-run diagnostics now reject/redact bearer/key-like values, provider URLs, signed URL markers, data/base64-like data, credential/token/access-key markers, cookie/CSRF/nonce markers, object-key markers, and admin response/log surfaces.)_
9. [ ] Provider fixtures: mark Duomi blocked; add GrsAI request/parser/redaction fixtures from local evidence only. _(Partial: Duomi/GrsAI live presets/templates explicitly fail closed; fixture-backed GrsAI parser/redaction remains pending local evidence.)_
10. [ ] No-provider-call gate: dry-run/fixture code uses mock transport or panic-on-provider-call test hooks; Phase B cannot reach Duomi/GrsAI network endpoints. _(Partial: current dry-run path has mock-only allowlists, Duomi/GrsAI configs reject, and AST regression gate forbids HTTP/client/channel/key/baseURL/provider endpoint references inside `BuildCreativeModelBindingsDryRun`; future fixture-backed code still needs its own panic transport/hook.)_

## Phase C1 — Mock Image Task Full Chain

No provider calls.

1. [x] new-api: add Creative image task submit/fetch route using mock upstream preset only. _(POST/GET/content routes added under `/creative/relay/v1/images/tasks`; submit uses only local mock task creation.)_
2. [x] new-api: add binding resolver before broker/distribute/pricing for image task route. _(Resolver validates `bindingId`, global flag, per-binding enabled state, canary group, image modality, and mock preset/template before task creation. The image task route intentionally does not enter broker/distribute.)_
3. [x] new-api: add explicit relay/task metadata for binding/provider/price/preset/template/channel/userParams. _(C1 mock task data stores versioned binding/provider/price/preset/template/channel/userParams metadata; public DTO uses a separate allowlist that omits channelId.)_
4. [x] new-api: make pricing use explicit price model, tested with distinct binding/provider/price ids. _(C1 mock task persists `BillingContext.OriginModelName=priceModelId` with distinct binding/provider/price ids and zero quota; real quota mutation remains C2+.)_
5. [x] new-api: add durable accepted-task recovery state/outbox or equivalent pending recovery record for provider/mock accepted followed by local failure. _(For C1 mock route, scoped idempotency is prepared before acceptance, retained on accepted local failures, and either replays the persisted task or returns a pending/conflict state without a second mock submit. Real provider billing outbox remains C2+.)_
6. [x] new-api: add owner-scoped private image task DTO; do not reuse generic TaskDto. _(Route-specific DTO omits user/channel/quota/private fields and fetch/content load by `user_id + task_id` plus `Platform==creative_image`.)_
7. [x] new-api: add mock private image URL sanitizer/proxy contract. _(Internal mock `ResultURL` is never returned; public result URL points to owner-scoped `/content` route returning no-store PNG.)_
8. [x] new-api sync-route privacy gate: schema-backed Creative adapter bindings are rejected/hidden/forced to task route until sync ImageHelper response interception/private rewrite exists; add negative test proving no sync adapter binding can expose raw provider URL/signed query to browser. _(Managed image binding IDs are rejected by `/images/generations` before broker/distribute/provider relay.)_
9. [x] new-api route-boundary tests: no session, API-token-only, cross-origin, missing/bad nonce, missing Idempotency-Key, JSON/query/form/multipart forbidden material all fail before mock/upstream call. _(Covered by image task route tests; header/query/form/file aliases assert no mock insert.)_
10. [x] new-api recovery/idempotency tests: accepted + insert fail, accepted + idempotency complete fail, accepted + settle fail all create durable recovery/pending state and never release guard; duplicate retry returns recoverable state/task and does not second-submit. _(C1 mock route covers accepted+insert failure, idempotency-complete failure, and accepted-finalize/settle-equivalent failure. Retries never insert a second task; insert failure returns pending/conflict and post-insert failures replay the persisted task.)_
11. [x] new-api task tests: double poller CAS, missing selected key fail-closed, fetch cross-user denied, DTO allowlist excludes generic TaskDto internals. _(C1 mock route is terminal/local and has no poller or selected-key fallback path. Tests cover cross-user denial, same-user wrong-platform denial, unmanaged task denial, and DTO allowlist excluding generic TaskDto internals.)_
12. [x] new-api kill-switch tests: disabled global/per-binding hides catalog, rejects submit, and prevents polling/cache from starting new managed provider/mock work. _(C1 mock route/catalog now cover global adapter off, per-binding disabled, wrong canary group, stored catalog hiding, and no poll/cache/provider startup path for managed image tasks.)_
13. [x] fake-secret corpus tests: submit/poll/fetch/logs/metrics/task DTO/Trellis artifacts/build outputs do not contain secret corpus. _(C1 mock route has no provider poll/log/metrics transport; tests cover private-data fake-secret corpus redaction on public task DTO/content surfaces, and current task/spec artifacts are grep-clean for the fake-secret corpus.)_
14. [x] No-provider-call gate: mock upstream is the only transport reachable in C1; any provider host call fails tests. _(Image task route is not wired through broker/distribute, tests install fatal relay handlers, and a source gate rejects provider transport/channel/key/baseURL references in the C1 controller.)_

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
