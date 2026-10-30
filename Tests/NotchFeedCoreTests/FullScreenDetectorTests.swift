import CoreGraphics
import Testing
@testable import NotchFeedCore

/// Window lists measured on a 14" MacBook Pro with notch running macOS 26 (1710 × 1107 pt,
/// 34 pt menu bar), with a test window entering full screen.
struct FullScreenDetectorTests {
    private static let normal = 0
    private static let statusItem = 25
    private let display = CGRect(x: 0, y: 0, width: 1710, height: 1107)
    private let menuBarHeight: CGFloat = 34
    private let menuBar = WindowSnapshot(layer: 24, bounds: CGRect(x: 0, y: 0, width: 1710, height: 34))
    private let clock = WindowSnapshot(layer: statusItem, bounds: CGRect(x: 1581, y: 0, width: 131, height: 34))
    private let belowNotch = WindowSnapshot(layer: normal, bounds: CGRect(x: 0, y: 34, width: 1710, height: 1073))

    private func isFullScreen(_ windows: [WindowSnapshot], display: CGRect? = nil, menuBarHeight: CGFloat? = nil) -> Bool {
        FullScreenDetector.isFullScreen(
            display: display ?? self.display,
            menuBarHeight: menuBarHeight ?? self.menuBarHeight,
            windows: windows,
            normalLayer: Self.normal,
            statusItemLayer: Self.statusItem
        )
    }

    @Test func fullScreenAppBelowTheNotch() {
        #expect(isFullScreen([menuBar, belowNotch]))
    }

    @Test func ordinaryDesktopIsNotFullScreen() {
        let window = WindowSnapshot(layer: Self.normal, bounds: CGRect(x: -67, y: 132, width: 1690, height: 968))
        #expect(!isFullScreen([menuBar, clock, window]))
    }

    /// With the Dock hidden, a zoomed window covers the same area as a full-screen one,
    /// but the menu bar items are still showing.
    @Test func zoomedWindowWithHiddenDockIsNotFullScreen() {
        #expect(!isFullScreen([menuBar, clock, belowNotch]))
    }

    /// Halfway through the Space switch the menu bar items slide out; the outgoing window
    /// still covers the display.
    @Test func menuBarItemsSlidingAwayStillCount() {
        let sliding = WindowSnapshot(layer: Self.statusItem, bounds: CGRect(x: -26, y: 0, width: 42, height: 34))
        let animating = WindowSnapshot(layer: Self.normal, bounds: display)
        #expect(!isFullScreen([menuBar, sliding, animating]))
    }

    @Test func emptyDesktopIsNotFullScreen() {
        #expect(!isFullScreen([menuBar]))
    }

    @Test func windowsOnOtherLayersDontCount() {
        let overlay = WindowSnapshot(layer: 3, bounds: display)
        #expect(!isFullScreen([menuBar, overlay]))
    }

    /// External display to the right without a notch: full-screen windows start at its top edge.
    @Test func fullScreenOnAnExternalDisplay() {
        let external = CGRect(x: 1710, y: -200, width: 2560, height: 1440)
        let window = WindowSnapshot(layer: Self.normal, bounds: external)
        let builtInClock = clock
        #expect(isFullScreen([window, builtInClock], display: external, menuBarHeight: 24))
    }

    @Test func fullScreenOnTheOtherDisplayDoesNotCount() {
        let external = CGRect(x: 1710, y: -200, width: 2560, height: 1440)
        let window = WindowSnapshot(layer: Self.normal, bounds: external)
        #expect(!isFullScreen([menuBar, clock, window]))
    }

    /// With the menu bar set to hide automatically there is no menu bar strip to check.
    @Test func autoHiddenMenuBarNeedsAWindowFromTheTopEdge() {
        let window = WindowSnapshot(layer: Self.normal, bounds: display)
        #expect(isFullScreen([window], menuBarHeight: 0))
        #expect(!isFullScreen([belowNotch], menuBarHeight: 0))
    }
}
