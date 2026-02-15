import SwiftUI
import SwiftData

@MainActor
public struct HomeView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(TimerService.self) private var timerService
    @Environment(SoundService.self) private var soundService
    @Environment(UserSettings.self) private var settings
    @Query(sort: \FocusTask.createdAt, order: .reverse) private var allTasks: [FocusTask]

    @State private var showAddTask = false
    @State private var showRenameTask = false
    @State private var taskToRename: FocusTask?
    @State private var newTaskTitle = ""
    @State private var renameText = ""

    // Start prompt (predict vs start)
    @State private var showStartPrompt = false
    @State private var pendingTask: FocusTask?

    public init() {}

    private var todoTasks: [FocusTask] { allTasks.filter { !$0.isCompleted } }
    private var doneTasks: [FocusTask] { allTasks.filter { $0.isCompleted } }

    public var body: some View {
        NavigationStack {
            List {
                // MARK: - Summary Section
                Section {
                    summaryCard
                }
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)

                // MARK: - To Do Section
                if !todoTasks.isEmpty {
                    Section {
                        ForEach(todoTasks) { task in
                            TaskRow(
                                task: task,
                                isSelected: timerService.selectedTask?.id == task.id,
                                onTap: { selectTask(task) },
                                onComplete: { toggleTaskCompletion(task) },
                                onStart: { startTaskTimer(task) }
                            )
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button(role: .destructive) {
                                    deleteTask(task)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                            .swipeActions(edge: .leading) {
                                Button {
                                    toggleTaskCompletion(task)
                                } label: {
                                    Label("Done", systemImage: "checkmark")
                                }
                                .tint(.green)
                            }
                            .contextMenu {
                                Button { startRenaming(task) } label: {
                                    Label("Rename", systemImage: "pencil")
                                }
                                Button { startTaskTimer(task) } label: {
                                    Label("Start Focus", systemImage: "play.fill")
                                }
                                Button(role: .destructive) { deleteTask(task) } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                        }
                    } header: {
                        Text("To Do")
                    }
                }

                // MARK: - Completed Section
                if !doneTasks.isEmpty {
                    Section {
                        ForEach(doneTasks) { task in
                            CompletedTaskRow(task: task)
                                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                    Button(role: .destructive) {
                                        deleteTask(task)
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                                .swipeActions(edge: .leading) {
                                    Button {
                                        toggleTaskCompletion(task)
                                    } label: {
                                        Label("Undo", systemImage: "arrow.uturn.backward")
                                    }
                                    .tint(.orange)
                                }
                        }
                    } header: {
                        Text("Completed")
                    }
                }

                // MARK: - Empty State
                if todoTasks.isEmpty && doneTasks.isEmpty {
                    Section {
                        VStack(spacing: 12) {
                            Image(systemName: "leaf.fill")
                                .font(.system(size: 40))
                                .foregroundStyle(.green.opacity(0.6))

                            Text("Ready to focus")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 48)
                    }
                    .listRowBackground(Color.clear)
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Today")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button { showAddTask = true } label: {
                        Image(systemName: "plus")
                            .fontWeight(.semibold)
                    }
                }
            }
            .alert("Add Task", isPresented: $showAddTask) {
                TextField("Task title", text: $newTaskTitle)
                Button("Cancel", role: .cancel) { newTaskTitle = "" }
                Button("Add") { addTask() }.disabled(newTaskTitle.trimmingCharacters(in: .whitespaces).isEmpty)
            } message: {
                Text("What do you want to focus on?")
            }
            .alert("Rename Task", isPresented: $showRenameTask) {
                TextField("Task title", text: $renameText)
                Button("Cancel", role: .cancel) { renameText = ""; taskToRename = nil }
                Button("Rename") { renameTask() }.disabled(renameText.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .sheet(isPresented: $showStartPrompt) {
                StartPromptSheet(
                    onPredict: { confirmStart(withPrediction: true) },
                    onStart: { confirmStart(withPrediction: false) }
                )
                .presentationDetents([.height(140)])
                .presentationDragIndicator(.visible)
            }
        }
    }

    // MARK: - Summary Card

    private var summaryCard: some View {
        VStack(spacing: 16) {
            // Plan sessions button - navigates to Timer tab with session planner
            Button {
                NotificationCenter.default.post(name: .switchToTimerTab, object: nil)
                NotificationCenter.default.post(name: .showSessionPlanner, object: nil)
            } label: {
                HStack {
                    Image(systemName: "square.stack.3d.up.fill")
                        .font(.system(size: 16))
                    Text("Plan Sessions")
                        .font(.system(size: 15, weight: .medium))
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.tertiary)
                }
                .foregroundStyle(.blue)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.blue.opacity(0.1))
                )
            }
            .buttonStyle(.plain)
        }
        .padding(16)
        .frame(maxWidth: 600)  // iPad: constrain content width
    }

    // MARK: - Actions

    private func addTask() {
        let trimmedTitle = newTaskTitle.trimmingCharacters(in: .whitespaces)
        guard !trimmedTitle.isEmpty else { return }
        modelContext.insert(FocusTask(title: trimmedTitle))
        try? modelContext.save()
        newTaskTitle = ""
    }

    private func selectTask(_ task: FocusTask) {
        if !task.isCompleted {
            timerService.selectedTask = timerService.selectedTask?.id == task.id ? nil : task
        }
    }

    private func toggleTaskCompletion(_ task: FocusTask) {
        if task.isCompleted {
            task.markIncomplete()
        } else {
            task.markCompleted()
            if timerService.selectedTask?.id == task.id {
                timerService.selectedTask = nil
            }
        }
    }

    private func deleteTask(_ task: FocusTask) {
        if timerService.selectedTask?.id == task.id {
            timerService.selectedTask = nil
        }
        modelContext.delete(task)
    }

    private func startRenaming(_ task: FocusTask) {
        taskToRename = task
        renameText = task.title
        showRenameTask = true
    }

    private func renameTask() {
        guard let task = taskToRename else { return }
        let trimmedTitle = renameText.trimmingCharacters(in: .whitespaces)
        guard !trimmedTitle.isEmpty else { return }
        task.title = trimmedTitle
        renameText = ""
        taskToRename = nil
    }

    private func startTaskTimer(_ task: FocusTask) {
        pendingTask = task
        showStartPrompt = true
    }

    private func confirmStart(withPrediction: Bool) {
        showStartPrompt = false

        if let task = pendingTask {
            // Select the task and navigate to Timer screen
            timerService.selectedTask = task
            NotificationCenter.default.post(name: .switchToTimerTab, object: nil)

            // If prediction requested, show energy prediction overlay after tab switch
            if withPrediction {
                NotificationCenter.default.post(name: .showEnergyPrediction, object: nil)
            }
        }

        pendingTask = nil
    }
}

// MARK: - Task Row

private struct TaskRow: View {
    let task: FocusTask
    let isSelected: Bool
    let onTap: () -> Void
    let onComplete: () -> Void
    let onStart: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Checkbox
                Button(action: onComplete) {
                    Image(systemName: "circle")
                        .font(.system(size: 22))
                        .foregroundStyle(.tertiary)
                }
                .buttonStyle(.plain)

                // Task info
                VStack(alignment: .leading, spacing: 2) {
                    Text(task.title)
                        .font(.body)
                        .foregroundStyle(.primary)

                    if task.totalFocusTime > 0 {
                        Text(task.formattedFocusTime)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                // Selected indicator
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.blue)
                }

                // Play button
                Button(action: onStart) {
                    Image(systemName: "play.circle.fill")
                        .font(.system(size: 28))
                        .foregroundStyle(.blue)
                }
                .buttonStyle(.plain)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Completed Task Row

private struct CompletedTaskRow: View {
    let task: FocusTask

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 22))
                .foregroundStyle(.green)

            VStack(alignment: .leading, spacing: 2) {
                Text(task.title)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .strikethrough()

                if task.totalFocusTime > 0 {
                    Text(task.formattedFocusTime)
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }

            Spacer()
        }
    }
}


// MARK: - Start Prompt Sheet

private struct StartPromptSheet: View {
    let onPredict: () -> Void
    let onStart: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 20) {
            Text("Ready to focus?")
                .font(.headline)
                .padding(.top, 8)

            HStack(spacing: 16) {
                // Predict button - matches start with gradient
                Button {
                    dismiss()
                    onPredict()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 14))
                        Text("Predict")
                            .font(.system(size: 15, weight: .semibold))
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        LinearGradient(
                            colors: [Theme.focusColor, Theme.pausedColor],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }

                // Start button
                Button {
                    dismiss()
                    onStart()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "play.fill")
                            .font(.system(size: 14))
                        Text("Start")
                            .font(.system(size: 15, weight: .semibold))
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Theme.focusColor)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
            .padding(.horizontal, 20)
        }
        .padding(.bottom, 16)
    }
}

// Notification for tab switching
public extension Notification.Name {
    static let switchToTimerTab = Notification.Name("switchToTimerTab")
    static let showSessionPlanner = Notification.Name("showSessionPlanner")
    static let startSessionPlan = Notification.Name("startSessionPlan")
    static let startSessionPlanWithPrediction = Notification.Name("startSessionPlanWithPrediction")
    static let autoStartTimer = Notification.Name("autoStartTimer")
    static let showEnergyPrediction = Notification.Name("showEnergyPrediction")
}
