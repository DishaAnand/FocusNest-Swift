import SwiftUI

public struct EmptyStateView: View {
    let icon: String
    let title: String
    let message: String
    let actionTitle: String?
    let action: (() -> Void)?

    public init(icon: String, title: String, message: String, actionTitle: String? = nil, action: (() -> Void)? = nil) {
        self.icon = icon; self.title = title; self.message = message; self.actionTitle = actionTitle; self.action = action
    }

    public var body: some View {
        VStack(spacing: Theme.spacingL) {
            Image(systemName: icon).font(.system(size: 64)).foregroundStyle(Theme.textTertiary)
            VStack(spacing: Theme.spacingS) {
                Text(title).font(Theme.headlineFont).foregroundStyle(Theme.textPrimary)
                Text(message).font(Theme.bodyFont).foregroundStyle(Theme.textSecondary).multilineTextAlignment(.center)
            }
            if let actionTitle, let action {
                Button(action: action) { Text(actionTitle).primaryButtonStyle() }.frame(maxWidth: 200)
            }
        }
        .padding(Theme.spacingXL)
    }
}
