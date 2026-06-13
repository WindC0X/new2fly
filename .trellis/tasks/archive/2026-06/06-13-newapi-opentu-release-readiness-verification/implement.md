# Implementation Plan — Release Readiness Verification

## Phase A — Baseline and script discovery

1. Capture git status for all three repositories.
2. Inspect `package.json`, Makefile/task scripts, backend build docs, and creative embed docs.
3. Identify exact commands for local browser smoke and production build chain.

## Phase B — Dynamic workflow independent verification

Run a dynamic workflow with independent branches:

- browser/E2E feasibility and smoke design
- production build/package chain readiness
- env/config readiness and fail-closed behavior
- release dirty-state review

The prompt must ask whether the current project reaches release-readiness goals; it must not depend on previous reports.

## Phase C — Local verification execution

Run feasible local checks without secrets or production endpoints:

- frontend type/build/test commands as discovered
- backend build/test/static route checks as feasible
- local browser smoke if browser tooling and local server prerequisites are available

## Phase D — Synthesis

Create final report with:

- verdict: `release_ready`, `mostly_ready`, or `not_ready`
- HIGH/MEDIUM/LOW findings
- command logs and dynamic workflow references
- exact follow-up actions
