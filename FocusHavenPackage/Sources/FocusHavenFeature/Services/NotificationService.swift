import Foundation
import UserNotifications

@MainActor
@Observable
public final class NotificationService: @unchecked Sendable {
    public private(set) var isAuthorized: Bool = false
    private var pendingNotificationIds: Set<String> = []

    public init() {
        Task { await checkAuthorizationStatus() }
    }

    public func requestAuthorization() async -> Bool {
        do {
            let granted = try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .sound, .badge])
            isAuthorized = granted
            return granted
        } catch {
            isAuthorized = false
            return false
        }
    }

    public func checkAuthorizationStatus() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        isAuthorized = settings.authorizationStatus == .authorized
    }

    public func scheduleTimerCompletion(in seconds: Int, mode: TimerMode, taskTitle: String?) async {
        guard isAuthorized else { return }

        let content = UNMutableNotificationContent()
        switch mode {
        case .focus:
            content.title = "Focus Session Complete!"
            content.body = taskTitle.map { "Great work on \"\($0)\"! Time for a break." } ?? "Great work! Time for a well-deserved break."
        case .shortBreak, .longBreak:
            content.title = "Break Time Over"
            content.body = "Ready to focus again? Let's go!"
        }
        content.sound = .default
        content.badge = 1

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: TimeInterval(max(1, seconds)), repeats: false)
        let identifier = "timer-\(UUID().uuidString)"
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)

        do {
            try await UNUserNotificationCenter.current().add(request)
            pendingNotificationIds.insert(identifier)
        } catch {}
    }

    public func cancelTimerNotifications() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: Array(pendingNotificationIds))
        pendingNotificationIds.removeAll()
    }

    public func notifyBuddyJoined(buddyName: String? = nil) async {
        guard isAuthorized else { return }
        let content = UNMutableNotificationContent()
        content.title = "Buddy Joined!"
        content.body = buddyName.map { "\($0) has joined your focus session." } ?? "A buddy has joined your focus session. Ready to start!"
        content.sound = .default
        let request = UNNotificationRequest(identifier: "buddy-join-\(UUID().uuidString)", content: content, trigger: nil)
        try? await UNUserNotificationCenter.current().add(request)
    }

    public func notifyBuddySessionComplete() async {
        guard isAuthorized else { return }
        let content = UNMutableNotificationContent()
        content.title = "Buddy Session Complete!"
        content.body = "You and your buddy crushed it! Time to rate your session."
        content.sound = .default
        content.badge = 1
        let request = UNNotificationRequest(identifier: "buddy-complete-\(UUID().uuidString)", content: content, trigger: nil)
        try? await UNUserNotificationCenter.current().add(request)
    }

    public func clearBadge() {
        UNUserNotificationCenter.current().setBadgeCount(0) { _ in }
    }
}
