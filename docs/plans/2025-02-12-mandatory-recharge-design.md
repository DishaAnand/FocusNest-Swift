# Mandatory Recharge Mode — Design Document

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Make Recharge Mode the default break experience with movement-based rewards (early exit + Universe bonus) rather than punishment for skipping.

**Philosophy:** Movement = Control. The more you move, the more control you have over your break.

**Architecture:** Remove settings toggle, add early exit unlock at 100% recharge, add recharged star bonus in Universe, add Recharge Score to analytics.

---

## User Experience Flow

### New Break Flow

```
Focus ends → Break starts → RechargeView (always) → Move to unlock early exit OR wait for timer
```

### Key Behaviors

| Scenario | What Happens |
|----------|--------------|
| User reaches 100% recharge | "Continue" button appears, can end break early |
| User waits for timer | Normal completion, shows achieved percentage |
| User starts focus after 100% recharge | That session's star gets special glow in Universe |

---

## UI Components

### 1. RechargeView Updates

**New Element: Unlock Progress Bar**

Position: Below the energy orb

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━
🔓 Unlock Early Exit: 78%
```

**Visual States:**

| Progress | Bar Color | Message |
|----------|-----------|---------|
| 0-25% | Blue | "Get moving to unlock early exit" |
| 25-50% | Blue→Cyan | "You're warming up!" |
| 50-75% | Cyan, gentle pulse | "Halfway to freedom!" |
| 75-99% | Cyan→Green, faster pulse | "Almost there!" |
| 100% | Green, celebration | "Break Complete! Tap to continue" |

**At 100% Celebration:**
- Haptic: Success pattern
- Progress bar bursts into particles
- Orb pulses with golden particles
- "Continue to Focus" button slides up
- Message: "You earned an early exit!"

### 2. Early Exit Button

Appears only when rechargePercentage >= 100

**Design:**
- Large, prominent button
- Vibrant green with glow effect
- Text: "Continue to Focus"
- Positioned at bottom of screen

### 3. Skip Button

Keep existing skip button but:
- Subtle styling (low contrast)
- Top-right position
- No changes to behavior

---

## Universe Bonus: Recharged Stars

### Visual Difference

**Normal Star:**
- Standard glow based on time of day
- Size based on duration

**Recharged Star:**
- Extra outer halo (cyan-gold gradient)
- 2-3 sparkle particles orbiting
- +20% glow radius

### Data Model

Add to `FocusRecord`:
```swift
var rechargePercentage: Double?  // 0-100, nil for focus sessions
var wasFullyRecharged: Bool      // true if previous break was 100%
```

Add to `CelestialBody`:
```swift
var isRecharged: Bool            // renders with bonus effect
```

---

## Analytics: Recharge Score

### New Metric

**Location:** Progress tab, weekly stats card

**Calculation:** Average recharge percentage across all breaks in time period

**Display:**
```
⚡ Recharge Score: 72%
   ↑ 8% vs last week
```

**Visual:**
- Lightning bolt icon in Theme.breakColor
- Trend arrow comparing to previous period
- No judgment language

---

## Technical Implementation

### Files to Modify

| File | Changes |
|------|---------|
| `UserSettings.swift` | Remove `rechargeModeEnabled` property |
| `SettingsView.swift` | Remove Recharge Mode toggle |
| `RechargeView.swift` | Add UnlockProgressBar, early exit button, 100% celebration |
| `RechargeCompleteView.swift` | Update messaging for recharged bonus |
| `TimerView.swift` | Handle early exit, pass recharge state to next session |
| `FocusRecord.swift` | Add `rechargePercentage`, `wasFullyRecharged` |
| `CelestialBody.swift` | Add `isRecharged`, update rendering |
| `UniverseView.swift` | Render recharged stars with bonus effect |
| `ProgressView.swift` | Add Recharge Score metric |

### New Files

| File | Purpose |
|------|---------|
| `UnlockProgressBar.swift` | Progress bar component for early exit |
| `RechargedStarEffect.swift` | Sparkle/halo modifier for recharged stars |

---

## Task Breakdown

### Task 1: Remove Recharge Mode Toggle
- Remove `rechargeModeEnabled` from UserSettings
- Remove toggle from SettingsView
- Update TimerView to always show RechargeView during breaks

### Task 2: Add Unlock Progress Bar
- Create `UnlockProgressBar.swift` component
- Gradient fill animation (blue → cyan → green)
- Lock icon that transforms to unlocked
- Pulse animation at 75%+
- Integrate into RechargeView

### Task 3: Add Early Exit Flow
- Detect 100% recharge in RechargeView
- Show celebration (haptic + visual burst)
- Display "Continue to Focus" button
- Handle early exit to end break and transition to focus

### Task 4: Update Data Models
- Add `rechargePercentage: Double?` to FocusRecord
- Add `wasFullyRecharged: Bool` to FocusRecord
- Add `isRecharged: Bool` to CelestialBody
- Store recharge percentage on break completion
- Pass recharged state to next focus session

### Task 5: Recharged Star Effect
- Create `RechargedStarEffect.swift` modifier
- Cyan-gold outer halo
- Orbiting sparkle particles
- Apply to stars where `isRecharged == true`

### Task 6: Update Universe Rendering
- Modify CelestialBody.createStar to accept recharged flag
- Update UniverseView to render recharged effect
- Test visual appearance

### Task 7: Add Recharge Score to Analytics
- Calculate average recharge percentage
- Add to ProgressView weekly stats
- Show trend vs previous period

### Task 8: Polish & Testing
- Test full flow on device
- Verify haptics and animations
- Test Universe rendering
- Verify analytics calculation

---

## Success Criteria

1. Recharge Mode appears on EVERY break (no toggle)
2. Users can exit break early by reaching 100% recharge
3. Early exit feels rewarding (celebration, messaging)
4. Recharged stars are visibly different in Universe
5. Recharge Score shows in Progress tab
6. No punishment for low recharge - just less reward
