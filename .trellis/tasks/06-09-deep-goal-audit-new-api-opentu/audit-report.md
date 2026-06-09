# Audit Report: new-api + opentu 开发目标达成度审查

生成时间：2026-06-09  
任务：`.trellis/tasks/06-09-deep-goal-audit-new-api-opentu`  
审查范围：`../new-api`、`../opentu` 当前本地 working tree（含未提交改动）  
动态工作流：`.codex-flow/generated/deep-goal-audit-new-api-opentu.workflow.ts`  
工作流日志：`.codex-flow/journal/deep-goal-audit-new-api-opentu.jsonl`  
结构化摘要：`workflow-synthesis.json`

## 1. Executive Verdict

**总体结论：partial（未达成完整开发目标）**。

当前实现已经完成了一部分基础设施：

- `new-api` 已有 `/creative/` 同源静态挂载、SPA fallback、`/creative/api` 与 `/creative/relay` 分流框架。
- `new-api` 侧边栏已有 Creative Workspace 入口。
- `new-api` 已有 `CreativeBootstrap`、session-broker 风格的 CSRF/nonce、forbidden relay fields 拒绝逻辑。
- `new-api` tokenless / playground 计费路径已有单元测试支撑。
- `opentu` 已有 `new-api-creative` session-broker profile、密钥剥离 transport、document sync 相关源码与目标单测。

但几个核心目标仍未完成或不能验收：

1. **生产嵌入 dist 过期且与测试夹具不一致**。
2. **OpenAI-compatible image 最小链路没有挂到 `/creative/relay/v1/images/generations`**。
3. **video/Suno/MJ creative relay 与异步幂等安全未完成**。
4. **返回控制台按钮缺失**。
5. **资产二进制云同步未实现，当前只有文档 JSON 快照类同步**。
6. **embedded 模式没有强制 new-api 作为唯一 provider gateway，仍有 legacy/direct provider 路径**。
7. **Opentu `tsconfig.spec.json` typecheck 失败；完整 build/full test/E2E 未验证**。

## 2. Completion Matrix

| 目标 | 状态 | 证据摘要 |
|---|---:|---|
| `/creative/` 同源静态 serving / SPA fallback / API 与 relay 隔离 | partial | `new-api/router/web-router.go:84-135` 已实现框架；但 `main.go` 嵌入 `web/creative/dist`，测试使用 `router/web/creative/dist`，两者产物不一致。 |
| new-api 导航进入 Creative Workspace | partial | `use-sidebar-data.ts` 有 `url='/creative/'` + `isExternal=true`；但 `command-menu.tsx` 仍用 Router `navigate()`，未处理 external。 |
| Opentu base path / 静态资源 / SW 隔离 | partial | `opentu/apps/web/vite.config.ts` 支持 `VITE_BASE_URL`；主入口 `main.tsx` 用 `./sw.js`；但 public home 页面仍有 `register('/sw.js')`，深链相对路径和缓存仍有风险。 |
| 生产嵌入 dist 与当前 opentu 构建一致 | not_done | `opentu/dist/apps/web/version.json` buildTime `2026-06-08T17:30:07.747Z`；`new-api/web/creative/dist/version.json` buildTime `2026-06-07T23:46:42.001Z`。 |
| session-cookie + tokenless、不暴露长期 API key 基础 | partial | `controller/creative.go` 返回 session-broker auth/csrf/nonce，并拒绝 `Authorization`、`apiKey`、`baseUrl` 等字段；但 embedded 全面禁用 direct key 尚未完成。 |
| new-api 作为唯一 Creative Gateway/provider gateway | partial | `creative-session-broker.ts` 有 `new-api-creative` profile；但 `settings-manager.ts`、`runtime-model-discovery.ts` 仍会注入/合并 legacy/static/direct providers。 |
| OpenAI-compatible image 通过 new-api relay | not_done | Opentu image path 是 `/images/generations`，base 是 `/creative/relay/v1`；new-api creative relay 只注册 `/chat/completions`。 |
| video/Suno/MJ 通过 new-api relay 且幂等安全 | not_done | 未发现 `/creative/relay/v1/videos`、`/suno/*`、`/mj/*`；异步提交缺 reservation/idempotency，Suno 退款分支无 CAS。 |
| tokenless billing 使用用户钱包且避免 token quota | partial | chat/session 单元路径较好：`relay_info.go` 标记 `IsPlayground`，`quota.go` 跳过 token quota，`creative_billing_test.go` 覆盖钱包/订阅/并发退款；image/async 不可用。 |
| 资产/文档云同步、二进制资产、lazy download、删除与配额 | not_done | new-api 仅有 `CreativeDocument` 快照/元数据与 `/creative/api/documents`；Opentu Blob 仍在浏览器 Cache API/IndexedDB。 |
| 返回控制台按钮 | not_done | `opentu/apps/web/src/components/ReturnButton.tsx` 与 `apps/web/src/utils/embed-detection.ts` 不存在；源码和 dist 搜不到 `返回控制台`/`ReturnButton`。 |
| 测试/静态验证 | partial | 目标 Go 包测试通过；Opentu 10 个目标 Vitest 文件在 `packages/drawnix` cwd 下通过；`tsc -p tsconfig.spec.json --noEmit` 失败；完整 build/full test/E2E 未跑。 |

## 3. Critical Gaps

### G1. 生产 Creative dist 过期且测试夹具不一致（critical / not_done）

- `new-api/main.go` 嵌入：`web/creative/dist`。
- `new-api/router/web_router_test.go` 使用：`router/web/creative/dist`。
- `opentu/dist/apps/web/version.json` 与 `new-api/router/web/creative/dist/version.json` buildTime 是 `2026-06-08T17:30:07.747Z`。
- `new-api/web/creative/dist/version.json` buildTime 是 `2026-06-07T23:46:42.001Z`。

影响：测试可能验证了新产物，但实际 Go embed 使用旧产物；源码中已有的 session-broker/document-sync 变化可能没有进入生产嵌入包。

### G2. image 最小可用链路未挂载（critical / not_done）

- Opentu image 请求：`providerTransport.send(... path: '/images/generations')`。
- Creative mode base：`/creative/relay/v1`。
- new-api creative relay：只注册 `POST /creative/relay/v1/chat/completions`。
- `/creative/relay/v1/images/generations` 会落到 `RelayNotFound`。

影响：Phase 2.1 的核心验收“OpenAI-compatible image 单链路”未达成。

### G3. async video/Suno/MJ 与幂等/退款/channel-affinity 未完成（high / not_done）

- 未发现 creative relay 下 video/Suno/MJ route。
- `relay_task.go` / `controller/relay.go` 仍是成功响应后才插入 task，缺提交前 reservation/idempotency。
- `service/task_polling.go` Suno 失败分支直接 `RefundTaskQuota` 后 `task.Update()`，未用 CAS。
- `TaskPrivateData` 未保存 multi-key index/hash，exact-key 亲和不足。

### G4. 返回控制台按钮缺失（high / not_done）

06-08 任务要求 `/creative` 嵌入模式显示“← 返回控制台”，点击跳回 `/dashboard`。当前未发现源码组件、utility 或产物文案。

### G5. 资产二进制云同步未实现（high / not_done）

当前 `CreativeDocument` 更接近画布/文档 JSON 快照同步；没有实现素材二进制 metadata + binary 云同步、contentHash、本地磁盘对象存储、lazy download、tombstone、配额/速率限制等目标。

### G6. embedded 模式未强制唯一 new-api gateway（high / partial）

已有 session-broker profile 和密钥剥离 transport，但仍存在 legacy/static/direct providers 的选择/注入路径，部分 UI 或服务仍可能要求/使用 API key。该问题会影响统一计费、日志、渠道容灾与合规边界。

### G7. Opentu spec typecheck 失败（medium / not_done）

`packages/drawnix` 下运行：

```bash
TMPDIR=/dev/shm pnpm exec tsc -p tsconfig.spec.json --noEmit
```

结果：exit code 2。错误包含既有测试类型债务，也包含本次新增/修改的 creative document sync / session broker / status hook / model selection 测试类型问题。

## 4. Dynamic Workflow Branch Summary

| Branch | 主题 | 结论 |
|---|---|---|
| B1 | 目标基线重构 | done：基线来自 06-07 / 06-08 Trellis 文档、product decisions、AGENTS/OpenSpec/docs。 |
| B2 | new-api embed / routing / navigation | partial：路由框架可用；dist、cache/SW、command-menu 有缺口。 |
| B3 | new-api auth / billing / async safety | partial：chat session-broker 与 tokenless billing 基础较好；image/async 与幂等未完成。 |
| B4 | opentu embedded runtime / SW / return button | partial/not_done：base path 有进展；return button 缺失；SW/root URL 风险仍在。 |
| B5 | opentu provider gateway / model routing | partial：new-api profile 存在；未强制唯一 gateway。 |
| B6 | cloud sync / storage safety | partial/not_done：document sync 有源码；资产二进制云同步没有。 |
| B7 | verification / tests / build evidence | partial：目标子集测试通过，typecheck 失败，完整 gates 未跑。 |
| B8 | adversarial cross-check | partial：确认 stale dist、relay 缺口、return button、direct provider、asset sync 等关键差距。 |
| B9 | synthesis | partial：汇总结论为未达成完整开发目标。 |

## 5. Coordinator Verification Commands

已由主会话额外复核的命令：

```bash
# 状态：两个代码仓均在 feat/creative-embed 且有未提交变更
git -C ../new-api status --short --branch
git -C ../opentu status --short --branch

# new-api 目标 Go 包测试：通过
TMPDIR=/dev/shm GOCACHE=/dev/shm/new-api-gocache GOTMPDIR=/dev/shm \
  go test ./controller ./middleware ./model ./relay/common ./relay/constant ./router ./service

# opentu 目标 Vitest 子集：在 packages/drawnix cwd 下通过，10 files / 56 tests
cd ../opentu/packages/drawnix
TMPDIR=/dev/shm pnpm exec vitest run \
  src/components/ai-input-bar/ModelDropdown.test.tsx \
  src/components/ai-input-bar/ModelSelector.test.tsx \
  src/utils/__tests__/ai-model-selection-storage.test.ts \
  src/hooks/use-creative-document-sync-status.test.tsx \
  src/services/creative-display-policy.test.ts \
  src/services/creative-document-sync.test.ts \
  src/services/creative-model-preference-sync.test.ts \
  src/services/creative-session-broker.test.ts \
  src/services/provider-routing/provider-transport.session-broker.test.ts \
  src/utils/gemini-api/auth.creative-embedded.test.ts

# opentu spec typecheck：失败
TMPDIR=/dev/shm pnpm exec tsc -p tsconfig.spec.json --noEmit
```

备注：从 `opentu` 根目录直接跑同一批 Vitest 会因测试环境缺少 `window/document/localStorage` 而失败；从 `packages/drawnix` 包目录运行时使用正确 Vitest 配置并通过。

## 6. Recommended Next Steps

建议按阻断顺序推进：

1. **先修 dist 一致性**：统一 opentu 构建输出、`new-api/web/creative/dist`、`new-api/router/web/creative/dist` 测试夹具；增加 hash/buildTime 一致性检查。
2. **补 image relay**：注册 `/creative/relay/v1/images/generations`，接入 session-broker、nonce、forbidden fields、Distribute、RelayMode、billing 和日志。
3. **补 video/Suno/MJ 与异步硬化**：新增 route；加提交前 idempotency reservation；Suno 退款改 CAS；持久化 multi-key exact-key 亲和信息。
4. **实现返回控制台按钮**：按 06-08 任务创建 embedded-only `ReturnButton`，跳转 `/dashboard`，并同步构建产物。
5. **强制 embedded 唯一 gateway**：在 `isCreativeEmbeddedMode()` 下只暴露 `new-api-creative` profile，禁用 legacy/direct key path 和 `promptForApiKey`。
6. **明确并实现资产同步范围**：若目标是素材资产云同步，需要补 `creative_assets` 模型/迁移、二进制上传下载、本地盘后端、lazy download、tombstone、用户隔离和配额策略。
7. **修 typecheck 并补完整 gates**：修复 `packages/drawnix` spec typecheck；再跑完整 new-api Go/front-end、opentu typecheck/lint/test/build，以及 `/creative` browser smoke/E2E。

## 7. Final Status

当前项目**不能判定为达成开发目标**。更准确地说：

- **Phase 0.5 embed skeleton：partial**。
- **Phase 2.1 image 最小可用交付：not_done**。
- **Phase 3 async 容灾/幂等：not_done**。
- **Phase 4 资产云同步：not_done**。
- **返回控制台按钮：not_done**。
- **测试质量门：partial / blocked_unverified**。

