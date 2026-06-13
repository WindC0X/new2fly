# Check Report — OpenTU new-api Embed Branch Push — 2026-06-13

## Result

Pushed the dedicated OpenTU new-api embed branch to the writable fork without changing the platformization/upstream branch.

## Remote Layout

- `origin`: `https://github.com/ljquan/opentu.git` — upstream/parent; push attempt was denied for host account `WindC0X`, so this remote was left unchanged.
- `fork`: `https://github.com/WindC0X/opentu.git` — writable fork; added as a local remote in the OpenTU worktree.

## Branch

- Local branch: `newapi-embed-release-gate`
- Remote branch: `fork/newapi-embed-release-gate`
- Commit: `39e0fe23180ffcfc98a767043869c4a90171356d` (`test(creative): harden release smoke gates`)

## Commands / Evidence

```bash
cd /mnt/f/code/project/opentu
git branch newapi-embed-release-gate 39e0fe23
# host-side Windows Git was used for credentials:
powershell.exe -NoProfile -Command "Set-Location -LiteralPath 'F:\\code\\project\\opentu'; git push -u fork newapi-embed-release-gate"
git ls-remote --heads fork newapi-embed-release-gate
```

Remote verification output:

```text
39e0fe23180ffcfc98a767043869c4a90171356d refs/heads/newapi-embed-release-gate
```

## Notes

- Did not read or print GitHub credentials. `gh auth status` only showed the active host account and a masked token.
- First push to `origin` failed with 403 because host account `WindC0X` does not have write permission to `ljquan/opentu`.
- Current OpenTU worktree still has unrelated local-only untracked file `packages/drawnix/audio-test.pptx`; it was not committed or pushed.
