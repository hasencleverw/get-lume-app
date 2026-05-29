import Foundation

/// Tracks launch counts per device for the developer to monitor active installs.
/// Data is stored locally in ~/Library/Application Support/Lume/analytics.json
/// and optionally pinged to a remote counter endpoint.
final class AnalyticsService {
    static let shared = AnalyticsService()

    private let defaults = UserDefaults.standard
    private let launchCountKey  = "lume.launchCount"
    private let deviceIdKey     = "lume.deviceId"
    private let firstLaunchKey  = "lume.firstLaunch"
    private let appVersion      = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"

    // MARK: - Public properties (developer-accessible)

    /// Persistent device UUID — unique per install
    var deviceId: String {
        if let id = defaults.string(forKey: deviceIdKey) { return id }
        let id = UUID().uuidString
        defaults.set(id, forKey: deviceIdKey)
        return id
    }

    /// Total launches ever recorded on this device
    var launchCount: Int { defaults.integer(forKey: launchCountKey) }

    /// Date of very first launch on this device
    var firstLaunchDate: Date? { defaults.object(forKey: firstLaunchKey) as? Date }

    // MARK: - Record launch (call once at app startup)
    func recordLaunch() {
        let count = launchCount + 1
        defaults.set(count, forKey: launchCountKey)
        if firstLaunchDate == nil {
            defaults.set(Date(), forKey: firstLaunchKey)
        }
        saveLocalEntry(count: count)
        pingRemote(count: count)
    }

    // MARK: - Developer summary (readable via Console.app or debug builds)
    func printSummary() {
        let first = firstLaunchDate.map {
            DateFormatter.localizedString(from: $0, dateStyle: .medium, timeStyle: .short)
        } ?? "N/A"

        print("""
        ┌─ Lume Analytics ─────────────────────────────
        │ Device ID    : \(deviceId)
        │ Launch Count : \(launchCount)
        │ First Launch : \(first)
        │ App Version  : \(appVersion)
        │ OS Version   : \(ProcessInfo.processInfo.operatingSystemVersionString)
        │ Log file     : \(analyticsFileURL.path)
        └───────────────────────────────────────────────
        """)
    }

    // MARK: - Local log
    private func saveLocalEntry(count: Int) {
        let entry: [String: Any] = [
            "deviceId":    deviceId,
            "launchCount": count,
            "version":     appVersion,
            "os":          ProcessInfo.processInfo.operatingSystemVersionString,
            "timestamp":   ISO8601DateFormatter().string(from: Date())
        ]

        var entries: [[String: Any]] = []
        if let data = try? Data(contentsOf: analyticsFileURL),
           let existing = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] {
            entries = existing
        }
        entries.append(entry)
        if entries.count > 500 { entries = Array(entries.suffix(500)) }

        if let data = try? JSONSerialization.data(withJSONObject: entries, options: [.prettyPrinted, .sortedKeys]) {
            try? data.write(to: analyticsFileURL)
        }
    }

    var analyticsFileURL: URL {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = support.appendingPathComponent("Lume")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("analytics.json")
    }

    // MARK: - Remote ping (fire-and-forget, non-blocking)
    private func pingRemote(count: Int) {
        // Endpoint: replace with your own server or use a free counter API
        // The request carries: deviceId, count, version as query params
        // This makes it easy to count unique devices and total launches server-side.
        guard let url = URL(string: "https://api.counterapi.dev/v1/lume-mac-app/launches/up") else { return }

        var req = URLRequest(url: url)
        req.httpMethod = "GET"
        req.setValue("Lume/\(appVersion)", forHTTPHeaderField: "User-Agent")
        req.timeoutInterval = 8

        URLSession.shared.dataTask(with: req) { data, _, _ in
            // Response ignored — best-effort only
        }.resume()
    }

    private init() {}
}
