import Foundation

/// Available ambient sounds for focus sessions
public enum AmbientSound: String, CaseIterable, Identifiable, Sendable {
    case silence = "silence"
    case rain = "rain"
    case oceanWaves = "ocean_waves"
    case brownNoise = "brown_noise"
    case whiteNoise = "white_noise"
    case forest = "forest"
    case lofiBeats = "lofi_beats"

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .silence: return "Silence"
        case .rain: return "Rain"
        case .oceanWaves: return "Ocean Waves"
        case .brownNoise: return "Brown Noise"
        case .whiteNoise: return "White Noise"
        case .forest: return "Forest"
        case .lofiBeats: return "Lo-fi Beats"
        }
    }

    public var iconName: String {
        switch self {
        case .silence: return "speaker.slash.fill"
        case .rain: return "cloud.rain.fill"
        case .oceanWaves: return "water.waves"
        case .brownNoise: return "waveform"
        case .whiteNoise: return "waveform.path"
        case .forest: return "leaf.fill"
        case .lofiBeats: return "headphones"
        }
    }

    public var fileName: String? {
        switch self {
        case .silence: return nil
        case .rain: return "rain"
        case .oceanWaves: return "ocean_waves"
        case .brownNoise: return "brown_noise"
        case .whiteNoise: return "white_noise"
        case .forest: return "forest"
        case .lofiBeats: return "lofi_beats"
        }
    }

    /// Sounds that are available (have audio files)
    public static var availableSounds: [AmbientSound] {
        allCases
    }

    /// Whether this sound is available in the free tier
    public var isFree: Bool {
        switch self {
        case .silence, .rain:
            return true
        case .oceanWaves, .brownNoise, .whiteNoise, .forest, .lofiBeats:
            return false
        }
    }

    /// Free sounds only
    public static var freeSounds: [AmbientSound] {
        allCases.filter { $0.isFree }
    }

    /// Premium sounds only
    public static var premiumSounds: [AmbientSound] {
        allCases.filter { !$0.isFree }
    }
}
