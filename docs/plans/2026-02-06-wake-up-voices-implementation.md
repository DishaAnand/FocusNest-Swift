# Wake-Up Voices Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Play personal voice recordings when users extend their break 2+ minutes past the timer.

**Architecture:** New `WakeUpVoiceService` manages recordings and triggers playback. Integrates with `TimerService` to detect when break ends and user doesn't return. Audio plays via AVFoundation even when app is backgrounded.

**Tech Stack:** SwiftUI, AVFoundation (recording + playback), FileManager (local storage), UserDefaults (settings)

---

## Task 1: Create WakeUpVoice Model

**Files:**
- Create: `FocusHavenPackage/Sources/FocusHavenFeature/Models/WakeUpVoice.swift`

**Step 1: Create the model file**

```swift
import Foundation

/// A personal voice recording used to wake users from extended breaks
struct WakeUpVoice: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    var fileName: String
    var duration: TimeInterval
    var isDefault: Bool
    var createdAt: Date

    init(id: UUID = UUID(), name: String, fileName: String, duration: TimeInterval, isDefault: Bool = false) {
        self.id = id
        self.name = name
        self.fileName = fileName
        self.duration = duration
        self.isDefault = isDefault
        self.createdAt = Date()
    }

    /// Formatted duration string (e.g., "12 sec")
    var formattedDuration: String {
        let seconds = Int(duration)
        return "\(seconds) sec"
    }
}
```

**Step 2: Verify file compiles**

Run: Build the project in Xcode or via `mcp__XcodeBuildMCP__build_sim`

**Step 3: Commit**

```bash
git add FocusHavenPackage/Sources/FocusHavenFeature/Models/WakeUpVoice.swift
git commit -m "feat: add WakeUpVoice model for voice recordings"
```

---

## Task 2: Create WakeUpVoiceService - Storage & Management

**Files:**
- Create: `FocusHavenPackage/Sources/FocusHavenFeature/Services/WakeUpVoiceService.swift`

**Step 1: Create service with storage functionality**

```swift
import Foundation
import AVFoundation
import UIKit

@MainActor
@Observable
public final class WakeUpVoiceService: @unchecked Sendable {
    // MARK: - Published State
    public private(set) var voices: [WakeUpVoice] = []
    public private(set) var isRecording: Bool = false
    public private(set) var isPlaying: Bool = false

    // MARK: - Settings
    public var isEnabled: Bool {
        didSet { UserDefaults.standard.set(isEnabled, forKey: "wakeUpVoicesEnabled") }
    }
    public var playInSilentMode: Bool {
        didSet { UserDefaults.standard.set(playInSilentMode, forKey: "wakeUpVoicesPlayInSilent") }
    }
    public var shuffleEnabled: Bool {
        didSet { UserDefaults.standard.set(shuffleEnabled, forKey: "wakeUpVoicesShuffle") }
    }

    // MARK: - Private
    private var audioRecorder: AVAudioRecorder?
    private var audioPlayer: AVAudioPlayer?
    private var overtimeTimer: Timer?
    private let voicesKey = "wakeUpVoices"

    // MARK: - Directories
    private var recordingsDirectory: URL {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let recordingsPath = documentsPath.appendingPathComponent("WakeUpVoices", isDirectory: true)

        if !FileManager.default.fileExists(atPath: recordingsPath.path) {
            try? FileManager.default.createDirectory(at: recordingsPath, withIntermediateDirectories: true)
        }
        return recordingsPath
    }

    // MARK: - Init
    public init() {
        self.isEnabled = UserDefaults.standard.object(forKey: "wakeUpVoicesEnabled") as? Bool ?? false
        self.playInSilentMode = UserDefaults.standard.object(forKey: "wakeUpVoicesPlayInSilent") as? Bool ?? true
        self.shuffleEnabled = UserDefaults.standard.object(forKey: "wakeUpVoicesShuffle") as? Bool ?? false
        loadVoices()
    }

    // MARK: - Persistence
    private func loadVoices() {
        guard let data = UserDefaults.standard.data(forKey: voicesKey),
              let decoded = try? JSONDecoder().decode([WakeUpVoice].self, from: data) else {
            voices = []
            return
        }
        voices = decoded
    }

    private func saveVoices() {
        guard let data = try? JSONEncoder().encode(voices) else { return }
        UserDefaults.standard.set(data, forKey: voicesKey)
    }

    // MARK: - Voice Management
    public func addVoice(_ voice: WakeUpVoice) {
        // If this is the first voice or marked as default, ensure it's the only default
        var newVoice = voice
        if voices.isEmpty {
            newVoice.isDefault = true
        }
        if newVoice.isDefault {
            voices = voices.map { var v = $0; v.isDefault = false; return v }
        }
        voices.append(newVoice)
        saveVoices()
    }

    public func deleteVoice(_ voice: WakeUpVoice) {
        // Delete audio file
        let fileURL = recordingsDirectory.appendingPathComponent(voice.fileName)
        try? FileManager.default.removeItem(at: fileURL)

        // Remove from list
        voices.removeAll { $0.id == voice.id }

        // If deleted voice was default, make first one default
        if voice.isDefault && !voices.isEmpty {
            voices[0].isDefault = true
        }
        saveVoices()
    }

    public func setDefault(_ voice: WakeUpVoice) {
        voices = voices.map { v in
            var updated = v
            updated.isDefault = (v.id == voice.id)
            return updated
        }
        saveVoices()
    }

    public func getDefaultVoice() -> WakeUpVoice? {
        if shuffleEnabled && !voices.isEmpty {
            return voices.randomElement()
        }
        return voices.first { $0.isDefault } ?? voices.first
    }

    public func getFileURL(for voice: WakeUpVoice) -> URL {
        return recordingsDirectory.appendingPathComponent(voice.fileName)
    }
}
```

**Step 2: Verify file compiles**

Run: Build the project

**Step 3: Commit**

```bash
git add FocusHavenPackage/Sources/FocusHavenFeature/Services/WakeUpVoiceService.swift
git commit -m "feat: add WakeUpVoiceService with storage and management"
```

---

## Task 3: Add Recording Functionality to WakeUpVoiceService

**Files:**
- Modify: `FocusHavenPackage/Sources/FocusHavenFeature/Services/WakeUpVoiceService.swift`

**Step 1: Add recording methods**

Add these methods to `WakeUpVoiceService`:

```swift
    // MARK: - Recording
    public func startRecording() async -> Bool {
        let session = AVAudioSession.sharedInstance()

        do {
            try session.setCategory(.playAndRecord, mode: .default)
            try session.setActive(true)
        } catch {
            print("Failed to set up audio session: \(error)")
            return false
        }

        // Check microphone permission
        if await AVAudioApplication.requestRecordPermission() == false {
            return false
        }

        let fileName = "\(UUID().uuidString).m4a"
        let fileURL = recordingsDirectory.appendingPathComponent(fileName)

        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44100,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]

        do {
            audioRecorder = try AVAudioRecorder(url: fileURL, settings: settings)
            audioRecorder?.record()
            isRecording = true
            return true
        } catch {
            print("Failed to start recording: \(error)")
            return false
        }
    }

    public func stopRecording() -> (url: URL, duration: TimeInterval)? {
        guard let recorder = audioRecorder, isRecording else { return nil }

        recorder.stop()
        isRecording = false

        let url = recorder.url
        let duration = recorder.currentTime

        audioRecorder = nil

        return (url, duration)
    }

    public func cancelRecording() {
        guard let recorder = audioRecorder else { return }

        recorder.stop()
        isRecording = false

        // Delete the incomplete file
        try? FileManager.default.removeItem(at: recorder.url)
        audioRecorder = nil
    }

    public func saveRecording(url: URL, name: String, duration: TimeInterval) -> WakeUpVoice {
        let fileName = url.lastPathComponent
        let voice = WakeUpVoice(name: name, fileName: fileName, duration: duration)
        addVoice(voice)
        return voice
    }
```

**Step 2: Verify file compiles**

Run: Build the project

**Step 3: Commit**

```bash
git add FocusHavenPackage/Sources/FocusHavenFeature/Services/WakeUpVoiceService.swift
git commit -m "feat: add recording functionality to WakeUpVoiceService"
```

---

## Task 4: Add Playback Functionality to WakeUpVoiceService

**Files:**
- Modify: `FocusHavenPackage/Sources/FocusHavenFeature/Services/WakeUpVoiceService.swift`

**Step 1: Add playback methods**

Add these methods to `WakeUpVoiceService`:

```swift
    // MARK: - Playback
    public func playVoice(_ voice: WakeUpVoice) {
        let fileURL = getFileURL(for: voice)
        playAudio(from: fileURL)
    }

    public func playAudio(from url: URL) {
        stopPlayback()

        do {
            let session = AVAudioSession.sharedInstance()

            // If playInSilentMode, use playback category which ignores silent switch
            if playInSilentMode {
                try session.setCategory(.playback, mode: .default, options: [])
            } else {
                try session.setCategory(.ambient, mode: .default)
            }
            try session.setActive(true)

            audioPlayer = try AVAudioPlayer(contentsOf: url)
            audioPlayer?.play()
            isPlaying = true

            // Stop playing state when audio finishes
            DispatchQueue.main.asyncAfter(deadline: .now() + (audioPlayer?.duration ?? 0) + 0.1) { [weak self] in
                self?.isPlaying = false
            }
        } catch {
            print("Failed to play audio: \(error)")
            isPlaying = false
        }
    }

    public func stopPlayback() {
        audioPlayer?.stop()
        audioPlayer = nil
        isPlaying = false
    }
```

**Step 2: Verify file compiles**

Run: Build the project

**Step 3: Commit**

```bash
git add FocusHavenPackage/Sources/FocusHavenFeature/Services/WakeUpVoiceService.swift
git commit -m "feat: add playback functionality to WakeUpVoiceService"
```

---

## Task 5: Add Break Overtime Trigger Logic

**Files:**
- Modify: `FocusHavenPackage/Sources/FocusHavenFeature/Services/WakeUpVoiceService.swift`

**Step 1: Add overtime detection and trigger**

Add these methods to `WakeUpVoiceService`:

```swift
    // MARK: - Break Overtime Trigger
    private let overtimeThreshold: TimeInterval = 120 // 2 minutes

    /// Called when break ends - starts countdown to play wake-up voice
    public func breakEnded() {
        guard isEnabled, !voices.isEmpty else { return }

        // Cancel any existing timer
        overtimeTimer?.invalidate()

        // Start 2-minute countdown
        overtimeTimer = Timer.scheduledTimer(withTimeInterval: overtimeThreshold, repeats: false) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.triggerWakeUpVoice()
            }
        }
    }

    /// Called when user returns to the app - cancels the wake-up trigger
    public func userReturned() {
        overtimeTimer?.invalidate()
        overtimeTimer = nil
    }

    /// Plays the wake-up voice
    private func triggerWakeUpVoice() {
        guard let voice = getDefaultVoice() else { return }
        playVoice(voice)
    }
```

**Step 2: Verify file compiles**

Run: Build the project

**Step 3: Commit**

```bash
git add FocusHavenPackage/Sources/FocusHavenFeature/Services/WakeUpVoiceService.swift
git commit -m "feat: add break overtime trigger logic"
```

---

## Task 6: Create WakeUpVoicesSettingsView

**Files:**
- Create: `FocusHavenPackage/Sources/FocusHavenFeature/Views/Settings/WakeUpVoicesSettingsView.swift`

**Step 1: Create the settings view**

```swift
import SwiftUI
import AVFoundation

@MainActor
struct WakeUpVoicesSettingsView: View {
    @Environment(WakeUpVoiceService.self) private var voiceService
    @State private var showingRecordSheet = false

    var body: some View {
        @Bindable var voiceService = voiceService

        List {
            Section {
                Toggle("Enable Wake-Up Voices", isOn: $voiceService.isEnabled)
            } footer: {
                Text("When enabled, a voice recording will play if you extend your break by more than 2 minutes.")
            }

            if voiceService.isEnabled {
                Section {
                    Toggle("Play in Silent Mode", isOn: $voiceService.playInSilentMode)
                    Toggle("Shuffle Recordings", isOn: $voiceService.shuffleEnabled)
                } footer: {
                    Text("Shuffle will randomly pick from your recordings each time.")
                }

                Section {
                    if voiceService.voices.isEmpty {
                        VStack(spacing: 16) {
                            Image(systemName: "waveform.circle")
                                .font(.system(size: 48))
                                .foregroundStyle(Theme.textTertiary)
                            Text("No recordings yet")
                                .font(Theme.bodyFont)
                                .foregroundStyle(Theme.textSecondary)
                            Text("Add your first wake-up voice")
                                .font(Theme.captionFont)
                                .foregroundStyle(Theme.textTertiary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 24)
                    } else {
                        ForEach(voiceService.voices) { voice in
                            VoiceRow(voice: voice)
                        }
                        .onDelete { indexSet in
                            indexSet.forEach { index in
                                voiceService.deleteVoice(voiceService.voices[index])
                            }
                        }
                    }

                    Button {
                        showingRecordSheet = true
                    } label: {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                                .foregroundStyle(Theme.focusColor)
                            Text("Add Recording")
                                .foregroundStyle(Theme.focusColor)
                        }
                    }
                } header: {
                    Text("Your Recordings")
                }
            }
        }
        .navigationTitle("Wake-Up Voices")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingRecordSheet) {
            RecordVoiceView()
        }
    }
}

// MARK: - Voice Row

private struct VoiceRow: View {
    let voice: WakeUpVoice
    @Environment(WakeUpVoiceService.self) private var voiceService

    var body: some View {
        HStack(spacing: 12) {
            // Play button
            Button {
                if voiceService.isPlaying {
                    voiceService.stopPlayback()
                } else {
                    voiceService.playVoice(voice)
                }
            } label: {
                Image(systemName: voiceService.isPlaying ? "stop.circle.fill" : "play.circle.fill")
                    .font(.title2)
                    .foregroundStyle(Theme.focusColor)
            }
            .buttonStyle(.plain)

            // Name and duration
            VStack(alignment: .leading, spacing: 2) {
                Text(voice.name)
                    .font(Theme.bodyFont)
                    .foregroundStyle(Theme.textPrimary)
                Text(voice.formattedDuration)
                    .font(Theme.captionFont)
                    .foregroundStyle(Theme.textTertiary)
            }

            Spacer()

            // Default star
            Button {
                voiceService.setDefault(voice)
            } label: {
                Image(systemName: voice.isDefault ? "star.fill" : "star")
                    .foregroundStyle(voice.isDefault ? .yellow : Theme.textTertiary)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 4)
    }
}
```

**Step 2: Verify file compiles**

Run: Build the project

**Step 3: Commit**

```bash
git add FocusHavenPackage/Sources/FocusHavenFeature/Views/Settings/WakeUpVoicesSettingsView.swift
git commit -m "feat: add WakeUpVoicesSettingsView"
```

---

## Task 7: Create RecordVoiceView

**Files:**
- Create: `FocusHavenPackage/Sources/FocusHavenFeature/Views/Settings/RecordVoiceView.swift`

**Step 1: Create the recording view**

```swift
import SwiftUI
import AVFoundation
import UniformTypeIdentifiers

@MainActor
struct RecordVoiceView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(WakeUpVoiceService.self) private var voiceService

    @State private var recordingState: RecordingState = .idle
    @State private var recordingDuration: TimeInterval = 0
    @State private var recordingTimer: Timer?
    @State private var recordedURL: URL?
    @State private var voiceName: String = ""
    @State private var showingFilePicker = false

    private enum RecordingState {
        case idle
        case recording
        case recorded
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 32) {
                Spacer()

                switch recordingState {
                case .idle:
                    idleView
                case .recording:
                    recordingView
                case .recorded:
                    recordedView
                }

                Spacer()
            }
            .padding()
            .navigationTitle("Add Recording")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        voiceService.cancelRecording()
                        dismiss()
                    }
                }
            }
            .fileImporter(
                isPresented: $showingFilePicker,
                allowedContentTypes: [.audio],
                allowsMultipleSelection: false
            ) { result in
                handleFileImport(result)
            }
        }
    }

    // MARK: - Idle View

    private var idleView: some View {
        VStack(spacing: 24) {
            Image(systemName: "waveform.circle")
                .font(.system(size: 80))
                .foregroundStyle(Theme.focusColor.opacity(0.6))

            Text("Record or import a voice")
                .font(Theme.bodyFont)
                .foregroundStyle(Theme.textSecondary)

            HStack(spacing: 20) {
                Button {
                    startRecording()
                } label: {
                    VStack(spacing: 8) {
                        Image(systemName: "mic.circle.fill")
                            .font(.system(size: 48))
                        Text("Record")
                            .font(Theme.bodyFont)
                    }
                    .foregroundStyle(Theme.focusColor)
                    .frame(width: 120, height: 100)
                    .background(Theme.backgroundSecondary)
                    .cornerRadius(16)
                }

                Button {
                    showingFilePicker = true
                } label: {
                    VStack(spacing: 8) {
                        Image(systemName: "folder.circle.fill")
                            .font(.system(size: 48))
                        Text("Import")
                            .font(Theme.bodyFont)
                    }
                    .foregroundStyle(Theme.textSecondary)
                    .frame(width: 120, height: 100)
                    .background(Theme.backgroundSecondary)
                    .cornerRadius(16)
                }
            }
        }
    }

    // MARK: - Recording View

    private var recordingView: some View {
        VStack(spacing: 24) {
            // Recording indicator
            Circle()
                .fill(Color.red)
                .frame(width: 16, height: 16)
                .opacity(recordingDuration.truncatingRemainder(dividingBy: 1) < 0.5 ? 1 : 0.3)
                .animation(.easeInOut(duration: 0.5).repeatForever(), value: recordingDuration)

            Text(formatDuration(recordingDuration))
                .font(.system(size: 48, weight: .light, design: .monospaced))
                .foregroundStyle(Theme.textPrimary)

            Text("Max 30 seconds")
                .font(Theme.captionFont)
                .foregroundStyle(Theme.textTertiary)

            Button {
                stopRecording()
            } label: {
                Image(systemName: "stop.circle.fill")
                    .font(.system(size: 72))
                    .foregroundStyle(.red)
            }
        }
    }

    // MARK: - Recorded View

    private var recordedView: some View {
        VStack(spacing: 24) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 64))
                .foregroundStyle(.green)

            Text(formatDuration(recordingDuration))
                .font(.system(size: 32, weight: .light))
                .foregroundStyle(Theme.textSecondary)

            // Preview button
            Button {
                if let url = recordedURL {
                    voiceService.playAudio(from: url)
                }
            } label: {
                HStack {
                    Image(systemName: "play.fill")
                    Text("Preview")
                }
                .font(Theme.bodyFont)
                .foregroundStyle(Theme.focusColor)
            }

            // Name input
            TextField("Name this recording", text: $voiceName)
                .textFieldStyle(.roundedBorder)
                .padding(.horizontal, 32)

            // Save button
            Button {
                saveRecording()
            } label: {
                Text("Save")
                    .font(Theme.bodyFont.weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(voiceName.isEmpty ? Theme.textTertiary : Theme.focusColor)
                    .cornerRadius(12)
            }
            .disabled(voiceName.isEmpty)
            .padding(.horizontal, 32)
        }
    }

    // MARK: - Actions

    private func startRecording() {
        Task {
            let started = await voiceService.startRecording()
            if started {
                recordingState = .recording
                recordingDuration = 0

                // Start duration timer
                recordingTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
                    Task { @MainActor in
                        recordingDuration += 0.1

                        // Auto-stop at 30 seconds
                        if recordingDuration >= 30 {
                            stopRecording()
                        }
                    }
                }
            }
        }
    }

    private func stopRecording() {
        recordingTimer?.invalidate()
        recordingTimer = nil

        if let result = voiceService.stopRecording() {
            recordedURL = result.url
            recordingDuration = result.duration
            recordingState = .recorded
        }
    }

    private func saveRecording() {
        guard let url = recordedURL else { return }
        _ = voiceService.saveRecording(url: url, name: voiceName, duration: recordingDuration)
        dismiss()
    }

    private func handleFileImport(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }

            // Copy file to recordings directory
            let fileName = "\(UUID().uuidString).m4a"
            let destURL = voiceService.getFileURL(for: WakeUpVoice(name: "", fileName: fileName, duration: 0))

            do {
                // Start accessing security-scoped resource
                guard url.startAccessingSecurityScopedResource() else { return }
                defer { url.stopAccessingSecurityScopedResource() }

                try FileManager.default.copyItem(at: url, to: destURL)

                // Get duration
                let asset = AVURLAsset(url: destURL)
                Task {
                    let duration = try await asset.load(.duration)
                    let seconds = CMTimeGetSeconds(duration)

                    await MainActor.run {
                        recordedURL = destURL
                        recordingDuration = min(seconds, 30) // Cap at 30 sec
                        recordingState = .recorded
                        voiceName = url.deletingPathExtension().lastPathComponent
                    }
                }
            } catch {
                print("Failed to import file: \(error)")
            }

        case .failure(let error):
            print("File import failed: \(error)")
        }
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        let seconds = Int(duration)
        let tenths = Int((duration - Double(seconds)) * 10)
        return String(format: "%02d.%d", seconds, tenths)
    }
}
```

**Step 2: Verify file compiles**

Run: Build the project

**Step 3: Commit**

```bash
git add FocusHavenPackage/Sources/FocusHavenFeature/Views/Settings/RecordVoiceView.swift
git commit -m "feat: add RecordVoiceView for recording and importing audio"
```

---

## Task 8: Integrate WakeUpVoiceService into App

**Files:**
- Modify: `FocusHavenPackage/Sources/FocusHavenFeature/ContentView.swift`

**Step 1: Add WakeUpVoiceService to environment**

Find where other services are initialized (like TimerService, NotificationService) and add:

```swift
@State private var wakeUpVoiceService = WakeUpVoiceService()
```

And add to the environment chain:

```swift
.environment(wakeUpVoiceService)
```

**Step 2: Verify file compiles**

Run: Build the project

**Step 3: Commit**

```bash
git add FocusHavenPackage/Sources/FocusHavenFeature/ContentView.swift
git commit -m "feat: add WakeUpVoiceService to app environment"
```

---

## Task 9: Add Wake-Up Voices to Settings

**Files:**
- Modify: `FocusHavenPackage/Sources/FocusHavenFeature/Views/Settings/SettingsView.swift`

**Step 1: Add navigation link to WakeUpVoicesSettingsView**

Add this section after the "Feedback" section:

```swift
Section {
    NavigationLink {
        WakeUpVoicesSettingsView()
    } label: {
        HStack {
            Image(systemName: "waveform.circle")
                .foregroundStyle(Theme.focusColor)
            Text("Wake-Up Voices")
        }
    }
} footer: {
    Text("Play a personal voice recording when you extend your break too long.")
}
```

**Step 2: Verify file compiles**

Run: Build the project

**Step 3: Commit**

```bash
git add FocusHavenPackage/Sources/FocusHavenFeature/Views/Settings/SettingsView.swift
git commit -m "feat: add Wake-Up Voices link to Settings"
```

---

## Task 10: Integrate Trigger with TimerService

**Files:**
- Modify: `FocusHavenPackage/Sources/FocusHavenFeature/Views/Timer/TimerView.swift`

**Step 1: Add WakeUpVoiceService environment and trigger logic**

Add to TimerView:

```swift
@Environment(WakeUpVoiceService.self) private var wakeUpVoiceService
```

In the `onChange(of: scenePhase)` handler, add logic to:
1. Call `wakeUpVoiceService.breakEnded()` when break completes
2. Call `wakeUpVoiceService.userReturned()` when user returns to app during break

In the `setupTimerCallbacks()` where `onComplete` is set, after a break completes:

```swift
// When break ends, start wake-up voice countdown
if mode == .shortBreak || mode == .longBreak {
    wakeUpVoiceService.breakEnded()
}
```

In `scenePhase` handler when user returns during break:

```swift
// User returned during break - cancel wake-up voice
if timerService.isBreak || (!timerService.isRunning && timerService.mode != .focus) {
    wakeUpVoiceService.userReturned()
}
```

**Step 2: Verify file compiles**

Run: Build the project

**Step 3: Commit**

```bash
git add FocusHavenPackage/Sources/FocusHavenFeature/Views/Timer/TimerView.swift
git commit -m "feat: integrate wake-up voice trigger with timer"
```

---

## Task 11: Add Microphone Permission to Info.plist

**Files:**
- Modify: `FocusHaven/Info.plist` (or add via Xcode target settings)

**Step 1: Add NSMicrophoneUsageDescription**

Add to Info.plist:

```xml
<key>NSMicrophoneUsageDescription</key>
<string>FocusHaven needs microphone access to record wake-up voice messages that play when you extend your breaks.</string>
```

**Step 2: Verify permission works**

Run: Build and run, try to record - should see permission prompt

**Step 3: Commit**

```bash
git add FocusHaven/Info.plist
git commit -m "feat: add microphone permission for voice recording"
```

---

## Task 12: Final Integration Test

**Step 1: Build and run on simulator**

Run: `mcp__XcodeBuildMCP__build_run_sim`

**Step 2: Test the full flow**

1. Go to Settings → Wake-Up Voices
2. Enable the feature
3. Add a recording (record or import)
4. Start a focus session
5. Complete focus, start break
6. When break ends, don't return for 2+ minutes
7. Verify voice plays

**Step 3: Install on device and test**

Run: Build for device and install

**Step 4: Final commit**

```bash
git add -A
git commit -m "feat: complete Wake-Up Voices feature"
```

---

## Summary

This plan creates:
1. **WakeUpVoice model** - Data structure for voice recordings
2. **WakeUpVoiceService** - Recording, playback, storage, and trigger logic
3. **WakeUpVoicesSettingsView** - Settings UI with toggle and recording list
4. **RecordVoiceView** - Recording and import UI
5. **Integration** - Connects to TimerService to trigger on break overtime

The feature is self-contained and doesn't modify existing timer logic significantly - it just hooks into the break completion event.
