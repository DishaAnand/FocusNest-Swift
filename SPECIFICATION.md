# FocusNest - Complete Feature Specification

## Overview

FocusNest is a native iOS Pomodoro timer application with collaborative "buddy sessions" via Firebase.

## Platform Requirements

- **Target**: iOS 17.0+
- **Swift Version**: 5.9+ (Xcode 15.2 compatible)
- **Architecture**: Workspace + SPM Package
- **State Management**: Pure SwiftUI with @Observable (MV pattern, no ViewModels)

---

## Core Features

### 1. Pomodoro Timer

#### Requirements
- [x] Focus session: Default 25 minutes (configurable 1-120 min)
- [x] Short break: Default 5 minutes (configurable 1-30 min)
- [x] Long break: Default 15 minutes (configurable 1-60 min)
- [x] Sessions before long break: Default 4 (configurable 2-8)
- [x] Timer states: idle, running, paused
- [x] Controls: Play/Pause toggle, Stop, Skip
- [x] Background time tracking (calculates elapsed time when app returns)
- [x] Circular progress indicator with animated ring
- [x] Session counter (e.g., "0 of 4 sessions until long break")

#### Timer Display
- [x] Large countdown format: MM:SS
- [x] Mode indicator: "Focus" / "Short Break" / "Long Break"
- [x] Paused indicator when paused
- [x] Selected task display (if any)

### 2. Task Management

#### Requirements
- [x] Create new tasks with title
- [x] View tasks in two tabs: "To Do" / "Done"
- [x] Mark task as complete/incomplete
- [x] Rename tasks
- [x] Delete tasks
- [x] Select task for focus session
- [x] Track accumulated focus time per task
- [x] Empty state when no tasks

#### Task Data Model
```swift
@Model FocusTask {
    id: UUID
    title: String
    isCompleted: Bool
    createdAt: Date
    completedAt: Date?
    totalFocusTime: Int (seconds)
}
```

### 3. Progress Tracking

#### Requirements
- [x] Stats cards: Total Focus, Sessions Count, Today's Minutes, Streak Days
- [x] Segmented tabs: Daily / Weekly / Monthly
- [x] Bar charts using Swift Charts
- [x] Focus vs Break time visualization (color-coded)
- [x] Persist records in SwiftData

#### FocusRecord Data Model
```swift
@Model FocusRecord {
    id: UUID
    date: Date
    duration: Int (seconds)
    isBreak: Bool
    taskId: UUID?
    taskTitle: String?
    wasCompleted: Bool
    wasBuddySession: Bool
}
```

### 4. Settings

#### Timer Settings
- [x] Focus Duration picker (1-120 minutes)
- [x] Short Break Duration picker (1-30 minutes)
- [x] Long Break Duration picker (1-60 minutes)
- [x] Sessions before long break stepper (2-8)

#### Automation
- [x] Auto-start Breaks toggle
- [x] Auto-start Focus toggle

#### Feedback
- [x] Sound enabled toggle
- [x] Vibration enabled toggle

#### Notifications
- [x] Notifications enabled toggle
- [x] Enable Notifications button (if not authorized)

#### Appearance
- [x] Theme picker: System / Light / Dark

#### About
- [x] Version display
- [x] Reset All Settings button with confirmation

### 5. Buddy Sessions (Firebase)

#### Create Session Flow
1. Setup: Enter name, select/create task, choose duration (15/25/45/60 min)
2. Waiting: Display share link, wait for buddy, show "Start" when 2+ joined
3. Active: Collaborative timer countdown
4. Rating: Rate buddy (1-5 stars)
5. Completed: Success message

#### Join Session Flow
1. Receive deep link: `focusnest://buddy/{sessionId}`
2. Enter name, select/create task
3. Join session
4. Participate in active timer
5. Rate buddy

#### BuddySession Data Model
```swift
struct BuddySession: Codable {
    sessionId: String
    creatorId: String
    state: SessionState (waiting/active/paused/completed/cancelled)
    duration: Int (seconds)
    startTime: Double?
    endTime: Double?
    participants: [String: SessionParticipant]
    createdAt: Double
}

struct SessionParticipant: Codable {
    odid: String
    name: String
    taskTitle: String
    status: ParticipantStatus (focused/away/waiting)
    violationCount: Int
    joinedAt: Double
    rating: Int?
}
```

### 6. Notifications

- [x] Timer completion notification (customized for focus vs break)
- [x] Buddy joined notification
- [x] Buddy session complete notification
- [x] Badge management

### 7. Audio/Haptic Feedback

#### Sounds (via AudioServices)
- [x] Timer complete sound
- [x] Success sound
- [x] Notification sound
- [x] Tap sound

#### Haptics
- [x] Light/Medium/Heavy impact
- [x] Success/Warning/Error notification
- [x] Selection changed

---

## Navigation Structure

```
TabView
├── Tasks (HomeView)
│   ├── Segmented: To Do / Done
│   └── Task list with TaskCardView
├── Timer (TimerView)
│   ├── Mode indicator
│   ├── Circular progress
│   ├── Controls
│   └── Session counter
├── Progress (FocusProgressView)
│   ├── Stats grid
│   ├── Segmented: Daily / Weekly / Monthly
│   └── Chart view
└── Settings (SettingsView)
    └── List sections
```

---

## Component Inventory

| Component | Purpose |
|-----------|---------|
| CircularProgressView | Animated ring progress |
| TaskCardView | Task list item with actions |
| TaskSelectionCardView | Task picker item |
| SegmentedTabView | Generic tab switcher |
| EmptyStateView | Empty state placeholder |
| PulsingIndicatorView | Loading animation |
| StarRatingView | 5-star rating input |
| StatCard | Statistics display card |
| LegendItem | Chart legend entry |

---

## Theme System

### Colors
| Name | RGB | Usage |
|------|-----|-------|
| focusColor | (0.38, 0.73, 0.60) | Focus sessions, primary actions |
| breakColor | (0.45, 0.68, 0.82) | Break sessions |
| pausedColor | (0.85, 0.65, 0.35) | Paused state |
| successColor | System green | Success states |
| warningColor | System orange | Warnings |
| errorColor | System red | Errors, destructive |
| awayColor | (0.85, 0.55, 0.55) | Away status |

### Spacing
- XS: 4pt, S: 8pt, M: 16pt, L: 24pt, XL: 32pt, XXL: 48pt

### Corner Radius
- S: 8pt, M: 12pt, L: 16pt, XL: 24pt

### Typography
- titleFont: .title, rounded, bold
- headlineFont: .headline, rounded, semibold
- bodyFont: .body, rounded
- captionFont: .caption, rounded
- timerFont: 72pt, rounded, light
- timerFontSmall: 48pt, rounded, light

---

## Services

### TimerService (@Observable @MainActor)
- State: remainingTime, totalDuration, state, mode, completedSessions
- Methods: start(), pause(), resume(), stop(), skip(), reset(), togglePlayPause()
- Callbacks: onComplete, onTick
- Background: Handles app backgrounding/foregrounding

### NotificationService (@Observable @MainActor)
- Methods: requestAuthorization(), scheduleTimerCompletion(), cancelTimerNotifications()
- State: isAuthorized

### SoundService (@Observable @MainActor)
- Sounds: playTimerComplete(), playSuccess(), playNotification(), playTap()
- Haptics: lightImpact(), mediumImpact(), heavyImpact(), successHaptic(), warningHaptic(), errorHaptic()

### SessionService (@Observable @MainActor)
- Firebase Realtime Database integration
- Methods: createSession(), joinSession(), startSession(), leaveSession(), rateBuddy()
- State: currentSession, isLoading, error

---

## Deep Linking

Scheme: `focusnest://buddy/{sessionId}`

Handling:
1. ContentView receives URL via `.onOpenURL`
2. Parses sessionId from path
3. Shows JoinSessionView sheet

---

## Test Coverage Requirements

### Unit Tests (Swift Testing)
- [ ] TimerService state transitions
- [ ] TimerService time formatting
- [ ] TimerService mode changes
- [ ] UserSettings persistence
- [ ] FocusTask model operations
- [ ] FocusRecord calculations
- [ ] BuddySession serialization

### Integration Tests
- [ ] SwiftData persistence roundtrip
- [ ] Timer with notification scheduling
- [ ] Settings changes propagation

### UI Tests
- [ ] Tab navigation
- [ ] Timer controls
- [ ] Task CRUD operations
- [ ] Settings changes

---

## Known Issues to Fix

1. **FocusProgressView missing @MainActor** - Needs annotation for consistency
2. **UI automation tools unavailable** - axe command returns system error -86
3. **Verify all views have proper @MainActor isolation**

---

## Build Commands

```bash
# Build for simulator
xcodebuild -workspace FocusNest.xcworkspace -scheme FocusNest -destination 'platform=iOS Simulator,name=iPhone 15' build

# Run tests
xcodebuild -workspace FocusNest.xcworkspace -scheme FocusNestFeature test

# Clean
xcodebuild -workspace FocusNest.xcworkspace -scheme FocusNest clean
```
