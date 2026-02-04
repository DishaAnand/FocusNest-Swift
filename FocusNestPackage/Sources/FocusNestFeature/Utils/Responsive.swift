import SwiftUI

public enum Responsive {
    private static let baseWidth: CGFloat = 390  // iPhone 12/13 width
    private static let baseHeight: CGFloat = 844 // iPhone 12/13 height
    private static let largeScreenThreshold: CGFloat = 768 // iPad

    public static func scale(_ size: CGFloat) -> CGFloat {
        let width = UIScreen.main.bounds.width
        let factor = width / baseWidth

        if width >= largeScreenThreshold {
            return size + (size * factor - size) * 0.5
        }
        return size * factor
    }

    public static func verticalScale(_ size: CGFloat) -> CGFloat {
        let height = UIScreen.main.bounds.height
        let factor = height / baseHeight

        if UIScreen.main.bounds.width >= largeScreenThreshold {
            return size + (size * factor - size) * 0.5
        }
        return size * factor
    }

    public static func moderateScale(_ size: CGFloat, factor: CGFloat = 0.5) -> CGFloat {
        let width = UIScreen.main.bounds.width
        let scaledSize = scale(size)

        var adjustedFactor = factor
        if width >= largeScreenThreshold {
            adjustedFactor *= 0.9
        }

        return size + (scaledSize - size) * adjustedFactor
    }
}
