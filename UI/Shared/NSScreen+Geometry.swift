import AppKit
import NotchFeedCore

extension NSScreen {
    var displayID: UInt32? {
        (deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value
    }

    var geometry: ScreenGeometry? {
        displayID.map { ScreenGeometry(displayID: $0, frame: frame, visibleFrame: visibleFrame) }
    }

    /// The screen showing the ticker: the chosen display, or the primary one.
    static func tickerScreen(preferredDisplayID: UInt32?) -> NSScreen? {
        let geometries = screens.compactMap(\.geometry)
        guard let chosen = TickerPositioner.screen(preferredDisplayID: preferredDisplayID, among: geometries) else { return nil }
        return screens.first { $0.displayID == chosen.displayID }
    }
}
