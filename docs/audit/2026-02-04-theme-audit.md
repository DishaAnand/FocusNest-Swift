# Category 4: Theme - Audit

> Audit Date: 2026-02-04
> React Native Files: 3
> Swift Equivalents: Partial (Theme.swift)

---

## File 1: `src/theme/theme.ts`

### RN AppColors Structure

```typescript
type AppColors = {
  bg: string;       // Background
  card: string;     // Card background
  text: string;     // Primary text
  muted: string;    // Secondary text
  primary: string;  // Primary accent
  primaryBg: string;// Primary tinted background
  border: string;   // Border color
};
```

### Light Theme Colors

| RN Color | RN Hex | Swift Equivalent | Status |
|----------|--------|------------------|--------|
| `lightColors.bg` | `#F8F7F3` | `rnBackground` (#FBF9F4) | ⚠️ Slight difference |
| `lightColors.card` | `#FFFFFF` | `cardBackground` | ✅ |
| `lightColors.text` | `#111111` | `rnText` (#0F172A) | ⚠️ Different |
| `lightColors.muted` | `#6B7280` | `mutedColor` (#2F6F6A) | ⚠️ Different |
| `lightColors.primary` | `#2b7a78` | `rnPrimary` (#2A7F7F) | ✅ Close |
| `lightColors.primaryBg` | `#E0F2F1` | `secondaryLight` (#E0F0F0) | ✅ Close |
| `lightColors.border` | `#E5E7EB` | `borderColor` (0.06 opacity) | ⚠️ Different |

### Dark Theme Colors

| RN Color | RN Hex | Swift Equivalent | Status |
|----------|--------|------------------|--------|
| `darkColors.bg` | `#121212` | Missing | ❌ |
| `darkColors.card` | `#1E1E1E` | Missing | ❌ |
| `darkColors.text` | `#FFFFFF` | Missing | ❌ |
| `darkColors.muted` | `#AAAAAA` | Missing | ❌ |
| `darkColors.primary` | `#4DD0E1` | Missing | ❌ |
| `darkColors.primaryBg` | `#1A2A2A` | Missing | ❌ |
| `darkColors.border` | `#333333` | Missing | ❌ |

### Issues Found

1. **❌ Dark theme colors missing** - Swift relies on system semantic colors
2. **⚠️ Light theme colors don't exactly match RN**
3. **❌ No equivalent of `navThemeFromColors()`** - Swift uses SwiftUI built-in

---

## File 2: `src/theme/ThemeProvider.tsx`

### RN Theme Context

| RN Property | Type | Swift Equivalent | Status |
|-------------|------|------------------|--------|
| `mode` | `'light' \| 'dark' \| 'system'` | `UserSettings.theme` (AppTheme enum) | ✅ |
| `colorScheme` | `'light' \| 'dark'` | `@Environment(\.colorScheme)` | ✅ |
| `colors` | `AppColors` | `Theme.*` | ⚠️ Static, not reactive |
| `navTheme` | Navigation theme | N/A (SwiftUI handles) | ✅ OK |
| `setMode` | Function | `settings.theme = ...` | ✅ |

### RN Functionality

| RN Feature | Purpose | Swift Equivalent | Status |
|------------|---------|------------------|--------|
| `ThemeProvider` component | Context provider | SwiftUI `@Environment` | ✅ Different pattern |
| `useAppTheme()` hook | Access theme | `@Environment(\.colorScheme)` | ✅ |
| System appearance listener | React to OS changes | Built into SwiftUI | ✅ Automatic |
| `SETTINGS_CHANGED_EVENT` | Notify on theme change | `@Observable` auto-updates | ✅ |

### Issues Found

1. **✅ SwiftUI handles theme switching automatically** - No issues
2. **⚠️ Custom colors don't adapt to dark mode** - Swift uses static colors

---

## File 3: `src/theme/useChartColors.ts`

### RN Chart Colors

```typescript
{
  axisLabel: isDark ? '#B0B0B0' : '#4A5A59',
  xAxisLabel: isDark ? '#CCCCCC' : '#0E1A19',
  gridLine: isDark ? '#FFFFFF' : '#0B0B0B',
  gridOpacityMajor: 0.06,
  gridOpacityMinor: 0.03,
}
```

### Swift Equivalent

| RN Property | Light | Dark | Swift Equivalent | Status |
|-------------|-------|------|------------------|--------|
| `axisLabel` | `#4A5A59` | `#B0B0B0` | Missing | ❌ |
| `xAxisLabel` | `#0E1A19` | `#CCCCCC` | Missing | ❌ |
| `gridLine` | `#0B0B0B` | `#FFFFFF` | Missing | ❌ |
| `gridOpacityMajor` | 0.06 | 0.06 | Missing | ❌ |
| `gridOpacityMinor` | 0.03 | 0.03 | Missing | ❌ |

### Issues Found

1. **❌ Chart colors missing** - No useChartColors equivalent in Swift
2. **Charts may use wrong colors in dark mode**

---

## Summary

| File | Colors/Features | Implemented | Missing | Issues |
|------|-----------------|-------------|---------|--------|
| theme.ts | 14 colors | 7 | 7 | 0 |
| ThemeProvider.tsx | 5 features | 5 | 0 | 0 |
| useChartColors.ts | 5 colors | 0 | 5 | 0 |

**CRITICAL ISSUES:**
1. Dark theme colors not defined - charts/custom views may look wrong in dark mode
2. Chart colors missing - charts won't match RN appearance

**MEDIUM ISSUES:**
1. Some light theme hex values differ slightly from RN

---

## Implementation Status

### Priority 1: Add Chart Colors - DONE

Added to Theme.swift:
```swift
// MARK: - Chart Colors (matching RN useChartColors.ts)
public static func chartAxisLabel(_ colorScheme: ColorScheme) -> Color {
    colorScheme == .dark
        ? Color(hex: "B0B0B0")
        : Color(hex: "4A5A59")
}

public static func chartXAxisLabel(_ colorScheme: ColorScheme) -> Color {
    colorScheme == .dark
        ? Color(hex: "CCCCCC")
        : Color(hex: "0E1A19")
}

public static func chartGridLine(_ colorScheme: ColorScheme) -> Color {
    colorScheme == .dark
        ? Color.white
        : Color(hex: "0B0B0B")
}

public static let chartGridOpacityMajor: Double = 0.06
public static let chartGridOpacityMinor: Double = 0.03
```

### Priority 2: Add Dark Theme Colors - DONE

Added to Theme.swift:
```swift
// MARK: - Theme Colors (matching RN theme.ts)
public enum ThemeColors {
    public struct Light {
        public static let bg = Color(hex: "F8F7F3")
        public static let card = Color.white
        public static let text = Color(hex: "111111")
        public static let muted = Color(hex: "6B7280")
        public static let primary = Color(hex: "2B7A78")
        public static let primaryBg = Color(hex: "E0F2F1")
        public static let border = Color(hex: "E5E7EB")
    }

    public struct Dark {
        public static let bg = Color(hex: "121212")
        public static let card = Color(hex: "1E1E1E")
        public static let text = Color.white
        public static let muted = Color(hex: "AAAAAA")
        public static let primary = Color(hex: "4DD0E1")
        public static let primaryBg = Color(hex: "1A2A2A")
        public static let border = Color(hex: "333333")
    }
}
```

---

## Tests Required

1. Test chart colors return correct values for light mode
2. Test chart colors return correct values for dark mode
3. Test theme colors match RN hex values
4. Test opacity values are correct
