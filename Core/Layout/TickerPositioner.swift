import CoreGraphics

/// A display as the positioner sees it; built from `NSScreen` in the app.
public struct ScreenGeometry: Sendable, Equatable {
    public let displayID: UInt32
    /// Full display bounds in global coordinates.
    public let frame: CGRect
    /// Bounds without the menu bar and the Dock.
    public let visibleFrame: CGRect

    public init(displayID: UInt32, frame: CGRect, visibleFrame: CGRect) {
        self.displayID = displayID
        self.frame = frame
        self.visibleFrame = visibleFrame
    }
}

/// FR-1.2: where the ticker bar goes. `visibleFrame` already accounts for the taller menu bar
/// on notched displays and for the Dock, so the bar never sits under either.
public enum TickerPositioner {
    /// Fixed in V0.1; FR-1.7 makes it a setting in V0.2.
    public static let height: CGFloat = 24

    /// The preferred display if it is connected, otherwise the primary one (listed first).
    public static func screen(preferredDisplayID: UInt32?, among screens: [ScreenGeometry]) -> ScreenGeometry? {
        screens.first { $0.displayID == preferredDisplayID } ?? screens.first
    }

    public static func frame(on screen: ScreenGeometry, position: TickerPosition, height: CGFloat = height) -> CGRect {
        let visible = screen.visibleFrame
        let y = switch position {
        case .top: visible.maxY - height
        case .bottom: visible.minY
        }
        return CGRect(x: visible.minX, y: y, width: visible.width, height: height)
    }
}
