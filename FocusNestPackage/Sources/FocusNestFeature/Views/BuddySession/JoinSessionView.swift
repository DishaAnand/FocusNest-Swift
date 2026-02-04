import SwiftUI
import SwiftData

@MainActor
public struct JoinSessionView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(SessionService.self) private var sessionService
    @Environment(SoundService.self) private var soundService
    @Query(filter: #Predicate<FocusTask> { !$0.isCompleted }, sort: \FocusTask.createdAt, order: .reverse) private var tasks: [FocusTask]

    let sessionId: String
    let onJoined: () -> Void

    @State private var userName = UserDefaults.standard.string(forKey: "userName") ?? ""
    @State private var selectedTask: FocusTask?
    @State private var customTaskTitle = ""
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
                    VStack(spacing: Theme.spacingS) {
                        Image(systemName: "person.2.fill").font(.system(size: 48)).foregroundStyle(Theme.focusColor)
                        Text("Join Buddy Session").font(Theme.titleFont)
                        Text("Someone invited you to focus together!").font(Theme.bodyFont).foregroundStyle(Theme.textSecondary).multilineTextAlignment(.center)
                    }.padding(.top, Theme.spacingL)

                    VStack(alignment: .leading, spacing: Theme.spacingS) {
                        Text("Your Name").font(Theme.headlineFont)
                        TextField("Enter your name", text: $userName).textFieldStyle(.roundedBorder).autocorrectionDisabled()
                    }

                    VStack(alignment: .leading, spacing: Theme.spacingS) {
                        Text("What will you work on?").font(Theme.headlineFont)
                        TextField("Enter your task", text: $customTaskTitle).textFieldStyle(.roundedBorder)
                        if !tasks.isEmpty {
                            Text("Or select:").font(Theme.captionFont).foregroundStyle(Theme.textSecondary)
                            ForEach(tasks.prefix(3)) { task in
                                TaskSelectionCardView(task: task, isSelected: selectedTask?.id == task.id) {
                                    selectedTask = task
                                    customTaskTitle = task.title
                                }
                            }
                        }
                    }

                    Button { Task { await joinSession() } } label: {
                        if isLoading {
                            ProgressView().progressViewStyle(.circular).tint(.white).frame(maxWidth: .infinity).padding(.vertical, Theme.spacingM).background(Theme.focusGradient).clipShape(RoundedRectangle(cornerRadius: Theme.cornerRadiusM))
                        } else {
                            Text("Join Session").primaryButtonStyle()
                        }
                    }
                    .disabled(userName.isEmpty || customTaskTitle.isEmpty || isLoading)
                    .padding(.top, Theme.spacingM)

                    if let error = errorMessage {
                        Text(error).font(Theme.captionFont).foregroundStyle(Theme.errorColor).multilineTextAlignment(.center)
                    }
                }.padding(Theme.spacingM)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } } }
        }
    }

    private func joinSession() async {
        UserDefaults.standard.set(userName, forKey: "userName")
        isLoading = true
        errorMessage = nil

        do {
            _ = try await sessionService.joinSession(sessionId: sessionId, taskTitle: customTaskTitle, userName: userName)
            soundService.successHaptic()
            dismiss()
            onJoined()
        } catch {
            errorMessage = error.localizedDescription
            soundService.errorHaptic()
        }

        isLoading = false
    }
}
