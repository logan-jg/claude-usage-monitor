# Claude Usage Monitor

macOS menu bar app that shows your **official** [Claude](https://claude.ai) usage right from your menu bar — the exact same `%` numbers as `claude.ai/settings/usage`, not a local estimate. Optional macOS notifications when you hit thresholds like 80% or 90%.

![menu bar popover](docs/popover.png) <!-- add screenshot here -->

## Why

If you're on Claude Pro / Max and push against your 5-hour session or 7-day weekly limits, you probably open `claude.ai/settings/usage` five times a day. This app puts that page one click away in your menu bar and pings you before you hit the wall.

- ✅ **100% accurate** — renders the real Anthropic dashboard, not a guess
- 🔔 **Threshold notifications** — configurable (default: 5h @ 75/90%, 7d @ 80%)
- 🔒 **Stays on your machine** — no third-party servers, no extra API calls. Your claude.ai cookies live only in the app's WebKit data store on your Mac
- 🪶 **Menu bar only** — no Dock icon, no windows cluttering your desktop

## Requirements

- macOS 14 (Sonoma) or later
- A Claude account (Pro or Max recommended — Free accounts will also show something but thresholds are less meaningful)

## Install

1. Download the latest `ClaudeUsageMonitor-<version>.zip` from the [Releases](https://github.com/logan-jg/claude-usage-monitor/releases) page
2. Unzip → drag `ClaudeUsageMonitor.app` to `/Applications`
3. **First launch**: since the app isn't signed with an Apple Developer ID, Gatekeeper will refuse a normal double-click. Work around it once with either:
   - **Recommended:** right-click the app → `열기` / `Open` → confirm the warning
   - Or from the Terminal: `xattr -dr com.apple.quarantine /Applications/ClaudeUsageMonitor.app`
4. A gauge icon appears in your menu bar. Click it → log in to Claude once inside the embedded WebView. You're done — cookies persist across relaunches.

## Using the app

- **Menu bar icon** — click to open the popover
- **설정 button** — toggle the popover between the usage dashboard and the app's settings
- **•••** — quit
- Popover **auto-reloads** to `claude.ai/settings/usage` every time it opens, so it never drifts to the chat homepage

### Settings

- **알림 권한** — request notification permission + sanity-check it's granted
- **5h 세션 임계치** — pick which `%` thresholds fire an alert (default `75%`, `90%`)
- **7d 주간 임계치** — same but for the weekly window (default `80%`)
- **로그인 시 자동 시작** — register as a macOS login item
- **폴링 주기** — how often to re-read the dashboard. `5분` is sensible for most users; `1분` if you're pushing limits

## Build from source

Requires Xcode Command Line Tools 26.4.1 or newer (Swift 6.3+).

```bash
git clone <this repo>
cd claude_tracker
make install        # builds, signs (ad-hoc), copies to /Applications
make run            # builds, bundles, opens from ./build
make release VERSION=0.1.0   # produces dist/ClaudeUsageMonitor-0.1.0.zip
```

No external dependencies; the Makefile invokes `swiftc` directly (SPM is currently broken on CLT 26.4.1, so `Package.swift` is a fallback for when that gets fixed).

## Privacy & security

- The app embeds `https://claude.ai/settings/usage` in a `WKWebView`. Everything behaves exactly as if you opened that URL in Safari, **except** the cookies live in this app's isolated data store instead of Safari's.
- The app never sends your cookies, tokens, or usage numbers anywhere other than claude.ai (which it was already talking to).
- External links clicked inside the webview (e.g. Claude's help pages) open in your default browser. Only `http`, `https`, and `mailto` schemes are allowed through — custom URL schemes are silently dropped.
- No analytics, no telemetry, no crash reporting.

## Known limitations

- **Ad-hoc signed.** Not notarized. If you redistribute the binary further, recipients get the same Gatekeeper prompt.
- **DOM-dependent.** The `%` values are read from claude.ai's rendered HTML. If Anthropic redesigns the settings page, the parser may break until this app is updated. When that happens the menu bar icon shows a warning state — it will not silently report stale numbers.
- **No weekly-reset notification in v0.1.** The "you just got your quota back" alert was cut because reset detection is unreliable without a trustworthy signal. Threshold alerts (80/90%) are the higher-value half and are in.
- **App Sandbox is off.** This is fine for a local, signed-by-yourself build — your own processes can already read each other. If you plan to redistribute seriously, the author recommends turning the sandbox on and notarizing.

## License

MIT. See [LICENSE](LICENSE).

## Credits

- Idea & product direction: [@logan-jg](https://github.com/logan-jg)
- SwiftUI + WebKit + the fact that Anthropic ships a solid web dashboard in the first place
