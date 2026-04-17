import Foundation
import Observation
import WebKit

/// Overall app status summarizing what the sampler has observed.
enum UsageStatus: Equatable {
    case booting                      // No sample yet
    case loading                      // Webview is mid-navigation
    case ok(session: UsageReading, weekly: UsageReading, plan: String?)
    case authRequired                 // Login expired or redirect loop
    case parseError(String)           // DOM extracted but shape unexpected
    case network(String)              // didFailProvisionalNavigation etc.
}

struct UsageReading: Equatable {
    let percent: Int
    /// Absolute reset time if it could be computed from the DOM's ETA label.
    let resetAt: Date?
    /// Raw reset-label text from the DOM (preserved verbatim for display).
    let resetLabel: String?
}

/// Drives periodic sampling of the embedded claude.ai/settings/usage page.
///
/// Flow per tick:
///   1. evaluateJavaScript on the WKWebView to pull %/reset/plan out of the DOM
///   2. update `status`
///   3. detect newly-crossed thresholds → post a local notification
///   4. if the parser breaks for N consecutive ticks → surface an error state
///
/// Dedup: fired thresholds are stored in UserDefaults keyed by the *reset bucket*
/// for that scope. When a new session/week begins (bucket advances), the fired
/// set is automatically empty so the same threshold fires again.
@MainActor
@Observable
final class UsageSampler {
    // MARK: Public state
    private(set) var status: UsageStatus = .booting
    private(set) var lastSampleAt: Date?
    private(set) var consecutiveFailures = 0

    /// True while the webview hasn't finished its first navigation. Shown as a spinner.
    var isWebViewLoading: Bool = false
    var isAuthBlocked: Bool = false

    // MARK: Configuration (persisted via @AppStorage in SettingsView)
    private let defaults = UserDefaults.standard

    var thresholds5h: [Int] {
        (defaults.array(forKey: "thresholds5h") as? [Int]) ?? [75, 90]
    }
    var thresholds7d: [Int] {
        (defaults.array(forKey: "thresholds7d") as? [Int]) ?? [80]
    }
    var pollIntervalOpen: TimeInterval {
        let v = defaults.double(forKey: "pollIntervalSeconds")
        return v > 0 ? v : 60
    }
    var pollIntervalClosed: TimeInterval {
        pollIntervalOpen * 3
    }

    // MARK: Internal
    private weak var webView: WKWebView?
    private var timer: Timer?
    private var popoverOpen: Bool = false

    init() {}

    func attach(_ webView: WKWebView) {
        self.webView = webView
    }

    func setPopoverOpen(_ open: Bool) {
        popoverOpen = open
        restartTimer()
        if open {
            Task { await sample() }
        }
    }

    func forceSample() {
        Task { await sample() }
    }

    // MARK: Timer

    private func restartTimer() {
        timer?.invalidate()
        let interval = popoverOpen ? pollIntervalOpen : pollIntervalClosed
        let t = Timer(timeInterval: interval, repeats: true) { [weak self] _ in
            Task { @MainActor in await self?.sample() }
        }
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    // MARK: Sampling

    private func sample() async {
        guard let webView else { return }
        if isAuthBlocked {
            status = .authRequired
            return
        }
        if isWebViewLoading {
            if case .ok = status { return }  // keep last good
            status = .loading
            return
        }

        do {
            let raw = try await webView.evaluateJavaScript(Self.extractionJS)
            guard let jsonString = raw as? String,
                  let data = jsonString.data(using: .utf8),
                  let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
            else {
                recordFailure(reason: "JS returned unexpected type")
                return
            }
            try handle(obj)
        } catch {
            recordFailure(reason: error.localizedDescription)
        }
    }

    private func handle(_ obj: [String: Any]) throws {
        guard obj["ok"] as? Bool == true else {
            recordFailure(reason: (obj["reason"] as? String) ?? "not ok")
            return
        }
        if obj["spinner"] as? Bool == true {
            // Page still rendering; don't overwrite last known good
            if case .ok = status { return }
            status = .loading
            return
        }
        if obj["loggedIn"] as? Bool == false {
            status = .authRequired
            return
        }

        let plan = obj["plan"] as? String
        let session = Self.readingFrom(obj["session"] as? [String: Any])
        let weekly = Self.readingFrom(obj["weekly"] as? [String: Any])

        guard let session, let weekly else {
            recordFailure(reason: "session/weekly missing in samples")
            return
        }

        consecutiveFailures = 0
        status = .ok(session: session, weekly: weekly, plan: plan)
        lastSampleAt = Date()

        checkThresholds(scope: .session, reading: session)
        checkThresholds(scope: .weekly, reading: weekly)
    }

    private func recordFailure(reason: String) {
        consecutiveFailures += 1
        // Keep last good reading on screen until we've failed several consecutive
        // polls — one glitch shouldn't blank the UI.
        if consecutiveFailures >= 3 {
            status = .parseError(reason)
        }
    }

    // MARK: Threshold detection & dedup

    private enum Scope: String {
        case session, weekly
    }

    private func checkThresholds(scope: Scope, reading: UsageReading) {
        let thresholds = scope == .session ? thresholds5h : thresholds7d
        let bucket = bucketKey(scope: scope, reading: reading)
        let firedKey = "fired.\(scope.rawValue).\(bucket)"
        var fired = Set(defaults.array(forKey: firedKey) as? [Int] ?? [])

        let newlyCrossed = thresholds
            .sorted()
            .filter { reading.percent >= $0 && !fired.contains($0) }

        guard !newlyCrossed.isEmpty else { return }
        for t in newlyCrossed {
            fireThresholdNotification(scope: scope, threshold: t, reading: reading, bucket: bucket)
            fired.insert(t)
        }
        defaults.set(Array(fired).sorted(), forKey: firedKey)
        pruneOldBuckets(scope: scope)
    }

    private func bucketKey(scope: Scope, reading: UsageReading) -> String {
        switch scope {
        case .session:
            // Round resetAt to 5-minute buckets so ETA-string jitter doesn't drift the key.
            if let resetAt = reading.resetAt {
                let rounded = (resetAt.timeIntervalSince1970 / 300).rounded() * 300
                return "ra_\(Int(rounded))"
            }
            // Fallback: day-bucket if no ETA parsed
            let fmt = DateFormatter()
            fmt.dateFormat = "yyyyMMdd_HH"
            return "day_\(fmt.string(from: Date()))"
        case .weekly:
            // ISO week number
            let comps = Calendar(identifier: .iso8601).dateComponents([.yearForWeekOfYear, .weekOfYear], from: Date())
            return "iso_\(comps.yearForWeekOfYear ?? 0)_\(comps.weekOfYear ?? 0)"
        }
    }

    private func pruneOldBuckets(scope: Scope) {
        let prefix = "fired.\(scope.rawValue)."
        let keys = defaults.dictionaryRepresentation().keys.filter { $0.hasPrefix(prefix) }
        guard keys.count > 8 else { return }
        // Keep the 4 most recent by lexicographic suffix (timestamps / week numbers sort correctly)
        let sorted = keys.sorted()
        for k in sorted.dropLast(4) {
            defaults.removeObject(forKey: k)
        }
    }

    private func fireThresholdNotification(scope: Scope, threshold: Int, reading: UsageReading, bucket: String) {
        let scopeLabel = scope == .session ? "5h 세션" : "7d 주간"
        let title = "Claude 사용량 \(threshold)% 도달"
        var body = "\(scopeLabel) · 현재 \(reading.percent)%"
        if let r = reading.resetLabel {
            body += " · \(r)"
        }
        let id = "threshold.\(scope.rawValue).\(bucket).\(threshold)"
        NotificationManager.shared.post(identifier: id, title: title, body: body)
    }

    // MARK: JS → Swift

    private static func readingFrom(_ obj: [String: Any]?) -> UsageReading? {
        guard let obj,
              let pct = obj["pct"] as? Int
        else { return nil }
        let resetLabel = obj["resetStr"] as? String
        let resetAt = resetLabel.flatMap { parseResetETA($0) }
        return UsageReading(percent: pct, resetAt: resetAt, resetLabel: resetLabel)
    }

    /// Convert a human reset label to an absolute `Date` when possible.
    /// Supports Korean "N시간 M분 후", "M분 후" and English "Nh Mm", "Mm".
    /// Absolute-time labels (e.g. "(금) 오전 10:00에 재설정") are left unparsed for v1
    /// — weekly bucketing uses ISO week instead.
    static func parseResetETA(_ s: String, now: Date = Date()) -> Date? {
        func firstInts(in range: String) -> [Int] {
            range.split(whereSeparator: { !$0.isNumber }).compactMap { Int($0) }
        }
        if let m = s.range(of: #"(\d+)\s*시간\s*(\d+)\s*분"#, options: .regularExpression) {
            let ints = firstInts(in: String(s[m]))
            if ints.count >= 2 {
                return now.addingTimeInterval(TimeInterval(ints[0] * 3600 + ints[1] * 60))
            }
        }
        if let m = s.range(of: #"(\d+)\s*h\s*(\d+)\s*m"#, options: .regularExpression) {
            let ints = firstInts(in: String(s[m]))
            if ints.count >= 2 {
                return now.addingTimeInterval(TimeInterval(ints[0] * 3600 + ints[1] * 60))
            }
        }
        if let m = s.range(of: #"(\d+)\s*분\s*후"#, options: .regularExpression) {
            let ints = firstInts(in: String(s[m]))
            if !ints.isEmpty {
                return now.addingTimeInterval(TimeInterval(ints[0] * 60))
            }
        }
        if let m = s.range(of: #"(\d+)\s*m\b"#, options: .regularExpression) {
            let ints = firstInts(in: String(s[m]))
            if !ints.isEmpty {
                return now.addingTimeInterval(TimeInterval(ints[0] * 60))
            }
        }
        return nil
    }

    /// JS snippet injected into the rendered page. Returns a JSON string.
    static let extractionJS: String = #"""
    (() => {
      const root = document.body ? document.body.innerText : "";
      if (!root) return JSON.stringify({ ok: false, reason: "empty body" });
      const lines = root.split(/\n+/).map(s => s.trim()).filter(Boolean);
      const pctRegex = /(\d{1,3})\s*%/;

      const etaInLine = (s) => {
        const m = s.match(/(\d+)\s*시간\s*(\d+)\s*분|(\d+)\s*h\s*(\d+)\s*m\b|(\d+)\s*분\s*후|(\d+)\s*m\b|\([가-힣]{1,2}\)[^,\n|]*|resets?[^,\n|]*/i);
        return m ? m[0] : null;
      };

      const samples = [];
      lines.forEach((line, idx) => {
        const pctMatch = line.match(pctRegex);
        if (!pctMatch) return;
        const pct = +pctMatch[1];
        if (pct < 0 || pct > 999) return;

        const ctx = lines.slice(Math.max(0, idx - 10), idx + 1).join(" | ");
        let scope = "unknown";
        if (/현재\s*세션|current\s*session|5\s*h/i.test(ctx)) scope = "session";
        else if (/주간|weekly|7\s*d/i.test(ctx)) scope = "weekly";
        if (scope === "unknown") return;

        let resetStr = null;
        for (let j = idx - 1; j >= Math.max(0, idx - 6); j--) {
          const eta = etaInLine(lines[j]);
          if (eta) { resetStr = lines[j]; break; }
        }
        samples.push({ pct, scope, resetStr });
      });

      const session = samples.find(s => s.scope === "session") || null;
      const weekly = samples.find(s => s.scope === "weekly") || null;
      const plan = (root.match(/Max\s*\(\s*\d+x\s*\)|Max\s+\d+x|Pro|Team|Enterprise/) || [null])[0];
      const spinner = !!document.querySelector('[role="progressbar"], .animate-spin');
      const loggedIn = !/Sign\s+in|Log\s+in|로그인|continue\s+with\s+google/i.test(root.slice(0, 800));

      return JSON.stringify({
        ok: true, spinner, plan, loggedIn,
        session, weekly,
        at: Date.now()
      });
    })();
    """#
}
