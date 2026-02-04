# Category 2: Storage - Audit

> Audit Date: 2026-02-04
> React Native Files: 4
> Swift Equivalents: Partial (using SwiftData instead of AsyncStorage)

---

## File 1: `src/storage/tasks.ts`

### Data Model

| RN Field | Type | Swift Equivalent | Status |
|----------|------|------------------|--------|
| `id` | string | `FocusTask.id: UUID` | ✅ |
| `title` | string | `FocusTask.title: String` | ✅ |
| `icon` | string | Missing | ❌ Not needed (SF Symbols) |

### Functions

| RN Function | Purpose | Swift Equivalent | Status |
|-------------|---------|------------------|--------|
| `getTasks()` | Get all tasks, returns DEFAULT if empty | `@Query var tasks` | ⚠️ No default task |
| `upsertTask(task)` | Add or update task | `modelContext.insert()` | ✅ |
| `renameTask(id, title)` | Change task title | Direct property edit | ✅ |
| `deleteTask(id)` | Remove task, restore default if empty | `modelContext.delete()` | ⚠️ No default restore |
| `TASKS_CHANGED_EVENT` | Event emitter for changes | SwiftData auto-updates | ✅ Auto |

### Constants

| RN Constant | Value | Swift Equivalent | Status |
|-------------|-------|------------------|--------|
| `DEFAULT_TASKS` | `[{ id: 'other', title: 'Other', icon: 'refresh-outline' }]` | Missing | ❌ Missing |

### Issues Found
- [ ] No default "Other" task when task list is empty
- [ ] Delete doesn't restore default task
- [ ] RN emits events on change, Swift uses SwiftData observation (OK)

---

## File 2: `src/storage/settings.ts`

### Settings Comparison

| RN Setting | RN Default | Swift Setting | Swift Default | Status |
|------------|------------|---------------|---------------|--------|
| `autoStartBreak` | **true** | `autoStartBreaks` | **false** | ❌ MISMATCH |
| `focusMin` | 25 | `focusDuration` (seconds) | 25*60 | ✅ |
| `breakMin` | 5 | `breakDuration` (seconds) | 5*60 | ✅ |
| `appearance` | 'system' | `theme` | .system | ✅ |
| `soundKey` | 'chimes' | Missing | - | ❌ Missing |

### Functions

| RN Function | Purpose | Swift Equivalent | Status |
|-------------|---------|------------------|--------|
| `getAutoStartBreak()` | Get auto-start setting | `settings.autoStartBreaks` | ⚠️ Different default |
| `setAutoStartBreak(v)` | Set auto-start | Direct property | ✅ |
| `getFocusMinutes()` | Get focus duration | `settings.focusDurationMinutes` | ✅ |
| `setFocusMinutes(min)` | Set focus duration (min 1) | Direct property | ⚠️ No min validation |
| `getBreakMinutes()` | Get break duration | `settings.breakDurationMinutes` | ✅ |
| `setBreakMinutes(min)` | Set break duration (min 1) | Direct property | ⚠️ No min validation |
| `getSoundKey()` | Get selected sound | Missing | ❌ Missing |
| `setSoundKey(key)` | Set selected sound | Missing | ❌ Missing |
| `getAppearanceMode()` | Get theme | `settings.theme` | ✅ |
| `setAppearanceMode(m)` | Set theme | Direct property | ✅ |

### Issues Found
- [ ] **CRITICAL**: autoStartBreak default is TRUE in RN, FALSE in Swift
- [ ] soundKey setting missing - user can't select notification sound
- [ ] No minimum value validation (RN enforces min 1 minute)

---

## File 3: `src/storage/progressStore.ts`

### Data Model

```typescript
// RN: Daily aggregates stored as single object
type DailyTotals = Record<string, { focus: number; break: number }>;
// e.g., { "2026-02-04": { focus: 1500, break: 300 } }
```

```swift
// Swift: Individual records, aggregated at query time
@Model class FocusRecord {
    var date: Date
    var duration: Int
    var isBreak: Bool
    // ... more fields
}
```

### Functions

| RN Function | Purpose | Swift Equivalent | Status |
|-------------|---------|------------------|--------|
| `addSessionSeconds(type, secs, at)` | Add seconds to daily total | Insert FocusRecord + view aggregates | ⚠️ Different approach |
| `setDayTotals(dateKey, focus, brk)` | Set day totals | N/A (append-only in Swift) | ❌ Different model |
| `getDayTotals(dateKey)` | Get single day stats | View computes from records | ⚠️ Different approach |
| `getRangeTotals(start, end)` | Get range of days | View computes from records | ⚠️ Different approach |
| `clearAllProgress()` | Delete all progress | Missing | ❌ Missing |
| `PROGRESS_UPDATED_EVENT` | Event for updates | SwiftData observation | ✅ Auto |

### Issues Found
- [ ] Different storage model (OK - SwiftData is better)
- [ ] `clearAllProgress()` function missing
- [ ] Need to verify chart aggregation matches RN behavior

---

## File 4: `src/storage/sessionStore.ts`

### Data Model

```typescript
// RN
type Session = {
  type: 'focus' | 'break';
  seconds: number;
  at: string; // ISO timestamp
};
```

```swift
// Swift - FocusRecord serves same purpose
@Model class FocusRecord {
    var date: Date        // = at
    var duration: Int     // = seconds
    var isBreak: Bool     // = type == 'break'
    // ... additional fields
}
```

### Functions

| RN Function | Purpose | Swift Equivalent | Status |
|-------------|---------|------------------|--------|
| `appendSession(type, secs, at)` | Log session | `modelContext.insert(FocusRecord(...))` | ✅ |
| `getSessionStatsInRange(start, end)` | Get stats: count, avg, longest | Missing | ❌ Missing |
| `clearAllSessions()` | Delete all sessions | Missing | ❌ Missing |
| `clearSessions()` | Delete all sessions | Missing | ❌ Missing |

### Stats Return Object (RN)

```typescript
{ sessionsCompleted: number, avgSession: number, longestSession: number }
```

### Issues Found
- [ ] `getSessionStatsInRange()` not implemented - Progress stats will be wrong
- [ ] `clearAllSessions()` not implemented - Can't reset data

---

## Summary

| File | Functions | Implemented | Missing | Buggy |
|------|-----------|-------------|---------|-------|
| tasks.ts | 5 | 3 | 2 | 0 |
| settings.ts | 10 | 6 | 2 | 2 |
| progressStore.ts | 6 | 0* | 1 | 0 |
| sessionStore.ts | 4 | 1 | 3 | 0 |

*Different storage model (SwiftData vs AsyncStorage aggregates)

**CRITICAL ISSUES:**
1. `autoStartBreak` default mismatch (true vs false)
2. `soundKey` setting completely missing
3. `getSessionStatsInRange()` missing - breaks Progress screen stats
4. `clearAllProgress()` / `clearAllSessions()` missing

---

## Implementation Plan

1. **Fix autoStartBreaks default** - Change to `true` to match RN
2. **Add soundKey setting** - Add property to UserSettings
3. **Add session stats function** - Create `FocusRecord.getStatsInRange()`
4. **Add clear functions** - Add delete-all capabilities
5. **Add default task** - Create "Other" task if none exist
6. **Add min validation** - Enforce min 1 minute for durations

---

## Tests Required

1. Verify autoStartBreaks loads as true by default
2. Verify soundKey can be get/set
3. Verify getSessionStatsInRange returns correct values
4. Verify clear functions delete all data
5. Verify default task created when list empty
