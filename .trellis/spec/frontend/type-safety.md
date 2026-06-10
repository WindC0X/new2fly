# Type Safety

> Type safety patterns in this project.

---

## Overview

<!--
Document your project's type safety conventions here.

Questions to answer:
- What type system do you use?
- How are types organized?
- What validation library do you use?
- How do you handle type inference?
-->

(To be filled by the team)

---

## Type Organization

<!-- Where types are defined, shared types vs local types -->

(To be filled by the team)

---

## Validation

<!-- Runtime validation patterns (Zod, Yup, io-ts, etc.) -->

(To be filled by the team)

---

## Common Patterns

<!-- Type utilities, generics, type guards -->

### Test Fixture Type-Safety for Drawnix Follow-ups

When fixing or adding Drawnix test fixtures under the sibling `opentu/packages/drawnix` package, prefer precise fixture types over TypeScript suppressions. The `tsconfig.spec.json --noEmit` gate is expected to compile tests as strictly as production-adjacent code.

Use these patterns:

- Keep fixtures aligned with current domain contracts such as `ModelVendor`, `ProviderProfile`, `ProviderCatalog`, `ProviderCapabilities`, `WorkflowContext`, and workspace create-option types. Do not keep stale string/object shapes after the source type changes.
- Type Vitest mocks with their real function signatures when assertions read `mock.calls`, for example `vi.fn<typeof fetch>(...)` plus a small helper that returns `Parameters<typeof fetch>`.
- For `mock.calls[0]` access, use narrow helpers that throw if the call is missing instead of indexing an untyped or zero-argument mock tuple.
- For intentionally malformed external data tests, use a local helper with a narrow `unknown` cast to the target partial type. Keep the invalid-input assertion; do not weaken the production type to make the test compile.
- For geometry/Plait fixtures, preserve literal and tuple types (`type: 'frame'`, `[Point, Point]`) so tests exercise the same shapes production utilities expect.
- For optional/unknown result payloads, assert with `toMatchObject` or introduce a local typed result helper instead of assuming `unknown` has properties.

Example:

```ts
type FetchMock = ReturnType<typeof vi.fn<typeof fetch>>;
type FetchCall = Parameters<typeof fetch>;

function getFetchCall(fetcher: FetchMock, index = 0): FetchCall {
  const call = fetcher.mock.calls[index];
  if (!call) {
    throw new Error(`Expected fetch call #${index + 1}`);
  }
  return call;
}
```

Security-sensitive creative embedded tests must keep the original assertion intent while applying these patterns. In particular, no-secret/no-provider-leak checks for upstream API keys, base URLs, `Authorization`, and provider overrides must remain meaningful.

---

## Forbidden Patterns

<!-- any, type assertions, etc. -->

For Drawnix spec-test type fixes:

- Do not add `skipLibCheck`, new broad excludes, or loosen `tsconfig.spec.json` to hide fixture drift.
- Do not add blanket `any`, `@ts-ignore`, or broad `@ts-expect-error` just to satisfy the spec compiler.
- Do not delete security assertions or invalid-input cases to make a test type-check. Express the external data boundary with a narrow local helper instead.
