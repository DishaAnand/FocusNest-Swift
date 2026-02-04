import SwiftUI

public struct StarRatingView: View {
    @Binding var rating: Int
    let maxRating: Int
    let size: CGFloat

    public init(rating: Binding<Int>, maxRating: Int = 5, size: CGFloat = 32) {
        self._rating = rating; self.maxRating = maxRating; self.size = size
    }

    public var body: some View {
        HStack(spacing: Theme.spacingS) {
            ForEach(1...maxRating, id: \.self) { star in
                Image(systemName: star <= rating ? "star.fill" : "star")
                    .font(.system(size: size))
                    .foregroundStyle(star <= rating ? Color.yellow : Theme.textTertiary)
                    .onTapGesture { withAnimation(.easeInOut(duration: 0.2)) { rating = star } }
            }
        }
    }
}
