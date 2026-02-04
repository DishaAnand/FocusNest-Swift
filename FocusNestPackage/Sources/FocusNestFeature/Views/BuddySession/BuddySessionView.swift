import SwiftUI
import SwiftData

@MainActor
public struct BuddySessionView: View {
    @Environment(\.modelContext) private var modelContext
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
        }
    }

    private var navigationTitle: String {
        switch currentStep {
        case .setup: return "Start Buddy Session"
        case .waiting: return "Waiting for Buddy"
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
                VStack(alignment: .leading, spacing: Theme.spacingS) { Text("Duration").font(Theme.headlineFont); Picker("Duration", selection: $sessionDuration) { Text("15 min").tag(15); Text("25 min").tag(25); Text("45 min").tag(45); Text("60 min").tag(60) }.pickerStyle(.segmented) }
                Button { Task { await createSession() } } label: { Text("Create Session").primaryButtonStyle() }.disabled(userName.isEmpty || customTaskTitle.isEmpty).padding(.top, Theme.spacingM)
            }.padding(Theme.spacingM)
        }
    }

    private var waitingView: some View {
        VStack(spacing: Theme.spacingXL) {
            Spacer()
            PulsingIndicatorView()
            Text("Waiting for your buddy to join...").font(Theme.headlineFont).foregroundStyle(Theme.textSecondary)
            if let session = sessionService.currentSession {
                VStack(spacing: Theme.spacingM) {
                    Text("Share this link:").font(Theme.captionFont).foregroundStyle(Theme.textSecondary)
                    Text(session.shareLink).font(.system(.body, design: .monospaced)).padding(Theme.spacingM).background(Theme.backgroundSecondary).clipShape(RoundedRectangle(cornerRadius: Theme.cornerRadiusS))
                    Button { UIPasteboard.general.string = session.shareLink; soundService.lightImpact(settings: settings) } label: { Label("Copy Link", systemImage: "doc.on.doc").secondaryButtonStyle() }.frame(maxWidth: 200)
                }
                if session.creatorId == sessionService.deviceId && session.isReadyToStart { Button { Task { await startSession() } } label: { Text("Start Session").primaryButtonStyle() }.padding(.top, Theme.spacingM) }
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
    }

    private func finishSession() {
        sessionService.cleanup()
        resetState()
    }

    private func handleSessionStateChange(_ newState: SessionState?) {
        guard let state = newState else { return }
        switch state {
        case .active: if currentStep == .waiting { currentStep = .active }
        case .completed: if currentStep == .active { currentStep = .rating }
        case .cancelled: errorMessage = "Session was cancelled"; resetState()
        default: break
        }
    }

    private func resetState() {
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
    let session: BuddySession
    let onComplete: () -> Void
    @State private var remainingTime: Int
    @State private var timer: Timer?

    init(session: BuddySession, onComplete: @escaping () -> Void) {
        self.session = session
        self.onComplete = onComplete
        self._remainingTime = State(initialValue: session.remainingTime(currentTime: Date().timeIntervalSince1970))
    }

    var body: some View {
        VStack(spacing: Theme.spacingM) {
            CircularProgressView(progress: 1.0 - Double(remainingTime) / Double(session.duration), size: 200, color: Theme.focusColor)
            Text(String(format: "%02d:%02d", remainingTime / 60, remainingTime % 60)).font(Theme.timerFontSmall).monospacedDigit()
        }
        .onAppear {
            timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
                if remainingTime > 0 { remainingTime -= 1 }
                else { timer?.invalidate(); onComplete() }
            }
        }
        .onDisappear { timer?.invalidate() }
    }
}
