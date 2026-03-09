import SwiftUI

struct FocusPredictionResultView: View {
    let predictedLevel: Int
    let actualLevel: Int
    let duration: Int
    let distractionCount: Int
    let wasCompleted: Bool
    let onDone: () -> Void
    let onTakeBreak: () -> Void
    let onExtend: (Int) -> Void
    var onDismiss: (() -> Void)? = nil // optional close button handler

    // Cumulative focus time (for break guardian — tracks total focus without breaks)
    var continuousFocusTime: Int = 0

    // MARK: - Break Guardian Thresholds (in seconds)
    private let playfulNudgeThreshold = 25 * 60
    private let mandatoryBreakThreshold = 45 * 60

    @State private var ringProgress: CGFloat = 0
    @State private var showScore = false
    @State private var showComparison = false
    @State private var showMessage = false
    @State private var showStats = false
    @State private var showButton = false
    @State private var pulseScale: CGFloat = 1.0
    @State private var particlesVisible = false

    // Break Guardian states
    @State private var showExtendOptions = false
    @State private var showPlayfulNudge = false
    @State private var showMandatoryBreak = false
    @State private var mandatoryBreakRemaining: Int = 5 * 60 // 5 minutes
    @State private var mandatoryBreakTimer: Timer? = nil
    @State private var mandatoryBreakStartDate: Date? = nil
    private let mandatoryBreakDuration: Int = 5 * 60

    @Environment(\.scenePhase) private var scenePhase
    @Environment(SoundService.self) private var soundService
    @Environment(UserSettings.self) private var settings

    // Use cumulative focus time for break guardian thresholds
    private var effectiveDuration: Int {
        if continuousFocusTime > 0 {
            return continuousFocusTime
        }
        return duration > 0 ? duration : settings.focusDuration
    }

    // Break Guardian computed properties
    private var needsPlayfulNudge: Bool {
        effectiveDuration >= playfulNudgeThreshold && effectiveDuration < mandatoryBreakThreshold
    }

    private var needsMandatoryBreak: Bool {
        effectiveDuration >= mandatoryBreakThreshold
    }

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
                        .opacity(showButton ? 1 : 0)
                    }
                }
                .frame(height: 44)
                .padding(.horizontal, 20)
                .padding(.top, 16)

                Spacer(minLength: 20)

                // Main score ring (sized to fit with extend options)
                ZStack {
                    // Outer glow
                    Circle()
                        .stroke(comparisonType.color.opacity(0.2), lineWidth: 20)
                        .frame(width: 160, height: 160)
                        .blur(radius: 10)
                        .scaleEffect(pulseScale)

                    // Background ring
                    Circle()
                        .stroke(Color.white.opacity(0.1), lineWidth: 10)
                        .frame(width: 160, height: 160)

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
                            style: StrokeStyle(lineWidth: 10, lineCap: .round)
                        )
                        .frame(width: 160, height: 160)
                        .rotationEffect(.degrees(-90))
                        .shadow(color: comparisonType.color.opacity(0.5), radius: 8)

                    // Center content
                    VStack(spacing: 2) {
                        Text(celebrationEmoji)
                            .font(.system(size: 28))
                            .opacity(showScore ? 1 : 0)
                            .scaleEffect(showScore ? 1 : 0.5)

                        Text("\(actualLevel)")
                            .font(.system(size: 56, weight: .bold, design: .rounded))
                            .foregroundStyle(comparisonType.color)
                            .opacity(showScore ? 1 : 0)
                            .scaleEffect(showScore ? 1 : 0.8)

                        Text("out of 5")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.white.opacity(0.5))
                            .opacity(showScore ? 1 : 0)
                    }
                }
                .padding(.bottom, 24)

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

                    Text(messages.randomElement() ?? "")
                        .font(.system(size: 15))
                        .foregroundStyle(.white.opacity(0.7))
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 32)
                .opacity(showMessage ? 1 : 0)
                .offset(y: showMessage ? 0 : 20)
                .padding(.bottom, 16)

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
                            color: distractionCount == 0 ? .pink : .orange
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
                .padding(.bottom, 20)

                Spacer(minLength: 10)

                // Action buttons
                VStack(spacing: 16) {
                    // Primary: Done (dismiss summary)
                    Button {
                        soundService.mediumImpact(settings: settings)
                        if let onDismiss = onDismiss {
                            onDismiss()
                        } else {
                            onDone()
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

                    // Secondary: Keep Focusing (only show if NOT mandatory break)
                    if !needsMandatoryBreak {
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
                                    PredictionExtendButton(minutes: 15, color: .cyan) {
                                        soundService.mediumImpact(settings: settings)
                                        onExtend(15 * 60)
                                    }
                                    PredictionExtendButton(minutes: 25, color: .pink) {
                                        soundService.mediumImpact(settings: settings)
                                        onExtend(25 * 60)
                                    }
                                    PredictionExtendButton(minutes: 45, color: .orange) {
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
                .opacity(showButton ? 1 : 0)
                .offset(y: showButton ? 0 : 30)
                .frame(maxWidth: 400)  // iPad: constrain button width
                .frame(maxWidth: .infinity)  // Center on larger screens
            }
        }
        .onAppear {
            startAnimations()
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
            PredictionPlayfulNudgeView(
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
                PredictionMandatoryBreakView(
                    remainingSeconds: mandatoryBreakRemaining,
                    onBreakComplete: {
                        stopMandatoryBreakTimer()
                        withAnimation(.easeOut(duration: 0.3)) {
                            showMandatoryBreak = false
                        }
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

// MARK: - Extend Option Button

private struct PredictionExtendButton: View {
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

// MARK: - Playful Nudge View (45-59 min sessions)

private struct PredictionPlayfulNudgeView: View {
    let onTakeBreak: () -> Void
    let onContinueAnyway: () -> Void

    @State private var brainBounce: CGFloat = 1.0
    @State private var eyesClosed = false
    @State private var steamOffset: CGFloat = 0

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            // Tired Brain Character
            ZStack {
                // Steam/exhaustion lines
                ForEach(0..<3, id: \.self) { i in
                    PredictionWavyLine()
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
                    PredictionSleepyEye(isClosed: eyesClosed)
                    PredictionSleepyEye(isClosed: eyesClosed)
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
                Timer.scheduledTimer(withTimeInterval: 3, repeats: true) { _ in
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
private struct PredictionSleepyEye: View {
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
private struct PredictionWavyLine: Shape {
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

private struct PredictionMandatoryBreakView: View {
    let remainingSeconds: Int
    let onBreakComplete: () -> Void

    @State private var spotlightScale: CGFloat = 0.8
    @State private var lockRotation: Double = 0
    @State private var lockScale: CGFloat = 0
    @State private var showContent = false
    @State private var pulseRing: CGFloat = 1.0

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

#Preview("Better than expected") {
    FocusPredictionResultView(
        predictedLevel: 3,
        actualLevel: 5,
        duration: 25 * 60,
        distractionCount: 0,
        wasCompleted: true,
        onDone: {},
        onTakeBreak: {},
        onExtend: { _ in }
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
        onDone: {},
        onTakeBreak: {},
        onExtend: { _ in }
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
        onDone: {},
        onTakeBreak: {},
        onExtend: { _ in }
    )
    .environment(SoundService())
    .environment(UserSettings())
}
