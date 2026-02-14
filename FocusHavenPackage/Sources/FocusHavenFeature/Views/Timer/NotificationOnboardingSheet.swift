import SwiftUI
import UIKit

/// Onboarding sheet explaining why notifications are needed for timer completion sounds
struct NotificationOnboardingSheet: View {
    let onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            // Icon
            Image(systemName: "lock.fill")
                .font(.system(size: 44))
                .foregroundStyle(Theme.focusColor)
                .padding(.top, 32)

            // Title & Description - concise
            VStack(spacing: 8) {
                Text("Phone Locked?")
                    .font(.title3.bold())
                    .foregroundStyle(Theme.textPrimary)

                Text("Enable notifications to hear when your timer ends while your screen is off.")
                    .font(.subheadline)
                    .foregroundStyle(Theme.textSecondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 24)

            Spacer(minLength: 16)

            // Buttons
            VStack(spacing: 12) {
                Button {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                    onDismiss()
                } label: {
                    Text("Open Settings")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Theme.focusColor)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }

                Button {
                    onDismiss()
                } label: {
                    Text("Skip")
                        .font(.subheadline)
                        .foregroundStyle(Theme.textSecondary)
                        .padding(.vertical, 8)
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 16)
            .frame(maxWidth: 400)  // iPad: constrain button width
            .frame(maxWidth: .infinity)  // Center on larger screens
        }
        .background(Theme.backgroundPrimary)
    }
}
