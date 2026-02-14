# iCloud Sync Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Sync FocusRecord and FocusTask to iCloud via SwiftData + CloudKit — no login, no backend, automatic.

**Architecture:** Enable CloudKit on the existing SwiftData model container. All `@Model` types sync automatically. UserDefaults/audio files stay local. Graceful fallback to local-only if iCloud unavailable.

**Tech Stack:** SwiftData, CloudKit, Xcode entitlements

**Design doc:** `docs/plans/2026-02-14-icloud-sync-design.md`

---

### Task 1: Add CloudKit Entitlements

**Files:**
- Create: `FocusHaven/FocusHaven.entitlements`
- Modify: `FocusHaven.xcodeproj/project.pbxproj` (via Xcode build settings)

**Step 1: Create the entitlements file**

Create `FocusHaven/FocusHaven.entitlements`:
```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>aps-environment</key>
    <string>development</string>
    <key>com.apple.developer.icloud-services</key>
    <array>
        <string>CloudKit</string>
    </array>
    <key>com.apple.developer.icloud-container-identifiers</key>
    <array>
        <string>iCloud.com.dishaanand.focushaven</string>
    </array>
</dict>
</plist>
```

Note: `aps-environment` is required because CloudKit uses push notifications for sync. The `development` value is automatic for Debug builds; Xcode will switch to `production` for App Store builds.

**Step 2: Wire entitlements into the Xcode project**

The entitlements file must be referenced in the project's build settings. Use the PBXProjectHelper or manually add `CODE_SIGN_ENTITLEMENTS = FocusHaven/FocusHaven.entitlements` to the FocusHaven target's build settings in `project.pbxproj`.

Alternatively, use `sed` or direct edit to add the entitlements path to both Debug and Release build settings for the FocusHaven target:
```
CODE_SIGN_ENTITLEMENTS = FocusHaven/FocusHaven.entitlements;
```

**Step 3: Build to verify entitlements compile**

Run: `xcodebuild -workspace FocusHaven.xcworkspace -scheme FocusHaven -destination 'generic/platform=iOS' -configuration Debug build 2>&1 | grep -E "(BUILD|error:)"`

Expected: `BUILD SUCCEEDED`

**Step 4: Commit**

```bash
git add FocusHaven/FocusHaven.entitlements FocusHaven.xcodeproj/project.pbxproj
git commit -m "feat: add CloudKit entitlements for iCloud sync"
```

---

### Task 2: Make Models CloudKit-Compatible

CloudKit requires all non-optional `@Model` properties to have default values at the property declaration level (not just in `init`).

**Files:**
- Modify: `FocusHavenPackage/Sources/FocusHavenFeature/Models/FocusRecord.swift`
- Modify: `FocusHavenPackage/Sources/FocusHavenFeature/Models/FocusTask.swift`

**Step 1: Add default values to FocusRecord properties**

Change the property declarations (NOT the init — keep the init as-is):

```swift
@Model
public final class FocusRecord: @unchecked Sendable {
    public var id: UUID = UUID()
    public var date: Date = Date()
    public var duration: Int = 0
    public var isBreak: Bool = false
    public var taskId: UUID?
    public var taskTitle: String?
    public var wasCompleted: Bool = true
    public var wasBuddySession: Bool = false
    public var predictedFocus: Int?
    public var actualFocus: Int?
    public var distractionCount: Int = 0
    public var rechargePercentage: Double?
    public var wasFullyRecharged: Bool = false
    // ... init stays exactly the same
```

Properties that are already optional (`UUID?`, `String?`, `Int?`, `Double?`) don't need defaults — CloudKit handles optionals fine.

**Step 2: Add default values to FocusTask properties**

```swift
@Model
public final class FocusTask: @unchecked Sendable {
    public var id: UUID = UUID()
    public var title: String = ""
    public var isCompleted: Bool = false
    public var createdAt: Date = Date()
    public var completedAt: Date?
    public var totalFocusTime: Int = 0
    // ... init stays exactly the same
```

**Step 3: Build to verify**

Run: `xcodebuild -workspace FocusHaven.xcworkspace -scheme FocusHaven -destination 'generic/platform=iOS' -configuration Debug build 2>&1 | grep -E "(BUILD|error:)"`

Expected: `BUILD SUCCEEDED`

**Step 4: Commit**

```bash
git add FocusHavenPackage/Sources/FocusHavenFeature/Models/FocusRecord.swift FocusHavenPackage/Sources/FocusHavenFeature/Models/FocusTask.swift
git commit -m "feat: add default values to models for CloudKit compatibility"
```

---

### Task 3: Enable CloudKit on ModelContainer

**Files:**
- Modify: `FocusHaven/FocusHavenApp.swift:56`

**Step 1: Change modelContainer to use CloudKit**

Replace line 56:
```swift
// Before:
.modelContainer(for: [FocusTask.self, FocusRecord.self])

// After:
.modelContainer(for: [FocusTask.self, FocusRecord.self], cloudKitDatabase: .automatic)
```

The `.automatic` option means:
- Uses CloudKit private database if iCloud is available
- Falls back to local-only if iCloud is unavailable
- Handles all sync, conflict resolution, and offline queuing automatically

**Step 2: Build and test on simulator**

Run: `xcodebuild -workspace FocusHaven.xcworkspace -scheme FocusHaven -destination 'id=AE83F5C9-D939-4558-9CDE-3406C2B8423D' -configuration Debug build 2>&1 | grep -E "(BUILD|error:)"`

Expected: `BUILD SUCCEEDED`

Then install and launch on simulator to verify the app starts without crashing:
```bash
xcrun simctl install AE83F5C9-D939-4558-9CDE-3406C2B8423D <app-path>
xcrun simctl launch --console-pty AE83F5C9-D939-4558-9CDE-3406C2B8423D com.dishaanand.focushaven
```

Expected: App launches, timer screen appears, no crash. Console may show CloudKit messages about iCloud account status (expected on simulator — CloudKit requires a real iCloud account).

**Step 3: Commit**

```bash
git add FocusHaven/FocusHavenApp.swift
git commit -m "feat: enable CloudKit sync on SwiftData model container"
```

---

### Task 4: Add iCloud Sync Status to Settings

**Files:**
- Modify: `FocusHavenPackage/Sources/FocusHavenFeature/Views/Settings/SettingsView.swift`

**Step 1: Add sync status row to Settings**

Find the "About" section in SettingsView and add an iCloud status row above or within it. Use `FileManager.default.ubiquityIdentityToken` to check if iCloud is available:

```swift
// Add this computed property to the SettingsView struct:
private var iCloudStatus: (text: String, color: Color) {
    if FileManager.default.ubiquityIdentityToken != nil {
        return ("iCloud Sync: Active", .green)
    } else {
        return ("iCloud Sync: Unavailable", .secondary)
    }
}
```

Then add a row in the appropriate section:
```swift
HStack {
    Image(systemName: "icloud")
        .foregroundStyle(iCloudStatus.color)
    Text(iCloudStatus.text)
        .font(.system(size: 14))
        .foregroundStyle(Theme.textSecondary)
}
```

**Step 2: Build to verify**

Run: `xcodebuild -workspace FocusHaven.xcworkspace -scheme FocusHaven -destination 'generic/platform=iOS' -configuration Debug build 2>&1 | grep -E "(BUILD|error:)"`

Expected: `BUILD SUCCEEDED`

**Step 3: Commit**

```bash
git add FocusHavenPackage/Sources/FocusHavenFeature/Views/Settings/SettingsView.swift
git commit -m "feat: add iCloud sync status indicator in Settings"
```

---

### Task 5: Build and Deploy to Physical Device

**Files:** None (build & deploy only)

**Step 1: Build for device**

```bash
xcodebuild -workspace FocusHaven.xcworkspace -scheme FocusHaven -destination 'generic/platform=iOS' -configuration Debug build
```

Expected: `BUILD SUCCEEDED`

Note: CloudKit entitlements require a valid provisioning profile with iCloud capability. If the build fails with a signing error, the iCloud container may need to be registered on the Apple Developer Portal. Xcode with automatic signing should handle this, but if it doesn't, go to Signing & Capabilities in Xcode and add the iCloud capability there (this auto-registers the container).

**Step 2: Install on iPhone**

```bash
xcrun devicectl device install app --device 035E9AF9-4FC8-53E3-A445-518779A1118D <path-to-FocusHaven.app>
```

**Step 3: Verify on device**

- Open app, create a focus session or task
- Check Settings for "iCloud Sync: Active"
- Data should be syncing to iCloud (verifiable by installing on a second device or deleting/reinstalling)

**Step 4: Push all changes**

```bash
git push
```
