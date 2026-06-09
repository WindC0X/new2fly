# Task: Add Return-to-Console Button in Opentu

**Status**: 📋 Ready for Implementation (Codex Handoff)  
**Created**: 2026-06-08  
**Priority**: Medium  
**Est. Time**: 2 hours

---

## Quick Links

| Document | Purpose | Read Time |
|----------|---------|-----------|
| **[QUICK_START.md](./QUICK_START.md)** | 5-min implementation guide | 5 min |
| **[HANDOFF.md](./HANDOFF.md)** | Step-by-step checklist for Codex | 5 min |
| **[prd.md](./prd.md)** | Full requirements & acceptance criteria | 15 min |
| **[context.md](./context.md)** | Project architecture & current state | 10 min |
| **[SUMMARY.md](./SUMMARY.md)** | Phase 0.5 completion & handoff summary | 10 min |

---

## What This Task Does

Add a "返回控制台" (Return to Console) button in opentu that:
- ✅ Only appears when opentu is embedded in new-api at `/creative/`
- ✅ Navigates user back to new-api dashboard when clicked
- ✅ Does not interfere with opentu standalone usage

---

## For Codex: Start Here

1. Read **[QUICK_START.md](./QUICK_START.md)** first (5 min)
2. Review **[HANDOFF.md](./HANDOFF.md)** checklist (5 min)
3. Implement 3 files (see QUICK_START)
4. Build, deploy, test
5. Report completion

---

## Task Context

This task is part of **Phase 0.5: opentu Integration** into new-api.

**Previous work (already done by Claude)**:
- ✅ opentu embedded at `/creative/` with correct base path
- ✅ Creative Workspace menu added to new-api sidebar
- ✅ Navigation from new-api → opentu working

**This task (for Codex)**:
- ❌ Navigation from opentu → new-api (missing)

---

## File Overview

```
.
├── README.md              ← You are here
├── QUICK_START.md         ← Start with this
├── HANDOFF.md             ← Checklist for implementation
├── prd.md                 ← Full requirements
├── context.md             ← Project architecture
├── SUMMARY.md             ← Phase 0.5 completion summary
├── implement.jsonl        ← Files to read during implementation
├── check.jsonl            ← Files to verify after implementation
└── task.json              ← Trellis task metadata
```

---

## Success Criteria

✅ Task is complete when:
- Button appears at http://localhost:3009/creative/
- Button does NOT appear in standalone opentu
- Clicking button navigates to http://localhost:3009/dashboard
- No visual regression in opentu UI
- All tests pass (see prd.md section 5)

---

## Related Documentation

- **Implementation Guide**: `/mnt/f/code/project/new-api/.trellis/tasks/task-opentu-return-button.md`
- **Integration Assessment**: `/mnt/f/code/project/new2fly/.trellis/tasks/06-07-opentu-new-api/integration-assessment.md`
- **Phase 0.5 Commits**: `b6aaa44`, `1ce404f`, `1ef09ca`

---

## Questions?

Check **[context.md](./context.md)** section "Common Issues & Solutions" or review git history for Phase 0.5 integration patterns.

---

**Ready to start? Open [QUICK_START.md](./QUICK_START.md) →**
