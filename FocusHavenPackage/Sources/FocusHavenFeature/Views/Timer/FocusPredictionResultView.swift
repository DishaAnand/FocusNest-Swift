import SwiftUI

struct FocusPredictionResultView: View {
    let predictedLevel: Int
    let actualLevel: Int
    let duration: Int
    let distractionCount: Int
    let wasCompleted: Bool
    let onDone: () -> Void

    @State private var ringProgress: CGFloat = 0
    @State private var showScore = false
    @State private var showComparison = false
    @State private var showMessage = false
    @State private var showStats = false
    @State private var showButton = false
    @State private var pulseScale: CGFloat = 1.0
    @State private var particlesVisible = false

    @Environment(SoundService.self) private var soundService
    @Environment(UserSettings.self) private var settings

    private var comparisonType: ComparisonType {
        if actualLevel > predictedLevel { return .underestimated }
        else if actualLevel == predictedLevel { return .spotOn }
        else { return .overestimated }
    }

    private var celebrationEmoji: String {
        let gap = actualLevel - predictedLevel
        switch comparisonType {
        case .underestimated:
            if gap >= 3 { return "🤯" }
            else if gap == 2 { return "🚀" }
            else { return "✨" }
        case .spotOn: return "🎯"
        case .overestimated:
            let missedBy = predictedLevel - actualLevel
            if missedBy >= 2 { return "💪" }
            else { return "👍" }
        }
    }

    private var titleForGap: String {
        let gap = actualLevel - predictedLevel
        switch comparisonType {
        case .underestimated:
            if gap >= 3 { return "Mind Blown! 🤯" }
            else if gap == 2 { return "Way Better! 🚀" }
            else { return "Nice Surprise! ✨" }
        case .spotOn:
            return "Spot On! 🎯"
        case .overestimated:
            let missedBy = predictedLevel - actualLevel
            if missedBy >= 3 { return "Tough One 💪" }
            else if missedBy == 2 { return "Keep Growing 🌱" }
            else { return "Almost There! 👍" }
        }
    }

    private var messages: [String] {
        let gap = actualLevel - predictedLevel

        switch comparisonType {
        case .underestimated:
            if gap >= 3 {
                // Massive improvement (3-4 levels up)
                return [
                    "Wow! You seriously underestimated yourself!",
                    "Plot twist: You're a focus beast!",
                    "Who knew you had this in you? 🔥",
                    "That's a whole different level!"
                ]
            } else if gap == 2 {
                // Good improvement (2 levels up)
                return [
                    "Way better than you thought!",
                    "Your focus surprised even you!",
                    "Turns out you're pretty amazing",
                    "Two levels up? Nice work!"
                ]
            } else {
                // Slight improvement (1 level up)
                return [
                    "Just a bit better than expected!",
                    "You edged past your prediction",
                    "A little extra focus magic ✨",
                    "Slightly underestimated yourself"
                ]
            }
        case .spotOn:
            return [
                "Perfect prediction!",
                "You know yourself so well!",
                "Nailed it! Self-awareness on point",
                "Exactly as you predicted 🎯",
                "Your intuition is spot on"
            ]
        case .overestimated:
            let missedBy = predictedLevel - actualLevel
            if missedBy >= 3 {
                return [
                    "Tough session, but you tried",
                    "Some days are harder than others",
                    "The important thing: you showed up",
                    "Tomorrow is a fresh start"
                ]
            } else if missedBy == 2 {
                return [
                    "A bit off today, but that's okay",
                    "Not quite there, keep going!",
                    "Building awareness takes time",
                    "Progress isn't always linear"
                ]
            } else {
                return [
                    "So close to your prediction!",
                    "Just slightly off—nearly nailed it",
                    "Almost there! Great effort",
                    "One level off is still solid"
                ]
            }
        }
    }

    var body: some View {
        ZStack {
            // Animated gradient background
            backgroundGradient

            // Floating particles for celebration
            if particlesVisible && comparisonType != .overestimated {
                ParticleView(color: comparisonType.color)
            }

            VStack(spacing: 0) {
                Spacer()

                // Main score ring
                ZStack {
                    // Outer glow
                    Circle()
                        .stroke(comparisonType.color.opacity(0.2), lineWidth: 24)
                        .frame(width: 200, height: 200)
                        .blur(radius: 10)
                        .scaleEffect(pulseScale)

                    // Background ring
                    Circle()
                        .stroke(Color.white.opacity(0.1), lineWidth: 12)
                        .frame(width: 200, height: 200)

                    // Progress ring
                    Circle()
                        .trim(from: 0, to: ringProgress * CGFloat(actualLevel) / 5.0)
                        .stroke(
                            AngularGradient(
                                colors: [comparisonType.color.opacity(0.6), comparisonType.color],
                                center: .center,
                                startAngle: .degrees(-90),
                                endAngle: .degrees(270)
                            ),
                            style: StrokeStyle(lineWidth: 12, lineCap: .round)
                        )
                        .frame(width: 200, height: 200)
                        .rotationEffect(.degrees(-90))
                        .shadow(color: comparisonType.color.opacity(0.5), radius: 8)

                    // Center content
                    VStack(spacing: 4) {
                        Text(celebrationEmoji)
                            .font(.system(size: 36))
                            .opacity(showScore ? 1 : 0)
                            .scaleEffect(showScore ? 1 : 0.5)

                        Text("\(actualLevel)")
                            .font(.system(size: 72, weight: .bold, design: .rounded))
                            .foregroundStyle(comparisonType.color)
                            .opacity(showScore ? 1 : 0)
                            .scaleEffect(showScore ? 1 : 0.8)

                        Text("out of 5")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(.white.opacity(0.5))
                            .opacity(showScore ? 1 : 0)
                    }
                }
                .padding(.bottom, 32)

                // Comparison cards
                HStack(spacing: 16) {
                    ComparisonCard(
                        title: "Predicted",
                        value: predictedLevel,
                        color: .orange,
                        icon: "brain.head.profile"
                    )
                    .opacity(showComparison ? 1 : 0)
                    .offset(x: showComparison ? 0 : -30)

                    // Arrow with animation
                    Image(systemName: comparisonType == .spotOn ? "equal" : (comparisonType == .underestimated ? "arrow.up.right" : "arrow.down.right"))
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(comparisonType.color)
                        .opacity(showComparison ? 1 : 0)
                        .scaleEffect(showComparison ? 1 : 0.5)

                    ComparisonCard(
                        title: "Actual",
                        value: actualLevel,
                        color: comparisonType.color,
                        icon: "flame.fill"
                    )
                    .opacity(showComparison ? 1 : 0)
                    .offset(x: showComparison ? 0 : 30)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 24)

                // Message banner
                VStack(spacing: 8) {
                    Text(titleForGap)
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(.white)

                    Text(messages.randomElement()!)
                        .font(.system(size: 15))
                        .foregroundStyle(.white.opacity(0.7))
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 32)
                .opacity(showMessage ? 1 : 0)
                .offset(y: showMessage ? 0 : 20)
                .padding(.bottom, 24)

                // Session summary card
                VStack(spacing: 0) {
                    HStack(spacing: 0) {
                        // Duration
                        StatItem(
                            icon: "hourglass.bottomhalf.filled",
                            label: "Duration",
                            value: "\(duration / 60) min",
                            color: .cyan
                        )

                        Divider()
                            .frame(height: 40)
                            .background(Color.white.opacity(0.1))

                        // Focus quality
                        StatItem(
                            icon: distractionCount == 0 ? "sparkles" : "eyes",
                            label: distractionCount == 0 ? "Deep Focus" : "Distractions",
                            value: distractionCount == 0 ? "Locked In" : "\(distractionCount) break\(distractionCount == 1 ? "" : "s")",
                            color: distractionCount == 0 ? .green : .orange
                        )

                        Divider()
                            .frame(height: 40)
                            .background(Color.white.opacity(0.1))

                        // Completion
                        StatItem(
                            icon: wasCompleted ? "trophy.fill" : "flag.fill",
                            label: "Status",
                            value: wasCompleted ? "Finished" : "Stopped",
                            color: wasCompleted ? .yellow : .orange
                        )
                    }
                }
                .padding(.vertical, 16)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.white.opacity(0.06))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(Color.white.opacity(0.08), lineWidth: 1)
                        )
                )
                .padding(.horizontal, 24)
                .opacity(showStats ? 1 : 0)
                .scaleEffect(showStats ? 1 : 0.95)
                .padding(.bottom, 32)

                Spacer()

                // Continue button with glow
                Button {
                    soundService.mediumImpact(settings: settings)
                    onDone()
                } label: {
                    Text("Continue")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            ZStack {
                                RoundedRectangle(cornerRadius: 14)
                                    .fill(comparisonType.color.opacity(0.3))
                                    .blur(radius: 8)
                                    .offset(y: 4)

                                RoundedRectangle(cornerRadius: 14)
                                    .fill(
                                        LinearGradient(
                                            colors: [comparisonType.color, comparisonType.color.opacity(0.8)],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                            }
                        )
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 40)
                .opacity(showButton ? 1 : 0)
                .offset(y: showButton ? 0 : 30)
            }
        }
        .onAppear {
            startAnimations()
        }
    }

    private var backgroundGradient: some View {
        ZStack {
            Color(red: 0.05, green: 0.05, blue: 0.08)

            // Radial glow at top
            RadialGradient(
                colors: [comparisonType.color.opacity(0.15), .clear],
                center: .top,
                startRadius: 50,
                endRadius: 400
            )

            // Subtle bottom gradient
            LinearGradient(
                colors: [.clear, comparisonType.color.opacity(0.05)],
                startPoint: .top,
                endPoint: .bottom
            )
        }
        .ignoresSafeArea()
    }

    private func startAnimations() {
        // Haptic feedback
        soundService.successHaptic(settings: settings)

        // Ring fills up
        withAnimation(.easeOut(duration: 1.0).delay(0.2)) {
            ringProgress = 1.0
        }

        // Score appears
        withAnimation(.spring(response: 0.5, dampingFraction: 0.7).delay(0.6)) {
            showScore = true
        }

        // Start pulse animation
        withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true).delay(1.0)) {
            pulseScale = 1.08
        }

        // Comparison slides in
        withAnimation(.spring(response: 0.5, dampingFraction: 0.8).delay(1.0)) {
            showComparison = true
        }

        // Message fades up
        withAnimation(.easeOut(duration: 0.4).delay(1.3)) {
            showMessage = true
        }

        // Stats appear
        withAnimation(.easeOut(duration: 0.4).delay(1.5)) {
            showStats = true
        }

        // Button slides up
        withAnimation(.spring(response: 0.5, dampingFraction: 0.8).delay(1.7)) {
            showButton = true
        }

        // Particles for celebration
        if comparisonType != .overestimated {
            withAnimation(.easeIn(duration: 0.3).delay(0.8)) {
                particlesVisible = true
            }
        }
    }
}

// MARK: - Supporting Views

private struct ComparisonCard: View {
    let title: String
    let value: Int
    let color: Color
    let icon: String

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundStyle(color)

            Text("\(value)")
                .font(.system(size: 32, weight: .bold, design: .rounded))
                .foregroundStyle(.white)

            Text(title)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.white.opacity(0.5))
        }
        .frame(width: 100, height: 100)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.white.opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(color.opacity(0.3), lineWidth: 1)
                )
        )
    }
}

private struct StatItem: View {
    let icon: String
    let label: String
    let value: String
    let color: Color

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundStyle(color)

            Text(value)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.8)

            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.white.opacity(0.4))
        }
        .frame(maxWidth: .infinity)
    }
}

private struct ParticleView: View {
    let color: Color

    @State private var particles: [Particle] = []

    struct Particle: Identifiable {
        let id = UUID()
        var x: CGFloat
        var y: CGFloat
        var scale: CGFloat
        var opacity: Double
        var rotation: Double
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                ForEach(particles) { particle in
                    Circle()
                        .fill(color)
                        .frame(width: 8, height: 8)
                        .scaleEffect(particle.scale)
                        .opacity(particle.opacity)
                        .position(x: particle.x, y: particle.y)
                        .rotationEffect(.degrees(particle.rotation))
                }
            }
            .onAppear {
                createParticles(in: geometry.size)
            }
        }
        .allowsHitTesting(false)
    }

    private func createParticles(in size: CGSize) {
        for i in 0..<20 {
            let particle = Particle(
                x: CGFloat.random(in: 50...(size.width - 50)),
                y: size.height + 50,
                scale: CGFloat.random(in: 0.3...1.0),
                opacity: Double.random(in: 0.3...0.8),
                rotation: Double.random(in: 0...360)
            )
            particles.append(particle)

            // Animate each particle upward
            let delay = Double(i) * 0.05
            withAnimation(.easeOut(duration: Double.random(in: 2.0...3.5)).delay(delay)) {
                if let index = particles.firstIndex(where: { $0.id == particle.id }) {
                    particles[index].y = CGFloat.random(in: -50...size.height * 0.3)
                    particles[index].opacity = 0
                }
            }
        }
    }
}

// MARK: - Comparison Type

private enum ComparisonType {
    case underestimated, spotOn, overestimated

    var title: String {
        switch self {
        case .underestimated: return "Better Than Expected! 🎉"
        case .spotOn: return "Perfect Prediction! 🎯"
        case .overestimated: return "Keep Growing 🌱"
        }
    }

    var color: Color {
        switch self {
        case .underestimated: return Color(red: 0.2, green: 0.8, blue: 0.4)
        case .spotOn: return Color(red: 0.3, green: 0.7, blue: 0.9)
        case .overestimated: return Color(red: 1.0, green: 0.6, blue: 0.2)
        }
    }
}

#Preview("Better than expected") {
    FocusPredictionResultView(
        predictedLevel: 3,
        actualLevel: 5,
        duration: 25 * 60,
        distractionCount: 0,
        wasCompleted: true,
        onDone: {}
    )
    .environment(SoundService())
    .environment(UserSettings())
}

#Preview("Spot on") {
    FocusPredictionResultView(
        predictedLevel: 4,
        actualLevel: 4,
        duration: 25 * 60,
        distractionCount: 1,
        wasCompleted: true,
        onDone: {}
    )
    .environment(SoundService())
    .environment(UserSettings())
}

#Preview("Room to grow") {
    FocusPredictionResultView(
        predictedLevel: 5,
        actualLevel: 3,
        duration: 25 * 60,
        distractionCount: 2,
        wasCompleted: false,
        onDone: {}
    )
    .environment(SoundService())
    .environment(UserSettings())
}
