import AppKit
import NotchFeedCore

/// FR-1.1: tells the ticker when a full-screen app is in front on its display, so it can hide.
/// Screen sharing (FR-7.1) and the full-screen setting with allow list (FR-7.2) follow in V0.3.
@MainActor
final class VisibilityController {
    /// Space switches animate; the window list settles some time after the notification.
    private static let recheckDelays: [Duration] = [.zero, .milliseconds(400), .milliseconds(1200)]

    /// Called whenever the answer may have changed.
    var onChange: (() -> Void)?

    private var observers: [any NSObjectProtocol] = []
    private var recheckTask: Task<Void, Never>?

    func start() {
        let center = NSWorkspace.shared.notificationCenter
        observers = [NSWorkspace.activeSpaceDidChangeNotification, NSWorkspace.didActivateApplicationNotification].map { name in
            center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.scheduleChecks() }
            }
        }
    }

    func isFullScreenAppShowing(on screen: NSScreen) -> Bool {
        guard let displayID = screen.displayID else { return false }
        let options: CGWindowListOption = [.optionOnScreenOnly, .excludeDesktopElements]
        let info = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] ?? []
        let windows = info.compactMap { window -> WindowSnapshot? in
            guard let layer = window[kCGWindowLayer as String] as? Int,
                  let bounds = window[kCGWindowBounds as String] as? NSDictionary,
                  let rect = CGRect(dictionaryRepresentation: bounds) else { return nil }
            return WindowSnapshot(layer: layer, bounds: rect)
        }
        return FullScreenDetector.isFullScreen(
            display: CGDisplayBounds(displayID),
            menuBarHeight: screen.frame.maxY - screen.visibleFrame.maxY,
            windows: windows,
            normalLayer: Int(CGWindowLevelForKey(.normalWindow)),
            statusItemLayer: Int(CGWindowLevelForKey(.statusWindow))
        )
    }

    private func scheduleChecks() {
        recheckTask?.cancel()
        recheckTask = Task { [weak self] in
            for delay in Self.recheckDelays {
                try? await Task.sleep(for: delay)
                guard !Task.isCancelled else { return }
                self?.onChange?()
            }
        }
    }
}
