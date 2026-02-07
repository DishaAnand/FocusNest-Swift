import Foundation
import AVFoundation
import UserNotifications

@MainActor
@Observable
public final class WakeUpVoiceService: @unchecked Sendable {
    // MARK: - Published State
    public private(set) var voices: [WakeUpVoice] = []
    public private(set) var isRecording: Bool = false
    public private(set) var isPlaying: Bool = false
    public private(set) var conversionProgress: String? = nil

    // MARK: - Settings
    public var isEnabled: Bool {
        didSet { UserDefaults.standard.set(isEnabled, forKey: "wakeUpVoicesEnabled") }
    }
    public var shuffleEnabled: Bool {
        didSet { UserDefaults.standard.set(shuffleEnabled, forKey: "wakeUpVoicesShuffle") }
    }

    // MARK: - Private
    private var audioRecorder: AVAudioRecorder?
    private var audioPlayer: AVAudioPlayer?
    private let voicesKey = "wakeUpVoices"
    private let maxRecordingDuration: TimeInterval = 30 // iOS notification sound limit

    // MARK: - Directories
    private var recordingsDirectory: URL {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let recordingsPath = documentsPath.appendingPathComponent("WakeUpVoices", isDirectory: true)
        if !FileManager.default.fileExists(atPath: recordingsPath.path) {
            try? FileManager.default.createDirectory(at: recordingsPath, withIntermediateDirectories: true)
        }
        return recordingsPath
    }

    /// Library/Sounds directory - where iOS looks for custom notification sounds
    private var notificationSoundsDirectory: URL {
        let libraryPath = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask)[0]
        let soundsPath = libraryPath.appendingPathComponent("Sounds", isDirectory: true)
        if !FileManager.default.fileExists(atPath: soundsPath.path) {
            try? FileManager.default.createDirectory(at: soundsPath, withIntermediateDirectories: true)
        }
        return soundsPath
    }

    // MARK: - Init
    public init() {
        self.isEnabled = UserDefaults.standard.object(forKey: "wakeUpVoicesEnabled") as? Bool ?? false
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
        // Delete from Library/Sounds
        let soundURL = notificationSoundsDirectory.appendingPathComponent(voice.fileName)
        try? FileManager.default.removeItem(at: soundURL)

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

    public func getNotificationSoundURL(for voice: WakeUpVoice) -> URL {
        return notificationSoundsDirectory.appendingPathComponent(voice.fileName)
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

        if await AVAudioApplication.requestRecordPermission() == false {
            return false
        }

        // Record as M4A first (will convert to WAV later)
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
            audioRecorder?.record(forDuration: maxRecordingDuration) // Auto-stop at 30 sec
            isRecording = true
            return true
        } catch {
            print("Failed to start recording: \(error)")
            return false
        }
    }

    public func stopRecording() async -> (url: URL, duration: TimeInterval)? {
        guard let recorder = audioRecorder, isRecording else { return nil }

        recorder.stop()
        isRecording = false

        let url = recorder.url
        audioRecorder = nil

        // Get duration using AVURLAsset
        let asset = AVURLAsset(url: url)
        do {
            let duration = try await asset.load(.duration)
            let seconds = CMTimeGetSeconds(duration)
            return (url, seconds.isNaN ? 0 : min(seconds, maxRecordingDuration))
        } catch {
            print("Failed to get duration: \(error)")
            return (url, 0)
        }
    }

    public func cancelRecording() {
        guard let recorder = audioRecorder else { return }
        recorder.stop()
        isRecording = false
        try? FileManager.default.removeItem(at: recorder.url)
        audioRecorder = nil
    }

    /// Converts M4A to WAV and saves to Library/Sounds for notification use
    public func saveRecording(sourceURL: URL, name: String, duration: TimeInterval) async -> WakeUpVoice? {
        conversionProgress = "Converting audio..."
        print("🎤 [WakeUp] Starting save recording from: \(sourceURL.path)")
        print("🎤 [WakeUp] Sounds directory: \(notificationSoundsDirectory.path)")

        do {
            let wavFileName = "\(UUID().uuidString).wav"
            let wavURL = notificationSoundsDirectory.appendingPathComponent(wavFileName)
            print("🎤 [WakeUp] Will save WAV to: \(wavURL.path)")

            try await convertToWAV(sourceURL: sourceURL, destinationURL: wavURL)

            // Verify file exists
            let exists = FileManager.default.fileExists(atPath: wavURL.path)
            print("🎤 [WakeUp] WAV file exists after conversion: \(exists)")

            if exists {
                let attrs = try? FileManager.default.attributesOfItem(atPath: wavURL.path)
                let size = attrs?[.size] as? Int ?? 0
                print("🎤 [WakeUp] WAV file size: \(size) bytes")
            }

            // Clean up original M4A
            try? FileManager.default.removeItem(at: sourceURL)

            let voice = WakeUpVoice(name: name, fileName: wavFileName, duration: duration)
            addVoice(voice)
            print("🎤 [WakeUp] Voice saved successfully: \(wavFileName)")

            conversionProgress = nil
            return voice
        } catch {
            print("🎤 [WakeUp] Failed to convert recording: \(error)")
            conversionProgress = nil
            return nil
        }
    }

    // MARK: - Audio Conversion (M4A to WAV)
    private func convertToWAV(sourceURL: URL, destinationURL: URL) async throws {
        let asset = AVAsset(url: sourceURL)

        guard let audioTrack = try await asset.loadTracks(withMediaType: .audio).first else {
            throw ConversionError.noAudioTrack
        }

        // Set up asset reader with PCM output
        let reader = try AVAssetReader(asset: asset)

        let readerOutputSettings: [String: Any] = [
            AVFormatIDKey: kAudioFormatLinearPCM,
            AVLinearPCMBitDepthKey: 16,
            AVLinearPCMIsFloatKey: false,
            AVLinearPCMIsBigEndianKey: false,
            AVSampleRateKey: 44100.0,
            AVNumberOfChannelsKey: 1
        ]

        let readerOutput = AVAssetReaderTrackOutput(track: audioTrack, outputSettings: readerOutputSettings)
        reader.add(readerOutput)

        // Set up asset writer for WAV
        let writer = try AVAssetWriter(outputURL: destinationURL, fileType: .wav)

        let writerInputSettings: [String: Any] = [
            AVFormatIDKey: kAudioFormatLinearPCM,
            AVLinearPCMBitDepthKey: 16,
            AVLinearPCMIsFloatKey: false,
            AVLinearPCMIsBigEndianKey: false,
            AVLinearPCMIsNonInterleaved: false,
            AVSampleRateKey: 44100.0,
            AVNumberOfChannelsKey: 1
        ]

        let writerInput = AVAssetWriterInput(mediaType: .audio, outputSettings: writerInputSettings)
        writerInput.expectsMediaDataInRealTime = false
        writer.add(writerInput)

        // Start processing
        reader.startReading()
        writer.startWriting()
        writer.startSession(atSourceTime: .zero)

        // Process all samples
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            let queue = DispatchQueue(label: "com.focushaven.audioconversion")
            writerInput.requestMediaDataWhenReady(on: queue) {
                while writerInput.isReadyForMoreMediaData {
                    if let sampleBuffer = readerOutput.copyNextSampleBuffer() {
                        writerInput.append(sampleBuffer)
                    } else {
                        writerInput.markAsFinished()
                        continuation.resume()
                        return
                    }
                }
            }
        }

        await writer.finishWriting()

        if writer.status == .failed {
            throw writer.error ?? ConversionError.writeFailed
        }

        print("WAV conversion successful: \(destinationURL.path)")
    }

    enum ConversionError: Error {
        case noAudioTrack
        case writeFailed
    }

    // MARK: - Playback (for preview)
    public func playVoice(_ voice: WakeUpVoice) {
        let fileURL = getNotificationSoundURL(for: voice)
        playAudio(from: fileURL)
    }

    public func playAudio(from url: URL) {
        stopPlayback()

        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default, options: [])
            try session.setActive(true)

            audioPlayer = try AVAudioPlayer(contentsOf: url)
            audioPlayer?.volume = 1.0
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

    // MARK: - Notification Sound
    /// Returns the UNNotificationSound for the default voice, or system default if none
    public func getNotificationSound() -> UNNotificationSound {
        print("🔔 [WakeUp] getNotificationSound called - isEnabled: \(isEnabled), voices count: \(voices.count)")
        guard isEnabled, let voice = getDefaultVoice() else {
            print("🔔 [WakeUp] Returning default sound (not enabled or no voices)")
            return .default
        }

        // Verify the file exists
        let soundURL = notificationSoundsDirectory.appendingPathComponent(voice.fileName)
        let exists = FileManager.default.fileExists(atPath: soundURL.path)
        print("🔔 [WakeUp] Using custom sound: \(voice.fileName), exists: \(exists), path: \(soundURL.path)")

        // UNNotificationSound looks in Library/Sounds/ for the filename
        return UNNotificationSound(named: UNNotificationSoundName(rawValue: voice.fileName))
    }
}
