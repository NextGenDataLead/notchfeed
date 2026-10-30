import CoreGraphics

/// A window as `CGWindowListCopyWindowInfo` reports it, in global display coordinates
/// (origin at the top left of the primary display, y pointing down).
public struct WindowSnapshot: Sendable, Equatable {
    public let layer: Int
    public let bounds: CGRect

    public init(layer: Int, bounds: CGRect) {
        self.layer = layer
        self.bounds = bounds
    }
}

/// FR-1.1: is a full-screen app showing on a display? On macOS 26 the ticker panel joins
/// full-screen Spaces despite leaving out `.fullScreenAuxiliary`, so the window list decides.
/// A full-screen Space has a normal window covering the display from the menu bar line down,
/// and no menu bar items. A zoomed window can cover the same area (notch, hidden Dock), but
/// then the menu bar items are still on screen.
public enum FullScreenDetector {
    /// Space switches animate, so allow a little slack at the edges.
    static let tolerance: CGFloat = 1

    /// - Parameters:
    ///   - display: the display's bounds in global display coordinates.
    ///   - menuBarHeight: the height of its menu bar, 0 when the menu bar hides automatically.
    public static func isFullScreen(
        display: CGRect,
        menuBarHeight: CGFloat,
        windows: [WindowSnapshot],
        normalLayer: Int,
        statusItemLayer: Int
    ) -> Bool {
        let menuBar = CGRect(x: display.minX, y: display.minY, width: display.width, height: menuBarHeight)
        let hasMenuBarItems = windows.contains { $0.layer == statusItemLayer && $0.bounds.intersects(menuBar) }
        guard !hasMenuBarItems else { return false }
        return windows.contains { window in
            window.layer == normalLayer
                && window.bounds.minX <= display.minX + tolerance
                && window.bounds.maxX >= display.maxX - tolerance
                && window.bounds.minY <= display.minY + menuBarHeight + tolerance
                && window.bounds.maxY >= display.maxY - tolerance
        }
    }
}
