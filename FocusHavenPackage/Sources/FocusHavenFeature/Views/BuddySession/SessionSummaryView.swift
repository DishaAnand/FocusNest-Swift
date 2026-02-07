import SwiftUI

struct SessionSummaryView: View {
    let myName: String
    let buddyName: String
    let myDuration: Int  // seconds
    let buddyDuration: Int  // seconds
    let myDistractions: Int
    let buddyDistractions: Int
    let onDone: () -> Void

    @State private var showContent = false
    @State private var ringProgress: Double = 0
    @State private var buddyRingProgress: Double = 0
    @State private var celebrationEmoji = "🎉"
    @State private var emojiScale: CGFloat = 0

    private var totalMinutes: Int {
        (myDuration + buddyDuration) / 60
    }

    private var totalDistractions: Int {
        myDistractions + buddyDistractions
    }

    private var dynamicMessage: String {
        if totalDistractions == 0 {
            return "Laser focused together!"
        } else if totalDistractions <= 2 {
            return "You two are unstoppable!"
        } else if myDistractions == 0 || buddyDistractions == 0 {
            return "Great teamwork!"
        } else {
            return "Focus session complete!"
        }
    }

    private var dynamicEmoji: String {
        if totalDistractions == 0 {
            return "🎯"
        } else if totalDistractions <= 2 {
            return "🔥"
        } else if myDistractions == 0 || buddyDistractions == 0 {
            return "🤝"
        } else {
            return "✨"
        }
    }

    private var myInitial: String {
        String(myName.prefix(1)).uppercased()
    }

    private var buddyInitial: String {
        String(buddyName.prefix(1)).uppercased()
    }

    var body: some View {
        ScrollView {
            VStack(spacing: Theme.spacingM) {
                // Top title
                VStack(spacing: 6) {
                    Text("Session Complete")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.white.opacity(0.6))
                        .textCase(.uppercase)
                        .tracking(2)

                    Text(dynamicEmoji)
                        .font(.system(size: 36))
                        .scaleEffect(emojiScale)
                }
                .padding(.top, Theme.spacingM)
                .opacity(showContent ? 1 : 0)

                // Main card
                VStack(spacing: Theme.spacingM) {
                    // Duo Connection Header
                    duoHeader
                        .opacity(showContent ? 1 : 0)
                        .offset(y: showContent ? 0 : 20)

                    // Focus Rings + Hero Stat
                    focusRingsView
                        .opacity(showContent ? 1 : 0)
                        .scaleEffect(showContent ? 1 : 0.8)

                    // Dynamic Message
                    Text(dynamicMessage)
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .opacity(showContent ? 1 : 0)

                    // Stats Breakdown
                    statsBreakdown
                        .opacity(showContent ? 1 : 0)
                        .offset(y: showContent ? 0 : 20)
                }
                .padding(Theme.spacingL)
                .background(
                    RoundedRectangle(cornerRadius: 24)
                        .fill(.ultraThinMaterial)
                        .overlay(
                            RoundedRectangle(cornerRadius: 24)
                                .stroke(
                                    LinearGradient(
                                        colors: [.white.opacity(0.2), .white.opacity(0.05)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 1
                                )
                        )
                        .shadow(color: .black.opacity(0.4), radius: 20, y: 10)
                )
                .frame(maxWidth: 450)
            }
            .padding(.horizontal, Theme.spacingM)
            .padding(.bottom, 20)
        }
        .safeAreaInset(edge: .bottom) {
            // Done button - always visible at bottom
            Button(action: onDone) {
                HStack(spacing: 8) {
                    Text("Done")
                    Image(systemName: "checkmark.circle.fill")
                }
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    LinearGradient(
                        colors: [Color.green, Color.green.opacity(0.8)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .shadow(color: .green.opacity(0.3), radius: 10, y: 5)
            }
            .frame(maxWidth: 450)
            .padding(.horizontal, Theme.spacingL)
            .padding(.bottom, Theme.spacingM)
            .opacity(showContent ? 1 : 0)
            .background(
                LinearGradient(
                    colors: [
                        Color(red: 0.05, green: 0.08, blue: 0.06),
                        Color(red: 0.05, green: 0.08, blue: 0.06).opacity(0)
                    ],
                    startPoint: .bottom,
                    endPoint: .top
                )
                .frame(height: 100)
                .allowsHitTesting(false)
            )
        }
        .background(
            LinearGradient(
                colors: [
                    Color(red: 0.12, green: 0.25, blue: 0.22),
                    Color(red: 0.08, green: 0.12, blue: 0.10),
                    Color(red: 0.05, green: 0.08, blue: 0.06)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
        )
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.2)) {
                showContent = true
            }
            withAnimation(.spring(response: 0.5, dampingFraction: 0.5).delay(0.4)) {
                emojiScale = 1.0
            }
            withAnimation(.easeOut(duration: 1.2).delay(0.5)) {
                ringProgress = 1.0
                buddyRingProgress = 1.0
            }
        }
    }

    // MARK: - Duo Header

    private var duoHeader: some View {
        HStack(spacing: 0) {
            // My circle
            VStack(spacing: 6) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Theme.focusColor, Theme.focusColor.opacity(0.7)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 56, height: 56)

                    Text(myInitial)
                        .font(.system(size: 24, weight: .bold))
                        .foregroundStyle(.white)
                }

                Text("You")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.white.opacity(0.9))
            }

            // Connection line
            connectionLine
                .frame(width: 60)

            // Buddy circle
            VStack(spacing: 6) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color.teal, Color.teal.opacity(0.7)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 56, height: 56)

                    Text(buddyInitial)
                        .font(.system(size: 24, weight: .bold))
                        .foregroundStyle(.white)
                }

                Text(buddyName)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.white.opacity(0.9))
                    .lineLimit(1)
            }
        }
    }

    private var connectionLine: some View {
        GeometryReader { geo in
            Path { path in
                path.move(to: CGPoint(x: 0, y: geo.size.height / 2 - 10))
                path.addLine(to: CGPoint(x: geo.size.width, y: geo.size.height / 2 - 10))
            }
            .trim(from: 0, to: showContent ? 1 : 0)
            .stroke(
                LinearGradient(
                    colors: [Theme.focusColor, Color.teal],
                    startPoint: .leading,
                    endPoint: .trailing
                ),
                style: StrokeStyle(lineWidth: 3, lineCap: .round)
            )
            .animation(.easeOut(duration: 0.5).delay(0.3), value: showContent)
        }
    }

    // MARK: - Focus Rings

    private var focusRingsView: some View {
        ZStack {
            // Outer ring - You
            Circle()
                .stroke(Color.white.opacity(0.1), lineWidth: 14)
                .frame(width: 160, height: 160)

            Circle()
                .trim(from: 0, to: ringProgress)
                .stroke(
                    LinearGradient(
                        colors: [Theme.focusColor, Theme.focusColor.opacity(0.6)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    style: StrokeStyle(lineWidth: 14, lineCap: .round)
                )
                .frame(width: 160, height: 160)
                .rotationEffect(.degrees(-90))

            // Inner ring - Buddy
            Circle()
                .stroke(Color.white.opacity(0.1), lineWidth: 10)
                .frame(width: 120, height: 120)

            Circle()
                .trim(from: 0, to: buddyRingProgress)
                .stroke(
                    LinearGradient(
                        colors: [Color.teal, Color.teal.opacity(0.6)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    style: StrokeStyle(lineWidth: 10, lineCap: .round)
                )
                .frame(width: 120, height: 120)
                .rotationEffect(.degrees(-90))

            // Center text
            VStack(spacing: 2) {
                Text("\(totalMinutes)")
                    .font(.system(size: 44, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)

                Text("min")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(.white.opacity(0.7))
            }
        }
    }

    // MARK: - Stats Breakdown

    private var statsBreakdown: some View {
        HStack(spacing: Theme.spacingL) {
            // Your stats
            VStack(spacing: 8) {
                Text("You")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)

                focusDots(distractions: myDistractions)

                Text("\(myDuration / 60) min")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.white)

                distractionLabel(myDistractions)
            }
            .frame(maxWidth: .infinity)

            // Divider
            Rectangle()
                .fill(Color.white.opacity(0.3))
                .frame(width: 1, height: 80)

            // Buddy stats
            VStack(spacing: 8) {
                Text(buddyName)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)

                focusDots(distractions: buddyDistractions)

                Text("\(buddyDuration / 60) min")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.white)

                distractionLabel(buddyDistractions)
            }
            .frame(maxWidth: .infinity)
        }
        .padding(Theme.spacingM)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.1))
        )
    }

    private func focusDots(distractions: Int) -> some View {
        HStack(spacing: 4) {
            ForEach(0..<5, id: \.self) { index in
                Circle()
                    .fill(index < (5 - min(distractions, 5)) ? Color.green : Color.white.opacity(0.3))
                    .frame(width: 10, height: 10)
            }
        }
    }

    @ViewBuilder
    private func distractionLabel(_ count: Int) -> some View {
        if count == 0 {
            Text("No distractions")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.green)
        } else {
            Text(count == 1 ? "1 distraction" : "\(count) distractions")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.orange)
        }
    }
}

#Preview {
    SessionSummaryView(
        myName: "Disha",
        buddyName: "Alex",
        myDuration: 25 * 60,
        buddyDuration: 45 * 60,
        myDistractions: 0,
        buddyDistractions: 2,
        onDone: {}
    )
}
