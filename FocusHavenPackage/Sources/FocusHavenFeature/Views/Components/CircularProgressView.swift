import SwiftUI

public struct CircularProgressView: View {
    let progress: Double
    let lineWidth: CGFloat
    let size: CGFloat
    let color: Color
    let showDot: Bool

    public init(progress: Double, lineWidth: CGFloat = 12, size: CGFloat = 280, color: Color = Theme.focusColor, showDot: Bool = true) {
        self.progress = progress
        self.lineWidth = lineWidth
        self.size = size
        self.color = color
        self.showDot = showDot
    }

    // Calculate dot position on the circle's circumference
    // Angle starts at 12 o'clock (-90°) and goes clockwise
    private var dotOffset: CGSize {
        let angle = 2 * Double.pi * progress - Double.pi / 2 // Start at top, go clockwise
        let radius = size / 2
        let x = radius * cos(angle)
        let y = radius * sin(angle)
        return CGSize(width: x, height: y)
    }

    public var body: some View {
        ZStack {
            Circle()
                .stroke(color.opacity(0.2), style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
            Circle()
                .trim(from: 0, to: CGFloat(min(progress, 1.0)))
                .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
            if showDot && progress > 0 {
                Circle()
                    .fill(color)
                    .frame(width: lineWidth + 4, height: lineWidth + 4)
                    .offset(dotOffset)
                    .shadow(color: color.opacity(0.5), radius: 4, x: 0, y: 0)
            }
        }
        .frame(width: size, height: size)
    }
}
