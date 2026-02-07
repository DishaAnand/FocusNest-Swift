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
    @Environment(WakeUpVoiceService.self) private var wakeUpVoiceService
    @Environment(AmbientSoundService.self) private var ambientSoundService

    @State private var showTaskSelector = false
    @State private var showAmbientSoundPicker = false
    @State private var showEnergyOverlay = false
    @State private var showSessionComplete = false
    @State private var showNotificationOnboarding = false
    @State private var showDurationPicker = false
    @State private var showWakeUpVoiceOnboarding = false
    @State private var showRecordVoice = false
    @State private var lastPrediction: Int? = nil
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
    @State private var oceanChoppiness: Double = 0
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
                            } else if timerService.state == .idle && !timerService.isBreak {
                                Text("Tap to change")
                                    .font(Theme.captionFont)
                                    .foregroundStyle(Theme.textTertiary)
                            }
                        }
                    }
                    .padding(.vertical, Theme.spacingL)
                    .onTapGesture {
                        if timerService.state == .idle && !timerService.isBreak {
                            soundService.lightImpact(settings: settings)
                            showDurationPicker = true
                        }
                    }

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
                                // Stop ambient sound when stopping timer
                                ambientSoundService.stop()
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
                        Button { soundService.lightImpact(settings: settings); timerService.skip(); notificationService.cancelTimerNotifications(); ambientSoundService.stop() } label: {
                            Image(systemName: "forward.end.fill").font(.title2).foregroundStyle(.white).frame(width: 56, height: 56).background(Theme.textSecondary).clipShape(Circle())
                        }
                    }
                    .padding(.vertical, Theme.spacingM)

                    // Ambient sound selector
                    AmbientSoundButton(
                        sound: ambientSoundService.selectedSound,
                        isPlaying: ambientSoundService.isPlaying
                    ) {
                        soundService.lightImpact(settings: settings)
                        showAmbientSoundPicker = true
                    }

                    // Energy prediction pill (only show when idle and in focus mode)
                    if timerService.state == .idle && !timerService.isBreak {
                        EnergyPredictionPill(lastPrediction: lastPrediction) {
                            soundService.lightImpact(settings: settings)
                            showEnergyOverlay = true
                        }
                        .padding(.top, Theme.spacingS)
                    }
                }
                .padding(Theme.spacingL)
                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(Theme.backgroundPrimary)
        .sheet(isPresented: $showTaskSelector) { TaskSelectorSheet(selectedTask: Bindable(timerService).selectedTask) }
        .sheet(isPresented: $showDurationPicker) {
            DurationPickerSheet(
                currentMinutes: settings.focusDurationMinutes,
                onSelect: { minutes in
                    settings.focusDurationMinutes = minutes
                    // Update timer with new duration before starting
                    timerService.setMode(.focus, duration: minutes * 60)
                    showDurationPicker = false
                    // Start timer after selecting duration
                    if !settings.hasSeenNotificationOnboarding && !notificationService.isAuthorized {
                        showNotificationOnboarding = true
                    } else {
                        startTimerWithoutPrediction()
                    }
                },
                onDismiss: { showDurationPicker = false }
            )
            .presentationDetents([.height(320)])
            .presentationDragIndicator(.visible)
        }
        .overlay {
            if showEnergyOverlay {
                EnergyPredictionOverlay(
                    onStart: { level in
                        showEnergyOverlay = false
                        startTimerAfterPrediction(level: level)
                    },
                    onDismiss: {
                        showEnergyOverlay = false
                    }
                )
                .transition(.opacity.combined(with: .scale(scale: 0.95)))
                .zIndex(100)
            }
        }
        .animation(.spring(response: 0.3), value: showEnergyOverlay)
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
        .sheet(isPresented: $showNotificationOnboarding) {
            NotificationOnboardingSheet(
                onDismiss: {
                    settings.hasSeenNotificationOnboarding = true
                    showNotificationOnboarding = false
                    // Continue to start timer (prediction is optional now)
                    startTimerWithoutPrediction()
                }
            )
            .presentationDetents([.height(340)])
            .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showWakeUpVoiceOnboarding) {
            WakeUpVoiceOnboardingView(
                onSetUp: {
                    settings.hasSeenWakeUpVoiceOnboarding = true
                    showWakeUpVoiceOnboarding = false
                    // Go directly to record screen
                    showRecordVoice = true
                },
                onSkip: {
                    settings.hasSeenWakeUpVoiceOnboarding = true
                    showWakeUpVoiceOnboarding = false
                    // Continue to start timer
                    startTimerWithoutPrediction()
                }
            )
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showRecordVoice) {
            RecordVoiceView()
                .onDisappear {
                    // After recording, start the timer
                    startTimerWithoutPrediction()
                }
        }
        .sheet(isPresented: $showAmbientSoundPicker) {
            AmbientSoundPicker()
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
                        // Make ocean choppy - intensity based on how long they were away
                        let intensity = min(1.0, awayDuration / 60.0) // Max choppiness at 60s away
                        withAnimation(.easeIn(duration: 0.3)) {
                            oceanChoppiness = 0.5 + (intensity * 0.5) // Range: 0.5 to 1.0
                        }
                        // Gradually calm the ocean over 15 seconds
                        withAnimation(.easeOut(duration: 15.0).delay(0.5)) {
                            oceanChoppiness = 0
                        }
                    } else if awayDuration >= 3 {
                        // Brief absence - slight ripple effect
                        withAnimation(.easeIn(duration: 0.2)) {
                            oceanChoppiness = 0.2
                        }
                        withAnimation(.easeOut(duration: 5.0).delay(0.3)) {
                            oceanChoppiness = 0
                        }
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
            // Check if we need to show notification onboarding first
            if !settings.hasSeenNotificationOnboarding && !notificationService.isAuthorized {
                showNotificationOnboarding = true
                return
            }

            // Check if we should show wake-up voice onboarding (first focus session, no voices recorded yet)
            if !settings.hasSeenWakeUpVoiceOnboarding && !timerService.isBreak && wakeUpVoiceService.voices.isEmpty {
                showWakeUpVoiceOnboarding = true
                return
            }

            // Start timer directly (prediction is now optional via pill)
            startTimerWithoutPrediction()
        } else if timerService.state == .paused {
            let customSound = timerService.isBreak ? wakeUpVoiceService.getNotificationSound() : nil
            Task { notificationService.cancelTimerNotifications(); await notificationService.scheduleTimerCompletion(in: timerService.remainingTime, mode: timerService.mode, taskTitle: timerService.selectedTask?.title, customBreakSound: customSound) }
            timerService.togglePlayPause()
            // Resume ambient sound when resuming focus
            if !timerService.isBreak {
                ambientSoundService.resume()
            }
        } else {
            notificationService.cancelTimerNotifications()
            timerService.togglePlayPause()
            // Pause ambient sound when pausing timer
            ambientSoundService.pause()
        }
    }

    private func startTimerWithoutPrediction() {
        distractionCount = 0
        sessionWasCompleted = true
        predictedFocus = nil
        let customSound = timerService.isBreak ? wakeUpVoiceService.getNotificationSound() : nil
        Task { await notificationService.scheduleTimerCompletion(in: timerService.remainingTime, mode: timerService.mode, taskTitle: timerService.selectedTask?.title, customBreakSound: customSound) }
        timerService.togglePlayPause()
        // Start ambient sound when focus session begins (not during breaks)
        if !timerService.isBreak {
            ambientSoundService.play()
        }
    }

    private func startTimerAfterPrediction(level: Int) {
        distractionCount = 0
        sessionWasCompleted = true
        predictedFocus = level
        lastPrediction = level
        let customSound = timerService.isBreak ? wakeUpVoiceService.getNotificationSound() : nil
        Task { await notificationService.scheduleTimerCompletion(in: timerService.remainingTime, mode: timerService.mode, taskTitle: timerService.selectedTask?.title, customBreakSound: customSound) }
        timerService.togglePlayPause()
        // Start ambient sound when focus session begins (not during breaks)
        if !timerService.isBreak {
            ambientSoundService.play()
        }
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
            // Stop ambient sound when timer completes
            ambientSoundService.stop()

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

// MARK: - Duration Picker Sheet

@MainActor
private struct DurationPickerSheet: View {
    let currentMinutes: Int
    let onSelect: (Int) -> Void
    let onDismiss: () -> Void

    @State private var selectedMinutes: Int

    init(currentMinutes: Int, onSelect: @escaping (Int) -> Void, onDismiss: @escaping () -> Void) {
        self.currentMinutes = currentMinutes
        self.onSelect = onSelect
        self.onDismiss = onDismiss
        self._selectedMinutes = State(initialValue: currentMinutes)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Wheel Picker
                Picker("Minutes", selection: $selectedMinutes) {
                    ForEach(1...120, id: \.self) { minute in
                        Text("\(minute) min")
                            .tag(minute)
                    }
                }
                .pickerStyle(.wheel)
                .frame(height: 180)

                // Quick preset buttons
                HStack(spacing: Theme.spacingM) {
                    ForEach([15, 25, 45, 60], id: \.self) { preset in
                        Button {
                            selectedMinutes = preset
                        } label: {
                            Text("\(preset)")
                                .font(.system(size: 15, weight: .medium))
                                .foregroundStyle(selectedMinutes == preset ? .white : Theme.focusColor)
                                .frame(width: 52, height: 36)
                                .background(selectedMinutes == preset ? Theme.focusColor : Theme.focusColor.opacity(0.15))
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                        }
                    }
                }
                .padding(.bottom, Theme.spacingM)
            }
            .navigationTitle("Focus Duration")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { onDismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { onSelect(selectedMinutes) }
                        .fontWeight(.semibold)
                }
            }
        }
    }
}
