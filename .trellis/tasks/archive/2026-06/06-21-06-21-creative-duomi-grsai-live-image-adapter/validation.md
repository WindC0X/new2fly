# Validation record — Creative Duomi / GrsAI live image adapter

Date: 2026-06-21

## Static / unit verification

Repository: `/mnt/f/CODE/Project/new-api`

```bash
go test -count=1 ./service ./controller ./model ./relay ./relay/common ./relay/constant
```

Result:

```text
ok  github.com/QuantumNous/new-api/service
ok  github.com/QuantumNous/new-api/controller
ok  github.com/QuantumNous/new-api/model
ok  github.com/QuantumNous/new-api/relay
ok  github.com/QuantumNous/new-api/relay/common
ok  github.com/QuantumNous/new-api/relay/constant
```

Frontend repository: `/mnt/f/CODE/Project/new-api/web/default`

```bash
pnpm typecheck
pnpm exec eslint src/features/system-settings/models/creative-model-bindings-section.tsx
```

Result: exit code 0.

Note: full repository `pnpm lint` was not claimed; earlier runs have unrelated legacy failures outside this task's touched admin UI.

## Dynamic workflow final audit

Workflows run under `/mnt/f/code/project/new2fly`:

- `.codex-flow/generated/creative-duomi-grsai-goal-audit-v4.workflow.ts`
  - Branches completed; synthesis failed.
  - Material findings were manually verified in the main session and fixed: submit billing stats/logging, endpoint affinity, stored config drift, multi-key readiness side effect, SVG result denial, GrsAI VIP schema, parser fixture coverage.
- `.codex-flow/generated/creative-duomi-grsai-goal-audit-v5.workflow.ts`
  - Branches completed; synthesis failed.
- `.codex-flow/generated/creative-duomi-grsai-goal-audit-v5-synthesis-only.workflow.ts`
  - Synthesis completed.
  - Verdict: `pass_with_risks`.
  - `goalMet: true`.
  - `mustFix: []`.

Remaining non-blocking risks from synthesis:

- MEDIUM: task billing outbox log/stat/used_quota/channel_used_quota is not fully crash-safe exactly-once. This is not a balance double-charge blocker for this release gate, but should be accepted explicitly or hardened before high-volume production rollout.
- Production enablement still needs canary/kill-switch/live-provider smoke gate.

## Local disposable staging smoke

Temporary local staging:

- Base URL: `http://127.0.0.1:31888`
- Temporary DB: `/tmp/newapi-creative-smoke-*/smoke.db`
- No production env/provider credentials loaded.
- Root smoke user: `root` / `12345678` in the temporary DB only.

Executed no-provider API smoke:

1. Enabled temporary options:
   - `creative.adapter.enabled=true`
   - `creative.mock_image_tasks.enabled=true`
   - `creative.adapter.canary_groups=default`
2. `GET /creative/api/bootstrap`
   - HTTP 200
   - `Cache-Control: private, no-store`
   - returned session-broker auth material.
3. `POST /api/creative/model-bindings/validate`
   - HTTP 200
   - `valid: true`
4. `POST /api/creative/model-bindings/dry-run`
   - HTTP 200
   - `noProviderCall: true`
   - `transport: mock`
5. `PUT /api/creative/model-bindings`
   - HTTP 200
   - dedicated nonce/session-protected endpoint accepted the config.
6. `GET /creative/api/models`
   - HTTP 200
   - returned model `mock:gpt-image-2:preview`
   - `parameterSchema` contained `size` and `quality` with label `质量`.
7. `POST /creative/relay/v1/images/tasks`
   - HTTP 202
   - model `mock:gpt-image-2:preview`
   - result URL is local `/creative/relay/v1/images/tasks/<task_id>/content`
   - response did not expose `channelId` or quota/private provider fields.
8. Same-origin `GET /creative/relay/v1/images/tasks/<task_id>`
   - HTTP 200
   - status `completed`
   - no `channelId`/quota leakage.
9. Same-origin `GET /creative/relay/v1/images/tasks/<task_id>/content`
   - HTTP 200
   - `Content-Type: image/png`
   - PNG signature `89504e470d0a1a0a`.

Browser smoke with Python Playwright:

- Logged in through the temporary root account.
- Opened `/creative`.
- Browser URL: `http://127.0.0.1:31888/creative/?board=...`.
- Page title: `New API Creative - 我的画板1`.
- In-browser `/creative/api/bootstrap` returned:
  - `modelCount: 1`
  - `modelId: mock:gpt-image-2:preview`
  - `schemaIds: [size, quality]`
  - `schemaLabels: [Size, 质量]`
- Page body sample included the selected short label and parameter text: `mgi2`, `1024×1024, Standard`.

## Not executed

- Real Duomi/GrsAI live provider smoke was intentionally not executed. It requires explicit authorization, real test keys, and acceptance of provider cost/output risk.
- Existing production/staging data was not mutated by this local disposable smoke.
