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
    @State private var buddyRating = 0
    @State private var errorMessage: String?
    @State private var showJoinWithCode = false
    @State private var joinCode = ""

    // Distraction detection - only counted when user RETURNS after 15+ seconds
    @State private var wentAwayAt: Date?
    @State private var wasScreenLocked = false
    private let distractionThreshold: TimeInterval = 15  // seconds

    public init() {}

    public var body: some View {
        NavigationStack {
            Group {
                switch currentStep {
                case .setup: setupView
                case .waiting: waitingView
                case .active: activeSessionView
                case .rating: ratingView
                case .completed: completedView
                }
            }
            .navigationTitle(navigationTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { if currentStep != .completed { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { Task { await cancelSession() } } } } }
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
                    case .completed: currentStep = .rating
                    default: break
                    }
                }
            }
        }
    }

    private var navigationTitle: String {
        let isCreator = sessionService.currentSession?.creatorId == sessionService.deviceId
        switch currentStep {
        case .setup: return "Start Buddy Session"
        case .waiting: return isCreator ? "Waiting for Buddy" : "Ready to Focus"
        case .active: return "Focus Together"
        case .rating: return "Rate Your Buddy"
        case .completed: return "Session Complete"
        }
    }

    private var setupView: some View {
        ScrollView {
            VStack(spacing: Theme.spacingL) {
                VStack(alignment: .leading, spacing: Theme.spacingS) { Text("Your Name").font(Theme.headlineFont); TextField("Enter your name", text: $userName).textFieldStyle(.roundedBorder).autocorrectionDisabled() }
                VStack(alignment: .leading, spacing: Theme.spacingS) {
                    Text("What are you working on?").font(Theme.headlineFont); TextField("Enter task", text: $customTaskTitle).textFieldStyle(.roundedBorder)
                    if !tasks.isEmpty { Text("Or select:").font(Theme.captionFont).foregroundStyle(Theme.textSecondary); ForEach(tasks.prefix(5)) { task in TaskSelectionCardView(task: task, isSelected: selectedTask?.id == task.id) { selectedTask = task; customTaskTitle = task.title } } }
                }
                VStack(alignment: .leading, spacing: Theme.spacingS) { Text("Duration").font(Theme.headlineFont); Picker("Duration", selection: $sessionDuration) { Text("1 min").tag(1); Text("15 min").tag(15); Text("25 min").tag(25); Text("45 min").tag(45) }.pickerStyle(.segmented) }
                Button { Task { await createSession() } } label: { Text("Create Session").primaryButtonStyle() }.disabled(userName.isEmpty || customTaskTitle.isEmpty).padding(.top, Theme.spacingM)

                // Divider with "or"
                HStack {
                    Rectangle().fill(Theme.textSecondary.opacity(0.3)).frame(height: 1)
                    Text("or").font(Theme.captionFont).foregroundStyle(Theme.textSecondary)
                    Rectangle().fill(Theme.textSecondary.opacity(0.3)).frame(height: 1)
                }.padding(.vertical, Theme.spacingS)

                // Join with code button
                Button { showJoinWithCode = true } label: { Label("Join with Code", systemImage: "person.badge.plus").secondaryButtonStyle() }
            }.padding(Theme.spacingM)
        }
        .sheet(isPresented: $showJoinWithCode) {
            JoinWithCodeSheet(userName: $userName, taskTitle: $customTaskTitle, isPresented: $showJoinWithCode) {
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
            if let session = sessionService.currentSession { ActiveSessionTimerView(session: session) { Task { await completeSession() } } }
        }.padding(Theme.spacingM)
    }

    private var ratingView: some View {
        VStack(spacing: Theme.spacingXL) {
            Spacer()
            Image(systemName: "star.fill").font(.system(size: 64)).foregroundStyle(.yellow)
            Text("How focused was your buddy?").font(Theme.titleFont).multilineTextAlignment(.center)
            StarRatingView(rating: $buddyRating, size: 48)
            Button { Task { await submitRating() } } label: { Text("Submit Rating").primaryButtonStyle() }.disabled(buddyRating == 0)
            Spacer()
        }.padding(Theme.spacingM)
    }

    private var completedView: some View {
        VStack(spacing: Theme.spacingXL) {
            Spacer()
            Image(systemName: "hands.clap.fill").font(.system(size: 80)).foregroundStyle(Theme.focusColor)
            Text("Session Complete!").font(Theme.titleFont)
            Text("Great work focusing together!").font(Theme.bodyFont).foregroundStyle(Theme.textSecondary)
            Button { finishSession() } label: { Text("Done").primaryButtonStyle() }
            Spacer()
        }.padding(Theme.spacingM)
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
            currentStep = .rating
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func submitRating() async {
        if let session = sessionService.currentSession, let buddy = session.otherParticipants(exceptId: sessionService.deviceId).first {
            try? await sessionService.rateBuddy(buddyId: buddy.odid, rating: buddyRating)
        }
        if let session = sessionService.currentSession {
            modelContext.insert(FocusRecord(duration: session.duration, isBreak: false, taskTitle: customTaskTitle, wasCompleted: true, wasBuddySession: true))
        }
        currentStep = .completed
        soundService.successHaptic(settings: settings)
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
        case .completed: if currentStep == .active { currentStep = .rating }
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
        buddyRating = 0
    }
}

enum BuddySessionStep { case setup, waiting, active, rating, completed }

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
                    // Always show green - we track distractions via the badge only
                    Circle()
                        .fill(Color.green)
                        .frame(width: 12, height: 12)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(buddy.name).font(Theme.headlineFont)
                        Text(buddy.taskTitle).font(Theme.captionFont).foregroundStyle(Theme.textSecondary)

                        // Show buddy's remaining time if different
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

                    // Distraction count badge
                    if buddy.violationCount > 0 {
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
private struct JoinWithCodeSheet: View {
    @Environment(SessionService.self) private var sessionService
    @Binding var userName: String
    @Binding var taskTitle: String
    @Binding var isPresented: Bool
    let onJoined: () -> Void

    @State private var code = ""
    @State private var sessionDuration = 25
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Theme.spacingL) {
                    Image(systemName: "person.badge.plus")
                        .font(.system(size: 60))
                        .foregroundStyle(Theme.focusColor)
                        .padding(.top, Theme.spacingL)

                    Text("Enter Session Code")
                        .font(Theme.titleFont)

                    Text("Ask your buddy for their session code")
                        .font(Theme.bodyFont)
                        .foregroundStyle(Theme.textSecondary)

                    TextField("Enter code", text: $code)
                        .font(.system(size: 24, weight: .medium, design: .monospaced))
                        .multilineTextAlignment(.center)
                        .textFieldStyle(.roundedBorder)
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                        .frame(maxWidth: 200)

                    VStack(alignment: .leading, spacing: Theme.spacingS) {
                        Text("Your Focus Duration").font(Theme.headlineFont)
                        Text("Pick your own time - can differ from buddy").font(Theme.captionFont).foregroundStyle(Theme.textSecondary)
                        Picker("Duration", selection: $sessionDuration) {
                            Text("1 min").tag(1)
                            Text("15 min").tag(15)
                            Text("25 min").tag(25)
                            Text("45 min").tag(45)
                        }.pickerStyle(.segmented)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    if let error = errorMessage {
                        Text(error)
                            .font(Theme.captionFont)
                            .foregroundStyle(.red)
                            .multilineTextAlignment(.center)
                    }

                    Button {
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
                    .disabled(code.count < 6 || isLoading || userName.isEmpty || taskTitle.isEmpty)
                    .frame(maxWidth: 280)

                    if userName.isEmpty || taskTitle.isEmpty {
                        Text("Please fill in your name and task first")
                            .font(Theme.captionFont)
                            .foregroundStyle(.orange)
                    }
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
