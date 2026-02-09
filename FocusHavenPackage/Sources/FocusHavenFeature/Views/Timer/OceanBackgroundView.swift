import SwiftUI

/// A beautiful, serene ocean scene - soft organic waves with gentle light
struct OceanBackgroundView: View {
    let choppiness: Double
    var isBreakMode: Bool = false

    var body: some View {
        TimelineView(.animation(minimumInterval: 1/30)) { timeline in
            let time = timeline.date.timeIntervalSinceReferenceDate

            GeometryReader { geo in
                ZStack {
                    // Beautiful sky gradient - twilight colors
                    skyGradient

                    // Soft horizon glow
                    horizonGlow(size: geo.size)

                    // Ocean layers - back to front for depth
                    oceanLayer(
                        time: time,
                        size: geo.size,
                        yPosition: 0.48,
                        color: oceanColors.distant,
                        waveHeight: 6 + choppiness * 8,
                        speed: 0.12 + choppiness * 0.08
                    )

                    oceanLayer(
                        time: time,
                        size: geo.size,
                        yPosition: 0.55,
                        color: oceanColors.mid,
                        waveHeight: 10 + choppiness * 12,
                        speed: 0.18 + choppiness * 0.1
                    )

                    oceanLayer(
                        time: time,
                        size: geo.size,
                        yPosition: 0.63,
                        color: oceanColors.near,
                        waveHeight: 14 + choppiness * 16,
                        speed: 0.25 + choppiness * 0.12
                    )

                    // Front wave with highlight
                    oceanLayer(
                        time: time,
                        size: geo.size,
                        yPosition: 0.72,
                        color: oceanColors.front,
                        waveHeight: 18 + choppiness * 20,
                        speed: 0.3 + choppiness * 0.15
                    )

                    // Light shimmer on water
                    shimmerLayer(time: time, size: geo.size)

                    // Soft vignette for depth
                    vignette
                }
            }
        }
        .ignoresSafeArea()
    }

    // MARK: - Sky Gradient

    private var skyGradient: some View {
        LinearGradient(
            stops: isBreakMode ? [
                .init(color: Color(red: 0.08, green: 0.06, blue: 0.14), location: 0),
                .init(color: Color(red: 0.12, green: 0.10, blue: 0.20), location: 0.3),
                .init(color: Color(red: 0.18, green: 0.14, blue: 0.26), location: 0.5),
                .init(color: Color(red: 0.22, green: 0.18, blue: 0.30), location: 0.7),
                .init(color: Color(red: 0.16, green: 0.14, blue: 0.24), location: 1)
            ] : [
                .init(color: Color(red: 0.04, green: 0.06, blue: 0.12), location: 0),
                .init(color: Color(red: 0.06, green: 0.10, blue: 0.18), location: 0.25),
                .init(color: Color(red: 0.08, green: 0.16, blue: 0.26), location: 0.45),
                .init(color: Color(red: 0.10, green: 0.20, blue: 0.32), location: 0.6),
                .init(color: Color(red: 0.06, green: 0.14, blue: 0.24), location: 1)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    // MARK: - Horizon Glow

    private func horizonGlow(size: CGSize) -> some View {
        let glowColor = isBreakMode
            ? Color(red: 0.35, green: 0.25, blue: 0.45)
            : Color(red: 0.20, green: 0.40, blue: 0.55)

        return Ellipse()
            .fill(
                RadialGradient(
                    colors: [
                        glowColor.opacity(0.35),
                        glowColor.opacity(0.15),
                        Color.clear
                    ],
                    center: .center,
                    startRadius: 0,
                    endRadius: size.width * 0.7
                )
            )
            .frame(width: size.width * 1.5, height: size.height * 0.5)
            .position(x: size.width / 2, y: size.height * 0.48)
            .blur(radius: 30)
    }

    // MARK: - Ocean Colors

    private var oceanColors: (distant: Color, mid: Color, near: Color, front: Color) {
        if isBreakMode {
            return (
                distant: Color(red: 0.22, green: 0.20, blue: 0.32).opacity(0.6),
                mid: Color(red: 0.26, green: 0.24, blue: 0.38).opacity(0.7),
                near: Color(red: 0.30, green: 0.28, blue: 0.44).opacity(0.8),
                front: Color(red: 0.34, green: 0.32, blue: 0.50).opacity(0.9)
            )
        } else {
            return (
                distant: Color(red: 0.08, green: 0.22, blue: 0.34).opacity(0.6),
                mid: Color(red: 0.10, green: 0.28, blue: 0.42).opacity(0.7),
                near: Color(red: 0.12, green: 0.34, blue: 0.48).opacity(0.8),
                front: Color(red: 0.14, green: 0.38, blue: 0.52).opacity(0.9)
            )
        }
    }

    // MARK: - Ocean Wave Layer

    private func oceanLayer(
        time: Double,
        size: CGSize,
        yPosition: Double,
        color: Color,
        waveHeight: Double,
        speed: Double
    ) -> some View {
        Canvas { context, canvasSize in
            var path = Path()
            let baseY = canvasSize.height * yPosition

            path.move(to: CGPoint(x: 0, y: canvasSize.height))
            path.addLine(to: CGPoint(x: 0, y: baseY))

            // Create smooth organic wave using bezier curves
            let segments = 4
            let segmentWidth = canvasSize.width / CGFloat(segments)

            for i in 0..<segments {
                let startX = CGFloat(i) * segmentWidth
                let endX = startX + segmentWidth
                let midX = startX + segmentWidth / 2

                // Organic wave motion
                let phase1 = time * speed + Double(i) * 0.8
                let phase2 = time * speed * 0.7 + Double(i) * 1.2

                let startY = baseY + sin(phase1) * waveHeight
                let midY = baseY + sin(phase2) * waveHeight * 0.8
                let endY = baseY + sin(phase1 + 0.5) * waveHeight

                path.addCurve(
                    to: CGPoint(x: endX, y: endY),
                    control1: CGPoint(x: midX - segmentWidth * 0.2, y: midY - waveHeight * 0.3),
                    control2: CGPoint(x: midX + segmentWidth * 0.2, y: midY + waveHeight * 0.3)
                )
            }

            path.addLine(to: CGPoint(x: canvasSize.width, y: canvasSize.height))
            path.closeSubpath()

            // Fill with gradient for depth
            let gradient = Gradient(colors: [
                color,
                color.opacity(0.5)
            ])

            context.fill(
                path,
                with: .linearGradient(
                    gradient,
                    startPoint: CGPoint(x: 0, y: baseY),
                    endPoint: CGPoint(x: 0, y: canvasSize.height)
                )
            )
        }
    }

    // MARK: - Shimmer Layer

    private func shimmerLayer(time: Double, size: CGSize) -> some View {
        Canvas { context, canvasSize in
            let shimmerColor = (isBreakMode
                ? Color(red: 0.6, green: 0.5, blue: 0.7)
                : Color(red: 0.5, green: 0.7, blue: 0.8)
            ).opacity(0.15 - choppiness * 0.05)

            // Horizontal light streaks on water
            for i in 0..<6 {
                let baseY = canvasSize.height * (0.52 + Double(i) * 0.06)
                let wobble = sin(time * 0.4 + Double(i) * 0.7) * 8
                let width = 60 + sin(time * 0.3 + Double(i)) * 20
                let xOffset = sin(time * 0.2 + Double(i) * 1.3) * 30

                let rect = CGRect(
                    x: canvasSize.width / 2 - width / 2 + xOffset,
                    y: baseY + wobble,
                    width: width,
                    height: 2 + sin(time * 0.5 + Double(i)) * 1
                )

                context.fill(
                    Capsule().path(in: rect),
                    with: .color(shimmerColor.opacity(0.8 - Double(i) * 0.1))
                )
            }

            // Subtle light particles
            for i in 0..<12 {
                let seed = Double(i) * 1.7
                let x = (sin(seed * 2.3) * 0.4 + 0.5) * canvasSize.width
                let baseY = canvasSize.height * (0.50 + (sin(seed * 1.8) * 0.15 + 0.15))
                let y = baseY + sin(time * 0.3 + seed) * 5

                let twinkle = (sin(time * (1.5 + seed * 0.1) + seed) + 1) / 2
                let particleSize = 1.5 + twinkle * 1.5

                context.fill(
                    Circle().path(in: CGRect(
                        x: x - particleSize / 2,
                        y: y - particleSize / 2,
                        width: particleSize,
                        height: particleSize
                    )),
                    with: .color(shimmerColor.opacity(twinkle * 0.6))
                )
            }
        }
    }

    // MARK: - Vignette

    private var vignette: some View {
        RadialGradient(
            colors: [
                Color.clear,
                Color.black.opacity(0.2)
            ],
            center: .center,
            startRadius: 100,
            endRadius: 500
        )
    }
}

// MARK: - Previews

#Preview("Calm Ocean - Focus") {
    OceanBackgroundView(choppiness: 0.0)
}

#Preview("Slight Ripple") {
    OceanBackgroundView(choppiness: 0.3)
}

#Preview("Unsettled") {
    OceanBackgroundView(choppiness: 0.6)
}

#Preview("Break Mode - Calm") {
    OceanBackgroundView(choppiness: 0.0, isBreakMode: true)
}

#Preview("Break Mode - Ripple") {
    OceanBackgroundView(choppiness: 0.3, isBreakMode: true)
}
