# Wake-Up Voices Feature Design

## Overview

When a user extends their break 2+ minutes past the timer, a personal voice recording plays to snap them back to focus - even if they're scrolling Instagram or watching Netflix.

## Problem

Users finish a focus session, start a break, then get lost in dopamine loops (social media, videos). They ignore notifications because they're easy to swipe away. The break extends from 5 minutes to 30+ minutes, breaking focus momentum.

## Solution

Personal voice recordings that play through the speaker when break extends too long. Could be:
- User's own voice with motivation
- Parent's voice saying "get back to work!"
- Friend roasting them
- Any audio that personally resonates

This works because:
- **Personal** - Not a generic app sound
- **Impossible to ignore** - Audio plays through speaker, not just a notification
- **Emotional connection** - Your mom's voice hits different than an app ping

## User Flow

### Setup (one-time)
1. Settings → "Wake-Up Voices"
2. Tap "+" to add recording
3. Choose: "Record" or "Import File"
4. Name the recording (e.g., "Mom's voice")
5. Optionally star one as default

### During Break
1. User starts 5 min break
2. Break timer ends
3. User is still away (in another app)
4. 2 minutes pass...
5. **Voice recording plays through speaker**
6. User snaps back, opens app
7. "Welcome back! Ready to focus?"

## Trigger Logic

```
Break ends → Start 2 min overtime countdown
    ↓
User returns to app? → Cancel countdown, all good
    ↓
2 min passes, still away? → Play voice recording
    ↓
After audio → Show notification: "Ready to refocus?"
```

## Recording Rules

- **Max length:** 30 seconds
- **Min length:** 3 seconds
- **Formats:** m4a, mp3, wav (standard iOS audio)
- **Storage:** Local only (privacy, simplicity)
- **Size estimate:** ~500KB per 30 sec recording

## Settings

| Setting | Options | Default |
|---------|---------|---------|
| Enable Wake-Up Voices | On/Off | Off |
| Play in silent mode | On/Off | On |
| Shuffle recordings | On/Off | Off |

## UI Screens

### Wake-Up Voices List (Settings)
- Simple list of recordings
- Each row: Name, duration, play preview button, star (default)
- "+" floating button to add
- Swipe to delete
- Empty state with "Add your first wake-up voice"

### Add Recording
- Two buttons: "Record" / "Import File"
- Record: Tap to start, tap to stop
- Import: iOS file picker
- Name input field
- Save button

### Welcome Back (when user returns)
- Shows after voice plays and user opens app
- "Welcome back! Ready to focus?"
- "Start Focus" button

## Technical Implementation

### New Files
- `WakeUpVoiceService.swift` - Core logic: recording, playback, triggers
- `WakeUpVoice.swift` - Model for a voice recording
- `WakeUpVoiceSettingsView.swift` - Settings UI
- `RecordVoiceView.swift` - Recording UI

### Background Audio
- Enable "Audio, AirPlay, and Picture in Picture" background mode
- Use AVAudioSession with `.playback` category
- Audio plays even when app is backgrounded

### Integration Points
- `TimerService` calls `WakeUpVoiceService` when break ends
- `WakeUpVoiceService` starts 2 min countdown
- If user returns (app becomes active), cancel countdown
- If countdown completes, play audio

## Data Model

```swift
struct WakeUpVoice: Identifiable, Codable {
    let id: UUID
    var name: String
    var fileName: String  // Local file reference
    var duration: TimeInterval
    var isDefault: Bool
    var createdAt: Date
}
```

## Privacy

- All recordings stored locally on device
- No cloud upload
- No analytics on voice content
- User has full control to delete anytime

## Future Enhancements (not in v1)
- Buddy Knock feature for paired sessions
- Escalating system (gentle notification first, then voice)
- Configurable overtime threshold
- Volume control for wake-up audio
