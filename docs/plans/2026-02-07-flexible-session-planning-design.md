# Flexible Session Planning - Design Document

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Replace rigid pre-planned session durations with flexible "commit to session count, decide duration in-the-moment" approach.

**Architecture:** Reuse existing SessionCompleteView, PlayfulNudgeView, and MandatoryBreakView. Add new session count picker and enhance final celebration.

**Tech Stack:** SwiftUI, existing Timer/Session infrastructure

---

## Problem Statement

Current session planning requires users to decide exact durations upfront (e.g., "25min, 45min, 30min"). This is problematic because:
- Focus capacity changes throughout the day
- Pre-planning locks users into guesses that may not match reality
- Reddit users complain about rigid timers without flexibility to continue

## Solution

Users commit to NUMBER of sessions only. Duration is decided before each session starts, adapting to actual energy levels.

---

## User Flow

### 1. Starting a Focus Plan

**Entry Point:** "Plan Sessions" button on Tasks tab

**UI:** Simple picker
- "How many sessions?" → 1, 2, 3, 4, 5
- Shows: "X sessions = up to Y breaks"
- Start button

**No duration selection here** - that happens per-session.

### 2. Before Each Session

**UI Elements:**
- Session indicator: "Session 1 of 3"
- Timer circle with current duration (default: last used or 25min)
- "Tap to change" label under timer
- "Predict your focus" pill (optional)
- Play button to start

**User Actions:**
- Tap timer → Duration picker (1-120 min wheel)
- Tap Predict → Energy prediction overlay
- Tap Play → Session starts

### 3. During Session

- Normal timer countdown
- Ambient sound plays (focus sessions only)
- Distraction tracking via scenePhase changes
- Session indicator visible: "Session 1 of 3"

### 4. After Session Completes (Not Final)

**Celebration tier based on duration:**

| Duration | Celebration | Next Action |
|----------|-------------|-------------|
| < 25 min | Simple "Nice work!" | Choice: Break or Continue |
| 25-44 min | Brain animation 🧠 (PlayfulNudgeView) | Choice: Break or Continue |
| 45+ min continuous | Auto-lock 🔒 (MandatoryBreakView) | Forced 5 min break |

**If user chooses "Continue/Keep momentum":**
- Skip to next session setup (Session 2 of 3)
- Cumulative focus time tracked for 45min threshold

**If user chooses "Take a Break":**
- Break timer starts (duration based on focus length: 5/10/15 min)
- After break → Next session setup

### 5. After Final Session Completes

**Enhanced Celebration UI:**
- Same base as SessionCompleteView but elevated
- Gold/amber accents instead of green
- Extra confetti burst
- Larger, prouder animations

**Content:**
- Title: "All Sessions Complete!" or "You Crushed It!"
- Badge: "Focus Champion 🏆" or "Session Master ⭐"
- Total stats summary:
  - "3 sessions completed"
  - "75 minutes focused"
  - "0 distractions"
- Single "Done" button (no break options)

---

## Milestone Thresholds

| Threshold | Trigger | UI |
|-----------|---------|-----|
| 25 min | Session completion where duration >= 25 && < 45 | PlayfulNudgeView (brain animation) |
| 45 min | Continuous focus without break >= 45 min | MandatoryBreakView (lock, forced break) |

**Important:** The 45 min threshold is for CONTINUOUS focus, not per-session. If user does 25min → skip break → 20min more = 45min continuous → auto-lock triggers.

---

## State Management

**New State Variables:**
```swift
@State private var totalSessionCount: Int = 0      // User's commitment (1-5)
@State private var currentSessionNumber: Int = 0   // Which session we're on (1-indexed)
@State private var continuousFocusTime: Int = 0    //累計 focus without break (for 45min check)
@State private var totalFocusTime: Int = 0         // All sessions combined
@State private var totalDistractions: Int = 0      // All sessions combined
@State private var isFlexiblePlanActive: Bool = false
```

**Reset Points:**
- `continuousFocusTime` resets to 0 when user takes a break
- `totalFocusTime` and `totalDistractions` accumulate across all sessions
- Everything resets when plan completes or user exits

---

## UI Components to Modify

### SessionPlannerView
- Remove per-session duration configuration
- Replace with simple session count picker (1-5)
- Update "Start X Sessions" button

### TimerView
- Add session count indicator: "Session X of Y"
- Track `continuousFocusTime` for 45min threshold
- Show "Tap to change" when in flexible plan mode and idle
- Handle session transitions

### SessionCompleteView
- Add `isFinalSession: Bool` parameter
- Add `totalStats: (sessions: Int, minutes: Int, distractions: Int)` parameter
- Conditional rendering for final vs intermediate sessions
- Enhanced celebration for final session

### New: SessionCountPicker
- Simple picker: 1, 2, 3, 4, 5 sessions
- Shows break count calculation
- Clean, minimal UI

---

## Migration from Current Session Plans

Current behavior:
- User specifies exact duration for each session upfront
- Breaks are automatic between sessions

New behavior:
- User specifies only session count
- Duration decided per-session in the moment
- Breaks are offered but optional (except 45min force)

**Backward compatibility:** Remove old session planning entirely. This is a replacement, not an addition.

---

## Edge Cases

1. **User quits mid-plan**: Show partial stats, plan ends
2. **45min lock during session**: Lock triggers immediately, current session counts as complete
3. **User at session 3 of 3, chooses "continue"**: Not possible - final session has no "continue" option
4. **Very short sessions (< 5 min)**: Allowed, no special treatment
5. **Single session plan**: Essentially same as regular focus, but with session indicator

---

## Success Metrics

- Users can start focusing faster (no upfront duration decisions)
- Users feel in control (decide duration based on current energy)
- Burnout protection maintained (45min auto-lock)
- Final celebration creates sense of accomplishment

---

## Implementation Priority

1. **Session count picker** - Replace duration-per-session UI
2. **Continuous focus tracking** - For 45min threshold across skipped breaks
3. **Session transition flow** - Handle "continue" vs "break" choices
4. **Final session celebration** - Enhanced UI for last session
5. **Clean up old code** - Remove pre-planned duration logic
