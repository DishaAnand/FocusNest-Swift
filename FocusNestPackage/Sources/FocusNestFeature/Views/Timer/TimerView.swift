import SwiftUI
import SwiftData

@MainActor
public struct TimerView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(UserSettings.self) private var settings
    @Environment(TimerService.self) private var timerService
    @Environment(NotificationService.self) private var notificationService
    @Environment(SoundService.self) private var soundService

    @State private var showTaskSelector = false

    public init() {}

    public var body: some View {
        GeometryReader { geometry in
            let isCompact = geometry.size.width < 500
            VStack {
                Spacer()
                VStack(spacing: Theme.spacingXL) {
                    Text(timerService.mode.displayName)
                        .font(Theme.titleFont)
                        .foregroundStyle(timerService.isBreak ? Theme.breakColor : Theme.focusColor)

                    ZStack {
                        CircularProgressView(progress: timerService.progress, lineWidth: 12, size: isCompact ? 260 : 320, color: timerService.isBreak ? Theme.breakColor : Theme.focusColor)
                        VStack(spacing: Theme.spacingS) {
                            Text(timerService.formattedTime)
                                .font(isCompact ? Theme.timerFontSmall : Theme.timerFont)
                                .foregroundStyle(Theme.textPrimary)
                                .monospacedDigit()
                                .contentTransition(.numericText())
                            if timerService.state == .paused {
                                Text("PAUSED").font(Theme.captionFont).foregroundStyle(Theme.pausedColor).textCase(.uppercase)
                            }
                        }
                    }
                    .padding(.vertical, Theme.spacingL)

                    if let task = timerService.selectedTask {
                        Button { showTaskSelector = true } label: {
                            HStack(spacing: Theme.spacingS) {
                                Image(systemName: "target").foregroundStyle(Theme.focusColor)
                                Text(task.title).font(Theme.bodyFont).foregroundStyle(Theme.textPrimary).lineLimit(1)
                                Image(systemName: "chevron.right").font(.caption).foregroundStyle(Theme.textTertiary)
                            }
                            .padding(.horizontal, Theme.spacingM).padding(.vertical, Theme.spacingS)
                            .background(Theme.backgroundSecondary).clipShape(Capsule())
                        }
                        .disabled(timerService.isRunning)
                    }

                    HStack(spacing: Theme.spacingL) {
                        if timerService.state != .idle {
                            Button { soundService.lightImpact(); timerService.stop(); notificationService.cancelTimerNotifications() } label: {
                                Image(systemName: "stop.fill").font(.title2).foregroundStyle(.white).frame(width: 56, height: 56).background(Theme.errorColor.opacity(0.8)).clipShape(Circle())
                            }
                        }
                        Button { soundService.mediumImpact(); handlePlayPause() } label: {
                            Image(systemName: timerService.isRunning ? "pause.fill" : "play.fill")
                                .font(.title).foregroundStyle(.white).frame(width: 80, height: 80)
                                .background(timerService.isBreak ? Theme.breakGradient : Theme.focusGradient).clipShape(Circle())
                                .shadow(color: (timerService.isBreak ? Theme.breakColor : Theme.focusColor).opacity(0.3), radius: 10, x: 0, y: 4)
                        }
                        Button { soundService.lightImpact(); timerService.skip(); notificationService.cancelTimerNotifications() } label: {
                            Image(systemName: "forward.end.fill").font(.title2).foregroundStyle(.white).frame(width: 56, height: 56).background(Theme.textSecondary).clipShape(Circle())
                        }
                    }
                    .padding(.vertical, Theme.spacingM)

                    VStack(spacing: Theme.spacingS) {
                        HStack(spacing: Theme.spacingXS) {
                            ForEach(0..<settings.sessionsBeforeLongBreak, id: \.self) { index in
                                Circle().fill(index < timerService.completedSessions ? Theme.focusColor : Theme.textTertiary.opacity(0.3)).frame(width: 12, height: 12)
                            }
                        }
                        Text("\(timerService.completedSessions) of \(settings.sessionsBeforeLongBreak) sessions until long break").font(Theme.captionFont).foregroundStyle(Theme.textSecondary)
                    }
                }
                .padding(Theme.spacingL)
                Spacer()
            }
        }
        .background(Theme.backgroundPrimary)
        .sheet(isPresented: $showTaskSelector) { TaskSelectorSheet(selectedTask: Bindable(timerService).selectedTask) }
        .task { setupTimerCallbacks() }
    }

    private func handlePlayPause() {
        if timerService.state == .idle {
            Task { await notificationService.scheduleTimerCompletion(in: timerService.remainingTime, mode: timerService.mode, taskTitle: timerService.selectedTask?.title) }
        } else if timerService.state == .paused {
            Task { notificationService.cancelTimerNotifications(); await notificationService.scheduleTimerCompletion(in: timerService.remainingTime, mode: timerService.mode, taskTitle: timerService.selectedTask?.title) }
        } else {
            notificationService.cancelTimerNotifications()
        }
        timerService.togglePlayPause()
    }

    private func setupTimerCallbacks() {
        timerService.onComplete = { mode in
            if settings.soundEnabled { soundService.playTimerComplete() }
            if settings.vibrationEnabled { soundService.successHaptic() }
            if mode == .focus {
                let record = FocusRecord(duration: settings.focusDuration, isBreak: false, taskId: timerService.selectedTask?.id, taskTitle: timerService.selectedTask?.title, wasCompleted: true)
                modelContext.insert(record)
            }
        }
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
