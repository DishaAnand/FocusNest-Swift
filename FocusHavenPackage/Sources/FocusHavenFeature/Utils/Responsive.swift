import SwiftUI

public enum Responsive {
    private static let baseWidth: CGFloat = 390  // iPhone 12/13 width
    private static let baseHeight: CGFloat = 844 // iPhone 12/13 height
    private static let largeScreenThreshold: CGFloat = 768 // iPad

    private static var screenBounds: CGRect {
        guard let scene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first,
              let window = scene.windows.first else {
            return CGRect(x: 0, y: 0, width: baseWidth, height: baseHeight)
        }
        return window.bounds
    }

    public static func scale(_ size: CGFloat) -> CGFloat {
        let width = screenBounds.width
        let factor = width / baseWidth

        if width >= largeScreenThreshold {
            return size + (size * factor - size) * 0.5
        }
        return size * factor
    }

    public static func verticalScale(_ size: CGFloat) -> CGFloat {
        let bounds = screenBounds
        let height = bounds.height
        let factor = height / baseHeight

        if bounds.width >= largeScreenThreshold {
            return size + (size * factor - size) * 0.5
        }
        return size * factor
    }

    /// Moderate scaling with factor control
    /// Matches RN: `moderateScale(size, factor)`
    /// For iPad: returns adjusted * 0.9
    public static func moderateScale(_ size: CGFloat, factor: CGFloat = 0.5) -> CGFloat {
        let width = screenBounds.width
        let scaledSize = scale(size)
        let adjusted = size + (scaledSize - size) * factor

        // RN multiplies final result by 0.9 for large screens
        if width >= largeScreenThreshold {
            return adjusted * 0.9
        }
        return adjusted
    }
}
