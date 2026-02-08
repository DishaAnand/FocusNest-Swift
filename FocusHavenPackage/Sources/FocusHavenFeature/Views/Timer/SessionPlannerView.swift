import SwiftUI
import SwiftData

/// Simplified session plan - just tracks count, not individual durations
struct SessionPlan: Equatable {
    var totalSessions: Int = 0
    var currentSession: Int = 0  // 0-indexed during execution

    var isActive: Bool { totalSessions > 0 && currentSession < totalSessions }
    var isLastSession: Bool { currentSession == totalSessions - 1 }
    var maxBreaks: Int { max(0, totalSessions - 1) }

    var displayCurrentSession: Int { currentSession + 1 }  // 1-indexed for display

    mutating func reset() {
        totalSessions = 0
        currentSession = 0
    }

    mutating func nextSession() {
        if currentSession < totalSessions - 1 {
            currentSession += 1
        }
    }
}

/// Collapsed card that triggers the planner overlay
@MainActor
struct SessionPlannerCard: View {
    @Binding var showOverlay: Bool
    @Environment(SoundService.self) private var soundService
    @Environment(UserSettings.self) private var settings

    var body: some View {
        Button {
            soundService.lightImpact(settings: settings)
            withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                showOverlay = true
            }
        } label: {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [.purple.opacity(0.25), .pink.opacity(0.2)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 42, height: 42)

                    Image(systemName: "square.stack.3d.up.fill")
                        .font(.system(size: 17, weight: .medium))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.purple, .pink],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text("Plan Sessions")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Theme.textPrimary)

                    Text("Commit to focus blocks")
                        .font(.system(size: 12, weight: .regular))
                        .foregroundStyle(Theme.textSecondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Theme.textTertiary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 18)
                    .fill(Theme.backgroundSecondary)
                    .overlay(
                        RoundedRectangle(cornerRadius: 18)
                            .stroke(
                                LinearGradient(
                                    colors: [.purple.opacity(0.2), .pink.opacity(0.15), .clear],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1
                            )
                    )
            )
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 20)
    }
}

/// Simplified session planner - just pick number of sessions
@MainActor
struct SessionPlannerOverlay: View {
    @Binding var plan: SessionPlan
    @Binding var isPresented: Bool
    let onStart: () -> Void

    @State private var selectedCount: Int = 3
    @Environment(SoundService.self) private var soundService
    @Environment(UserSettings.self) private var settings

    private let sessionOptions = [1, 2, 3, 4, 5]

    var body: some View {
        ZStack {
            Color.black.opacity(0.45)
                .ignoresSafeArea()
                .onTapGesture { dismiss() }

            VStack(spacing: 0) {
                // Header
                HStack {
                    Button { dismiss() } label: {
                        Text("Cancel")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(Theme.textSecondary)
                    }

                    Spacer()

                    Text("Plan Sessions")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(Theme.textPrimary)

                    Spacer()

                    Color.clear.frame(width: 50)
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, 24)

                // Main content
                VStack(spacing: 32) {
                    // Question
                    Text("How many sessions today?")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(Theme.textPrimary)

                    // Session count picker
                    HStack(spacing: 12) {
                        ForEach(sessionOptions, id: \.self) { count in
                            SessionCountButton(
                                count: count,
                                isSelected: selectedCount == count,
                                onTap: {
                                    soundService.selectionChanged(settings: settings)
                                    withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                                        selectedCount = count
                                    }
                                }
                            )
                        }
                    }

                    // Info text
                    VStack(spacing: 8) {
                        HStack(spacing: 6) {
                            Image(systemName: "clock")
                                .font(.system(size: 13))
                            Text("Set duration before each session")
                        }
                        .font(.system(size: 14))
                        .foregroundStyle(Theme.textSecondary)

                        if selectedCount > 1 {
                            HStack(spacing: 6) {
                                Image(systemName: "cup.and.saucer")
                                    .font(.system(size: 13))
                                Text("Up to \(selectedCount - 1) break\(selectedCount > 2 ? "s" : "") between sessions")
                            }
                            .font(.system(size: 14))
                            .foregroundStyle(Theme.textSecondary)
                        }
                    }
                    .padding(.top, 8)
                }
                .padding(.horizontal, 24)

                Spacer()

                // Start button
                Button {
                    soundService.mediumImpact(settings: settings)
                    plan.totalSessions = selectedCount
                    plan.currentSession = 0
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                        isPresented = false
                    }
                    onStart()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "play.fill")
                            .font(.system(size: 13))
                        Text("Start \(selectedCount) Session\(selectedCount > 1 ? "s" : "")")
                            .font(.system(size: 16, weight: .semibold))
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        LinearGradient(
                            colors: [Theme.focusColor, Theme.focusColor.opacity(0.8)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .shadow(color: Theme.focusColor.opacity(0.3), radius: 10, x: 0, y: 5)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 30)
            }
            .frame(height: 380)
            .background(
                RoundedRectangle(cornerRadius: 28)
                    .fill(Theme.backgroundSecondary)
            )
            .padding(.horizontal, 20)
            .shadow(color: .black.opacity(0.25), radius: 30, x: 0, y: 15)
        }
    }

    private func dismiss() {
        soundService.lightImpact(settings: settings)
        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
            isPresented = false
        }
    }
}

// MARK: - Session Count Button

private struct SessionCountButton: View {
    let count: Int
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 4) {
                Text("\(count)")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundStyle(isSelected ? .white : Theme.textPrimary)
            }
            .frame(width: 56, height: 56)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(isSelected
                          ? LinearGradient(
                            colors: [.purple, .pink],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                          )
                          : LinearGradient(
                            colors: [Theme.backgroundPrimary, Theme.backgroundPrimary],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                          )
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(isSelected ? Color.clear : Theme.textTertiary.opacity(0.2), lineWidth: 1)
            )
            .scaleEffect(isSelected ? 1.08 : 1.0)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    struct PreviewWrapper: View {
        @State private var plan = SessionPlan()
        @State private var showOverlay = true

        var body: some View {
            ZStack {
                Theme.backgroundPrimary.ignoresSafeArea()

                if showOverlay {
                    SessionPlannerOverlay(
                        plan: $plan,
                        isPresented: $showOverlay,
                        onStart: { print("Starting \(plan.totalSessions) sessions") }
                    )
                }
            }
            .environment(SoundService())
            .environment(UserSettings())
        }
    }
    return PreviewWrapper()
}
