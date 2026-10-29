import AppKit

/// FR-1.1: borderless, non-activating bar above normal windows on every Space. It leaves out
/// `.fullScreenAuxiliary`, so macOS keeps it off full-screen Spaces (see DECISIONS.md).
final class TickerPanel: NSPanel {
    init() {
        super.init(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        level = .floating
        collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
        isFloatingPanel = true
        hidesOnDeactivate = false
        isReleasedWhenClosed = false
        isMovable = false
        hasShadow = false
        isOpaque = false
        backgroundColor = .clear
        animationBehavior = .none
    }

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}
