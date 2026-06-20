# Implementation plan — Creative Duomi / GrsAI live image adapter

## Preconditions

- Task must be reviewed and started with `task.py start` before code changes.
- Do not call live provider endpoints unless explicit credentials and authorization are provided for that stage.
- Keep OpenTU/browser provider credential-free.

## Ordered implementation checklist

### 1. Backend adapter foundations

- [x] Add provider-neutral Creative image adapter types and registry.
- [x] Add Duomi adapter submit/poll mapper/parser with fixture tests.
- [x] Add GrsAI adapter submit/poll mapper/parser with fixture tests for gpt-image-2 and nano-banana family.
- [x] Add sanitizer/redaction helpers for provider request preview, provider errors, and result URL metadata if existing helpers are insufficient.

### 2. Binding manifests, schemas, and validation

- [x] Change `duomi_image_live` / `grsai_image_live` manifests to supported live mode only after adapter tests exist.
- [x] Add/adjust parameter templates:
  - `duomi_gpt_image`
  - `grsai_gpt_image`
  - `grsai_nano_banana`
- [x] Update `creativeAdapterManifestCanBeSaved` / validation rules to allow known live presets only with locked valid channel and canary/enablement rules.
- [x] Keep `grsai_gpt_image_dryrun` offline-only and not user-executable.
- [x] Add tests for live binding save/enable success and failure cases: missing channel, disabled channel, provider model unsupported, invalid schema, forbidden params, unknown canary group.

### 3. Submit orchestration

- [x] Extend `ResolveCreativeImageModelBindingForGroup` or add a live resolver that returns adapter preset, channel id, final provider model, price model, and validated userParams.
- [x] Refactor `CreativeRelayImageTaskSubmit` to branch through a service:
  - mock path remains unchanged in behavior;
  - live path selects channel/key, bills/pre-consumes, submits provider, inserts pending/terminal task, completes idempotency, durably settles submit billing, and returns sanitized DTO.
- [x] Preserve idempotency deletion rule: delete only before provider accepted.
- [x] Add controller/service tests for replay, conflict, provider accepted + insert/finalize failures, and no duplicate provider call.

### 4. Poll/reconcile and content

- [x] Add a shared Creative image task poll/reconcile service used by fetch and future worker paths.
- [x] Require Creative tasks with idempotency to have stored `PrivateData.UpstreamTaskID` and `PrivateData.Key`; fail/refund closed if missing.
- [x] Map provider statuses to internal status/progress/fail reason.
- [x] Use `UpdateWithStatusAndBillingOutbox` for terminal transitions and process/leave retryable outbox.
- [x] Update content route to serve live result URL through safe server-side fetch/proxy or storage reference; keep mock PNG for mock tasks.
- [x] Add tests for owner/platform privacy, raw URL non-leakage, SSRF/redirect blocking where helper exists, and terminal settle/refund once.

### 5. Admin/frontend polish

- [x] Update Creative Model Bindings UI copy from “future blocked” to live-adapter status once backend manifests are live.
- [x] Add template/draft support for GrsAI nano-banana and Duomi/GrsAI live presets.
- [x] Ensure UI still consumes only `CreativeChannelSummary` and dedicated model-bindings endpoints.
- [x] Run frontend typecheck/lint for touched admin UI.

### 6. Validation

Backend targeted commands, adjusted if package paths differ:

```bash
cd /mnt/f/CODE/Project/new-api
go test -count=1 ./service ./controller ./model ./relay ./relay/common ./relay/constant
```

Frontend/admin targeted commands, adjusted to repo scripts:

```bash
cd /mnt/f/CODE/Project/new-api/web/default
pnpm typecheck
pnpm lint
```

Embedded/OpenTU validation if OpenTU code is touched:

```bash
cd /mnt/f/CODE/Project/opentu
pnpm typecheck
pnpm test -- --runInBand
```

Release/staging validation:

- [x] Run local disposable staging without provider credentials for catalog/schema/admin no-provider smoke.
- [x] Run browser smoke proving logged-in user sees model catalog and parameter panel.
- [ ] Live provider smoke only after explicit authorization and test keys; record provider cost risk and redact all output.

### 7. Dynamic workflow final audit

After implementation and staging checks pass, run a dynamic workflow / codex-flow audit with the goal:

> 使用动态工作流全面深度审查当前项目，主要是是否达成开发目标（当前目录是项目编排、项目代码具体在同级目录的new-api和opentu）,不要依赖于之前的报告

Rules:

- Audit goal is development-goal attainment and newly introduced problems, not just “修复完成”.
- If synthesis/verify is null, timed out, or incomplete, resume/split/retry; do not count as pass.
- Main session must verify material findings before deciding pass/fail.

## Risk points / rollback points

- Provider accepted before local persistence: idempotency guard must stay.
- Billing pre-consume/settle mismatch: do not ship until outbox tests cover success/failure/concurrency.
- Raw provider URL leak: DTO and logs must be checked by tests.
- Channel key/base URL exposure: admin UI must not switch to generic channel DTO.
- Enabling live manifests too early: keep blocked until adapter transport/parser/billing tests pass.
- Production deployment is a separate authorization gate.
