# Context: Add Return-to-Console Button

## Quick Start for Codex

**Task**: Add a "返回控制台" button in opentu that appears only when embedded in new-api.

**Key Files to Read First**:
1. `prd.md` - Full requirements
2. `/mnt/f/code/project/new-api/.trellis/tasks/task-opentu-return-button.md` - Implementation guide

**Implementation Summary**:
- Create `apps/web/src/components/ReturnButton.tsx` - UI component
- Create `apps/web/src/utils/embed-detection.ts` - Detection logic
- Modify `apps/web/src/app/app.tsx` - Integrate component
- Rebuild and deploy to new-api

---

## Project Structure

### new-api (Go Backend)
```
/mnt/f/code/project/new-api/
├── main.go
├── router/
│   └── web-router.go           # Serves /creative/* → embedded opentu
├── web/
│   ├── default/                # new-api React frontend
│   └── creative/dist/          # opentu build artifacts (embedded via go:embed)
└── .trellis/tasks/
    └── task-opentu-return-button.md  # Detailed guide
```

**Backend Routing**:
- `/` → new-api dashboard
- `/creative/` → opentu (embedded)
- `/creative/assets/*` → opentu static files

### opentu (React Frontend)
```
/mnt/f/code/project/opentu/
├── apps/web/
│   ├── src/
│   │   ├── main.tsx            # Entry point
│   │   ├── app/app.tsx         # Main app component (MODIFY HERE)
│   │   ├── components/         # (CREATE ReturnButton.tsx HERE)
│   │   └── utils/              # (CREATE embed-detection.ts HERE)
│   ├── vite.config.ts          # Has VITE_BASE_URL support
│   └── package.json
└── dist/apps/web/              # Build output (copy to new-api)
```

**Build System**:
- Monorepo: pnpm workspaces + nx
- Build command: `cd apps/web && pnpm run build`
- Output: `dist/apps/web/` (monorepo root)
- Current version: 0.9.6

---

## Current State (2026-06-08)

### ✅ Completed (Phase 0.5)
1. **opentu embedded in new-api**
   - Route: `/creative/`
   - Base path: `/creative/` (set via `VITE_BASE_URL`)
   - Backend: Go `embed.FS` serving static files
   
2. **Menu integration**
   - "Creative Workspace" menu item in new-api sidebar
   - Uses native `<a>` tag (not React Router) to avoid 404
   - File: `new-api/web/default/src/hooks/use-sidebar-data.ts`

3. **Navigation working**
   - new-api → opentu: Click menu ✅
   - opentu → new-api: **MISSING** ❌ (this task)

### Git History
```bash
git log --oneline -5
# b6aaa44 build(creative): rebuild opentu with base=/creative/
# 1ce404f fix(creative): support external navigation for Creative Workspace menu
# 1ef09ca feat(phase-0.5): add Creative Workspace menu and fix theme default
```

---

## Technical Details

### Environment Detection

**Strategy**: Check if `pathname` starts with `/creative/`

```typescript
// apps/web/src/utils/embed-detection.ts
export function isEmbeddedInNewApi(): boolean {
  return window.location.pathname.startsWith('/creative/');
}
```

**Why this works**:
- Standalone opentu: `pathname = /` or `/board/...`
- Embedded opentu: `pathname = /creative/` or `/creative/board/...`

**Alternative** (if pathname check is unreliable):
```typescript
// Use environment variable
const PARENT_URL = import.meta.env.VITE_PARENT_APP_URL;
export function isEmbeddedInNewApi(): boolean {
  return !!PARENT_URL;
}
```

### Navigation Implementation

```typescript
const handleReturn = () => {
  // Relative URL - works regardless of domain
  window.location.href = '/dashboard';
  
  // Or use absolute URL from env
  // window.location.href = import.meta.env.VITE_PARENT_APP_URL || '/';
};
```

**Why `window.location.href` (not React Router)**:
- opentu and new-api are separate SPAs
- Need full page navigation, not client-side routing
- Same pattern as new-api → opentu navigation

---

## Build & Deploy Process

### Step 1: Modify opentu Source
```bash
cd /mnt/f/code/project/opentu/apps/web/src

# Create files:
# - components/ReturnButton.tsx
# - utils/embed-detection.ts

# Modify:
# - app/app.tsx (add <ReturnButton />)
```

### Step 2: Rebuild opentu
```bash
cd /mnt/f/code/project/opentu
export VITE_BASE_URL=/creative/
cd apps/web
pnpm run build  # Output: ../../dist/apps/web/
```

### Step 3: Deploy to new-api
```bash
rsync -av --delete \
  /mnt/f/code/project/opentu/dist/apps/web/ \
  /mnt/f/code/project/new-api/web/creative/dist/
```

### Step 4: Rebuild new-api Binary
```bash
cd /mnt/f/code/project/new-api
go build -o /tmp/new-api-with-return .
```

### Step 5: Restart Service
```bash
tmux kill-session -t newapi-demo
tmux new-session -d -s newapi-demo \
  "cd /mnt/f/code/project/new-api && PORT=3009 SESSION_SECRET=demo /tmp/new-api-with-return"
```

### Step 6: Verify
```bash
# Test embedded mode
curl -s http://localhost:3009/creative/ | grep -o "返回控制台"

# Browser test:
# 1. Open http://localhost:3009/creative/
# 2. Button should appear in top-left/right
# 3. Click → navigates to http://localhost:3009/dashboard
```

---

## UI Design Reference

### Recommended Style (from PRD)
```typescript
<button
  style={{
    position: 'fixed',
    top: '16px',
    left: '16px',
    zIndex: 9999,
    padding: '8px 16px',
    background: 'rgba(0, 0, 0, 0.7)',
    color: 'white',
    border: 'none',
    borderRadius: '6px',
    cursor: 'pointer',
    fontSize: '14px',
    fontFamily: 'system-ui, sans-serif',
    transition: 'background 0.2s',
  }}
  onMouseEnter={(e) => e.currentTarget.style.background = 'rgba(0, 0, 0, 0.85)'}
  onMouseLeave={(e) => e.currentTarget.style.background = 'rgba(0, 0, 0, 0.7)'}
>
  ← 返回控制台
</button>
```

**Design Constraints**:
- Must not obstruct canvas drawing area
- Should be obvious but not intrusive
- Dark semi-transparent background (works on light/dark canvas)
- Fixed position (stays visible during scroll/zoom)

---

## Testing Checklist

### Functional Tests
- [ ] Button appears at `http://localhost:3009/creative/`
- [ ] Button **does not** appear when accessing opentu standalone
- [ ] Clicking button navigates to `http://localhost:3009/dashboard`
- [ ] Button is keyboard accessible (Tab + Enter)

### Visual Tests
- [ ] Button does not overlap important UI elements
- [ ] Readable on both light and dark canvas backgrounds
- [ ] Responsive across screen sizes (1366x768, 1920x1080, 2560x1440)
- [ ] Hover effect works smoothly

### Cross-Browser Tests
- [ ] Chrome 120+
- [ ] Firefox 120+
- [ ] Safari 17+ (if available)

---

## Common Issues & Solutions

### Issue 1: Button not appearing in embedded mode
**Cause**: Detection logic failing  
**Debug**: Console log `window.location.pathname` in opentu  
**Fix**: Check if pathname actually starts with `/creative/`

### Issue 2: Build output missing button
**Cause**: Component not imported in app.tsx  
**Debug**: Check `dist/apps/web/assets/index-*.js` for "返回控制台"  
**Fix**: Verify import and JSX in app.tsx

### Issue 3: Button appears in standalone mode
**Cause**: Detection logic inverted or broken  
**Debug**: Test `isEmbeddedInNewApi()` return value  
**Fix**: Review detection logic, add unit test

### Issue 4: Navigation not working
**Cause**: Incorrect URL or SPA routing intercepting  
**Debug**: Check browser console for errors  
**Fix**: Use `window.location.href = '/dashboard'` (not `history.push`)

---

## Code Review Checklist

- [ ] `ReturnButton.tsx` has TypeScript types
- [ ] Component has proper conditional rendering
- [ ] Detection logic is in separate utility file
- [ ] No magic numbers (use constants for z-index, padding, etc.)
- [ ] Accessibility: `aria-label` present
- [ ] No console.log statements left in production code
- [ ] Component is self-contained (no global state dependencies)

---

## Handoff Notes

**For Codex Developer**:

1. **Read First**: `prd.md` for requirements, then the implementation guide in `new-api/.trellis/tasks/`

2. **Project Locations**:
   - opentu source: `/mnt/f/code/project/opentu/`
   - new-api source: `/mnt/f/code/project/new-api/`
   - Task docs: `/mnt/f/code/project/new2fly/.trellis/tasks/06-08-add-return-to-console-button-in-opentu/`

3. **Build Environment**:
   - Node.js: v20+
   - pnpm: v10.21.0
   - Go: v1.21+
   - Tools: tmux (for service management)

4. **Current Service**:
   - new-api running in tmux session `newapi-demo`
   - Port: 3009
   - To check: `tmux ls`
   - To attach: `tmux attach -t newapi-demo`

5. **Verification URL**: http://localhost:3009/creative/

6. **If Stuck**:
   - Check `implement.jsonl` for key files to read
   - Review git commits for Phase 0.5 integration patterns
   - The navigation pattern (external link) is already working for new-api → opentu

**Estimated Time**: 2 hours (implementation + testing)

**Priority**: Medium (UX improvement, not blocking functionality)

**Success Metric**: User can click "返回控制台" button in opentu and return to new-api dashboard.

---

## References

- **Integration Assessment**: `/mnt/f/code/project/new2fly/.trellis/tasks/06-07-opentu-new-api/integration-assessment.md`
- **Phase 0.5 Commits**: `b6aaa44`, `1ce404f`, `1ef09ca`
- **Trellis Workflow**: `/mnt/f/code/project/new2fly/.trellis/workflow.md`

