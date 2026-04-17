import Foundation
import ServiceManagement

/// Thin wrapper around `SMAppService.mainApp` for the "Launch at login" toggle.
/// Only supported on macOS 13+. On earlier macOS the helper silently no-ops.
enum LaunchAtLogin {
    static var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    static var isRegistered: Bool {
        let s = SMAppService.mainApp.status
        return s == .enabled || s == .requiresApproval
    }

    /// True when the user previously approved but has since revoked via System Settings.
    static var requiresApproval: Bool {
        SMAppService.mainApp.status == .requiresApproval
    }

    @discardableResult
    static func setEnabled(_ enabled: Bool) -> Bool {
        do {
            if enabled {
                if SMAppService.mainApp.status == .enabled { return true }
                try SMAppService.mainApp.register()
            } else {
                if SMAppService.mainApp.status == .notRegistered { return true }
                try SMAppService.mainApp.unregister()
            }
            return true
        } catch {
            return false
        }
    }
}
