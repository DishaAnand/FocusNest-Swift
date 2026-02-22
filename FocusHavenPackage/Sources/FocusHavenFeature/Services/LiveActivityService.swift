import ActivityKit
import Foundation

/// Service to manage Live Activities for the focus timer
@MainActor
@Observable
public final class LiveActivityService {
    private var currentActivity: Activity<FocusTimerAttributes>?

    public init() {}

    /// Check if Live Activities are supported and enabled
    public var isSupported: Bool {
        ActivityAuthorizationInfo().areActivitiesEnabled
    }

    /// Start a new Live Activity for the timer
    public func startActivity(
        remainingSeconds: Int,
        totalSeconds: Int,
        mode: String,
        taskName: String?
    ) async {
        guard isSupported else { return }

        // End any existing activity first, then start new one
        await endActivity()

        let attributes = FocusTimerAttributes(taskName: taskName)
        let endTime = Date().addingTimeInterval(TimeInterval(remainingSeconds))
        let state = FocusTimerAttributes.ContentState(
            endTime: endTime,
            totalSeconds: totalSeconds,
            mode: mode,
            isPaused: false
        )

        do {
            let activity = try Activity.request(
                attributes: attributes,
                content: .init(state: state, staleDate: nil),
                pushType: nil
            )
            self.currentActivity = activity
        } catch {
            print("[LiveActivity] Failed to start: \(error.localizedDescription)")
        }
    }

    /// Update the Live Activity (e.g., when paused/resumed)
    public func updateActivity(
        remainingSeconds: Int,
        totalSeconds: Int,
        mode: String,
        isPaused: Bool
    ) async {
        guard let activity = currentActivity else { return }

        let endTime = Date().addingTimeInterval(TimeInterval(remainingSeconds))
        let state = FocusTimerAttributes.ContentState(
            endTime: endTime,
            totalSeconds: totalSeconds,
            mode: mode,
            isPaused: isPaused
        )

        await activity.update(.init(state: state, staleDate: nil))
    }

    /// End the Live Activity
    public func endActivity() async {
        guard let activity = currentActivity else { return }

        await activity.end(nil, dismissalPolicy: .immediate)
        currentActivity = nil
    }

    /// End all Live Activities (cleanup)
    public func endAllActivities() async {
        for activity in Activity<FocusTimerAttributes>.activities {
            await activity.end(nil, dismissalPolicy: .immediate)
        }
        currentActivity = nil
    }
}
