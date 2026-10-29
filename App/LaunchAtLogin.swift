import Observation
import ServiceManagement

/// FR-9.2: launch at login through `SMAppService`. The toggle always shows the real status,
/// which the user can also change in System Settings › General › Login Items.
@MainActor
@Observable
final class LaunchAtLogin {
    private(set) var isEnabled = false
    private(set) var needsApproval = false
    private(set) var errorMessage: String?

    init() {
        refresh()
    }

    func refresh() {
        let status = SMAppService.mainApp.status
        isEnabled = status == .enabled
        needsApproval = status == .requiresApproval
    }

    func setEnabled(_ enabled: Bool) {
        errorMessage = nil
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            errorMessage = error.localizedDescription
        }
        refresh()
    }

    func openLoginItemsSettings() {
        SMAppService.openSystemSettingsLoginItems()
    }
}
