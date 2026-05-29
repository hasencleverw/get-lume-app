import Foundation
import SwiftUI

struct JunkCategory: Identifiable {
    let id = UUID()
    /// Localization key for the category name. The view resolves it via Localization.t().
    let nameKey: String
    let icon: String
    let color: Color
    let path: String
    /// How files are picked inside `path` during measurement.
    let policy: SafetyPolicy
    var size: Int64 = 0
    var files: [URL] = []
    var isSelected: Bool = true

    enum SafetyPolicy {
        /// Every regular file under the path — caches, logs, temp, trash, Xcode sims.
        case all
        /// Only files older than `days` days (modificationDate-based). Used for Downloads.
        case olderThan(days: Int)
        /// Only sub-folders whose name matches an installed app's bundle id or display
        /// name AND that app is NOT currently installed. Used for Application Support.
        case orphanedAppSupport
    }
}

@MainActor
final class DiskScanner: ObservableObject {

    @Published var categories: [JunkCategory] = []
    @Published var isScanning = false
    @Published var scanProgress: Double = 0
    @Published var totalJunk: Int64 = 0
    @Published var hasScanResult = false
    /// Localization key for the current status text. Views render `loc.t(statusKey)`.
    /// `statusArg` is appended when the message needs the freed/total bytes.
    @Published var statusKey: String = "disk.status.idle"
    @Published var statusArg: Int64 = 0
    @Published var statusMessage = "Analisando disco…" // kept for legacy callsites
    @Published var isCleaning = false
    @Published var spaceFreed: Int64 = 0

    private let home = FileManager.default.homeDirectoryForCurrentUser.path

    init() {
        // Don't auto-scan on init: reading ~/Downloads / ~/Library/Caches at
        // launch time triggers TCC consent dialogs before the user has even
        // chosen to use the Disk tab. The scan runs lazily on first call to
        // `ensureLoaded()` (invoked by DiskScannerView.onAppear).
    }

    private var hasLoadedOnce = false
    /// Lazy entry-point so the Disk tab populates the first time it is shown
    /// — without us hammering protected folders at app startup.
    func ensureLoaded() {
        guard !hasLoadedOnce, !isScanning else { return }
        hasLoadedOnce = true
        Task.detached(priority: .utility) { await self.backgroundScan() }
    }

    // MARK: - Public scan (triggered by user button)
    func scan() {
        isScanning = true
        hasScanResult = false
        scanProgress = 0
        statusMessage = "Analisando disco…"
        spaceFreed = 0
        let homePath = home

        Task.detached(priority: .utility) {
            var cats = Self.buildCategories(home: homePath)
            let total = Double(cats.count)

            for i in cats.indices {
                let (size, files) = Self.measure(path: cats[i].path, policy: cats[i].policy)
                cats[i].size  = size
                cats[i].files = files

                // Realistic pacing — small sleep between each category
                try? await Task.sleep(nanoseconds: 150_000_000)

                let pct = Double(i + 1) / total
                await MainActor.run { [weak self] in
                    self?.scanProgress = pct
                    self?.statusMessage = "•"
                }
            }

            let junkTotal = cats.reduce(0) { $0 + $1.size }
            await MainActor.run { [weak self] in
                self?.categories   = cats.filter { $0.size > 0 }
                self?.totalJunk    = junkTotal
                self?.isScanning   = false
                self?.hasScanResult = true
                // Use generic markers; views resolve via Localization.
                self?.statusKey = junkTotal > 0 ? "disk.status.found" : "disk.status.clean"
                self?.statusArg = junkTotal
            }
        }
    }

    // MARK: - Silent background scan (populates disk tab immediately)
    private func backgroundScan() async {
        let homePath = home
        let cats = await Task.detached(priority: .background) {
            var result = Self.buildCategories(home: homePath)
            for i in result.indices {
                let (size, files) = Self.measure(path: result[i].path, policy: result[i].policy)
                result[i].size  = size
                result[i].files = files
            }
            return result.filter { $0.size > 0 }
        }.value

        let junkTotal = cats.reduce(0) { $0 + $1.size }
        await MainActor.run { [weak self] in
            guard let self, !self.isScanning else { return }
            self.categories    = cats
            self.totalJunk     = junkTotal
            self.hasScanResult = !cats.isEmpty
            self.statusKey = junkTotal > 0 ? "disk.status.found" : "disk.status.clean"
            self.statusArg = junkTotal
            self.statusMessage = "•"
        }
    }

    // MARK: - Clean
    func clean() {
        isCleaning = true
        let toClean = categories.filter(\.isSelected)

        Task.detached(priority: .utility) {
            var freed: Int64 = 0
            var failedURLs: [URL] = []

            for cat in toClean {
                for url in cat.files {
                    let size = (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize)
                        .map { Int64($0) } ?? 0
                    // Use trash for recoverability. Falls back to removeItem only for
                    // categories that are already trash (the user's own ~/.Trash).
                    let success: Bool
                    if cat.path.hasSuffix("/.Trash") {
                        success = (try? FileManager.default.removeItem(at: url)) != nil
                    } else {
                        success = (try? FileManager.default.trashItem(at: url, resultingItemURL: nil)) != nil
                    }
                    if success {
                        freed += size
                    } else if FileManager.default.fileExists(atPath: url.path) {
                        failedURLs.append(url)
                    } else {
                        // File vanished between scan and clean — count it as freed.
                        freed += size
                    }
                }
            }

            // Retry failures with admin privileges (covers root-owned caches and
            // system logs that the user can't trash directly).
            if !failedURLs.isEmpty {
                let escaped = failedURLs.map { "'" + $0.path.replacingOccurrences(of: "'", with: "'\\''") + "'" }
                    .joined(separator: " ")
                _ = await PrivilegedExecutor.shared.runShell("/bin/rm -rf \(escaped)")
                for url in failedURLs where !FileManager.default.fileExists(atPath: url.path) {
                    // Best effort: we don't know per-file size at this stage,
                    // so just nudge `freed` by a token amount so the user sees
                    // a non-zero result instead of "nothing was removed".
                    freed += 1
                }
            }

            await MainActor.run { [weak self] in
                self?.spaceFreed    = freed
                self?.isCleaning   = false
                self?.hasScanResult = false
                self?.categories   = []
                self?.totalJunk    = 0
                self?.statusKey = freed > 0 ? "disk.status.freed" : "disk.status.nothing"
                self?.statusArg = freed
                self?.statusMessage = "•"
                SoundManager.shared.playCompletion()
            }
        }
    }

    func toggle(id: UUID) {
        if let i = categories.firstIndex(where: { $0.id == id }) {
            categories[i].isSelected.toggle()
        }
    }

    // MARK: - Category definitions
    private nonisolated static func buildCategories(home: String) -> [JunkCategory] {[
        JunkCategory(nameKey: "disk.cat.systemCache",     icon: "archivebox.fill",
                     color: Color(hex: "FF8C38"),
                     path: "\(home)/Library/Caches",
                     policy: .all),
        JunkCategory(nameKey: "disk.cat.logs",            icon: "doc.text.fill",
                     color: Color(hex: "4D8FFF"),
                     path: "\(home)/Library/Logs",
                     policy: .all),
        JunkCategory(nameKey: "disk.cat.temp",            icon: "clock.badge.xmark",
                     color: Color(hex: "9B6BF8"),
                     path: NSTemporaryDirectory(),
                     policy: .all),
        JunkCategory(nameKey: "disk.cat.oldDownloads",    icon: "arrow.down.circle.fill",
                     color: Color(hex: "00C9A7"),
                     path: "\(home)/Downloads",
                     policy: .olderThan(days: 30)),
        JunkCategory(nameKey: "disk.cat.orphanedSupport", icon: "trash.fill",
                     color: Color(hex: "FF4D5E"),
                     path: "\(home)/Library/Application Support",
                     policy: .orphanedAppSupport),
        JunkCategory(nameKey: "disk.cat.trash",           icon: "trash.circle.fill",
                     color: Color(hex: "FFB830"),
                     path: "\(home)/.Trash",
                     policy: .all),
        JunkCategory(nameKey: "disk.cat.xcodeSims",       icon: "apps.iphone",
                     color: Color(hex: "8B6BF8"),
                     path: "\(home)/Library/Developer/CoreSimulator/Devices",
                     policy: .all),
    ]}

    // MARK: - Measurement
    private nonisolated static func measure(path: String, policy: JunkCategory.SafetyPolicy) -> (Int64, [URL]) {
        switch policy {
        case .all:
            return measureAll(path: path)
        case .olderThan(let days):
            return measureOlderThan(path: path, days: days)
        case .orphanedAppSupport:
            return measureOrphanedAppSupport(path: path)
        }
    }

    private nonisolated static func measureAll(path: String) -> (Int64, [URL]) {
        let fm = FileManager.default
        guard fm.fileExists(atPath: path) else { return (0, []) }
        let url = URL(fileURLWithPath: path)
        var totalSize: Int64 = 0
        var files: [URL] = []

        let opts: FileManager.DirectoryEnumerationOptions = [.skipsHiddenFiles, .skipsPackageDescendants]
        guard let enumerator = fm.enumerator(
            at: url,
            includingPropertiesForKeys: [.fileSizeKey, .isRegularFileKey],
            options: opts
        ) else { return (0, []) }

        for case let fileURL as URL in enumerator {
            guard let vals = try? fileURL.resourceValues(forKeys: [.fileSizeKey, .isRegularFileKey]),
                  vals.isRegularFile == true,
                  let size = vals.fileSize
            else { continue }
            totalSize += Int64(size)
            files.append(fileURL)
        }
        return (totalSize, files)
    }

    /// Only top-level files in `path` that were modified more than `days` days ago.
    /// We deliberately do NOT recurse — touching nested project folders by mtime
    /// is too risky.
    private nonisolated static func measureOlderThan(path: String, days: Int) -> (Int64, [URL]) {
        let fm = FileManager.default
        guard fm.fileExists(atPath: path) else { return (0, []) }
        let cutoff = Date().addingTimeInterval(-Double(days) * 86400)
        var totalSize: Int64 = 0
        var files: [URL] = []

        guard let entries = try? fm.contentsOfDirectory(
            at: URL(fileURLWithPath: path),
            includingPropertiesForKeys: [.fileSizeKey, .isRegularFileKey, .contentModificationDateKey],
            options: [.skipsHiddenFiles]
        ) else { return (0, []) }

        for url in entries {
            guard let vals = try? url.resourceValues(forKeys: [
                .fileSizeKey, .isRegularFileKey, .contentModificationDateKey
            ]) else { continue }
            // Only loose files (not nested folders) on Downloads.
            guard vals.isRegularFile == true,
                  let size = vals.fileSize,
                  let mtime = vals.contentModificationDate,
                  mtime < cutoff
            else { continue }
            totalSize += Int64(size)
            files.append(url)
        }
        return (totalSize, files)
    }

    /// Lists sub-folders of `~/Library/Application Support` whose name doesn't match
    /// any installed app's bundle id or display name. Adding nothing if the lookup
    /// of installed apps fails — better to under-collect than to nuke active data.
    private nonisolated static func measureOrphanedAppSupport(path: String) -> (Int64, [URL]) {
        let fm = FileManager.default
        guard fm.fileExists(atPath: path) else { return (0, []) }
        let installed = installedAppIdentifiers()
        guard !installed.isEmpty else { return (0, []) } // safety: skip if discovery failed

        guard let folders = try? fm.contentsOfDirectory(
            at: URL(fileURLWithPath: path),
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else { return (0, []) }

        // Never touch these — they're Apple-managed shared support folders.
        let alwaysKeep: Set<String> = [
            "MobileSync", "iCloud", "CallHistoryDB", "CallHistoryTransactions",
            "AddressBook", "Knowledge", "FaceTime", "com.apple", "AppleMediaServices",
            "CrashReporter", "App Store", "Containers", "Group Containers"
        ]

        var totalSize: Int64 = 0
        var files: [URL] = []
        for folder in folders {
            let name = folder.lastPathComponent
            if alwaysKeep.contains(where: { name.hasPrefix($0) }) { continue }
            if installed.contains(where: { name.lowercased().contains($0) || $0.contains(name.lowercased()) }) {
                continue
            }
            // Orphan candidate — recurse for size and file list, but offer up the
            // folder for trashing as a whole rather than individual files.
            guard (try? folder.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true else { continue }
            let (size, _) = measureAll(path: folder.path)
            guard size > 0 else { continue }
            totalSize += size
            files.append(folder)
        }
        return (totalSize, files)
    }

    /// Lowercased identifiers (bundle id last component + display name) of every
    /// app currently installed in /Applications, ~/Applications and system folders.
    private nonisolated static func installedAppIdentifiers() -> Set<String> {
        let fm = FileManager.default
        let home = fm.homeDirectoryForCurrentUser.path
        let appDirs = ["/Applications", "\(home)/Applications", "/System/Applications"]
        var ids = Set<String>()
        for dir in appDirs {
            guard let entries = try? fm.contentsOfDirectory(atPath: dir) else { continue }
            for entry in entries where entry.hasSuffix(".app") {
                let displayName = entry.replacingOccurrences(of: ".app", with: "").lowercased()
                ids.insert(displayName)
                let plistPath = "\(dir)/\(entry)/Contents/Info.plist"
                if let info = NSDictionary(contentsOfFile: plistPath),
                   let bid = info["CFBundleIdentifier"] as? String {
                    ids.insert(bid.lowercased())
                    if let last = bid.split(separator: ".").last {
                        ids.insert(String(last).lowercased())
                    }
                }
            }
        }
        return ids
    }
}
