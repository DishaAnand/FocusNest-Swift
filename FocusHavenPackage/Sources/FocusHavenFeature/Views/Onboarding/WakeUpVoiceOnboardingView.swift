import SwiftUI

@MainActor
struct WakeUpVoiceOnboardingView: View {
    let onSetUp: () -> Void
    let onSkip: () -> Void

    @State private var isPulsing = false

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            // Pulsing mic icon
            ZStack {
                // Outer pulse ring
                Circle()
                    .fill(Theme.focusColor.opacity(0.2))
                    .frame(width: 120, height: 120)
                    .scaleEffect(isPulsing ? 1.3 : 1.0)
                    .opacity(isPulsing ? 0 : 0.6)

                // Inner pulse ring
                Circle()
                    .fill(Theme.focusColor.opacity(0.3))
                    .frame(width: 100, height: 100)
                    .scaleEffect(isPulsing ? 1.2 : 1.0)
                    .opacity(isPulsing ? 0.2 : 0.8)

                // Icon background
                Circle()
                    .fill(Theme.focusColor.opacity(0.15))
                    .frame(width: 100, height: 100)

                // Mic icon
                Image(systemName: "mic.fill")
                    .font(.system(size: 44))
                    .foregroundStyle(Theme.focusColor)
            }
            .onAppear {
                withAnimation(
                    .easeInOut(duration: 1.5)
                    .repeatForever(autoreverses: false)
                ) {
                    isPulsing = true
                }
            }

            // Headline
            VStack(spacing: 12) {
                Text("Add your secret weapon")
                    .font(.system(size: 26, weight: .bold))
                    .foregroundStyle(Theme.textPrimary)

                Text("Record a voice that plays when you\nextend your break too long")
                    .font(Theme.bodyFont)
                    .foregroundStyle(Theme.textSecondary)
                    .multilineTextAlignment(.center)
            }

            // Ideas box
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Image(systemName: "lightbulb.fill")
                        .foregroundStyle(.yellow)
                    Text("Ideas")
                        .font(Theme.bodyFont.weight(.semibold))
                        .foregroundStyle(Theme.textPrimary)
                }

                VStack(alignment: .leading, spacing: 8) {
                    IdeaRow(text: "Mom saying \"Get back to work!\"")
                    IdeaRow(text: "Your own motivational pep talk")
                    IdeaRow(text: "A friend cheering you on")
                }
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.backgroundSecondary)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .padding(.horizontal, 24)

            Spacer()

            // Buttons
            VStack(spacing: 16) {
                Button(action: onSetUp) {
                    HStack {
                        Image(systemName: "mic.fill")
                        Text("Set It Up")
                    }
                    .font(Theme.bodyFont.weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Theme.focusColor)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                }

                Button(action: onSkip) {
                    Text("Maybe Later")
                        .font(Theme.bodyFont)
                        .foregroundStyle(Theme.textSecondary)
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 32)
            .frame(maxWidth: 400)  // iPad: constrain button width
            .frame(maxWidth: .infinity)  // Center on larger screens
        }
        .frame(maxWidth: 500)  // iPad: constrain overall content width
        .frame(maxWidth: .infinity)  // Center on larger screens
        .background(Theme.backgroundPrimary)
    }
}

private struct IdeaRow: View {
    let text: String

    var body: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(Theme.focusColor)
                .frame(width: 6, height: 6)
            Text(text)
                .font(Theme.bodyFont)
                .foregroundStyle(Theme.textSecondary)
        }
    }
}

#Preview {
    WakeUpVoiceOnboardingView(
        onSetUp: {},
        onSkip: {}
    )
}
