import SwiftUI
import WebKit

struct PopoverView: View {
    @Bindable var sampler: UsageSampler
    @Environment(\.appLanguage) private var lang

    @State private var reloadTrigger = 0
    @State private var isLoading = false
    @State private var isAuthBlocked = false
    @State private var showSettings = false

    private var s: Strings { lang.strings }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()

            ZStack {
                // Keep the webview alive even when Settings is shown so sampling
                // keeps running and there's no re-login on every switch.
                UsageWebView(
                    reloadTrigger: $reloadTrigger,
                    isLoading: $isLoading,
                    isAuthBlocked: $isAuthBlocked,
                    onWebViewReady: { sampler.attach($0) }
                )
                .opacity(showSettings ? 0 : 1)
                .allowsHitTesting(!showSettings)

                if showSettings {
                    SettingsView(sampler: sampler)
                        .transition(.opacity)
                }
            }
            .frame(minWidth: 540, minHeight: 560)
            .onChange(of: isLoading) { _, newValue in
                sampler.isWebViewLoading = newValue
            }
            .onChange(of: isAuthBlocked) { _, newValue in
                sampler.isAuthBlocked = newValue
            }

            statusStrip
        }
        .frame(width: 560, height: 720)
        .onAppear {
            reloadTrigger &+= 1
            sampler.setPopoverOpen(true)
        }
        .onDisappear {
            sampler.setPopoverOpen(false)
        }
    }

    private var header: some View {
        HStack(spacing: 10) {
            Image(systemName: statusIcon)
                .font(.title3)
                .foregroundStyle(statusIconColor)
            Text(showSettings ? s.popoverTitleSettings : s.popoverTitleUsage)
                .font(.headline)
            if isLoading && !showSettings {
                ProgressView()
                    .controlSize(.small)
                    .padding(.leading, 4)
            }
            Spacer()

            if !showSettings {
                Button {
                    reloadTrigger &+= 1
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .buttonStyle(.borderless)
                .help(s.reloadHelp)
                .disabled(isLoading)
            }

            Button {
                withAnimation(.easeInOut(duration: 0.12)) {
                    showSettings.toggle()
                }
            } label: {
                if showSettings {
                    Label(s.backButton, systemImage: "chevron.left")
                } else {
                    Label(s.settingsButton, systemImage: "gearshape")
                }
            }
            .buttonStyle(.bordered)
            .controlSize(.small)

            Menu {
                Button(s.quitMenu, action: { NSApplication.shared.terminate(nil) })
            } label: {
                Image(systemName: "ellipsis.circle")
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .fixedSize()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial)
    }

    @ViewBuilder
    private var statusStrip: some View {
        switch sampler.status {
        case .authRequired:
            statusBanner(
                color: .orange,
                icon: "exclamationmark.triangle.fill",
                text: s.statusAuthRequired
            )
        case .parseError(let detail):
            statusBanner(
                color: .red,
                icon: "xmark.octagon.fill",
                text: s.statusParseError(String(detail.prefix(60)))
            )
        case .network(let detail):
            statusBanner(
                color: .orange,
                icon: "wifi.exclamationmark",
                text: s.statusNetwork(String(detail.prefix(80)))
            )
        default:
            EmptyView()
        }
    }

    private func statusBanner(color: Color, icon: String, text: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon).foregroundStyle(color)
            Text(text).font(.caption)
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(color.opacity(0.1))
    }

    private var statusIcon: String {
        switch sampler.status {
        case .ok: return "gauge.medium"
        case .authRequired: return "lock.fill"
        case .parseError, .network: return "exclamationmark.triangle.fill"
        case .loading, .booting: return "gauge.medium"
        }
    }

    private var statusIconColor: Color {
        switch sampler.status {
        case .ok: return .primary
        case .authRequired, .network: return .orange
        case .parseError: return .red
        case .loading, .booting: return .secondary
        }
    }
}
