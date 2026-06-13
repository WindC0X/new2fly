# Push new-api and new2fly Release Gate Branches

## Goal

Push the already-committed `new-api` and `new2fly` release-gate hardening work to writable GitHub remotes, using host-side GitHub credentials.

## Requirements

- Do not read or print GitHub credentials.
- Use Windows host Git/GitHub credential state for authenticated push when needed.
- Push `new-api` commit `c9f318c fix(creative): harden embedded static boundary` to a dedicated/writable branch.
- Push `new2fly` commits through `0924f3f chore: record journal` to a writable branch.
- Do not commit or push unrelated local-only artifacts:
  - `new-api/.codegraph/`
  - `new-api/.codex-flow/`
  - `new2fly/.cache/`
- Preserve existing remotes; add a `fork` remote only if the configured `origin` is not writable for the host account.

## Acceptance Criteria

- [ ] `new-api` release-gate commit is present on a writable remote branch.
- [ ] `new2fly` release-gate/Trellis commits are present on a writable remote branch.
- [ ] Final report lists branch names, remote URLs, and pushed commit hashes.
- [ ] Trellis task is archived and journaled.
