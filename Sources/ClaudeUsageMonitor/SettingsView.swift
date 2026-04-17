import SwiftUI

struct SettingsView: View {
    @Bindable var sampler: UsageSampler

    @AppStorage("thresholds5h") private var thresholds5hData: Data = try! JSONEncoder().encode([75, 90])
    @AppStorage("thresholds7d") private var thresholds7dData: Data = try! JSONEncoder().encode([80])
    @AppStorage("pollIntervalSeconds") private var pollIntervalSeconds: Double = 60

    @State private var notificationState: NotificationManager.AuthorizationState = .notDetermined
    @State private var launchAtLogin: Bool = LaunchAtLogin.isEnabled

    private let candidates5h = [50, 60, 70, 75, 80, 85, 90, 95]
    private let candidates7d = [50, 60, 70, 80, 85, 90, 95]
    private let pollIntervals: [(label: String, seconds: Double)] = [
        ("1분", 60), ("5분", 300), ("15분", 900)
    ]

    var body: some View {
        Form {
            Section("알림 권한") {
                HStack(spacing: 10) {
                    Image(systemName: permissionIcon)
                        .foregroundStyle(permissionColor)
                    Text(permissionText)
                        .font(.callout)
                    Spacer()
                    switch notificationState {
                    case .notDetermined:
                        Button("허용 요청") {
                            Task {
                                _ = await NotificationManager.shared.requestPermission()
                                notificationState = NotificationManager.shared.state
                            }
                        }
                    case .denied:
                        Button("시스템 설정 열기") {
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
                Text("5h 세션이 지정한 % 에 도달하면 알림. 같은 세션 안에서는 한 번만.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } header: {
                Text("5h 세션 임계치")
            }

            Section {
                thresholdChips(
                    candidates: candidates7d,
                    selected: thresholds7dBinding
                )
                Text("7d 주간 한도 임계치. 주간 리셋 전까지 한 번만.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } header: {
                Text("7d 주간 임계치")
            }

            Section("시스템") {
                Toggle("로그인 시 자동 시작", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _, newValue in
                        let ok = LaunchAtLogin.setEnabled(newValue)
                        if !ok { launchAtLogin = LaunchAtLogin.isEnabled }
                    }
                if LaunchAtLogin.requiresApproval {
                    Text("시스템 설정 → 로그인 항목에서 이 앱을 허용해주세요.")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
            }

            Section("폴링 주기") {
                Picker("팝오버 열려있을 때", selection: $pollIntervalSeconds) {
                    ForEach(pollIntervals, id: \.seconds) { option in
                        Text(option.label).tag(option.seconds)
                    }
                }
                .pickerStyle(.segmented)
                Text("팝오버가 닫혀있을 때는 이 간격의 3배마다 폴링합니다.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("About") {
                Text("이 앱은 claude.ai/settings/usage 를 WebView 로 읽어 공식 % 값을 그대로 표시합니다. 수치는 Anthropic 서버 기준으로 항상 정확합니다.")
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
        case .authorized: return "알림이 켜져 있습니다."
        case .denied: return "알림이 차단됐습니다. 시스템 설정에서 허용해주세요."
        case .notDetermined: return "알림 권한을 요청해주세요."
        }
    }
}
