import CoreGraphics
import Testing
@testable import NotchFeedCore

struct TickerPositionerTests {
    /// 14" MacBook Pro with notch: the menu bar is 37 pt; Dock at the bottom.
    private let builtIn = ScreenGeometry(
        displayID: 1,
        frame: CGRect(x: 0, y: 0, width: 1512, height: 982),
        visibleFrame: CGRect(x: 0, y: 70, width: 1512, height: 875)
    )
    /// External display to the right, placed lower, without Dock and with a 25 pt menu bar.
    private let external = ScreenGeometry(
        displayID: 2,
        frame: CGRect(x: 1512, y: -200, width: 2560, height: 1440),
        visibleFrame: CGRect(x: 1512, y: -200, width: 2560, height: 1415)
    )

    @Test func topSitsDirectlyUnderTheNotchMenuBar() {
        let frame = TickerPositioner.frame(on: builtIn, position: .top)
        #expect(frame == CGRect(x: 0, y: 945 - TickerPositioner.height, width: 1512, height: TickerPositioner.height))
    }

    @Test func bottomSitsDirectlyAboveTheDock() {
        let frame = TickerPositioner.frame(on: builtIn, position: .bottom)
        #expect(frame == CGRect(x: 0, y: 70, width: 1512, height: TickerPositioner.height))
    }

    @Test func avoidsADockOnTheLeft() {
        let screen = ScreenGeometry(
            displayID: 1,
            frame: CGRect(x: 0, y: 0, width: 1512, height: 982),
            visibleFrame: CGRect(x: 80, y: 0, width: 1432, height: 945)
        )
        let frame = TickerPositioner.frame(on: screen, position: .bottom)
        #expect(frame == CGRect(x: 80, y: 0, width: 1432, height: TickerPositioner.height))
    }

    @Test func topUsesTheScreenEdgeWhenTheMenuBarAutoHides() {
        let screen = ScreenGeometry(displayID: 1, frame: builtIn.frame, visibleFrame: CGRect(x: 0, y: 0, width: 1512, height: 982))
        #expect(TickerPositioner.frame(on: screen, position: .top).maxY == 982)
    }

    @Test func worksOnADisplayWithAnOffsetOrigin() {
        let frame = TickerPositioner.frame(on: external, position: .top)
        #expect(frame == CGRect(x: 1512, y: 1215 - TickerPositioner.height, width: 2560, height: TickerPositioner.height))
    }

    @Test func picksThePreferredDisplay() {
        #expect(TickerPositioner.screen(preferredDisplayID: 2, among: [builtIn, external]) == external)
    }

    @Test func fallsBackToThePrimaryDisplay() {
        #expect(TickerPositioner.screen(preferredDisplayID: nil, among: [builtIn, external]) == builtIn)
        #expect(TickerPositioner.screen(preferredDisplayID: 99, among: [builtIn, external]) == builtIn)
        #expect(TickerPositioner.screen(preferredDisplayID: 2, among: []) == nil)
    }
}
