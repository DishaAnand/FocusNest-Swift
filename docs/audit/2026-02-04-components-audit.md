# Category 5: Components - Audit

> Audit Date: 2026-02-04
> React Native Files: 8 (+1 styles)
> Swift Equivalents: 6 components + 3 charts

---

## File 1: `TaskCard.tsx` & `TaskCard.styles.ts`

### RN Features

| Feature | RN Implementation | Swift Equivalent | Status |
|---------|-------------------|------------------|--------|
| Task title display | `<Text style={styles.title}>{title}</Text>` | `Text(task.title)` | ✅ |
| Start button | Inline teal button "Start" | **Missing** | ❌ |
| Edit/Pencil icon | Inline icon button | Context menu | ⚠️ Different UX |
| Swipe-to-delete | Swipeable with red background | Context menu | ⚠️ Different UX |
| Delete animation | Animated scale on drag | N/A | ⚠️ Different |
| Card shadow | shadow props | `.cardStyle()` | ✅ |
| Completion checkbox | N/A (separate screen) | Inline checkbox | ✅ Extra |

### Issues Found

1. **❌ "Start" button missing** - RN has inline Start button on task card
2. **⚠️ Swipe-to-delete replaced with context menu** - Less discoverable
3. **⚠️ Edit replaced with context menu** - Different interaction pattern

### RN Style Values (from TaskCard.styles.ts)

| Style | RN Value | Swift Equivalent | Match |
|-------|----------|------------------|-------|
| Card background | `#fff` | `Theme.backgroundSecondary` | ⚠️ Adaptive |
| Card padding | 16 | `Theme.spacingM` (16) | ✅ |
| Card border radius | N/A (wrapper) | `Theme.cornerRadiusM` (12) | ⚠️ Different |
| Title color | `#222` | `Theme.textPrimary` | ⚠️ Adaptive |
| Start button color | `COLORS.primary` | N/A | ❌ Missing |
| Delete button color | `#FF5C5C` | N/A (context menu) | ⚠️ Different |

---

## File 2: `SegmentedTabs.tsx`

### RN Features

| Feature | RN Implementation | Swift Equivalent | Status |
|---------|-------------------|------------------|--------|
| Tab container | Row with background `#F5EDE4` | `HStack` with `backgroundSecondary` | ⚠️ Different color |
| Tab items | Pressable components | Buttons | ✅ |
| Active styling | `COLORS.primary2` background | `Theme.focusColor` | ⚠️ Different color |
| Active text | White | White | ✅ |
| Inactive text | `COLORS.muted` | `Theme.textSecondary` | ⚠️ Different |
| Animation | None (instant) | `.easeInOut(duration: 0.2)` | ✅ Better |
| Border radius | 16 outer, 12 inner | Capsule | ⚠️ Different shape |

### RN Style Values

| Style | RN Value | Swift Equivalent | Match |
|-------|----------|------------------|-------|
| Container background | `#F5EDE4` | System secondary bg | ⚠️ |
| Container padding | 6 | 4 | ⚠️ |
| Container radius | 16 | Capsule | ⚠️ Different |
| Tab padding V | 8 | `Theme.spacingS` (8) | ✅ |
| Tab padding H | 16 | maxWidth infinite | ⚠️ Different |
| Active background | `COLORS.primary2` (#FF7A73) | `Theme.focusColor` | ⚠️ Different |
| Inactive text | `COLORS.muted` | `Theme.textSecondary` | ⚠️ |
| Font weight | 600 | `.semibold` | ✅ |
| Font size | 16 | `.headline` | ✅ |

---

## File 3: `StatsList.tsx`

### RN Features

| Feature | Purpose | Swift Equivalent | Status |
|---------|---------|------------------|--------|
| Sessions completed | Count for period | `totalSessions` (all-time) | ⚠️ Different scope |
| Average session | `avgSessionSec` | **Missing** | ❌ |
| Longest session | `longestSessionSec` | **Missing** | ❌ |
| Themed card | Uses `colors.card` | `StatCard` | ⚠️ Different format |
| Dividers | Between rows | N/A | ⚠️ Different layout |

### Issues Found

1. **❌ Average session stat missing** - Swift shows total, not average
2. **❌ Longest session stat missing** - Swift doesn't show this
3. **⚠️ Stats show all-time, not period-specific** - RN shows stats for selected date range

### Implementation Required

Add to ProgressView:
```swift
// Period-specific stats (matching RN StatsList)
let periodStats = FocusRecord.getStatsInRange(records: filteredRecords, start: periodStart, end: periodEnd)
// Then display: sessionsCompleted, avgSession (formatted), longestSession (formatted)
```

---

## File 4: `BarChart.tsx` (Simple bar chart)

### RN Features

| Feature | RN Value | Swift Equivalent | Status |
|---------|----------|------------------|--------|
| Fill color | `COLORS.primary2` (#FF7A73) | `Theme.focusColor` | ⚠️ Different |
| Bar radius | Configurable (default 8) | 4 | ⚠️ Smaller |
| X-axis labels | Below chart | Built-in | ✅ |
| Y-axis scale | Auto from max | Built-in | ✅ |
| Caption | "Bars show focus minutes/day" | N/A | ⚠️ Missing |

---

## File 5: `SingleDayBarChart.tsx`

### RN Features

Uses `useChartColors()` for:
- axisLabel color
- xAxisLabel color
- gridLine color
- gridOpacityMajor/Minor

### Swift Status

Chart colors were added to Theme.swift but **NOT USED** in chart views.

### Issues Found

1. **❌ Chart colors not applied** - Swift charts use default colors
2. **⚠️ Custom SVG replaced with Swift Charts** - Different appearance

---

## File 6: `WeeklyStackedChart.tsx`

### RN Features

| Feature | RN Implementation | Swift Equivalent | Status |
|---------|-------------------|------------------|--------|
| Chart type | Custom SVG bars | Swift Charts BarMark | ✅ Different lib |
| Gradient fill | LinearGradient top-bottom | Solid color | ⚠️ Missing gradient |
| Today highlight | Rect glow behind bar | N/A | ⚠️ Missing |
| Y-axis format | Dynamic (m/h) | Dynamic (m/h) | ✅ |
| X-axis labels | Day names | Day names | ✅ |
| Uses chart colors | Yes | **No** | ❌ |

---

## File 7: `MonthlyFocusChart.tsx`

### RN Features

| Feature | RN Implementation | Swift Equivalent | Status |
|---------|-------------------|------------------|--------|
| Chart type | Weekly buckets for month | Weeks 1-4/5 | ✅ Similar |
| Caption | "Weekly buckets (Mon–Sun)..." | N/A | ⚠️ Missing |
| Current week highlight | Rect glow | N/A | ⚠️ Missing |
| Uses chart colors | Yes | **No** | ❌ |

---

## File 8: `DailyBarChart.tsx`

This file is empty (1 line) in RN. Functionality is in `SingleDayBarChart.tsx`.

---

## Summary

| Component | Features | Implemented | Missing | Different UX |
|-----------|----------|-------------|---------|--------------|
| TaskCard | 7 | 4 | 1 | 2 |
| SegmentedTabs | 8 | 4 | 0 | 4 |
| StatsList | 5 | 1 | 2 | 2 |
| Charts (3) | 15 | 10 | 2 | 3 |

**CRITICAL ISSUES:**
1. "Start" button missing on TaskCard
2. Period-specific stats missing (avgSession, longestSession)
3. Chart colors not applied to Swift Charts

**MEDIUM ISSUES:**
1. Swipe-to-delete replaced with context menu
2. SegmentedTabs uses different colors/shape
3. Chart gradients and highlights missing

---

## Implementation Plan

### Priority 1: Apply Chart Colors

Update chart views to use `Theme.chartAxisLabel()`, etc.

### Priority 2: Add Period Stats

Add `avgSession` and `longestSession` stats to ProgressView using `FocusRecord.getStatsInRange()`.

### Priority 3: (Optional) TaskCard Start Button

Consider adding inline "Start" button if user wants exact RN behavior.

---

## Tests Required

1. Test chart color functions return different values for light/dark
2. Test period stats calculation matches RN
3. Test SegmentedTabView works with custom enums
