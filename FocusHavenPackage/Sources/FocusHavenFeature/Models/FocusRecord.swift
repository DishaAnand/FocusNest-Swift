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

// MARK: - Session Stats (matching RN getSessionStatsInRange)

/// Stats for focus sessions in a date range
public struct SessionStats: Sendable {
    public let sessionsCompleted: Int
    public let avgSession: Int  // seconds
    public let longestSession: Int  // seconds

    public init(sessionsCompleted: Int = 0, avgSession: Int = 0, longestSession: Int = 0) {
        self.sessionsCompleted = sessionsCompleted
        self.avgSession = avgSession
        self.longestSession = longestSession
    }
}

extension FocusRecord {
    /// Calculate stats for focus sessions in date range
    /// Matches RN: `getSessionStatsInRange(start, end)`
    public static func getStatsInRange(records: [FocusRecord], start: Date, end: Date) -> SessionStats {
        let calendar = Calendar.current
        let startOfStart = calendar.startOfDay(for: start)
        let endOfEnd = calendar.date(bySettingHour: 23, minute: 59, second: 59, of: end) ?? end

        // Filter to focus sessions (not breaks) within range
        let focusSessions = records.filter { record in
            !record.isBreak &&
            record.date >= startOfStart &&
            record.date <= endOfEnd
        }

        let sessionsCompleted = focusSessions.count

        guard sessionsCompleted > 0 else {
            return SessionStats()
        }

        let durations = focusSessions.map { $0.duration }
        let longestSession = durations.max() ?? 0
        let totalSeconds = durations.reduce(0, +)
        let avgSession = totalSeconds / sessionsCompleted

        return SessionStats(
            sessionsCompleted: sessionsCompleted,
            avgSession: avgSession,
            longestSession: longestSession
        )
    }

    /// Delete all focus records from the model context
    /// Matches RN: `clearAllProgress()` / `clearAllSessions()`
    @MainActor
    public static func clearAll(from context: ModelContext) throws {
        try context.delete(model: FocusRecord.self)
    }
}
