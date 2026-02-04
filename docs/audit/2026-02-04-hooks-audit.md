# Category 7: Hooks & Other - Audit

> Audit Date: 2026-02-04
> React Native Files: 1 hook file
> Swift Equivalents: Logic embedded in views

---

## File 1: `useProgress.ts`

### RN Features

| Feature | RN Implementation | Swift Equivalent | Status |
|---------|-------------------|------------------|--------|
| View mode state | `useState<ViewMode>('Daily')` | `@State selectedTab: ProgressTab` | ✅ |
| Anchor date state | `useState<Date>(new Date())` | N/A (charts compute internally) | ❌ Missing |
| Title computation | Dynamic "Today"/"Yesterday"/date range | N/A | ❌ Missing |
| Period navigation | `goPrev()`, `goNext()`, `canGoNext` | N/A | ❌ Missing |
| Sessions completed | `stats.sessionsCompleted` | `totalSessions` (all-time) | ⚠️ Different scope |
| Average session | `stats.avgSession` | **Missing** | ❌ |
| Longest session | `stats.longestSession` | **Missing** | ❌ |
| Summary focus/break | Period-specific totals | All-time totals | ⚠️ Different scope |
| Series data | Computed per period | Charts compute internally | ✅ Different approach |
| Live refresh | `DeviceEventEmitter` listener | `@Query` auto-updates | ✅ |

### RN Stats Calculation (from sessionStore)

```typescript
// getSessionStatsInRange(start: Date, end: Date)
// Returns: { sessionsCompleted, avgSession, longestSession }

// sessionsCompleted = count of sessions in range
// avgSession = totalSeconds / sessionsCompleted (in seconds)
// longestSession = max duration of any session (in seconds)
```

### Issues Found

1. **❌ Period navigation missing** - No way to view past days/weeks/months
2. **❌ avgSession stat missing** - Swift doesn't calculate average
3. **❌ longestSession stat missing** - Swift doesn't track longest
4. **⚠️ Stats are all-time instead of period-specific** - Charts show period data but stats don't match

### RN Period Title Logic

```typescript
const title = useMemo(() => {
  if (mode === 'Daily') {
    if (anchorKey === todayKey) return 'Today';
    if (toISODate(addDays(new Date(), -1)) === anchorKey) return 'Yesterday';
    return anchor.toLocaleDateString(...);
  }
  if (mode === 'Weekly') {
    // "Mar 4 – Mar 10" format
  }
  return `${monthName(anchor)} ${anchor.getFullYear()}`;
}, [mode, anchor]);
```

---

## Summary

| Feature Category | RN Features | Swift Implemented | Missing |
|------------------|-------------|-------------------|---------|
| View Mode | 1 | 1 | 0 |
| Navigation | 3 (prev/next/canGoNext) | 0 | 3 |
| Title Display | 1 | 0 | 1 |
| Period Stats | 3 | 0 | 3 |
| All-time Stats | 0 | 4 | N/A |
| Live Updates | 1 | 1 | 0 |

**CRITICAL ISSUES:**

1. **Period navigation** - Users can't view historical data
2. **Period-specific stats** - Stats don't match the selected chart period

**MEDIUM ISSUES:**

1. avgSession and longestSession stats not displayed

---

## Implementation Plan

### Priority 1: Add Period-Specific Stats to FocusRecord

Add static method to compute stats for a date range:

```swift
extension FocusRecord {
    static func getStatsInRange(records: [FocusRecord], start: Date, end: Date) -> (sessions: Int, avgMinutes: Int, longestMinutes: Int) {
        let periodRecords = records.filter {
            !$0.isBreak && $0.date >= start && $0.date <= end
        }
        let sessions = periodRecords.count
        guard sessions > 0 else { return (0, 0, 0) }
        let total = periodRecords.reduce(0) { $0 + $1.durationMinutes }
        let longest = periodRecords.map { $0.durationMinutes }.max() ?? 0
        return (sessions, total / sessions, longest)
    }
}
```

### Priority 2: Add Period Navigation (Optional)

Add anchor date state and navigation buttons to ProgressView if user wants exact RN behavior.

---

## Tests Required

1. Test stats calculation matches RN for various date ranges
2. Test period navigation (if implemented)
3. Test live refresh when new records added
