# Phase 1+ 产品决策记录

> 决策时间: 2026-06-08  
> 决策人: WindC0X  
> 适用范围: Phase 1–5 实施

## 决策内容

| # | 决策项 | 选定方案 | 说明 |
|---|---|---|---|
| 1 | **用户开放范围** | 全部用户 | 不做分组限制,所有登录用户均可访问 `/creative/` |
| 2 | **鉴权模式** | session-cookie + tokenless 计费补丁 | HttpOnly cookie,不暴露长期 API key;session 用户计费走 user 钱包而非 token quota |
| 3 | **首批 provider/model** | 单链路渐进 | 先 OpenAI-compatible image 跑通,再依次加 video→Suno→MJ;Kling/Jimeng/Gemini/Flux 延后 |
| 4 | **资产配额策略** | 复用 new-api 计费体系 | creative 生成请求按 new-api 现有计费(token/quota)扣费;不单独设 byte-quota |
| 5 | **资产存储后端** | 本地盘 MVP + `CreativeBlobBackend` 接口 | 初期本地磁盘(`/data/creative-assets/`),接口留 S3/R2 投放位 |
| 6 | **计费策略** | 直接扣钱包 + 创意模型白名单 | creative 用量像普通 relay 计费,按模型白名单限定范围,MVP 不加二次确认 |
| 7 | **UI 风格** | 做风格迁移(难度不大) | 若工程量可控,将 opentu UI 主题适配 new-api 风格(TDesign→new-api 主题);否则 MVP 先接受割裂 |

## 实施影响

### Phase 1(Bootstrap + session-relay)

按决策 1、2、6:

- `GET /api/creative/bootstrap` 返回:
  ```json
  {
    "enabled": true,
    "auth": {"mode": "session"},
    "capabilities": ["image"],  // 初期只开 image,Phase 2+ 逐步加
    "models": {"image": ["gpt-image-1"]}  // 从 new-api 白名单模型动态读取
  }
  ```
- `CreativeSessionRelayAuth` 中间件:补全 `GetUserCache→WriteContext→ContextKeyUsingGroup`,guard `TokenId==0` 走 user 钱包计费
- 所有登录用户均可访问,不做分组/权限额外校验

### Phase 2(Provider 全链路)

按决策 3:

- **Phase 2.1**(~1 周):OpenAI-compatible `/v1/images/generations` 单链路跑通
- **Phase 2.2**(~1 周):video submit + poll + content
- **Phase 2.3**(按需):Suno submit/fetch
- **Phase 2.4**(按需):MJ imagine/fetch
- Flux 等暂不实现(new-api 无路由)

### Phase 4(资产云同步)

按决策 4、5:

- **不实现独立 byte-quota**:creative 资产上传不单独计费/限额
- 本地盘后端:`/data/creative-assets/{user_id}/{content_hash}.{ext}`
- `creative_assets` 表:`user_id`/`asset_type`/`content_hash`/`storage_key`/`size`
- 软删除 + contentHash 去重 + lazy download

### Phase 5(UI 风格迁移)

按决策 7:

- 评估 opentu TDesign React 主题到 new-api 主题的迁移成本
- 若成本 ≤1 周:Phase 5 实施主题适配
- 若成本 >1 周:MVP 接受 UI 割裂,标记为技术债务延后

## 简化路线(按决策优化后)

| Phase | 范围 | 工期(调整后) | 累计 |
|---|---|:---:|:---:|
| Phase 1 | Bootstrap + session-relay + tokenless 计费补丁 | ~1 周 | 1 周 |
| Phase 2.1 | image 生成单链路 | ~1 周 | 2 周 |
| Phase 2.2 | video 链路 | ~1 周 | 3 周 |
| Phase 3 | 异步幂等 + 容灾硬化 | ~2 周 | 5 周 |
| Phase 4 | 资产云同步(简化版,无 byte-quota) | ~1.5 周 | 6.5 周 |
| Phase 5 | UI 主题适配(若成本 ≤1 周) | ~1 周 | 7.5 周 |

**最小可用交付:** Phase 2.1(bootstrap + image),~2 周  
**推荐交付终点:** Phase 3(全链路 + 容灾),~5 周  
**完整交付(含 UI 适配):** Phase 5,~7.5 周

## 待办(按决策更新后)

- [ ] Phase 1: `CreativeSessionRelayAuth` + bootstrap API + tokenless 计费补丁
- [ ] Phase 2.1: OpenAI image 单链路(creative gateway provider)
- [ ] Phase 2.2: video submit/poll/content
- [ ] Phase 3: idempotency 表 + CAS 退款 + 中和 opentu 容灾
- [ ] Phase 4: `creative_assets` 表 + 本地盘后端 + lazy download
- [ ] Phase 5: 评估 UI 主题迁移成本 → 若 ≤1 周则实施

## 阻塞项已解除

Phase 1 可立即开始实施。