import AppKit
import NotchFeedCore
import SwiftData

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    /// nil when the store couldn't be opened; the error is shown at launch.
    let model: AppModel?
    private let startupError: (any Error)?
    private var ticker: TickerController?

    override init() {
        AppSettings.registerDefaults()
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
        guard let model else {
            showStartupError()
            return
        }
        model.start()
        let ticker = TickerController(model: model)
        ticker.start()
        self.ticker = ticker
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
