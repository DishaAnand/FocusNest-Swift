# Personal Universe - Gamification Feature Design

> **For Claude:** Use superpowers:subagent-driven-development to implement this plan task-by-task.

**Goal:** Create a beautiful, evolving personal cosmos that visualizes the user's focus journey - stars from sessions, constellations from repeated tasks, planets from consistency.

**Architecture:** SwiftUI Canvas-based rendering with SwiftData persistence. Static elegance with minimal purposeful motion. Premium aesthetic inspired by real space photography with Apple-level polish.

**Tech Stack:** SwiftUI, SwiftData, Canvas API, GeometryReader for interactions

---

## Visual Design System

### Color Palette
- **Background:** Pure black (#000000) to deep space blue (#0A0A1A) gradient
- **Stars by time of day:**
  - Morning (5am-11am): Warm white (#FFF8E7) with golden halo (#FFD700, 20% opacity)
  - Afternoon (11am-5pm): Pure white (#FFFFFF)
  - Evening (5pm-9pm): Soft amber (#FFB347)
  - Night (9pm-5am): Cool blue-white (#E6F0FF)
- **Constellation lines:** Subtle gray (#333333) with soft glow
- **UI elements:** Minimal, dark translucent backgrounds

### Star Sizing (by duration)
- 5-14 min: 4pt diameter (distant twinkle)
- 15-24 min: 8pt diameter (visible star)
- 25-44 min: 12pt diameter (bright star)
- 45+ min: 16pt diameter (brilliant star with subtle glow)

### Planet Evolution
- 7 sessions same task → Small planet forms
- 14 sessions → Planet gains ring system
- 21 sessions → Planet gains moon
- 30 sessions → Gas giant with multiple moons

---

## Data Model

### CelestialBody (SwiftData)
```swift
@Model
final class CelestialBody {
    var id: UUID
    var type: CelestialType // .star, .planet, .moon
    var taskId: UUID?
    var taskName: String
    var position: CGPoint // Normalized 0-1 coordinates
    var size: CGFloat
    var colorHex: String
    var createdAt: Date
    var sessionIds: [UUID] // FocusRecord IDs that formed this
    var constellationId: UUID?
    var constellationName: String?
}

enum CelestialType: String, Codable {
    case star, planet, moon
}
```

### Position Algorithm
- Stars positioned using deterministic hash of session ID
- Creates organic distribution that's consistent across app launches
- Constellation members cluster in same region based on task ID hash

---

## User Flow

### After Session Completion
1. Current celebration screen appears
2. New "View Universe" button at bottom
3. Tapping opens full-screen universe view
4. New star gently fades in at its position (0.5s fade, no bounce)

### Universe View
1. Full-screen dark canvas
2. All celestial bodies rendered
3. Pinch to zoom (0.5x to 3x)
4. Pan to explore
5. Tap star → detail card slides up from bottom
6. Tap planet → shows all contributing sessions

### Constellation Naming
1. After 5th star in a task group, subtle prompt appears
2. "Name your constellation?" with text field
3. Name persists and shows when viewing that region

---

## Implementation Tasks

### Task 1: Data Model
- Create CelestialBody SwiftData model
- Add position generation algorithm
- Add color determination by time

### Task 2: Universe View - Static Stars
- Create UniverseView with Canvas
- Render stars at correct positions/sizes/colors
- Implement zoom and pan gestures

### Task 3: Star Creation on Session Complete
- After FocusRecord saved, create corresponding CelestialBody
- Calculate position from session ID hash
- Determine color from completion time
- Determine size from duration

### Task 4: Star Detail View
- Tap detection on stars
- Minimal detail card with task name, duration, date
- Smooth slide-up animation

### Task 5: Constellation Formation
- Group stars by taskId
- Draw subtle connecting lines
- Cluster positioning for same-task stars

### Task 6: Constellation Naming
- Detect when 5+ stars form constellation
- One-time naming prompt
- Display name in universe view

### Task 7: Planet Evolution
- Detect 7+ sessions on same task
- Replace star cluster with planet
- Store contributing session IDs

### Task 8: Integration
- Add "View Universe" button to SessionCompleteView
- Add Universe tab or settings entry point
- Polish and refinement

---

## Quality Standards

- **No cartoonish animations** - Subtle fades and scales only
- **60fps rendering** - Canvas must be performant with 100+ stars
- **Persistent positioning** - Same star always in same place
- **Premium feel** - Every pixel considered, Apple-level polish
