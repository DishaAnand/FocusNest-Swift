import Foundation

public struct WakeUpVoice: Identifiable, Codable, Sendable {
    public var id: UUID
    public var name: String
    public var fileName: String // The WAV file in Library/Sounds/
    public var duration: TimeInterval
    public var isDefault: Bool
    public var createdAt: Date

    public init(
        id: UUID = UUID(),
        name: String,
        fileName: String,
        duration: TimeInterval,
        isDefault: Bool = false,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.fileName = fileName
        self.duration = duration
        self.isDefault = isDefault
        self.createdAt = createdAt
    }

    public var formattedDuration: String {
        let seconds = Int(duration)
        return "\(seconds) sec"
    }
}
