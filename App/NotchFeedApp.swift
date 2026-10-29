import SwiftUI

@main
struct NotchFeedApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        MenuBarExtra {
            if let model = appDelegate.model {
                MenuBarContent(model: model)
            } else {
                QuitButton()
            }
        } label: {
            MenuBarLabel(model: appDelegate.model)
        }

        Settings {
            if let model = appDelegate.model {
                SettingsView(model: model)
            }
        }
    }
}
