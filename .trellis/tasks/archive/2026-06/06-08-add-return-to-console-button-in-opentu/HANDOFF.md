# Codex Handoff Checklist

## Task Overview
**Goal**: Implement "返回控制台" button in opentu for embedded mode  
**Status**: Ready for implementation  
**Priority**: Medium (UX enhancement)  
**Est. Time**: 2 hours

---

## Pre-Implementation: Read These (in order)

1. ✅ `QUICK_START.md` - 5 min overview
2. ✅ `prd.md` - Full requirements (15 min)
3. ✅ `context.md` - Project context and architecture (10 min)
4. ✅ `/mnt/f/code/project/new-api/.trellis/tasks/task-opentu-return-button.md` - Detailed guide

**Total reading time**: ~30 min

---

## Key Facts

### Project Locations
```
opentu source:  /mnt/f/code/project/opentu/
new-api source: /mnt/f/code/project/new-api/
task docs:      /mnt/f/code/project/new2fly/.trellis/tasks/06-08-add-return-to-console-button-in-opentu/
```

### Current Status (as of 2026-06-08)
- ✅ opentu embedded at `/creative/` with correct base path
- ✅ Menu navigation (new-api → opentu) working
- ❌ Return navigation (opentu → new-api) **MISSING** ← your task

### Tech Stack
- **opentu**: React + TypeScript + Vite + pnpm + nx
- **new-api**: Go 1.21 + embed.FS
- **Runtime**: Chrome/Firefox/Safari, Node v20+

---

## Implementation Checklist

### Phase 1: Read & Understand (30 min)
- [ ] Read `QUICK_START.md`
- [ ] Read `prd.md` sections 1-4
- [ ] Skim `context.md` "Project Structure" section
- [ ] Check `implement.jsonl` for key files to read
- [ ] Open opentu in browser: http://localhost:3009/creative/

### Phase 2: Code (45 min)
- [ ] Create `apps/web/src/utils/embed-detection.ts`
- [ ] Create `apps/web/src/components/ReturnButton.tsx`
- [ ] Modify `apps/web/src/app/app.tsx` to integrate button
- [ ] Verify TypeScript compiles: `cd apps/web && pnpm run type-check`

### Phase 3: Build & Deploy (20 min)
- [ ] Set env: `export VITE_BASE_URL=/creative/`
- [ ] Build opentu: `cd apps/web && pnpm run build`
- [ ] Verify dist: `ls /mnt/f/code/project/opentu/dist/apps/web/index.html`
- [ ] Deploy: `rsync -av --delete opentu/dist/apps/web/ new-api/web/creative/dist/`
- [ ] Rebuild new-api: `cd new-api && go build -o /tmp/new-api-test .`
- [ ] Restart service (see commands in QUICK_START.md)

### Phase 4: Test (25 min)
- [ ] **Embedded mode**: Open http://localhost:3009/creative/
  - [ ] Button appears in top-left
  - [ ] Click → navigates to /dashboard
- [ ] **Standalone mode**: Open opentu directly (if available)
  - [ ] Button does NOT appear
- [ ] **Cross-browser**: Test Chrome + Firefox
- [ ] **Responsive**: Test on different window sizes
- [ ] **Keyboard**: Tab to button, press Enter → works

### Phase 5: Documentation & Handoff (10 min)
- [ ] Fill out `check.jsonl` with verification notes
- [ ] List any issues encountered
- [ ] Take screenshot of button in action
- [ ] Commit changes with clear message

---

## Success Criteria (from PRD)

Must have ALL of these:
- [ ] Button visible when accessing via new-api (`/creative/`)
- [ ] Button NOT visible in standalone mode
- [ ] Clicking button navigates to `/dashboard`
- [ ] No visual regression (opentu UI intact)
- [ ] TypeScript types correct, no `any`
- [ ] Code follows opentu conventions

---

## Common Pitfalls

### ❌ Don't Do This:
1. Use React Router for navigation (use `window.location.href`)
2. Hardcode absolute URLs like `http://localhost:3009/dashboard`
3. Put detection logic inline in component (use utility function)
4. Forget to set `VITE_BASE_URL=/creative/` during build
5. Skip testing standalone mode

### ✅ Do This:
1. Use relative URL: `/dashboard`
2. Extract detection to `embed-detection.ts`
3. Add `aria-label` for accessibility
4. Test both embedded and standalone modes
5. Verify build output before deploying

---

## File Change Summary

**New files** (create these):
- `apps/web/src/utils/embed-detection.ts` (~5 lines)
- `apps/web/src/components/ReturnButton.tsx` (~30 lines)

**Modified files**:
- `apps/web/src/app/app.tsx` (+2 lines: import + JSX)

**Build artifacts** (auto-generated):
- `dist/apps/web/assets/index-*.js` (contains button code)

---

## If You Get Stuck

### Issue: pnpm build fails
**Solution**: 
```bash
cd /mnt/f/code/project/opentu
pnpm install
cd apps/web && pnpm run type-check
```

### Issue: Button not appearing
**Debug**:
```typescript
// In ReturnButton.tsx, add:
console.log('isEmbedded:', isEmbeddedInNewApi());
console.log('pathname:', window.location.pathname);
```

### Issue: Build output in wrong location
**Check**: Output should be `/mnt/f/code/project/opentu/dist/apps/web/` (monorepo root, not `apps/web/dist/`)

### Issue: Can't restart service
**Check**:
```bash
tmux ls  # List sessions
tmux attach -t newapi-demo  # Attach to see logs
# Ctrl+C to stop, then re-run start command
```

---

## Verification Commands

```bash
# 1. Check if button code exists in build
grep "返回控制台" /mnt/f/code/project/opentu/dist/apps/web/assets/index-*.js

# 2. Check if deployed to new-api
grep "返回控制台" /mnt/f/code/project/new-api/web/creative/dist/assets/index-*.js

# 3. Check service is running
curl -s http://localhost:3009/creative/ | grep "Opentu"

# 4. Check button appears
curl -s http://localhost:3009/creative/ | grep "返回控制台"
```

---

## Final Deliverables

When complete, ensure these exist:
- [ ] `/mnt/f/code/project/opentu/apps/web/src/components/ReturnButton.tsx`
- [ ] `/mnt/f/code/project/opentu/apps/web/src/utils/embed-detection.ts`
- [ ] Modified `/mnt/f/code/project/opentu/apps/web/src/app/app.tsx`
- [ ] Updated `/mnt/f/code/project/new-api/web/creative/dist/` with new build
- [ ] Passing all tests in "Testing Checklist" (prd.md section 5)

---

## Contact / Questions

If you encounter blocking issues:
1. Check `context.md` "Common Issues & Solutions"
2. Review git history: `git log --oneline -10`
3. Check related commits: `b6aaa44`, `1ce404f`, `1ef09ca`

---

## Task Metadata

- **Created**: 2026-06-08
- **Assigned to**: Codex (external)
- **Task ID**: 06-08-add-return-to-console-button-in-opentu
- **Parent Project**: new2fly opentu integration (Phase 0.5)
- **Dependencies**: None (Phase 0.5 complete)
- **Blocks**: Task #5 (Dual-model audit)

---

Good luck! 🚀
