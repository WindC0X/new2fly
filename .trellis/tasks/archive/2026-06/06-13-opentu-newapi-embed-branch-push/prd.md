# OpenTU new-api Embed Branch Push

## Goal

Publish the OpenTU changes for the `new-api` embedded Creative route to a dedicated branch on the existing OpenTU fork, without mixing them into the platformization branch.

## Requirements

- Use the existing OpenTU fork remote.
- Keep the platformization branch untouched.
- Create/use a dedicated branch for the embedded New API route, recommended name: `newapi-embed-release-gate`.
- Push only the already-committed OpenTU release-smoke changes, especially commit `39e0fe23 test(creative): harden release smoke gates`.
- GitHub credentials are on the Windows host; do not read or print credentials. If WSL Git cannot authenticate, use host `git.exe`/PowerShell from the same worktree.
- Do not commit or push unrelated local artifacts such as `packages/drawnix/audio-test.pptx`.

## Acceptance Criteria

- [ ] OpenTU has a local branch for the new-api embed line at the intended commit.
- [ ] The branch is pushed to the fork remote.
- [ ] Platformization branch remains untouched.
- [ ] Final status reports any untracked local-only files left behind.
