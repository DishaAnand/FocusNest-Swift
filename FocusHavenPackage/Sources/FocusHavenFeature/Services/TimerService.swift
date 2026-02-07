import Foundation
import UIKit

public enum TimerMode: String, Sendable {
    case focus = "focus"
    case shortBreak = "shortBreak"
    case longBreak = "longBreak"

    public var displayName: String {
        switch self {
        case .focus: return "Focus"
        case .shortBreak: return "Short Break"
        case .longBreak: return "Long Break"
        }
    }
}

public enum TimerState: Sendable, Equatable {
    case idle
    case running
    case paused
}

@MainActor
@Observable
public final class TimerService: @unchecked Sendable {
    public private(set) var remainingTime: Int
    public private(set) var totalDuration: Int
    public private(set) var state: TimerState = .idle
    public private(set) var mode: TimerMode = .focus
    public private(set) var completedSessions: Int = 0
    public var selectedTask: FocusTask?
    public var onComplete: ((TimerMode) -> Void)?
    public var onTick: (() -> Void)?

    private var timer: Timer?
    private var displayTimer: Timer? // High-frequency timer for smooth progress
    private var backgroundTaskId: UIBackgroundTaskIdentifier = .invalid
    private var backgroundEnterTime: Date?
    private var wasRunningBeforeBackground: Bool = false
    private let settings: UserSettings
    private let liveActivityService: LiveActivityService
    private let notificationService: NotificationService
    private let wakeUpVoiceService: WakeUpVoiceService

    // For smooth progress calculation
    private var sessionStartTime: Date?
    private var pausedElapsedTime: TimeInterval = 0

    /// Smooth progress for animation (updates at 60fps)
    public private(set) var progress: Double = 0.0

    private func calculateProgress() -> Double {
        guard totalDuration > 0 else { return 0.0 }
        guard state == .running, let startTime = sessionStartTime else {
            // When paused or idle, use integer-based progress
            return 1.0 - (Double(remainingTime) / Double(totalDuration))
        }
        // Smooth progress based on precise elapsed time
        let elapsed = pausedElapsedTime + Date().timeIntervalSince(startTime)
        let smoothProgress = elapsed / Double(totalDuration)
        return min(max(smoothProgress, 0.0), 1.0)
    }

    public var isRunning: Bool { state == .running }
    public var isPaused: Bool { state == .paused }

    public var formattedTime: String {
        let minutes = remainingTime / 60
        let seconds = remainingTime % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    public var isBreak: Bool {
        mode == .shortBreak || mode == .longBreak
    }

    public init(settings: UserSettings, liveActivityService: LiveActivityService, notificationService: NotificationService, wakeUpVoiceService: WakeUpVoiceService) {
        self.settings = settings
        self.liveActivityService = liveActivityService
        self.notificationService = notificationService
        self.wakeUpVoiceService = wakeUpVoiceService
        self.totalDuration = settings.focusDuration
        self.remainingTime = settings.focusDuration
        setupBackgroundObservers()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    public func cleanup() {
        timer?.invalidate()
        timer = nil
        displayTimer?.invalidate()
        displayTimer = nil
    }

    public func start() {
        guard state != .running else { return }
        if state == .idle {
            remainingTime = totalDuration
            pausedElapsedTime = 0
            progress = 0
        }
        sessionStartTime = Date()
        state = .running
        startTimer()

        // Start Live Activity
        liveActivityService.startActivity(
            remainingSeconds: remainingTime,
            totalSeconds: totalDuration,
            mode: mode.rawValue,
            taskName: selectedTask?.title
        )

        // Schedule notification for timer completion
        Task {
            let customSound = isBreak ? wakeUpVoiceService.getNotificationSound() : nil
            await notificationService.scheduleTimerCompletion(
                in: remainingTime,
                mode: mode,
                taskTitle: selectedTask?.title,
                customBreakSound: customSound
            )
        }
    }

    public func pause() {
        guard state == .running else { return }
        // Accumulate elapsed time when pausing
        if let startTime = sessionStartTime {
            pausedElapsedTime += Date().timeIntervalSince(startTime)
        }
        sessionStartTime = nil
        state = .paused
        stopTimer()
        updateProgress() // Freeze at current progress

        // Cancel scheduled notification
        notificationService.cancelTimerNotifications()

        // Update Live Activity to show paused state
        Task {
            await liveActivityService.updateActivity(
                remainingSeconds: remainingTime,
                totalSeconds: totalDuration,
                mode: mode.rawValue,
                isPaused: true
            )
        }
    }

    public func resume() {
        guard state == .paused else { return }
        sessionStartTime = Date() // Start fresh, pausedElapsedTime already has accumulated time
        state = .running
        startTimer()

        // Update Live Activity with new end time
        Task {
            await liveActivityService.updateActivity(
                remainingSeconds: remainingTime,
                totalSeconds: totalDuration,
                mode: mode.rawValue,
                isPaused: false
            )
        }

        // Reschedule notification for remaining time
        Task {
            let customSound = isBreak ? wakeUpVoiceService.getNotificationSound() : nil
            await notificationService.scheduleTimerCompletion(
                in: remainingTime,
                mode: mode,
                taskTitle: selectedTask?.title,
                customBreakSound: customSound
            )
        }
    }

    public func togglePlayPause() {
        switch state {
        case .idle: start()
        case .running: pause()
        case .paused: resume()
        }
    }

    public func stop() {
        stopTimer()
        state = .idle
        pausedElapsedTime = 0
        sessionStartTime = nil
        resetToMode(mode)
        progress = 0

        // Cancel scheduled notification
        notificationService.cancelTimerNotifications()

        // End Live Activity
        Task {
            await liveActivityService.endActivity()
        }
    }

    public func skip() {
        stopTimer()
        pausedElapsedTime = 0
        sessionStartTime = nil

        // Cancel scheduled notification
        notificationService.cancelTimerNotifications()

        // End Live Activity before advancing
        Task {
            await liveActivityService.endActivity()
        }

        advanceToNextMode()
    }

    /// Start an extension session with a custom duration (used when user chooses to keep focusing)
    public func startExtension(duration: Int) {
        stopTimer()

        // Cancel any existing notification
        notificationService.cancelTimerNotifications()

        // End existing Live Activity
        Task {
            await liveActivityService.endActivity()
        }

        mode = .focus
        state = .idle
        pausedElapsedTime = 0
        sessionStartTime = nil
        totalDuration = duration
        remainingTime = duration
        progress = 0
        start()
    }

    public func reset() {
        stopTimer()
        state = .idle
        mode = .focus
        completedSessions = 0
        totalDuration = settings.focusDuration
        remainingTime = settings.focusDuration
        selectedTask = nil
        pausedElapsedTime = 0

        // Cancel scheduled notification
        notificationService.cancelTimerNotifications()

        // End Live Activity
        Task {
            await liveActivityService.endActivity()
        }
        sessionStartTime = nil
        progress = 0
    }

    public func setMode(_ newMode: TimerMode, duration: Int? = nil) {
        stopTimer()
        mode = newMode
        state = .idle
        pausedElapsedTime = 0
        sessionStartTime = nil

        switch newMode {
        case .focus: totalDuration = duration ?? settings.focusDuration
        case .shortBreak: totalDuration = duration ?? settings.breakDuration
        case .longBreak: totalDuration = duration ?? settings.longBreakDuration
        }
        remainingTime = totalDuration
        progress = 0
    }

    private func startTimer() {
        timer?.invalidate()
        displayTimer?.invalidate()

        // 1-second timer for countdown display and completion check
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor [self] in
                self.tick()
            }
        }

        // 60fps timer for ultra-smooth progress animation
        displayTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor [self] in
                self.updateProgress()
            }
        }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
        displayTimer?.invalidate()
        displayTimer = nil
    }

    private func updateProgress() {
        progress = calculateProgress()
    }

    private func tick() {
        guard state == .running else { return }
        remainingTime -= 1
        onTick?()
        if remainingTime <= 0 { completeCurrentSession() }
    }

    private func completeCurrentSession() {
        stopTimer()
        state = .idle
        let completedMode = mode
        onComplete?(completedMode)
        if completedMode == .focus {
            completedSessions += 1
            selectedTask?.addFocusTime(totalDuration)
        }
        advanceToNextMode()
        let shouldAutoStart = (isBreak && settings.autoStartBreaks) || (!isBreak && settings.autoStartFocus)
        if shouldAutoStart { start() }
    }

    private func advanceToNextMode() {
        switch mode {
        case .focus:
            if completedSessions > 0 && completedSessions % settings.sessionsBeforeLongBreak == 0 {
                setMode(.longBreak)
            } else {
                setMode(.shortBreak)
            }
        case .shortBreak, .longBreak:
            setMode(.focus)
        }
    }

    private func resetToMode(_ targetMode: TimerMode) {
        switch targetMode {
        case .focus: totalDuration = settings.focusDuration
        case .shortBreak: totalDuration = settings.breakDuration
        case .longBreak: totalDuration = settings.longBreakDuration
        }
        remainingTime = totalDuration
    }

    private func setupBackgroundObservers() {
        NotificationCenter.default.addObserver(forName: UIApplication.didEnterBackgroundNotification, object: nil, queue: .main) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor [self] in
                self.handleEnterBackground()
            }
        }
        NotificationCenter.default.addObserver(forName: UIApplication.willEnterForegroundNotification, object: nil, queue: .main) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor [self] in
                self.handleEnterForeground()
            }
        }
    }

    private func handleEnterBackground() {
        wasRunningBeforeBackground = (state == .running)
        if wasRunningBeforeBackground {
            backgroundEnterTime = Date()
            stopTimer()
            backgroundTaskId = UIApplication.shared.beginBackgroundTask {
                Task { @MainActor [weak self] in
                    self?.endBackgroundTask()
                }
            }
        }
    }

    private func handleEnterForeground() {
        if wasRunningBeforeBackground, let enterTime = backgroundEnterTime {
            let elapsedSeconds = Int(Date().timeIntervalSince(enterTime))
            remainingTime = max(0, remainingTime - elapsedSeconds)
            if remainingTime <= 0 {
                completeCurrentSession()
            } else {
                state = .running
                startTimer()
            }
        }
        endBackgroundTask()
        backgroundEnterTime = nil
        wasRunningBeforeBackground = false
    }

    private func endBackgroundTask() {
        if backgroundTaskId != .invalid {
            UIApplication.shared.endBackgroundTask(backgroundTaskId)
            backgroundTaskId = .invalid
        }
    }
}
