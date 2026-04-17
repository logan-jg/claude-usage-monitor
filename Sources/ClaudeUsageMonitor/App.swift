import AppKit
import SwiftUI

@main
struct ClaudeUsageApp: App {
    @State private var sampler = UsageSampler()
    @State private var updater = UpdaterManager()
    @AppStorage(AppLanguage.storageKey) private var languageRaw: String = AppLanguage.default.rawValue

    init() {
        AppLanguage.applyAtLaunch()
    }

    private var currentLanguage: AppLanguage {
        AppLanguage(rawValue: languageRaw) ?? .default
    }

    var body: some Scene {
        MenuBarExtra {
            PopoverView(sampler: sampler, updater: updater)
                .environment(\.appLanguage, currentLanguage)
        } label: {
            MenuBarIcon(sampler: sampler)
        }
        .menuBarExtraStyle(.window)
    }
}

/// Menu bar icon. Reflects sampler state: normal, warning, or critical.
struct MenuBarIcon: View {
    @Bindable var sampler: UsageSampler

    var body: some View {
        Image(systemName: iconName)
    }

    private var iconName: String {
        switch sampler.status {
        case .authRequired, .network:
            return "gauge.medium.badge.exclamationmark"
        case .parseError:
            return "exclamationmark.triangle"
        case .ok(let session, let weekly, _):
            let high = max(session.percent, weekly.percent)
            if high >= 90 { return "gauge.high" }
            if high >= 75 { return "gauge.medium" }
            return "gauge.low"
        case .loading, .booting:
            return "gauge.medium"
        }
    }
}
