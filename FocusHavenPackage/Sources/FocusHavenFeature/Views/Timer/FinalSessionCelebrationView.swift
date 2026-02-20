import SwiftUI

/// Task breakdown item for celebration display
struct TaskBreakdownItem: Identifiable {
    let id: UUID
    let name: String
    let sessionCount: Int
}

/// Enhanced celebration view for completing all sessions in a plan
struct FinalSessionCelebrationView: View {
    let totalSessions: Int
    let totalMinutes: Int
    let totalDistractions: Int
    let taskBreakdown: [TaskBreakdownItem]  // Empty if no tasks assigned
    let onDone: () -> Void
    var onDismiss: (() -> Void)? = nil // optional close button handler

    // Prediction context (optional — shown when user used predict)
    var predictedLevel: Int? = nil
    var actualLevel: Int? = nil
    var predictionSessionCount: Int = 1  // How many sessions contributed to prediction average

    private var hasPrediction: Bool {
        predictedLevel != nil && actualLevel != nil
    }

    private var predictionComparison: String {
        guard let predicted = predictedLevel, let actual = actualLevel else { return "" }
        if actual > predicted { return "You did better than expected!" }
        else if actual == predicted { return "Spot on prediction!" }
        else { return "Keep calibrating!" }
    }

    private var predictionComparisonColor: Color {
        guard let predicted = predictedLevel, let actual = actualLevel else { return .cyan }
        if actual > predicted { return Color(red: 0.2, green: 0.8, blue: 0.4) }
        else if actual == predicted { return Color(red: 0.3, green: 0.7, blue: 0.9) }
        else { return Color(red: 1.0, green: 0.6, blue: 0.2) }
    }

    @Environment(SoundService.self) private var soundService
    @Environment(UserSettings.self) private var settings

    @State private var showPredictionCards = false

    // Animation states
    @State private var phase: AnimationPhase = .initial
    @State private var backgroundGlow: CGFloat = 0
    @State private var orbitRotation: Double = 0
    @State private var pulseScale: CGFloat = 1.0
    @State private var confettiTrigger = false
    @State private var countedMinutes: Int = 0
    @State private var trophyScale: CGFloat = 0
    @State private var statsOffset: CGFloat = 50
    @State private var buttonOffset: CGFloat = 100
    @State private var starBurst = false

    private enum AnimationPhase {
        case initial, burst, counting, reveal, complete
    }

    private var championTitle: String {
        switch totalSessions {
        case 1: return "Session Master"
        case 2: return "Double Feature"
        case 3: return "Focus Triple"
        case 4: return "Quad Legend"
        case 5: return "Focus Champion"
        default: return "Focus Champion"
        }
    }

    private var championEmoji: String {
        switch totalSessions {
        case 1: return "🌟"
        case 2: return "✨"
        case 3: return "🔥"
        case 4: return "💫"
        case 5: return "🏆"
        default: return "🏆"
        }
    }

    private var focusQuality: String {
        switch totalDistractions {
        case 0: return "Perfect focus across all sessions!"
        case 1: return "Nearly flawless concentration"
        case 2...3: return "Solid focus throughout"
        default: return "Great effort staying focused"
        }
    }

    var body: some View {
        ZStack {
            // Animated gradient background with gold/amber tones
            FinalCelebrationBackground(intensity: backgroundGlow)
                .ignoresSafeArea()

            // Golden orbiting particles
            GoldenOrbitingParticles(rotation: orbitRotation)
                .opacity(phase == .initial ? 0 : 1)

            // Star burst effect
            if starBurst {
                StarBurstEffect()
            }

            // Extra confetti burst
            if confettiTrigger {
                FinalConfetti()
            }

            // Main content
            VStack(spacing: 0) {
                // Close button (top right) - always reserve space for consistent layout
                HStack {
                    Spacer()
                    if let onDismiss = onDismiss {
                        Button {
                            soundService.lightImpact(settings: settings)
                            onDismiss()
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 28))
                                .foregroundStyle(.white.opacity(0.5))
                                .symbolRenderingMode(.hierarchical)
                        }
                        .opacity(phase == .complete ? 1 : 0)
                    }
                }
                .frame(height: 44)
                .padding(.horizontal, 20)
                .padding(.top, 16)

                Spacer()

                // Trophy/Achievement display
                ZStack {
                    // Pulsing glow rings with gold tint
                    ForEach(0..<3) { i in
                        Circle()
                            .stroke(
                                LinearGradient(
                                    colors: [.yellow.opacity(0.4), .orange.opacity(0.3)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 2
                            )
                            .frame(width: CGFloat(160 + i * 45), height: CGFloat(160 + i * 45))
                            .scaleEffect(pulseScale + CGFloat(i) * 0.05)
                            .opacity(phase == .initial ? 0 : 0.7 - Double(i) * 0.15)
                    }

                    // Main circle with trophy
                    ZStack {
                        // Glowing backdrop
                        Circle()
                            .fill(
                                RadialGradient(
                                    colors: [.yellow.opacity(0.5), .orange.opacity(0.2), .clear],
                                    center: .center,
                                    startRadius: 20,
                                    endRadius: 80
                                )
                            )
                            .frame(width: 160, height: 160)
                            .blur(radius: 15)

                        Circle()
                            .fill(Color(white: 0.1))
                            .frame(width: 130, height: 130)
                            .overlay(
                                Circle()
                                    .stroke(
                                        LinearGradient(
                                            colors: [.yellow, .orange],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        ),
                                        lineWidth: 4
                                    )
                            )

                        // Trophy with animated count
                        VStack(spacing: 4) {
                            Text(championEmoji)
                                .font(.system(size: 50))
                                .scaleEffect(trophyScale)

                            Text("\(countedMinutes)")
                                .font(.system(size: 28, weight: .bold, design: .rounded))
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [.white, .yellow.opacity(0.9)],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                )
                                .contentTransition(.numericText(countsDown: false))

                            Text(countedMinutes == 1 ? "minute" : "minutes")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(.white.opacity(0.6))
                                .textCase(.uppercase)
                                .tracking(1)
                        }
                    }
                    .scaleEffect(phase == .burst ? 1.15 : 1.0)
                }
                .padding(.bottom, 28)

                // Main title
                Text("All Sessions Complete!")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.white, .yellow.opacity(0.9)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .opacity(phase == .initial || phase == .burst ? 0 : 1)
                    .offset(y: phase == .reveal || phase == .complete ? 0 : 20)
                    .padding(.bottom, 8)

                Text("You crushed it!")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(.white.opacity(0.7))
                    .opacity(phase == .initial || phase == .burst ? 0 : 1)
                    .padding(.bottom, 24)

                // Stats cards
                VStack(spacing: 12) {
                    // Champion badge
                    HStack(spacing: 10) {
                        Text(championEmoji)
                            .font(.system(size: 24))

                        VStack(alignment: .leading, spacing: 2) {
                            Text(championTitle)
                                .font(.system(size: 16, weight: .bold))
                                .foregroundStyle(.white)

                            Text(focusQuality)
                                .font(.system(size: 12))
                                .foregroundStyle(.white.opacity(0.6))
                        }
                    }
                    .padding(.horizontal, 18)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .fill(.ultraThinMaterial)
                            .overlay(
                                RoundedRectangle(cornerRadius: 14)
                                    .stroke(
                                        LinearGradient(
                                            colors: [.yellow.opacity(0.4), .orange.opacity(0.2)],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        ),
                                        lineWidth: 1
                                    )
                            )
                    )

                    // Stats row
                    HStack(spacing: 16) {
                        StatBadge(
                            icon: "square.stack.3d.up.fill",
                            value: "\(totalSessions)",
                            label: totalSessions == 1 ? "session" : "sessions",
                            color: .purple
                        )

                        StatBadge(
                            icon: "clock.fill",
                            value: "\(totalMinutes)",
                            label: totalMinutes == 1 ? "minute" : "minutes",
                            color: .cyan
                        )

                        StatBadge(
                            icon: "eye.slash.fill",
                            value: "\(totalDistractions)",
                            label: totalDistractions == 1 ? "distraction" : "distractions",
                            color: totalDistractions == 0 ? .green : .orange
                        )
                    }

                    // Prediction comparison (when user used predict)
                    if hasPrediction, let predicted = predictedLevel, let actual = actualLevel {
                        VStack(spacing: 10) {
                            Text(predictionComparison)
                                .font(.system(size: 16, weight: .bold, design: .rounded))
                                .foregroundStyle(predictionComparisonColor)

                            HStack(spacing: 14) {
                                VStack(spacing: 4) {
                                    Image(systemName: "brain.head.profile")
                                        .font(.system(size: 14))
                                        .foregroundStyle(.orange)
                                    Text("\(predicted)")
                                        .font(.system(size: 24, weight: .bold, design: .rounded))
                                        .foregroundStyle(.white)
                                    Text(predictionSessionCount > 1 ? "Avg Predicted" : "Predicted")
                                        .font(.system(size: 10, weight: .medium))
                                        .foregroundStyle(.white.opacity(0.6))
                                        .textCase(.uppercase)
                                }
                                .frame(width: 95, height: 75)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(.orange.opacity(0.12))
                                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(.orange.opacity(0.2), lineWidth: 1))
                                )

                                Image(systemName: actual >= predicted ? "arrow.up.right" : "arrow.down.right")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundStyle(predictionComparisonColor)

                                VStack(spacing: 4) {
                                    Image(systemName: "flame.fill")
                                        .font(.system(size: 14))
                                        .foregroundStyle(predictionComparisonColor)
                                    Text("\(actual)")
                                        .font(.system(size: 24, weight: .bold, design: .rounded))
                                        .foregroundStyle(.white)
                                    Text(predictionSessionCount > 1 ? "Avg Actual" : "Actual")
                                        .font(.system(size: 10, weight: .medium))
                                        .foregroundStyle(.white.opacity(0.6))
                                        .textCase(.uppercase)
                                }
                                .frame(width: 95, height: 75)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(predictionComparisonColor.opacity(0.12))
                                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(predictionComparisonColor.opacity(0.2), lineWidth: 1))
                                )
                            }
                        }
                        .padding(.top, 12)
                        .opacity(showPredictionCards ? 1 : 0)
                        .offset(y: showPredictionCards ? 0 : 20)
                    }

                }
                .offset(y: statsOffset)
                .opacity(phase == .complete ? 1 : 0)

                Spacer()

                // Action buttons
                VStack(spacing: 0) {
                    // Done button
                    Button {
                        soundService.mediumImpact(settings: settings)
                        onDone()
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 18))
                            Text("Done")
                                .font(.system(size: 17, weight: .semibold))
                        }
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 18)
                        .background(
                            ZStack {
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(
                                        LinearGradient(
                                            colors: [.yellow, .orange],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(.white.opacity(0.15))
                                    .blur(radius: 0.5)
                            }
                        )
                        .shadow(color: .orange.opacity(0.5), radius: 15, x: 0, y: 8)
                    }

                }
                .padding(.horizontal, 24)
                .padding(.bottom, 50)
                .offset(y: buttonOffset)
                .opacity(phase == .complete ? 1 : 0)
                .frame(maxWidth: 400)  // iPad: constrain button width
                .frame(maxWidth: .infinity)  // Center on larger screens
            }
        }
        .onAppear {
            startCelebration()
        }
    }

    private func startCelebration() {
        // Initial haptic
        soundService.successHaptic(settings: settings)

        // Phase 1: Background comes alive
        withAnimation(.easeOut(duration: 0.6)) {
            backgroundGlow = 1.0
            phase = .burst
        }

        // Start orbit rotation
        withAnimation(.linear(duration: 25).repeatForever(autoreverses: false)) {
            orbitRotation = 360
        }

        // Trophy bounces in
        withAnimation(.spring(response: 0.5, dampingFraction: 0.6).delay(0.3)) {
            trophyScale = 1.0
        }

        // Phase 2: Burst animation
        withAnimation(.spring(response: 0.4, dampingFraction: 0.6).delay(0.2)) {
            pulseScale = 1.1
        }
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7).delay(0.4)) {
            pulseScale = 1.0
        }

        // Phase 3: Count up minutes
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            phase = .counting
            animateCounter()
        }

        // Phase 4: Reveal title
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                phase = .reveal
            }
        }

        // Phase 5: Star burst + confetti + final reveals
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) {
            starBurst = true
            soundService.lightImpact(settings: settings)
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) {
            confettiTrigger = true
            soundService.lightImpact(settings: settings)

            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                phase = .complete
                statsOffset = 0
                buttonOffset = 0
            }

            // Prediction cards slide in
            if hasPrediction {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.4)) {
                    showPredictionCards = true
                }
            }
        }

        // Continuous pulse effect
        withAnimation(.easeInOut(duration: 2.5).repeatForever(autoreverses: true).delay(2.5)) {
            pulseScale = 1.04
        }
    }

    private func animateCounter() {
        guard totalMinutes > 0 else {
            countedMinutes = max(1, totalMinutes)
            return
        }

        let animDuration = 0.7
        let steps = min(totalMinutes, 40)
        let interval = animDuration / Double(steps)

        for i in 1...steps {
            DispatchQueue.main.asyncAfter(deadline: .now() + interval * Double(i)) {
                withAnimation(.easeOut(duration: 0.1)) {
                    self.countedMinutes = (self.totalMinutes * i) / steps
                }
                if i == steps {
                    self.countedMinutes = self.totalMinutes
                }
            }
        }
    }
}

// MARK: - Stat Badge

private struct StatBadge: View {
    let icon: String
    let value: String
    let label: String
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundStyle(color)

            Text(value)
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundStyle(.white)

            Text(label)
                .font(.system(size: 10))
                .foregroundStyle(.white.opacity(0.5))
                .textCase(.uppercase)
        }
        .frame(minWidth: 70)
        .padding(.vertical, 12)
        .padding(.horizontal, 8)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.ultraThinMaterial)
        )
    }
}

// MARK: - Task Breakdown Row

private struct TaskBreakdownRow: View {
    let item: TaskBreakdownItem

    var body: some View {
        HStack(spacing: 12) {
            // Task icon with gradient
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [.purple.opacity(0.3), .pink.opacity(0.2)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 32, height: 32)

                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 16))
                    .foregroundStyle(.green)
            }

            // Task name
            Text(item.name)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.white)
                .lineLimit(1)

            Spacer()

            // Session count pill
            Text("\(item.sessionCount) session\(item.sessionCount > 1 ? "s" : "")")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.white.opacity(0.8))
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [.purple.opacity(0.4), .pink.opacity(0.3)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                )
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(
                            LinearGradient(
                                colors: [.purple.opacity(0.2), .pink.opacity(0.1)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
        )
        .padding(.horizontal, 20)
    }
}

// MARK: - Final Celebration Background

private struct FinalCelebrationBackground: View {
    let intensity: CGFloat
    @State private var animateGradient = false

    var body: some View {
        ZStack {
            // Base dark color with warm tint
            Color(red: 0.04, green: 0.02, blue: 0.02)

            // Animated gradient blobs with gold/amber
            GeometryReader { geometry in
                ZStack {
                    // Gold blob
                    Circle()
                        .fill(Color.yellow.opacity(0.12 * intensity))
                        .frame(width: 350, height: 350)
                        .blur(radius: 90)
                        .offset(
                            x: animateGradient ? 60 : -60,
                            y: animateGradient ? -120 : -180
                        )

                    // Orange blob
                    Circle()
                        .fill(Color.orange.opacity(0.1 * intensity))
                        .frame(width: 280, height: 280)
                        .blur(radius: 80)
                        .offset(
                            x: animateGradient ? -100 : 100,
                            y: animateGradient ? 220 : 160
                        )

                    // Subtle pink accent
                    Circle()
                        .fill(Color.pink.opacity(0.06 * intensity))
                        .frame(width: 220, height: 220)
                        .blur(radius: 70)
                        .offset(
                            x: animateGradient ? 120 : 70,
                            y: animateGradient ? 60 : 120
                        )
                }
                .frame(width: geometry.size.width, height: geometry.size.height)
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 5).repeatForever(autoreverses: true)) {
                animateGradient = true
            }
        }
    }
}

// MARK: - Golden Orbiting Particles

private struct GoldenOrbitingParticles: View {
    let rotation: Double

    var body: some View {
        GeometryReader { geometry in
            let centerX = geometry.size.width / 2
            let centerY = geometry.size.height * 0.32

            ZStack {
                ForEach(0..<10, id: \.self) { i in
                    let angle = Double(i) * .pi / 5 + rotation * .pi / 180
                    let radius = 90.0 + Double(i) * 12.0
                    let xOffset = cos(angle) * radius
                    let yOffset = sin(angle) * radius
                    let particleColor: Color = [.yellow, .orange, .yellow.opacity(0.8)][i % 3]
                    let size: CGFloat = CGFloat(3 + i % 4)

                    Circle()
                        .fill(particleColor.opacity(0.7))
                        .frame(width: size, height: size)
                        .offset(x: xOffset, y: yOffset)
                        .position(x: centerX, y: centerY)
                }
            }
        }
        .allowsHitTesting(false)
    }
}

// MARK: - Star Burst Effect

private struct StarBurstEffect: View {
    @State private var stars: [StarParticle] = []

    struct StarParticle: Identifiable {
        let id = UUID()
        var x: CGFloat
        var y: CGFloat
        var scale: CGFloat
        var rotation: Double
        var opacity: Double
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                ForEach(stars) { star in
                    Image(systemName: "star.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.yellow, .orange],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .scaleEffect(star.scale)
                        .rotationEffect(.degrees(star.rotation))
                        .position(x: star.x, y: star.y)
                        .opacity(star.opacity)
                }
            }
            .onAppear {
                createStarBurst(in: geometry.size)
            }
        }
        .allowsHitTesting(false)
    }

    private func createStarBurst(in size: CGSize) {
        let centerX = size.width / 2
        let centerY = size.height * 0.32

        for i in 0..<12 {
            let angle = Double(i) * .pi / 6
            var star = StarParticle(
                x: centerX,
                y: centerY,
                scale: 0.2,
                rotation: Double.random(in: 0...360),
                opacity: 1.0
            )
            stars.append(star)

            let targetX = centerX + cos(angle) * CGFloat.random(in: 100...180)
            let targetY = centerY + sin(angle) * CGFloat.random(in: 100...180)
            let targetRotation = star.rotation + Double.random(in: 180...540)

            withAnimation(.easeOut(duration: Double.random(in: 0.8...1.2)).delay(Double(i) * 0.03)) {
                if let index = stars.firstIndex(where: { $0.id == star.id }) {
                    stars[index].x = targetX
                    stars[index].y = targetY
                    stars[index].scale = CGFloat.random(in: 0.8...1.2)
                    stars[index].rotation = targetRotation
                }
            }

            withAnimation(.easeIn(duration: 0.5).delay(Double(i) * 0.03 + 0.8)) {
                if let index = stars.firstIndex(where: { $0.id == star.id }) {
                    stars[index].opacity = 0
                    stars[index].scale = 0
                }
            }
        }
    }
}

// MARK: - Final Confetti

private struct FinalConfetti: View {
    @State private var particles: [ConfettiParticle] = []

    struct ConfettiParticle: Identifiable {
        let id = UUID()
        var x: CGFloat
        var y: CGFloat
        var rotation: Double
        var scale: CGFloat
        let color: Color
        let shape: ConfettiShape
    }

    enum ConfettiShape {
        case circle, rectangle, star, diamond
    }

    private let colors: [Color] = [
        .yellow, .orange, .pink, .purple, .cyan, .mint, .white
    ]

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                ForEach(particles) { particle in
                    FinalConfettiPiece(shape: particle.shape, color: particle.color)
                        .frame(width: 10, height: 10)
                        .scaleEffect(particle.scale)
                        .rotationEffect(.degrees(particle.rotation))
                        .position(x: particle.x, y: particle.y)
                }
            }
            .onAppear {
                createConfetti(in: geometry.size)
            }
        }
        .allowsHitTesting(false)
    }

    private func createConfetti(in size: CGSize) {
        let centerX = size.width / 2
        let startY = size.height * 0.32

        for i in 0..<50 {
            let shape: ConfettiShape = [.circle, .rectangle, .star, .diamond].randomElement() ?? .circle
            var particle = ConfettiParticle(
                x: centerX,
                y: startY,
                rotation: Double.random(in: 0...360),
                scale: CGFloat.random(in: 0.5...1.3),
                color: colors.randomElement() ?? .white,
                shape: shape
            )
            particles.append(particle)

            let targetX = centerX + CGFloat.random(in: -200...200)
            let targetY = startY + CGFloat.random(in: 250...550)
            let targetRotation = particle.rotation + Double.random(in: 180...900)

            withAnimation(.easeOut(duration: Double.random(in: 1.8...2.8)).delay(Double(i) * 0.015)) {
                if let index = particles.firstIndex(where: { $0.id == particle.id }) {
                    particles[index].x = targetX
                    particles[index].y = targetY
                    particles[index].rotation = targetRotation
                    particles[index].scale = 0
                }
            }
        }
    }
}

private struct FinalConfettiPiece: View {
    let shape: FinalConfetti.ConfettiShape
    let color: Color

    var body: some View {
        switch shape {
        case .circle:
            Circle().fill(color)
        case .rectangle:
            RoundedRectangle(cornerRadius: 1)
                .fill(color)
                .frame(width: 8, height: 4)
        case .star:
            Image(systemName: "star.fill")
                .font(.system(size: 8))
                .foregroundStyle(color)
        case .diamond:
            Rectangle()
                .fill(color)
                .frame(width: 6, height: 6)
                .rotationEffect(.degrees(45))
        }
    }
}

// MARK: - Preview

#Preview {
    FinalSessionCelebrationView(
        totalSessions: 3,
        totalMinutes: 75,
        totalDistractions: 1,
        taskBreakdown: [
            TaskBreakdownItem(id: UUID(), name: "Build login feature", sessionCount: 2),
            TaskBreakdownItem(id: UUID(), name: "Write documentation", sessionCount: 1)
        ],
        onDone: { print("Done!") }
    )
    .environment(SoundService())
    .environment(UserSettings())
}
