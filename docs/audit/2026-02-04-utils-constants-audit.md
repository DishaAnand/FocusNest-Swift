# Category 1: Utils & Constants - Audit

> Audit Date: 2026-02-04
> React Native Files: 4
> Swift Equivalents: Partial

---

## File 1: `src/constants/colors.ts`

### Constants Defined

| RN Constant | RN Value | Swift Equivalent | Status |
|-------------|----------|------------------|--------|
| `COLORS.primary` | `#2A7F7F` | `Theme.focusColor` | ⚠️ Different value |
| `COLORS.background` | `#FBF9F4` | `Theme.backgroundPrimary` | ⚠️ Uses system color |
| `COLORS.secondaryLight` | `#E0F0F0` | Missing | ❌ Missing |
| `COLORS.secondaryDark` | `#4D7070` | Missing | ❌ Missing |
| `COLORS.card` | `#FFFFFF` | `Theme.backgroundSecondary` | ⚠️ Uses system color |
| `COLORS.text` | `#0F172A` | `Theme.textPrimary` | ⚠️ Uses system color |
| `COLORS.muted` | `#2F6F6A` | Missing | ❌ Missing |
| `COLORS.primary2` | `#FF7A73` | Missing | ❌ Missing (coral color) |
| `COLORS.border` | `rgba(0,0,0,0.06)` | Missing | ❌ Missing |
| `COLORS.shadow` | `rgba(0,0,0,0.08)` | Hardcoded in cardStyle | ⚠️ Not centralized |

### Issues Found
- [ ] Swift uses system colors while RN uses fixed brand colors
- [ ] Missing: secondaryLight, secondaryDark, muted, primary2 (coral), border colors
- [ ] Colors won't match between platforms

### Fix Required
Add RN-matching color constants to Theme.swift

---

## File 2: `src/utils/responsive.ts`

### Functions Defined

| Function | Purpose | Swift Equivalent | Status |
|----------|---------|------------------|--------|
| `scale(size)` | Width-based scaling, dampened for iPad | `Responsive.scale(_:)` | ✅ Implemented |
| `verticalScale(size)` | Height-based scaling, dampened for iPad | `Responsive.verticalScale(_:)` | ✅ Implemented |
| `moderateScale(size, factor)` | Controlled scaling with factor | `Responsive.moderateScale(_:factor:)` | ✅ Implemented |

### Constants

| Constant | RN Value | Swift Value | Status |
|----------|----------|-------------|--------|
| `guidelineBaseWidth` | 390 | 390 | ✅ Match |
| `guidelineBaseHeight` | 844 | 844 | ✅ Match |
| `isLargeScreen` threshold | 768 | 768 | ✅ Match |

### Issues Found
- [x] All functions implemented correctly
- [ ] Minor: RN `moderateScale` returns `adjusted * 0.9` for iPad, Swift returns `size + (scaledSize - size) * adjustedFactor` - DIFFERENT FORMULA!

### Fix Required
Fix moderateScale formula to match RN exactly

---

## File 3: `src/utils/date.ts`

### Functions Defined

| Function | Purpose | Swift Equivalent | Status |
|----------|---------|------------------|--------|
| `toISODate(d)` | Returns "YYYY-MM-DD" string | Missing | ❌ Missing |
| `startOfDay(d)` | Returns date at 00:00:00 | Inline in ProgressView | ⚠️ Not reusable |
| `startOfWeekSun(d)` | Returns Sunday of week | Missing | ❌ Missing |
| `endOfWeekSun(d)` | Returns Saturday 23:59:59 | Missing | ❌ Missing |
| `startOfMonth(d)` | Returns 1st of month | Missing | ❌ Missing |
| `endOfMonth(d)` | Returns last day 23:59:59 | Missing | ❌ Missing |
| `addDays(d, n)` | Add n days to date | Missing | ❌ Missing |
| `addMonths(d, n)` | Add n months to date | Missing | ❌ Missing |
| `endOfDay(d)` | Returns date at 23:59:59.999 | Missing | ❌ Missing |

### Constants

| Constant | Purpose | Swift Equivalent | Status |
|----------|---------|------------------|--------|
| `weekdayShort` | ['Sun','Mon',...] | Missing | ❌ Missing |
| `monthName(d)` | Returns full month name | Missing | ❌ Missing |

### Issues Found
- [ ] NO DateUtils.swift file exists
- [ ] Date logic scattered inline in views
- [ ] Charts likely have bugs due to missing date utilities

### Fix Required
Create `/Utils/DateUtils.swift` with all functions

---

## File 4: `src/utils/time.ts`

### Functions Defined

| Function | Purpose | Swift Equivalent | Status |
|----------|---------|------------------|--------|
| `secsToWholeMinutes(secs)` | Convert seconds to minutes (floor) | Missing | ❌ Missing |
| `fmtHMsec(s)` | Format as "1h 30m" or "25m 30s" | `FocusTask.focusTimeFormatted` | ⚠️ Different location/logic |

### RN `fmtHMsec` Logic:
```
if s >= 3600: return "Xh Ym" or "Xh"
else: return "Xm Ys" or "Xm"
```

### Swift `focusTimeFormatted` Logic:
```
if hours > 0: return "Xh Ym"
else if minutes > 0: return "Xm"
else: return "Xs"
```

### Issues Found
- [ ] `secsToWholeMinutes` doesn't exist
- [ ] `fmtHMsec` logic differs - RN shows seconds in output, Swift doesn't show "25m 30s"
- [ ] Time utils should be centralized, not on model

### Fix Required
Create `/Utils/TimeUtils.swift` with matching functions

---

## Summary

| File | Functions | Implemented | Missing | Buggy |
|------|-----------|-------------|---------|-------|
| colors.ts | 11 colors | 5 | 6 | 0 |
| responsive.ts | 3 functions | 3 | 0 | 1 |
| date.ts | 11 functions | 1 (inline) | 10 | 0 |
| time.ts | 2 functions | 1 (partial) | 1 | 1 |

**Total: 27 items → 10 implemented, 17 missing/buggy**

---

## Tests Required

1. `ColorConstantsTests.swift` - Verify all colors match RN hex values
2. `ResponsiveTests.swift` - Verify scaling matches RN output
3. `DateUtilsTests.swift` - Verify all date functions
4. `TimeUtilsTests.swift` - Verify time formatting matches RN

---

## Implementation Plan

1. Create `DateUtils.swift` with all 11 functions
2. Create `TimeUtils.swift` with 2 functions
3. Fix `Responsive.moderateScale` formula
4. Add missing colors to Theme.swift
5. Write comprehensive tests for all
