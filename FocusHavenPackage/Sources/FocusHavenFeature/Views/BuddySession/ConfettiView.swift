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

    @State private var showGlow = true
    @State private var glowOpacity: Double = 0.3
    @Environment(SoundService.self) private var soundService
    @Environment(UserSettings.self) private var settings

    var body: some View {
        ZStack {
            // Pulsing glow background
            Color.green
                .opacity(glowOpacity)
                .ignoresSafeArea()

            // Confetti
            ConfettiView()

            // Celebration text
            VStack(spacing: Theme.spacingL) {
                Image(systemName: "hands.clap.fill")
                    .font(.system(size: 80))
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.3), radius: 10)

                Text("You did it!")
                    .font(.system(size: 36, weight: .bold))
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.3), radius: 5)
            }
        }
        .onAppear {
            // Haptic feedback
            soundService.successHaptic(settings: settings)

            // Pulsing glow animation
            withAnimation(.easeInOut(duration: 0.5).repeatCount(3, autoreverses: true)) {
                glowOpacity = 0.6
            }

            // Auto-dismiss after 3 seconds
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                onComplete()
            }
        }
    }
}

#Preview {
    CelebrationOverlay(onComplete: {})
        .environment(SoundService())
        .environment(UserSettings())
}
