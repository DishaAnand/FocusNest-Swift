import SwiftUI

/// End-of-break celebration showing recharge results with star rewards
struct RechargeCompleteView: View {
    let rechargeLevel: Double // 0-100
    let onContinue: () -> Void
    var onDismiss: (() -> Void)? = nil // optional close button handler

    @Environment(SoundService.self) private var soundService
    @Environment(UserSettings.self) private var settings

    // Animation states
    @State private var backgroundGlow: CGFloat = 0
    @State private var percentageScale: CGFloat = 0
    @State private var starsRevealed: [Bool] = [false, false, false, false, false]
    @State private var messageOpacity: CGFloat = 0
    @State private var buttonOffset: CGFloat = 100
    @State private var confettiTrigger = false

    // Star calculation
    private var starCount: Int {
        switch rechargeLevel {
        case 0..<25: return 1
        case 25..<50: return 2
        case 50..<75: return 3
        case 75..<90: return 4
        default: return 5
        }
    }

    private var celebrationMessage: String {
        switch starCount {
        case 1: return "Good start! Move more next time"
        case 2: return "Nice effort! Keep it up"
        case 3: return "Well done! Great recharge"
        case 4: return "Excellent! Almost perfect"
        case 5: return "Perfect recharge! You're a star!"
        default: return "Break complete!"
        }
    }

    private var celebrationEmoji: String {
        switch starCount {
        case 1: return "👍"
        case 2: return "✨"
        case 3: return "🎯"
        case 4: return "🔥"
        case 5: return "🏆"
        default: return "⭐"
        }
    }

    var body: some View {
        ZStack {
            // Animated gradient background
            RechargeCompleteBackground(intensity: backgroundGlow, starCount: starCount)
                .ignoresSafeArea()

            // Confetti
            if confettiTrigger && starCount >= 4 {
                RechargeConfetti()
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
                        .opacity(messageOpacity)
                    }
                }
                .frame(height: 44)
                .padding(.horizontal, 20)
                .padding(.top, 16)

                Spacer()

                // Large percentage display with glow
                ZStack {
                    // Glow rings
                    ForEach(0..<3, id: \.self) { i in
                        Circle()
                            .stroke(
                                LinearGradient(
                                    colors: [Theme.breakColor.opacity(0.4), .cyan.opacity(0.3)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 2
                            )
                            .frame(width: CGFloat(140 + i * 35), height: CGFloat(140 + i * 35))
                            .scaleEffect(percentageScale)
                            .opacity(0.6 - Double(i) * 0.15)
                    }

                    // Main circle
                    ZStack {
                        Circle()
                            .fill(
                                RadialGradient(
                                    colors: [Theme.breakColor.opacity(0.4), Theme.breakColor.opacity(0.1), .clear],
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
                                            colors: [Theme.breakColor, .cyan],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        ),
                                        lineWidth: 4
                                    )
                            )

                        VStack(spacing: 2) {
                            Text("\(Int(rechargeLevel))")
                                .font(.system(size: 44, weight: .bold, design: .rounded))
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [.white, Theme.breakColor.opacity(0.9)],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                )

                            Text("%")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundStyle(.white.opacity(0.6))
                        }
                    }
                    .scaleEffect(percentageScale)
                }
                .padding(.bottom, 32)

                // Title
                Text("Break Complete!")
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .opacity(messageOpacity)
                    .padding(.bottom, 24)

                // Star row
                HStack(spacing: 12) {
                    ForEach(0..<5, id: \.self) { index in
                        Image(systemName: index < starCount ? "star.fill" : "star")
                            .font(.system(size: 32))
                            .foregroundStyle(
                                index < starCount
                                    ? LinearGradient(colors: [.yellow, .orange], startPoint: .top, endPoint: .bottom)
                                    : LinearGradient(colors: [.gray.opacity(0.3), .gray.opacity(0.2)], startPoint: .top, endPoint: .bottom)
                            )
                            .scaleEffect(starsRevealed[index] ? 1.0 : 0)
                            .shadow(color: index < starCount ? .yellow.opacity(0.5) : .clear, radius: 8)
                    }
                }
                .padding(.bottom, 20)

                // Celebration message
                HStack(spacing: 8) {
                    Text(celebrationEmoji)
                        .font(.system(size: 24))
                    Text(celebrationMessage)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(.white.opacity(0.8))
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(
                    Capsule()
                        .fill(.ultraThinMaterial)
                )
                .opacity(messageOpacity)

                Spacer()

                // Continue button
                Button {
                    soundService.mediumImpact(settings: settings)
                    onContinue()
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "arrow.right.circle.fill")
                            .font(.system(size: 18))
                        Text("Continue")
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
                                        colors: [Theme.breakColor, Theme.breakColor.opacity(0.7)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                            RoundedRectangle(cornerRadius: 16)
                                .fill(.white.opacity(0.1))
                                .blur(radius: 0.5)
                        }
                    )
                    .shadow(color: Theme.breakColor.opacity(0.4), radius: 15, x: 0, y: 8)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 50)
                .offset(y: buttonOffset)
                .frame(maxWidth: 400)
            }
        }
        .onAppear {
            startCelebration()
        }
    }

    // MARK: - Animation

    private func startCelebration() {
        // Initial haptic
        soundService.successHaptic(settings: settings)

        // Background glow
        withAnimation(.easeOut(duration: 0.6)) {
            backgroundGlow = 1.0
        }

        // Percentage scales in
        withAnimation(.spring(response: 0.5, dampingFraction: 0.7).delay(0.2)) {
            percentageScale = 1.0
        }

        // Stars reveal one by one
        for i in 0..<5 {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.6).delay(0.5 + Double(i) * 0.1)) {
                starsRevealed[i] = true
            }

            // Light haptic for earned stars
            if i < starCount {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5 + Double(i) * 0.1) {
                    soundService.lightImpact(settings: settings)
                }
            }
        }

        // Message and button
        withAnimation(.easeOut(duration: 0.4).delay(1.0)) {
            messageOpacity = 1.0
        }

        withAnimation(.spring(response: 0.5, dampingFraction: 0.8).delay(1.2)) {
            buttonOffset = 0
        }

        // Confetti for high scores
        if starCount >= 4 {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                confettiTrigger = true
            }
        }
    }
}

// MARK: - Background

private struct RechargeCompleteBackground: View {
    let intensity: CGFloat
    let starCount: Int
    @State private var animateGradient = false

    private var accentColor: Color {
        starCount >= 4 ? .yellow : Theme.breakColor
    }

    var body: some View {
        ZStack {
            Color(red: 0.02, green: 0.04, blue: 0.08)

            GeometryReader { geometry in
                ZStack {
                    Circle()
                        .fill(accentColor.opacity(0.15 * intensity))
                        .frame(width: 350, height: 350)
                        .blur(radius: 100)
                        .offset(
                            x: animateGradient ? 50 : -50,
                            y: animateGradient ? -100 : -150
                        )

                    Circle()
                        .fill(Color.cyan.opacity(0.1 * intensity))
                        .frame(width: 280, height: 280)
                        .blur(radius: 80)
                        .offset(
                            x: animateGradient ? -80 : 80,
                            y: animateGradient ? 200 : 150
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

// MARK: - Confetti

private struct RechargeConfetti: View {
    @State private var particles: [ConfettiParticle] = []

    private let colors: [Color] = [
        Theme.breakColor, .cyan, .yellow, .mint, .white
    ]

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                ForEach(particles) { particle in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(particle.color)
                        .frame(width: 8, height: 4)
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

        for i in 0..<30 {
            var particle = ConfettiParticle(
                x: centerX,
                y: startY,
                rotation: Double.random(in: 0...360),
                scale: CGFloat.random(in: 0.6...1.2),
                color: colors.randomElement()!
            )
            particles.append(particle)

            let targetX = centerX + CGFloat.random(in: -160...160)
            let targetY = startY + CGFloat.random(in: 180...450)
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

private struct ConfettiParticle: Identifiable {
    let id = UUID()
    var x: CGFloat
    var y: CGFloat
    var rotation: Double
    var scale: CGFloat
    let color: Color
}

// MARK: - Preview

#Preview("Low Recharge") {
    RechargeCompleteView(rechargeLevel: 20, onContinue: {})
        .environment(SoundService())
        .environment(UserSettings())
}

#Preview("Medium Recharge") {
    RechargeCompleteView(rechargeLevel: 55, onContinue: {})
        .environment(SoundService())
        .environment(UserSettings())
}

#Preview("High Recharge") {
    RechargeCompleteView(rechargeLevel: 85, onContinue: {})
        .environment(SoundService())
        .environment(UserSettings())
}

#Preview("Full Recharge") {
    RechargeCompleteView(rechargeLevel: 100, onContinue: {})
        .environment(SoundService())
        .environment(UserSettings())
}
