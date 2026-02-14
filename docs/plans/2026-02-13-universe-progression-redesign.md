# Universe Progression Redesign

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Redesign the Universe system to reward total cumulative focus time rather than per-task grouping, making progression feel achievable for all work styles.

**Architecture:** Remove task-based planet formation. Stars earned per session (with minimum threshold), brightness scales with break recharge %. Planets unlock at cumulative hour milestones.

**Tech Stack:** SwiftUI, SwiftData, existing CelestialBody model

---

## Design Decisions

### Stars
- **Minimum threshold:** 5 minutes to earn a star (prevents 1-min spam)
- **Size:** Based on session duration (existing logic)
  - 5-14 min = 4pt (small)
  - 15-24 min = 8pt (medium)
  - 25-44 min = 12pt (large)
  - 45+ min = 16pt (extra large)
- **Brightness/Glow:** Scales with break recharge %
  - 0-25% recharge = dim (0.3 opacity glow)
  - 25-50% = normal (0.5 opacity)
  - 50-75% = bright (0.7 opacity)
  - 75-99% = vibrant (0.9 opacity)
  - 100% = vibrant + cyan-gold halo ring

### Planets (Hour-Based Milestones)
| Total Hours | Reward | Visual |
|-------------|--------|--------|
| 3 hours | First planet | Small, single color |
| 7 hours | Second planet | Medium, different color |
| 15 hours | Planet + moon | Medium with 1 orbiting moon |
| 30 hours | Planet + rings | Saturn-style rings |
| 50 hours | Gas giant | Large with bands + moons |
| 100 hours | Sun/Nebula | Special golden sun or nebula effect |

### What's Removed
- Task-based planet formation (weight system per task)
- Task-based constellation grouping (lines between same-task stars)
- The `checkAndEvolveToPlanet(for taskId:)` method

### What's Kept
- Star creation from focus sessions
- Star positioning algorithm
- Basic planet/moon/ring drawing code (reused for milestones)
- Recharged star halo (enhanced with brightness scaling)

---

## Files to Modify

| File | Changes |
|------|---------|
| `CelestialBody.swift` | Remove task-based evolution, add `rechargeLevel` property, add hour milestone logic |
| `UniverseView.swift` | Remove constellation lines, update planet drawing to use milestone planets |
| `TimerView.swift` | Pass recharge % when creating star |
| `FocusRecord.swift` | Ensure `rechargeLevel` (0-100) is stored |

## Files to Create

| File | Purpose |
|------|---------|
| `UniverseProgressService.swift` | Calculate total hours, check milestones, create milestone planets |

---

## Task 1: Update CelestialBody Model

**Files:** `FocusHavenPackage/Sources/FocusHavenFeature/Models/CelestialBody.swift`

Changes:
1. Add `rechargeLevel: Double` property (0-100) to store break recharge %
2. Remove `checkAndEvolveToPlanet(for taskId:)` method entirely
3. Update `createStar(from:)` to accept rechargeLevel parameter
4. Add computed property `glowOpacity` based on rechargeLevel:
```swift
public var glowOpacity: Double {
    switch rechargeLevel {
    case 0..<25: return 0.3
    case 25..<50: return 0.5
    case 50..<75: return 0.7
    case 75..<100: return 0.9
    default: return 1.0  // 100%
    }
}
```

5. Add minimum duration check (5 minutes = 300 seconds):
```swift
public static func shouldCreateStar(duration: Int) -> Bool {
    return duration >= 300  // 5 minutes minimum
}
```

---

## Task 2: Create UniverseProgressService

**Files:** Create `FocusHavenPackage/Sources/FocusHavenFeature/Services/UniverseProgressService.swift`

Purpose: Track total focus hours and manage milestone planets.

```swift
@Observable
@MainActor
public final class UniverseProgressService {

    struct Milestone {
        let hours: Double
        let type: MilestoneType
        let name: String
    }

    enum MilestoneType {
        case smallPlanet
        case mediumPlanet
        case planetWithMoon
        case planetWithRings
        case gasGiant
        case sun
    }

    static let milestones: [Milestone] = [
        Milestone(hours: 3, type: .smallPlanet, name: "First Light"),
        Milestone(hours: 7, type: .mediumPlanet, name: "Rising World"),
        Milestone(hours: 15, type: .planetWithMoon, name: "Companion"),
        Milestone(hours: 30, type: .planetWithRings, name: "Ringed Wonder"),
        Milestone(hours: 50, type: .gasGiant, name: "Giant"),
        Milestone(hours: 100, type: .sun, name: "Your Sun")
    ]

    /// Calculate total focus hours from all records
    func totalFocusHours(from records: [FocusRecord]) -> Double {
        let totalSeconds = records.reduce(0) { $0 + $1.duration }
        return Double(totalSeconds) / 3600.0
    }

    /// Get unlocked milestones based on total hours
    func unlockedMilestones(totalHours: Double) -> [Milestone] {
        return Self.milestones.filter { $0.hours <= totalHours }
    }

    /// Check and create milestone planets if needed
    func syncMilestonePlanets(totalHours: Double, existingBodies: [CelestialBody], modelContext: ModelContext) {
        let unlocked = unlockedMilestones(totalHours: totalHours)
        let existingPlanetCount = existingBodies.filter { $0.type == .planet }.count

        // Create any missing milestone planets
        for (index, milestone) in unlocked.enumerated() {
            if index >= existingPlanetCount {
                let planet = createMilestonePlanet(milestone: milestone, index: index)
                modelContext.insert(planet)
            }
        }

        try? modelContext.save()
    }

    private func createMilestonePlanet(milestone: Milestone, index: Int) -> CelestialBody {
        // Position planets in a nice arc
        let angle = Double(index) * 0.4 + 0.3
        let radius = 0.25 + Double(index) * 0.08
        let x = 0.5 + cos(angle * .pi) * radius
        let y = 0.5 + sin(angle * .pi) * radius * 0.6

        let (color, glow) = planetColors(for: milestone.type)
        let size = planetSize(for: milestone.type)

        return CelestialBody(
            type: .planet,
            taskName: milestone.name,
            position: CelestialPosition(x: x, y: y),
            size: size,
            colorHex: color,
            glowColorHex: glow,
            weight: milestone.hours
        )
    }
}
```

---

## Task 3: Update Star Drawing with Brightness Scaling

**Files:** `FocusHavenPackage/Sources/FocusHavenFeature/Views/Universe/UniverseView.swift`

In `drawStar()` method:
1. Use `body.glowOpacity` instead of hardcoded opacity values
2. Keep the cyan-gold halo only for `body.isRecharged` (100%)

```swift
// Glow opacity now scales with recharge level
let glowOpacity: CGFloat = isRecharged ? 1.0 : body.glowOpacity
context.fill(
    Circle().path(in: glowRect),
    with: .color(body.glowColor.opacity(glowOpacity * 0.4))
)
```

---

## Task 4: Remove Constellation Lines

**Files:** `FocusHavenPackage/Sources/FocusHavenFeature/Views/Universe/UniverseView.swift`

1. Remove `drawConstellationLines()` method call from `drawCelestialBodies()`
2. Remove the `drawConstellationLines()` method entirely
3. Remove constellation naming sheet and related state
4. Remove `unnamedConstellations` computed property

---

## Task 5: Update Star Creation Flow

**Files:**
- `FocusHavenPackage/Sources/FocusHavenFeature/Views/Timer/TimerView.swift`
- `FocusHavenPackage/Sources/FocusHavenFeature/Models/FocusRecord.swift`

1. Ensure FocusRecord stores `rechargeLevel: Double` (0-100)
2. When creating star, check minimum duration first:
```swift
if CelestialBody.shouldCreateStar(duration: record.duration) {
    let star = CelestialBody.createStar(from: record, rechargeLevel: lastRechargeLevel)
    modelContext.insert(star)
}
```

3. After creating star, sync milestone planets:
```swift
let totalHours = universeProgress.totalFocusHours(from: allRecords)
universeProgress.syncMilestonePlanets(totalHours: totalHours, existingBodies: celestialBodies, modelContext: modelContext)
```

---

## Task 6: Clean Up Old Task-Based Code

**Files:** `FocusHavenPackage/Sources/FocusHavenFeature/Models/CelestialBody.swift`

Remove:
- `checkAndEvolveToPlanet(for:in:modelContext:)` method
- `generalFocusId` static property
- `determinePlanetColors(from:)` method (replace with milestone-based colors)
- Task-based weight accumulation logic

Keep:
- `calculateWeight()` - still useful for star importance
- `calculateSize()` - still used for star sizing
- `determineColors()` - still used for star colors based on time of day

---

## Verification

1. Build and run on simulator
2. Complete a 5+ minute focus session → star appears
3. Check star brightness varies with recharge % (test at different levels)
4. Accumulate 3 hours total → first planet appears
5. Verify no constellation lines appear
6. Verify planets positioned nicely (not clustered)

---

## Summary

| Before | After |
|--------|-------|
| Stars grouped by task | Stars independent, all contribute to total |
| Planet per 7-weight of same task | Planet per hour milestone (3, 7, 15, 30, 50, 100) |
| Binary recharged halo | Brightness scales 0-100%, halo at 100% |
| Constellation lines | Removed |
| Complex task tracking | Simple hour accumulation |
