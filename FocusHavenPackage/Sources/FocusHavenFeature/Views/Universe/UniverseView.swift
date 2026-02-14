import SwiftUI
import SwiftData

/// The personal universe view showing all celestial bodies from focus sessions
public struct UniverseView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \CelestialBody.createdAt, order: .forward) private var celestialBodies: [CelestialBody]

    @State private var scale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastScale: CGFloat = 1.0
    @State private var lastOffset: CGSize = .zero
    @State private var selectedStar: CelestialBody? = nil
    @State private var canvasSize: CGSize = .zero
    public init() {}

    public var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Deep space background
                spaceBackground

                // Stars and celestial bodies
                Canvas { context, size in
                    drawCelestialBodies(context: context, size: size)
                }
                .scaleEffect(scale)
                .offset(offset)
                .gesture(combinedGesture)
                .onTapGesture { location in
                    handleTap(at: location, in: geometry.size)
                }
                .onAppear {
                    canvasSize = geometry.size
                }
                .onChange(of: geometry.size) { _, newSize in
                    canvasSize = newSize
                }

                // Star detail card
                if let star = selectedStar {
                    StarDetailCard(star: star) {
                        withAnimation(.spring(response: 0.3)) {
                            selectedStar = nil
                        }
                    }
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }

                // Close button and debug button
                VStack {
                    HStack {
                        // Debug: Populate test data button
                        Button {
                            populateTestData()
                        } label: {
                            Image(systemName: "wand.and.stars")
                                .font(.system(size: 24))
                                .foregroundStyle(.yellow.opacity(0.7))
                                .symbolRenderingMode(.hierarchical)
                        }
                        .padding(.leading, 20)
                        .padding(.top, 60)

                        Spacer()

                        Button {
                            dismiss()
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 32))
                                .foregroundStyle(.white.opacity(0.6))
                                .symbolRenderingMode(.hierarchical)
                        }
                        .padding(.trailing, 20)
                        .padding(.top, 60)
                    }
                    Spacer()
                }

                // Empty state - only show when NO stars/planets exist
                if celestialBodies.isEmpty {
                    emptyState
                }
            }
        }
        .ignoresSafeArea()
        .statusBarHidden()
        .animation(.spring(response: 0.3), value: selectedStar?.id)
    }

    // MARK: - Background

    private var spaceBackground: some View {
        // Solid color matching the Canvas fill for seamless panning
        Color(red: 0.02, green: 0.02, blue: 0.06)
            .ignoresSafeArea()
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "sparkles")
                .font(.system(size: 48))
                .foregroundStyle(.white.opacity(0.3))

            Text("Your universe awaits")
                .font(.system(size: 20, weight: .medium))
                .foregroundStyle(.white.opacity(0.6))

            Text("Complete focus sessions to create stars")
                .font(.system(size: 14))
                .foregroundStyle(.white.opacity(0.4))
        }
    }

    // MARK: - Debug: Populate Test Data

    private func populateTestData() {
        // Clear existing celestial bodies first
        for body in celestialBodies {
            modelContext.delete(body)
        }

        // Create stars directly with varying recharge levels
        let testStars: [(recharge: Double, size: Double, taskName: String)] = [
            (10, 8, "Dim Star"),      // Very dim
            (25, 10, "Low Recharge"),  // Dim
            (40, 8, "Medium-Low"),     // Medium dim
            (60, 12, "Medium"),        // Medium bright
            (80, 10, "Bright"),        // Bright
            (100, 14, "Perfect 1"),    // Full brightness + halo
            (100, 12, "Perfect 2"),    // Full brightness + halo
            (50, 8, "Half Way"),       // Medium
            (75, 10, "Almost There"),  // Fairly bright
            (90, 12, "So Close"),      // Very bright
            (15, 6, "Quick Session"),  // Dim, small
            (100, 16, "Long Perfect")  // Full brightness + halo, large
        ]

        for (index, data) in testStars.enumerated() {
            // Spread stars across the canvas
            let angle = Double(index) * 0.5 + 0.2
            let radius = 0.15 + Double(index % 4) * 0.12
            let x = 0.5 + cos(angle * .pi * 2) * radius
            let y = 0.55 + sin(angle * .pi * 2) * radius * 0.7

            let star = CelestialBody(
                type: .star,
                taskName: data.taskName,
                position: CelestialPosition(x: min(max(x, 0.08), 0.92), y: min(max(y, 0.15), 0.85)),
                size: data.size,
                colorHex: "#FFFFFF",
                glowColorHex: data.recharge >= 100 ? "#FFD700" : "#87CEEB",
                createdAt: Date().addingTimeInterval(-Double(index) * 3600),
                isRecharged: data.recharge >= 100,
                rechargeLevel: data.recharge
            )
            modelContext.insert(star)
        }

        // Create 2 milestone planets directly (simulating 6 hours of focus)
        let planet1 = CelestialBody(
            type: .planet,
            taskName: "First Light",
            position: CelestialPosition(x: 0.25, y: 0.3),
            size: 14,
            colorHex: "#4A90D9",
            glowColorHex: "#6BB3F0",
            createdAt: Date(),
            weight: 3
        )
        modelContext.insert(planet1)

        let planet2 = CelestialBody(
            type: .planet,
            taskName: "Rising World",
            position: CelestialPosition(x: 0.75, y: 0.25),
            size: 18,
            colorHex: "#7B5BB7",
            glowColorHex: "#9B7DD4",
            createdAt: Date(),
            weight: 7
        )
        modelContext.insert(planet2)

        try? modelContext.save()
    }

    // MARK: - Tap Handling

    private func handleTap(at location: CGPoint, in size: CGSize) {
        // Adjust for scale and offset
        let adjustedX = (location.x - size.width / 2 - offset.width) / scale + size.width / 2
        let adjustedY = (location.y - size.height / 2 - offset.height) / scale + size.height / 2

        // Find the closest star within tap radius
        let tapRadius: CGFloat = 30.0

        var closestStar: CelestialBody? = nil
        var closestDistance: CGFloat = .infinity

        for body in celestialBodies {
            let starX = body.position.x * size.width
            let starY = body.position.y * size.height

            let distance = sqrt(pow(adjustedX - starX, 2) + pow(adjustedY - starY, 2))

            if distance < tapRadius && distance < closestDistance {
                closestDistance = distance
                closestStar = body
            }
        }

        if let star = closestStar {
            withAnimation(.spring(response: 0.3)) {
                selectedStar = star
            }
        } else {
            withAnimation(.spring(response: 0.3)) {
                selectedStar = nil
            }
        }
    }

    // MARK: - Gestures

    private var combinedGesture: some Gesture {
        SimultaneousGesture(magnificationGesture, dragGesture)
    }

    private var magnificationGesture: some Gesture {
        MagnificationGesture()
            .onChanged { value in
                let newScale = lastScale * value
                scale = min(max(newScale, 0.5), 3.0)
            }
            .onEnded { _ in
                lastScale = scale
            }
    }

    private var dragGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                offset = CGSize(
                    width: lastOffset.width + value.translation.width,
                    height: lastOffset.height + value.translation.height
                )
            }
            .onEnded { _ in
                lastOffset = offset
            }
    }

    // MARK: - Drawing

    private func drawCelestialBodies(context: GraphicsContext, size: CGSize) {
        // Fill extended area with deep space background (supports panning)
        // Using 5x area for generous panning room
        let extendedRect = CGRect(
            x: -size.width * 2,
            y: -size.height * 2,
            width: size.width * 5,
            height: size.height * 5
        )
        // Match the spaceBackground color exactly
        context.fill(
            Rectangle().path(in: extendedRect),
            with: .color(Color(red: 0.02, green: 0.02, blue: 0.06))
        )

        // Draw distant background stars (decorative) - covers extended area
        drawBackgroundStars(context: context, size: size, extendedArea: extendedRect)

        // Draw each celestial body
        for body in celestialBodies {
            switch body.type {
            case .star:
                drawStar(context: context, body: body, size: size)
            case .planet:
                drawPlanet(context: context, body: body, size: size)
            case .moon:
                break
            }
        }
    }

    private func drawBackgroundStars(context: GraphicsContext, size: CGSize, extendedArea: CGRect) {
        var generator = SeededRandomNumberGenerator(seed: 42)

        // Draw stars throughout the extended area for seamless panning
        for _ in 0..<500 {  // More stars for larger 5x area
            let x = CGFloat.random(in: extendedArea.minX...extendedArea.maxX, using: &generator)
            let y = CGFloat.random(in: extendedArea.minY...extendedArea.maxY, using: &generator)
            let starSize = CGFloat.random(in: 0.5...2.0, using: &generator)
            let opacity = Double.random(in: 0.2...0.5, using: &generator)

            let rect = CGRect(
                x: x - starSize / 2,
                y: y - starSize / 2,
                width: starSize,
                height: starSize
            )

            context.fill(
                Circle().path(in: rect),
                with: .color(.white.opacity(opacity))
            )
        }
    }

    private func drawStar(context: GraphicsContext, body: CelestialBody, size: CGSize) {
        let x = body.position.x * size.width
        let y = body.position.y * size.height
        let starSize = body.size
        let isSelected = selectedStar?.id == body.id
        let isRecharged = body.isRecharged

        // Recharged star: Extra outer halo (cyan-gold gradient effect) - makes fully recharged stars stand out
        if isRecharged {
            let rechargeHaloSize = starSize * 6.0
            let rechargeHaloRect = CGRect(
                x: x - rechargeHaloSize / 2,
                y: y - rechargeHaloSize / 2,
                width: rechargeHaloSize,
                height: rechargeHaloSize
            )

            // Cyan outer ring - more visible
            context.fill(
                Circle().path(in: rechargeHaloRect),
                with: .color(Color.cyan.opacity(0.25))
            )

            // Gold middle ring - brighter
            let goldHaloSize = starSize * 4.0
            let goldHaloRect = CGRect(
                x: x - goldHaloSize / 2,
                y: y - goldHaloSize / 2,
                width: goldHaloSize,
                height: goldHaloSize
            )
            context.fill(
                Circle().path(in: goldHaloRect),
                with: .color(Color(red: 1.0, green: 0.84, blue: 0.0).opacity(0.35))
            )
        }

        // Outer glow - opacity scales with recharge level (brighter = better break)
        let glowMultiplier: CGFloat = isRecharged ? 3.5 : (isSelected ? 4 : 3)
        let glowSize = starSize * glowMultiplier
        let glowRect = CGRect(
            x: x - glowSize / 2,
            y: y - glowSize / 2,
            width: glowSize,
            height: glowSize
        )

        // Use recharge-based opacity (0.3-1.0) multiplied by base
        let baseOpacity: CGFloat = isSelected ? 0.35 : 0.25
        let scaledOpacity = baseOpacity * body.glowOpacity
        context.fill(
            Circle().path(in: glowRect),
            with: .color(body.glowColor.opacity(scaledOpacity))
        )

        // Inner glow - also scales with recharge
        let innerGlowSize = starSize * (isSelected ? 2.2 : 1.8)
        let innerGlowRect = CGRect(
            x: x - innerGlowSize / 2,
            y: y - innerGlowSize / 2,
            width: innerGlowSize,
            height: innerGlowSize
        )

        let innerBaseOpacity: CGFloat = isSelected ? 0.5 : 0.4
        context.fill(
            Circle().path(in: innerGlowRect),
            with: .color(body.glowColor.opacity(innerBaseOpacity * body.glowOpacity))
        )

        // Core star
        let coreSize = isSelected ? starSize * 1.2 : starSize
        let coreRect = CGRect(
            x: x - coreSize / 2,
            y: y - coreSize / 2,
            width: coreSize,
            height: coreSize
        )

        context.fill(
            Circle().path(in: coreRect),
            with: .color(body.color)
        )
    }

    private func drawPlanet(context: GraphicsContext, body: CelestialBody, size: CGSize) {
        let x = body.position.x * size.width
        let y = body.position.y * size.height
        let planetSize = body.size * 2.5  // Slightly larger

        // Outer atmosphere glow (multiple layers for depth)
        for i in stride(from: 3, through: 1, by: -1) {
            let glowSize = planetSize * (1.0 + CGFloat(i) * 0.4)
            let glowRect = CGRect(
                x: x - glowSize / 2,
                y: y - glowSize / 2,
                width: glowSize,
                height: glowSize
            )
            context.fill(
                Circle().path(in: glowRect),
                with: .color(body.glowColor.opacity(0.08 / Double(i)))
            )
        }

        // Draw back rings first (behind planet) if milestone has rings (30+ hours)
        if body.hasRings {
            drawPlanetRings(context: context, x: x, y: y, planetSize: planetSize, color: body.glowColor, behind: true)
        }

        // Planet base (darker shade)
        let planetRect = CGRect(
            x: x - planetSize / 2,
            y: y - planetSize / 2,
            width: planetSize,
            height: planetSize
        )
        context.fill(
            Circle().path(in: planetRect),
            with: .color(body.color.opacity(0.9))
        )

        // 3D shading - dark side (bottom right)
        let shadowOffset: CGFloat = planetSize * 0.15
        let shadowRect = CGRect(
            x: x - planetSize / 2 + shadowOffset,
            y: y - planetSize / 2 + shadowOffset,
            width: planetSize,
            height: planetSize
        )
        context.fill(
            Circle().path(in: shadowRect),
            with: .color(Color.black.opacity(0.4))
        )

        // Re-draw planet on top to clip shadow
        context.fill(
            Circle().path(in: planetRect),
            with: .color(body.color)
        )

        // Surface bands (horizontal stripes for gas giant look)
        let bandCount = 4
        for i in 0..<bandCount {
            let bandY = y - planetSize / 2 + (planetSize / CGFloat(bandCount + 1)) * CGFloat(i + 1)
            let bandWidth = sqrt(pow(planetSize / 2, 2) - pow(bandY - y, 2)) * 2
            if bandWidth > 0 {
                let bandRect = CGRect(
                    x: x - bandWidth / 2,
                    y: bandY - 1.5,
                    width: bandWidth,
                    height: 3
                )
                context.fill(
                    Capsule().path(in: bandRect),
                    with: .color(body.glowColor.opacity(i % 2 == 0 ? 0.15 : 0.08))
                )
            }
        }

        // Highlight/shine (top left) - gives 3D spherical look
        let highlightSize = planetSize * 0.35
        let highlightOffset = planetSize * 0.2
        let highlightRect = CGRect(
            x: x - highlightOffset - highlightSize / 2,
            y: y - highlightOffset - highlightSize / 2,
            width: highlightSize,
            height: highlightSize
        )
        context.fill(
            Circle().path(in: highlightRect),
            with: .color(Color.white.opacity(0.25))
        )

        // Smaller bright spot
        let spotSize = planetSize * 0.12
        let spotRect = CGRect(
            x: x - highlightOffset * 0.8 - spotSize / 2,
            y: y - highlightOffset * 0.8 - spotSize / 2,
            width: spotSize,
            height: spotSize
        )
        context.fill(
            Circle().path(in: spotRect),
            with: .color(Color.white.opacity(0.5))
        )

        // Draw front rings (in front of planet) if milestone has rings (30+ hours)
        if body.hasRings {
            drawPlanetRings(context: context, x: x, y: y, planetSize: planetSize, color: body.glowColor, behind: false)
        }

        // Draw moons for 15+ hour milestone planets
        if body.hasMoons {
            // Number of moons based on milestone level (1 for 15h, 2 for 30h, 3 for 50h+)
            let moonCount: Int
            if body.weight >= 50 {
                moonCount = 3
            } else if body.weight >= 30 {
                moonCount = 2
            } else {
                moonCount = 1
            }
            drawMoons(context: context, x: x, y: y, planetSize: planetSize, count: moonCount, color: body.glowColor)
        }
    }

    private func drawMoons(context: GraphicsContext, x: CGFloat, y: CGFloat, planetSize: CGFloat, count: Int, color: Color) {
        // Max 3 moons, smaller and subtle
        let actualCount = min(count, 3)
        let orbitRadius = planetSize * 1.4
        let moonSizes: [CGFloat] = [5, 4, 3]

        for i in 0..<actualCount {
            let angle = (Double(i) * 100.0 - 40.0) * .pi / 180.0
            let moonX = x + cos(angle) * orbitRadius
            let moonY = y + sin(angle) * orbitRadius * 0.35
            let moonSize = moonSizes[i]

            // Subtle moon glow
            let glowRect = CGRect(x: moonX - moonSize, y: moonY - moonSize, width: moonSize * 2, height: moonSize * 2)
            context.fill(Circle().path(in: glowRect), with: .color(color.opacity(0.1)))

            // Moon body
            let moonRect = CGRect(x: moonX - moonSize / 2, y: moonY - moonSize / 2, width: moonSize, height: moonSize)
            context.fill(Circle().path(in: moonRect), with: .color(Color(white: 0.8)))
        }
    }

    private func drawPlanetRings(context: GraphicsContext, x: CGFloat, y: CGFloat, planetSize: CGFloat, color: Color, behind: Bool) {
        // Multiple ring layers for Saturn-like effect
        let ringConfigs: [(widthMult: CGFloat, opacity: Double, lineWidth: CGFloat)] = [
            (2.6, 0.25, 5),   // Outer ring
            (2.2, 0.35, 4),   // Middle ring
            (1.8, 0.3, 3),    // Inner ring
        ]

        for config in ringConfigs {
            let ringWidth = planetSize * config.widthMult
            let ringHeight = ringWidth * 0.25  // Flattened ellipse for tilted view

            let ringRect = CGRect(
                x: x - ringWidth / 2,
                y: y - ringHeight / 2,
                width: ringWidth,
                height: ringHeight
            )

            // Create ellipse path
            let ellipsePath = Ellipse().path(in: ringRect)

            if behind {
                // Draw only the back half (clip to top)
                var clipPath = Path()
                clipPath.addRect(CGRect(x: x - ringWidth, y: y - ringHeight - planetSize, width: ringWidth * 2, height: ringHeight + planetSize))

                context.stroke(
                    ellipsePath,
                    with: .color(color.opacity(config.opacity * 0.6)),  // Dimmer behind
                    lineWidth: config.lineWidth
                )
            } else {
                // Draw the front half on top of planet
                // Use a gradient-like effect with multiple strokes
                context.stroke(
                    ellipsePath,
                    with: .color(color.opacity(config.opacity)),
                    lineWidth: config.lineWidth
                )

                // Add a brighter inner edge
                context.stroke(
                    ellipsePath,
                    with: .color(Color.white.opacity(config.opacity * 0.3)),
                    lineWidth: config.lineWidth * 0.3
                )
            }
        }
    }

}

// MARK: - Star Detail Card

private struct StarDetailCard: View {
    let star: CelestialBody
    let onDismiss: () -> Void

    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: star.createdAt)
    }

    private var timeOfDay: String {
        let hour = Calendar.current.component(.hour, from: star.createdAt)
        switch hour {
        case 5..<11: return "Morning"
        case 11..<17: return "Afternoon"
        case 17..<21: return "Evening"
        default: return "Night"
        }
    }

    private var durationText: String {
        // Estimate duration from star size
        switch star.size {
        case 0..<6: return "5-14 min"
        case 6..<10: return "15-24 min"
        case 10..<14: return "25-44 min"
        default: return "45+ min"
        }
    }

    var body: some View {
        VStack {
            Spacer()

            VStack(spacing: 16) {
                // Handle bar
                RoundedRectangle(cornerRadius: 2)
                    .fill(.white.opacity(0.3))
                    .frame(width: 36, height: 4)
                    .padding(.top, 12)

                // Star preview
                ZStack {
                    Circle()
                        .fill(star.glowColor.opacity(0.2))
                        .frame(width: 60, height: 60)
                        .blur(radius: 10)

                    Circle()
                        .fill(star.color)
                        .frame(width: 24, height: 24)
                }

                // Task name
                Text(star.taskName.isEmpty ? "Focus Session" : star.taskName)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(.white)

                // Recharge level indicator
                if star.rechargeLevel > 0 {
                    HStack(spacing: 6) {
                        Image(systemName: star.isRecharged ? "bolt.fill" : "bolt")
                            .font(.system(size: 12))
                        Text(star.isRecharged ? "Fully Recharged" : "\(Int(star.rechargeLevel))% Recharged")
                            .font(.system(size: 14, weight: .medium))
                    }
                    .foregroundStyle(star.isRecharged ? .yellow : .cyan)
                }

                // Details grid
                HStack(spacing: 24) {
                    DetailItem(icon: "clock.fill", label: "Duration", value: durationText)
                    DetailItem(icon: "sun.horizon.fill", label: "Time", value: timeOfDay)
                }

                // Date
                Text(formattedDate)
                    .font(.system(size: 13))
                    .foregroundStyle(.white.opacity(0.5))

                // Close button
                Button {
                    onDismiss()
                } label: {
                    Text("Close")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(.white.opacity(0.7))
                        .padding(.horizontal, 32)
                        .padding(.vertical, 12)
                        .background(
                            Capsule()
                                .fill(.white.opacity(0.1))
                        )
                }
                .padding(.top, 8)
                .padding(.bottom, 24)
            }
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 24)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 24)
                            .stroke(.white.opacity(0.1), lineWidth: 1)
                    )
            )
            .padding(.horizontal, 16)
            .padding(.bottom, 16)
        }
    }
}

private struct DetailItem: View {
    let icon: String
    let label: String
    let value: String

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundStyle(.white.opacity(0.6))

            Text(value)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.white)

            Text(label)
                .font(.system(size: 11))
                .foregroundStyle(.white.opacity(0.4))
                .textCase(.uppercase)
        }
    }
}

// MARK: - Seeded Random Number Generator

struct SeededRandomNumberGenerator: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) {
        self.state = seed
    }

    mutating func next() -> UInt64 {
        state = state &* 6364136223846793005 &+ 1442695040888963407
        return state
    }
}

#Preview {
    UniverseView()
        .modelContainer(for: CelestialBody.self, inMemory: true)
}
