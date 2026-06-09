# Dynamic Deep Project Audit

## Goal

Run a complete read-only deep review of the current project using `$dynamic-workflow` / `codex-flow`, with parallel sub-agents covering repository structure, Trellis workflow health, agent/hook/config safety, script quality, and task/workspace consistency. Produce a concise, evidence-based summary of material findings and follow-up recommendations.

## What I already know

* User explicitly requested: `使用 $dynamic-workflow 完全深度审查当前项目`.
* Current directory is Trellis-managed and contains `.trellis/`, `.agents/`, `.codex/`, `.claude/`, `.codegraph/`, and `AGENTS.md`.
* There is no Git repository at the current root according to `git rev-parse` / `git ls-files`.
* `codex-flow doctor` passes for local install and fake backend.
* `codex-flow smoke --backend codex-sdk` timed out, while `codex-flow smoke --backend codex-exec` passed; the workflow will therefore run with the Codex CLI membership backend (`codex-exec`) rather than API keys.

## Assumptions

* “Current project” means `/mnt/f/code/project/new2fly` and its in-repo files.
* The audit should be read-only with respect to project/source files. Operational files generated for the requested workflow under `.codex-flow/` and this Trellis task metadata are allowed.
* Potential secrets must not be printed. If secret-like files or values are encountered, report paths/key names and risk only, with values redacted.

## Requirements

* Generate an import-free `.codex-flow/generated/*.workflow.ts` file following the dynamic-workflow engine API.
* Fan out into independent read-only audit branches rather than one giant prompt.
* Cover at least:
  * repository inventory and missing/extra project artifacts;
  * Trellis workflow/spec/task consistency;
  * agent, hook, and config safety;
  * script/code quality for project automation;
  * state consistency and operational risks.
* Run the workflow to completion if the available backend permits.
* Summarize findings by severity, with file/path evidence and actionable next steps.

## Acceptance Criteria

* [ ] `codex-flow run .codex-flow/generated/deep-project-audit.workflow.ts --backend codex-exec` completes or the blocking backend/runtime failure is reported clearly.
* [ ] Journal path is recorded.
* [ ] Parallel branch outputs are summarized.
* [ ] No secret values are printed in the final report.
* [ ] The final answer includes a one-line rerun command.

## Out of Scope

* Making code/config fixes during the audit.
* Pushing commits or destructive Git operations.
* Reading or printing external credentials outside the project.

## Technical Notes

* Dynamic workflow skill: `/home/windc0x/.codex/skills/dynamic-workflow/SKILL.md`.
* Engine API reference: `/home/windc0x/.codex/skills/dynamic-workflow/references/engine-api.md`.
* Relevant Trellis docs/spec inputs are listed in `implement.jsonl` and `check.jsonl`.

## Correction - 2026-06-08

User clarified that the actual project scope is **Opentu embedded in new-api**. The relevant repositories are sibling directories:

* `/mnt/f/code/project/opentu`
* `/mnt/f/code/project/new-api`

The earlier workflow output should be treated as a meta/workspace audit of `/mnt/f/code/project/new2fly`, not as the requested integration audit. A corrected workflow must audit the two sibling repositories and their cross-repository integration contracts.
