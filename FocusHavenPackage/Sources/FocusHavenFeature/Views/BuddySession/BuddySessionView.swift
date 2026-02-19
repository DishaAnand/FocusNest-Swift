import SwiftUI
import SwiftData
import UIKit

@MainActor
public struct BuddySessionView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @Environment(SessionService.self) private var sessionService
    @Environment(UserSettings.self) private var settings
    @Environment(NotificationService.self) private var notificationService
    @Environment(SoundService.self) private var soundService
    @Environment(SubscriptionService.self) private var subscriptionService
    @Query(filter: #Predicate<FocusTask> { !$0.isCompleted }, sort: \FocusTask.createdAt, order: .reverse) private var tasks: [FocusTask]

    @State private var currentStep: BuddySessionStep = .setup
    @State private var showUpgradePrompt = false
    @State private var selectedTask: FocusTask?
    @State private var customTaskTitle = ""
    @State private var sessionDuration = 25
    @State private var userName = UserDefaults.standard.string(forKey: "userName") ?? ""
    @State private var errorMessage: String?
    @State private var showJoinWithCode = false
    @State private var showCreateSession = false
    @State private var joinCode = ""

    // Track if user stayed in support mode (for accurate summary duration)
    @State private var stayedInSupportMode = false

    // Distraction detection - only counted when user RETURNS after 15+ seconds
    @State private var wentAwayAt: Date?
    @State private var wasScreenLocked = false
    private let distractionThreshold: TimeInterval = 15  // seconds

    public init() {}

    public var body: some View {
        NavigationStack {
            ZStack {
                Group {
                    switch currentStep {
                    case .setup: setupView
                    case .waiting: waitingView
                    case .active: activeSessionView
                    case .celebrating: Color.clear // Celebration overlay handles this
                    case .postCompletion: postCompletionView
                    case .supportMode: supportModeView
                    case .summary: summaryView
                    }
                }

                // Celebration overlay
                if currentStep == .celebrating {
                    CelebrationOverlay {
                        // Check if buddy is still going
                        if let session = sessionService.currentSession {
                            let buddyStillGoing = session.otherParticipants(exceptId: sessionService.deviceId)
                                .contains { session.remainingTimeForParticipant($0.odid, currentTime: sessionService.serverTime) > 0 }
                            if buddyStillGoing {
                                currentStep = .postCompletion
                            } else {
                                currentStep = .summary
                            }
                        } else {
                            currentStep = .summary
                        }
                    }
                }
            }
            .navigationTitle(navigationTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { if currentStep != .summary { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { Task { await cancelSession() } } } } }
            .alert("Error", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) { Button("OK") { errorMessage = nil } } message: { Text(errorMessage ?? "") }
            .onChange(of: sessionService.currentSession?.state) { _, newState in handleSessionStateChange(newState) }
            .onChange(of: sessionService.currentSession?.participantCount) { oldCount, newCount in
                // Notify when a buddy joins (participant count increases)
                if let old = oldCount, let new = newCount, new > old && currentStep == .waiting {
                    soundService.successHaptic(settings: settings)
                    Task {
                        await notificationService.notifyBuddyJoined()
                    }
                }
            }
            .onChange(of: scenePhase) { oldPhase, newPhase in
                // Only track distractions during active session
                guard currentStep == .active else { return }

                if newPhase != .active && oldPhase == .active {
                    // User left the app - record the time
                    wentAwayAt = Date()
                    // Check if protected data is available - if not, device is locked
                    // This is more reliable than brightness across iOS versions
                    wasScreenLocked = !UIApplication.shared.isProtectedDataAvailable
                } else if newPhase == .active && oldPhase != .active {
                    // User returned to the app
                    Task {
                        // Only count as distraction if:
                        // 1. They were away 15+ seconds
                        // 2. Screen was NOT locked (they switched apps)
                        if let awayTime = wentAwayAt {
                            let awayDuration = Int(Date().timeIntervalSince(awayTime))
                            if awayDuration >= Int(distractionThreshold) && !wasScreenLocked {
                                try? await sessionService.recordDistraction(awayDuration: awayDuration)
                            }
                        }
                        wentAwayAt = nil
                        wasScreenLocked = false
                    }
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.protectedDataWillBecomeUnavailableNotification)) { _ in
                // Device is being locked - mark it so we don't count as distraction
                if currentStep == .active {
                    wasScreenLocked = true
                }
            }
            .onAppear {
                // If we already have a session (joined via deep link), skip to appropriate step
                if let session = sessionService.currentSession {
                    switch session.state {
                    case .waiting: currentStep = .waiting
                    case .active: currentStep = .active
                    case .completed: currentStep = .summary
                    default: break
                    }
                }
            }
        }
        .presentationDetents([.large])
        .interactiveDismissDisabled(currentStep != .setup)
    }

    private var navigationTitle: String {
        let isCreator = sessionService.currentSession?.creatorId == sessionService.deviceId
        switch currentStep {
        case .setup: return "Start Buddy Session"
        case .waiting: return isCreator ? "Waiting for Buddy" : "Ready to Focus"
        case .active: return "Focus Together"
        case .celebrating: return "Focus Together"
        case .postCompletion: return "You Did It!"
        case .supportMode: return "Supporting Buddy"
        case .summary: return ""  // Summary has its own visual header
        }
    }

    private var setupView: some View {
        ScrollView {
            VStack(spacing: Theme.spacingL) {
                // Header
                VStack(spacing: Theme.spacingS) {
                    Image(systemName: "person.2.fill")
                        .font(.system(size: 48))
                        .foregroundStyle(Theme.focusColor)
                    Text("Buddy Session")
                        .font(Theme.titleFont)
                    Text("Focus together with a friend")
                        .font(Theme.bodyFont)
                        .foregroundStyle(Theme.textSecondary)
                }
                .padding(.top, Theme.spacingM)

                // Two clear options
                VStack(spacing: Theme.spacingM) {
                    // Create Session Card
                    Button {
                        if subscriptionService.canStartBuddySession {
                            showCreateSession = true
                        } else {
                            showUpgradePrompt = true
                        }
                    } label: {
                        HStack(spacing: Theme.spacingM) {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 32))
                                .foregroundStyle(Theme.focusColor)
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Create Session")
                                    .font(Theme.headlineFont)
                                    .foregroundStyle(Theme.textPrimary)
                                Text("Start a new focus session and invite a buddy")
                                    .font(Theme.captionFont)
                                    .foregroundStyle(Theme.textSecondary)
                                    .multilineTextAlignment(.leading)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundStyle(Theme.textSecondary)
                        }
                        .padding(Theme.spacingM)
                        .background(Theme.backgroundSecondary)
                        .clipShape(RoundedRectangle(cornerRadius: Theme.cornerRadiusM))
                    }

                    // Join Session Card
                    Button {
                        if subscriptionService.canStartBuddySession {
                            showJoinWithCode = true
                        } else {
                            showUpgradePrompt = true
                        }
                    } label: {
                        HStack(spacing: Theme.spacingM) {
                            Image(systemName: "person.badge.plus")
                                .font(.system(size: 32))
                                .foregroundStyle(.teal)
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Join Session")
                                    .font(Theme.headlineFont)
                                    .foregroundStyle(Theme.textPrimary)
                                Text("Enter a code to join your buddy's session")
                                    .font(Theme.captionFont)
                                    .foregroundStyle(Theme.textSecondary)
                                    .multilineTextAlignment(.leading)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundStyle(Theme.textSecondary)
                        }
                        .padding(Theme.spacingM)
                        .background(Theme.backgroundSecondary)
                        .clipShape(RoundedRectangle(cornerRadius: Theme.cornerRadiusM))
                    }
                }
            }
            .padding(Theme.spacingM)
            .frame(maxWidth: 500)  // iPad: constrain content width
            .frame(maxWidth: .infinity)  // Center on larger screens
        }
        .sheet(isPresented: $showCreateSession) {
            CreateSessionSheet(isPresented: $showCreateSession) {
                currentStep = .waiting
            }
        }
        .sheet(isPresented: $showJoinWithCode) {
            BuddyJoinWithCodeSheet(isPresented: $showJoinWithCode) {
                currentStep = .waiting
            }
        }
        .sheet(isPresented: $showUpgradePrompt) {
            UpgradePromptSheet {
                UpgradePromptView.buddySessionLimit()
            }
        }
    }

    private struct UpgradePromptSheet<Content: View>: View {
        @Environment(\.dismiss) private var dismiss
        let content: () -> Content

        init(@ViewBuilder content: @escaping () -> Content) {
            self.content = content
        }

        var body: some View {
            ZStack {
                Color.black.opacity(0.3).ignoresSafeArea()
                    .onTapGesture { dismiss() }
                content()
            }
            .presentationBackground(.clear)
        }
    }

    private var waitingView: some View {
        let isCreator = sessionService.currentSession?.creatorId == sessionService.deviceId

        return VStack(spacing: Theme.spacingXL) {
            Spacer()
            PulsingIndicatorView()

            if let session = sessionService.currentSession {
                if isCreator {
                    // CREATOR VIEW - Show share options
                    Text("Waiting for your buddy to join...").font(Theme.headlineFont).foregroundStyle(Theme.textSecondary)

                    VStack(spacing: Theme.spacingM) {
                        Text("Share this code with your buddy:").font(Theme.captionFont).foregroundStyle(Theme.textSecondary)

                        // Show the session code prominently
                        Text(session.shortCode)
                            .font(.system(size: 36, weight: .bold, design: .monospaced))
                            .tracking(4)
                            .foregroundStyle(Theme.focusColor)
                            .padding(.vertical, Theme.spacingM)

                        // Share button - opens share sheet with code
                        ShareLink(item: "Join my FocusHaven focus session! Open the app and enter code: \(session.shortCode)", subject: Text("Join my FocusHaven session!")) {
                            Label("Share Code", systemImage: "square.and.arrow.up")
                                .font(Theme.headlineFont)
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, Theme.spacingM)
                                .background(Theme.focusGradient)
                                .clipShape(RoundedRectangle(cornerRadius: Theme.cornerRadiusM))
                        }
                        .frame(maxWidth: 280)

                        // Copy button as backup
                        Button { UIPasteboard.general.string = session.shortCode; soundService.lightImpact(settings: settings) } label: { Label("Copy Code", systemImage: "doc.on.doc").secondaryButtonStyle() }.frame(maxWidth: 200)

                        Text("Your buddy can tap 'Join with Code' in the app").font(Theme.captionFont).foregroundStyle(Theme.textSecondary).multilineTextAlignment(.center)
                    }

                    if session.isReadyToStart {
                        Button { Task { await startSession() } } label: { Text("Start Session").primaryButtonStyle() }.padding(.top, Theme.spacingM)
                    }
                } else {
                    // JOINER VIEW - Show waiting for host
                    Text("You're in!").font(Theme.titleFont).foregroundStyle(Theme.focusColor)
                    Text("Waiting for the host to start the session...").font(Theme.headlineFont).foregroundStyle(Theme.textSecondary).multilineTextAlignment(.center)

                    // Show who you're focusing with
                    if let creator = session.participants[session.creatorId] {
                        VStack(spacing: Theme.spacingS) {
                            Text("Focusing with").font(Theme.captionFont).foregroundStyle(Theme.textSecondary)
                            Text(creator.name).font(Theme.headlineFont)
                            Text("Working on: \(creator.taskTitle)").font(Theme.bodyFont).foregroundStyle(Theme.textSecondary)
                        }
                        .padding(Theme.spacingM)
                        .background(Theme.backgroundSecondary)
                        .clipShape(RoundedRectangle(cornerRadius: Theme.cornerRadiusM))
                    }

                    Text("Session will start when the host is ready").font(Theme.captionFont).foregroundStyle(Theme.textSecondary)
                }
            }
            Spacer()
        }
        .padding(Theme.spacingM)
        .frame(maxWidth: 500)  // iPad: constrain content width
        .frame(maxWidth: .infinity)  // Center on larger screens
    }

    private var activeSessionView: some View {
        VStack(spacing: Theme.spacingL) {
            if let session = sessionService.currentSession {
                ActiveSessionTimerView(session: session) {
                    // My timer completed - show celebration
                    currentStep = .celebrating
                }
            }
        }
        .padding(Theme.spacingM)
        .frame(maxWidth: 500)  // iPad: constrain content width
        .frame(maxWidth: .infinity)  // Center on larger screens
    }

    private var postCompletionView: some View {
        VStack(spacing: Theme.spacingXL) {
            Spacer()

            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 80))
                .foregroundStyle(Theme.focusColor)

            Text("Great focus session!")
                .font(Theme.titleFont)

            if let session = sessionService.currentSession,
               let buddy = session.otherParticipants(exceptId: sessionService.deviceId).first {
                let buddyRemaining = session.remainingTimeForParticipant(buddy.odid, currentTime: sessionService.serverTime)

                if buddyRemaining > 0 {
                    Text("\(buddy.name) has \(buddyRemaining / 60):\(String(format: "%02d", buddyRemaining % 60)) left")
                        .font(Theme.headlineFont)
                        .foregroundStyle(Theme.textSecondary)

                    VStack(spacing: Theme.spacingM) {
                        Button {
                            stayedInSupportMode = true
                            currentStep = .supportMode
                            Task { try? await sessionService.updateStatus(.supporting) }
                        } label: {
                            Text("Focus Together").primaryButtonStyle()
                        }

                        Button {
                            currentStep = .summary
                        } label: {
                            Text("I'm Done").secondaryButtonStyle()
                        }
                    }
                    .padding(.top, Theme.spacingM)
                }
            }

            Spacer()
        }
        .padding(Theme.spacingM)
        .frame(maxWidth: 500)  // iPad: constrain content width
        .frame(maxWidth: .infinity)  // Center on larger screens
    }

    private var supportModeView: some View {
        VStack(spacing: Theme.spacingL) {
            if let session = sessionService.currentSession {
                SupportModeTimerView(session: session) {
                    // Buddy finished - both go to rating
                    currentStep = .celebrating
                }
            }
        }
        .padding(Theme.spacingM)
        .frame(maxWidth: 500)  // iPad: constrain content width
        .frame(maxWidth: .infinity)  // Center on larger screens
    }

    private var summaryView: some View {
        Group {
            if let session = sessionService.currentSession {
                let me = session.participant(withId: sessionService.deviceId)
                let buddy = session.otherParticipants(exceptId: sessionService.deviceId).first

                // If user stayed in support mode, they focused for the full buddy duration
                let myOriginalDuration = me?.duration ?? session.duration
                let buddyOriginalDuration = buddy?.duration ?? session.duration
                let myActualDuration = stayedInSupportMode ? max(myOriginalDuration, buddyOriginalDuration) : myOriginalDuration

                SessionSummaryView(
                    myName: me?.name ?? userName,
                    buddyName: buddy?.name ?? "Buddy",
                    myDuration: myActualDuration,
                    buddyDuration: buddyOriginalDuration,
                    myDistractions: me?.violationCount ?? 0,
                    buddyDistractions: buddy?.violationCount ?? 0,
                    onDone: {
                        // Save focus record with actual duration (including support time)
                        modelContext.insert(FocusRecord(
                            duration: myActualDuration,
                            isBreak: false,
                            taskTitle: customTaskTitle.isEmpty ? (me?.taskTitle ?? "Focus session") : customTaskTitle,
                            wasCompleted: true,
                            wasBuddySession: true
                        ))
                        soundService.successHaptic(settings: settings)
                        finishSession()
                    }
                )
                .navigationBarHidden(true)
            } else {
                // Fallback if session is nil
                VStack(spacing: Theme.spacingXL) {
                    Spacer()
                    Image(systemName: "hands.clap.fill").font(.system(size: 80)).foregroundStyle(Theme.focusColor)
                    Text("Session Complete!").font(Theme.titleFont)
                    Button { finishSession() } label: { Text("Done").primaryButtonStyle() }
                    Spacer()
                }.padding(Theme.spacingM)
            }
        }
    }

    private func createSession() async {
        UserDefaults.standard.set(userName, forKey: "userName")
        do {
            _ = try await sessionService.createSession(taskTitle: customTaskTitle, duration: sessionDuration * 60, userName: userName)
            currentStep = .waiting
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func startSession() async {
        do {
            try await sessionService.startSession()
            subscriptionService.recordBuddySessionUsed()
            currentStep = .active
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func completeSession() async {
        wentAwayAt = nil
        do {
            try await sessionService.completeSession()
            await notificationService.notifyBuddySessionComplete()
            currentStep = .summary
        } catch {
            errorMessage = error.localizedDescription
        }
    }


    private func cancelSession() async {
        try? await sessionService.leaveSession()
        sessionService.cleanup()
        resetState()
        dismiss()
    }

    private func finishSession() {
        sessionService.cleanup()
        resetState()
    }

    private func handleSessionStateChange(_ newState: SessionState?) {
        guard let state = newState else { return }
        switch state {
        case .active:
            if currentStep == .waiting {
                subscriptionService.recordBuddySessionUsed()
                currentStep = .active
                // Ensure our status is focused when session starts
                Task { try? await sessionService.updateStatus(.focused) }
            }
        case .completed: if currentStep == .active { currentStep = .summary }
        case .cancelled: errorMessage = "Session was cancelled"; resetState()
        default: break
        }
    }

    private func resetState() {
        wentAwayAt = nil
        currentStep = .setup
        selectedTask = nil
        customTaskTitle = ""
        sessionDuration = 25
        stayedInSupportMode = false
    }
}

enum BuddySessionStep { case setup, waiting, active, celebrating, postCompletion, supportMode, summary }

@MainActor
private struct ActiveSessionTimerView: View {
    @Environment(SessionService.self) private var sessionService
    @Environment(NotificationService.self) private var notificationService
    @Environment(SoundService.self) private var soundService
    @Environment(UserSettings.self) private var settings
    let session: BuddySession
    let onComplete: () -> Void
    @State private var remainingTime: Int = 0
    @State private var progress: Double = 0.0
    @State private var timer: Timer?
    @State private var displayTimer: Timer?
    @State private var buddySupportNotified = false

    private var myDuration: Int {
        session.participant(withId: sessionService.deviceId)?.duration ?? session.duration
    }

    /// Use live session data so buddy status updates are reflected
    private var buddy: SessionParticipant? {
        let liveSession = sessionService.currentSession ?? session
        return liveSession.otherParticipants(exceptId: sessionService.deviceId).first
    }

    private var buddyRemainingTime: Int {
        guard let buddy = buddy else { return 0 }
        let liveSession = sessionService.currentSession ?? session
        return liveSession.remainingTimeForParticipant(buddy.odid, currentTime: sessionService.serverTime)
    }

    var body: some View {
        VStack(spacing: Theme.spacingM) {
            // Your timer
            CircularProgressView(progress: progress, size: 200, color: Theme.focusColor)
            Text(String(format: "%02d:%02d", remainingTime / 60, remainingTime % 60)).font(Theme.timerFontSmall).monospacedDigit()

            // Buddy status card
            if let buddy = buddy {
                HStack(spacing: Theme.spacingM) {
                    // Show green circle or checkmark if completed
                    if buddyRemainingTime > 0 {
                        Circle()
                            .fill(Color.green)
                            .frame(width: 12, height: 12)
                    } else {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(Theme.focusColor)
                            .font(.system(size: 16))
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text(buddy.name).font(Theme.headlineFont)
                        Text(buddy.taskTitle).font(Theme.captionFont).foregroundStyle(Theme.textSecondary)

                        // Show buddy's remaining time or completed status
                        if buddyRemainingTime > 0 {
                            Text("\(buddyRemainingTime / 60):\(String(format: "%02d", buddyRemainingTime % 60)) left")
                                .font(Theme.captionFont)
                                .foregroundStyle(Theme.textSecondary)
                        } else {
                            Text("Completed!")
                                .font(Theme.captionFont)
                                .foregroundStyle(Theme.focusColor)
                        }
                    }
                    Spacer()

                    // Distraction count badge or completion badge
                    if buddyRemainingTime <= 0 {
                        VStack {
                            Image(systemName: "hands.clap.fill")
                                .font(.system(size: 20))
                                .foregroundStyle(Theme.focusColor)
                        }
                    } else if buddy.violationCount > 0 {
                        VStack {
                            Text("\(buddy.violationCount)")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundStyle(.white)
                                .frame(width: 28, height: 28)
                                .background(Color.orange)
                                .clipShape(Circle())
                            Text("away").font(.system(size: 10)).foregroundStyle(Theme.textSecondary)
                        }
                    }
                }
                .padding(Theme.spacingM)
                .background(Theme.backgroundSecondary)
                .clipShape(RoundedRectangle(cornerRadius: Theme.cornerRadiusM))

                if buddy.status == .supporting {
                    HStack(spacing: Theme.spacingS) {
                        Image(systemName: "hands.clap.fill")
                            .foregroundStyle(Theme.focusColor)
                        Text("\(buddy.name) is cheering you on!")
                            .font(Theme.captionFont)
                            .foregroundStyle(Theme.focusColor)
                    }
                    .padding(.horizontal, Theme.spacingM)
                    .padding(.vertical, Theme.spacingS)
                    .background(Theme.focusColor.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: Theme.cornerRadiusS))
                }
            }
        }
        .onAppear {
            let duration = myDuration
            // Use participant's own duration
            remainingTime = session.remainingTimeForParticipant(sessionService.deviceId, currentTime: sessionService.serverTime)
            progress = 1.0 - Double(remainingTime) / Double(duration)
            // 1-second timer for countdown and completion
            let capturedSoundService = soundService
            let capturedNotificationService = notificationService
            let capturedSettings = settings
            timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [sessionService] _ in
                Task { @MainActor in
                    let remaining = session.remainingTimeForParticipant(sessionService.deviceId, currentTime: sessionService.serverTime)
                    if remaining > 0 { remainingTime = remaining }
                    else { timer?.invalidate(); displayTimer?.invalidate(); onComplete() }

                    // Check if buddy entered support mode
                    if let liveSession = sessionService.currentSession,
                       let liveBuddy = liveSession.otherParticipants(exceptId: sessionService.deviceId).first {
                        if liveBuddy.status == .supporting && !buddySupportNotified {
                            NSLog("[ActiveTimer] BUDDY IS SUPPORTING! name=%@ notifying now", liveBuddy.name)
                            buddySupportNotified = true
                            capturedSoundService.successHaptic(settings: capturedSettings)
                            await capturedNotificationService.notifyBuddySupporting(buddyName: liveBuddy.name)
                        }
                    }
                }
            }
            // 60fps timer for smooth progress — same as normal TimerService
            displayTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { [sessionService] _ in
                Task { @MainActor in
                    let preciseRemaining = session.preciseRemainingTime(forParticipant: sessionService.deviceId, currentTime: sessionService.serverTime)
                    let preciseElapsed = Double(duration) - preciseRemaining
                    progress = min(max(preciseElapsed / Double(duration), 0.0), 1.0)
                }
            }
        }
        .onDisappear { timer?.invalidate(); displayTimer?.invalidate() }
    }
}

@MainActor
private struct SupportModeTimerView: View {
    @Environment(SessionService.self) private var sessionService
    let session: BuddySession
    let onBuddyComplete: () -> Void
    @State private var buddyRemainingTime: Int = 0
    @State private var buddyProgress: Double = 0.0
    @State private var timer: Timer?
    @State private var displayTimer: Timer?

    private var buddy: SessionParticipant? {
        session.otherParticipants(exceptId: sessionService.deviceId).first
    }

    var body: some View {
        VStack(spacing: Theme.spacingL) {
            Text("Supporting your buddy")
                .font(Theme.headlineFont)
                .foregroundStyle(Theme.textSecondary)

            if let buddy = buddy {
                // Buddy's timer (you're watching them)
                CircularProgressView(
                    progress: buddyProgress,
                    size: 200,
                    color: Theme.focusColor
                )

                Text(String(format: "%02d:%02d", buddyRemainingTime / 60, buddyRemainingTime % 60))
                    .font(Theme.timerFontSmall)
                    .monospacedDigit()

                // Buddy info card
                HStack(spacing: Theme.spacingM) {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 12, height: 12)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(buddy.name).font(Theme.headlineFont)
                        Text(buddy.taskTitle).font(Theme.captionFont).foregroundStyle(Theme.textSecondary)
                    }
                    Spacer()

                    // Your completed badge
                    VStack {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 24))
                            .foregroundStyle(Theme.focusColor)
                        Text("You").font(.system(size: 10)).foregroundStyle(Theme.textSecondary)
                    }
                }
                .padding(Theme.spacingM)
                .background(Theme.backgroundSecondary)
                .clipShape(RoundedRectangle(cornerRadius: Theme.cornerRadiusM))

                Text("You finished! Cheering on \(buddy.name)")
                    .font(Theme.captionFont)
                    .foregroundStyle(Theme.textSecondary)
            }
        }
        .onAppear {
            guard let buddy = buddy else { return }
            let duration = buddy.duration
            buddyRemainingTime = session.remainingTimeForParticipant(buddy.odid, currentTime: sessionService.serverTime)
            buddyProgress = 1.0 - Double(buddyRemainingTime) / Double(duration)
            // 1-second timer for countdown and completion
            timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [sessionService] _ in
                Task { @MainActor in
                    guard let buddy = session.otherParticipants(exceptId: sessionService.deviceId).first else { return }
                    let remaining = session.remainingTimeForParticipant(buddy.odid, currentTime: sessionService.serverTime)
                    if remaining > 0 {
                        buddyRemainingTime = remaining
                    } else {
                        timer?.invalidate()
                        displayTimer?.invalidate()
                        onBuddyComplete()
                    }
                }
            }
            // 60fps timer for smooth progress
            displayTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { [sessionService] _ in
                Task { @MainActor in
                    guard let buddy = session.otherParticipants(exceptId: sessionService.deviceId).first else { return }
                    let preciseRemaining = session.preciseRemainingTime(forParticipant: buddy.odid, currentTime: sessionService.serverTime)
                    let preciseElapsed = Double(buddy.duration) - preciseRemaining
                    buddyProgress = min(max(preciseElapsed / Double(buddy.duration), 0.0), 1.0)
                }
            }
        }
        .onDisappear { timer?.invalidate(); displayTimer?.invalidate() }
    }
}

@MainActor
struct BuddyJoinWithCodeSheet: View {
    @Environment(SessionService.self) private var sessionService
    @Query(filter: #Predicate<FocusTask> { !$0.isCompleted }, sort: \FocusTask.createdAt, order: .reverse) private var tasks: [FocusTask]

    @Binding var isPresented: Bool
    let onJoined: () -> Void

    @State private var userName = UserDefaults.standard.string(forKey: "userName") ?? ""
    @State private var taskTitle = ""
    @State private var code = ""
    @State private var sessionDuration = 25
    @State private var selectedTask: FocusTask?
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Theme.spacingL) {
                    // Header
                    Image(systemName: "person.badge.plus")
                        .font(.system(size: 60))
                        .foregroundStyle(.teal)
                        .padding(.top, Theme.spacingM)

                    Text("Join Session")
                        .font(Theme.titleFont)

                    // Session code
                    VStack(alignment: .leading, spacing: Theme.spacingS) {
                        Text("Session Code").font(Theme.headlineFont)
                        HStack {
                            Image(systemName: "number")
                                .foregroundStyle(.teal)
                                .font(.system(size: 24, weight: .semibold))
                            TextField("XXXX", text: $code)
                                .font(.system(size: 32, weight: .bold, design: .monospaced))
                                .textInputAutocapitalization(.characters)
                                .autocorrectionDisabled()
                                .multilineTextAlignment(.center)
                        }
                        .padding()
                        .background(Theme.backgroundSecondary)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(code.count >= 4 ? Color.teal.opacity(0.5) : Color.clear, lineWidth: 2)
                        )
                    }

                    // Name field
                    VStack(alignment: .leading, spacing: Theme.spacingS) {
                        Text("Your Name").font(Theme.headlineFont)
                        HStack(spacing: 12) {
                            Image(systemName: "person.fill")
                                .foregroundStyle(Theme.textTertiary)
                            TextField("Enter your name", text: $userName)
                                .font(Theme.bodyFont)
                                .autocorrectionDisabled()
                        }
                        .padding()
                        .background(Theme.backgroundSecondary)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }

                    // Task field
                    VStack(alignment: .leading, spacing: Theme.spacingS) {
                        Text("What are you working on?").font(Theme.headlineFont)
                        HStack(spacing: 12) {
                            Image(systemName: "target")
                                .foregroundStyle(Theme.textTertiary)
                            TextField("Enter your focus task", text: $taskTitle)
                                .font(Theme.bodyFont)
                        }
                        .padding()
                        .background(Theme.backgroundSecondary)
                        .clipShape(RoundedRectangle(cornerRadius: 12))

                        if !tasks.isEmpty {
                            Text("Or select:")
                                .font(Theme.captionFont)
                                .foregroundStyle(Theme.textSecondary)
                            ForEach(tasks.prefix(3)) { task in
                                TaskSelectionCardView(task: task, isSelected: selectedTask?.id == task.id) {
                                    selectedTask = task
                                    taskTitle = task.title
                                }
                            }
                        }
                    }

                    // Duration picker
                    VStack(alignment: .leading, spacing: Theme.spacingS) {
                        HStack {
                            Image(systemName: "clock.fill")
                                .foregroundStyle(.teal)
                            Text("Your Focus Duration").font(Theme.headlineFont)
                        }
                        Text("Can differ from your buddy's time").font(Theme.captionFont).foregroundStyle(Theme.textSecondary)
                        Picker("Duration", selection: $sessionDuration) {
                            Text("1 min").tag(1)
                            Text("15 min").tag(15)
                            Text("25 min").tag(25)
                            Text("45 min").tag(45)
                        }.pickerStyle(.segmented)
                    }

                    if let error = errorMessage {
                        Text(error)
                            .font(Theme.captionFont)
                            .foregroundStyle(.red)
                            .multilineTextAlignment(.center)
                    }

                    // Join button
                    Button {
                        UserDefaults.standard.set(userName, forKey: "userName")
                        Task { await joinWithCode() }
                    } label: {
                        if isLoading {
                            ProgressView().tint(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, Theme.spacingM)
                                .background(Theme.focusGradient)
                                .clipShape(RoundedRectangle(cornerRadius: Theme.cornerRadiusM))
                        } else {
                            Text("Join Session").primaryButtonStyle()
                        }
                    }
                    .disabled(code.count < 4 || isLoading || userName.isEmpty || taskTitle.isEmpty)
                    .padding(.top, Theme.spacingS)
                }
                .padding(Theme.spacingM)
                .frame(maxWidth: 500)  // iPad: constrain content width
                .frame(maxWidth: .infinity)  // Center on larger screens
            }
            .navigationTitle("Join Session")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { isPresented = false }
                }
            }
        }
    }

    private func joinWithCode() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let sessionId = try await sessionService.findSessionByCode(code)
            _ = try await sessionService.joinSession(sessionId: sessionId, taskTitle: taskTitle, userName: userName, duration: sessionDuration * 60)
            isPresented = false
            onJoined()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

@MainActor
struct CreateSessionSheet: View {
    @Environment(SessionService.self) private var sessionService
    @Environment(SoundService.self) private var soundService
    @Environment(UserSettings.self) private var settings
    @Environment(\.modelContext) private var modelContext
    @Query(filter: #Predicate<FocusTask> { !$0.isCompleted }, sort: \FocusTask.createdAt, order: .reverse) private var tasks: [FocusTask]

    @Binding var isPresented: Bool
    let onCreated: () -> Void

    @State private var userName = UserDefaults.standard.string(forKey: "userName") ?? ""
    @State private var taskTitle = ""
    @State private var duration = 25
    @State private var selectedTask: FocusTask?
    @State private var isLoading = false
    @State private var errorMessage: String?

    private var isFormValid: Bool {
        !userName.isEmpty && !taskTitle.isEmpty
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Theme.spacingL) {
                    // Header
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 56))
                        .foregroundStyle(Theme.focusColor)
                        .padding(.top, Theme.spacingM)

                    Text("Create Session")
                        .font(Theme.titleFont)

                    // Name field
                    VStack(alignment: .leading, spacing: Theme.spacingS) {
                        Text("Your Name").font(Theme.headlineFont)
                        HStack(spacing: 12) {
                            Image(systemName: "person.fill")
                                .foregroundStyle(Theme.textTertiary)
                            TextField("Enter your name", text: $userName)
                                .font(Theme.bodyFont)
                                .autocorrectionDisabled()
                        }
                        .padding()
                        .background(Theme.backgroundSecondary)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }

                    // Task selection - clean and simple
                    VStack(alignment: .leading, spacing: Theme.spacingS) {
                        Text("What are you working on?").font(Theme.headlineFont)

                        // Show tasks if available
                        if !tasks.isEmpty {
                            ForEach(tasks.prefix(4)) { task in
                                Button {
                                    selectedTask = task
                                    taskTitle = task.title
                                } label: {
                                    HStack(spacing: 12) {
                                        Image(systemName: selectedTask?.id == task.id ? "checkmark.circle.fill" : "circle")
                                            .font(.system(size: 22))
                                            .foregroundStyle(selectedTask?.id == task.id ? Theme.focusColor : Theme.textTertiary)

                                        Text(task.title)
                                            .font(Theme.bodyFont)
                                            .foregroundStyle(Theme.textPrimary)
                                            .lineLimit(1)

                                        Spacer()
                                    }
                                    .padding()
                                    .background(
                                        RoundedRectangle(cornerRadius: 12)
                                            .fill(selectedTask?.id == task.id ? Theme.focusColor.opacity(0.1) : Theme.backgroundSecondary)
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .strokeBorder(selectedTask?.id == task.id ? Theme.focusColor.opacity(0.4) : Color.clear, lineWidth: 1.5)
                                    )
                                }
                                .buttonStyle(.plain)
                            }

                            // Show "type different" option when task is selected
                            if selectedTask != nil {
                                Button {
                                    selectedTask = nil
                                    taskTitle = ""
                                } label: {
                                    HStack {
                                        Image(systemName: "pencil")
                                            .font(.system(size: 14))
                                        Text("Type a different task")
                                            .font(Theme.captionFont)
                                    }
                                    .foregroundStyle(Theme.focusColor)
                                    .padding(.top, 8)
                                }
                            }

                            // Only show text input option when no task selected
                            if selectedTask == nil {
                                // Or type custom divider
                                HStack {
                                    Rectangle()
                                        .fill(Theme.textTertiary.opacity(0.3))
                                        .frame(height: 1)
                                    Text("or type your own")
                                        .font(Theme.captionFont)
                                        .foregroundStyle(Theme.textSecondary)
                                    Rectangle()
                                        .fill(Theme.textTertiary.opacity(0.3))
                                        .frame(height: 1)
                                }
                                .padding(.vertical, 8)

                                // Text input
                                HStack(spacing: 12) {
                                    Image(systemName: "pencil")
                                        .foregroundStyle(Theme.textTertiary)
                                    TextField("Type a task...", text: $taskTitle)
                                        .font(Theme.bodyFont)
                                }
                                .padding()
                                .background(Theme.backgroundSecondary)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .strokeBorder(!taskTitle.isEmpty ? Theme.focusColor.opacity(0.4) : Color.clear, lineWidth: 1.5)
                                )
                            }
                        } else {
                            // No tasks - show text input directly
                            HStack(spacing: 12) {
                                Image(systemName: "pencil")
                                    .foregroundStyle(Theme.textTertiary)
                                TextField("Type a task...", text: $taskTitle)
                                    .font(Theme.bodyFont)
                            }
                            .padding()
                            .background(Theme.backgroundSecondary)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .strokeBorder(!taskTitle.isEmpty ? Theme.focusColor.opacity(0.4) : Color.clear, lineWidth: 1.5)
                            )
                        }
                    }

                    // Duration picker
                    VStack(alignment: .leading, spacing: Theme.spacingS) {
                        HStack {
                            Image(systemName: "clock.fill")
                                .foregroundStyle(Theme.focusColor)
                            Text("Focus Duration").font(Theme.headlineFont)
                        }
                        Picker("Duration", selection: $duration) {
                            Text("1 min").tag(1)
                            Text("15 min").tag(15)
                            Text("25 min").tag(25)
                            Text("45 min").tag(45)
                        }
                        .pickerStyle(.segmented)
                    }
                    .opacity(isFormValid ? 1.0 : 0.6)

                    if let error = errorMessage {
                        Text(error)
                            .font(Theme.captionFont)
                            .foregroundStyle(.red)
                            .multilineTextAlignment(.center)
                    }

                    // Create button
                    Button {
                        UserDefaults.standard.set(userName, forKey: "userName")
                        Task {
                            do {
                                _ = try await sessionService.createSession(taskTitle: taskTitle, duration: duration * 60, userName: userName)
                                isPresented = false
                                onCreated()
                            } catch {
                                errorMessage = error.localizedDescription
                            }
                        }
                    } label: {
                        Text("Create & Get Code")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(isFormValid ? Theme.focusGradient : LinearGradient(colors: [Color.gray.opacity(0.4), Color.gray.opacity(0.3)], startPoint: .leading, endPoint: .trailing))
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                    .disabled(!isFormValid)
                    .padding(.top, Theme.spacingS)
                }
                .padding(Theme.spacingM)
                .frame(maxWidth: 500)  // iPad: constrain content width
                .frame(maxWidth: .infinity)  // Center on larger screens
            }
            .navigationTitle("Create Session")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { isPresented = false }
                }
            }
        }
    }
}
