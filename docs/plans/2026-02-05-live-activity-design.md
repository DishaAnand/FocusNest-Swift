# Live Activity for Focus Timer

## Overview

Show the focus timer on Lock Screen and Dynamic Island so users can see their progress without opening the app.

## What We're Building

**Information displayed:**
- Countdown timer (hero element)
- Mode (Focus/Break)
- Task name if selected
- Progress indicator

**Visual style:**
- Mode-based colors: Green for Focus, Blue for Break
- Minimal, clean design
- Centered layout

**Interactions:**
- Tap to open app (no action buttons)

## Technical Architecture

### Files to Create

1. **Widget Extension Target**: `FocusHavenWidgets`
2. **FocusTimerAttributes.swift** - ActivityKit data model
3. **FocusTimerLiveActivity.swift** - SwiftUI views for all contexts

### Data Model

```swift
struct FocusTimerAttributes: ActivityAttributes {
    let taskName: String?

    struct ContentState: Codable, Hashable {
        let endTime: Date
        let totalSeconds: Int
        let mode: String // "focus", "shortBreak", "longBreak"
        let isPaused: Bool
    }
}
```

### Integration Points

- TimerService.start() → Start Live Activity
- TimerService.pause() → Update with isPaused = true
- TimerService.resume() → Update with new endTime
- TimerService.stop()/complete → End Live Activity

## UI Contexts

1. **Lock Screen** - Full banner with centered timer
2. **Dynamic Island Compact** - Colored dot + timer
3. **Dynamic Island Expanded** - Timer, progress, task name
