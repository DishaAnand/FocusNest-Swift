import Foundation
import SwiftData

/// A record of a completed focus session
@Model
public final class FocusRecord: @unchecked Sendable {
    public var id: UUID
    public var date: Date
    public var duration: Int
    public var isBreak: Bool
    public var taskId: UUID?
    public var taskTitle: String?
    public var wasCompleted: Bool
    public var wasBuddySession: Bool

    public init(
        id: UUID = UUID(),
        date: Date = Date(),
        duration: Int,
        isBreak: Bool = false,
        taskId: UUID? = nil,
        taskTitle: String? = nil,
        wasCompleted: Bool = true,
        wasBuddySession: Bool = false
    ) {
        self.id = id
        self.date = date
        self.duration = duration
        self.isBreak = isBreak
        self.taskId = taskId
        self.taskTitle = taskTitle
        self.wasCompleted = wasCompleted
        self.wasBuddySession = wasBuddySession
    }
}

extension FocusRecord {
    public var durationMinutes: Int {
        duration / 60
    }

    public var formattedDuration: String {
        let hours = duration / 3600
        let minutes = (duration % 3600) / 60

        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
}
