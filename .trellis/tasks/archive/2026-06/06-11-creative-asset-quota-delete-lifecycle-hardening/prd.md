# Creative asset quota delete lifecycle hardening

## Goal

Fix backend Creative asset quota, delete, document-reference, and product/spec reconciliation issues in `../new-api` and `.trellis/spec` before release or explicit risk acceptance.

## Source Findings

- Codex H6: quota check and DB write are not atomic, so concurrent uploads can bypass per-user byte/count limits.
- Codex M2: asset delete removes DB metadata before object deletion, making failed object deletion hard to retry by asset id.
- Codex M3 / Claude doc-ref finding: document deletion/mutation and asset ref refresh/delete are not consistently in one transaction/lock domain.
- PRD/spec conflict: original PRD mentions metadata `name/prompt/model`, soft-delete tombstone, and byte quota, while product decision says no independent byte quota. Current implementation chose byte quota and lacks tombstone/metadata columns.

## Requirements

- Concurrent uploads must not exceed configured per-user asset count/byte quota beyond a documented, bounded tolerance.
- Asset delete must be recoverable if object deletion fails; metadata needed for retry must not be lost prematurely.
- Document snapshot mutation and asset ref refresh/delete must not leave permanent orphan refs or missing refs after partial failure.
- Product/spec docs must be updated or a follow-up accepted-risk record must document metadata/tombstone/rate-limit decisions.

## Acceptance Criteria

- [ ] Concurrent quota test demonstrates only allowed uploads succeed under low per-user quota.
- [ ] Delete failure test demonstrates object metadata remains retryable or tombstone/outbox records pending deletion.
- [ ] Document delete/ref cleanup failure test demonstrates atomic rollback or recoverable retry state.
- [ ] Create/update document ref refresh happens in the same consistency domain as the document mutation or has a documented recovery mechanism.
- [ ] PRD/spec reconciliation is committed for byte quota, metadata fields, tombstone, and per-user rate limit decisions.
