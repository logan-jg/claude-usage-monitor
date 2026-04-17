import SwiftUI
import WebKit

struct PopoverView: View {
    @Bindable var sampler: UsageSampler
    @Bindable var updater: UpdaterManager
    @Environment(\.appLanguage) private var lang

    @State private var reloadTrigger = 0
    @State private var isLoading = false
    @State private var isAuthBlocked = false
    @State private var showSettings = false
    @State private var currentURL: String?

    private var s: Strings { lang.strings }

    /// Paths we must NOT interrupt by force-reloading /settings/usage when the
    /// popover reopens. If the user is in the middle of login/OAuth and clicks
    /// away to copy a verification code from their mail client, snapping the
    /// webview back to /settings/usage would kick them to /login and wipe
    /// the email-code form.
    private static let preserveURLSubstrings = [
        "/login", "/oauth", "/auth", "/magic", "/verify",
        "/signin", "/sign-in", "/sso",
        // Also hosts we bounce through during SSO
        "anthropic.com/oauth", "accounts.google.com", "appleid.apple.com"
    ]

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
                    currentURL: $currentURL,
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
            sampler.setPopoverOpen(true)
            // Only snap back to /settings/usage when the webview has wandered to
            // something that is clearly NOT the usage page and NOT a login flow.
            // During sign-in we leave the webview alone so stepping away to grab
            // a verification code doesn't reset the session.
            if shouldForceReloadOnAppear() {
                reloadTrigger &+= 1
            }
        }
        .onDisappear {
            sampler.setPopoverOpen(false)
        }
    }

    private func shouldForceReloadOnAppear() -> Bool {
        guard let url = currentURL else {
            // First ever open — let the initial makeNSView load do its thing.
            return false
        }
        // Never interrupt a login/OAuth flow mid-form.
        if Self.preserveURLSubstrings.contains(where: url.contains) { return false }
        // Reload every other claude.ai page, INCLUDING /settings/usage itself —
        // the page doesn't auto-refresh its numbers, so without this the sampler
        // keeps reading the same stale DOM values indefinitely.
        return url.contains("claude.ai")
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
                Button(s.checkForUpdates) {
                    updater.checkForUpdates()
                }
                .disabled(!updater.canCheckForUpdates)
                Divider()
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
