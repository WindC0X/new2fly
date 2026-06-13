# Design — Creative asset quota delete lifecycle hardening

## Affected Areas

- `../new-api/service/creative_asset.go`
- `../new-api/model/creative_asset.go`
- `../new-api/controller/creative_asset.go`
- `../new-api/controller/creative.go`
- `../new-api/model/creative.go`
- `.trellis/spec/backend/creative-asset-sync.md`
- `.trellis/spec/frontend/creative-asset-sync.md` when contract wording changes.

## Quota Design Options

Preferred: per-user quota reservation/counter row with transaction/CAS semantics.

Alternative: DB transaction with lock over user asset set plus final insert. This may be DB-dialect-sensitive and must be tested with the repository's supported DB assumptions.

## Delete Design Options

Preferred: tombstone/outbox.

- Mark asset `pending_delete` or write delete outbox while retaining storage backend/object key.
- Delete object asynchronously or synchronously.
- Finalize metadata delete only after object deletion succeeds.

Alternative: delete object first, then DB metadata, with clear handling for DB delete failure. This can leave object unavailable while metadata still exists, so tombstone/outbox is safer.

## Document Ref Design

Create/update/delete document and asset refs should share one transaction or a recoverable mutation journal. If existing model boundaries make this large, prioritize delete+ref cleanup atomicity because it is currently least self-healing.

## Spec Reconciliation

If implementation intentionally keeps byte quota and omits metadata/tombstone for release, update specs/product notes to say so explicitly. If tombstone or metadata is implemented, update public DTO and frontend contract tests accordingly.
