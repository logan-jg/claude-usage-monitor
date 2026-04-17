# Claude Usage Monitor

Status: **v0.2.2 released · shared internally · on hold pending feedback** (2026-04-17)

- Repo: https://github.com/logan-jg/claude-usage-monitor (public, MIT)
- Latest release: https://github.com/logan-jg/claude-usage-monitor/releases/tag/v0.2.2
- Bundle ID: `com.logan.ClaudeUsageMonitor`
- Path: `~/workspace/claude_tracker/`

---

## What this app does

macOS menu bar app that embeds `claude.ai/settings/usage` in a WKWebView and surfaces the **real Anthropic dashboard numbers** (5h session % / 7d weekly %) in the menu bar. Posts local notifications when user-configurable thresholds are crossed. Single source of truth is the rendered page — no estimates, no API key juggling.

## Architecture (as shipped)

```
Menu bar icon
   │
   ▼
PopoverView (WKWebView + embedded SettingsView)
   │
   ├── UsageWebView ─── WKWebView loading claude.ai/settings/usage
   │        │                 │
   │        │                 └── injected CSS hides settings chrome
   │        │                     (nav[aria-label=설정/Settings/사이드바], page header)
   │        │
   │        └── Navigation delegate auto-returns to /settings/usage if the
   │            SPA drifts to chat/home — but preserves /login /oauth /auth
   │            flows so sign-in isn't interrupted.
   │
   └── UsageSampler (60s while open / 180s closed)
            │
            ▼ evaluateJavaScript
         innerText regex → session % / weekly % / reset labels
            │
            ▼
         Threshold check → NotificationManager
            (bucketed by reset epoch so the same % fires once per window)
```

## Key decisions (the journey)

Originally planned to parse `~/.claude/projects/**/*.jsonl` locally for token counts. After validation this turned out to be **measurably wrong** — local API-price estimation diverged from the subscription's actual dollar equivalence by ~3×. Calibration helped but still drifted per session boundary.

Tried OAuth → `api.anthropic.com/api/oauth/usage`: **returns `rate_limit_error`** for all OAuth tokens. Anthropic intentionally blocks this.

Final call: **embed the real dashboard in WKWebView**. Accuracy is 100% by construction (same numbers the user sees on the web), cookies live in the app's own WebKit data store, and everything happens locally.

## File layout (current)

```
Sources/ClaudeUsageMonitor/
├── App.swift                   # @main, MenuBarExtra, language injection
├── AppLanguage.swift           # ko/en/ja enum + AppleLanguages bridge
├── Localization.swift          # full Strings struct × 3 languages + SwiftUI env
├── UsageWebView.swift          # NSViewRepresentable WKWebView
│                                  - persistent cookies
│                                  - injected CSS to hide settings chrome
│                                  - nav delegate: auth-safe snap-back
│                                  - URL scheme allowlist on popups
├── UsageSampler.swift          # @Observable, Timer-driven DOM sampling
│                                  - extractionJS regex
│                                  - threshold detection with bucketed dedup
│                                  - ISO-week bucket for weekly scope
├── NotificationManager.swift   # UNUserNotificationCenter wrapper + delegate
│                                  - forces banner in foreground
├── LaunchAtLogin.swift         # SMAppService.mainApp wrapper
├── PopoverView.swift           # header + webview ↔ settings toggle + status strip
│                                  - ultraThinMaterial header
│                                  - URL-aware onAppear (no interrupting login)
└── SettingsView.swift          # form: permissions / thresholds / polling /
                                   language / about
```

## Release history

| Ver | Date | Change |
|---|---|---|
| v0.1.0 | 2026-04-17 | Initial public release |
| v0.2.0 | 2026-04-17 | i18n (한국어/English/日本語), WebView locale switching, better Sequoia install docs |
| v0.2.1 | 2026-04-17 | Fix: popover reopen no longer restarts mid-login |
| v0.2.2 | 2026-04-17 | Fix: auto-return to /settings/usage after login redirects to /new |

All releases are ad-hoc signed `.app` bundles delivered as zip on GitHub Releases.

## Install (for users)

```bash
# 1. Download the latest zip, unzip, drop .app into /Applications
# 2. Clear the quarantine flag (one-time)
xattr -dr com.apple.quarantine /Applications/ClaudeUsageMonitor.app
# 3. Launch
open /Applications/ClaudeUsageMonitor.app
```

Cookies and settings persist across upgrades — overwriting `.app` doesn't log the user out.

## Build (for contributors)

Requires Command Line Tools 26.4.1+ (Swift 6.3+).

```bash
make install            # local /Applications install
make release VERSION=x  # dist/ClaudeUsageMonitor-x.zip
```

No SPM dependencies. `Package.swift` exists for future `swift build` once CLT ships the `swiftLanguageModes` symbol fix.

## Security posture

Audited after v0.1 (`compound-engineering:review:security-sentinel`). Findings:

- **Fixed:** `NSWorkspace.open()` now allowlists `http/https/mailto` only (blocks `file://` and custom-scheme abuse).
- **Fixed:** `/tmp/claude_tracker_dom.html` debug dump hook removed.
- **Verified clean:** no `document.cookie` / `localStorage` read in injected JS. Static CSS/JS strings, no user input interpolated.
- **Info:** ad-hoc signed + sandbox OFF — acceptable for local build / GitHub-zip distribution. Would need Developer ID + notarization + `com.apple.security.network.client` sandbox entitlement for App Store or wider distribution.

## What's on hold for v0.3

Paused until real-world feedback surfaces concrete bugs:

- 5h/7d **reset-completion notification** (cut from v0.1 as unreliable; revisit once user reports suggest it's missed)
- Custom app icon (`.icns`) — currently uses SF Symbol `gauge.*`
- Apple Silicon + Intel universal binary
- Developer ID signing + notarization if wider distribution happens
- Homebrew cask submission

## Current hold reason

Shipped v0.2.2 to an internal channel. Waiting on user feedback / bug reports before opening the next iteration. No active work until then.
