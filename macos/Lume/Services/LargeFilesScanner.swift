import Foundation
import SwiftUI

struct LargeFileItem: Identifiable {
    let id = UUID()
    let url: URL
    let size: Int64
    let kind: FileKind
    let disk: String
    var isSelected: Bool = false

    var name: String { url.lastPathComponent }
    var path: String { url.path }

    enum FileKind: String, CaseIterable {
        case folder, video, image, archive, document, app, other

        var localizationKey: String {
            switch self {
            case .folder:   return "spaceLens.kind.folder"
            case .video:    return "spaceLens.kind.video"
            case .image:    return "spaceLens.kind.image"
            case .archive:  return "spaceLens.kind.archive"
            case .document: return "spaceLens.kind.document"
            case .app:      return "spaceLens.kind.app"
            case .other:    return "spaceLens.kind.other"
            }
        }

        var icon: String {
            switch self {
            case .folder:   return "folder.fill"
            case .video:    return "film.fill"
            case .image:    return "photo.fill"
            case .archive:  return "archivebox.fill"
            case .document: return "doc.fill"
            case .app:      return "app.fill"
            case .other:    return "doc.questionmark.fill"
            }
        }
        var color: Color {
            switch self {
            case .folder:   return Color(hex: "F5C542")
            case .video:    return Color(hex: "FF4D5E")
            case .image:    return Color(hex: "4D8FFF")
            case .archive:  return Color(hex: "FFB830")
            case .document: return Color(hex: "9B6BF8")
            case .app:      return Color(hex: "34C87A")
            case .other:    return Color(hex: "8899BB")
            }
        }
    }
}

@MainActor
final class LargeFilesScanner: ObservableObject {
    @Published var items: [LargeFileItem] = []
    @Published var isScanning = false
    @Published var progress: Double = 0
    @Published var statusMessage = "Pronto para analisar"
    @Published var disks: [DiskInfo] = []
    @Published var selectedDisk: String? = nil
    @Published var minSizeMB: Int = 50
    @Published var selectedKind: LargeFileItem.FileKind? = nil

    struct DiskInfo: Identifiable {
        let id: String
        let name: String
        let path: String
        let total: Int64
        let free: Int64
        var used: Int64 { total - free }
    }

    var filteredItems: [LargeFileItem] {
        items.filter { item in
            let diskOK = selectedDisk == nil || item.disk == selectedDisk
            let kindOK = selectedKind == nil || item.kind == selectedKind
            return diskOK && kindOK
        }
    }

    init() {
        loadDisks()
    }

    func loadDisks() {
        let fm = FileManager.default
        guard let vols = fm.mountedVolumeURLs(
            includingResourceValuesForKeys: [.volumeNameKey, .volumeTotalCapacityKey, .volumeAvailableCapacityKey],
            options: [.skipHiddenVolumes]
        ) else { return }

        disks = vols.compactMap { url -> DiskInfo? in
            guard let vals = try? url.resourceValues(forKeys: [
                .volumeNameKey, .volumeTotalCapacityKey, .volumeAvailableCapacityKey
            ]),
            let total = vals.volumeTotalCapacity, total > 0
            else { return nil }
            let name = vals.volumeName ?? url.lastPathComponent
            let free = vals.volumeAvailableCapacity ?? 0
            return DiskInfo(id: url.path, name: name, path: url.path,
                            total: Int64(total), free: Int64(free))
        }
    }

    func scan() {
        isScanning = true
        items = []
        progress = 0
        statusMessage = "Procurando arquivos grandes…"
        loadDisks()

        let minBytes = Int64(minSizeMB) * 1_048_576
        let home = FileManager.default.homeDirectoryForCurrentUser

        let searchRoots: [(url: URL, disk: String)]
        if let disk = selectedDisk, let d = disks.first(where: { $0.name == disk }) {
            searchRoots = Self.searchRootsForVolume(URL(fileURLWithPath: d.path), home: home)
                .map { ($0, d.name) }
        } else {
            searchRoots = disks.flatMap { d in
                Self.searchRootsForVolume(URL(fileURLWithPath: d.path), home: home)
                    .map { ($0, d.name) }
            }
        }

        Task.detached(priority: .utility) {
            var found: [LargeFileItem] = []
            let totalRoots = max(searchRoots.count, 1)

            for (rootIdx, entry) in searchRoots.enumerated() {
                let root = entry.url
                let diskName = entry.disk
                guard let enumerator = FileManager.default.enumerator(
                    at: root,
                    includingPropertiesForKeys: [.fileSizeKey, .isRegularFileKey],
                    options: [.skipsHiddenFiles, .skipsPackageDescendants]
                ) else { continue }

                var batch = 0
                for case let fileURL as URL in enumerator {
                    guard let vals = try? fileURL.resourceValues(forKeys: [.fileSizeKey, .isRegularFileKey]),
                          vals.isRegularFile == true,
                          let size = vals.fileSize, size > 0
                    else { continue }

                    let bytes = Int64(size)
                    if bytes >= minBytes {
                        let kind = Self.classifyFile(fileURL)
                        found.append(LargeFileItem(url: fileURL, size: bytes, kind: kind, disk: diskName))
                    }

                    batch += 1
                    if batch % 150 == 0 {
                        let rootPct = Double(rootIdx) / Double(totalRoots)
                        let intraRootPct = min(Double(batch) / 8000.0, 1.0) / Double(totalRoots)
                        let pct = min(rootPct + intraRootPct, 0.97)
                        let count = found.count
                        await MainActor.run { [weak self] in
                            self?.progress = pct
                            self?.statusMessage = "Analisando \(root.lastPathComponent)… (\(count) encontrados)"
                        }
                    }

                    if batch >= 60000 || found.count >= 3000 { break }
                }

                let doneProgress = Double(rootIdx + 1) / Double(totalRoots) * 0.97
                await MainActor.run { [weak self] in self?.progress = doneProgress }
            }

            // Compute top-level folder sizes from already-scanned files
            // Map folder path -> (size, disk)
            var folderSizes: [String: (size: Int64, disk: String)] = [:]
            for item in found {
                for entry in searchRoots {
                    let rootPath = entry.url.path
                    let itemPath = item.path
                    guard itemPath.hasPrefix(rootPath + "/") else { continue }
                    let relative = String(itemPath.dropFirst(rootPath.count + 1))
                    guard let firstSlash = relative.firstIndex(of: "/") else { continue }
                    let folderName = String(relative[relative.startIndex..<firstSlash])
                    guard !folderName.isEmpty, !folderName.hasPrefix(".") else { continue }
                    let folderPath = rootPath + "/" + folderName
                    let prev = folderSizes[folderPath]?.size ?? 0
                    folderSizes[folderPath] = (prev + item.size, entry.disk)
                }
            }
            // Add folders exceeding the threshold (excluding ones already found as .app files)
            let existingPaths = Set(found.map(\.path))
            for (folderPath, info) in folderSizes where info.size >= minBytes {
                guard !existingPaths.contains(folderPath) else { continue }
                var isDir: ObjCBool = false
                guard FileManager.default.fileExists(atPath: folderPath, isDirectory: &isDir),
                      isDir.boolValue else { continue }
                found.append(LargeFileItem(url: URL(fileURLWithPath: folderPath),
                                           size: info.size, kind: .folder, disk: info.disk))
            }

            let sorted = found.sorted { $0.size > $1.size }
            await MainActor.run { [weak self] in
                self?.items = sorted
                self?.isScanning = false
                self?.progress = 1.0
                self?.statusMessage = sorted.isEmpty
                    ? "Nenhum arquivo ou pasta grande encontrado"
                    : "\(sorted.count) itens grandes encontrados"
            }
        }
    }

    func deleteSelected() {
        let toDelete = items.filter(\.isSelected)
        for item in toDelete {
            try? FileManager.default.trashItem(at: item.url, resultingItemURL: nil)
        }
        items.removeAll { $0.isSelected }
        statusMessage = "\(toDelete.count) arquivos movidos para a Lixeira"
        SoundManager.shared.playCompletion()
    }

    func toggleSelect(_ id: UUID) {
        if let i = items.firstIndex(where: { $0.id == id }) {
            items[i].isSelected.toggle()
        }
    }

    // Boot volume: scope to user subdirs to avoid indefinite scan
    private nonisolated static func searchRootsForVolume(_ volumeURL: URL, home: URL) -> [URL] {
        let volPath = volumeURL.path
        let homePath = home.path
        let isBootVol = volPath == "/" || homePath.hasPrefix(volPath == "/" ? "/" : volPath + "/")
        if isBootVol {
            let subdirs = ["Documents", "Downloads", "Desktop", "Movies", "Music", "Pictures"]
            let fm = FileManager.default
            return subdirs.compactMap { sub -> URL? in
                let u = home.appendingPathComponent(sub)
                var isDir: ObjCBool = false
                return fm.fileExists(atPath: u.path, isDirectory: &isDir) && isDir.boolValue ? u : nil
            }
        } else {
            return [volumeURL]
        }
    }

    private nonisolated static func classifyFile(_ url: URL) -> LargeFileItem.FileKind {
        let ext = url.pathExtension.lowercased()
        switch ext {
        case "mp4","mov","avi","mkv","m4v","wmv","flv","webm": return .video
        case "jpg","jpeg","png","gif","heic","tiff","raw","bmp","psd": return .image
        case "zip","tar","gz","rar","7z","dmg","pkg","iso","xip": return .archive
        case "pdf","doc","docx","xls","xlsx","ppt","pptx","pages","numbers","key": return .document
        case "app": return .app
        default: return .other
        }
    }
}
