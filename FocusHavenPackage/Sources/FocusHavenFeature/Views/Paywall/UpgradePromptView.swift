import SwiftUI

@MainActor
public struct UpgradePromptView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(SubscriptionService.self) private var subscriptionService

    let title: String
    let message: String
    let icon: String

    @State private var showPaywall = false

    public init(title: String, message: String, icon: String = "crown.fill") {
        self.title = title
        self.message = message
        self.icon = icon
    }

    public var body: some View {
        VStack(spacing: Theme.spacingL) {
            Image(systemName: icon)
                .font(.system(size: 56))
                .foregroundStyle(Theme.focusColor)

            Text(title)
                .font(Theme.titleFont)
                .multilineTextAlignment(.center)

            Text(message)
                .font(Theme.bodyFont)
                .foregroundStyle(Theme.textSecondary)
                .multilineTextAlignment(.center)

            if subscriptionService.daysUntilReset < 30 {
                Text("Resets in \(subscriptionService.daysUntilReset) days")
                    .font(Theme.captionFont)
                    .foregroundStyle(Theme.textTertiary)
            }

            VStack(spacing: Theme.spacingM) {
                Button {
                    showPaywall = true
                } label: {
                    Text("Upgrade to Pro")
                        .font(Theme.headlineFont)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, Theme.spacingM)
                        .background(Theme.focusGradient)
                        .clipShape(RoundedRectangle(cornerRadius: Theme.cornerRadiusM))
                }

                Button {
                    dismiss()
                } label: {
                    Text("Maybe Later")
                        .font(Theme.bodyFont)
                        .foregroundStyle(Theme.textSecondary)
                }
            }
            .padding(.top, Theme.spacingS)
        }
        .padding(Theme.spacingL)
        .frame(maxWidth: 400)
        .background(Theme.backgroundPrimary)
        .clipShape(RoundedRectangle(cornerRadius: Theme.cornerRadiusXL))
        .shadow(color: .black.opacity(0.2), radius: 20)
        .sheet(isPresented: $showPaywall) {
            PaywallView()
        }
    }
}

// MARK: - Convenience Prompts

extension UpgradePromptView {
    public static func buddySessionLimit() -> UpgradePromptView {
        UpgradePromptView(
            title: "Buddy Session Limit Reached",
            message: "You've used your free buddy session this month. Upgrade to Pro for unlimited sessions with friends!",
            icon: "person.2.fill"
        )
    }

    public static func sessionPlanLimit() -> UpgradePromptView {
        UpgradePromptView(
            title: "Session Plan Limit Reached",
            message: "You've used your free session plans this month. Upgrade to Pro for unlimited planning!",
            icon: "list.bullet.clipboard"
        )
    }

    public static func wakeUpVoiceLimit() -> UpgradePromptView {
        UpgradePromptView(
            title: "Wake-Up Voice Limit",
            message: "Free users can save 1 wake-up voice. Upgrade to Pro for unlimited recordings!",
            icon: "mic.fill"
        )
    }

    public static func soundsLocked() -> UpgradePromptView {
        UpgradePromptView(
            title: "Premium Sound",
            message: "This ambient sound is available with Pro. Unlock all 7 sounds!",
            icon: "waveform"
        )
    }


    public static func insightsLocked() -> UpgradePromptView {
        UpgradePromptView(
            title: "Insights & Charts",
            message: "Get detailed analytics on your focus patterns. Available with Pro.",
            icon: "chart.bar.fill"
        )
    }
}

#Preview {
    ZStack {
        Color.black.opacity(0.5).ignoresSafeArea()
        UpgradePromptView.buddySessionLimit()
    }
    .environment(SubscriptionService())
}
