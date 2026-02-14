import SwiftUI

/// An animated energy orb that responds to movement intensity
struct EnergyOrbView: View {
    let rechargePercentage: Double // 0-100
    let movementIntensity: Double // 0-1

    // Animation states
    @State private var pulseScale: CGFloat = 1.0
    @State private var innerGlow: CGFloat = 0.5
    @State private var particles: [EnergyParticle] = []

    private let orbSize: CGFloat = 140

    // Color based on recharge level
    private var orbColor: Color {
        switch rechargePercentage {
        case 0..<25:
            return Theme.breakColor
        case 25..<50:
            return Color(red: 0.35, green: 0.75, blue: 0.85) // Shift toward cyan
        case 50..<75:
            return .cyan
        default:
            return Color(red: 0.4, green: 0.85, blue: 0.6) // Green/gold success
        }
    }

    private var glowColor: Color {
        orbColor.opacity(0.6)
    }

    // Dynamic glow size based on intensity
    private var outerGlowSize: CGFloat {
        80 + (movementIntensity * 40)
    }

    var body: some View {
        ZStack {
            // Outer glow - expands with intensity
            Circle()
                .fill(
                    RadialGradient(
                        colors: [glowColor, glowColor.opacity(0.3), .clear],
                        center: .center,
                        startRadius: 30,
                        endRadius: outerGlowSize
                    )
                )
                .frame(width: outerGlowSize * 2, height: outerGlowSize * 2)
                .blur(radius: 20)

            // Particle field
            TimelineView(.animation(minimumInterval: 1/30)) { timeline in
                let time = timeline.date.timeIntervalSinceReferenceDate

                Canvas { context, size in
                    let center = CGPoint(x: size.width / 2, y: size.height / 2)

                    for particle in particles {
                        let age = time - particle.startTime
                        let progress = min(1.0, age / particle.lifetime)

                        // Fade out over lifetime
                        let opacity = (1.0 - progress) * particle.opacity * movementIntensity

                        guard opacity > 0.01 else { continue }

                        // Radial movement outward
                        let distance = particle.startRadius + (progress * particle.speed * 60)
                        let angle = particle.angle + (time * particle.rotationSpeed)

                        let x = center.x + cos(angle) * distance
                        let y = center.y + sin(angle) * distance

                        let particleSize = particle.size * (1 - progress * 0.5)

                        // Draw the particle circle
                        let rect = CGRect(
                            x: x - particleSize / 2,
                            y: y - particleSize / 2,
                            width: particleSize,
                            height: particleSize
                        )
                        context.fill(
                            Path(ellipseIn: rect),
                            with: .color(orbColor.opacity(opacity))
                        )
                    }
                }
            }
            .frame(width: 280, height: 280)
            .onChange(of: movementIntensity) { _, intensity in
                // Emit particles when moving
                if intensity > 0.1 {
                    emitParticles(count: Int(intensity * 3) + 1)
                }
            }
            .task {
                // Continuous particle emission when tracking
                while !Task.isCancelled {
                    try? await Task.sleep(for: .milliseconds(100))
                    if movementIntensity > 0.05 {
                        emitParticles(count: 1)
                    }
                    // Clean up old particles
                    cleanupParticles()
                }
            }

            // Core orb
            ZStack {
                // Glowing backdrop
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [orbColor.opacity(0.5), orbColor.opacity(0.2), .clear],
                            center: .center,
                            startRadius: 20,
                            endRadius: 80
                        )
                    )
                    .frame(width: orbSize + 20, height: orbSize + 20)
                    .blur(radius: 10)

                // Main orb body
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                orbColor.opacity(0.9),
                                orbColor.opacity(0.6),
                                orbColor.opacity(0.3)
                            ],
                            center: .center,
                            startRadius: 10,
                            endRadius: orbSize / 2
                        )
                    )
                    .frame(width: orbSize, height: orbSize)
                    .overlay(
                        Circle()
                            .stroke(
                                LinearGradient(
                                    colors: [.white.opacity(0.4), orbColor.opacity(0.6)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 2
                            )
                    )
                    .scaleEffect(pulseScale)

                // Inner light - pulses faster with movement
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [.white.opacity(innerGlow), .clear],
                            center: .center,
                            startRadius: 0,
                            endRadius: 40
                        )
                    )
                    .frame(width: 60, height: 60)
                    .scaleEffect(pulseScale * 0.9)

                // Percentage display
                VStack(spacing: 2) {
                    Text("\(Int(rechargePercentage))")
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .contentTransition(.numericText())

                    Text("%")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.white.opacity(0.7))
                }
            }
        }
        .onAppear {
            startPulseAnimation()
        }
        .onChange(of: movementIntensity) { _, intensity in
            updatePulseSpeed(for: intensity)
        }
    }

    // MARK: - Animation Helpers

    private func startPulseAnimation() {
        withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: true)) {
            pulseScale = 1.05
            innerGlow = 0.7
        }
    }

    private func updatePulseSpeed(for intensity: Double) {
        // Faster pulse with more movement
        let duration = 2.0 - (intensity * 1.2) // 0.8 to 2 seconds
        withAnimation(.easeInOut(duration: max(0.5, duration)).repeatForever(autoreverses: true)) {
            pulseScale = 1.0 + (0.05 + intensity * 0.05)
            innerGlow = 0.5 + (intensity * 0.4)
        }
    }

    private func emitParticles(count: Int) {
        let currentTime = Date().timeIntervalSinceReferenceDate

        for _ in 0..<count {
            let particle = EnergyParticle(
                startTime: currentTime,
                lifetime: Double.random(in: 1.5...3.0),
                angle: Double.random(in: 0...(2 * .pi)),
                startRadius: Double.random(in: 70...80),
                speed: Double.random(in: 0.5...1.5),
                rotationSpeed: Double.random(in: -0.2...0.2),
                size: CGFloat.random(in: 3...8),
                opacity: Double.random(in: 0.4...0.8)
            )
            particles.append(particle)
        }
    }

    private func cleanupParticles() {
        let currentTime = Date().timeIntervalSinceReferenceDate
        particles.removeAll { particle in
            currentTime - particle.startTime > particle.lifetime
        }

        // Limit total particles
        if particles.count > 50 {
            particles.removeFirst(particles.count - 50)
        }
    }
}

// MARK: - Particle Model

private struct EnergyParticle: Identifiable {
    let id = UUID()
    let startTime: TimeInterval
    let lifetime: TimeInterval
    let angle: Double
    let startRadius: Double
    let speed: Double
    let rotationSpeed: Double
    let size: CGFloat
    let opacity: Double
}

// MARK: - Preview

#Preview("Idle") {
    ZStack {
        Color.black.ignoresSafeArea()
        EnergyOrbView(rechargePercentage: 0, movementIntensity: 0)
    }
}

#Preview("Moving - 25%") {
    ZStack {
        Color.black.ignoresSafeArea()
        EnergyOrbView(rechargePercentage: 25, movementIntensity: 0.5)
    }
}

#Preview("Active - 75%") {
    ZStack {
        Color.black.ignoresSafeArea()
        EnergyOrbView(rechargePercentage: 75, movementIntensity: 0.8)
    }
}

#Preview("Full - 100%") {
    ZStack {
        Color.black.ignoresSafeArea()
        EnergyOrbView(rechargePercentage: 100, movementIntensity: 1.0)
    }
}
