import SwiftUI

/// A friendly animated companion that celebrates with you after focus sessions
struct FocusBuddy: View {
    let mood: BuddyMood

    enum BuddyMood {
        case celebrating   // 0 distractions - perfect!
        case happy         // 1-2 distractions - great job
        case encouraging   // 3+ distractions - still supportive
        case waving        // Stopped early - see you next time
    }

    // Animation states
    @State private var floatOffset: CGFloat = 0
    @State private var glowPulse: CGFloat = 1.0
    @State private var eyesClosed = false
    @State private var bodySquish: CGFloat = 1.0
    @State private var rotation: Double = 0
    @State private var sparkleOpacity: CGFloat = 0
    @State private var armWave: Double = 0
    @State private var bounceScale: CGFloat = 1.0

    private var primaryColor: Color {
        switch mood {
        case .celebrating: return .green
        case .happy: return .cyan
        case .encouraging: return .purple
        case .waving: return .orange
        }
    }

    private var secondaryColor: Color {
        switch mood {
        case .celebrating: return .mint
        case .happy: return .teal
        case .encouraging: return .pink
        case .waving: return .yellow
        }
    }

    var body: some View {
        ZStack {
            // Sparkles for celebrating mood
            if mood == .celebrating {
                CelebrationSparkles(opacity: sparkleOpacity)
            }

            // Main buddy body
            ZStack {
                // Outer glow
                Ellipse()
                    .fill(
                        RadialGradient(
                            colors: [
                                primaryColor.opacity(0.4),
                                primaryColor.opacity(0.1),
                                .clear
                            ],
                            center: .center,
                            startRadius: 20,
                            endRadius: 70
                        )
                    )
                    .frame(width: 140, height: 140)
                    .scaleEffect(glowPulse)
                    .blur(radius: 8)

                // Body
                BuddyBody(
                    primaryColor: primaryColor,
                    secondaryColor: secondaryColor,
                    squish: bodySquish
                )

                // Face
                BuddyFace(
                    mood: mood,
                    eyesClosed: eyesClosed
                )

                // Arms (for waving)
                if mood == .waving || mood == .celebrating {
                    BuddyArms(
                        color: primaryColor,
                        waveAngle: armWave,
                        isCelebrating: mood == .celebrating
                    )
                }
            }
            .scaleEffect(bounceScale)
            .rotationEffect(.degrees(rotation))
            .offset(y: floatOffset)
        }
        .frame(width: 160, height: 160)
        .onAppear {
            startAnimations()
        }
    }

    private func startAnimations() {
        // Gentle floating
        withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: true)) {
            floatOffset = -8
        }

        // Glow pulse
        withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
            glowPulse = 1.15
        }

        // Blinking
        startBlinking()

        // Mood-specific animations
        switch mood {
        case .celebrating:
            startCelebratingAnimations()
        case .happy:
            startHappyAnimations()
        case .encouraging:
            startEncouragingAnimations()
        case .waving:
            startWavingAnimations()
        }
    }

    private func startBlinking() {
        Timer.scheduledTimer(withTimeInterval: 3, repeats: true) { _ in
            withAnimation(.easeInOut(duration: 0.15)) {
                eyesClosed = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                withAnimation(.easeInOut(duration: 0.15)) {
                    eyesClosed = false
                }
            }
        }
    }

    private func startCelebratingAnimations() {
        // Sparkles fade in
        withAnimation(.easeOut(duration: 0.5)) {
            sparkleOpacity = 1.0
        }

        // Excited bouncing
        withAnimation(.spring(response: 0.3, dampingFraction: 0.5).repeatForever(autoreverses: true)) {
            bounceScale = 1.1
        }

        // Body squish with bounce
        withAnimation(.easeInOut(duration: 0.4).repeatForever(autoreverses: true)) {
            bodySquish = 0.9
        }

        // Arm waving (both arms up and down)
        withAnimation(.easeInOut(duration: 0.3).repeatForever(autoreverses: true)) {
            armWave = 25
        }

        // Slight rotation wiggle
        withAnimation(.easeInOut(duration: 0.2).repeatForever(autoreverses: true)) {
            rotation = 5
        }
    }

    private func startHappyAnimations() {
        // Gentle bounce
        withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
            bounceScale = 1.05
        }

        // Soft squish
        withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
            bodySquish = 0.95
        }
    }

    private func startEncouragingAnimations() {
        // Slow, calming movement
        withAnimation(.easeInOut(duration: 2.5).repeatForever(autoreverses: true)) {
            bounceScale = 1.03
        }

        // Gentle tilt
        withAnimation(.easeInOut(duration: 3).repeatForever(autoreverses: true)) {
            rotation = 3
        }
    }

    private func startWavingAnimations() {
        // Wave animation
        withAnimation(.easeInOut(duration: 0.5).repeatForever(autoreverses: true)) {
            armWave = 30
        }

        // Gentle movement
        withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
            bounceScale = 1.03
        }
    }
}

// MARK: - Buddy Body

private struct BuddyBody: View {
    let primaryColor: Color
    let secondaryColor: Color
    let squish: CGFloat

    var body: some View {
        ZStack {
            // Main body shape - slightly oval, blob-like
            Ellipse()
                .fill(
                    LinearGradient(
                        colors: [
                            secondaryColor.opacity(0.9),
                            primaryColor.opacity(0.8)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 80, height: 90)
                .scaleEffect(x: 1.0 / squish, y: squish)

            // Inner highlight
            Ellipse()
                .fill(
                    LinearGradient(
                        colors: [
                            .white.opacity(0.4),
                            .clear
                        ],
                        startPoint: .topLeading,
                        endPoint: .center
                    )
                )
                .frame(width: 60, height: 50)
                .offset(x: -8, y: -15)
                .scaleEffect(x: 1.0 / squish, y: squish)

            // Subtle inner glow
            Ellipse()
                .fill(
                    RadialGradient(
                        colors: [
                            .white.opacity(0.3),
                            .clear
                        ],
                        center: .center,
                        startRadius: 0,
                        endRadius: 30
                    )
                )
                .frame(width: 40, height: 45)
                .offset(y: -5)
        }
    }
}

// MARK: - Buddy Face

private struct BuddyFace: View {
    let mood: FocusBuddy.BuddyMood
    let eyesClosed: Bool

    private var eyeStyle: EyeStyle {
        switch mood {
        case .celebrating: return .sparkle
        case .happy: return .happy
        case .encouraging: return .gentle
        case .waving: return .friendly
        }
    }

    private var mouthStyle: MouthStyle {
        switch mood {
        case .celebrating: return .bigSmile
        case .happy: return .smile
        case .encouraging: return .softSmile
        case .waving: return .smile
        }
    }

    enum EyeStyle {
        case sparkle, happy, gentle, friendly
    }

    enum MouthStyle {
        case bigSmile, smile, softSmile
    }

    var body: some View {
        VStack(spacing: 8) {
            // Eyes
            HStack(spacing: 20) {
                BuddyEye(style: eyeStyle, isClosed: eyesClosed)
                BuddyEye(style: eyeStyle, isClosed: eyesClosed)
            }

            // Mouth
            BuddyMouth(style: mouthStyle)
        }
        .offset(y: -5)
    }
}

// MARK: - Buddy Eye

private struct BuddyEye: View {
    let style: BuddyFace.EyeStyle
    let isClosed: Bool

    var body: some View {
        ZStack {
            if isClosed {
                // Closed eye - curved line
                ClosedEye()
            } else {
                switch style {
                case .sparkle:
                    SparkleEye()
                case .happy:
                    HappyEye()
                case .gentle:
                    GentleEye()
                case .friendly:
                    FriendlyEye()
                }
            }
        }
        .frame(width: 16, height: 16)
    }
}

private struct ClosedEye: View {
    var body: some View {
        Path { path in
            path.move(to: CGPoint(x: 2, y: 8))
            path.addQuadCurve(
                to: CGPoint(x: 14, y: 8),
                control: CGPoint(x: 8, y: 12)
            )
        }
        .stroke(Color.white.opacity(0.9), lineWidth: 2.5)
        .frame(width: 16, height: 16)
    }
}

private struct SparkleEye: View {
    @State private var sparkle = false

    var body: some View {
        ZStack {
            // Eye base
            Circle()
                .fill(Color.white)
                .frame(width: 14, height: 14)

            // Pupil
            Circle()
                .fill(Color.black.opacity(0.8))
                .frame(width: 8, height: 8)

            // Sparkle highlight
            Circle()
                .fill(Color.white)
                .frame(width: 4, height: 4)
                .offset(x: -2, y: -2)

            // Extra sparkle for celebrating
            Image(systemName: "sparkle")
                .font(.system(size: 6))
                .foregroundStyle(.yellow)
                .offset(x: 4, y: -4)
                .opacity(sparkle ? 1 : 0.5)
                .scaleEffect(sparkle ? 1.2 : 0.8)
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 0.4).repeatForever(autoreverses: true)) {
                sparkle = true
            }
        }
    }
}

private struct HappyEye: View {
    var body: some View {
        ZStack {
            Circle()
                .fill(Color.white)
                .frame(width: 14, height: 14)

            Circle()
                .fill(Color.black.opacity(0.8))
                .frame(width: 8, height: 8)

            Circle()
                .fill(Color.white)
                .frame(width: 3, height: 3)
                .offset(x: -2, y: -2)
        }
    }
}

private struct GentleEye: View {
    var body: some View {
        ZStack {
            Circle()
                .fill(Color.white.opacity(0.9))
                .frame(width: 12, height: 12)

            Circle()
                .fill(Color.black.opacity(0.7))
                .frame(width: 6, height: 6)
                .offset(y: 1) // Looking slightly down - gentle

            Circle()
                .fill(Color.white)
                .frame(width: 2, height: 2)
                .offset(x: -1, y: -1)
        }
    }
}

private struct FriendlyEye: View {
    var body: some View {
        ZStack {
            Circle()
                .fill(Color.white)
                .frame(width: 13, height: 13)

            Circle()
                .fill(Color.black.opacity(0.8))
                .frame(width: 7, height: 7)

            Circle()
                .fill(Color.white)
                .frame(width: 3, height: 3)
                .offset(x: -1, y: -2)
        }
    }
}

// MARK: - Buddy Mouth

private struct BuddyMouth: View {
    let style: BuddyFace.MouthStyle

    var body: some View {
        switch style {
        case .bigSmile:
            BigSmileMouth()
        case .smile:
            SmileMouth()
        case .softSmile:
            SoftSmileMouth()
        }
    }
}

private struct BigSmileMouth: View {
    var body: some View {
        ZStack {
            // Mouth shape
            Path { path in
                path.move(to: CGPoint(x: 0, y: 0))
                path.addQuadCurve(
                    to: CGPoint(x: 24, y: 0),
                    control: CGPoint(x: 12, y: 16)
                )
            }
            .stroke(Color.white.opacity(0.9), style: StrokeStyle(lineWidth: 3, lineCap: .round))
            .frame(width: 24, height: 16)
        }
    }
}

private struct SmileMouth: View {
    var body: some View {
        Path { path in
            path.move(to: CGPoint(x: 0, y: 0))
            path.addQuadCurve(
                to: CGPoint(x: 18, y: 0),
                control: CGPoint(x: 9, y: 10)
            )
        }
        .stroke(Color.white.opacity(0.9), style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
        .frame(width: 18, height: 10)
    }
}

private struct SoftSmileMouth: View {
    var body: some View {
        Path { path in
            path.move(to: CGPoint(x: 0, y: 0))
            path.addQuadCurve(
                to: CGPoint(x: 14, y: 0),
                control: CGPoint(x: 7, y: 6)
            )
        }
        .stroke(Color.white.opacity(0.8), style: StrokeStyle(lineWidth: 2, lineCap: .round))
        .frame(width: 14, height: 6)
    }
}

// MARK: - Buddy Arms

private struct BuddyArms: View {
    let color: Color
    let waveAngle: Double
    let isCelebrating: Bool

    var body: some View {
        ZStack {
            // Left arm
            Capsule()
                .fill(color.opacity(0.8))
                .frame(width: 8, height: 25)
                .offset(x: -45, y: 5)
                .rotationEffect(.degrees(isCelebrating ? -30 - waveAngle : -20 - waveAngle), anchor: .bottom)

            // Right arm
            Capsule()
                .fill(color.opacity(0.8))
                .frame(width: 8, height: 25)
                .offset(x: 45, y: 5)
                .rotationEffect(.degrees(isCelebrating ? 30 + waveAngle : 20 + waveAngle), anchor: .bottom)
        }
    }
}

// MARK: - Celebration Sparkles

private struct CelebrationSparkles: View {
    let opacity: CGFloat

    @State private var sparklePositions: [(x: CGFloat, y: CGFloat, delay: Double)] = []
    @State private var animatedOpacities: [CGFloat] = []

    var body: some View {
        ZStack {
            ForEach(0..<8, id: \.self) { i in
                Image(systemName: "sparkle")
                    .font(.system(size: CGFloat.random(in: 8...14)))
                    .foregroundStyle(
                        [Color.yellow, .white, .cyan, .mint].randomElement()!
                    )
                    .offset(
                        x: sparklePositions.indices.contains(i) ? sparklePositions[i].x : 0,
                        y: sparklePositions.indices.contains(i) ? sparklePositions[i].y : 0
                    )
                    .opacity(animatedOpacities.indices.contains(i) ? Double(animatedOpacities[i]) : 0)
            }
        }
        .opacity(opacity)
        .onAppear {
            // Generate random positions around the buddy
            for i in 0..<8 {
                let angle = Double(i) * .pi / 4
                let radius = CGFloat.random(in: 50...80)
                let x = cos(angle) * Double(radius)
                let y = sin(angle) * Double(radius)
                sparklePositions.append((CGFloat(x), CGFloat(y), Double(i) * 0.1))
                animatedOpacities.append(0)
            }

            // Animate sparkles
            for i in 0..<8 {
                withAnimation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true).delay(sparklePositions[i].delay)) {
                    animatedOpacities[i] = CGFloat.random(in: 0.5...1.0)
                }
            }
        }
    }
}

// MARK: - Preview

#Preview("Celebrating") {
    ZStack {
        Color.black.ignoresSafeArea()
        FocusBuddy(mood: .celebrating)
    }
}

#Preview("Happy") {
    ZStack {
        Color.black.ignoresSafeArea()
        FocusBuddy(mood: .happy)
    }
}

#Preview("Encouraging") {
    ZStack {
        Color.black.ignoresSafeArea()
        FocusBuddy(mood: .encouraging)
    }
}

#Preview("Waving") {
    ZStack {
        Color.black.ignoresSafeArea()
        FocusBuddy(mood: .waving)
    }
}
