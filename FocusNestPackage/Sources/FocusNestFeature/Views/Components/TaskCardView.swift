import SwiftUI

public struct TaskCardView: View {
    let task: FocusTask
    let isSelected: Bool
    let onTap: () -> Void
    let onComplete: () -> Void
    let onDelete: () -> Void
    let onRename: () -> Void
    let onStart: (() -> Void)?

    public init(task: FocusTask, isSelected: Bool = false, onTap: @escaping () -> Void, onComplete: @escaping () -> Void, onDelete: @escaping () -> Void, onRename: @escaping () -> Void, onStart: (() -> Void)? = nil) {
        self.task = task; self.isSelected = isSelected; self.onTap = onTap; self.onComplete = onComplete; self.onDelete = onDelete; self.onRename = onRename; self.onStart = onStart
    }

    public var body: some View {
        HStack(spacing: Theme.spacingM) {
            Button(action: onComplete) {
                Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundStyle(task.isCompleted ? Theme.successColor : Theme.textSecondary)
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: Theme.spacingXS) {
                Text(task.title)
                    .font(Theme.bodyFont)
                    .foregroundStyle(task.isCompleted ? Theme.textSecondary : Theme.textPrimary)
                    .strikethrough(task.isCompleted)
                    .lineLimit(2)
                if task.totalFocusTime > 0 {
                    HStack(spacing: Theme.spacingXS) {
                        Image(systemName: "clock").font(.caption2)
                        Text(task.formattedFocusTime).font(Theme.captionFont)
                    }
                    .foregroundStyle(Theme.textTertiary)
                }
            }
            Spacer()

            // Start button for incomplete tasks
            if !task.isCompleted, let onStart = onStart {
                Button(action: onStart) {
                    Text("Start")
                        .font(Theme.captionFont.weight(.semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, Theme.spacingM)
                        .padding(.vertical, Theme.spacingXS)
                        .background(Theme.focusColor)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }

            if isSelected {
                Image(systemName: "checkmark.circle.fill").font(.title3).foregroundStyle(Theme.focusColor)
            }
        }
        .padding(Theme.spacingM)
        .background(RoundedRectangle(cornerRadius: Theme.cornerRadiusM).fill(isSelected ? Theme.focusColor.opacity(0.1) : Theme.backgroundSecondary))
        .overlay(RoundedRectangle(cornerRadius: Theme.cornerRadiusM).stroke(isSelected ? Theme.focusColor : Color.clear, lineWidth: 2))
        .contentShape(Rectangle())
        .onTapGesture(perform: onTap)
        .contextMenu {
            Button { onRename() } label: { Label("Rename", systemImage: "pencil") }
            Button { onComplete() } label: { Label(task.isCompleted ? "Mark Incomplete" : "Mark Complete", systemImage: task.isCompleted ? "circle" : "checkmark.circle") }
            Divider()
            Button(role: .destructive) { onDelete() } label: { Label("Delete", systemImage: "trash") }
        }
    }
}

public struct TaskSelectionCardView: View {
    let task: FocusTask
    let isSelected: Bool
    let onSelect: () -> Void

    public init(task: FocusTask, isSelected: Bool, onSelect: @escaping () -> Void) {
        self.task = task; self.isSelected = isSelected; self.onSelect = onSelect
    }

    public var body: some View {
        HStack(spacing: Theme.spacingM) {
            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle").font(.title3).foregroundStyle(isSelected ? Theme.focusColor : Theme.textSecondary)
            Text(task.title).font(Theme.bodyFont).foregroundStyle(Theme.textPrimary).lineLimit(1)
            Spacer()
            if task.totalFocusTime > 0 { Text(task.formattedFocusTime).font(Theme.captionFont).foregroundStyle(Theme.textTertiary) }
        }
        .padding(Theme.spacingM)
        .background(RoundedRectangle(cornerRadius: Theme.cornerRadiusM).fill(isSelected ? Theme.focusColor.opacity(0.1) : Theme.backgroundSecondary))
        .overlay(RoundedRectangle(cornerRadius: Theme.cornerRadiusM).stroke(isSelected ? Theme.focusColor : Color.clear, lineWidth: 2))
        .contentShape(Rectangle())
        .onTapGesture(perform: onSelect)
    }
}
