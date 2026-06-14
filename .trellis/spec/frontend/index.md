# Frontend Development Guidelines

> Best practices for frontend development in this project.

---

## Overview

This directory contains guidelines for frontend development. Fill in each file with your project's specific conventions.

---

## Guidelines Index

| Guide | Description | Status |
|-------|-------------|--------|
| [Directory Structure](./directory-structure.md) | Module organization and file layout | To fill |
| [Component Guidelines](./component-guidelines.md) | Component patterns, props, composition | To fill |
| [Hook Guidelines](./hook-guidelines.md) | Custom hooks, data fetching patterns | To fill |
| [State Management](./state-management.md) | Local state, global state, server state | To fill |
| [Quality Guidelines](./quality-guidelines.md) | Code standards, forbidden patterns | To fill |
| [Type Safety](./type-safety.md) | Type patterns, validation, Drawnix spec-test fixture contracts | Active |
| [Creative Asset Sync](./creative-asset-sync.md) | Opentu asset prepare/hydrate, sanitizer, and service-worker pass-through contract | Active |
| [Creative Async Video Relay](./creative-async-video-relay.md) | Opentu session-broker async video paths, idempotency, no-fallback, and credential-stripping contract | Active |
| [Creative Async Suno Relay](./creative-async-suno-relay.md) | Opentu session-broker Suno paths, empty-key handling, idempotency propagation, unsupported no-fallback, and credential-stripping contract | Active |
| [Creative Async MJ Relay](./creative-async-mj-relay.md) | Opentu session-broker MJ paths, stable image idempotency, no-fallback unsupported handling, and credential-stripping contract | Active |
| [Creative Embedded Release Artifact](./creative-embedded-release-artifact.md) | Opentu `/creative/` production build, dist sync, embedded smoke, and managed model policy/fail-closed contract | Active |

---

## How to Fill These Guidelines

For each guideline file:

1. Document your project's **actual conventions** (not ideals)
2. Include **code examples** from your codebase
3. List **forbidden patterns** and why
4. Add **common mistakes** your team has made

The goal is to help AI assistants and new team members understand how YOUR project works.

---

**Language**: All documentation should be written in **English**.
