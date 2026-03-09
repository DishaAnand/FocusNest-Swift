import SwiftUI
import SwiftData

struct SessionCompleteView: View {
    let duration: Int // in seconds (passed for display, but we also check settings)
    let distractionCount: Int // number of distractions during session
    let onTakeBreak: () -> Void
    let onExtend: (Int) -> Void // extension duration in seconds
    var onDismiss: (() -> Void)? = nil // optional close button handler

    // Prediction context (optional — shown when user used predict)
    var predictedLevel: Int? = nil
    var actualLevel: Int? = nil
    var wasCompleted: Bool = true

    // Session plan context (optional)
    var currentSession: Int? = nil
    var totalSessions: Int? = nil

    // Cumulative focus time (for break guardian — tracks total focus without breaks)
    var continuousFocusTime: Int = 0


    private var isSessionPlan: Bool {
        currentSession != nil && totalSessions != nil
    }

    private var hasPrediction: Bool {
        predictedLevel != nil && actualLevel != nil
    }

    private var predictionComparison: ComparisonType {
        guard let predicted = predictedLevel, let actual = actualLevel else { return .spotOn }
        if actual > predicted { return .underestimated }
        else if actual == predicted { return .spotOn }
        else { return .overestimated }
    }

    private var predictionTitle: String {
        guard let predicted = predictedLevel, let actual = actualLevel else { return "" }
        let gap = actual - predicted
        switch predictionComparison {
        case .underestimated:
            if gap >= 3 { return "Mind Blown!" }
            else if gap == 2 { return "Way Better!" }
            else { return "Nice Surprise!" }
        case .spotOn:
            return "Spot On!"
        case .overestimated:
            let missedBy = predicted - actual
            if missedBy >= 3 { return "Tough One" }
            else if missedBy == 2 { return "Keep Growing" }
            else { return "Almost There!" }
        }
    }

    @State private var showPredictionCards = false

    @Environment(\.scenePhase) private var scenePhase
    @Environment(SoundService.self) private var soundService
    @Environment(UserSettings.self) private var settings

    // MARK: - Break Guardian Thresholds (in seconds)
    private let playfulNudgeThreshold = 25 * 60
    private let mandatoryBreakThreshold = 45 * 60

    // Use cumulative focus time for break guardian thresholds
    // Falls back to single session duration if cumulative not provided
    private var effectiveDuration: Int {
        if continuousFocusTime > 0 {
            return continuousFocusTime
        }
        return duration > 0 ? duration : settings.focusDuration
    }

    // Phase-based animation system
    @State private var phase: AnimationPhase = .initial

    // Individual animation states
    @State private var backgroundGlow: CGFloat = 0
    @State private var orbitRotation: Double = 0
    @State private var pulseScale: CGFloat = 1.0
    @State private var confettiTrigger = false
    @State private var showExtendOptions = false
    @State private var countedMinutes: Int = 1  // Start at 1 to avoid showing 0
    @State private var streakScale: CGFloat = 0
    @State private var buttonOffset: CGFloat = 100

    // Break Guardian states
    @State private var showPlayfulNudge = false
    @State private var showMandatoryBreak = false
    @State private var mandatoryBreakRemaining: Int = 5 * 60 // 5 minutes
    @State private var mandatoryBreakTimer: Timer? = nil
    @State private var mandatoryBreakStartDate: Date? = nil
    private let mandatoryBreakDuration: Int = 5 * 60

    private enum AnimationPhase {
        case initial, burst, counting, reveal, complete
    }

    private var minutesEarned: Int { max(1, effectiveDuration / 60) }

    // Break Guardian computed properties
    private var needsPlayfulNudge: Bool {
        effectiveDuration >= playfulNudgeThreshold && effectiveDuration < mandatoryBreakThreshold
    }

    private var needsMandatoryBreak: Bool {
        effectiveDuration >= mandatoryBreakThreshold
    }

    private var focusEmoji: String {
        switch distractionCount {
        case 0: return "🎯"
        case 1: return "✨"
        case 2: return "👍"
        case 3: return "💪"
        default: return "🌱"
        }
    }

    private var focusTitle: String {
        switch distractionCount {
        case 0: return "Perfect Focus"
        case 1: return "Nearly Perfect"
        case 2: return "Solid Session"
        case 3: return "Good Effort"
        default: return "Keep Growing"
        }
    }

    private var distractionMessage: String {
        switch distractionCount {
        case 0: return "Zero distractions!"
        case 1: return "Only 1 distraction"
        default: return "\(distractionCount) distractions"
        }
    }

    var body: some View {
        ZStack {
            // Animated gradient background
            AnimatedGradientBackground(intensity: backgroundGlow)
                .ignoresSafeArea()

            // Orbiting particles
            OrbitingParticles(rotation: orbitRotation)
                .opacity(phase == .initial ? 0 : 1)

            // Confetti layer
            if confettiTrigger {
                SessionConfetti()
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

                // Central achievement display
                ZStack {
                    // Pulsing glow rings
                    ForEach(0..<3) { i in
                        Circle()
                            .stroke(
                                LinearGradient(
                                    colors: [.pink.opacity(0.3), .pink.opacity(0.2)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 2
                            )
                            .frame(width: CGFloat(140 + i * 40), height: CGFloat(140 + i * 40))
                            .scaleEffect(pulseScale + CGFloat(i) * 0.05)
                            .opacity(phase == .initial ? 0 : 0.6 - Double(i) * 0.15)
                    }

                    // Main circle with minutes counter
                    ZStack {
                        // Glowing backdrop
                        Circle()
                            .fill(
                                RadialGradient(
                                    colors: [.pink.opacity(0.4), .pink.opacity(0.1), .clear],
                                    center: .center,
                                    startRadius: 20,
                                    endRadius: 70
                                )
                            )
                            .frame(width: 140, height: 140)
                            .blur(radius: 10)

                        Circle()
                            .fill(Color(white: 0.1))
                            .frame(width: 120, height: 120)
                            .overlay(
                                Circle()
                                    .stroke(
                                        LinearGradient(
                                            colors: [.pink, .pink.opacity(0.7)],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        ),
                                        lineWidth: 4
                                    )
                            )

                        // Animated minute counter
                        VStack(spacing: 2) {
                            Text("\(countedMinutes)")
                                .font(.system(size: 44, weight: .bold, design: .rounded))
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [.white, .pink.opacity(0.9)],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                )
                                .contentTransition(.numericText(countsDown: false))

                            Text(countedMinutes == 1 ? "minute" : "minutes")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(.white.opacity(0.6))
                                .textCase(.uppercase)
                                .tracking(1.5)
                        }
                    }
                    .scaleEffect(phase == .burst ? 1.2 : 1.0)
                }
                .padding(.bottom, 32)

                // Title with gradient
                Text("Deep Work Complete")
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.white, .white.opacity(0.8)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .opacity(phase == .initial || phase == .burst ? 0 : 1)
                    .offset(y: phase == .reveal || phase == .complete ? 0 : 20)
                    .padding(.bottom, 24)

                // Session progress (for session plans)
                if isSessionPlan, let current = currentSession, let total = totalSessions {
                    HStack(spacing: 8) {
                        ForEach(0..<total, id: \.self) { index in
                            Circle()
                                .fill(index < current
                                      ? LinearGradient(colors: [.green, .mint], startPoint: .top, endPoint: .bottom)
                                      : LinearGradient(colors: [.white.opacity(0.3), .white.opacity(0.2)], startPoint: .top, endPoint: .bottom))
                                .frame(width: index < current ? 10 : 8, height: index < current ? 10 : 8)
                        }
                        Text("Session \(current) of \(total)")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(.white.opacity(0.7))
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(
                        Capsule()
                            .fill(.ultraThinMaterial)
                    )
                    .scaleEffect(streakScale)
                    .opacity(phase == .complete ? 1 : 0)
                    .padding(.bottom, 8)
                }

                // Achievement badge
                HStack(spacing: 12) {
                    // Focus emoji with bounce
                    Text(focusEmoji)
                        .font(.system(size: 28))
                        .scaleEffect(streakScale)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(focusTitle)
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(.white)

                        Text(distractionMessage)
                            .font(.system(size: 13))
                            .foregroundStyle(.white.opacity(0.6))
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(.ultraThinMaterial)
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(
                                    LinearGradient(
                                        colors: [.white.opacity(0.3), .white.opacity(0.1)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 1
                                )
                        )
                )
                .scaleEffect(streakScale)
                .opacity(phase == .complete ? 1 : 0)

                // Prediction comparison (when user used predict)
                if hasPrediction, let predicted = predictedLevel, let actual = actualLevel {
                    VStack(spacing: 12) {
                        Text(predictionTitle)
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                            .foregroundStyle(predictionComparison.color)

                        HStack(spacing: 16) {
                            PredictionCard(
                                title: "Predicted",
                                value: predicted,
                                color: .orange,
                                icon: "brain.head.profile"
                            )

                            Image(systemName: predictionComparison == .spotOn ? "equal" : (predictionComparison == .underestimated ? "arrow.up.right" : "arrow.down.right"))
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundStyle(predictionComparison.color)

                            PredictionCard(
                                title: "Actual",
                                value: actual,
                                color: predictionComparison.color,
                                icon: "flame.fill"
                            )
                        }
                    }
                    .padding(.top, 16)
                    .opacity(showPredictionCards ? 1 : 0)
                    .offset(y: showPredictionCards ? 0 : 20)
                }

                Spacer()

                // Action buttons
                VStack(spacing: 16) {
                    // Primary: Done (dismiss summary)
                    Button {
                        soundService.mediumImpact(settings: settings)
                        if let onDismiss = onDismiss {
                            onDismiss()
                        } else {
                            onTakeBreak()
                        }
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 18))
                            Text("Done")
                                .font(.system(size: 17, weight: .semibold))
                        }
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 18)
                        .background(
                            ZStack {
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(
                                        LinearGradient(
                                            colors: [Theme.focusColor, Theme.focusColor.opacity(0.7)],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(.white.opacity(0.1))
                                    .blur(radius: 0.5)
                            }
                        )
                        .shadow(color: Theme.focusColor.opacity(0.4), radius: 15, x: 0, y: 8)
                    }

                    // Secondary: Keep Focusing (only for single sessions, not session plans)
                    if !isSessionPlan && !needsMandatoryBreak {
                        VStack(spacing: 14) {
                            Button {
                                if needsPlayfulNudge {
                                    withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                                        showPlayfulNudge = true
                                    }
                                    soundService.lightImpact(settings: settings)
                                } else {
                                    withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
                                        showExtendOptions.toggle()
                                    }
                                    soundService.lightImpact(settings: settings)
                                }
                            } label: {
                                HStack(spacing: 8) {
                                    Image(systemName: "flame.fill")
                                        .font(.system(size: 14))
                                    Text("Keep the momentum")
                                        .font(.system(size: 15, weight: .medium))
                                    Image(systemName: showExtendOptions ? "chevron.up" : "chevron.down")
                                        .font(.system(size: 11, weight: .bold))
                                }
                                .foregroundStyle(.white.opacity(0.7))
                            }

                            if showExtendOptions {
                                HStack(spacing: 12) {
                                    ExtendOptionButton(minutes: 15, color: .cyan) {
                                        soundService.mediumImpact(settings: settings)
                                        onExtend(15 * 60)
                                    }
                                    ExtendOptionButton(minutes: 25, color: .pink) {
                                        soundService.mediumImpact(settings: settings)
                                        onExtend(25 * 60)
                                    }
                                    ExtendOptionButton(minutes: 45, color: .orange) {
                                        soundService.mediumImpact(settings: settings)
                                        onExtend(45 * 60)
                                    }
                                }
                                .transition(.asymmetric(
                                    insertion: .scale(scale: 0.8).combined(with: .opacity).combined(with: .offset(y: -10)),
                                    removal: .scale(scale: 0.9).combined(with: .opacity)
                                ))
                            }
                        }
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
            // Auto-show mandatory break for 60+ min sessions
            if needsMandatoryBreak {
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                    withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                        showMandatoryBreak = true
                    }
                    startMandatoryBreakTimer()
                }
            }
        }
        .sheet(isPresented: $showPlayfulNudge) {
            PlayfulNudgeView(
                onTakeBreak: {
                    showPlayfulNudge = false
                    onTakeBreak()
                },
                onContinueAnyway: {
                    showPlayfulNudge = false
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
                        showExtendOptions = true
                    }
                }
            )
            .presentationDetents([.medium])
            .presentationDragIndicator(.visible)
        }
        .overlay {
            if showMandatoryBreak {
                MandatoryBreakView(
                    remainingSeconds: mandatoryBreakRemaining,
                    onBreakComplete: {
                        stopMandatoryBreakTimer()
                        withAnimation(.easeOut(duration: 0.3)) {
                            showMandatoryBreak = false
                        }
                        // Dismiss back to focus screen
                        if let onDismiss {
                            onDismiss()
                        } else {
                            onTakeBreak()
                        }
                    }
                )
                .transition(.opacity.combined(with: .scale(scale: 1.1)))
            }
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active && showMandatoryBreak {
                recalcMandatoryBreakRemaining()
            }
        }
    }

    private func startMandatoryBreakTimer() {
        mandatoryBreakStartDate = Date()
        mandatoryBreakRemaining = mandatoryBreakDuration
        mandatoryBreakTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            Task { @MainActor in
                recalcMandatoryBreakRemaining()
            }
        }
    }

    private func recalcMandatoryBreakRemaining() {
        guard let startDate = mandatoryBreakStartDate else { return }
        let elapsed = Int(Date().timeIntervalSince(startDate))
        let remaining = max(0, mandatoryBreakDuration - elapsed)
        mandatoryBreakRemaining = remaining
        if remaining <= 0 {
            stopMandatoryBreakTimer()
        }
    }

    private func stopMandatoryBreakTimer() {
        mandatoryBreakTimer?.invalidate()
        mandatoryBreakTimer = nil
        mandatoryBreakStartDate = nil
    }

    private func startCelebration() {
        // Initial haptic
        soundService.successHaptic(settings: settings)

        // Phase 1: Background comes alive
        withAnimation(.easeOut(duration: 0.6)) {
            backgroundGlow = 1.0
            phase = .burst
        }

        // Start orbit rotation (continuous)
        withAnimation(.linear(duration: 20).repeatForever(autoreverses: false)) {
            orbitRotation = 360
        }

        // Phase 2: Burst animation
        withAnimation(.spring(response: 0.4, dampingFraction: 0.6).delay(0.2)) {
            pulseScale = 1.1
        }
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7).delay(0.4)) {
            pulseScale = 1.0
        }

        // Phase 3: Count up minutes
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            phase = .counting
            animateCounter()
        }

        // Phase 4: Reveal title
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                phase = .reveal
            }
        }

        // Phase 5: Confetti burst + final reveals
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            confettiTrigger = true
            soundService.lightImpact(settings: settings)

            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                phase = .complete
                buttonOffset = 0
            }

            // Streak badge bounces in
            withAnimation(.spring(response: 0.4, dampingFraction: 0.5).delay(0.2)) {
                streakScale = 1.0
            }

            // Prediction cards slide in
            if hasPrediction {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.4)) {
                    showPredictionCards = true
                }
            }
        }

        // Continuous pulse effect
        withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: true).delay(2)) {
            pulseScale = 1.03
        }
    }

    private func animateCounter() {
        // Guard against 0 minutes (happens with very short durations)
        guard minutesEarned > 0 else {
            countedMinutes = max(1, minutesEarned) // Show at least 1
            return
        }

        let animDuration = 0.6
        let steps = min(minutesEarned, 30) // Cap animation steps
        let interval = animDuration / Double(steps)

        for i in 1...steps {
            DispatchQueue.main.asyncAfter(deadline: .now() + interval * Double(i)) {
                withAnimation(.easeOut(duration: 0.1)) {
                    self.countedMinutes = (self.minutesEarned * i) / steps
                }
                if i == steps {
                    self.countedMinutes = self.minutesEarned
                }
            }
        }
    }
}

// MARK: - Animated Gradient Background

private struct AnimatedGradientBackground: View {
    let intensity: CGFloat
    @State private var animateGradient = false

    var body: some View {
        ZStack {
            // Base dark color
            Color(red: 0.02, green: 0.02, blue: 0.04)

            // Animated gradient blobs
            GeometryReader { geometry in
                ZStack {
                    // Green blob
                    Circle()
                        .fill(Color.pink.opacity(0.15 * intensity))
                        .frame(width: 300, height: 300)
                        .blur(radius: 80)
                        .offset(
                            x: animateGradient ? 50 : -50,
                            y: animateGradient ? -100 : -150
                        )

                    // Cyan blob
                    Circle()
                        .fill(Color.cyan.opacity(0.1 * intensity))
                        .frame(width: 250, height: 250)
                        .blur(radius: 70)
                        .offset(
                            x: animateGradient ? -80 : 80,
                            y: animateGradient ? 200 : 150
                        )

                    // Subtle purple accent
                    Circle()
                        .fill(Color.purple.opacity(0.08 * intensity))
                        .frame(width: 200, height: 200)
                        .blur(radius: 60)
                        .offset(
                            x: animateGradient ? 100 : 60,
                            y: animateGradient ? 50 : 100
                        )
                }
                .frame(width: geometry.size.width, height: geometry.size.height)
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 4).repeatForever(autoreverses: true)) {
                animateGradient = true
            }
        }
    }
}

// MARK: - Orbiting Particles

private struct OrbitingParticles: View {
    let rotation: Double

    var body: some View {
        GeometryReader { geometry in
            let centerX = geometry.size.width / 2
            let centerY = geometry.size.height * 0.35

            ZStack {
                ForEach(0..<8, id: \.self) { i in
                    let angle = Double(i) * .pi / 4 + rotation * .pi / 180
                    let radius = 80.0 + Double(i) * 10.0
                    let xOffset = cos(angle) * radius
                    let yOffset = sin(angle) * radius
                    let particleColor: Color = i % 2 == 0 ? .pink.opacity(0.6) : .pink.opacity(0.4)
                    let size: CGFloat = CGFloat(4 + i % 3)

                    Circle()
                        .fill(particleColor)
                        .frame(width: size, height: size)
                        .offset(x: xOffset, y: yOffset)
                        .position(x: centerX, y: centerY)
                }
            }
        }
        .allowsHitTesting(false)
    }
}

// MARK: - Confetti View

private struct SessionConfetti: View {
    @State private var particles: [SessionConfettiParticle] = []

    struct SessionConfettiParticle: Identifiable {
        let id = UUID()
        var x: CGFloat
        var y: CGFloat
        var rotation: Double
        var scale: CGFloat
        let color: Color
        let shape: SessionConfettiShape
    }

    enum SessionConfettiShape {
        case circle, rectangle, star
    }

    private let colors: [Color] = [
        .pink, .pink.opacity(0.7), .mint, .yellow, .orange, .purple, .cyan
    ]

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                ForEach(particles) { particle in
                    SessionConfettiPiece(shape: particle.shape, color: particle.color)
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
        let startY = size.height * 0.35

        for i in 0..<40 {
            let shape: SessionConfettiShape = [.circle, .rectangle, .star].randomElement() ?? .circle
            var particle = SessionConfettiParticle(
                x: centerX,
                y: startY,
                rotation: Double.random(in: 0...360),
                scale: CGFloat.random(in: 0.5...1.2),
                color: colors.randomElement() ?? .white,
                shape: shape
            )
            particles.append(particle)

            let targetX = centerX + CGFloat.random(in: -180...180)
            let targetY = startY + CGFloat.random(in: 200...500)
            let targetRotation = particle.rotation + Double.random(in: 180...720)

            withAnimation(.easeOut(duration: Double.random(in: 1.5...2.5)).delay(Double(i) * 0.02)) {
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

private struct SessionConfettiPiece: View {
    let shape: SessionConfetti.SessionConfettiShape
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
        }
    }
}

// MARK: - Playful Nudge View (45-59 min sessions)

struct PlayfulNudgeView: View {
    let onTakeBreak: () -> Void
    let onContinueAnyway: () -> Void

    @State private var brainBounce: CGFloat = 1.0
    @State private var eyesClosed = false
    @State private var steamOffset: CGFloat = 0
    @State private var blinkTimer: Timer?

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            // Tired Brain Character
            ZStack {
                // Steam/exhaustion lines
                ForEach(0..<3, id: \.self) { i in
                    WavyLine()
                        .stroke(Color.gray.opacity(0.4), lineWidth: 2)
                        .frame(width: 20, height: 30)
                        .offset(x: CGFloat(-30 + i * 30), y: -70 + steamOffset)
                        .opacity(0.6)
                }

                // Brain body
                Text("🧠")
                    .font(.system(size: 100))
                    .scaleEffect(brainBounce)

                // Sleepy eyes overlay
                HStack(spacing: 24) {
                    SleepyEye(isClosed: eyesClosed)
                    SleepyEye(isClosed: eyesClosed)
                }
                .offset(y: -10)

                // Coffee cup
                Text("☕")
                    .font(.system(size: 40))
                    .offset(x: 55, y: 30)
                    .rotationEffect(.degrees(-15))
            }
            .onAppear {
                // Gentle bounce
                withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: true)) {
                    brainBounce = 1.05
                }
                // Blink animation
                blinkTimer = Timer.scheduledTimer(withTimeInterval: 3, repeats: true) { _ in
                    withAnimation(.easeInOut(duration: 0.2)) {
                        eyesClosed = true
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            eyesClosed = false
                        }
                    }
                }
                // Steam float
                withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                    steamOffset = -10
                }
            }
            .onDisappear {
                blinkTimer?.invalidate()
                blinkTimer = nil
            }

            // Message
            VStack(spacing: 8) {
                Text("You've been crushing it!")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)

                Text("Your brain might thank you for a quick breather 🙏")
                    .font(.system(size: 16))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 24)

            Spacer()

            // Buttons
            VStack(spacing: 12) {
                Button {
                    onTakeBreak()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "cup.and.saucer.fill")
                        Text("Yeah, I'll take a break")
                    }
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .fill(Color.pink)
                    )
                }

                Button {
                    onContinueAnyway()
                } label: {
                    Text("I'm good, let's go!")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 4)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 40)
        }
        .background(Color(uiColor: .systemBackground))
    }
}

// Sleepy eye component
private struct SleepyEye: View {
    let isClosed: Bool

    var body: some View {
        ZStack {
            // Eye white
            Ellipse()
                .fill(.white)
                .frame(width: 20, height: isClosed ? 3 : 14)
                .shadow(color: .black.opacity(0.2), radius: 2)

            // Pupil
            if !isClosed {
                Circle()
                    .fill(.black)
                    .frame(width: 8, height: 8)
                    .offset(y: 2) // Looking down (tired)
            }
        }
    }
}

// Wavy steam line
private struct WavyLine: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.maxY))
        path.addCurve(
            to: CGPoint(x: rect.midX, y: rect.minY),
            control1: CGPoint(x: rect.minX, y: rect.midY + rect.height * 0.25),
            control2: CGPoint(x: rect.maxX, y: rect.midY - rect.height * 0.25)
        )
        return path
    }
}

// MARK: - Mandatory Break View (60+ min sessions)

struct MandatoryBreakView: View {
    let remainingSeconds: Int
    let onBreakComplete: () -> Void

    @State private var spotlightScale: CGFloat = 0.8
    @State private var lockRotation: Double = 0
    @State private var lockScale: CGFloat = 0
    @State private var showContent = false
    @State private var pulseRing: CGFloat = 1.0
    @State private var warningFlash = false

    private var formattedTime: String {
        let minutes = remainingSeconds / 60
        let seconds = remainingSeconds % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    var body: some View {
        ZStack {
            // Dark overlay
            Color.black.opacity(0.92)
                .ignoresSafeArea()

            // Spotlight effect
            RadialGradient(
                colors: [
                    Color.red.opacity(0.15),
                    Color.red.opacity(0.05),
                    Color.clear
                ],
                center: .center,
                startRadius: 50,
                endRadius: 300
            )
            .scaleEffect(spotlightScale)
            .ignoresSafeArea()

            // Warning pulse ring
            Circle()
                .stroke(Color.red.opacity(0.3), lineWidth: 3)
                .frame(width: 200, height: 200)
                .scaleEffect(pulseRing)
                .opacity(2 - pulseRing)

            // Main content
            VStack(spacing: 32) {
                // Lock icon with animation
                ZStack {
                    // Glow behind lock
                    Circle()
                        .fill(Color.red.opacity(0.2))
                        .frame(width: 120, height: 120)
                        .blur(radius: 20)

                    Image(systemName: "lock.fill")
                        .font(.system(size: 60, weight: .bold))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.red, .orange],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .rotationEffect(.degrees(lockRotation))
                        .scaleEffect(lockScale)
                }

                // Message
                VStack(spacing: 12) {
                    Text("Mandatory Pit Stop! 🏁")
                        .font(.system(size: 26, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)

                    Text("Okay champion, your brain needs\nat least 5 minutes to refuel")
                        .font(.system(size: 16))
                        .foregroundStyle(.white.opacity(0.7))
                        .multilineTextAlignment(.center)
                }
                .opacity(showContent ? 1 : 0)
                .offset(y: showContent ? 0 : 20)

                // Countdown timer
                VStack(spacing: 8) {
                    Text(formattedTime)
                        .font(.system(size: 48, weight: .bold, design: .monospaced))
                        .foregroundStyle(
                            remainingSeconds <= 60 ? .pink : .white
                        )
                        .contentTransition(.numericText())

                    Text(remainingSeconds > 0 ? "until you can continue" : "You're free!")
                        .font(.system(size: 14))
                        .foregroundStyle(.white.opacity(0.5))
                }
                .opacity(showContent ? 1 : 0)

            }
        }
        .onAppear {
            startAnimations()
        }
        .onChange(of: remainingSeconds) { _, newValue in
            if newValue <= 0 {
                onBreakComplete()
            }
        }
    }

    private func startAnimations() {
        // Spotlight pulse
        withAnimation(.easeOut(duration: 0.8)) {
            spotlightScale = 1.2
        }

        // Lock drops in with bounce
        withAnimation(.spring(response: 0.6, dampingFraction: 0.6).delay(0.2)) {
            lockScale = 1.0
        }

        // Lock shakes
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            withAnimation(.easeInOut(duration: 0.1).repeatCount(6, autoreverses: true)) {
                lockRotation = 10
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                lockRotation = 0
            }
        }

        // Content fades in
        withAnimation(.easeOut(duration: 0.5).delay(1.0)) {
            showContent = true
        }

        // Continuous pulse ring
        withAnimation(.easeOut(duration: 2).repeatForever(autoreverses: false)) {
            pulseRing = 2.0
        }
    }
}

// MARK: - Extend Option Button

private struct ExtendOptionButton: View {
    let minutes: Int
    let color: Color
    let action: () -> Void

    @State private var isPressed = false

    var body: some View {
        Button {
            action()
        } label: {
            VStack(spacing: 6) {
                Text("+\(minutes)")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                Text("min")
                    .font(.system(size: 11, weight: .medium))
                    .textCase(.uppercase)
                    .tracking(0.5)
            }
            .foregroundStyle(.white)
            .frame(width: 80, height: 70)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(color.opacity(0.2))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(color.opacity(0.4), lineWidth: 1.5)
                    )
            )
            .scaleEffect(isPressed ? 0.95 : 1.0)
        }
        .buttonStyle(.plain)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    withAnimation(.easeInOut(duration: 0.1)) { isPressed = true }
                }
                .onEnded { _ in
                    withAnimation(.easeInOut(duration: 0.1)) { isPressed = false }
                }
        )
    }
}

// MARK: - Prediction Card

private struct PredictionCard: View {
    let title: String
    let value: Int
    let color: Color
    let icon: String

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundStyle(color)

            Text("\(value)")
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundStyle(.white)

            Text(title)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.white.opacity(0.6))
                .textCase(.uppercase)
                .tracking(0.5)
        }
        .frame(width: 100, height: 90)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(color.opacity(0.12))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(color.opacity(0.2), lineWidth: 1)
                )
        )
    }
}

// MARK: - Comparison Type

private enum ComparisonType {
    case underestimated, spotOn, overestimated

    var color: Color {
        switch self {
        case .underestimated: return Color(red: 0.2, green: 0.8, blue: 0.4)
        case .spotOn: return Color(red: 0.3, green: 0.7, blue: 0.9)
        case .overestimated: return Color(red: 1.0, green: 0.6, blue: 0.2)
        }
    }
}

// MARK: - Preview

#Preview {
    SessionCompleteView(
        duration: 25 * 60,
        distractionCount: 1,
        onTakeBreak: { print("Take break") },
        onExtend: { mins in print("Extend by \(mins)") },
        predictedLevel: 3,
        actualLevel: 4
    )
    .environment(SoundService())
    .environment(UserSettings())
}
