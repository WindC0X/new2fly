# Design: Deep Goal Audit for new-api and opentu

## Context

The orchestration repository `new2fly` holds Trellis task history and target requirements. The implementation under review lives in sibling repositories:

- `../new-api`
- `../opentu`

Both code repositories currently have uncommitted work on branch `feat/creative-embed`. The review must judge the current local state, not just committed history.

## Review Architecture

Use a two-layer audit:

1. **Main coordinator**
   - Creates Trellis artifacts.
   - Generates and runs a `codex-flow` workflow.
   - Performs light local verification where necessary.
   - Writes the final report.

2. **Read-only dynamic workflow agents**
   - Each agent owns a bounded evidence branch.
   - Agents must not edit files.
   - Prompts start with `Active task: .trellis/tasks/06-09-deep-goal-audit-new-api-opentu` per Trellis sub-agent protocol.
   - Structured outputs use JSON Schema with status, evidence, findings, and confidence.

## Branches

### B1. Target baseline reconstruction

Extract intended goals and acceptance criteria from Trellis task docs, product decisions, Opentu OpenSpec/docs, README/AGENTS files. Output a normalized target matrix.

### B2. new-api embed, routing, static serving, navigation

Inspect `router/web-router.go`, creative controller/routes, embedded FS, `web/creative/dist`, sidebar/menu changes, SPA fallback behavior, cache headers, and route tests.

### B3. new-api session auth, creative relay, billing, quota, async safety

Inspect creative middleware/controllers/models/services, relay mode changes, funding source/quota logic, billing tests, async task handling, and edge cases for tokenless session usage.

### B4. opentu embedded runtime, base path, SW, virtual media URLs, return button

Inspect Vite/Nx build config, SW registration/scope, generated asset paths, embedded-mode detection, return-to-console UI, root-absolute virtual URLs, and settings changes.

### B5. opentu provider gateway, model discovery, fallback neutralization

Inspect provider routing/session broker/model preference changes, AI input bar/model dropdown, direct API key paths, fallback executor behavior, and whether generation can use new-api as sole gateway.

### B6. asset/document cloud sync and storage safety

Inspect creative document sync, cloud sanitizer, asset metadata/binary behavior, user isolation assumptions, local cache interactions, privacy/security concerns, and tests.

### B7. verification and build/test evidence

Inspect package scripts and existing tests, then run safe lightweight commands when feasible. Prefer targeted tests over full destructive or long-running suites. Record if dependencies or environment prevent execution.

### B8. adversarial cross-check

Challenge optimistic conclusions from B1-B7: find contradictions, missing acceptance checks, stale build artifacts, untested code, and cases where implementation appears present but product goal remains unmet.

### B9. synthesis

Combine branch outputs into a completion verdict and prioritized gap list.

## Evidence Contract

Every material claim should cite at least one of:

- File path with function/component/model name.
- Test name or command output.
- Build/static artifact path.
- Trellis source requirement path.
- Explicit `blocked/unverified` reason.

## Status Vocabulary

- `done`: implemented and locally verified by code/test/static artifact evidence.
- `partial`: implementation exists but lacks key acceptance coverage, deployment artifact, or edge-case safety.
- `not_done`: no implementation or implementation contradicts target.
- `blocked/unverified`: plausible but cannot be verified locally due missing credential/service/runtime.

## Non-Destructive Rule

Sub-agents run with `sandbox: "read-only"`. The main coordinator may write only review artifacts in `new2fly` (`.trellis/tasks/...`, `.codex-flow/...`). No source modifications in `../new-api` or `../opentu`.

## Risks and Mitigations

- **Large codebase / token pressure**: split into branches; require concise structured outputs.
- **Uncommitted state drift**: include `git status` evidence in final report.
- **Generated dist may be stale**: compare source intent and embedded build artifacts where possible.
- **Tests may be long or dependency-heavy**: run targeted tests first; mark broad suites unverified if not feasible.
- **Sub-agent failure**: `codex-flow` journals partial outputs; rerun resumes. Main agent can supplement with direct local inspection.
