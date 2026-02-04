import SwiftUI
import SwiftData

@MainActor
public struct HomeView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(TimerService.self) private var timerService
    @Query(sort: \FocusTask.createdAt, order: .reverse) private var allTasks: [FocusTask]

    @State private var selectedTab: TaskTab = .todo
    @State private var showAddTask = false
    @State private var showRenameTask = false
    @State private var showBuddySession = false
    @State private var taskToRename: FocusTask?
    @State private var newTaskTitle = ""
    @State private var renameText = ""

    public init() {}

    private var todoTasks: [FocusTask] { allTasks.filter { !$0.isCompleted } }
    private var doneTasks: [FocusTask] { allTasks.filter { $0.isCompleted } }
    private var currentTasks: [FocusTask] { selectedTab == .todo ? todoTasks : doneTasks }

    public var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                SegmentedTabView(selection: $selectedTab).padding(.horizontal, Theme.spacingM).padding(.vertical, Theme.spacingS)
                if currentTasks.isEmpty {
                    Spacer()
                    EmptyStateView(icon: selectedTab == .todo ? "checklist" : "checkmark.circle", title: selectedTab == .todo ? "No Tasks Yet" : "No Completed Tasks", message: selectedTab == .todo ? "Add your first task to get started with focused work sessions." : "Complete some tasks to see them here.", actionTitle: selectedTab == .todo ? "Add Task" : nil, action: selectedTab == .todo ? { showAddTask = true } : nil)
                    Spacer()
                } else {
                    ScrollView {
                        LazyVStack(spacing: Theme.spacingS) {
                            ForEach(currentTasks) { task in
                                TaskCardView(
                                    task: task,
                                    isSelected: timerService.selectedTask?.id == task.id,
                                    onTap: { selectTask(task) },
                                    onComplete: { toggleTaskCompletion(task) },
                                    onDelete: { deleteTask(task) },
                                    onRename: { startRenaming(task) },
                                    onStart: { startTaskTimer(task) }
                                )
                            }
                        }
                        .padding(Theme.spacingM)
                    }
                }
            }
            .background(Theme.backgroundPrimary)
            .navigationTitle("Tasks")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    HStack(spacing: Theme.spacingS) {
                        Button { showBuddySession = true } label: { Image(systemName: "person.2.fill").font(.title2).foregroundStyle(Theme.focusColor) }
                        Button { showAddTask = true } label: { Image(systemName: "plus.circle.fill").font(.title2).foregroundStyle(Theme.focusColor) }
                    }
                }
            }
            .sheet(isPresented: $showBuddySession) { BuddySessionView() }
            .alert("Add Task", isPresented: $showAddTask) {
                TextField("Task title", text: $newTaskTitle)
                Button("Cancel", role: .cancel) { newTaskTitle = "" }
                Button("Add") { addTask() }.disabled(newTaskTitle.trimmingCharacters(in: .whitespaces).isEmpty)
            } message: { Text("Enter a title for your new task") }
            .alert("Rename Task", isPresented: $showRenameTask) {
                TextField("Task title", text: $renameText)
                Button("Cancel", role: .cancel) { renameText = ""; taskToRename = nil }
                Button("Rename") { renameTask() }.disabled(renameText.trimmingCharacters(in: .whitespaces).isEmpty)
            } message: { Text("Enter a new title for the task") }
        }
    }

    private func addTask() {
        let trimmedTitle = newTaskTitle.trimmingCharacters(in: .whitespaces)
        guard !trimmedTitle.isEmpty else { return }
        modelContext.insert(FocusTask(title: trimmedTitle))
        newTaskTitle = ""
    }

    private func selectTask(_ task: FocusTask) {
        if !task.isCompleted { timerService.selectedTask = timerService.selectedTask?.id == task.id ? nil : task }
    }

    private func toggleTaskCompletion(_ task: FocusTask) {
        if task.isCompleted { task.markIncomplete() } else { task.markCompleted(); if timerService.selectedTask?.id == task.id { timerService.selectedTask = nil } }
    }

    private func deleteTask(_ task: FocusTask) {
        if timerService.selectedTask?.id == task.id { timerService.selectedTask = nil }
        modelContext.delete(task)
    }

    private func startRenaming(_ task: FocusTask) { taskToRename = task; renameText = task.title; showRenameTask = true }

    private func renameTask() {
        guard let task = taskToRename else { return }
        let trimmedTitle = renameText.trimmingCharacters(in: .whitespaces)
        guard !trimmedTitle.isEmpty else { return }
        task.title = trimmedTitle; renameText = ""; taskToRename = nil
    }

    private func startTaskTimer(_ task: FocusTask) {
        timerService.selectedTask = task
        // Post notification to switch to Timer tab
        NotificationCenter.default.post(name: .switchToTimerTab, object: nil)
    }
}

// Notification for tab switching
public extension Notification.Name {
    static let switchToTimerTab = Notification.Name("switchToTimerTab")
}
