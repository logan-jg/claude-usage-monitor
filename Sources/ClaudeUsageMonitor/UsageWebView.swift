import SwiftUI
@preconcurrency import WebKit

/// SwiftUI wrapper that embeds `https://claude.ai/settings/usage` in a WKWebView.
///
/// The popover is locked to this URL — navigation to chat, new pages, or anywhere
/// outside `/settings/usage` (and its auth redirects) is cancelled. Cookies persist
/// across launches so users only log in once.
struct UsageWebView: NSViewRepresentable {
    static let targetURL = URL(string: "https://claude.ai/settings/usage")!
    static let desktopUA = "Mozilla/5.0 (Macintosh; Intel Mac OS X 14_0) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Safari/605.1.15"

    @Binding var reloadTrigger: Int
    @Binding var isLoading: Bool
    @Binding var isAuthBlocked: Bool
    let onWebViewReady: (WKWebView) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeNSView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.websiteDataStore = .default()

        // Inject a tiny CSS stylesheet that hides the settings page header, the
        // left tab navigation, and collapses the 2-column grid to a single
        // column. Selectors are taken from the real claude.ai DOM (captured via
        // a debug dump), so this is targeted — no MutationObserver, no layout
        // guessing, and nothing to re-apply on SPA rerender.
        let userScript = WKUserScript(
            source: Self.chromeHidingJS,
            injectionTime: .atDocumentStart,
            forMainFrameOnly: true
        )
        config.userContentController.addUserScript(userScript)

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.customUserAgent = Self.desktopUA
        webView.navigationDelegate = context.coordinator
        webView.uiDelegate = context.coordinator
        webView.setValue(false, forKey: "drawsBackground")
        webView.allowsBackForwardNavigationGestures = false

        context.coordinator.webView = webView
        webView.load(URLRequest(url: Self.targetURL))
        onWebViewReady(webView)
        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        if context.coordinator.lastReloadTrigger != reloadTrigger {
            context.coordinator.lastReloadTrigger = reloadTrigger
            webView.load(URLRequest(url: Self.targetURL))
        }
    }

    /// CSS injected at document-start. Selectors match the live claude.ai DOM
    /// (verified from a captured snapshot of /settings/usage).
    private static let chromeHidingJS = """
    (() => {
      const install = () => {
        if (!document.head || document.getElementById('cu-hide-style')) return;
        const style = document.createElement('style');
        style.id = 'cu-hide-style';
        style.textContent = `
          /* Hide the "설정 / Settings" title bar */
          header[data-testid="page-header"] { display: none !important; }
          /* Hide the left-hand settings tab navigation */
          nav[aria-label="설정"],
          nav[aria-label="Settings"] { display: none !important; }
          /* Hide the main app chat sidebar (with 'pin-sidebar-toggle' button) */
          nav[aria-label="사이드바"],
          nav[aria-label="Sidebar"] { display: none !important; }
          /* Hide the mobile "설정" heading */
          #main-content main > h1 { display: none !important; }
          /* Collapse the 2-column grid to a single column so the usage card fills width */
          #main-content main .grid { grid-template-columns: 1fr !important; }
          #main-content main { margin-top: 0 !important; padding-top: 4px !important; }
        `;
        document.head.appendChild(style);
      };
      if (document.head) install();
      else document.addEventListener('DOMContentLoaded', install, { once: true });
    })();
    """

    final class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate {
        let parent: UsageWebView
        weak var webView: WKWebView?
        var lastReloadTrigger = 0

        init(_ parent: UsageWebView) {
            self.parent = parent
        }

        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            Task { @MainActor in parent.isLoading = true }
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            Task { @MainActor in
                parent.isLoading = false
                parent.isAuthBlocked = false
            }
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            Task { @MainActor in parent.isLoading = false }
        }

        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            Task { @MainActor in parent.isLoading = false }
        }

        /// Cmd-click and `target="_blank"` links escape to the user's default browser
        /// so we never end up with a second Claude tab hidden inside the popover.
        /// Only http(s) and mailto are allowed through; custom schemes (file://,
        /// smb://, third-party handlers, etc.) are silently dropped so a
        /// compromised page can't coax Launch Services into opening something
        /// unexpected.
        func webView(
            _ webView: WKWebView,
            createWebViewWith configuration: WKWebViewConfiguration,
            for navigationAction: WKNavigationAction,
            windowFeatures: WKWindowFeatures
        ) -> WKWebView? {
            guard let url = navigationAction.request.url,
                  let scheme = url.scheme?.lowercased(),
                  ["http", "https", "mailto"].contains(scheme)
            else { return nil }
            NSWorkspace.shared.open(url)
            return nil
        }
    }
}
