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

// MARK: - Default Task (matching RN DEFAULT_TASKS)

extension FocusTask {
    /// Default task ID (matches RN 'other' task)
    public static let defaultTaskId = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!

    /// Create the default "Other" task
    /// Matches RN: `DEFAULT_TASKS = [{ id: 'other', title: 'Other', icon: 'refresh-outline' }]`
    public static func createDefaultTask() -> FocusTask {
        FocusTask(id: defaultTaskId, title: "Other")
    }

    /// Ensure at least one task exists, creating default if needed
    @MainActor
    public static func ensureDefaultTask(in context: ModelContext, existingTasks: [FocusTask]) {
        if existingTasks.isEmpty {
            context.insert(createDefaultTask())
        }
    }

    /// Delete all tasks from the model context
    @MainActor
    public static func clearAll(from context: ModelContext) throws {
        try context.delete(model: FocusTask.self)
    }
}
