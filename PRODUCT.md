# Product

## Register

product

## Users

New API administrators configure upstream channels, model exposure, Creative adapter bindings, rollout safety, and provider capability metadata. OpenTU Creative users consume the managed catalog inside the embedded `/creative/` app without seeing provider credentials, channel internals, or unstable upstream details.

## Product Purpose

This product embeds OpenTU Creative into New API while keeping New API as the control plane for authentication, channels, model availability, billing, security boundaries, and cloud-synced user state. Success means administrators can expose only safe, available Creative models and parameters, while end users get a predictable creation UI that fails closed when channels, bindings, or schemas are unavailable.

## Brand Personality

Operational, precise, trustworthy.

## Anti-references

- Provider-specific admin pages duplicated for every new image/video vendor.
- Browser-visible API keys, base URLs, provider callbacks, or channel secrets.
- Ambiguous model selectors where OpenTU defaults, New API channel models, and Creative bindings look interchangeable.
- Static hard-coded parameter UIs that drift from backend capability checks.
- Marketing-heavy copy in operational settings pages.

## Design Principles

1. Make the control-plane boundary visible: Channels store credentials and upstream reachability; adapters describe provider protocol; bindings decide what Creative exposes.
2. Prefer schema-driven UI over provider-specific branching so new adapters do not require redesigning the admin surface.
3. Fail closed before provider calls: validation, dry-run, canary, and enabled state must be explicit.
4. Keep user-facing Creative simple: show supported models and parameters only after backend catalog resolution succeeds.
5. Treat labels as operational contracts: use stable, precise names such as “质量” for `quality`, and let schemas carry model-specific parameter differences.

## Accessibility & Inclusion

Target WCAG 2.1 AA for admin and embedded Creative flows. Settings controls must be keyboard reachable, labels must be explicit, disabled states must explain why an adapter or binding cannot be used, and motion should not be required to understand validation or rollout state.
