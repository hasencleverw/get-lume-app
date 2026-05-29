import Foundation
import SwiftUI

/// Update notifier — Swift port of the Tauri `updater.rs` service.
///
/// Hits the GitHub Releases API ≤ 1×/week. If the latest non-prerelease,
/// non-draft tag is semver-greater than the running app's
/// `CFBundleShortVersionString`, an "Update available" banner is surfaced to
/// the user. The app NEVER downloads or installs anything automatically —
/// clicking the banner opens the GitHub release page in the browser.
///
/// State persistence lives in `UserDefaults` so the banner can render
/// instantly on app boot from cached data, before the next async check fires.
@MainActor
final class UpdaterService: ObservableObject {

    @Published private(set) var current: String = ""
    @Published private(set) var latest: String?
    @Published private(set) var releaseURL: URL?
    @Published private(set) var releaseNotes: String?
    @Published private(set) var available: Bool = false
    @Published private(set) var lastCheckDate: Date?
    @Published private(set) var checking: Bool = false
    @Published private(set) var lastError: String?

    /// Owner/repo on GitHub. Mirrored from `windows-linux/src-tauri/src/services/updater.rs`.
    /// If you fork or rename the repo, change both this constant and the Rust one.
    private static let repo = "hasencleverw/get-lume-app"
    private static let sevenDays: TimeInterval = 7 * 24 * 60 * 60

    // UserDefaults keys
    private let kLastCheck = "lume.updater.lastCheckTime"
    private let kLastLatest = "lume.updater.lastLatest"
    private let kLastURL = "lume.updater.lastURL"
    private let kLastNotes = "lume.updater.lastNotes"

    init() {
        self.current = (Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String) ?? "1.0.0"
        loadCachedState()
        renderAvailability()
    }

    // MARK: - Public API

    /// Called once on app launch. Performs a check only if 7 days have passed
    /// since the last one (or never). Banner state is rendered from cache
    /// regardless so the user sees the previous result instantly.
    func bootstrap() {
        renderAvailability()
        guard shouldCheckNow else { return }
        Task { await checkNow() }
    }

    /// Forces an immediate check, regardless of the throttle window. Wired to
    /// the "Verificar Atualizações" button in Settings → Updates.
    func checkNow() async {
        guard !checking else { return }
        checking = true
        defer { checking = false }

        do {
            let release = try await fetchLatestRelease()
            let cleaned = release.tag_name.trimmingPrefix("v")
            let latestStr = String(cleaned)

            // Persist
            let now = Date()
            UserDefaults.standard.set(now.timeIntervalSince1970, forKey: kLastCheck)
            UserDefaults.standard.set(latestStr, forKey: kLastLatest)
            UserDefaults.standard.set(release.html_url, forKey: kLastURL)
            UserDefaults.standard.set(release.body ?? "", forKey: kLastNotes)

            // Publish
            self.lastCheckDate = now
            self.latest = latestStr
            self.releaseURL = URL(string: release.html_url)
            self.releaseNotes = release.body
            self.lastError = nil
            renderAvailability()
        } catch {
            // Bump last-check anyway so a transient failure doesn't make us hammer the API.
            let now = Date()
            UserDefaults.standard.set(now.timeIntervalSince1970, forKey: kLastCheck)
            self.lastCheckDate = now
            self.lastError = error.localizedDescription
        }
    }

    /// Opens the cached release page in the default browser.
    func openReleasePage() {
        if let url = releaseURL { NSWorkspace.shared.open(url) }
    }

    // MARK: - State

    private var shouldCheckNow: Bool {
        guard let last = lastCheckDate else { return true }
        return Date().timeIntervalSince(last) >= Self.sevenDays
    }

    private func loadCachedState() {
        let d = UserDefaults.standard
        if let t = d.object(forKey: kLastCheck) as? TimeInterval {
            lastCheckDate = Date(timeIntervalSince1970: t)
        }
        latest = d.string(forKey: kLastLatest)
        releaseURL = d.string(forKey: kLastURL).flatMap(URL.init(string:))
        let notes = d.string(forKey: kLastNotes) ?? ""
        releaseNotes = notes.isEmpty ? nil : notes
    }

    private func renderAvailability() {
        guard let latestStr = latest else { available = false; return }
        available = Self.semverGreater(latestStr, than: current)
    }

    // MARK: - GitHub API

    private struct GhRelease: Decodable {
        let tag_name: String
        let html_url: String
        let body: String?
        let draft: Bool?
        let prerelease: Bool?
    }

    private func fetchLatestRelease() async throws -> GhRelease {
        let url = URL(string: "https://api.github.com/repos/\(Self.repo)/releases/latest")!
        var req = URLRequest(url: url)
        req.httpMethod = "GET"
        req.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        req.setValue("Lume/\(current)", forHTTPHeaderField: "User-Agent")
        req.timeoutInterval = 10

        let (data, response) = try await URLSession.shared.data(for: req)
        guard let http = response as? HTTPURLResponse else { throw UpdaterError.badResponse }
        if http.statusCode == 404 { throw UpdaterError.noReleases }
        guard 200..<300 ~= http.statusCode else { throw UpdaterError.httpStatus(http.statusCode) }

        let release = try JSONDecoder().decode(GhRelease.self, from: data)
        if release.draft == true || release.prerelease == true {
            throw UpdaterError.prerelease
        }
        return release
    }

    enum UpdaterError: LocalizedError {
        case badResponse, noReleases, prerelease, httpStatus(Int)
        var errorDescription: String? {
            switch self {
            case .badResponse:  return "Unexpected response from GitHub"
            case .noReleases:   return "Repository has no releases yet"
            case .prerelease:   return "Latest release is a draft/prerelease"
            case .httpStatus(let s): return "HTTP \(s)"
            }
        }
    }

    // MARK: - Semver

    /// Returns true iff `a` > `b` under SemVer 2.0 ordering.
    /// Mirrors the `semver` Rust crate behavior used by the Tauri updater.
    static func semverGreater(_ a: String, than b: String) -> Bool {
        guard let pa = parseSemver(a), let pb = parseSemver(b) else { return false }
        // Numeric core comparison
        for (x, y) in zip(pa.core, pb.core) {
            if x != y { return x > y }
        }
        if pa.core.count != pb.core.count { return pa.core.count > pb.core.count }
        // Equal cores → handle pre-release: NO pre-release > WITH pre-release
        switch (pa.pre.isEmpty, pb.pre.isEmpty) {
        case (true, true):   return false
        case (true, false):  return true   // 1.0.0 > 1.0.0-beta
        case (false, true):  return false  // 1.0.0-beta < 1.0.0
        case (false, false): return pa.pre > pb.pre
        }
    }

    private static func parseSemver(_ raw: String) -> (core: [Int], pre: String)? {
        let s = raw.split(separator: "+", maxSplits: 1).first.map(String.init) ?? raw
        var pre = ""
        var coreStr = s
        if let dash = s.firstIndex(of: "-") {
            pre = String(s[s.index(after: dash)...])
            coreStr = String(s[..<dash])
        }
        let parts = coreStr.split(separator: ".").compactMap { Int($0) }
        guard !parts.isEmpty else { return nil }
        return (parts, pre)
    }
}
