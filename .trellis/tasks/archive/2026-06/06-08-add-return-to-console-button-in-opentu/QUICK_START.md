# Quick Start: Return Button Implementation

## TL;DR
Add a "返回控制台" button to opentu that only shows when embedded in new-api at `/creative/`.

---

## 3 Files to Create/Modify

### 1. Create: `apps/web/src/utils/embed-detection.ts`
```typescript
export function isEmbeddedInNewApi(): boolean {
  return window.location.pathname.startsWith('/creative/');
}
```

### 2. Create: `apps/web/src/components/ReturnButton.tsx`
```typescript
import { isEmbeddedInNewApi } from '../utils/embed-detection';

export function ReturnButton() {
  const isEmbedded = isEmbeddedInNewApi();
  
  if (!isEmbedded) return null;
  
  return (
    <button
      onClick={() => window.location.href = '/dashboard'}
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
      }}
    >
      ← 返回控制台
    </button>
  );
}
```

### 3. Modify: `apps/web/src/app/app.tsx`
```typescript
// Add import at top
import { ReturnButton } from '../components/ReturnButton';

// Add in render (near top of JSX tree):
<div className="app-root">
  <ReturnButton />
  {/* existing content */}
</div>
```

---

## Build & Deploy Commands

```bash
# 1. Rebuild opentu
cd /mnt/f/code/project/opentu
export VITE_BASE_URL=/creative/
cd apps/web && pnpm run build

# 2. Deploy to new-api
rsync -av --delete \
  /mnt/f/code/project/opentu/dist/apps/web/ \
  /mnt/f/code/project/new-api/web/creative/dist/

# 3. Rebuild new-api
cd /mnt/f/code/project/new-api
go build -o /tmp/new-api-with-return .

# 4. Restart service
tmux kill-session -t newapi-demo
tmux new-session -d -s newapi-demo \
  "cd /mnt/f/code/project/new-api && PORT=3009 SESSION_SECRET=demo /tmp/new-api-with-return"
```

---

## Test

1. Open: http://localhost:3009/creative/
2. Look for "← 返回控制台" button in top-left
3. Click → should navigate to http://localhost:3009/dashboard

---

## Full Docs

- **Requirements**: `prd.md`
- **Context**: `context.md`
- **Implementation Guide**: `/mnt/f/code/project/new-api/.trellis/tasks/task-opentu-return-button.md`
