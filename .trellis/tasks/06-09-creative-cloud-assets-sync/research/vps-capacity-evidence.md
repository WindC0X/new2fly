# VPS capacity evidence for creative asset sync — 2026-06-09

Source docs inspected under `/mnt/f/CODE/Project/OpenClawChineseTranslation/docs`:

- `VPS_A_CAPACITY_GOVERNANCE_2026-03-21.md`
- `VPS_STATUS_HANDOFF_2026-03-06.md`
- `VPS_SERVICE_INVENTORY_2026-03-06.md`
- `VPS_MONITORING_2026-03-14.md`
- `superpowers/plans/2026-06-02-grok2api-jiujiu-canary.md`

Relevant facts:

- `VPS-A` is the current public edge/control host for `CPA`, `new-api`, helper HTTP/internal listener, subscription bridge, cluster monitor, and backup state.
- `new-api` runs on `VPS-A`; `api.se7endot.top` and `console.se7endot.top` point to this path.
- `VPS-A` capacity governance documents a 40G root disk and warns that when root usage exceeds 90%, `/v1/responses` may return `system_disk_overloaded`.
- The same runbook says 90% must not be treated as normal and recommends at least 4G free on the 40G root disk.
- `new-api` DB lives under `/home/admin/apps/new-api/data/new-api.db` and is included in automatic backup to `/home/admin/apps/new-api/backups/auto`.
- `/home/admin/apps/new-api/data`, the live `new-api.db`, Docker overlay/volumes, and live business data are explicitly high-risk cleanup targets and must not be deleted to rescue space.
- A newer 2026-06-02 canary note shows another node (`VPS-E`) remained about `49G total / 45G used / 3.7G available / 93%` after low-risk cleanup, reinforcing that this VPS cluster has low storage headroom.
- `VPS-B` is documented as a 1G-class/high-volatility execution layer and is not a good place for persistent creative assets.
- `VPS-D` is the private OpenClaw host and docs say OpenClaw should remain there; it should not become a public new-api asset store.

Planning consequence:

- The previous 2GiB-per-user DB-backed asset cap is not safe as a production default on the current `VPS-A` because asset bytes would increase live DB size and DB backup size on the same constrained root disk.
- DB-backed storage is still acceptable for local development, tests, and very small canary use if protected by strict global/per-user caps, a feature flag, and disk-headroom guards.
- For real public/user-facing creative media sync, the production storage backend should be S3-compatible object storage such as Cloudflare R2, while new-api continues to enforce auth and serve `/creative/api/assets/:id/content` as the stable private URL.

Additional caveat:

- No live 2026-06-09 / deployment-window VPS-A `df` or `/api/performance/stats` sample was captured in this planning pass. DB canary cannot be enabled without fresh same-window evidence.
- The VPS-E 93% observation is cluster headroom evidence only; VPS-E is not an asset-store target.
