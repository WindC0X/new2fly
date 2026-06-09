# Object storage options for creative asset bytes — 2026-06-09

Reason: user raised VPS capacity risk during planning, then asked to re-plan after current VPS docs were inspected.

## Superseding recommendation

The dynamic VPS re-plan upgrades production MVP scope:

- Current VPS-A broad/public production rollout should use a **generic S3-compatible object storage adapter**.
- DB-backed blobs are allowed only for local development, tests, and explicitly capped tiny VPS-A canary/emergency mode.
- The implementation must be provider-neutral. Do not hard-code Cloudflare R2, Backblaze B2, Tigris, bucket URLs, or provider credentials into snapshots/API responses.
- Opentu continues to store only `/creative/api/assets/:id/content`; new-api enforces session/owner checks and streams from the selected backend.

## Candidate providers

- Cloudflare R2 remains the preferred first deployment candidate because it is S3-compatible and historically attractive for egress-heavy media workloads.
- Backblaze B2 and Tigris remain viable S3-compatible alternatives.
- Provider pricing, free tiers, limits, regions, TOS, and account/bucket/IAM details must be rechecked against official sources before provider freeze/production rollout. This file is planning evidence, not a current price guarantee.

## Current provider precheck — 2026-06-09

Official provider pages were rechecked for production planning. See `research/provider-freeze-precheck-2026-06-09.md`.

Planning recommendation: use **Cloudflare R2 Standard** as the first production configuration target because it is S3-compatible, has a 10 GB Standard free tier, includes monthly operation allowances, and does not charge direct R2 egress. Keep Backblaze B2 and Tigris as compatible fallbacks. Keep AWS S3 as the compatibility baseline, not the preferred small VPS-A media-sync provider.

This is a provider planning freeze, not account provisioning: before production enablement, create the private bucket, scoped token, secret injection, budget alerts, and smoke tests outside git/Trellis.

## Planning consequence

- Implement `S3CompatibleCreativeAssetStorage` in this task for production path.
- Also implement `DatabaseCreativeAssetStorage` for local/test/canary fallback, but require explicit canary config, low caps, and disk-headroom guard.
- Production mode must fail closed when S3 config is missing/unhealthy; it must not silently fallback to DB blobs on VPS-A.
- Bucket/prefix must be private. No public read ACL/policy. No direct browser-to-bucket upload/download in this task.
- Never persist provider credentials, public permanent object URLs, signed URLs, bucket secrets, or raw `sourceUrl` in creative document snapshots, document metadata, asset metadata, frontend state, logs, or test fixtures.
