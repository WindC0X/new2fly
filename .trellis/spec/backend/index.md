# Backend Development Guidelines

> Best practices for backend development in this project.

---

## Overview

This directory contains guidelines for backend development. Fill in each file with your project's specific conventions.

---

## Guidelines Index

| Guide | Description | Status |
|-------|-------------|--------|
| [Directory Structure](./directory-structure.md) | Module organization and file layout | To fill |
| [Database Guidelines](./database-guidelines.md) | ORM patterns, queries, migrations | To fill |
| [Error Handling](./error-handling.md) | Error types, handling strategies | To fill |
| [Quality Guidelines](./quality-guidelines.md) | Code standards, forbidden patterns | To fill |
| [Logging Guidelines](./logging-guidelines.md) | Structured logging, log levels | To fill |
| [Creative Backend Security Boundary](./creative-backend-security-boundary.md) | Shared `/creative/api` and `/creative/relay/v1` route, cache, origin, denylist, DTO, and proxy hardening contract | Active |
| [Creative Async Task Billing Consistency](./creative-async-task-billing-consistency.md) | Creative async submit, idempotency, billing outbox, terminal CAS, and selected-key affinity contract | Active |
| [Creative Asset Sync](./creative-asset-sync.md) | `/creative/api/assets` API, storage, DB, and secret-safety contract | Active |
| [Creative Async Video Relay](./creative-async-video-relay.md) | `/creative/relay/v1/videos` session-broker async video, idempotency, billing/CAS, and key-affinity contract | Active |
| [Creative Async Suno Relay](./creative-async-suno-relay.md) | `/creative/relay/v1/suno` session-broker async Suno, server-side action/model inference, idempotency, billing/CAS, and key-affinity contract | Active |
| [Creative Async MJ Relay](./creative-async-mj-relay.md) | `/creative/relay/v1/mj` session-broker async Midjourney imagine, owner-scoped fetch/image proxy, idempotency, billing/CAS, and key-affinity contract | Active |

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
