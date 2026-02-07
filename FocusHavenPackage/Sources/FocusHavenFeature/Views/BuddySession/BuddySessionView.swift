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
    @Query(filter: #Predicate<FocusTask> { !$0.isCompleted }, sort: \FocusTask.createdAt, order: .reverse) private var tasks: [FocusTask]

    @State private var currentStep: BuddySessionStep = .setup
    @State private var selectedTask: FocusTask?
    @State private var customTaskTitle = ""
    @State private var sessionDuration = 25
    @State private var userName = UserDefaults.standard.string(forKey: "userName") ?? ""
    @State private var errorMessage: String?
    @State private var showJoinWithCode = false
    @State private var showCreateSession = false
    @State private var joinCode = ""

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
                        showCreateSession = true
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
                        showJoinWithCode = true
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
        }
        .sheet(isPresented: $showCreateSession) {
            CreateSessionSheet(
                userName: $userName,
                taskTitle: $customTaskTitle,
                duration: $sessionDuration,
                tasks: tasks,
                isPresented: $showCreateSession
            ) {
                Task { await createSession() }
            }
        }
        .sheet(isPresented: $showJoinWithCode) {
            JoinWithCodeSheet(userName: $userName, taskTitle: $customTaskTitle, isPresented: $showJoinWithCode, tasks: tasks) {
                currentStep = .waiting
            }
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
        }.padding(Theme.spacingM)
    }

    private var activeSessionView: some View {
        VStack(spacing: Theme.spacingL) {
            if let session = sessionService.currentSession {
                ActiveSessionTimerView(session: session) {
                    // My timer completed - show celebration
                    currentStep = .celebrating
                }
            }
        }.padding(Theme.spacingM)
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
                            currentStep = .supportMode
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
    }

    private var summaryView: some View {
        Group {
            if let session = sessionService.currentSession {
                let me = session.participant(withId: sessionService.deviceId)
                let buddy = session.otherParticipants(exceptId: sessionService.deviceId).first

                SessionSummaryView(
                    myName: me?.name ?? userName,
                    buddyName: buddy?.name ?? "Buddy",
                    myDuration: me?.duration ?? session.duration,
                    buddyDuration: buddy?.duration ?? session.duration,
                    myDistractions: me?.violationCount ?? 0,
                    buddyDistractions: buddy?.violationCount ?? 0,
                    onDone: {
                        // Save focus record
                        modelContext.insert(FocusRecord(
                            duration: me?.duration ?? session.duration,
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
    }
}

enum BuddySessionStep { case setup, waiting, active, celebrating, postCompletion, supportMode, summary }

@MainActor
private struct ActiveSessionTimerView: View {
    @Environment(SessionService.self) private var sessionService
    let session: BuddySession
    let onComplete: () -> Void
    @State private var remainingTime: Int = 0
    @State private var timer: Timer?

    private var myDuration: Int {
        session.participant(withId: sessionService.deviceId)?.duration ?? session.duration
    }

    private var buddy: SessionParticipant? {
        session.otherParticipants(exceptId: sessionService.deviceId).first
    }

    private var buddyRemainingTime: Int {
        guard let buddy = buddy else { return 0 }
        return session.remainingTimeForParticipant(buddy.odid, currentTime: sessionService.serverTime)
    }

    var body: some View {
        VStack(spacing: Theme.spacingM) {
            // Your timer
            CircularProgressView(progress: 1.0 - Double(remainingTime) / Double(myDuration), size: 200, color: Theme.focusColor)
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
            }
        }
        .onAppear {
            // Use participant's own duration
            remainingTime = session.remainingTimeForParticipant(sessionService.deviceId, currentTime: sessionService.serverTime)
            timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [sessionService] _ in
                Task { @MainActor in
                    let remaining = session.remainingTimeForParticipant(sessionService.deviceId, currentTime: sessionService.serverTime)
                    if remaining > 0 { remainingTime = remaining }
                    else { timer?.invalidate(); onComplete() }
                }
            }
        }
        .onDisappear { timer?.invalidate() }
    }
}

@MainActor
private struct SupportModeTimerView: View {
    @Environment(SessionService.self) private var sessionService
    let session: BuddySession
    let onBuddyComplete: () -> Void
    @State private var buddyRemainingTime: Int = 0
    @State private var timer: Timer?

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
                    progress: 1.0 - Double(buddyRemainingTime) / Double(buddy.duration),
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
            buddyRemainingTime = session.remainingTimeForParticipant(buddy.odid, currentTime: sessionService.serverTime)
            timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [sessionService] _ in
                Task { @MainActor in
                    guard let buddy = session.otherParticipants(exceptId: sessionService.deviceId).first else { return }
                    let remaining = session.remainingTimeForParticipant(buddy.odid, currentTime: sessionService.serverTime)
                    if remaining > 0 {
                        buddyRemainingTime = remaining
                    } else {
                        timer?.invalidate()
                        onBuddyComplete()
                    }
                }
            }
        }
        .onDisappear { timer?.invalidate() }
    }
}

@MainActor
private struct JoinWithCodeSheet: View {
    @Environment(SessionService.self) private var sessionService
    @Binding var userName: String
    @Binding var taskTitle: String
    @Binding var isPresented: Bool
    let tasks: [FocusTask]
    let onJoined: () -> Void

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
private struct CreateSessionSheet: View {
    @Environment(SessionService.self) private var sessionService
    @Environment(SoundService.self) private var soundService
    @Environment(UserSettings.self) private var settings
    @Binding var userName: String
    @Binding var taskTitle: String
    @Binding var duration: Int
    let tasks: [FocusTask]
    @Binding var isPresented: Bool
    let onCreate: () -> Void

    @State private var selectedTask: FocusTask?
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Theme.spacingL) {
                    // Header
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 60))
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

                    if let error = errorMessage {
                        Text(error)
                            .font(Theme.captionFont)
                            .foregroundStyle(.red)
                            .multilineTextAlignment(.center)
                    }

                    // Create button
                    Button {
                        UserDefaults.standard.set(userName, forKey: "userName")
                        isPresented = false
                        onCreate()
                    } label: {
                        Text("Create & Get Code").primaryButtonStyle()
                    }
                    .disabled(userName.isEmpty || taskTitle.isEmpty)
                    .padding(.top, Theme.spacingS)
                }
                .padding(Theme.spacingM)
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
