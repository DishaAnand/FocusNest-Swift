# iCloud Sync via CloudKit — Design Document

## Goal
Protect user data by syncing FocusRecord and FocusTask to iCloud via SwiftData + CloudKit. No login screen, no backend costs, no infrastructure to maintain.

## What Syncs
- **FocusRecord** — full session history (duration, task, completion status, distraction count, recharge %, focus score)
- **FocusTask** — task list with cumulative focus time

## What Stays Local
- **UserSettings** (UserDefaults) — timer durations, theme, toggles
- **Wake-up voice recordings** — audio files too heavy for iCloud sync
- **Ambient sound preferences** — trivial to re-select

## Architecture

### How It Works
SwiftData + CloudKit sync is built into Apple's frameworks. The app writes to a local SwiftData store as it does today. When CloudKit is available, SwiftData automatically mirrors that data to the user's private iCloud container. No custom sync logic needed.

### User Experience
- No login screen, no sign-up, no buttons
- Data appears on other devices automatically
- Delete and reinstall → data comes back from iCloud
- Works offline — syncs when connectivity returns

### Failure Modes (all graceful)
| Scenario | Local data | iCloud sync | Impact |
|----------|-----------|-------------|--------|
| Normal | Saved | Active | Full sync |
| iCloud full | Saved | Paused | Local-only, no data loss |
| iCloud disabled | Saved | Off | Local-only |
| Not signed in (~3%) | Saved | Off | Local-only |
| No internet | Saved | Queued | Syncs when online |

No scenario causes the app to break. Worst case = local-only (same as today).

## Implementation Changes

### 1. Entitlements
Add to `Config/FocusHaven.entitlements`:
- `com.apple.developer.icloud-services` → CloudKit
- iCloud container: `iCloud.com.dishaanand.focushaven`

### 2. Model Container (FocusHavenApp.swift)
```swift
// Change from:
.modelContainer(for: [FocusTask.self, FocusRecord.self])

// To:
.modelContainer(for: [FocusTask.self, FocusRecord.self],
                cloudKitDatabase: .automatic)
```

### 3. Model Audit
Ensure all `@Model` properties have default values (CloudKit requirement):
- Audit `FocusRecord` — all stored properties need defaults
- Audit `FocusTask` — all stored properties need defaults
- No optionals without defaults allowed

### 4. Settings Sync Status (optional)
Add a small indicator in SettingsView: "iCloud Sync: Active / Unavailable"

## What We Don't Build
- No login/auth screen
- No sync service
- No conflict resolution (last-write-wins is fine)
- No network monitoring
- No retry logic
- No backend infrastructure

## Cost
Zero. CloudKit storage is free for the developer. Data lives in each user's personal iCloud account.

## Limitations
- Apple-only (no Android sync). If Android is needed later, add a shared backend and migrate.
- Depends on user having iCloud enabled (~97% do)
- User's 5GB iCloud storage is shared with all their apps (FocusHaven data is tiny — ~1-2 MB/year)

## Success Criteria
- User installs app on second device → sees all their focus records and tasks
- User deletes and reinstalls → data restored from iCloud
- User with iCloud disabled → app works normally, just local-only
