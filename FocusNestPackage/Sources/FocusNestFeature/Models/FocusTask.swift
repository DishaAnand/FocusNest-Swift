import Foundation
import SwiftData

/// A task that the user can focus on during a Pomodoro session
@Model
public final class FocusTask: @unchecked Sendable {
    public var id: UUID
    public var title: String
    public var isCompleted: Bool
    public var createdAt: Date
    public var completedAt: Date?
    public var totalFocusTime: Int

    public init(
        id: UUID = UUID(),
        title: String,
        isCompleted: Bool = false,
        createdAt: Date = Date(),
        completedAt: Date? = nil,
        totalFocusTime: Int = 0
    ) {
        self.id = id
        self.title = title
        self.isCompleted = isCompleted
        self.createdAt = createdAt
        self.completedAt = completedAt
        self.totalFocusTime = totalFocusTime
    }

    public func markCompleted() {
        isCompleted = true
        completedAt = Date()
    }

    public func markIncomplete() {
        isCompleted = false
        completedAt = nil
    }

    public func addFocusTime(_ seconds: Int) {
        totalFocusTime += seconds
    }
}

extension FocusTask {
    public var formattedFocusTime: String {
        let hours = totalFocusTime / 3600
        let minutes = (totalFocusTime % 3600) / 60
        let seconds = totalFocusTime % 60

        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else if minutes > 0 {
            return "\(minutes)m"
        } else {
            return "\(seconds)s"
        }
    }
}
