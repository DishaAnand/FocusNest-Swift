import SwiftUI

/// A view modifier that adds a special recharged effect to stars
/// Shows a cyan-gold outer halo and orbiting sparkle particles
struct RechargedStarEffect: ViewModifier {
    let starSize: Double
    let isActive: Bool

    @State private var rotation: Double = 0
    @State private var pulseScale: CGFloat = 1.0
    @State private var sparkleOpacity: Double = 0.8

    private var haloSize: Double {
        starSize * 2.5
    }

    func body(content: Content) -> some View {
        if isActive {
            ZStack {
                // Outer halo (cyan-gold gradient)
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                Color.cyan.opacity(0.4),
                                Color(red: 1.0, green: 0.84, blue: 0.0).opacity(0.2), // Gold
                                Color.clear
                            ],
                            center: .center,
                            startRadius: starSize * 0.5,
                            endRadius: haloSize * 0.6
                        )
                    )
                    .frame(width: haloSize, height: haloSize)
                    .scaleEffect(pulseScale)
                    .blur(radius: 4)

                // Orbiting sparkles
                ForEach(0..<3) { index in
                    SparkleParticle(
                        size: max(3, starSize * 0.25),
                        orbitRadius: starSize * 1.2,
                        rotationOffset: Double(index) * 120 + rotation,
                        opacity: sparkleOpacity
                    )
                }

                // The original star content
                content
            }
            .onAppear {
                // Orbit animation
                withAnimation(.linear(duration: 6).repeatForever(autoreverses: false)) {
                    rotation = 360
                }

                // Pulse animation
                withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: true)) {
                    pulseScale = 1.15
                }

                // Sparkle twinkle
                withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
                    sparkleOpacity = 1.0
                }
            }
        } else {
            content
        }
    }
}

/// A small sparkle particle that orbits around the star
private struct SparkleParticle: View {
    let size: Double
    let orbitRadius: Double
    let rotationOffset: Double
    let opacity: Double

    var body: some View {
        Circle()
            .fill(
                RadialGradient(
                    colors: [.white, Color.cyan.opacity(0.8), .clear],
                    center: .center,
                    startRadius: 0,
                    endRadius: size * 0.6
                )
            )
            .frame(width: size, height: size)
            .offset(x: orbitRadius)
            .rotationEffect(.degrees(rotationOffset))
            .opacity(opacity)
    }
}

// MARK: - View Extension

extension View {
    /// Apply recharged star effect if the star was earned after a fully recharged break
    func rechargedStarEffect(starSize: Double, isRecharged: Bool) -> some View {
        modifier(RechargedStarEffect(starSize: starSize, isActive: isRecharged))
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()

        HStack(spacing: 60) {
            // Normal star
            VStack {
                Circle()
                    .fill(.white)
                    .frame(width: 12, height: 12)
                    .shadow(color: .white.opacity(0.6), radius: 8)
                Text("Normal")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.6))
            }

            // Recharged star
            VStack {
                Circle()
                    .fill(.white)
                    .frame(width: 12, height: 12)
                    .shadow(color: .white.opacity(0.6), radius: 8)
                    .rechargedStarEffect(starSize: 12, isRecharged: true)
                Text("Recharged")
                    .font(.caption)
                    .foregroundStyle(.cyan)
            }
        }
    }
}
