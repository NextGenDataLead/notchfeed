import AppKit
import NotchFeedCore
import SwiftData

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    /// nil when the store couldn't be opened; the error is shown at launch.
    let model: AppModel?
    private let startupError: (any Error)?
    private let isDuplicateInstance: Bool
    private var ticker: TickerController?

    override init() {
        AppSettings.registerDefaults()
        // Two copies (say /Applications and a fresh build) would write the same store and both
        // add a menu bar item, so a second copy doesn't open the store and quits at launch.
        isDuplicateInstance = Self.anotherInstanceIsRunning()
        if isDuplicateInstance {
            model = nil
            startupError = nil
            super.init()
            return
        }
        do {
            let container = try ModelContainerFactory.makePersistent()
            let store = FeedStore(modelContainer: container)
            let client = URLSessionHTTPClient()
            let coordinator = RefreshCoordinator(
                store: store,
                fetcher: FeedFetcher(client: client),
                favicons: FaviconFetcher(client: client),
                retentionDays: { AppSettings.retentionDays() }
            )
            model = AppModel(container: container, store: store, coordinator: coordinator)
            startupError = nil
        } catch {
            model = nil
            startupError = error
        }
        super.init()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        if isDuplicateInstance {
            NSApp.terminate(nil)
            return
        }
        guard let model else {
            showStartupError()
            return
        }
        model.start()
        let ticker = TickerController(model: model)
        ticker.start()
        self.ticker = ticker
    }

    private static func anotherInstanceIsRunning() -> Bool {
        guard let bundleID = Bundle.main.bundleIdentifier else { return false }
        let ownPID = ProcessInfo.processInfo.processIdentifier
        return NSRunningApplication.runningApplications(withBundleIdentifier: bundleID)
            .contains { $0.processIdentifier != ownPID && !$0.isTerminated }
    }

    private func showStartupError() {
        let alert = NSAlert()
        alert.alertStyle = .critical
        alert.messageText = String(localized: "NotchFeed can't open its database")
        alert.informativeText = startupError?.localizedDescription ?? ""
        alert.addButton(withTitle: String(localized: "Quit"))
        NSApp.activate()
        alert.runModal()
        NSApp.terminate(nil)
    }
}
