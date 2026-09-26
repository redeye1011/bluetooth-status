import ServiceManagement

final class LoginItemManager {
    var isEnabled: Bool { SMAppService.mainApp.status == .enabled }
    var requiresApproval: Bool { SMAppService.mainApp.status == .requiresApproval }
    var isRequested: Bool { isEnabled || requiresApproval }

    func setEnabled(_ enabled: Bool) throws {
        if enabled {
            if !isRequested {
                try SMAppService.mainApp.register()
            }
        } else if isRequested {
            try SMAppService.mainApp.unregister()
        }
    }

    func openApprovalSettings() {
        SMAppService.openSystemSettingsLoginItems()
    }
}
