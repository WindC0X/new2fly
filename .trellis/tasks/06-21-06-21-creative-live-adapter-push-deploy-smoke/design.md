# Design — Push / deploy / smoke workflow

## Boundaries

- Orchestration repo: `/mnt/f/code/project/new2fly`.
- Code repo: `/mnt/f/CODE/Project/new-api`.
- OpenTU repo: `/mnt/f/CODE/Project/opentu` (expected no diff for this task).
- GitHub credentials are on the Windows host; WSL must not inspect secrets.

## Push design

1. Inspect status/logs:
   - `git -C /mnt/f/CODE/Project/new-api status --short && git log --oneline -3`
   - `git -C /mnt/f/code/project/new2fly status --short && git log --oneline -6`
2. Push using host-side git if WSL cannot authenticate:
   - `powershell.exe -NoProfile -Command "git -C 'F:\\CODE\\Project\\new-api' push ..."`
   - `powershell.exe -NoProfile -Command "git -C 'F:\\code\\project\\new2fly' push ..."`
3. Never print credential helpers, tokens, remotes containing credentials, or auth config values.

## Staging-first deployment design

Staging is mandatory before production. Deployment is a dangerous operation because it can affect current users and existing channel/config data.

Before running staging deployment commands, confirm:

- staging host/environment;
- branch/commit to deploy;
- backup/data preservation expectation;
- whether brief service interruption is acceptable;
- whether live provider calls are permitted.

Preferred staging deployment posture:

1. Update application code/image only.
2. Preserve existing DB, channels, users, options, and storage.
3. Run application-native migrations only if they are part of normal startup and non-destructive.
4. Validate health before smoke.
5. Keep rollback pointer to prior commit/image.

## Configuration design

Live adapter configuration remains admin-driven:

- Channel page owns provider BaseURL/key/model list.
- Creative Model Bindings page owns logical Creative model IDs and maps them to:
  - `channelId`
  - `providerModelId`
  - `priceModelId`
  - `adapterPreset` (`duomi_image_live` / `grsai_image_live`)
  - `parameterTemplate` (`duomi_gpt_image`, `grsai_gpt_image`, `grsai_gpt_image_vip`, `grsai_nano_banana`)
  - schema visible to OpenTU.

## Smoke design

Smoke stages run on staging first. Production smoke is a separate gate after staging passes and production deployment is explicitly authorized.

Staging smoke stages:

1. Read-only route/header smoke.
2. Authenticated dashboard/session smoke.
3. Admin no-provider validation/dry-run smoke.
4. Browser smoke for model catalog and parameter panel.
5. Optional mock image task smoke.
6. Optional real provider smoke after explicit authorization.

Real provider smoke must use a minimal prompt and must record only redacted task IDs/status, not provider keys/raw signed URLs.

## Rollback

If staging deploy or smoke fails:

- stop further provider calls;
- capture failing request class/status/log excerpt with secrets redacted;
- roll back application code/image to prior known-good if the target environment is degraded;
- keep data/channel config intact unless user explicitly approves a config rollback.


## Production gate

Production is intentionally outside the automatic first execution path. It can proceed only after:

1. `new-api` and `new2fly` commits are pushed;
2. staging is deployed to the verified `new-api` commit;
3. staging no-provider/browser smoke passes;
4. live provider smoke is either passed on staging or explicitly deferred/accepted;
5. the user separately confirms production deployment.
