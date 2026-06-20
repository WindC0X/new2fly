# Implement Plan — Creative production post-deploy browser acceptance

## Phase A — Setup and safe evidence

- [x] Confirm deployed version/provenance and public route smoke remain healthy.
- [x] Determine available authenticated browser path without handling raw cookies/secrets. User performed real logged-in production browser acceptance and reported checks normal.
- [x] Keep a no-provider/no-cloud-sync mutation boundary.

## Phase B — Authenticated UI acceptance

- [x] Open production `/creative/` in authenticated browser session.
- [x] Confirm app shell loads past loading screen.
- [x] Confirm return-to-console/control layout is usable.
- [x] Confirm no standalone APIKey/provider setup prompt blocks normal embedded use.
- [x] Confirm no GitHub/Gist cloud sync setup or feedback/GitHub CTA is presented as required embedded setup.

## Phase C — Model and parameter acceptance

- [x] Inspect model selector/catalog source.
- [x] Confirm text/image model availability or document intentional empty state.
- [x] Select available managed image model without submitting generation.
- [x] Confirm parameter panel appears for schema-backed image models.
- [x] Confirm no `#img`-only/empty-params regression where schema exists.

## Phase D — Record result

- [x] Record observations and safe screenshots/route statuses only.
- [x] Record not-run items: provider generation, cloud sync/S3, Duomi/GrsAI live adapters.
- [x] Commit Trellis task notes and archive if acceptance is complete; otherwise mark blocked with required user action.
