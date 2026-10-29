import AppKit
import SwiftUI

/// FR-9.1: the settings window. V0.1 has the General and Feeds tabs; the others follow per version.
struct SettingsView: View {
    let model: AppModel

    var body: some View {
        TabView {
            GeneralTab(model: model)
                .tabItem { Label("General", systemImage: "gearshape") }
            FeedsTab(model: model)
                .tabItem { Label("Feeds", systemImage: "dot.radiowaves.up.forward") }
        }
        .frame(width: 600, height: 480)
        .onAppear {
            // An accessory app isn't activated by opening a window, so bring it forward.
            NSApp.activate()
        }
    }
}
