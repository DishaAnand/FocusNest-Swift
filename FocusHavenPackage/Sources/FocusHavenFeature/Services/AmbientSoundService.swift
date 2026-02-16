import Foundation
import AVFoundation

/// Service for playing ambient sounds during focus sessions
@MainActor
@Observable
public final class AmbientSoundService: @unchecked Sendable {
    private var audioPlayer: AVAudioPlayer?
    private var audioSession: AVAudioSession { AVAudioSession.sharedInstance() }

    /// Currently selected ambient sound
    public var selectedSound: AmbientSound {
        didSet {
            UserDefaults.standard.set(selectedSound.rawValue, forKey: "selectedAmbientSound")
        }
    }

    /// Whether ambient sound is currently playing
    public private(set) var isPlaying = false

    /// Volume level (0.0 to 1.0)
    public var volume: Float = 0.7 {
        didSet {
            audioPlayer?.volume = volume
            UserDefaults.standard.set(volume, forKey: "ambientSoundVolume")
        }
    }

    public init() {
        // Load saved preferences
        if let savedSound = UserDefaults.standard.string(forKey: "selectedAmbientSound"),
           let sound = AmbientSound(rawValue: savedSound) {
            self.selectedSound = sound
        } else {
            self.selectedSound = .silence
        }

        self.volume = UserDefaults.standard.object(forKey: "ambientSoundVolume") as? Float ?? 0.7
    }

    /// Start playing the selected ambient sound
    public func play() {
        guard selectedSound != .silence else {
            stop()
            return
        }

        guard let fileName = selectedSound.fileName else { return }

        // Configure audio session for background playback
        do {
            try audioSession.setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try audioSession.setActive(true)
        } catch {
            print("Failed to configure audio session: \(error)")
            return
        }

        // Try to load from bundle - check in Sounds subdirectory first, then root
        let soundsPath = "Sounds/\(fileName)"
        guard let url = Bundle.module.url(forResource: soundsPath, withExtension: "mp3") ??
                        Bundle.module.url(forResource: soundsPath, withExtension: "wav") ??
                        Bundle.module.url(forResource: fileName, withExtension: "mp3") ??
                        Bundle.module.url(forResource: fileName, withExtension: "wav") else {
            print("🔊 Could not find audio file: \(fileName)")
            print("🔊 Searched for: \(soundsPath).mp3, \(soundsPath).wav, \(fileName).mp3, \(fileName).wav")
            print("🔊 Bundle path: \(Bundle.module.bundlePath)")
            return
        }
        print("🔊 Found audio file at: \(url)")

        do {
            audioPlayer = try AVAudioPlayer(contentsOf: url)
            audioPlayer?.numberOfLoops = -1 // Loop indefinitely
            audioPlayer?.volume = volume
            audioPlayer?.prepareToPlay()
            let success = audioPlayer?.play() ?? false
            isPlaying = success
            print("🔊 Audio play started: \(success), volume: \(volume)")
        } catch {
            print("🔊 Failed to play audio: \(error)")
        }
    }

    /// Stop playing ambient sound
    public func stop() {
        audioPlayer?.stop()
        audioPlayer = nil
        isPlaying = false

        // Deactivate audio session
        try? audioSession.setActive(false, options: .notifyOthersOnDeactivation)
    }

    /// Pause ambient sound (for breaks or interruptions)
    public func pause() {
        audioPlayer?.pause()
        isPlaying = false
    }

    /// Resume ambient sound
    public func resume() {
        guard selectedSound != .silence, audioPlayer != nil else {
            play()
            return
        }
        audioPlayer?.play()
        isPlaying = true
    }

    /// Toggle between play and pause
    public func toggle() {
        if isPlaying {
            pause()
        } else {
            resume()
        }
    }

    /// Change sound and start playing if was already playing or if forced
    public func changeSound(to sound: AmbientSound, forcePlay: Bool = false) {
        let wasPlaying = isPlaying || audioPlayer != nil
        // Stop the current player without deactivating the audio session
        audioPlayer?.stop()
        audioPlayer = nil
        isPlaying = false
        selectedSound = sound
        if (wasPlaying || forcePlay) && sound != .silence {
            play()
        } else if sound == .silence {
            // Only deactivate session when switching to silence
            try? audioSession.setActive(false, options: .notifyOthersOnDeactivation)
        }
    }
}
