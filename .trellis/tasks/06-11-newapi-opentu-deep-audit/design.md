# Design — Dynamic Deep Audit of new-api and opentu

## Execution Model

The audit will be executed from the orchestration/specification repository `/mnt/f/code/project/new2fly` using `codex-flow` and a generated import-free workflow file under `.codex-flow/generated/`. The audit target is the `new2fly` project goal, with implementation evidence gathered from sibling repositories `new-api` and `opentu`.

The workflow will fan out independent read-only review branches using `ctx.parallel`. Each branch receives a bounded audit lens and must inspect current files directly. A final synthesis agent will merge findings, remove duplicates, rank severity, and produce a structured summary. A dedicated goal-conformance synthesis pass will compare `new2fly` Creative integration contracts against implemented behavior and validation coverage.

## Boundaries

### Writable Locations

- `.codex-flow/generated/newapi-opentu-deep-audit.workflow.ts`
- `.codex-flow/journal/newapi-opentu-deep-audit.jsonl` created by the engine
- `.trellis/tasks/06-11-newapi-opentu-deep-audit/` report and optional notes

### Read-only Target Repositories

- `/mnt/f/code/project/new-api`
- `/mnt/f/code/project/opentu`

Agents must not modify files in target repositories.

## Evidence Policy

Allowed evidence:

- Current `new2fly/.trellis/spec` contracts and current source code, tests, configs, package manifests, route declarations, migration code, and repository docs needed to understand implementation behavior.
- Local command outputs that inspect code or run safe tests/checks.

Disallowed evidence:

- Prior audit reports or old task outputs as sources of truth.
- `.codebuddy/code-review-report.md`, old Trellis/archive reports, prior assistant summaries, or generated historical findings.
- Secrets from real `.env` or credentials files.

## Parallel Audit Branches

1. **new-api surface and routing**
   - Entry points, router/middleware stack, CORS/session/auth order, public/admin route exposure.
2. **new-api AuthN/AuthZ and identity**
   - JWT/session, OAuth/OIDC/passkey/two-factor, role checks, user/admin isolation, token handling.
3. **new-api billing/payment/quota logic**
   - Top-up, subscription, Stripe/Creem/Epay/Waffo/Pancake webhooks, idempotency, quota settlement, refund/duplicate scenarios.
4. **new-api relay/provider/request transformation**
   - Provider routing, model/channel selection, request DTOs, stream handling, zero-value preservation, fallback behavior.
5. **new-api external file/media/proxy/task security**
   - URL validation, SSRF protections, file service, video/image proxy, async task callbacks, path/content validation.
6. **new-api persistence/concurrency/cross-DB compatibility**
   - GORM/raw SQL, transactions, locking/idempotency, Redis/cache consistency, SQLite/MySQL/PostgreSQL behavior.
7. **opentu app/runtime architecture**
   - Entry points, Nx projects, app shell, service worker, build/deployment assumptions.
8. **opentu AI task/material/workspace logic**
   - `packages/drawnix` task queue, asset integration, generation preferences, history/cache, media lifecycle.
9. **opentu browser security and integration surfaces**
   - postMessage, iframe/tool/plugin/skill integration, DOM injection/XSS, local storage/indexedDB/Gist sync, worker messaging.
10. **new2fly development-goal conformance**
   - Derive current goals from `new2fly/.trellis/spec/backend/creative-*.md` and `new2fly/.trellis/spec/frontend/creative-*.md`. Judge whether implemented code, tests, and wiring in `new-api` and `opentu` satisfy those contracts.
11. **Cross-repo contract and validation gaps**
   - API assumptions between embedded Opentu and new-api creative routes, error/status shapes, nonce/auth/session handling, idempotency headers, async task lifecycle, service-worker pass-through, test coverage gaps, and cross-repo goal drift.

## Finding Schema

Each branch returns:

- `branch`: audit lens name.
- `scope`: repository and subsystem.
- `findings`: list of findings with `title`, `severity`, `confidence`, `status`, `repo`, `files`, `impact`, `scenario`, `evidence`, `recommendation`, `validation`.
- `reviewed`: files/areas reviewed with no material issue.
- `gaps`: items that require runtime verification or unavailable context.

## Severity Guide

- **Critical**: unauthenticated/low-privilege compromise, payment/quota bypass at scale, secret/key disclosure, remote code execution, broad tenant data exposure.
- **High**: reliable privilege escalation, confirmed payment/idempotency defect, SSRF to sensitive network, cross-user data access, persistent XSS in high-trust context.
- **Medium**: constrained abuse, data inconsistency, local/session exposure, partial bypass, significant reliability gap.
- **Low**: hardening issue, edge-case correctness, test/observability gap with limited direct impact.

For development-goal findings, severity reflects impact on the `new2fly` integration contract: Critical/High if a required embedded Creative route, asset sync path, auth/session boundary, idempotency/billing invariant, or credential-stripping invariant is absent/unsafe; Medium if a required workflow is partial or unvalidated; Low if a secondary contract is incomplete or poorly evidenced.

## Validation Strategy

Primary validation is static source inspection plus targeted safe commands where feasible:

- `new-api`: focused `go test` packages for changed/high-risk areas if runtime dependencies allow; otherwise static compile/test gap noted.
- `opentu`: `pnpm`/Nx typecheck/lint/test commands only if dependencies are installed and command cost is reasonable; otherwise report as not run with reason.
- No production endpoints or credentialed external APIs.

## Output

Final report path:

- `.trellis/tasks/06-11-newapi-opentu-deep-audit/audit-report.md`

The report will include:

- executive summary;
- methodology and evidence limits;
- prioritized findings table;
- dedicated development-goal conformance matrix;
- detailed findings;
- reviewed/no-finding areas;
- validation status and next remediation recommendations.
