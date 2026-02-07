import SwiftUI
import SwiftData

@MainActor
public struct JoinSessionView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(SessionService.self) private var sessionService
    @Environment(SoundService.self) private var soundService
    @Environment(UserSettings.self) private var settings
    @Query(filter: #Predicate<FocusTask> { !$0.isCompleted }, sort: \FocusTask.createdAt, order: .reverse) private var tasks: [FocusTask]

    let sessionId: String
    let onJoined: () -> Void

    @State private var userName = UserDefaults.standard.string(forKey: "userName") ?? ""
    @State private var selectedTask: FocusTask?
    @State private var customTaskTitle = ""
    @State private var sessionDuration = 25  // Independent duration
    @State private var isLoading = false
    @State private var errorMessage: String?

    public init(sessionId: String, onJoined: @escaping () -> Void) {
        self.sessionId = sessionId
        self.onJoined = onJoined
    }

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Theme.spacingL) {
                    headerSection
                    nameInputSection
                    taskInputSection
                    durationSection
                    errorSection
                    joinButtonSection
                }
                .padding(.horizontal, Theme.spacingM)
                .padding(.top, Theme.spacingM)
                .padding(.bottom, 60)
                .frame(maxWidth: 500)
                .frame(maxWidth: .infinity)
            }
            .scrollIndicators(.hidden)
            .background(Theme.backgroundPrimary)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }

    private var headerSection: some View {
        VStack(spacing: Theme.spacingS) {
            ZStack {
                Circle()
                    .fill(Theme.focusColor.opacity(0.15))
                    .frame(width: 88, height: 88)
                Image(systemName: "person.2.fill")
                    .font(.system(size: 40))
                    .foregroundStyle(Theme.focusColor)
            }
            Text("Join Buddy Session")
                .font(.system(size: 24, weight: .bold, design: .rounded))
            Text("Someone invited you to focus together!")
                .font(Theme.bodyFont)
                .foregroundStyle(Theme.textSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(.top, Theme.spacingM)
    }

    private var nameInputSection: some View {
        VStack(alignment: .leading, spacing: Theme.spacingS) {
            Label("Your Name", systemImage: "person.fill")
                .font(Theme.headlineFont)
            TextField("Enter your name", text: $userName)
                .textFieldStyle(.roundedBorder)
                .autocorrectionDisabled()
        }
        .padding(Theme.spacingM)
        .background(Theme.backgroundSecondary)
        .clipShape(RoundedRectangle(cornerRadius: Theme.cornerRadiusM))
    }

    private var taskInputSection: some View {
        VStack(alignment: .leading, spacing: Theme.spacingS) {
            Label("What will you work on?", systemImage: "target")
                .font(Theme.headlineFont)
            TextField("Enter your task", text: $customTaskTitle)
                .textFieldStyle(.roundedBorder)
            if !tasks.isEmpty {
                Text("Or select from recent:")
                    .font(Theme.captionFont)
                    .foregroundStyle(Theme.textSecondary)
                    .padding(.top, 4)
                ForEach(tasks.prefix(3)) { task in
                    TaskSelectionCardView(task: task, isSelected: selectedTask?.id == task.id) {
                        selectedTask = task
                        customTaskTitle = task.title
                    }
                }
            }
        }
        .padding(Theme.spacingM)
        .background(Theme.backgroundSecondary)
        .clipShape(RoundedRectangle(cornerRadius: Theme.cornerRadiusM))
    }

    private var durationSection: some View {
        VStack(alignment: .leading, spacing: Theme.spacingS) {
            Label("Your Focus Duration", systemImage: "clock.fill")
                .font(Theme.headlineFont)
            Text("You can pick a different time than your buddy")
                .font(Theme.captionFont)
                .foregroundStyle(Theme.textSecondary)
            Picker("Duration", selection: $sessionDuration) {
                Text("1 min").tag(1)
                Text("15 min").tag(15)
                Text("25 min").tag(25)
                Text("45 min").tag(45)
            }
            .pickerStyle(.segmented)
        }
        .padding(Theme.spacingM)
        .background(Theme.backgroundSecondary)
        .clipShape(RoundedRectangle(cornerRadius: Theme.cornerRadiusM))
    }

    @ViewBuilder
    private var errorSection: some View {
        if let error = errorMessage {
            Text(error)
                .font(Theme.captionFont)
                .foregroundStyle(Theme.errorColor)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
    }

    private var joinButtonSection: some View {
        Button { Task { await joinSession() } } label: {
            joinButtonLabel
        }
        .disabled(userName.isEmpty || customTaskTitle.isEmpty || isLoading)
        .padding(.top, Theme.spacingS)
    }

    @ViewBuilder
    private var joinButtonLabel: some View {
        if isLoading {
            ProgressView()
                .progressViewStyle(.circular)
                .tint(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, Theme.spacingM)
                .background(Theme.focusGradient)
                .clipShape(RoundedRectangle(cornerRadius: Theme.cornerRadiusM))
        } else {
            HStack(spacing: 8) {
                Image(systemName: "person.2.fill")
                Text("Join Session")
            }
            .font(.system(size: 17, weight: .semibold))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, Theme.spacingM)
            .background(joinButtonBackground)
            .clipShape(RoundedRectangle(cornerRadius: Theme.cornerRadiusM))
        }
    }

    @ViewBuilder
    private var joinButtonBackground: some View {
        if userName.isEmpty || customTaskTitle.isEmpty {
            Color.gray.opacity(0.5)
        } else {
            Theme.focusGradient
        }
    }

    private func joinSession() async {
        UserDefaults.standard.set(userName, forKey: "userName")
        isLoading = true
        errorMessage = nil

        do {
            _ = try await sessionService.joinSession(sessionId: sessionId, taskTitle: customTaskTitle, userName: userName, duration: sessionDuration * 60)
            soundService.successHaptic(settings: settings)
            dismiss()
            onJoined()
        } catch {
            errorMessage = error.localizedDescription
            soundService.errorHaptic(settings: settings)
        }

        isLoading = false
    }
}
