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
    @Environment(MotionService.self) private var motionService

    @State private var showTaskSelector = false
    @State private var showRechargeMode = false
    @State private var showAmbientSoundPicker = false
    @State private var showEnergyOverlay = false
    @State private var showSessionComplete = false
    @State private var showNotificationOnboarding = false
    @State private var showDurationPicker = false
    @State private var showWakeUpVoiceOnboarding = false
    @State private var showRecordVoice = false
    @State private var sessionPlanPendingOnboarding: SessionPlan? = nil  // Session plan waiting for onboarding
    @State private var startWithPredictionAfterOnboarding = false  // Whether to show energy prediction after onboarding
    @State private var lastPrediction: Int? = nil
    @State private var completedSessionDuration: Int = 0
    @State private var completedDistractionCount: Int = 0  // Captured at session end for display
    @State private var predictedFocus: Int? = nil
    @State private var distractionCount = 0
    @State private var lastBreakRechargePercentage: Double = 0  // Recharge from previous break for halo effect

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

    // Flexible session planning (user picks count, duration decided per-session)
    @State private var sessionPlan = SessionPlan()
    @State private var pendingSessionPlan: SessionPlan? = nil  // Temp storage for energy overlay flow
    @State private var showSessionPlannerSheet = false  // Shows session planner sheet
    @State private var continuousFocusTime: Int = 0  // For 45min auto-lock threshold
    @State private var sessionPlanTotalDistractions = 0
    @State private var sessionPlanTotalFocusTime = 0
    @State private var showFinalCelebration = false  // For last session enhanced celebration
    @Query(filter: #Predicate<FocusTask> { !$0.isCompleted }) private var availableTasks: [FocusTask]
    @Query private var allTasks: [FocusTask]  // All tasks for looking up names in breakdown
    @Query private var focusRecords: [FocusRecord]  // For total hours calculation

    /// Build task breakdown items for celebration display
    private var taskBreakdownItems: [TaskBreakdownItem] {
        let breakdown = sessionPlan.getTaskBreakdown()
        return breakdown.compactMap { item in
            guard let task = allTasks.first(where: { $0.id == item.taskId }) else { return nil }
            return TaskBreakdownItem(id: item.taskId, name: task.title, sessionCount: item.sessionCount)
        }
    }

    public init() {}

    public var body: some View {
        GeometryReader { geometry in
            let isCompact = geometry.size.width < 500
            let timerSize: CGFloat = isCompact ? 260 : 320

            VStack(spacing: 0) {
                // Session progress indicator (when plan is active)
                if sessionPlan.isActive {
                    sessionProgressIndicator
                        .padding(.top, Theme.spacingS)
                }

                Spacer()

                // Mode label
                Text(timerService.mode.displayName)
                    .font(Theme.titleFont)
                    .foregroundStyle(timerService.isBreak ? Theme.breakColor : Theme.focusColor)

                // Timer circle
                ZStack {
                    CircularProgressView(progress: timerService.progress, lineWidth: 10, size: timerSize, color: timerService.isBreak ? Theme.breakColor : Theme.focusColor)
                    VStack(spacing: 4) {
                        Text(timerService.formattedTime)
                            .font(.system(size: isCompact ? 52 : 60, weight: .light, design: .rounded))
                            .foregroundStyle(Theme.textPrimary)
                            .monospacedDigit()
                            .contentTransition(.numericText())
                        if timerService.state == .paused {
                            Text("PAUSED").font(Theme.captionFont).foregroundStyle(Theme.pausedColor).textCase(.uppercase)
                        } else if timerService.state == .idle && !timerService.isBreak {
                            Text("Tap to change")
                                .font(.system(size: 13))
                                .foregroundStyle(Theme.textTertiary)
                        }
                    }
                }
                .padding(.vertical, Theme.spacingM)
                .onTapGesture {
                    if timerService.state == .idle && !timerService.isBreak {
                        soundService.lightImpact(settings: settings)
                        showDurationPicker = true
                    }
                }

                // Control buttons
                HStack(spacing: Theme.spacingL) {
                    if timerService.state != .idle {
                        // Stop button when running/paused
                        Button {
                            soundService.lightImpact(settings: settings)
                            sessionWasCompleted = false
                            ambientSoundService.stop()
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
                                    distractionCount: dist,
                                    wasFullyRecharged: lastBreakRechargePercentage >= 100
                                )
                                modelContext.insert(record)
                                lastBreakRechargePercentage = 0  // Reset after use
                                timerService.stop()
                                notificationService.cancelTimerNotifications()

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
                            Image(systemName: "stop.fill").font(.title3).foregroundStyle(.white).frame(width: 50, height: 50).background(Theme.errorColor.opacity(0.8)).clipShape(Circle())
                        }
                    }
                    Button { soundService.mediumImpact(settings: settings); handlePlayPause() } label: {
                        Image(systemName: timerService.isRunning ? "pause.fill" : "play.fill")
                            .font(.title2).foregroundStyle(.white).frame(width: 72, height: 72)
                            .background(timerService.isBreak ? Theme.breakGradient : Theme.focusGradient).clipShape(Circle())
                            .shadow(color: (timerService.isBreak ? Theme.breakColor : Theme.focusColor).opacity(0.3), radius: 8, x: 0, y: 3)
                    }
                    Button { soundService.lightImpact(settings: settings); timerService.skip(); notificationService.cancelTimerNotifications(); ambientSoundService.stop() } label: {
                        Image(systemName: "forward.end.fill").font(.title3).foregroundStyle(.white).frame(width: 50, height: 50).background(Theme.textSecondary).clipShape(Circle())
                    }
                }
                .padding(.vertical, Theme.spacingM)

                // Ambient sound button
                AmbientSoundButton(
                    sound: ambientSoundService.selectedSound,
                    isPlaying: ambientSoundService.isPlaying
                ) {
                    soundService.lightImpact(settings: settings)
                    showAmbientSoundPicker = true
                }

                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.horizontal, Theme.spacingM)
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
                        if let plan = pendingSessionPlan {
                            // Start session plan with prediction
                            sessionPlan = plan
                            pendingSessionPlan = nil
                            startSessionPlanWithPrediction(level: level)
                        } else {
                            // Start single task with prediction
                            startTimerAfterPrediction(level: level)
                        }
                    },
                    onDismiss: {
                        showEnergyOverlay = false
                        pendingSessionPlan = nil
                    }
                )
                .transition(.opacity.combined(with: .scale(scale: 0.95)))
                .zIndex(100)
            }

        }
        .animation(.spring(response: 0.3), value: showEnergyOverlay)
        .sheet(isPresented: $showSessionPlannerSheet) {
            SessionPlannerSheet(
                plan: $sessionPlan,
                isPresented: $showSessionPlannerSheet,
                onStart: {
                    startSessionPlan()
                }
            )
            .presentationDetents([.medium])
            .presentationDragIndicator(.visible)
        }
        .onReceive(NotificationCenter.default.publisher(for: .showSessionPlanner)) { _ in
            // Show session planner sheet (triggered from Home tab)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                if timerService.state == .idle && !sessionPlan.isActive {
                    showSessionPlannerSheet = true
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .startSessionPlan)) { notification in
            if let userInfo = notification.userInfo,
               let plan = userInfo["sessionPlan"] as? SessionPlan,
               plan.totalSessions > 0 {
                // Check if we should show wake-up voice onboarding first
                if !settings.hasSeenWakeUpVoiceOnboarding && wakeUpVoiceService.voices.isEmpty {
                    sessionPlanPendingOnboarding = plan
                    startWithPredictionAfterOnboarding = false
                    showWakeUpVoiceOnboarding = true
                } else {
                    sessionPlan = plan
                    startSessionPlan()
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .autoStartTimer)) { _ in
            // Auto-start timer when triggered from task list (with small delay for tab switch)
            if timerService.state == .idle && !timerService.isBreak {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    if timerService.state == .idle {
                        // Check if we should show wake-up voice onboarding first
                        if !settings.hasSeenWakeUpVoiceOnboarding && wakeUpVoiceService.voices.isEmpty {
                            sessionPlanPendingOnboarding = nil
                            startWithPredictionAfterOnboarding = false
                            showWakeUpVoiceOnboarding = true
                        } else {
                            startTimerWithoutPrediction()
                        }
                    }
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .showEnergyPrediction)) { _ in
            // Show energy prediction overlay for single task (with small delay for tab switch)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                if timerService.state == .idle && !timerService.isBreak {
                    // Check if we should show wake-up voice onboarding first
                    if !settings.hasSeenWakeUpVoiceOnboarding && wakeUpVoiceService.voices.isEmpty {
                        sessionPlanPendingOnboarding = nil
                        startWithPredictionAfterOnboarding = true
                        showWakeUpVoiceOnboarding = true
                    } else {
                        pendingSessionPlan = nil  // Not a session plan
                        showEnergyOverlay = true
                    }
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .startSessionPlanWithPrediction)) { notification in
            // Store session plan and show energy overlay (or onboarding first)
            if let userInfo = notification.userInfo,
               let plan = userInfo["sessionPlan"] as? SessionPlan,
               plan.totalSessions > 0 {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    // Check if we should show wake-up voice onboarding first
                    if !settings.hasSeenWakeUpVoiceOnboarding && wakeUpVoiceService.voices.isEmpty {
                        sessionPlanPendingOnboarding = plan
                        startWithPredictionAfterOnboarding = true
                        showWakeUpVoiceOnboarding = true
                    } else {
                        pendingSessionPlan = plan
                        showEnergyOverlay = true
                    }
                }
            }
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
                    if sessionPlan.isActive {
                        // Session plan: check if last session for final celebration
                        if sessionPlan.isLastSession {
                            completedSessionDuration = sessionPlanTotalFocusTime
                            completedDistractionCount = sessionPlanTotalDistractions
                            showFinalCelebration = true
                        }
                        // Otherwise just dismiss, user can choose break or continue from timer
                    } else {
                        // Normal flow: Break already auto-running — show RechargeView
                        showRechargeAfterSheetDismiss()
                    }
                    resetPredictionState()
                },
                onTakeBreak: {
                    focusResult = nil
                    resetPredictionState()
                    if sessionPlan.isActive {
                        // Session plan: start break, then next session
                        handleSessionPlanTakeBreak()
                    } else {
                        // Normal flow: Break already auto-running — show RechargeView
                        showRechargeAfterSheetDismiss()
                    }
                },
                onExtend: { extensionSeconds in
                    focusResult = nil
                    if sessionPlan.isActive {
                        // Session plan: skip break, go to next session
                        handleSessionPlanContinue()
                    } else {
                        // Normal flow: Start a new focus session with the extension duration
                        timerService.startExtension(duration: extensionSeconds)
                    }
                },
                onDismiss: {
                    focusResult = nil
                    if sessionPlan.isActive {
                        // Session plan: check if last session for final celebration
                        if sessionPlan.isLastSession {
                            completedSessionDuration = sessionPlanTotalFocusTime
                            completedDistractionCount = sessionPlanTotalDistractions
                            showFinalCelebration = true
                        }
                    } else {
                        // Normal flow: Break already auto-running — show RechargeView
                        showRechargeAfterSheetDismiss()
                    }
                    resetPredictionState()
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
                    if sessionPlan.isActive {
                        // Session plan: start break, then next session
                        handleSessionPlanTakeBreak()
                    } else {
                        resetPredictionState()
                        // Break is already auto-started by TimerService — just show RechargeView
                        // If break isn't running yet for some reason, start it
                        if !timerService.isRunning || !timerService.isBreak {
                            timerService.setMode(.breakTime, duration: settings.breakDuration)
                            timerService.start()
                        }
                        // Show RechargeView after a brief delay to let sheet dismiss
                        if motionService.isAvailable {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                showRechargeMode = true
                            }
                        }
                    }
                },
                onExtend: { extensionSeconds in
                    showSessionComplete = false
                    if sessionPlan.isActive {
                        // Session plan: skip break, go to next session
                        handleSessionPlanContinue()
                    } else {
                        // Normal flow: extend current session
                        timerService.startExtension(duration: extensionSeconds)
                    }
                },
                onDismiss: {
                    showSessionComplete = false
                    resetPredictionState()
                    // Break is already auto-running — show RechargeView
                    if timerService.isRunning && timerService.isBreak && motionService.isAvailable {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            showRechargeMode = true
                        }
                    }
                },
                // Pass session plan context
                currentSession: sessionPlan.isActive ? sessionPlan.displayCurrentSession : nil,
                totalSessions: sessionPlan.isActive ? sessionPlan.totalSessions : nil
            )
        }
        .fullScreenCover(isPresented: $showFinalCelebration) {
            FinalSessionCelebrationView(
                totalSessions: sessionPlan.totalSessions,
                totalMinutes: sessionPlanTotalFocusTime / 60,
                totalDistractions: sessionPlanTotalDistractions,
                taskBreakdown: taskBreakdownItems,
                onDone: {
                    showFinalCelebration = false
                    finishSessionPlan()
                },
                onDismiss: {
                    showFinalCelebration = false
                    finishSessionPlan()
                }
            )
        }
        .fullScreenCover(isPresented: $showRechargeMode) {
            RechargeView()
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
                    // Note: Session plan will start after recording (handled in showRecordVoice dismiss)
                },
                onSkip: {
                    settings.hasSeenWakeUpVoiceOnboarding = true
                    showWakeUpVoiceOnboarding = false
                    // Continue with session plan, energy prediction, or regular timer
                    if let plan = sessionPlanPendingOnboarding {
                        sessionPlanPendingOnboarding = nil
                        if startWithPredictionAfterOnboarding {
                            pendingSessionPlan = plan
                            showEnergyOverlay = true
                        } else {
                            sessionPlan = plan
                            startSessionPlan()
                        }
                    } else if startWithPredictionAfterOnboarding {
                        // Single task with prediction
                        pendingSessionPlan = nil
                        showEnergyOverlay = true
                    } else {
                        startTimerWithoutPrediction()
                    }
                }
            )
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showRecordVoice) {
            RecordVoiceView()
                .onDisappear {
                    // After recording, continue with session plan, energy prediction, or regular timer
                    if let plan = sessionPlanPendingOnboarding {
                        sessionPlanPendingOnboarding = nil
                        if startWithPredictionAfterOnboarding {
                            pendingSessionPlan = plan
                            showEnergyOverlay = true
                        } else {
                            sessionPlan = plan
                            startSessionPlan()
                        }
                    } else if startWithPredictionAfterOnboarding {
                        // Single task with prediction
                        pendingSessionPlan = nil
                        showEnergyOverlay = true
                    } else {
                        startTimerWithoutPrediction()
                    }
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
            if timerService.state == .idle && timerService.mode == .breakTime {
                timerService.setMode(.breakTime, duration: newDuration)
            }
        }
        .onChange(of: timerService.state) { oldState, newState in
            // Show recharge mode when break starts running — but only if no sheet is blocking
            if newState == .running && oldState != .running && timerService.isBreak {
                if motionService.isAvailable && !showSessionComplete && focusResult == nil {
                    showRechargeMode = true
                }
            }
            // Note: We do NOT auto-dismiss RechargeView here when break ends.
            // RechargeView handles its own flow: shows RechargeCompleteView, then dismisses itself.
            // The recharge percentage is captured in onChange(of: showRechargeMode) when it actually dismisses.
        }
        .onChange(of: showRechargeMode) { wasShowing, isShowing in
            // Capture recharge percentage when RechargeView dismisses (via skip, early exit, etc.)
            if wasShowing && !isShowing {
                lastBreakRechargePercentage = motionService.rechargePercentage
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

    private func showRechargeAfterSheetDismiss() {
        if timerService.isRunning && timerService.isBreak && motionService.isAvailable {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                showRechargeMode = true
            }
        }
    }

    private func resetPredictionState() {
        predictedFocus = nil
        distractionCount = 0
        sessionWasCompleted = true
        wentAwayAt = nil
    }


    private func setupTimerCallbacks() {
        timerService.onComplete = { mode in
            // Play appropriate completion sound
            if mode == .breakTime {
                // Break complete - play custom wake-up voice if available
                wakeUpVoiceService.playDefaultVoice()
            } else {
                // Focus complete - play generic sound
                soundService.playTimerComplete(settings: settings)
            }
            soundService.successHaptic(settings: settings)
            // Stop ambient sound when timer completes
            ambientSoundService.stop()

            // Handle flexible session plan flow
            if sessionPlan.isActive {
                // Prevent TimerService from doing default mode transition - we handle it ourselves
                timerService.skipDefaultTransition = true

                if mode == .focus {
                    // Accumulate stats
                    sessionPlanTotalDistractions += distractionCount
                    sessionPlanTotalFocusTime += settings.focusDuration
                    continuousFocusTime += settings.focusDuration

                    // Save record for this session
                    let record = FocusRecord(
                        duration: settings.focusDuration,
                        isBreak: false,
                        taskId: timerService.selectedTask?.id,
                        taskTitle: timerService.selectedTask?.title,
                        wasCompleted: true,
                        predictedFocus: predictedFocus,
                        actualFocus: nil,
                        distractionCount: distractionCount,
                        wasFullyRecharged: lastBreakRechargePercentage >= 100
                    )
                    modelContext.insert(record)
                    lastBreakRechargePercentage = 0  // Reset after use

                    // Check if user made a prediction - show prediction result first
                    if let predicted = predictedFocus {
                        let actualFocus = calculateActualFocus()
                        focusResult = FocusResultData(
                            predicted: predicted,
                            actual: actualFocus,
                            duration: settings.focusDuration,
                            distractions: distractionCount,
                            wasCompleted: true
                        )
                        // Note: After dismissing focusResult, user can take break or continue
                        // The session plan state is preserved
                    } else if sessionPlan.isLastSession {
                        // Last session complete (no prediction) - show final celebration
                        completedSessionDuration = sessionPlanTotalFocusTime
                        completedDistractionCount = sessionPlanTotalDistractions
                        showFinalCelebration = true
                    } else {
                        // Not last session (no prediction) - show completion with choice
                        completedSessionDuration = settings.focusDuration
                        completedDistractionCount = distractionCount
                        showSessionComplete = true
                    }
                } else {
                    // Break complete — save break record, set up next session
                    let breakRecord = FocusRecord(
                        duration: settings.breakDuration,
                        isBreak: true,
                        rechargePercentage: lastBreakRechargePercentage > 0 ? lastBreakRechargePercentage : nil
                    )
                    modelContext.insert(breakRecord)
                    lastBreakRechargePercentage = 0
                    sessionPlan.nextSession()
                    continuousFocusTime = 0
                    distractionCount = 0
                    timerService.setMode(.focus, duration: settings.focusDuration)
                }
                return
            }

            // Normal (non-session-plan) flow
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
                    distractionCount: distractionCount,
                    wasFullyRecharged: lastBreakRechargePercentage >= 100
                )
                modelContext.insert(record)
                lastBreakRechargePercentage = 0  // Reset after use

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
                    completedDistractionCount = distractionCount
                    showSessionComplete = true
                }
            } else {
                // Break complete in normal mode — save break record, transition to focus
                let breakRecord = FocusRecord(
                    duration: settings.breakDuration,
                    isBreak: true,
                    rechargePercentage: lastBreakRechargePercentage > 0 ? lastBreakRechargePercentage : nil
                )
                modelContext.insert(breakRecord)
                lastBreakRechargePercentage = 0
                distractionCount = 0
                timerService.setMode(.focus, duration: settings.focusDuration)
            }
        }
    }

    private func calculateActualFocusForSessionPlan() -> Int {
        // Calculate focus score based on total distractions across all sessions
        var score = 5

        // More lenient for session plans: -1 per 2 distractions
        score -= sessionPlanTotalDistractions / 2

        return max(1, min(5, score))
    }

    // MARK: - Session Plan Helpers

    private var sessionProgressIndicator: some View {
        HStack(spacing: 8) {
            ForEach(0..<sessionPlan.totalSessions, id: \.self) { index in
                Circle()
                    .fill(index < sessionPlan.currentSession
                          ? LinearGradient(colors: [.green, .mint], startPoint: .top, endPoint: .bottom)
                          : index == sessionPlan.currentSession
                          ? (timerService.isBreak
                             ? LinearGradient(colors: [Theme.breakColor, Theme.breakColor.opacity(0.7)], startPoint: .top, endPoint: .bottom)
                             : LinearGradient(colors: [.purple, .pink], startPoint: .top, endPoint: .bottom))
                          : LinearGradient(colors: [Theme.textTertiary.opacity(0.3), Theme.textTertiary.opacity(0.3)], startPoint: .top, endPoint: .bottom))
                    .frame(width: index == sessionPlan.currentSession ? 12 : 8, height: index == sessionPlan.currentSession ? 12 : 8)
                    .animation(.spring(response: 0.3), value: sessionPlan.currentSession)
                    .animation(.spring(response: 0.3), value: timerService.isBreak)
            }

            if timerService.isBreak {
                Text("Break before Session \(sessionPlan.currentSession + 2)")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Theme.breakColor)
            } else {
                Text("Session \(sessionPlan.displayCurrentSession) of \(sessionPlan.totalSessions)")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Theme.textSecondary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(
            Capsule()
                .fill(Theme.backgroundSecondary)
        )
        .animation(.spring(response: 0.3), value: timerService.isBreak)
    }

    private func startSessionPlan() {
        guard sessionPlan.totalSessions > 0 else { return }

        // Initialize session plan state
        sessionPlanTotalDistractions = 0
        sessionPlanTotalFocusTime = 0
        continuousFocusTime = 0
        distractionCount = 0

        // Timer is ready - user will tap to set duration and start
        timerService.setMode(.focus, duration: settings.focusDuration)
    }

    private func startSessionPlanWithPrediction(level: Int) {
        guard sessionPlan.totalSessions > 0 else { return }

        // Initialize session plan state
        sessionPlanTotalDistractions = 0
        sessionPlanTotalFocusTime = 0
        continuousFocusTime = 0
        distractionCount = 0

        // Set prediction and start with current duration
        predictedFocus = level
        lastPrediction = level
        startTimerWithoutPrediction()
    }

    // Handle session plan choices from SessionCompleteView
    private func handleSessionPlanTakeBreak() {
        // Start a break using user's break setting, after which user will set up next session
        timerService.setMode(.breakTime, duration: settings.breakDuration)
        timerService.start()
        // Show RechargeView after a brief delay to let sheet dismiss
        if motionService.isAvailable {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                showRechargeMode = true
            }
        }
    }

    private func handleSessionPlanContinue() {
        // Skip break, move to next session setup
        sessionPlan.nextSession()
        continuousFocusTime += 0  // Continuous time keeps accumulating (no break taken)
        distractionCount = 0
        timerService.setMode(.focus, duration: settings.focusDuration)
        // User will tap to change duration and start
    }

    private func finishSessionPlan() {
        // Reset all session plan state
        sessionPlan.reset()
        sessionPlanTotalDistractions = 0
        sessionPlanTotalFocusTime = 0
        continuousFocusTime = 0
        distractionCount = 0
        predictedFocus = nil
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

// MARK: - Sound Wave Animation

@MainActor
private struct SoundWaveView: View {
    @State private var isAnimating = false

    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<3, id: \.self) { index in
                RoundedRectangle(cornerRadius: 1)
                    .fill(Theme.focusColor)
                    .frame(width: 3, height: isAnimating ? [8, 12, 6][index] : [4, 6, 4][index])
                    .animation(
                        .easeInOut(duration: 0.4)
                        .repeatForever(autoreverses: true)
                        .delay(Double(index) * 0.15),
                        value: isAnimating
                    )
            }
        }
        .frame(width: 14, height: 14)
        .onAppear { isAnimating = true }
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
