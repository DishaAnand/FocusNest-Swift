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
        let fileURL = recordingsDirectory.appendingPathComponent(voice.fileName)
        try? FileManager.default.removeItem(at: fileURL)
        voices.removeAll { $0.id == voice.id }
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
