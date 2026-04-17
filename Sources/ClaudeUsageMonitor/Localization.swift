import Foundation
import SwiftUI

/// All user-facing strings in the app, per language.
/// Adding a new string: add the field here, then set all three variants in
/// `AppLanguage.strings`. Missing translations will fail to compile — that's
/// the point of the struct-based approach vs. dictionary-keyed lookup.
struct Strings {
    // Popover header
    let popoverTitleUsage: String
    let popoverTitleSettings: String
    let reloadHelp: String
    let settingsButton: String
    let backButton: String
    let quitMenu: String

    // Status banners
    let statusAuthRequired: String
    let statusParseError: (String) -> String   // argument: detail
    let statusNetwork: (String) -> String

    // Settings — Notifications section
    let settingsNotificationsHeader: String
    let settingsNotificationsAuthorized: String
    let settingsNotificationsDenied: String
    let settingsNotificationsNotDetermined: String
    let settingsNotificationsRequestButton: String
    let settingsNotificationsOpenSystemButton: String

    // Settings — Threshold sections
    let settings5hThresholdsHeader: String
    let settings5hThresholdsCaption: String
    let settings7dThresholdsHeader: String
    let settings7dThresholdsCaption: String

    // Settings — System
    let settingsSystemHeader: String
    let settingsLaunchAtLogin: String
    let settingsLaunchAtLoginRequiresApproval: String

    // Settings — Polling
    let settingsPollingHeader: String
    let settingsPollingLabel: String
    let settingsPollingCaption: String
    let pollMin1: String
    let pollMin5: String
    let pollMin15: String

    // Settings — Language
    let settingsLanguageHeader: String
    let settingsLanguageLabel: String
    let settingsLanguageCaption: String
    let settingsLanguageRestartWarning: String
    let settingsLanguageRestartButton: String

    // Settings — About
    let settingsAboutHeader: String
    let settingsAboutCaption: String

    // Notifications
    let notifThresholdTitle: (Int) -> String       // argument: threshold %
    let notifScope5h: String
    let notifScope7d: String
    let notifCurrentPct: (Int) -> String           // argument: current %

    // Google sign-in block
    let googleBlockedTitle: String
    let googleBlockedBody: String
    let googleBlockedOK: String
}

extension AppLanguage {
    var strings: Strings {
        switch self {
        case .korean:    return .korean
        case .english:   return .english
        case .japanese:  return .japanese
        }
    }
}

extension Strings {
    static let korean = Strings(
        popoverTitleUsage: "Claude Usage",
        popoverTitleSettings: "설정",
        reloadHelp: "새로고침",
        settingsButton: "설정",
        backButton: "뒤로",
        quitMenu: "Claude Usage 종료",

        statusAuthRequired: "로그인이 필요하거나 리디렉션이 막혔습니다. 위쪽 WebView에서 로그인해주세요.",
        statusParseError: { detail in "수치를 읽지 못했습니다 — claude.ai UI 변경 가능성. (\(detail))" },
        statusNetwork: { detail in "네트워크 오류: \(detail)" },

        settingsNotificationsHeader: "알림 권한",
        settingsNotificationsAuthorized: "알림이 켜져 있습니다.",
        settingsNotificationsDenied: "알림이 차단됐습니다. 시스템 설정에서 허용해주세요.",
        settingsNotificationsNotDetermined: "알림 권한을 요청해주세요.",
        settingsNotificationsRequestButton: "허용 요청",
        settingsNotificationsOpenSystemButton: "시스템 설정 열기",

        settings5hThresholdsHeader: "5h 세션 임계치",
        settings5hThresholdsCaption: "5h 세션이 지정한 % 에 도달하면 알림. 같은 세션 안에서는 한 번만.",
        settings7dThresholdsHeader: "7d 주간 임계치",
        settings7dThresholdsCaption: "7d 주간 한도 임계치. 주간 리셋 전까지 한 번만.",

        settingsSystemHeader: "시스템",
        settingsLaunchAtLogin: "로그인 시 자동 시작",
        settingsLaunchAtLoginRequiresApproval: "시스템 설정 → 로그인 항목에서 이 앱을 허용해주세요.",

        settingsPollingHeader: "폴링 주기",
        settingsPollingLabel: "팝오버 열려있을 때",
        settingsPollingCaption: "팝오버가 닫혀있을 때는 이 간격의 3배마다 폴링합니다.",
        pollMin1: "1분",
        pollMin5: "5분",
        pollMin15: "15분",

        settingsLanguageHeader: "언어",
        settingsLanguageLabel: "표시 언어",
        settingsLanguageCaption: "로그인 화면과 claude.ai 설정 페이지가 이 언어로 표시됩니다. 앱 UI도 함께 변경됩니다.",
        settingsLanguageRestartWarning: "언어가 적용되려면 앱을 다시 시작해주세요.",
        settingsLanguageRestartButton: "지금 재시작",

        settingsAboutHeader: "About",
        settingsAboutCaption: "이 앱은 claude.ai/settings/usage 를 WebView 로 읽어 공식 % 값을 그대로 표시합니다. 수치는 Anthropic 서버 기준으로 항상 정확합니다.",

        notifThresholdTitle: { pct in "Claude 사용량 \(pct)% 도달" },
        notifScope5h: "5h 세션",
        notifScope7d: "7d 주간",
        notifCurrentPct: { pct in "현재 \(pct)%" },

        googleBlockedTitle: "Google 로그인은 지원되지 않습니다",
        googleBlockedBody: "Google 정책으로 macOS 앱 내부 WebView 에서의 Google 로그인이 차단되어 있습니다.\n\nClaude 로그인 화면에서 \"이메일로 계속하기\" 를 선택해 이메일 인증 코드로 로그인해주세요.",
        googleBlockedOK: "확인"
    )

    static let english = Strings(
        popoverTitleUsage: "Claude Usage",
        popoverTitleSettings: "Settings",
        reloadHelp: "Reload",
        settingsButton: "Settings",
        backButton: "Back",
        quitMenu: "Quit Claude Usage",

        statusAuthRequired: "You're signed out or a redirect was blocked. Please sign in inside the WebView above.",
        statusParseError: { detail in "Couldn't read the numbers — claude.ai UI may have changed. (\(detail))" },
        statusNetwork: { detail in "Network error: \(detail)" },

        settingsNotificationsHeader: "Notifications",
        settingsNotificationsAuthorized: "Notifications are enabled.",
        settingsNotificationsDenied: "Notifications are blocked. Please allow them in System Settings.",
        settingsNotificationsNotDetermined: "Please request notification permission.",
        settingsNotificationsRequestButton: "Request permission",
        settingsNotificationsOpenSystemButton: "Open System Settings",

        settings5hThresholdsHeader: "5h session thresholds",
        settings5hThresholdsCaption: "Notify when the 5h session reaches these %. Once per session only.",
        settings7dThresholdsHeader: "7d weekly thresholds",
        settings7dThresholdsCaption: "Thresholds for the 7d weekly limit. Once per weekly reset.",

        settingsSystemHeader: "System",
        settingsLaunchAtLogin: "Launch at login",
        settingsLaunchAtLoginRequiresApproval: "Enable this app under System Settings → Login Items.",

        settingsPollingHeader: "Poll interval",
        settingsPollingLabel: "While popover is open",
        settingsPollingCaption: "When closed the app polls at 3× this interval.",
        pollMin1: "1 min",
        pollMin5: "5 min",
        pollMin15: "15 min",

        settingsLanguageHeader: "Language",
        settingsLanguageLabel: "Display language",
        settingsLanguageCaption: "The login screen and claude.ai settings pages display in this language. The app's own UI also follows this setting.",
        settingsLanguageRestartWarning: "Please relaunch the app for the language change to take effect.",
        settingsLanguageRestartButton: "Relaunch now",

        settingsAboutHeader: "About",
        settingsAboutCaption: "This app reads claude.ai/settings/usage inside a WebView and surfaces the exact same % values. Numbers are authoritative — pulled from Anthropic's own dashboard.",

        notifThresholdTitle: { pct in "Claude usage at \(pct)%" },
        notifScope5h: "5h session",
        notifScope7d: "7d weekly",
        notifCurrentPct: { pct in "now at \(pct)%" },

        googleBlockedTitle: "Sign in with Google isn't supported here",
        googleBlockedBody: "Google's policy blocks its sign-in flow inside embedded WebViews for security reasons.\n\nOn the Claude sign-in screen, please choose \"Continue with email\" and log in with an email verification code instead.",
        googleBlockedOK: "OK"
    )

    static let japanese = Strings(
        popoverTitleUsage: "Claude Usage",
        popoverTitleSettings: "設定",
        reloadHelp: "再読み込み",
        settingsButton: "設定",
        backButton: "戻る",
        quitMenu: "Claude Usage を終了",

        statusAuthRequired: "サインインが必要か、リダイレクトがブロックされました。上部の WebView でログインしてください。",
        statusParseError: { detail in "数値を読み取れませんでした — claude.ai の UI が変更された可能性があります。(\(detail))" },
        statusNetwork: { detail in "ネットワークエラー: \(detail)" },

        settingsNotificationsHeader: "通知権限",
        settingsNotificationsAuthorized: "通知が有効になっています。",
        settingsNotificationsDenied: "通知がブロックされています。システム設定で許可してください。",
        settingsNotificationsNotDetermined: "通知権限をリクエストしてください。",
        settingsNotificationsRequestButton: "権限をリクエスト",
        settingsNotificationsOpenSystemButton: "システム設定を開く",

        settings5hThresholdsHeader: "5h セッションしきい値",
        settings5hThresholdsCaption: "5h セッションが指定した % に達したら通知します。同じセッション内で一度だけ。",
        settings7dThresholdsHeader: "7d 週間しきい値",
        settings7dThresholdsCaption: "週次制限のしきい値。週次リセットまで一度だけ。",

        settingsSystemHeader: "システム",
        settingsLaunchAtLogin: "ログイン時に自動起動",
        settingsLaunchAtLoginRequiresApproval: "システム設定 → ログイン項目 でこのアプリを許可してください。",

        settingsPollingHeader: "ポーリング間隔",
        settingsPollingLabel: "ポップオーバーが開いている時",
        settingsPollingCaption: "閉じている時はこの間隔の 3 倍ごとにポーリングします。",
        pollMin1: "1分",
        pollMin5: "5分",
        pollMin15: "15分",

        settingsLanguageHeader: "言語",
        settingsLanguageLabel: "表示言語",
        settingsLanguageCaption: "ログイン画面と claude.ai 設定ページがこの言語で表示されます。アプリの UI もこれに合わせて変わります。",
        settingsLanguageRestartWarning: "言語を適用するにはアプリを再起動してください。",
        settingsLanguageRestartButton: "今すぐ再起動",

        settingsAboutHeader: "About",
        settingsAboutCaption: "このアプリは claude.ai/settings/usage を WebView で読み込み、公式の % 値をそのまま表示します。数値は Anthropic サーバーの値なので常に正確です。",

        notifThresholdTitle: { pct in "Claude 使用量 \(pct)% に到達" },
        notifScope5h: "5h セッション",
        notifScope7d: "7d 週間",
        notifCurrentPct: { pct in "現在 \(pct)%" },

        googleBlockedTitle: "Google ログインはご利用いただけません",
        googleBlockedBody: "Google のポリシーにより、組み込み WebView 内での Google ログインはブロックされています。\n\nClaude のログイン画面で「メールで続行」を選択し、メール認証コードでログインしてください。",
        googleBlockedOK: "OK"
    )
}

// MARK: - SwiftUI environment

private struct AppLanguageKey: EnvironmentKey {
    static let defaultValue: AppLanguage = AppLanguage.default
}

extension EnvironmentValues {
    var appLanguage: AppLanguage {
        get { self[AppLanguageKey.self] }
        set { self[AppLanguageKey.self] = newValue }
    }
}
