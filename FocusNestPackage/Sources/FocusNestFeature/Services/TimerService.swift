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
    private var backgroundTaskId: UIBackgroundTaskIdentifier = .invalid
    private var backgroundEnterTime: Date?
    private var wasRunningBeforeBackground: Bool = false
    private let settings: UserSettings

    public var progress: Double {
        guard totalDuration > 0 else { return 0.0 }
        return 1.0 - (Double(remainingTime) / Double(totalDuration))
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

    public init(settings: UserSettings) {
        self.settings = settings
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
    }

    public func start() {
        guard state != .running else { return }
        if state == .idle { remainingTime = totalDuration }
        state = .running
        startTimer()
    }

    public func pause() {
        guard state == .running else { return }
        state = .paused
        stopTimer()
    }

    public func resume() {
        guard state == .paused else { return }
        state = .running
        startTimer()
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
        resetToMode(mode)
    }

    public func skip() {
        stopTimer()
        advanceToNextMode()
    }

    public func reset() {
        stopTimer()
        state = .idle
        mode = .focus
        completedSessions = 0
        totalDuration = settings.focusDuration
        remainingTime = settings.focusDuration
        selectedTask = nil
    }

    public func setMode(_ newMode: TimerMode, duration: Int? = nil) {
        stopTimer()
        mode = newMode
        state = .idle

        switch newMode {
        case .focus: totalDuration = duration ?? settings.focusDuration
        case .shortBreak: totalDuration = duration ?? settings.breakDuration
        case .longBreak: totalDuration = duration ?? settings.longBreakDuration
        }
        remainingTime = totalDuration
    }

    private func startTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor [self] in
                self.tick()
            }
        }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
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
