# Independent Timer Completion Flow

## Problem

When two participants have different focus durations (e.g., 25 min vs 45 min), the session currently ends for both when one person finishes. This breaks the independent timer feature.

## Solution

Allow each participant to complete independently with a celebration, then choose to continue supporting their buddy or leave.

## User Flows

### Person A Finishes First (Person B still has time)

1. **Timer hits zero** → Celebration screen appears
   - Confetti burst animation (particles falling from top)
   - Pulsing green glow effect on screen
   - Strong haptic feedback (success pattern)
   - Text: "You did it!"

2. **After celebration (2-3 seconds)** → Choice screen
   - Shows: "Your buddy has X min left"
   - Button: **[Focus Together]** - Continue with buddy's remaining time
   - Button: **[I'm Done]** - Go to rating screen

3. **If "Focus Together":**
   - Shows buddy's remaining timer (their countdown)
   - User A is in "support mode" - watching buddy's progress
   - When buddy's timer hits zero → both go to rating together
   - Same celebration plays for both

4. **If "I'm Done":**
   - Goes directly to rating screen
   - Rates buddy, sees completion stats
   - Can close the session
   - Person B continues uninterrupted

### Person B (Still Focusing)

- Buddy status card updates to show "✓ Completed"
- No popup or interruption
- Continues focusing until their timer ends
- When done → same celebration → rating screen

## Technical Implementation

### New UI States

Add to `BuddySessionStep`:
- `.myTimerComplete` - Show celebration + choice (Person A finished, B still going)
- `.supportMode` - Watching buddy's timer (chose "Focus Together")

### Components to Create

1. **ConfettiView** - SwiftUI particle animation
2. **CelebrationOverlay** - Combines confetti + glow + haptic
3. **PostCompletionChoiceView** - "Focus Together" vs "I'm Done" buttons

### Data Flow

1. Each participant tracks their own completion locally
2. When timer hits zero, check if buddy is still going
3. If buddy still going → show choice screen
4. If both done → both go to rating
5. "Focus Together" doesn't create new Firebase data - just UI state

### Firebase Updates

No schema changes needed. Existing fields sufficient:
- `participant.duration` - already per-participant
- Session `state` stays `active` until both complete or one leaves

## Animation Specs

### Confetti
- 50-100 particles
- Fall from top of screen
- Random colors (green, yellow, orange, blue)
- Duration: 3 seconds
- Physics: slight gravity, random horizontal drift

### Pulsing Glow
- Green color (#61BA82)
- Pulse from 0.3 to 0.6 opacity
- Duration: 0.5s per pulse
- 3 pulses total

### Haptic
- Use `.success` notification feedback
- Fire once at celebration start
