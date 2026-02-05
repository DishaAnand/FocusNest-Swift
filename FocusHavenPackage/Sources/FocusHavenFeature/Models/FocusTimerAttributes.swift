import ActivityKit
import Foundation

/// Attributes for the Focus Timer Live Activity
public struct FocusTimerAttributes: ActivityAttributes {
    /// The name of the task being worked on (if any)
    public let taskName: String?

    public init(taskName: String? = nil) {
        self.taskName = taskName
    }

    /// Dynamic state that updates during the Live Activity
    public struct ContentState: Codable, Hashable {
        /// When the timer will end (used for automatic countdown)
        public let endTime: Date
        /// Total duration in seconds
        public let totalSeconds: Int
        /// Current mode: "focus", "shortBreak", "longBreak"
        public let mode: String
        /// Whether the timer is paused
        public let isPaused: Bool

        public init(endTime: Date, totalSeconds: Int, mode: String, isPaused: Bool) {
            self.endTime = endTime
            self.totalSeconds = totalSeconds
            self.mode = mode
            self.isPaused = isPaused
        }

        /// Display name for the mode
        public var modeDisplayName: String {
            switch mode {
            case "focus": return "Focus"
            case "shortBreak": return "Short Break"
            case "longBreak": return "Long Break"
            default: return "Focus"
            }
        }

        /// Whether this is a break mode
        public var isBreak: Bool {
            mode == "shortBreak" || mode == "longBreak"
        }
    }
}
