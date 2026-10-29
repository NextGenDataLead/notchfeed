import AppKit
import NotchFeedCore
import SwiftUI

struct GeneralTab: View {
    let model: AppModel

    @State private var launchAtLogin = LaunchAtLogin()
    @State private var screens: [DisplayOption] = DisplayOption.connected()

    @AppStorage(AppSettings.Key.tickerPosition) private var position = AppDefaults.tickerPosition
    @AppStorage(AppSettings.Key.tickerDisplayID) private var displayID = 0
    @AppStorage(AppSettings.Key.tickerDisplayName) private var displayName = ""
    @AppStorage(AppSettings.Key.showFeedName) private var showFeedName = AppDefaults.showFeedName
    @AppStorage(AppSettings.Key.showUnreadCount) private var showUnreadCount = AppDefaults.showUnreadCount
    @AppStorage(AppSettings.Key.retentionDays) private var retentionDays = AppDefaults.retentionDays

    var body: some View {
        Form {
            Section {
                Toggle("Open NotchFeed at login", isOn: Binding(
                    get: { launchAtLogin.isEnabled || launchAtLogin.needsApproval },
                    set: { launchAtLogin.setEnabled($0) }
                ))
                if launchAtLogin.needsApproval {
                    HStack {
                        Text("Allow NotchFeed in Login Items to finish turning this on.")
                            .foregroundStyle(.secondary)
                        Spacer()
                        Button("Open Login Items…") { launchAtLogin.openLoginItemsSettings() }
                    }
                    .font(.callout)
                }
                if let message = launchAtLogin.errorMessage {
                    Text(message).font(.callout).foregroundStyle(.red)
                }
            }

            Section("Ticker") {
                Picker("Position", selection: $position) {
                    Text("Top, under the menu bar").tag(TickerPosition.top)
                    Text("Bottom, above the Dock").tag(TickerPosition.bottom)
                }
                Picker("Display", selection: displaySelection) {
                    Text("Primary display").tag(0)
                    ForEach(screens) { screen in
                        Text(screen.name).tag(Int(screen.id))
                    }
                    if displayID != 0, !screens.contains(where: { Int($0.id) == displayID }) {
                        Text("\(displayName) (not connected)").tag(displayID)
                    }
                }
                Toggle("Show feed name", isOn: $showFeedName)
            }

            Section("Menu bar") {
                Toggle("Show unread count", isOn: $showUnreadCount)
            }

            Section("Storage") {
                Stepper(value: $retentionDays, in: AppSettings.retentionRange) {
                    Text("Keep items for \(retentionDays) days")
                }
                .onChange(of: retentionDays) { model.applyRetention() }
            }
        }
        .formStyle(.grouped)
        .onAppear { launchAtLogin.refresh() }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didChangeScreenParametersNotification)) { _ in
            screens = DisplayOption.connected()
        }
    }

    /// Stores the display's name with its ID so the choice stays readable while it's unplugged.
    private var displaySelection: Binding<Int> {
        Binding(
            get: { displayID },
            set: { newValue in
                displayID = newValue
                displayName = screens.first { Int($0.id) == newValue }?.name ?? ""
            }
        )
    }
}

struct DisplayOption: Identifiable, Hashable {
    let id: UInt32
    let name: String

    @MainActor
    static func connected() -> [DisplayOption] {
        NSScreen.screens.compactMap { screen in
            screen.displayID.map { DisplayOption(id: $0, name: screen.localizedName) }
        }
    }
}
