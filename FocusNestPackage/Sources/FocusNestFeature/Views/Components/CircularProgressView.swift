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

    public var body: some View {
        ZStack {
            Circle()
                .stroke(color.opacity(0.2), style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
            Circle()
                .trim(from: 0, to: CGFloat(min(progress, 1.0)))
                .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.easeInOut(duration: 0.3), value: progress)
            if showDot && progress > 0 {
                Circle()
                    .fill(color)
                    .frame(width: lineWidth + 4, height: lineWidth + 4)
                    .offset(y: -size / 2)
                    .rotationEffect(.degrees(360 * progress - 90))
                    .animation(.easeInOut(duration: 0.3), value: progress)
                    .shadow(color: color.opacity(0.5), radius: 4, x: 0, y: 0)
            }
        }
        .frame(width: size, height: size)
    }
}
