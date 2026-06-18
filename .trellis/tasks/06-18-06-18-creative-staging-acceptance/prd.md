# PRD — Creative staging acceptance

## Goal

Refresh staging with the committed Creative Adapter Capability Registry changes and provide a safe user-facing staging acceptance path before any production deployment.

## Scope

- Use committed revisions:
  - new-api `8f50577 fix(creative): finalize managed binding release gates`
  - OpenTU `59b09cc5 fix(creative): close managed runtime model gaps`
  - new2fly task evidence `204a6fa chore(task): archive creative adapter capability task`
- Deploy or refresh staging only.
- Run smoke checks against staging.
- Provide the user with staging URL and a concise acceptance checklist.

## Non-goals

- No production deployment.
- No real Duomi/GrsAI provider calls.
- No printing or persisting secrets.
- No modification of production user/channel data.

## Acceptance Criteria

- [x] Staging runs the intended new-api/OpenTU commits or an image built from them.
- [x] `/creative/` loads in staging.
- [x] Logged-out and logged-in boundary checks behave as expected.
- [x] Creative model bindings admin page loads and uses sanitized channel summaries.
- [x] User receives staging URL plus manual validation steps.
- [x] Findings, commands, and any caveats are recorded before task closure.
