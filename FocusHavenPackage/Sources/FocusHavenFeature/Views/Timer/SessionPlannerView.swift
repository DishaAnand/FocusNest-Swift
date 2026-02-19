import SwiftUI
import SwiftData

// MARK: - Session Plan Model

/// Session plan with optional task assignments
struct SessionPlan: Equatable {
    var totalSessions: Int = 0
    var currentSession: Int = 0  // 0-indexed during execution
    var taskAssignments: [UUID?] = []  // Task ID for each session (nil = unassigned)

    var isActive: Bool { totalSessions > 0 && currentSession < totalSessions }
    var isLastSession: Bool { currentSession == totalSessions - 1 }
    var maxBreaks: Int { max(0, totalSessions - 1) }

    var displayCurrentSession: Int { currentSession + 1 }  // 1-indexed for display

    /// Whether any tasks are assigned to sessions
    var hasTaskAssignments: Bool {
        taskAssignments.contains { $0 != nil }
    }

    /// Get the task ID for the current session
    var currentTaskId: UUID? {
        guard currentSession < taskAssignments.count else { return nil }
        return taskAssignments[currentSession]
    }

    mutating func reset() {
        totalSessions = 0
        currentSession = 0
        taskAssignments = []
    }

    mutating func nextSession() {
        if currentSession < totalSessions - 1 {
            currentSession += 1
        }
    }

    mutating func setTaskCount(_ count: Int) {
        totalSessions = count
        currentSession = 0
        // Initialize task assignments array with nil values
        taskAssignments = Array(repeating: nil, count: count)
    }

    mutating func assignTask(_ taskId: UUID?, toSession sessionIndex: Int) {
        guard sessionIndex < taskAssignments.count else { return }
        taskAssignments[sessionIndex] = taskId
    }

    /// Get task breakdown: [taskId: sessionCount]
    func getTaskBreakdown() -> [(taskId: UUID, sessionCount: Int)] {
        var counts: [UUID: Int] = [:]
        for taskId in taskAssignments.compactMap({ $0 }) {
            counts[taskId, default: 0] += 1
        }
        return counts.map { (taskId: $0.key, sessionCount: $0.value) }
            .sorted { $0.sessionCount > $1.sessionCount }
    }
}

/// Simple button that triggers the planner sheet
@MainActor
struct SessionPlannerCard: View {
    @Binding var showSheet: Bool
    @Environment(SoundService.self) private var soundService
    @Environment(UserSettings.self) private var settings
    @Environment(SubscriptionService.self) private var subscriptionService
    @State private var showUpgradePrompt = false

    var body: some View {
        Button {
            soundService.lightImpact(settings: settings)
            if subscriptionService.canUseSessionPlanning {
                showSheet = true
            } else {
                showUpgradePrompt = true
            }
        } label: {
            HStack(spacing: 14) {
                // Icon with green background
                Image(systemName: "square.stack.3d.up.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 42, height: 42)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Theme.focusColor)
                    )

                VStack(alignment: .leading, spacing: 3) {
                    Text("Plan Focus Sessions")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Theme.textPrimary)

                    Text("Set your daily focus goal")
                        .font(.system(size: 13))
                        .foregroundStyle(Theme.textSecondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.tertiary)
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(
                        LinearGradient(
                            colors: [
                                Theme.focusColor.opacity(0.15),
                                Theme.pausedColor.opacity(0.12)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(
                                LinearGradient(
                                    colors: [Theme.focusColor.opacity(0.4), Theme.pausedColor.opacity(0.35)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1.5
                            )
                    )
            )
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 20)
        .sheet(isPresented: $showUpgradePrompt) {
            ZStack {
                Color.black.opacity(0.3).ignoresSafeArea()
                    .onTapGesture { showUpgradePrompt = false }
                UpgradePromptView.sessionPlanLimit()
            }
            .presentationBackground(.clear)
        }
    }
}

/// Native iOS sheet for session planning
@MainActor
struct SessionPlannerSheet: View {
    @Binding var plan: SessionPlan
    @Binding var isPresented: Bool
    let onStart: () -> Void
    var onStartWithPrediction: (() -> Void)? = nil

    @State private var selectedCount: Int = 2
    @State private var assignTasks: Bool = false
    @State private var taskTexts: [String] = ["", "", "", "", ""]  // Editable task names
    @State private var taskAssignments: [UUID?] = [nil, nil, nil, nil, nil]  // For existing tasks
    @Environment(SoundService.self) private var soundService
    @Environment(UserSettings.self) private var settings
    @Environment(SubscriptionService.self) private var subscriptionService
    @Environment(\.modelContext) private var modelContext
    @Query(filter: #Predicate<FocusTask> { !$0.isCompleted }, sort: \FocusTask.createdAt, order: .reverse) private var availableTasks: [FocusTask]

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                List {
                    // Session count section
                    Section {
                        VStack(alignment: .leading, spacing: 16) {
                            Text("How many sessions?")
                                .font(.system(size: 15, weight: .medium))
                                .foregroundStyle(Theme.textSecondary)

                            HStack(spacing: 10) {
                                ForEach(1...5, id: \.self) { count in
                                    SessionPill(
                                        count: count,
                                        isSelected: selectedCount == count
                                    ) {
                                        soundService.selectionChanged(settings: settings)
                                        withAnimation(.easeInOut(duration: 0.2)) {
                                            selectedCount = count
                                        }
                                    }
                                }
                            }
                        }
                        .listRowInsets(EdgeInsets(top: 16, leading: 16, bottom: 16, trailing: 16))
                    }

                    // Task assignment section
                    Section {
                        Toggle("Assign tasks", isOn: $assignTasks.animation(.easeInOut(duration: 0.2)))
                            .tint(Theme.focusColor)

                        if assignTasks {
                            ForEach(0..<selectedCount, id: \.self) { index in
                                EditableSessionTaskRow(
                                    sessionNumber: index + 1,
                                    taskText: $taskTexts[index],
                                    selectedTaskId: $taskAssignments[index],
                                    availableTasks: availableTasks
                                )
                            }
                        }
                    }
                }
                .listStyle(.insetGrouped)

                // Bottom action area - your green + orange gradient
                VStack(spacing: 12) {
                    Button {
                        startWithPrediction()
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "sparkles")
                                .font(.system(size: 15, weight: .medium))
                            Text("Predict & Start")
                        }
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 15)
                        .background(
                            LinearGradient(
                                colors: [Theme.focusColor, Theme.pausedColor],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }

                    Button {
                        startDirectly()
                    } label: {
                        Text("Start Without Prediction")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(Theme.textSecondary)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
                .background(Theme.backgroundPrimary)
                .frame(maxWidth: 500)  // iPad: constrain content width
                .frame(maxWidth: .infinity)  // Center on larger screens
            }
            .navigationTitle("Plan Sessions")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        isPresented = false
                    }
                }
            }
        }
    }

    private func createTasksAndAssign() {
        // Create new tasks for any typed text, assign existing task IDs
        for i in 0..<selectedCount {
            let text = taskTexts[i].trimmingCharacters(in: .whitespaces)
            if !text.isEmpty && taskAssignments[i] == nil {
                // Create new task
                let task = FocusTask(title: text)
                modelContext.insert(task)
                plan.assignTask(task.id, toSession: i)
            } else if let taskId = taskAssignments[i] {
                // Use existing task
                plan.assignTask(taskId, toSession: i)
            }
        }
    }

    private func startWithPrediction() {
        soundService.mediumImpact(settings: settings)
        subscriptionService.recordSessionPlanUsed()
        plan.setTaskCount(selectedCount)
        if assignTasks {
            createTasksAndAssign()
        }
        isPresented = false
        // Use callback to avoid NotificationCenter timing issues
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            onStartWithPrediction?()
        }
    }

    private func startDirectly() {
        soundService.mediumImpact(settings: settings)
        subscriptionService.recordSessionPlanUsed()
        plan.setTaskCount(selectedCount)
        if assignTasks {
            createTasksAndAssign()
        }
        isPresented = false
        // Use callback to avoid NotificationCenter timing issues
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            onStart()
        }
    }
}

// MARK: - Session Pill

private struct SessionPill: View {
    let count: Int
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            Text("\(count)")
                .font(.system(size: 17, weight: .semibold, design: .rounded))
                .foregroundStyle(isSelected ? .white : Theme.textPrimary)
                .frame(width: 50, height: 44)
                .background(
                    isSelected
                        ? AnyShapeStyle(LinearGradient(
                            colors: [Theme.focusColor, Theme.pausedColor],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                          ))
                        : AnyShapeStyle(Color(.systemGray6))
                )
                .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(count) session\(count > 1 ? "s" : "")")
    }
}

// MARK: - Editable Session Task Row

private struct EditableSessionTaskRow: View {
    let sessionNumber: Int
    @Binding var taskText: String
    @Binding var selectedTaskId: UUID?
    let availableTasks: [FocusTask]
    @State private var showPicker = false

    private var selectedTask: FocusTask? {
        guard let id = selectedTaskId else { return nil }
        return availableTasks.first { $0.id == id }
    }

    private var displayText: String {
        if let task = selectedTask {
            return task.title
        }
        return taskText
    }

    // Badge colors alternate between green and orange
    private var badgeColor: Color {
        sessionNumber % 2 == 1 ? Theme.focusColor : Theme.pausedColor
    }

    var body: some View {
        HStack(spacing: 12) {
            // Session badge - alternating green/orange
            Text("\(sessionNumber)")
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)
                .frame(width: 26, height: 26)
                .background(badgeColor)
                .clipShape(Circle())

            // Text field for typing or showing selected task
            TextField("What will you work on?", text: Binding(
                get: { displayText },
                set: { newValue in
                    taskText = newValue
                    selectedTaskId = nil  // Clear selection when typing
                }
            ))
            .font(.system(size: 15, weight: .regular))

            // Picker button for existing tasks
            if !availableTasks.isEmpty {
                Button {
                    showPicker = true
                } label: {
                    Image(systemName: "list.bullet")
                        .font(.system(size: 14))
                        .foregroundStyle(Theme.focusColor)
                        .frame(width: 32, height: 32)
                        .background(Theme.focusColor.opacity(0.1))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }
        }
        .sheet(isPresented: $showPicker) {
            TaskPickerView(
                tasks: availableTasks,
                selectedId: $selectedTaskId,
                taskText: $taskText
            )
            .presentationDetents([.medium])
            .presentationDragIndicator(.visible)
        }
    }
}

// MARK: - Task Picker View

private struct TaskPickerView: View {
    let tasks: [FocusTask]
    @Binding var selectedId: UUID?
    @Binding var taskText: String
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Button {
                    selectedId = nil
                    taskText = ""
                    dismiss()
                } label: {
                    HStack {
                        Text("None")
                            .foregroundStyle(Theme.textSecondary)
                        Spacer()
                        if selectedId == nil && taskText.isEmpty {
                            Image(systemName: "checkmark")
                                .foregroundStyle(Theme.focusColor)
                        }
                    }
                }

                ForEach(tasks) { task in
                    Button {
                        selectedId = task.id
                        taskText = ""
                        dismiss()
                    } label: {
                        HStack {
                            Text(task.title)
                                .foregroundStyle(Theme.textPrimary)
                            Spacer()
                            if selectedId == task.id {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(Theme.focusColor)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Select Task")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

// MARK: - Session Task Row

private struct SessionTaskRow: View {
    let sessionNumber: Int
    @Binding var selectedTaskId: UUID?
    let availableTasks: [FocusTask]

    private var selectedTask: FocusTask? {
        guard let id = selectedTaskId else { return nil }
        return availableTasks.first { $0.id == id }
    }

    var body: some View {
        HStack(spacing: 12) {
            // Session badge
            Text("\(sessionNumber)")
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .frame(width: 24, height: 24)
                .background(Theme.focusColor)
                .clipShape(Circle())

            // Task picker
            if availableTasks.isEmpty {
                Text("No tasks available")
                    .foregroundStyle(Theme.textTertiary)
            } else {
                Picker("Task", selection: $selectedTaskId) {
                    Text("None")
                        .tag(nil as UUID?)

                    ForEach(availableTasks) { task in
                        Text(task.title)
                            .tag(task.id as UUID?)
                    }
                }
                .pickerStyle(.menu)
                .tint(selectedTask != nil ? Theme.focusColor : Theme.textSecondary)
            }

            Spacer()
        }
    }
}

// MARK: - Legacy Support (Overlay version - kept for compatibility)

/// Session planner overlay (deprecated - use SessionPlannerSheet instead)
@MainActor
struct SessionPlannerOverlay: View {
    @Binding var plan: SessionPlan
    @Binding var isPresented: Bool
    let onStart: () -> Void

    @State private var selectedCount: Int = 3
    @State private var showTaskAssignment = false
    @State private var taskAssignments: [UUID?] = [nil, nil, nil, nil, nil]
    @State private var showingTaskPicker = false
    @State private var editingSessionIndex: Int = 0
    @Environment(SoundService.self) private var soundService
    @Environment(UserSettings.self) private var settings
    @Environment(\.modelContext) private var modelContext
    @Query(filter: #Predicate<FocusTask> { !$0.isCompleted }, sort: \FocusTask.createdAt, order: .reverse) private var availableTasks: [FocusTask]

    var body: some View {
        ZStack {
            Color.black.opacity(0.4)
                .ignoresSafeArea()
                .onTapGesture { dismiss() }

            VStack(spacing: 0) {
                // Drag indicator
                Capsule()
                    .fill(Color.gray.opacity(0.4))
                    .frame(width: 36, height: 5)
                    .padding(.top, 10)
                    .padding(.bottom, 16)

                // Content
                VStack(spacing: 24) {
                    Text("Plan Focus Sessions")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(Theme.textPrimary)

                    // Session count picker - cleaner design
                    VStack(spacing: 12) {
                        Text("How many sessions?")
                            .font(.subheadline)
                            .foregroundStyle(Theme.textSecondary)

                        HStack(spacing: 8) {
                            ForEach(1...5, id: \.self) { count in
                                SessionPill(
                                    count: count,
                                    isSelected: selectedCount == count
                                ) {
                                    soundService.selectionChanged(settings: settings)
                                    withAnimation(.easeInOut(duration: 0.2)) {
                                        selectedCount = count
                                    }
                                }
                            }
                        }
                    }

                    // Task assignment toggle - simplified
                    if !availableTasks.isEmpty {
                        VStack(spacing: 12) {
                            Toggle("Assign tasks", isOn: $showTaskAssignment.animation())
                                .tint(Theme.focusColor)
                                .padding(.horizontal, 4)

                            if showTaskAssignment {
                                VStack(spacing: 8) {
                                    ForEach(0..<selectedCount, id: \.self) { index in
                                        SimpleTaskRow(
                                            sessionNumber: index + 1,
                                            selectedTaskId: $taskAssignments[index],
                                            tasks: availableTasks
                                        )
                                    }
                                }
                                .transition(.opacity.combined(with: .move(edge: .top)))
                            }
                        }
                        .padding(16)
                        .background(Theme.backgroundSecondary)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }

                    // Info
                    if selectedCount > 1 {
                        Text("\(selectedCount) sessions · \(selectedCount - 1) break\(selectedCount > 2 ? "s" : "")")
                            .font(.footnote)
                            .foregroundStyle(Theme.textTertiary)
                    }
                }
                .padding(.horizontal, 24)

                Spacer()

                // Buttons
                HStack(spacing: 12) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(Theme.textSecondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Theme.backgroundSecondary)
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                    Button {
                        soundService.mediumImpact(settings: settings)
                        plan.setTaskCount(selectedCount)
                        if showTaskAssignment {
                            for i in 0..<selectedCount {
                                plan.assignTask(taskAssignments[i], toSession: i)
                            }
                        }
                        withAnimation { isPresented = false }
                        // Post notification to show energy prediction
                        NotificationCenter.default.post(
                            name: .startSessionPlanWithPrediction,
                            object: nil,
                            userInfo: ["sessionPlan": plan]
                        )
                    } label: {
                        Text("Start")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Theme.focusColor)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 34)
            }
            .frame(maxHeight: showTaskAssignment ? 500 : 380)
            .background(Theme.backgroundPrimary)
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .padding(.horizontal, 16)
        }
    }

    private func dismiss() {
        soundService.lightImpact(settings: settings)
        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
            isPresented = false
        }
    }
}

// MARK: - Simple Task Row (for overlay)

private struct SimpleTaskRow: View {
    let sessionNumber: Int
    @Binding var selectedTaskId: UUID?
    let tasks: [FocusTask]

    private var selectedTask: FocusTask? {
        guard let id = selectedTaskId else { return nil }
        return tasks.first { $0.id == id }
    }

    var body: some View {
        HStack(spacing: 10) {
            Text("\(sessionNumber)")
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .frame(width: 22, height: 22)
                .background(Theme.focusColor)
                .clipShape(Circle())

            Menu {
                Button("None") {
                    selectedTaskId = nil
                }

                ForEach(tasks) { task in
                    Button(task.title) {
                        selectedTaskId = task.id
                    }
                }
            } label: {
                HStack {
                    Text(selectedTask?.title ?? "Select task")
                        .font(.system(size: 14))
                        .foregroundStyle(selectedTask != nil ? Theme.textPrimary : Theme.textTertiary)
                        .lineLimit(1)

                    Spacer()

                    Image(systemName: "chevron.up.chevron.down")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(Theme.textTertiary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(Theme.backgroundPrimary)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
    }
}

#Preview {
    struct PreviewWrapper: View {
        @State private var showSheet = false
        @State private var plan = SessionPlan()

        var body: some View {
            VStack {
                SessionPlannerCard(showSheet: $showSheet)
            }
            .sheet(isPresented: $showSheet) {
                SessionPlannerSheet(
                    plan: $plan,
                    isPresented: $showSheet,
                    onStart: { print("Starting \(plan.totalSessions) sessions") }
                )
            }
            .environment(SoundService())
            .environment(UserSettings())
        }
    }
    return PreviewWrapper()
}
