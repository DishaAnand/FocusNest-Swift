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

        try? FileManager.default.removeItem(at: recorder.url)
        audioRecorder = nil
    }

    public func saveRecording(url: URL, name: String, duration: TimeInterval) -> WakeUpVoice {
        let fileName = url.lastPathComponent
        let voice = WakeUpVoice(name: name, fileName: fileName, duration: duration)
        addVoice(voice)
        return voice
    }

    // MARK: - Playback
    public func playVoice(_ voice: WakeUpVoice) {
        let fileURL = getFileURL(for: voice)
        playAudio(from: fileURL)
    }

    public func playAudio(from url: URL) {
        stopPlayback()

        do {
            let session = AVAudioSession.sharedInstance()

            if playInSilentMode {
                try session.setCategory(.playback, mode: .default, options: [])
            } else {
                try session.setCategory(.ambient, mode: .default)
            }
            try session.setActive(true)

            audioPlayer = try AVAudioPlayer(contentsOf: url)
            audioPlayer?.play()
            isPlaying = true

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
}
