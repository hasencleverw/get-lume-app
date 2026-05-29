import Foundation
import SwiftUI
import AppKit

struct InstalledApp: Identifiable {
    let id = UUID()
    let name: String
    let url: URL
    let bundleID: String?
    let version: String?
    let size: Int64
    let lastUsed: Date?
    var isSelected: Bool = false

    var icon: NSImage {
        NSWorkspace.shared.icon(forFile: url.path)
    }
}

@MainActor
final class AppManager: ObservableObject {
    @Published var apps: [InstalledApp] = []
    @Published var isLoading = false
    @Published var sortBy: SortField = .size
    @Published var searchText = ""
    @Published var isUninstalling = false
    @Published var statusMessage = ""

    enum SortField: String, CaseIterable {
        case name    = "Nome"
        case size    = "Tamanho"
        case lastUsed = "Último uso"
    }

    var filteredApps: [InstalledApp] {
        var result = apps
        if !searchText.isEmpty {
            result = result.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
        }
        switch sortBy {
        case .name:     result.sort { $0.name < $1.name }
        case .size:     result.sort { $0.size > $1.size }
        case .lastUsed: result.sort { ($0.lastUsed ?? .distantPast) > ($1.lastUsed ?? .distantPast) }
        }
        return result
    }

    var selectedApps: [InstalledApp] { apps.filter(\.isSelected) }
    var selectedSize: Int64 { selectedApps.reduce(0) { $0 + $1.size } }

    func load() {
        isLoading = true
        Task.detached(priority: .utility) {
            let found = Self.scanApps()
            await MainActor.run { [weak self] in
                self?.apps = found
                self?.isLoading = false
                self?.statusMessage = "\(found.count) apps instalados"
            }
        }
    }

    func toggleSelect(_ id: UUID) {
        if let i = apps.firstIndex(where: { $0.id == id }) {
            apps[i].isSelected.toggle()
        }
    }

    func uninstallSelected() {
        let toUninstall = selectedApps
        guard !toUninstall.isEmpty else { return }
        isUninstalling = true
        // Pre-authorize on the main thread (auth dialog must run there) — first
        // run prompts, subsequent runs reuse the cached AuthorizationRef.
        _ = PrivilegedExecutor.shared.authorize()

        Task.detached(priority: .utility) {
            // First pass: attempt user-level removal. Anything that lands in
            // `needsAdmin` is owned by root (App Store apps like Keynote/Pages,
            // anything in /Applications dropped by an installer running as root)
            // and requires admin privileges to delete.
            var removed: [InstalledApp] = []
            var needsAdmin: [InstalledApp] = []

            for app in toUninstall {
                if Self.attemptUserTrash(app.url) {
                    removed.append(app)
                    Self.trashSupportFiles(for: app)
                } else {
                    needsAdmin.append(app)
                }
            }

            // Second pass: batch the privileged removals into a single
            // privileged shell call using the cached AuthorizationRef so the
            // user only sees one password prompt per app session.
            if !needsAdmin.isEmpty {
                let escapedPaths = needsAdmin.map { app -> String in
                    "'" + app.url.path.replacingOccurrences(of: "'", with: "'\\''") + "'"
                }.joined(separator: " ")
                _ = await PrivilegedExecutor.shared.runShell("/bin/rm -rf \(escapedPaths)")
                for app in needsAdmin where !FileManager.default.fileExists(atPath: app.url.path) {
                    removed.append(app)
                    Self.trashSupportFiles(for: app)
                }
            }

            let removedCount = removed.count
            let failedCount  = toUninstall.count - removedCount
            let removedIDs = Set(removed.map(\.id))

            await MainActor.run { [weak self] in
                self?.isUninstalling = false
                self?.apps.removeAll { removedIDs.contains($0.id) }
                if removedCount > 0 && failedCount == 0 {
                    self?.statusMessage = "\(removedCount) app(s) removido(s)"
                } else if removedCount > 0 && failedCount > 0 {
                    self?.statusMessage = "\(removedCount) removido(s), \(failedCount) falharam"
                } else {
                    self?.statusMessage = "Falha ao remover. Verifique permissões."
                }
            }
        }
    }

    /// Tries the safe path: move the app to the user's Trash. Returns false if
    /// the file still exists afterwards (typical for root-owned apps).
    private nonisolated static func attemptUserTrash(_ url: URL) -> Bool {
        do {
            try FileManager.default.trashItem(at: url, resultingItemURL: nil)
        } catch {
            return false
        }
        return !FileManager.default.fileExists(atPath: url.path)
    }

    func openApp(_ app: InstalledApp) {
        NSWorkspace.shared.open(app.url)
    }

    func revealInFinder(_ app: InstalledApp) {
        NSWorkspace.shared.activateFileViewerSelecting([app.url])
    }

    // MARK: - Private helpers
    private nonisolated static func scanApps() -> [InstalledApp] {
        let fm = FileManager.default
        let home = fm.homeDirectoryForCurrentUser.path
        let searchPaths = ["/Applications", "\(home)/Applications"]
        var result: [InstalledApp] = []

        for base in searchPaths {
            guard let contents = try? fm.contentsOfDirectory(atPath: base) else { continue }
            for item in contents {
                guard item.hasSuffix(".app") else { continue }
                let url = URL(fileURLWithPath: "\(base)/\(item)")
                let name = url.deletingPathExtension().lastPathComponent

                // Bundle info
                let infoPlist = url.appendingPathComponent("Contents/Info.plist")
                let dict = NSDictionary(contentsOf: infoPlist)
                let bundleID = dict?["CFBundleIdentifier"] as? String
                let version  = dict?["CFBundleShortVersionString"] as? String

                // Size (recursive)
                let size = Self.directorySize(url)

                // Last used via spotlight metadata
                let lastUsed = Self.lastUsedDate(url)

                result.append(InstalledApp(
                    name: name, url: url,
                    bundleID: bundleID, version: version,
                    size: size, lastUsed: lastUsed
                ))
            }
        }
        return result
    }

    private nonisolated static func directorySize(_ url: URL) -> Int64 {
        var total: Int64 = 0
        guard let enumerator = FileManager.default.enumerator(
            at: url,
            includingPropertiesForKeys: [.fileSizeKey],
            options: [.skipsHiddenFiles]
        ) else { return 0 }
        for case let fileURL as URL in enumerator {
            if let size = try? fileURL.resourceValues(forKeys: [.fileSizeKey]).fileSize {
                total += Int64(size)
            }
        }
        return total
    }

    private nonisolated static func lastUsedDate(_ url: URL) -> Date? {
        let attrs = try? FileManager.default.attributesOfItem(atPath: url.path)
        return attrs?[.modificationDate] as? Date
    }

    private nonisolated static func trashSupportFiles(for app: InstalledApp) {
        guard let bid = app.bundleID else { return }
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let supportPaths = [
            "\(home)/Library/Application Support/\(bid)",
            "\(home)/Library/Caches/\(bid)",
            "\(home)/Library/Preferences/\(bid).plist",
            "\(home)/Library/Logs/\(bid)",
            "\(home)/Library/Application Support/\(app.name)",
            "\(home)/Library/Caches/\(app.name)",
        ]
        for path in supportPaths {
            let url = URL(fileURLWithPath: path)
            if FileManager.default.fileExists(atPath: path) {
                try? FileManager.default.trashItem(at: url, resultingItemURL: nil)
            }
        }
    }
}
