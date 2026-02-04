# Category 3: Services - Audit

> Audit Date: 2026-02-04
> React Native Files: 2
> Swift Equivalents: Yes (with significant differences)

---

## File 1: `src/services/sessionService.ts`

### Data Model Comparison

**React Native SessionData:**
```typescript
interface SessionData {
  creator: string;
  task: string;
  duration: number;          // in minutes
  status: "waiting" | "active" | "complete";
  createdAt: number;
  startTime?: number;        // Firebase server timestamp
  creatorStatus: "focused" | "away";
  friendStatus: "waiting" | "focused" | "away";
  friendTask?: string;
  creatorViolations: number;
  friendViolations: number;
}
```

**Swift BuddySession:**
```swift
struct BuddySession {
    var sessionId: String
    var creatorId: String
    var state: SessionState     // waiting, active, completed, cancelled
    var duration: Int           // in seconds
    var createdAt: TimeInterval
    var startTime: TimeInterval?
    var endTime: TimeInterval?
    var participants: [String: SessionParticipant]  // Multi-participant support
}
```

| RN Field | Swift Equivalent | Status |
|----------|------------------|--------|
| `creator` | `creatorId` | ✅ |
| `task` | `participants[creator].taskTitle` | ⚠️ Different structure |
| `duration` (minutes) | `duration` (seconds) | ⚠️ Unit mismatch |
| `status` | `state` | ✅ (different enum values) |
| `createdAt` | `createdAt` | ✅ |
| `startTime` | `startTime` | ✅ |
| `creatorStatus` | `participants[creator].status` | ⚠️ Different structure |
| `friendStatus` | `participants[friend].status` | ⚠️ Different structure |
| `friendTask` | `participants[friend].taskTitle` | ⚠️ Different structure |
| `creatorViolations` | `participants[creator].violationCount` | ⚠️ Different structure |
| `friendViolations` | `participants[friend].violationCount` | ⚠️ Different structure |
| - | `endTime` | ✅ EXTRA (good addition) |
| - | `sessionId` in data | ✅ EXTRA |

### Functions Comparison

| RN Function | Purpose | Swift Equivalent | Status |
|-------------|---------|------------------|--------|
| `generateSessionId()` | Generate 8-char random ID | Uses UUID | ⚠️ Different format |
| `createSession(sessionId, task, duration)` | Create session in Firebase | `createSession(taskTitle:duration:userName:)` | ✅ |
| `joinSession(sessionId, friendTask?)` | Friend joins session | `joinSession(sessionId:taskTitle:userName:)` | ✅ |
| `startSession(sessionId)` | Start with serverTimestamp() | `startSession()` | ⚠️ Uses client time |
| `getSession(sessionId)` | One-time read | N/A (uses observer) | ✅ OK different |
| `listenToSession(sessionId, callback)` | Real-time updates | `startObservingSession(sessionId:)` | ✅ |
| `listenForFriendJoin(sessionId, callback)` | Specific friend join listener | Via session observer | ✅ OK different |
| `listenToServerTimeOffset(callback)` | Firebase server time offset | **MISSING** | ❌ CRITICAL |
| `updateUserStatus(sessionId, isCreator, status)` | Update focused/away | `updateStatus(_:)` | ✅ |
| `incrementViolations(sessionId, isCreator)` | Increment violation count | `incrementViolation()` | ✅ |
| `completeSession(sessionId)` | Mark complete | `completeSession()` | ✅ |
| - | Rate buddy after session | `rateBuddy(buddyId:rating:)` | ✅ EXTRA |
| - | Leave/cancel session | `leaveSession()` | ✅ EXTRA |

### Critical Issues Found

1. **❌ CRITICAL: `listenToServerTimeOffset()` missing**
   - RN uses Firebase `.info/serverTimeOffset` to sync timers
   - Without this, timers on two devices will drift based on local clock differences
   - **Impact**: Timer sync will be off between buddy devices

2. **⚠️ startSession uses client time, not serverTimestamp()**
   - RN: `startTime: serverTimestamp()` - uses Firebase server time
   - Swift: `Date().timeIntervalSince1970` - uses local device time
   - **Impact**: Session start times differ between devices

3. **⚠️ Session ID format different**
   - RN: 8-character random string (e.g., "a1b2c3d4")
   - Swift: Full UUID (e.g., "550e8400-e29b-41d4-a716-446655440000")
   - **Impact**: Longer share links, but not a bug

4. **⚠️ Duration unit difference**
   - RN: duration in minutes
   - Swift: duration in seconds (converted at UI layer)
   - **Impact**: Must verify conversion is correct everywhere

---

## File 2: `src/services/notificationService.ts`

### Functions Comparison

| RN Function | Purpose | Swift Equivalent | Status |
|-------------|---------|------------------|--------|
| `constructor` | Configure, create channel | `init()` | ✅ |
| - | Request permission | `requestAuthorization()` | ✅ EXTRA (good) |
| - | Check authorization status | `checkAuthorizationStatus()` | ✅ EXTRA (good) |
| `scheduleTimerNotification(seconds, mode)` | Schedule notification | `scheduleTimerCompletion(in:mode:taskTitle:)` | ✅ |
| `cancelAllNotifications()` | Cancel all | `cancelTimerNotifications()` | ⚠️ Different scope |
| - | Buddy joined notification | `notifyBuddyJoined(buddyName:)` | ✅ EXTRA |
| - | Buddy session complete | `notifyBuddySessionComplete()` | ✅ EXTRA |
| - | Clear badge | `clearBadge()` | ✅ EXTRA |

### Notification Content Comparison

| Scenario | RN Title | RN Body | Swift Title | Swift Body | Match |
|----------|----------|---------|-------------|------------|-------|
| Focus complete | "Focus session complete!" | "Time to take a break" | "Focus Session Complete!" | "Great work! Time for a well-deserved break." / "Great work on [task]! Time for a break." | ⚠️ Similar |
| Break complete | "Break time is over!" | "Ready to focus again?" | "Break Time Over" | "Ready to focus again? Let's go!" | ⚠️ Similar |

### Issues Found

1. **⚠️ cancelAllNotifications vs cancelTimerNotifications**
   - RN: Cancels ALL local notifications
   - Swift: Only cancels timer notifications (tracks specific IDs)
   - **Impact**: May leave orphaned notifications (minor)

2. **✅ Swift has extra buddy notifications (GOOD)**
   - `notifyBuddyJoined` and `notifyBuddySessionComplete` not in RN
   - These are improvements, not bugs

3. **✅ Swift handles authorization properly**
   - RN relies on library config
   - Swift explicitly requests and checks authorization

---

## Summary

| File | Functions | Implemented | Missing | Issues |
|------|-----------|-------------|---------|--------|
| sessionService.ts | 11 | 9 | 1 | 2 |
| notificationService.ts | 3 | 3 | 0 | 1 |

**CRITICAL ISSUES:**
1. `listenToServerTimeOffset()` missing - buddy timer sync will be wrong
2. `startSession` uses client time instead of Firebase serverTimestamp()

**MEDIUM ISSUES:**
1. Session ID format different (functional, not bug)
2. Duration unit conversion (verify UI handles this)
3. Cancel notifications scope difference

---

## Implementation Plan

### Priority 1: Fix Timer Sync (CRITICAL) - DONE

1. **Add `listenToServerTimeOffset()` to SessionService** - IMPLEMENTED
   - Added `serverTimeOffset` property to SessionService
   - Added `startListeningToServerTimeOffset()` that listens to Firebase `.info/serverTimeOffset`
   - Added `serverTime` computed property that returns accurate server time
   - Cleanup properly stops observer

2. **Fix `startSession()` to use server timestamp** - IMPLEMENTED
   - Changed from `Date().timeIntervalSince1970` to `serverTime`
   - Both devices will now have synchronized start times

### Priority 2: Verify Duration Handling

1. Check all places duration is used
2. Verify conversion between minutes (RN) and seconds (Swift)

---

## Implementation Completed

**SessionService.swift changes:**
- Added `serverTimeOffset: TimeInterval` property
- Added `serverTimeOffsetObserver: DatabaseHandle?`
- Added `serverTime` computed property
- Added `startListeningToServerTimeOffset()` method
- Added `stopListeningToServerTimeOffset()` method
- Updated `configure()` to start listening to server time offset
- Updated `cleanup()` to stop listening to server time offset
- Fixed `startSession()` to use `serverTime` instead of local time

---

## Tests Required

### SessionService Tests

1. Test `listenToServerTimeOffset` returns valid offset
2. Test `startSession` sets startTime using server time
3. Test session creation stores correct duration
4. Test observer fires on session changes
5. Test leave session cancels session if creator leaves during waiting

### NotificationService Tests

1. Test `scheduleTimerCompletion` schedules correctly for focus mode
2. Test `scheduleTimerCompletion` schedules correctly for break mode
3. Test `cancelTimerNotifications` removes pending notifications
4. Test notification content matches expected text

---

## Firebase Data Structure

### React Native (from sessionService.ts)
```
sessions/
  {8-char-id}/
    creator: "user1"
    task: "Study"
    duration: 25          // minutes
    status: "waiting"
    createdAt: 1234567890
    startTime: <serverTimestamp>
    creatorStatus: "focused"
    friendStatus: "waiting"
    friendTask: "Reading"
    creatorViolations: 0
    friendViolations: 0
```

### Swift (from SessionService.swift)
```
sessions/
  {uuid}/
    sessionId: "uuid"
    creatorId: "device-uuid"
    state: "waiting"
    duration: 1500        // seconds
    createdAt: 1234567890
    startTime: <local-time>    // BUG: should be server time
    endTime: null
    participants/
      {device-uuid}/
        odid: "device-uuid"
        name: "User Name"
        taskTitle: "Study"
        status: "focused"
        violationCount: 0
        joinedAt: 1234567890
        rating: null
```

**Note:** Different data structures mean RN and Swift apps CANNOT share buddy sessions. This may be intentional (native-only feature) but should be documented.
