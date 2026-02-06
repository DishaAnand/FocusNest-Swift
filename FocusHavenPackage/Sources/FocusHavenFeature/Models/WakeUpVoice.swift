import Foundation

/// A personal voice recording used to wake users from extended breaks
public struct WakeUpVoice: Identifiable, Codable, Equatable, Sendable {
    public let id: UUID
    public var name: String
    public var fileName: String
    public var duration: TimeInterval
    public var isDefault: Bool
    public var createdAt: Date

    public init(id: UUID = UUID(), name: String, fileName: String, duration: TimeInterval, isDefault: Bool = false) {
        self.id = id
        self.name = name
        self.fileName = fileName
        self.duration = duration
        self.isDefault = isDefault
        self.createdAt = Date()
    }

    /// Formatted duration string (e.g., "12 sec")
    public var formattedDuration: String {
        let seconds = Int(duration)
        return "\(seconds) sec"
    }
}
