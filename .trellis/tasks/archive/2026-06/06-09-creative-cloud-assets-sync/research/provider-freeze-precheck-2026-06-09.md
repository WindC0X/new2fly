# Provider freeze precheck — 2026-06-09

Purpose: continue planning under the approved `approvedDeploymentTarget=vps-a-production-s3` target without starting implementation. This is a current-provider precheck for production enablement, not account setup and not product-code implementation.

## Sources checked

Official/current sources checked on 2026-06-09:

- Cloudflare R2 pricing docs: https://developers.cloudflare.com/r2/pricing/
- Cloudflare R2 product/pricing page: https://www.cloudflare.com/products/r2/
- Cloudflare R2 S3 token docs: https://developers.cloudflare.com/r2/api/s3/tokens/
- Cloudflare service-specific terms: https://www.cloudflare.com/service-specific-terms-application-services/
- Backblaze B2 pricing: https://www.backblaze.com/cloud-storage/pricing
- Backblaze B2 S3-compatible API docs: https://www.backblaze.com/docs/en/cloud-storage-call-the-s3-compatible-api
- Backblaze Terms of Service: https://www.backblaze.com/company/policy/terms-of-service
- Tigris pricing: https://www.tigrisdata.com/pricing/
- Tigris service terms: https://www.tigrisdata.com/service-terms/
- AWS S3 pricing/free tier page: https://aws.amazon.com/s3/pricing/

## Current pricing/limit observations

### Cloudflare R2 — recommended first production candidate

- S3-compatible object storage with no direct R2 egress charge.
- Standard storage free tier: 10 GB-month/month, 1M Class A operations/month, 10M Class B operations/month, egress free.
- Standard paid pricing observed: $0.015/GB-month, $4.50/M Class A operations, $0.36/M Class B operations.
- R2-specific S3 API tokens can be generated and scoped to buckets/resources; production should use a least-privilege bucket token, not a broad account token when avoidable.
- Good fit for this task because creative asset reads may become egress-heavy and Opentu never needs direct bucket access.

### Backblaze B2 — viable fallback

- S3-compatible API with endpoint shape like `https://s3.<region>.backblazeb2.com`.
- Pricing page currently shows pay-as-you-go storage at $6.95/TB/month, first 10GB storage always free, and free egress up to 3x average monthly storage, with overage at $0.01/GB unless routed through eligible CDN/compute partners.
- API calls are broadly free for pay-as-you-go customers, with Class D caveats.
- Good fallback if Cloudflare billing/account/R2 availability becomes a blocker, but egress rules are less simple for arbitrary direct downloads than R2.

### Tigris — viable alternative / later candidate

- Globally distributed S3-compatible object storage with zero egress fees.
- Standard tier observed: $0.02/GB/month, Class A $0.005/1,000, Class B $0.0005/1,000, egress free.
- Free tier observed: 5GB Standard storage, 10,000 Class A requests, 100,000 Class B requests per month.
- Useful if global placement/distribution becomes more important than R2's lower Standard storage price/free tier.

### AWS S3 — compatibility baseline, not preferred for this VPS-A media use case

- Official pricing page confirms S3 cost components include storage, requests/data retrieval, data transfer, management/replication, etc.
- AWS Free Tier shifted to credit-based terms for new customers; this is not as simple as R2/B2/Tigris for a small self-hosted deployment.
- Use mainly as SDK/API compatibility baseline unless there is an existing AWS account/credit reason.

## Planning recommendation

Freeze the first production configuration target as **Cloudflare R2 Standard** for deployment planning:

```text
CREATIVE_ASSET_STORAGE=s3-compatible
CREATIVE_ASSET_S3_PROVIDER=cloudflare-r2      # optional internal label only, not required by generic adapter
CREATIVE_ASSET_S3_ENDPOINT=https://<account-id>.r2.cloudflarestorage.com
CREATIVE_ASSET_S3_REGION=auto
CREATIVE_ASSET_S3_BUCKET=<private bucket>
CREATIVE_ASSET_S3_PREFIX=creative-assets/<environment>/
CREATIVE_ASSET_S3_FORCE_PATH_STYLE=true
```

Implementation must remain generic S3-compatible. The optional provider label must not affect Opentu/API/snapshot contracts and must never be exposed to the frontend.

## Production enablement checklist still required later

Do not put real credentials in Trellis, git, tests, logs, or frontend bootstrap. Before enabling production asset sync:

- Create a private bucket and environment-specific prefix.
- Create a least-privilege write/read/delete/list/head token scoped to that bucket/prefix where provider supports it.
- Inject secrets through deployment secret management, not repo files.
- Enable provider-side budget/billing alerts when available.
- Run a production smoke test: PutObject, HeadObject, ranged GetObject, DeleteObject, missing object, permission failure.
- Confirm new-api production config fails closed when S3 config is missing/unhealthy and does not fall back to DB blobs.
- Re-open the provider pricing and terms pages at enablement time because prices/TOS are unstable.

## Trellis consequence

- This precheck supports keeping R2 as the preferred first production candidate.
- This does not require hard-coding R2 in code.
- This does not start implementation; task remains in planning until `task.py start` is allowed and run.
