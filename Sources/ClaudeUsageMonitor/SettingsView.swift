import SwiftUI

struct SettingsView: View {
    @Bindable var sampler: UsageSampler
    @Environment(\.appLanguage) private var lang

    @AppStorage("thresholds5h") private var thresholds5hData: Data = try! JSONEncoder().encode([75, 90])
    @AppStorage("thresholds7d") private var thresholds7dData: Data = try! JSONEncoder().encode([80])
    @AppStorage("pollIntervalSeconds") private var pollIntervalSeconds: Double = 60

    @State private var notificationState: NotificationManager.AuthorizationState = .notDetermined
    @State private var launchAtLogin: Bool = LaunchAtLogin.isEnabled

    @AppStorage(AppLanguage.storageKey) private var languageRaw: String = AppLanguage.default.rawValue
    @State private var initialLanguageRaw: String = AppLanguage.current.rawValue

    private let candidates5h = [50, 60, 70, 75, 80, 85, 90, 95]
    private let candidates7d = [50, 60, 70, 80, 85, 90, 95]

    private var s: Strings { lang.strings }

    private var pollIntervals: [(label: String, seconds: Double)] {
        [(s.pollMin1, 60), (s.pollMin5, 300), (s.pollMin15, 900)]
    }

    var body: some View {
        Form {
            Section(s.settingsNotificationsHeader) {
                HStack(spacing: 10) {
                    Image(systemName: permissionIcon)
                        .foregroundStyle(permissionColor)
                    Text(permissionText)
                        .font(.callout)
                    Spacer()
                    switch notificationState {
                    case .notDetermined:
                        Button(s.settingsNotificationsRequestButton) {
                            Task {
                                _ = await NotificationManager.shared.requestPermission()
                                notificationState = NotificationManager.shared.state
                            }
                        }
                    case .denied:
                        Button(s.settingsNotificationsOpenSystemButton) {
                            NotificationManager.shared.openSystemNotificationSettings()
                        }
                    case .authorized:
                        EmptyView()
                    }
                }
            }

            Section {
                thresholdChips(
                    candidates: candidates5h,
                    selected: thresholds5hBinding
                )
                Text(s.settings5hThresholdsCaption)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } header: {
                Text(s.settings5hThresholdsHeader)
            }

            Section {
                thresholdChips(
                    candidates: candidates7d,
                    selected: thresholds7dBinding
                )
                Text(s.settings7dThresholdsCaption)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } header: {
                Text(s.settings7dThresholdsHeader)
            }

            Section(s.settingsSystemHeader) {
                Toggle(s.settingsLaunchAtLogin, isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _, newValue in
                        let ok = LaunchAtLogin.setEnabled(newValue)
                        if !ok { launchAtLogin = LaunchAtLogin.isEnabled }
                    }
                if LaunchAtLogin.requiresApproval {
                    Text(s.settingsLaunchAtLoginRequiresApproval)
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
            }

            Section(s.settingsPollingHeader) {
                Picker(s.settingsPollingLabel, selection: $pollIntervalSeconds) {
                    ForEach(pollIntervals, id: \.seconds) { option in
                        Text(option.label).tag(option.seconds)
                    }
                }
                .pickerStyle(.segmented)
                Text(s.settingsPollingCaption)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section(s.settingsLanguageHeader) {
                Picker(s.settingsLanguageLabel, selection: $languageRaw) {
                    ForEach(AppLanguage.allCases) { language in
                        Text(language.displayName).tag(language.rawValue)
                    }
                }
                .pickerStyle(.segmented)
                if languageRaw != initialLanguageRaw {
                    HStack(spacing: 8) {
                        Image(systemName: "arrow.clockwise.circle.fill")
                            .foregroundStyle(.orange)
                        Text(s.settingsLanguageRestartWarning)
                            .font(.caption)
                        Spacer()
                        Button(s.settingsLanguageRestartButton) {
                            restartApp()
                        }
                        .controlSize(.small)
                    }
                } else {
                    Text(s.settingsLanguageCaption)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Section(s.settingsAboutHeader) {
                Text(s.settingsAboutCaption)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .task {
            await NotificationManager.shared.refreshState()
            notificationState = NotificationManager.shared.state
        }
    }

    /// Re-launch the app via `open -n` so the new AppleLanguages takes effect.
    /// We detach the relauncher so it outlives this process.
    private func restartApp() {
        let bundlePath = Bundle.main.bundlePath
        let task = Process()
        task.launchPath = "/bin/sh"
        task.arguments = ["-c", "sleep 0.5 && open -n \"\(bundlePath)\""]
        try? task.run()
        NSApp.terminate(nil)
    }

    private func thresholdChips(candidates: [Int], selected: Binding<Set<Int>>) -> some View {
        HStack(spacing: 8) {
            ForEach(candidates, id: \.self) { v in
                let isOn = selected.wrappedValue.contains(v)
                Button {
                    if isOn { selected.wrappedValue.remove(v) }
                    else    { selected.wrappedValue.insert(v) }
                } label: {
                    Text("\(v)%")
                        .font(.callout.monospacedDigit())
                        .lineLimit(1)
                        .fixedSize(horizontal: true, vertical: false)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(isOn ? Color.accentColor : Color.secondary.opacity(0.15))
                        .foregroundStyle(isOn ? Color.white : Color.primary)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
            Spacer()
        }
    }

    private var thresholds5hBinding: Binding<Set<Int>> {
        Binding(
            get: { Self.decode(thresholds5hData, fallback: [75, 90]) },
            set: { thresholds5hData = Self.encode($0) }
        )
    }
    private var thresholds7dBinding: Binding<Set<Int>> {
        Binding(
            get: { Self.decode(thresholds7dData, fallback: [80]) },
            set: { thresholds7dData = Self.encode($0) }
        )
    }

    private static func decode(_ data: Data, fallback: [Int]) -> Set<Int> {
        guard let arr = try? JSONDecoder().decode([Int].self, from: data) else {
            return Set(fallback)
        }
        return Set(arr)
    }
    private static func encode(_ set: Set<Int>) -> Data {
        (try? JSONEncoder().encode(Array(set).sorted())) ?? Data()
    }

    private var permissionIcon: String {
        switch notificationState {
        case .authorized: return "checkmark.circle.fill"
        case .denied: return "xmark.circle.fill"
        case .notDetermined: return "questionmark.circle.fill"
        }
    }
    private var permissionColor: Color {
        switch notificationState {
        case .authorized: return .green
        case .denied: return .red
        case .notDetermined: return .orange
        }
    }
    private var permissionText: String {
        switch notificationState {
        case .authorized: return s.settingsNotificationsAuthorized
        case .denied: return s.settingsNotificationsDenied
        case .notDetermined: return s.settingsNotificationsNotDetermined
        }
    }
}
