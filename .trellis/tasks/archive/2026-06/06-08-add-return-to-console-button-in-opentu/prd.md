# PRD: Add Return-to-Console Button in Opentu

## 1. Background

### Project Context
- **new-api**: Go-based API management console running at `http://localhost:3009`
- **opentu**: React/TypeScript canvas workspace application (v0.9.6)
- **Current Integration**: opentu is embedded at `/creative/` route in new-api via Go `embed.FS`

### Problem Statement
Users can navigate from new-api → opentu via the "Creative Workspace" menu, but there is **no way to return** from opentu → new-api without manually editing the browser URL or using browser back button.

### Current State (as of 2026-06-08)
✅ **Completed in Phase 0.5:**
- opentu successfully embedded at `/creative/` with correct base path
- "Creative Workspace" menu item in new-api sidebar
- External link navigation working (uses native `<a>` tag, not React Router)
- Git commits: `1ef09ca`, `1ce404f`, `b6aaa44`

❌ **Missing:**
- Return navigation from opentu → new-api

---

## 2. Objectives

### Primary Goal
Implement a **"返回控制台" (Return to Console)** button in opentu that:
1. Only appears when opentu is embedded in new-api
2. Navigates user back to new-api dashboard
3. Does not interfere with opentu's standalone usage

### Success Criteria
- Button visible when accessing `http://localhost:3009/creative/`
- Button **not** visible when accessing opentu standalone
- Clicking button navigates to `http://localhost:3009/dashboard`
- No visual regression in opentu UI
- Works across Chrome/Firefox/Safari

---

## 3. Requirements

### 3.1 Functional Requirements

**FR1: Environment Detection**
- opentu must detect if running in embedded mode
- Detection method: Check if `window.location.pathname` starts with `/creative/`
- Alternative: Use `VITE_PARENT_APP_URL` environment variable

**FR2: UI Component**
- Button component: `ReturnButton.tsx`
- Position: Fixed, top-left or top-right corner
- Style: Non-intrusive, semi-transparent background
- Text: "← 返回控制台" or icon + text
- Z-index: Above canvas content but below modals

**FR3: Navigation Behavior**
- Click handler: `window.location.href = '/dashboard'`
- No confirmation dialog (unless unsaved work detected in future iteration)
- Full page navigation (not SPA client-side routing)

**FR4: Conditional Rendering**
- `if (!isEmbedded) return null;`
- No performance impact when running standalone

### 3.2 Non-Functional Requirements

**NFR1: Performance**
- Detection logic runs once on mount, not per render
- Button rendering cost < 1ms

**NFR2: Maintainability**
- Self-contained component, no tight coupling to app logic
- Environment detection logic in dedicated utility function

**NFR3: Accessibility**
- Button has `aria-label="返回控制台"`
- Keyboard accessible (Tab + Enter)

---

## 4. Technical Design

### 4.1 Architecture

```
opentu (React App)
├── Environment Detection Layer
│   └── isEmbedded() → boolean
├── UI Layer
│   └── <ReturnButton />
└── Navigation Layer
    └── handleReturn() → window.location
```

### 4.2 Implementation Plan

**Step 1: Create Detection Utility**
```typescript
// apps/web/src/utils/embed-detection.ts
export function isEmbeddedInNewApi(): boolean {
  return window.location.pathname.startsWith('/creative/');
}
```

**Step 2: Create Button Component**
```typescript
// apps/web/src/components/ReturnButton.tsx
import { isEmbeddedInNewApi } from '../utils/embed-detection';

export function ReturnButton() {
  const isEmbedded = isEmbeddedInNewApi();
  
  if (!isEmbedded) return null;
  
  const handleReturn = () => {
    window.location.href = '/dashboard';
  };
  
  return (
    <button
      onClick={handleReturn}
      aria-label="返回控制台"
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
      }}
    >
      ← 返回控制台
    </button>
  );
}
```

**Step 3: Integrate into App**
```typescript
// apps/web/src/app/app.tsx
import { ReturnButton } from '../components/ReturnButton';

// In render function, add at top level:
<div className="app-root">
  <ReturnButton />
  {/* existing content */}
</div>
```

**Step 4: Rebuild and Deploy**
```bash
# Rebuild opentu
cd /mnt/f/code/project/opentu
export VITE_BASE_URL=/creative/
cd apps/web && pnpm run build

# Deploy to new-api
rsync -av --delete \
  /mnt/f/code/project/opentu/dist/apps/web/ \
  /mnt/f/code/project/new-api/web/creative/dist/

# Rebuild new-api
cd /mnt/f/code/project/new-api
go build -o /tmp/new-api-with-return .

# Restart
tmux kill-session -t newapi-demo
tmux new-session -d -s newapi-demo \
  "PORT=3009 SESSION_SECRET=demo /tmp/new-api-with-return"
```

---

## 5. Testing Plan

### 5.1 Unit Tests (if opentu has test suite)
```typescript
describe('ReturnButton', () => {
  it('renders when embedded', () => {
    // Mock pathname to /creative/
    expect(screen.getByRole('button')).toBeInTheDocument();
  });
  
  it('does not render when standalone', () => {
    // Mock pathname to /
    expect(screen.queryByRole('button')).toBeNull();
  });
});
```

### 5.2 Manual Testing Checklist
- [ ] Access `http://localhost:3009/creative/` → button appears
- [ ] Access opentu standalone → button does **not** appear
- [ ] Click button → navigates to `http://localhost:3009/dashboard`
- [ ] Button does not obstruct canvas drawing area
- [ ] Button visible on 1920x1080, 1366x768, 2560x1440 resolutions
- [ ] Works in Chrome, Firefox, Safari
- [ ] Keyboard navigation: Tab focuses button, Enter clicks

---

## 6. Key Files & Locations

### opentu Source Files
```
/mnt/f/code/project/opentu/
├── apps/web/
│   ├── src/
│   │   ├── app/app.tsx              # [MODIFY] Add <ReturnButton />
│   │   ├── components/              # [CREATE]
│   │   │   └── ReturnButton.tsx     # New component
│   │   └── utils/                   # [CREATE]
│   │       └── embed-detection.ts   # Detection logic
│   └── vite.config.ts               # Already configured with VITE_BASE_URL
└── dist/apps/web/                   # Build output
```

### new-api Integration Files
```
/mnt/f/code/project/new-api/
├── router/web-router.go             # Serves /creative/*
├── web/creative/dist/               # Deploy target for opentu build
│   ├── index.html
│   └── assets/
└── web/default/src/
    └── hooks/use-sidebar-data.ts    # Creative Workspace menu (already done)
```

---

## 7. Risks & Mitigation

| Risk | Impact | Mitigation |
|------|--------|------------|
| Button overlaps important UI | High | Position carefully, test on different screen sizes |
| Detection breaks with opentu updates | Medium | Use explicit env var `VITE_PARENT_APP_URL` instead of pathname check |
| Cross-origin navigation issues | Low | Use relative URL `/dashboard`, not absolute |
| State loss on navigation | Medium | Document this behavior; future enhancement can add confirmation dialog |

---

## 8. Future Enhancements

1. **Save State Before Return**: Auto-save canvas state to localStorage
2. **Confirmation Dialog**: If unsaved changes exist, prompt user
3. **Breadcrumb Navigation**: Show "new-api > Creative Workspace" path
4. **Keyboard Shortcut**: `Ctrl+Q` or `Esc` to return

---

## 9. Dependencies

- **Build Tools**: pnpm, vite, nx (already configured)
- **Runtime**: Modern browsers with ES2020 support
- **new-api**: Go 1.21+, port 3009
- **opentu**: v0.9.6 (current)

---

## 10. Acceptance Criteria

**Definition of Done:**
- [ ] `ReturnButton.tsx` component created
- [ ] `embed-detection.ts` utility created
- [ ] Component integrated into `app.tsx`
- [ ] opentu rebuilt with `VITE_BASE_URL=/creative/`
- [ ] Deployed to new-api and tested
- [ ] Button appears only in embedded mode
- [ ] Navigation works to `/dashboard`
- [ ] No visual regression in opentu
- [ ] Code committed with clear commit message

---

## 11. Timeline Estimate

- **Detection Logic**: 15 min
- **Button Component**: 30 min
- **Integration**: 15 min
- **Build & Deploy**: 20 min
- **Testing**: 30 min
- **Total**: ~2 hours

---

## 12. References

### Related Commits
- `1ef09ca`: Phase 0.5 initial integration
- `1ce404f`: External navigation support
- `b6aaa44`: Rebuild opentu with base=/creative/

### Related Files
- `/mnt/f/code/project/new-api/.trellis/tasks/task-opentu-return-button.md` (detailed implementation guide)
- `/mnt/f/code/project/new2fly/.trellis/tasks/06-08-add-return-to-console-button-in-opentu/` (this task)

### Documentation
- new-api: No formal docs, read `router/web-router.go` for routing logic
- opentu: No formal docs, monorepo structure with pnpm workspaces
- Integration assessment: `.trellis/tasks/06-07-opentu-new-api/integration-assessment.md`
