import SwiftUI

struct ConfettiPiece: Identifiable {
    let id = UUID()
    var x: CGFloat
    var y: CGFloat
    let color: Color
    let size: CGFloat
    let rotation: Double
    let xVelocity: CGFloat
}

struct ConfettiView: View {
    @State private var pieces: [ConfettiPiece] = []
    @State private var animate = false

    private let colors: [Color] = [
        Color(red: 0.38, green: 0.73, blue: 0.51), // Green
        Color(red: 1.0, green: 0.8, blue: 0.2),    // Yellow
        Color(red: 1.0, green: 0.6, blue: 0.2),    // Orange
        Color(red: 0.3, green: 0.6, blue: 1.0),    // Blue
        Color(red: 0.9, green: 0.3, blue: 0.5),    // Pink
    ]

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                ForEach(pieces) { piece in
                    Rectangle()
                        .fill(piece.color)
                        .frame(width: piece.size, height: piece.size * 1.5)
                        .rotationEffect(.degrees(piece.rotation + (animate ? 360 : 0)))
                        .position(
                            x: piece.x + (animate ? piece.xVelocity * 100 : 0),
                            y: animate ? geometry.size.height + 50 : piece.y
                        )
                        .opacity(animate ? 0 : 1)
                }
            }
            .onAppear {
                createPieces(in: geometry.size)
                withAnimation(.easeOut(duration: 3.0)) {
                    animate = true
                }
            }
        }
        .allowsHitTesting(false)
    }

    private func createPieces(in size: CGSize) {
        pieces = (0..<80).map { _ in
            ConfettiPiece(
                x: CGFloat.random(in: 0...size.width),
                y: CGFloat.random(in: -100...(-20)),
                color: colors.randomElement() ?? .green,
                size: CGFloat.random(in: 6...12),
                rotation: Double.random(in: 0...360),
                xVelocity: CGFloat.random(in: -2...2)
            )
        }
    }
}

struct CelebrationOverlay: View {
    let onComplete: () -> Void

    @State private var glowOpacity: Double = 0.3
    @State private var buddyScale: CGFloat = 0.3
    @State private var buddyOpacity: Double = 0
    @State private var textOffset: CGFloat = 30
    @State private var textOpacity: Double = 0
    @State private var sparklesVisible = false
    @Environment(SoundService.self) private var soundService
    @Environment(UserSettings.self) private var settings

    var body: some View {
        ZStack {
            // Animated gradient background
            RadialGradient(
                colors: [
                    Color.green.opacity(glowOpacity),
                    Color.mint.opacity(glowOpacity * 0.5),
                    Color.black.opacity(0.8)
                ],
                center: .center,
                startRadius: 50,
                endRadius: 400
            )
            .ignoresSafeArea()

            // Confetti
            ConfettiView()

            // Floating sparkles around buddy
            if sparklesVisible {
                CelebrationSparkles()
            }

            // Main celebration content
            VStack(spacing: Theme.spacingM) {
                // Cute mascot buddy
                FocusBuddy(mood: .celebrating)
                    .scaleEffect(buddyScale)
                    .opacity(buddyOpacity)

                // Celebration text
                VStack(spacing: 8) {
                    Text("You did it!")
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .shadow(color: .green.opacity(0.5), radius: 10)

                    Text("Amazing teamwork! 🎉")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(.white.opacity(0.8))
                }
                .offset(y: textOffset)
                .opacity(textOpacity)
            }
        }
        .onAppear {
            startCelebration()
        }
    }

    private func startCelebration() {
        // Haptic feedback
        soundService.successHaptic(settings: settings)

        // Background glow pulse
        withAnimation(.easeInOut(duration: 0.6).repeatCount(4, autoreverses: true)) {
            glowOpacity = 0.7
        }

        // Buddy bounces in
        withAnimation(.spring(response: 0.5, dampingFraction: 0.6)) {
            buddyScale = 1.0
            buddyOpacity = 1.0
        }

        // Sparkles appear
        withAnimation(.easeIn(duration: 0.3).delay(0.3)) {
            sparklesVisible = true
        }

        // Text slides up
        withAnimation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.4)) {
            textOffset = 0
            textOpacity = 1.0
        }

        // Auto-dismiss after 3.5 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.5) {
            onComplete()
        }
    }
}

// MARK: - Celebration Sparkles

private struct CelebrationSparkles: View {
    @State private var sparkles: [(id: UUID, x: CGFloat, y: CGFloat, scale: CGFloat, opacity: Double)] = []

    var body: some View {
        ZStack {
            ForEach(sparkles, id: \.id) { sparkle in
                Image(systemName: "sparkle")
                    .font(.system(size: 16))
                    .foregroundStyle([Color.yellow, .white, .cyan, .mint].randomElement()!)
                    .scaleEffect(sparkle.scale)
                    .opacity(sparkle.opacity)
                    .position(x: sparkle.x, y: sparkle.y)
            }
        }
        .onAppear {
            createSparkles()
        }
        .allowsHitTesting(false)
    }

    private func createSparkles() {
        for i in 0..<12 {
            let angle = Double(i) * .pi / 6
            let radius: CGFloat = CGFloat.random(in: 100...160)
            let centerX: CGFloat = UIScreen.main.bounds.width / 2
            let centerY: CGFloat = UIScreen.main.bounds.height / 2 - 40

            let sparkle = (
                id: UUID(),
                x: centerX + cos(angle) * radius,
                y: centerY + sin(angle) * radius,
                scale: CGFloat.random(in: 0.5...1.2),
                opacity: 0.0
            )
            sparkles.append(sparkle)

            // Animate each sparkle
            withAnimation(.easeInOut(duration: 0.5).repeatForever(autoreverses: true).delay(Double(i) * 0.08)) {
                if let index = sparkles.firstIndex(where: { $0.id == sparkle.id }) {
                    sparkles[index].opacity = Double.random(in: 0.6...1.0)
                    sparkles[index].scale = sparkle.scale * 1.3
                }
            }
        }
    }
}

#Preview {
    CelebrationOverlay(onComplete: {})
        .environment(SoundService())
        .environment(UserSettings())
}
