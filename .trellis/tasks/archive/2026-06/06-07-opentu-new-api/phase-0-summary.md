# Phase 0 完成总结

## 交付物

- **new-api `feat/creative-embed`** @ `d268466`: `/creative/` 静态挂载 + 显式路由 + SW no-cache + 目录防护 + relay 保留 + HEAD/OPTIONS 支持
- **opentu `feat/creative-embed`** @ `bf44d14`: 干净分支(dist 已验证可构建)
- **评估报告**: `.trellis/tasks/06-07-opentu-new-api/integration-assessment.md` (三方交叉验证版)

## 验收结果(全部通过)

| 验收项 | 状态 |
|---|:---:|
| `/creative/` → 200 opentu index (no-cache) | ✅ |
| `/creative` → 301 → `/creative/` | ✅ |
| `/creative/sw.js` → 200 JS, no-cache | ✅ |
| `/creative/assets/*.js` → 200 JS, max-age=604800 | ✅ |
| `/creative/board` → SPA fallback | ✅ |
| `/api/status` → 200 JSON (不被 `/creative` 吞) | ✅ |
| `/v1/models` → 401 JSON | ✅ |
| admin SPA 无回归 | ✅ |
| 双模型审计(Codex + Gemini) | ✅ |
| 4 项安全/回归修复已应用 | ✅ |

## 当前状态与限制

**Phase 0 是 POC 验证,不是可用产品:**

- ✅ `/creative/` 可访问 opentu UI
- ❌ **无法生成任何内容**(opentu 需 API key,new-api 还未提供 bootstrap/session-relay)
- ❌ 无模型列表
- ❌ 无鉴权集成
- ❌ 无多渠道容灾
- ❌ 无资产云同步

**用户体验:** 打开 `/creative/` 后是空壳——所有生成按钮都无法工作。

## 下一阶段路线(评估文档 §11 推荐)

| Phase | 范围 | 可交付价值 | 预估工期 | 推荐度 |
|---|---|---|---|:---:|
| **Phase 1** | Bootstrap API + session-auth creative relay | 基础设施 | ~1.5 周 | 必需 |
| **Phase 2** | image 生成单链路跑通 | **MVP:能画图** | +1 周 | 高 |
| **Phase 3** | video/Suno/MJ + 多渠道容灾 + 异步幂等 | **可用产品** | +2–3 周 | 高 |
| **Phase 4** | 资产云同步 MVP | 多端同步 | +2–3 周 | 中高 |
| **Phase 5** | session-relay + S3/R2 + E2E | **生产级** | +2–3 周 | 中 |

**最小可用终点:** Phase 2(bootstrap + image 生成),总计 ~2.5 周。  
**推荐交付终点:** Phase 3(全链路 + 容灾),总计 ~4.5–6.5 周。

## 阻塞决策项(需人类确认才能继续)

按评估文档 §7,以下 7 项产品/安全决策必须在 Phase 1 开始前确定:

1. **Creative 对哪些用户开放?** (全部用户 / 特定分组 / admin only)
2. **鉴权模式?** (推荐:session-cookie + tokenless 计费;或 minted scoped token)
3. **首批 provider/model?** (推荐:先 OpenAI-compatible image 单链路,再逐步加 video/Suno/MJ)
4. **资产配额策略?** (byte-quota 独立,不复用计费 `Quota`;免费额度?超限行为?)
5. **资产存储后端?** (推荐:本地盘 MVP + `CreativeBlobBackend` 接口,留 S3 投放位)
6. **计费策略?** (推荐:直接扣钱包 + 创意模型白名单,MVP 不加二次确认)
7. **UI 风格割裂?** (MVP 接受 opentu 原 UI;或需主题适配?)

## 技术债务 & 待办

Phase 0 已知但延后的项:

- [ ] opentu 自带容灾引擎(`FallbackMediaExecutor`)需中和(Phase 2)
- [ ] `~110 处` 根绝对虚拟 URL(`/__aitu_cache__/` 等)需改相对(Phase 2,若 SW 实测无此问题可延后)
- [ ] Analytics 注入不涉及 `creativeIndexPage`(Phase 5 或按需)
- [ ] jsdelivr CDN 引用需替换为自托管(生产部署前)
- [ ] `.dockerignore` 未排除 `web/creative/dist`,生产 CI 需确认 COPY 行为

## 文件清单

```
new2fly/.trellis/tasks/06-07-opentu-new-api/
├── integration-assessment.md    # 三方验证评估(v2)
├── prd.md                        # 需求(R1–R7)
└── phase-0-summary.md            # 本文件
```

```
new-api feat/creative-embed @ d268466
├── main.go                       # +go:embed creativeBuildFS
├── router/web-router.go          # +显式路由 +IsDir guard
├── Dockerfile                    # +COPY web/creative/dist
└── web/creative/dist/            # 222 文件(opentu 0.9.6 dist)
```

```
opentu feat/creative-embed @ bf44d14
└── (干净 HEAD,无改动)
```

## 暂停原因

**Phase 0 POC 已验证技术可行性,但不具备交付价值。** 继续推进需:

1. 产品决策上述 7 项阻塞项
2. 投入 ~2.5–6.5 周工程时间(取决于目标 Phase)
3. 明确优先级(vs 其他待办事项)

建议先**本地起服查看 `/creative/` 真实 UI**,再决定是否值得投入后续开发。

## 如何恢复

```bash
# new-api
cd /mnt/f/code/project/new-api
git checkout feat/creative-embed
go build -o /tmp/new-api .
SESSION_SECRET=test PORT=3009 /tmp/new-api

# opentu (若需重新构建 dist)
cd /mnt/f/code/project/opentu
git checkout feat/creative-embed
pnpm install --frozen-lockfile
pnpm run build
# dist 产出: dist/apps/web/
```

访问 `http://localhost:3009/creative/` 查看 UI。

---

**状态:** Phase 0 已完成,任务暂停等待产品决策。  
**下一步:** 若继续,从 Phase 1(Bootstrap API)开始;需先确认上述 7 项决策。