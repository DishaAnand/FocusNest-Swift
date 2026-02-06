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
