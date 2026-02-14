# Predict Your Focus Feature

## Overview

Before starting a focus session, users predict their focus level (1-5). After the session, they see how their prediction compared to actual performance. This creates a self-awareness feedback loop that no other focus app has.

## User Flow

### Pre-Session
1. User taps "Start" on timer
2. Energy meter modal appears (half-sheet)
3. User drags to set prediction (1-5 flames)
4. Taps "Let's Go" → timer starts
5. Optional "Skip" to bypass prediction

### During Session
App tracks objective metrics:
- App exits (15+ seconds away)
- Session completion (full vs early stop)
- Pauses

### Post-Session
1. Timer completes → Comparison view appears
2. Shows: Predicted vs Actual side-by-side
3. Dynamic message based on comparison (rotating)
4. Breakdown of what affected score

## UI Components

### EnergyMeterView (Pre-Session)
- Half-sheet modal presentation
- Vertical drag gesture to fill meter
- Animated flames that grow with level
- Glow effect intensifies with level
- Haptic feedback on level changes
- Labels: 1="Expecting distractions" → 5="Full laser mode"

### FocusPredictionResultView (Post-Session)
- Shows predicted flames vs actual flames
- Actual flames animate in one-by-one
- Dynamic insight message (rotates from pool)
- Score breakdown (distractions, completion)
- Confetti if actual > predicted

## Score Calculation

Actual score starts at 5, deductions:
- Each distraction (app exit 15s+): -1
- Early stop/cancel: -2
- Long pause (2+ min): -1
- Minimum score: 1

## Message Banks

### Actual > Predicted (Underestimated)
- "You underestimate yourself! 🚀"
- "Better than you thought! Keep trusting yourself 💪"
- "Plot twist: you crushed it 🎯"
- "Your focus surprised you today ✨"

### Actual = Predicted (Spot on)
- "Nailed it! You know yourself well 🔮"
- "Prediction master! Self-awareness unlocked 🧠"
- "Exactly as planned. You're dialed in 🎯"
- "Called it! Trust your instincts 👊"

### Actual < Predicted (Overestimated)
- "Tough one - awareness is the first step 💪"
- "Not your best, but you showed up. That counts 🙌"
- "Every session teaches you something 📚"
- "Tomorrow's a new chance to prove yourself 🌅"

## Data Model

Add to FocusRecord:
- `predictedFocus: Int?` (1-5, nil if skipped)
- `actualFocus: Int?` (1-5, calculated)
- `distractionCount: Int` (for solo sessions)

## Implementation Files

1. `EnergyMeterView.swift` - Pre-session prediction UI
2. `FocusPredictionResultView.swift` - Post-session comparison
3. Update `TimerView.swift` - Integrate prediction flow
4. Update `TimerService.swift` - Track distractions, calculate score
5. Update `FocusRecord.swift` - Add prediction fields
