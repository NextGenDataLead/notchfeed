import SwiftUI

@main
struct NotchFeedApp: App {
    var body: some Scene {
        MenuBarExtra("NotchFeed", systemImage: "newspaper") {
            Button("Quit NotchFeed") {
                NSApplication.shared.terminate(nil)
            }
            .keyboardShortcut("q")
        }
    }
}
