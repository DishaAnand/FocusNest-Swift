import SwiftUI
import SwiftData
import UIKit

@MainActor
public struct TimerView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @Environment(UserSettings.self) private var settings
    @Environment(TimerService.self) private var timerService
    @Environment(NotificationService.self) private var notificationService
    @Environment(SoundService.self) private var soundService

    @State private var showTaskSelector = false
    @State private var showEnergyMeter = false
    @State private var showSessionComplete = false
    @State private var completedSessionDuration: Int = 0
    @State private var completedDistractionCount: Int = 0  // Captured at session end for display
    @State private var predictedFocus: Int? = nil
    @State private var distractionCount = 0
    // Result data for sheet (set before presenting)
    @State private var focusResult: FocusResultData? = nil

    private struct FocusResultData: Identifiable {
        let id = UUID()
        let predicted: Int
        let actual: Int
        let duration: Int
        let distractions: Int
        let wasCompleted: Bool
    }
    @State private var wentAwayAt: Date? = nil
    @State private var sessionWasCompleted = true
    private let distractionThreshold: TimeInterval = 15

    public init() {}

    public var body: some View {
        GeometryReader { geometry in
            let isCompact = geometry.size.width < 500
            VStack {
                Spacer()
                VStack(spacing: Theme.spacingXL) {
                    Text(timerService.mode.displayName)
                        .font(Theme.titleFont)
                        .foregroundStyle(timerService.isBreak ? Theme.breakColor : Theme.focusColor)

                    ZStack {
                        CircularProgressView(progress: timerService.progress, lineWidth: 12, size: isCompact ? 260 : 320, color: timerService.isBreak ? Theme.breakColor : Theme.focusColor)
                        VStack(spacing: Theme.spacingS) {
                            Text(timerService.formattedTime)
                                .font(isCompact ? Theme.timerFontSmall : Theme.timerFont)
                                .foregroundStyle(Theme.textPrimary)
                                .monospacedDigit()
                                .contentTransition(.numericText())
                            if timerService.state == .paused {
                                Text("PAUSED").font(Theme.captionFont).foregroundStyle(Theme.pausedColor).textCase(.uppercase)
                            }
                        }
                    }
                    .padding(.vertical, Theme.spacingL)

                    if let task = timerService.selectedTask {
                        Button { showTaskSelector = true } label: {
                            HStack(spacing: Theme.spacingS) {
                                Image(systemName: "target").foregroundStyle(Theme.focusColor)
                                Text(task.title).font(Theme.bodyFont).foregroundStyle(Theme.textPrimary).lineLimit(1)
                                Image(systemName: "chevron.right").font(.caption).foregroundStyle(Theme.textTertiary)
                            }
                            .padding(.horizontal, Theme.spacingM).padding(.vertical, Theme.spacingS)
                            .background(Theme.backgroundSecondary).clipShape(Capsule())
                        }
                        .disabled(timerService.isRunning)
                    }

                    HStack(spacing: Theme.spacingL) {
                        if timerService.state != .idle {
                            Button {
                                soundService.lightImpact(settings: settings)
                                sessionWasCompleted = false
                                // If we had a prediction and stopped early during focus, show result
                                if let predicted = predictedFocus, !timerService.isBreak {
                                    let actualFocus = calculateActualFocus()
                                    let dur = settings.focusDuration
                                    let dist = distractionCount

                                    let record = FocusRecord(
                                        duration: dur - timerService.remainingTime,
                                        isBreak: false,
                                        taskId: timerService.selectedTask?.id,
                                        taskTitle: timerService.selectedTask?.title,
                                        wasCompleted: false,
                                        predictedFocus: predicted,
                                        actualFocus: actualFocus,
                                        distractionCount: dist
                                    )
                                    modelContext.insert(record)
                                    timerService.stop()
                                    notificationService.cancelTimerNotifications()

                                    // Set result data to show sheet
                                    focusResult = FocusResultData(
                                        predicted: predicted,
                                        actual: actualFocus,
                                        duration: dur,
                                        distractions: dist,
                                        wasCompleted: false
                                    )
                                } else {
                                    timerService.stop()
                                    notificationService.cancelTimerNotifications()
                                    resetPredictionState()
                                }
                            } label: {
                                Image(systemName: "stop.fill").font(.title2).foregroundStyle(.white).frame(width: 56, height: 56).background(Theme.errorColor.opacity(0.8)).clipShape(Circle())
                            }
                        }
                        Button { soundService.mediumImpact(settings: settings); handlePlayPause() } label: {
                            Image(systemName: timerService.isRunning ? "pause.fill" : "play.fill")
                                .font(.title).foregroundStyle(.white).frame(width: 80, height: 80)
                                .background(timerService.isBreak ? Theme.breakGradient : Theme.focusGradient).clipShape(Circle())
                                .shadow(color: (timerService.isBreak ? Theme.breakColor : Theme.focusColor).opacity(0.3), radius: 10, x: 0, y: 4)
                        }
                        Button { soundService.lightImpact(settings: settings); timerService.skip(); notificationService.cancelTimerNotifications() } label: {
                            Image(systemName: "forward.end.fill").font(.title2).foregroundStyle(.white).frame(width: 56, height: 56).background(Theme.textSecondary).clipShape(Circle())
                        }
                    }
                    .padding(.vertical, Theme.spacingM)

                    VStack(spacing: Theme.spacingS) {
                        HStack(spacing: Theme.spacingXS) {
                            ForEach(0..<settings.sessionsBeforeLongBreak, id: \.self) { index in
                                Circle().fill(index < timerService.completedSessions ? Theme.focusColor : Theme.textTertiary.opacity(0.3)).frame(width: 12, height: 12)
                            }
                        }
                        Text("\(timerService.completedSessions) of \(settings.sessionsBeforeLongBreak) sessions until long break").font(Theme.captionFont).foregroundStyle(Theme.textSecondary)
                    }
                }
                .padding(Theme.spacingL)
                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(Theme.backgroundPrimary)
        .sheet(isPresented: $showTaskSelector) { TaskSelectorSheet(selectedTask: Bindable(timerService).selectedTask) }
        .sheet(isPresented: $showEnergyMeter) {
            EnergyMeterView(
                onStart: { level in
                    predictedFocus = level
                    showEnergyMeter = false
                    startTimerAfterPrediction()
                },
                onSkip: {
                    predictedFocus = nil
                    showEnergyMeter = false
                    startTimerAfterPrediction()
                }
            )
            .presentationDetents([.medium])
            .presentationDragIndicator(.visible)
        }
        .sheet(item: $focusResult) { result in
            FocusPredictionResultView(
                predictedLevel: result.predicted,
                actualLevel: result.actual,
                duration: result.duration,
                distractionCount: result.distractions,
                wasCompleted: result.wasCompleted,
                onDone: {
                    focusResult = nil
                    resetPredictionState()
                },
                onTakeBreak: {
                    focusResult = nil
                    resetPredictionState()
                    // Break auto-starts via timerService
                },
                onExtend: { extensionSeconds in
                    focusResult = nil
                    // Start a new focus session with the extension duration
                    timerService.startExtension(duration: extensionSeconds)
                    Task { await notificationService.scheduleTimerCompletion(in: extensionSeconds, mode: .focus, taskTitle: timerService.selectedTask?.title) }
                }
            )
            .presentationDetents([.large])
            .interactiveDismissDisabled()
        }
        .fullScreenCover(isPresented: $showSessionComplete) {
            SessionCompleteView(
                duration: completedSessionDuration,
                distractionCount: completedDistractionCount,
                onTakeBreak: {
                    showSessionComplete = false
                    resetPredictionState()
                    // Break auto-starts via timerService
                },
                onExtend: { extensionSeconds in
                    showSessionComplete = false
                    // Start a new focus session with the extension duration
                    timerService.startExtension(duration: extensionSeconds)
                    Task { await notificationService.scheduleTimerCompletion(in: extensionSeconds, mode: .focus, taskTitle: timerService.selectedTask?.title) }
                }
            )
        }
        .onChange(of: scenePhase) { oldPhase, newPhase in
            // Only track distractions during active focus session (not breaks)
            guard timerService.isRunning && !timerService.isBreak else { return }

            if newPhase != .active && oldPhase == .active {
                // User left the app - record the time
                wentAwayAt = Date()
            } else if newPhase == .active && oldPhase != .active {
                // User returned - check if they were away long enough
                if let awayTime = wentAwayAt {
                    let awayDuration = Date().timeIntervalSince(awayTime)
                    if awayDuration >= distractionThreshold {
                        distractionCount += 1
                    }
                }
                wentAwayAt = nil
            }
        }
        .onChange(of: settings.focusDuration) { _, newDuration in
            // Sync timer when settings change while idle in focus mode
            if timerService.state == .idle && timerService.mode == .focus {
                timerService.setMode(.focus, duration: newDuration)
            }
        }
        .onChange(of: settings.breakDuration) { _, newDuration in
            // Sync timer when settings change while idle in short break mode
            if timerService.state == .idle && timerService.mode == .shortBreak {
                timerService.setMode(.shortBreak, duration: newDuration)
            }
        }
        .onChange(of: settings.longBreakDuration) { _, newDuration in
            // Sync timer when settings change while idle in long break mode
            if timerService.state == .idle && timerService.mode == .longBreak {
                timerService.setMode(.longBreak, duration: newDuration)
            }
        }
        .task { setupTimerCallbacks() }
    }

    private func handlePlayPause() {
        if timerService.state == .idle {
            // Starting a new session - show energy meter for focus sessions
            if !timerService.isBreak {
                showEnergyMeter = true
            } else {
                // For breaks, just start normally
                Task { await notificationService.scheduleTimerCompletion(in: timerService.remainingTime, mode: timerService.mode, taskTitle: timerService.selectedTask?.title) }
                timerService.togglePlayPause()
            }
        } else if timerService.state == .paused {
            Task { notificationService.cancelTimerNotifications(); await notificationService.scheduleTimerCompletion(in: timerService.remainingTime, mode: timerService.mode, taskTitle: timerService.selectedTask?.title) }
            timerService.togglePlayPause()
        } else {
            notificationService.cancelTimerNotifications()
            timerService.togglePlayPause()
        }
    }

    private func startTimerAfterPrediction() {
        distractionCount = 0
        sessionWasCompleted = true
        Task { await notificationService.scheduleTimerCompletion(in: timerService.remainingTime, mode: timerService.mode, taskTitle: timerService.selectedTask?.title) }
        timerService.togglePlayPause()
    }

    private func calculateActualFocus() -> Int {
        // Start at 5, deduct for issues
        var score = 5

        // Each distraction: -1
        score -= distractionCount

        // Early stop: -2
        if !sessionWasCompleted {
            score -= 2
        }

        // Clamp to 1-5
        return max(1, min(5, score))
    }

    private func resetPredictionState() {
        predictedFocus = nil
        distractionCount = 0
        sessionWasCompleted = true
        wentAwayAt = nil
    }


    private func setupTimerCallbacks() {
        timerService.onComplete = { mode in
            soundService.playTimerComplete(settings: settings)
            soundService.successHaptic(settings: settings)
            if mode == .focus {
                sessionWasCompleted = true

                let actualFocus = calculateActualFocus()
                let record = FocusRecord(
                    duration: settings.focusDuration,
                    isBreak: false,
                    taskId: timerService.selectedTask?.id,
                    taskTitle: timerService.selectedTask?.title,
                    wasCompleted: true,
                    predictedFocus: predictedFocus,
                    actualFocus: actualFocus,
                    distractionCount: distractionCount
                )
                modelContext.insert(record)

                // Show prediction result if user made a prediction
                if let predicted = predictedFocus {
                    focusResult = FocusResultData(
                        predicted: predicted,
                        actual: actualFocus,
                        duration: settings.focusDuration,
                        distractions: distractionCount,
                        wasCompleted: true
                    )
                } else {
                    // No prediction - show celebration with choice to extend or break
                    completedSessionDuration = settings.focusDuration
                    completedDistractionCount = distractionCount  // Capture before showing
                    print("🎉 SESSION COMPLETE - distractionCount: \(distractionCount), completedDistractionCount: \(completedDistractionCount)")
                    showSessionComplete = true
                }
            }
        }
    }
}

@MainActor
private struct TaskSelectorSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(filter: #Predicate<FocusTask> { !$0.isCompleted }, sort: \FocusTask.createdAt, order: .reverse) private var tasks: [FocusTask]
    @Binding var selectedTask: FocusTask?

    var body: some View {
        NavigationStack {
            Group {
                if tasks.isEmpty {
                    EmptyStateView(icon: "checklist", title: "No Tasks", message: "Add a task from the Home tab to select it for your focus session.")
                } else {
                    ScrollView {
                        LazyVStack(spacing: Theme.spacingS) {
                            Button { selectedTask = nil; dismiss() } label: {
                                HStack {
                                    Image(systemName: selectedTask == nil ? "checkmark.circle.fill" : "circle").foregroundStyle(selectedTask == nil ? Theme.focusColor : Theme.textSecondary)
                                    Text("No task selected").foregroundStyle(Theme.textPrimary)
                                    Spacer()
                                }
                                .padding(Theme.spacingM).background(Theme.backgroundSecondary).clipShape(RoundedRectangle(cornerRadius: Theme.cornerRadiusM))
                            }
                            ForEach(tasks) { task in
                                TaskSelectionCardView(task: task, isSelected: selectedTask?.id == task.id) { selectedTask = task; dismiss() }
                            }
                        }
                        .padding(Theme.spacingM)
                    }
                }
            }
            .navigationTitle("Select Task")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } } }
        }
    }
}
