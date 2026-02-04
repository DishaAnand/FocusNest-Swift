import SwiftUI

public struct PulsingIndicatorView: View {
    @State private var isAnimating = false
    let color: Color
    let size: CGFloat

    public init(color: Color = Theme.focusColor, size: CGFloat = 100) {
        self.color = color; self.size = size
    }

    public var body: some View {
        ZStack {
            ForEach(0..<3) { index in
                Circle()
                    .stroke(color.opacity(0.3), lineWidth: 2)
                    .frame(width: size, height: size)
                    .scaleEffect(isAnimating ? 1.5 + CGFloat(index) * 0.3 : 1)
                    .opacity(isAnimating ? 0 : 0.5)
                    .animation(.easeOut(duration: 1.5).repeatForever(autoreverses: false).delay(Double(index) * 0.3), value: isAnimating)
            }
            Circle()
                .fill(color)
                .frame(width: size * 0.4, height: size * 0.4)
                .scaleEffect(isAnimating ? 1.1 : 1.0)
                .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: isAnimating)
        }
        .onAppear { isAnimating = true }
    }
}
