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

    private var totalMinutes: Int {
        (myDuration + buddyDuration) / 60
    }

    private var dynamicMessage: String {
        let totalDistractions = myDistractions + buddyDistractions
        if totalDistractions == 0 {
            return "Laser focused! 🎯"
        } else if totalDistractions <= 2 {
            return "You two are unstoppable!"
        } else if myDistractions == 0 || buddyDistractions == 0 {
            return "Great teamwork!"
        } else {
            return "Focus session complete!"
        }
    }

    private var myInitial: String {
        String(myName.prefix(1)).uppercased()
    }

    private var buddyInitial: String {
        String(buddyName.prefix(1)).uppercased()
    }

    var body: some View {
        ZStack {
            // Gradient background
            LinearGradient(
                colors: [
                    Color(red: 0.2, green: 0.35, blue: 0.3),
                    Color(red: 0.1, green: 0.15, blue: 0.12)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                // Main card
                VStack(spacing: Theme.spacingL) {
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
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.9))
                        .opacity(showContent ? 1 : 0)

                    // Stats Breakdown
                    statsBreakdown
                        .opacity(showContent ? 1 : 0)
                        .offset(y: showContent ? 0 : 20)
                }
                .padding(Theme.spacingXL)
                .background(
                    RoundedRectangle(cornerRadius: 24)
                        .fill(.ultraThinMaterial)
                        .shadow(color: .black.opacity(0.3), radius: 20, y: 10)
                )
                .padding(.horizontal, Theme.spacingM)

                Spacer()

                // Done button
                Button(action: onDone) {
                    Text("Done")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, Theme.spacingM)
                        .background(Theme.focusGradient)
                        .clipShape(RoundedRectangle(cornerRadius: Theme.cornerRadiusM))
                }
                .padding(.horizontal, Theme.spacingL)
                .padding(.bottom, Theme.spacingXL)
                .opacity(showContent ? 1 : 0)
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.2)) {
                showContent = true
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
