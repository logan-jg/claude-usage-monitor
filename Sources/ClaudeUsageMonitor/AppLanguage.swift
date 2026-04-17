import Foundation

/// Display language for the embedded claude.ai WebView.
///
/// Applied via `AppleLanguages` in UserDefaults at app launch — WKWebView picks
/// this up and reports it as `navigator.language` plus the `Accept-Language`
/// header, which Anthropic's login/settings pages use to choose locale.
///
/// The app's own Swift UI copy is still Korean in v0.1; only the WebView content
/// follows this selection. Changing the value requires an app relaunch.
enum AppLanguage: String, CaseIterable, Identifiable {
    case korean = "ko"
    case english = "en"
    case japanese = "ja"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .korean: return "한국어"
        case .english: return "English"
        case .japanese: return "日本語"
        }
    }

    /// The list that gets written to `AppleLanguages`. Fallback to English so the
    /// login page is usable if claude.ai doesn't have the primary language.
    var appleLanguagesList: [String] {
        switch self {
        case .korean:   return ["ko-KR", "ko", "en"]
        case .english:  return ["en-US", "en"]
        case .japanese: return ["ja-JP", "ja", "en"]
        }
    }

    static let storageKey = "language"
    static let `default`: AppLanguage = .korean

    /// Read the current selection from UserDefaults, falling back to `default`.
    static var current: AppLanguage {
        if let raw = UserDefaults.standard.string(forKey: storageKey),
           let lang = AppLanguage(rawValue: raw) {
            return lang
        }
        return .default
    }

    /// Write `AppleLanguages` so every subsequently-created WKWebView uses it.
    /// Must run before the first WKWebView is instantiated — call from App.init.
    static func applyAtLaunch() {
        UserDefaults.standard.set(current.appleLanguagesList, forKey: "AppleLanguages")
    }
}
