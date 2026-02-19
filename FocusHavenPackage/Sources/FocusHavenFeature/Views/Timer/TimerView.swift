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
    @Environment(SubscriptionService.self) private var subscriptionService

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
    @State private var completedPredictedLevel: Int? = nil
    @State private var completedActualLevel: Int? = nil
    @State private var completedWasCompleted: Bool = true
    @State private var predictedFocus: Int? = nil
    @State private var distractionCount = 0
    @State private var lastBreakRechargePercentage: Double = 0  // Recharge from previous break for halo effect

    @State private var wentAwayAt: Date? = nil
    @State private var sessionWasCompleted = true
    @State private var oceanChoppiness: Double = 0
    private let distractionThreshold: TimeInterval = 15

    // Flexible session planning (user picks count, duration decided per-session)
    @State private var sessionPlan = SessionPlan()
    @State private var pendingSessionPlan: SessionPlan? = nil  // Temp storage for energy overlay flow
    @State private var showSessionPlannerSheet = false  // Shows session planner sheet
    @State private var continuousFocusTime: Int = 0  // For 45min auto-lock threshold
    @State private var showDirectMandatoryBreak = false  // Direct autolock (skips summary)
    @State private var directMandatoryBreakRemaining: Int = 5 * 60
    @State private var directMandatoryBreakTimer: Timer? = nil
    @State private var directMandatoryBreakStartDate: Date? = nil  // Track actual start time
    private let mandatoryBreakDuration: Int = 5 * 60  // 5 minutes
    private let mandatoryBreakThreshold = 2 * 60 // TEMP: 2 min for testing (was 45 min)
    @State private var showSessionPlanUpgradePrompt = false
    @State private var sessionPlanTotalDistractions = 0
    @State private var sessionPlanTotalFocusTime = 0
    @State private var showFinalCelebration = false  // For last session enhanced celebration
    @State private var showSessionBanner = false  // Brief "Session X completed" banner
    @State private var sessionBannerNumber: Int = 0  // Which session just completed
    @State private var currentSessionDisplay: Int = 1  // 1-indexed session number for UI
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
        timerContentWithSheets
            .overlay {
                directMandatoryBreakOverlay
            }
            .onChange(of: settings.focusDuration) { _, newDuration in
                if timerService.state == .idle && timerService.mode == .focus {
                    timerService.setMode(.focus, duration: newDuration)
                }
            }
            .onChange(of: settings.breakDuration) { _, newDuration in
                if timerService.state == .idle && timerService.mode == .breakTime {
                    timerService.setMode(.breakTime, duration: newDuration)
                }
            }
            .onChange(of: timerService.state) { oldState, newState in
                if newState == .running && oldState != .running && timerService.isBreak {
                    if motionService.isAvailable && !showSessionComplete {
                        showRechargeMode = true
                    }
                }
            }
            .onChange(of: timerService.mode) { oldMode, newMode in
                if sessionPlan.isActive && oldMode == .breakTime && newMode == .focus {
                    currentSessionDisplay += 1
                }
            }
            .onChange(of: showRechargeMode) { wasShowing, isShowing in
                if wasShowing && !isShowing {
                    lastBreakRechargePercentage = motionService.rechargePercentage
                }
            }
            .onChange(of: scenePhase) { _, newPhase in
                // Recalculate mandatory break remaining when returning to foreground
                if newPhase == .active && showDirectMandatoryBreak {
                    recalcDirectMandatoryBreakRemaining()
                }
            }
            .task { setupTimerCallbacks() }
    }

    private var timerContentWithSheets: some View {
        GeometryReader { geometry in
            let isCompact = geometry.size.width < 500
            let timerSize: CGFloat = isCompact ? 260 : 320

            VStack(spacing: 0) {
                // Session progress indicator (when plan is active)
                if sessionPlan.isActive {
                    sessionProgressIndicator(isCompact: isCompact)
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

                                completedPredictedLevel = predicted
                                completedActualLevel = actualFocus
                                completedWasCompleted = false
                                completedSessionDuration = dur
                                completedDistractionCount = dist
                                showSessionComplete = true
                            } else if !timerService.isBreak {
                                // Save incomplete focus record (no prediction)
                                let record = FocusRecord(
                                    duration: settings.focusDuration - timerService.remainingTime,
                                    isBreak: false,
                                    taskId: timerService.selectedTask?.id,
                                    taskTitle: timerService.selectedTask?.title,
                                    wasCompleted: false,
                                    distractionCount: distractionCount
                                )
                                modelContext.insert(record)
                                timerService.stop()
                                notificationService.cancelTimerNotifications()
                                resetPredictionState()
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
                    Button {
                        soundService.lightImpact(settings: settings)
                        notificationService.cancelTimerNotifications()
                        ambientSoundService.stop()
                        if sessionPlan.isActive {
                            handleSessionPlanSkip()
                        } else {
                            timerService.skip()
                        }
                    } label: {
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
        .overlay {
            if showSessionBanner {
                SessionCompleteBanner(sessionNumber: sessionBannerNumber)
                    .transition(.asymmetric(
                        insertion: .scale(scale: 0.8).combined(with: .opacity),
                        removal: .scale(scale: 1.1).combined(with: .opacity)
                    ))
                    .onAppear {
                        // Auto-dismiss after 2 seconds
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                            withAnimation(.easeOut(duration: 0.3)) {
                                showSessionBanner = false
                            }
                        }
                    }
                    .zIndex(99)
            }
        }
        .animation(.spring(response: 0.4), value: showSessionBanner)
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
        .sheet(isPresented: $showSessionPlanUpgradePrompt) {
            ZStack {
                Color.black.opacity(0.3).ignoresSafeArea()
                    .onTapGesture { showSessionPlanUpgradePrompt = false }
                UpgradePromptView.sessionPlanLimit()
            }
            .presentationBackground(.clear)
        }
        .onReceive(NotificationCenter.default.publisher(for: .showSessionPlanner)) { _ in
            // Show session planner sheet (triggered from Home tab)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                if timerService.state == .idle && !sessionPlan.isActive {
                    if subscriptionService.canUseSessionPlanning {
                        showSessionPlannerSheet = true
                    } else {
                        showSessionPlanUpgradePrompt = true
                    }
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
            // Allow during breaks too — user is setting up their next focus session
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                if timerService.state == .idle || timerService.isBreak {
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
        .fullScreenCover(isPresented: $showSessionComplete) {
            sessionCompleteContent
        }
        .fullScreenCover(isPresented: $showFinalCelebration) {
            finalCelebrationContent
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
            wakeUpVoiceOnboardingContent
        }
        .sheet(isPresented: $showRecordVoice) {
            recordVoiceContent
        }
        .sheet(isPresented: $showAmbientSoundPicker) {
            AmbientSoundPicker()
        }
        .onChange(of: showAmbientSoundPicker) { _, isShowing in
            // When picker dismisses during an active session, ensure the selected sound plays
            if !isShowing && timerService.isRunning && !timerService.isBreak {
                if ambientSoundService.selectedSound != .silence && !ambientSoundService.isPlaying {
                    ambientSoundService.play()
                }
            }
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

            // If user already did a prediction, preserve it and just start
            if predictedFocus != nil {
                distractionCount = 0
                sessionWasCompleted = true
                timerService.togglePlayPause()
                if !timerService.isBreak {
                    ambientSoundService.play()
                }
            } else {
                startTimerWithoutPrediction()
            }
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
        // Set prediction but don't auto-start — user starts manually from the play button
        distractionCount = 0
        predictedFocus = level
        lastPrediction = level
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

    private var recordVoiceContent: some View {
        RecordVoiceView()
            .onDisappear {
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
                    pendingSessionPlan = nil
                    showEnergyOverlay = true
                } else {
                    startTimerWithoutPrediction()
                }
            }
    }

    private var wakeUpVoiceOnboardingContent: some View {
        WakeUpVoiceOnboardingView(
            onSetUp: {
                settings.hasSeenWakeUpVoiceOnboarding = true
                showWakeUpVoiceOnboarding = false
                showRecordVoice = true
            },
            onSkip: {
                settings.hasSeenWakeUpVoiceOnboarding = true
                showWakeUpVoiceOnboarding = false
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

    private var finalCelebrationContent: some View {
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
            },
            predictedLevel: completedPredictedLevel,
            actualLevel: completedActualLevel
        )
    }

    private var sessionCompleteContent: some View {
        SessionCompleteView(
            duration: completedSessionDuration,
            distractionCount: completedDistractionCount,
            onTakeBreak: {
                showSessionComplete = false
                resetPredictionState()
                if !timerService.isRunning || !timerService.isBreak {
                    timerService.setMode(.breakTime, duration: settings.breakDuration)
                    timerService.start()
                }
                if motionService.isAvailable {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        showRechargeMode = true
                    }
                }
            },
            onExtend: { extensionSeconds in
                showSessionComplete = false
                timerService.startExtension(duration: extensionSeconds)
            },
            onDismiss: {
                showSessionComplete = false
                resetPredictionState()
                if timerService.isRunning && timerService.isBreak && motionService.isAvailable {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        showRechargeMode = true
                    }
                }
            },
            predictedLevel: completedPredictedLevel,
            actualLevel: completedActualLevel,
            wasCompleted: completedWasCompleted
        )
    }

    @ViewBuilder
    private var directMandatoryBreakOverlay: some View {
        if showDirectMandatoryBreak {
            MandatoryBreakView(
                remainingSeconds: directMandatoryBreakRemaining,
                onBreakComplete: {
                    stopDirectMandatoryBreakTimer()
                    withAnimation(.easeOut(duration: 0.3)) {
                        showDirectMandatoryBreak = false
                    }
                    resetPredictionState()
                }
            )
            .transition(.opacity.combined(with: .scale(scale: 1.1)))
        }
    }

    private func startDirectMandatoryBreakTimer() {
        directMandatoryBreakStartDate = Date()
        directMandatoryBreakRemaining = mandatoryBreakDuration
        directMandatoryBreakTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            Task { @MainActor in
                recalcDirectMandatoryBreakRemaining()
            }
        }
    }

    private func recalcDirectMandatoryBreakRemaining() {
        guard let startDate = directMandatoryBreakStartDate else { return }
        let elapsed = Int(Date().timeIntervalSince(startDate))
        let remaining = max(0, mandatoryBreakDuration - elapsed)
        directMandatoryBreakRemaining = remaining
        if remaining <= 0 {
            stopDirectMandatoryBreakTimer()
        }
    }

    private func stopDirectMandatoryBreakTimer() {
        directMandatoryBreakTimer?.invalidate()
        directMandatoryBreakTimer = nil
        directMandatoryBreakStartDate = nil
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

                    if sessionPlan.isLastSession {
                        // Last session — show final celebration with cumulative stats, NO break
                        completedSessionDuration = sessionPlanTotalFocusTime
                        completedDistractionCount = sessionPlanTotalDistractions
                        // Include prediction data if available
                        if let predicted = predictedFocus {
                            completedPredictedLevel = predicted
                            completedActualLevel = calculateActualFocus()
                        }
                        showFinalCelebration = true
                    } else {
                        // Not last session — show brief banner, auto-start break
                        sessionBannerNumber = sessionPlan.displayCurrentSession
                        showSessionBanner = true
                        distractionCount = 0
                        resetPredictionState()
                        // Auto-start break after banner dismisses (2 seconds)
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                            timerService.setMode(.breakTime, duration: settings.breakDuration)
                            timerService.start()
                        }
                    }
                } else {
                    // Break complete — save break record, advance to next session
                    let breakRecord = FocusRecord(
                        duration: settings.breakDuration,
                        isBreak: true,
                        rechargePercentage: lastBreakRechargePercentage > 0 ? lastBreakRechargePercentage : nil
                    )
                    modelContext.insert(breakRecord)
                    lastBreakRechargePercentage = 0
                    continuousFocusTime = 0
                    distractionCount = 0
                    // Advance session plan and set up next focus
                    var plan = sessionPlan
                    plan.nextSession()
                    sessionPlan = plan
                    // Update selected task to the one assigned to the next session
                    if let taskId = plan.currentTaskId {
                        timerService.selectedTask = allTasks.first { $0.id == taskId }
                    }
                    // Note: currentSessionDisplay is updated via onChange(of: timerService.mode)
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

                // Show session complete (with prediction data if available)
                if let predicted = predictedFocus {
                    completedPredictedLevel = predicted
                    completedActualLevel = actualFocus
                    completedWasCompleted = true
                } else {
                    completedPredictedLevel = nil
                    completedActualLevel = nil
                    completedWasCompleted = true
                }
                completedSessionDuration = settings.focusDuration
                completedDistractionCount = distractionCount

                // If session >= mandatory break threshold, show autolock directly (skip summary)
                if settings.focusDuration >= mandatoryBreakThreshold {
                    timerService.skipDefaultTransition = true  // Prevent break timer from auto-starting behind autolock
                    directMandatoryBreakRemaining = 5 * 60
                    showDirectMandatoryBreak = true
                    startDirectMandatoryBreakTimer()
                } else {
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

    private func sessionProgressIndicator(isCompact: Bool) -> some View {
        let currentIndex = currentSessionDisplay - 1  // Convert to 0-indexed
        return HStack(spacing: isCompact ? 8 : 12) {
            ForEach(0..<sessionPlan.totalSessions, id: \.self) { index in
                Circle()
                    .fill(index < currentIndex
                          ? LinearGradient(colors: [.green, .mint], startPoint: .top, endPoint: .bottom)
                          : index == currentIndex
                          ? (timerService.isBreak
                             ? LinearGradient(colors: [Theme.breakColor, Theme.breakColor.opacity(0.7)], startPoint: .top, endPoint: .bottom)
                             : LinearGradient(colors: [.purple, .pink], startPoint: .top, endPoint: .bottom))
                          : LinearGradient(colors: [Theme.textTertiary.opacity(0.3), Theme.textTertiary.opacity(0.3)], startPoint: .top, endPoint: .bottom))
                    .frame(width: index == currentIndex ? (isCompact ? 12 : 14) : (isCompact ? 8 : 10),
                           height: index == currentIndex ? (isCompact ? 12 : 14) : (isCompact ? 8 : 10))
                    .animation(.spring(response: 0.3), value: currentSessionDisplay)
                    .animation(.spring(response: 0.3), value: timerService.isBreak)
            }

            if timerService.isBreak {
                Text("Break before Session \(currentSessionDisplay + 1)")
                    .font(.system(size: isCompact ? 13 : 15, weight: .medium))
                    .foregroundStyle(Theme.breakColor)
            } else {
                Text("Session \(currentSessionDisplay) of \(sessionPlan.totalSessions)")
                    .font(.system(size: isCompact ? 13 : 15, weight: .medium))
                    .foregroundStyle(Theme.textSecondary)
            }

            if !isCompact {
                Spacer()
            }
        }
        .padding(.horizontal, isCompact ? 16 : 24)
        .padding(.vertical, isCompact ? 10 : 14)
        .frame(maxWidth: isCompact ? nil : .infinity)
        .background(
            Capsule()
                .fill(Theme.backgroundSecondary)
        )
        .animation(.spring(response: 0.3), value: timerService.isBreak)
    }

    /// Look up the FocusTask for the current session plan assignment
    private func taskForCurrentSession() -> FocusTask? {
        guard let taskId = sessionPlan.currentTaskId else { return nil }
        return allTasks.first { $0.id == taskId }
    }

    private func startSessionPlan() {
        guard sessionPlan.totalSessions > 0 else { return }

        // Initialize session plan state
        sessionPlanTotalDistractions = 0
        sessionPlanTotalFocusTime = 0
        continuousFocusTime = 0
        distractionCount = 0
        currentSessionDisplay = 1

        // Set the selected task to the one assigned to session 1
        timerService.selectedTask = taskForCurrentSession()

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
        currentSessionDisplay = 1

        // Set the selected task to the one assigned to session 1
        timerService.selectedTask = taskForCurrentSession()

        // Set prediction but don't auto-start — user starts manually from the timer
        predictedFocus = level
        lastPrediction = level
        timerService.setMode(.focus, duration: settings.focusDuration)
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

    private func handleSessionPlanSkip() {
        // Skip during session plan — only record actual elapsed time, not full duration
        let wasRunning = timerService.state != .idle
        let actualElapsed = wasRunning ? (timerService.totalDuration - timerService.remainingTime) : 0
        timerService.stop()

        if timerService.isBreak {
            // Skipping a break — just advance to next focus session
            distractionCount = 0
            var plan = sessionPlan
            plan.nextSession()
            sessionPlan = plan
            currentSessionDisplay = plan.displayCurrentSession
            if let taskId = plan.currentTaskId {
                timerService.selectedTask = allTasks.first { $0.id == taskId }
            }
            timerService.setMode(.focus, duration: settings.focusDuration)
        } else {
            // Skipping a focus session — record partial time only if timer actually ran
            if actualElapsed > 0 {
                sessionPlanTotalDistractions += distractionCount
                sessionPlanTotalFocusTime += actualElapsed
                let record = FocusRecord(
                    duration: actualElapsed,
                    isBreak: false,
                    taskId: timerService.selectedTask?.id,
                    taskTitle: timerService.selectedTask?.title,
                    wasCompleted: false,
                    distractionCount: distractionCount
                )
                modelContext.insert(record)
            }

            if sessionPlan.isLastSession {
                if sessionPlanTotalFocusTime > 0 {
                    // Some actual focus was done — show celebration with real stats
                    completedSessionDuration = sessionPlanTotalFocusTime
                    completedDistractionCount = sessionPlanTotalDistractions
                    showFinalCelebration = true
                } else {
                    // No focus time at all — just cancel the plan silently
                    finishSessionPlan()
                }
            } else {
                // Not last — advance to next session directly (no break since they skipped)
                distractionCount = 0
                resetPredictionState()
                var plan = sessionPlan
                plan.nextSession()
                sessionPlan = plan
                currentSessionDisplay = plan.displayCurrentSession
                if let taskId = plan.currentTaskId {
                    timerService.selectedTask = allTasks.first { $0.id == taskId }
                }
                timerService.setMode(.focus, duration: settings.focusDuration)
            }
        }
    }

    private func handleSessionPlanContinue() {
        // Skip break, move to next session setup
        var updatedPlan = sessionPlan
        updatedPlan.nextSession()
        sessionPlan = updatedPlan
        currentSessionDisplay += 1
        // Update selected task to the one assigned to the next session
        if let taskId = updatedPlan.currentTaskId {
            timerService.selectedTask = allTasks.first { $0.id == taskId }
        }
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
        currentSessionDisplay = 1
        // Reset timer back to idle focus mode with default duration
        timerService.stop()
        timerService.setMode(.focus, duration: settings.focusDuration)
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

// MARK: - Session Complete Banner (shown between sessions in a plan)

@MainActor
private struct SessionCompleteBanner: View {
    let sessionNumber: Int
    @State private var checkScale: CGFloat = 0
    @State private var textOpacity: Double = 0

    var body: some View {
        VStack(spacing: 16) {
            Spacer()

            VStack(spacing: 12) {
                // Animated checkmark
                ZStack {
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [.green.opacity(0.3), .green.opacity(0.05)],
                                center: .center,
                                startRadius: 10,
                                endRadius: 50
                            )
                        )
                        .frame(width: 80, height: 80)

                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 52))
                        .foregroundStyle(.green)
                        .scaleEffect(checkScale)
                }

                Text("Session \(sessionNumber) Complete")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .opacity(textOpacity)

                Text("Break starting...")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.white.opacity(0.6))
                    .opacity(textOpacity)
            }
            .padding(.horizontal, 32)
            .padding(.vertical, 28)
            .background(
                RoundedRectangle(cornerRadius: 24)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 24)
                            .stroke(.white.opacity(0.15), lineWidth: 1)
                    )
            )

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black.opacity(0.5))
        .onAppear {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
                checkScale = 1.0
            }
            withAnimation(.easeOut(duration: 0.3).delay(0.2)) {
                textOpacity = 1.0
            }
        }
    }
}
