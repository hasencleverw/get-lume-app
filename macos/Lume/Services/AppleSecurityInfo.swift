import Foundation
import SwiftUI

struct AppleSecurityStatus {
    let xProtectVersion: String?
    let xProtectLastUpdate: Date?
    let xProtectSignatureCount: Int
    let xProtectYaraRuleCount: Int
    let extensionBlocklistCount: Int
    let mrtVersion: String?
    let remediatorVersion: String?
    let isAvailable: Bool

    var totalSignatures: Int { xProtectSignatureCount + xProtectYaraRuleCount + extensionBlocklistCount }

    var lastUpdateText: String {
        guard let d = xProtectLastUpdate else { return "Desconhecido" }
        let days = Calendar.current.dateComponents([.day], from: d, to: Date()).day ?? 0
        if days == 0 { return "Hoje" }
        if days == 1 { return "Ontem" }
        if days < 30 { return "\(days) dias atrás" }
        let f = DateFormatter()
        f.dateFormat = "d MMM yyyy"
        f.locale = Locale(identifier: "pt_BR")
        return f.string(from: d)
    }

    static let unavailable = AppleSecurityStatus(
        xProtectVersion: nil, xProtectLastUpdate: nil,
        xProtectSignatureCount: 0, xProtectYaraRuleCount: 0,
        extensionBlocklistCount: 0, mrtVersion: nil, remediatorVersion: nil,
        isAvailable: false
    )
}

@MainActor
final class AppleSecurityInfo: ObservableObject {
    @Published var status: AppleSecurityStatus = .unavailable
    @Published var isLoading = false

    private let xProtectBundlePath = "/Library/Apple/System/Library/CoreServices/XProtect.bundle"
    private let mrtAppPath         = "/Library/Apple/System/Library/CoreServices/MRT.app"
    private let xRemediatorPath    = "/Library/Apple/System/Library/CoreServices/XProtect.app"

    func refresh() {
        guard !isLoading else { return }
        isLoading = true
        Task.detached(priority: .utility) {
            let result = await Self.read(
                bundlePath: "/Library/Apple/System/Library/CoreServices/XProtect.bundle",
                mrtPath:    "/Library/Apple/System/Library/CoreServices/MRT.app",
                remediator: "/Library/Apple/System/Library/CoreServices/XProtect.app"
            )
            await MainActor.run { [weak self] in
                self?.status = result
                self?.isLoading = false
            }
        }
    }

    private nonisolated static func read(bundlePath: String, mrtPath: String, remediator: String) -> AppleSecurityStatus {
        let fm = FileManager.default
        guard fm.fileExists(atPath: bundlePath) else { return .unavailable }

        // Version from XProtect.bundle/Contents/Info.plist
        let infoPath = "\(bundlePath)/Contents/Info.plist"
        let version = (NSDictionary(contentsOfFile: infoPath))?["CFBundleShortVersionString"] as? String

        // Last update from yara file mtime (changes with each push from Apple)
        let yaraPath = "\(bundlePath)/Contents/Resources/XProtect.yara"
        let mtime = (try? fm.attributesOfItem(atPath: yaraPath)[.modificationDate]) as? Date

        // Signature count from XProtect.plist (top-level array of match dicts)
        let plistPath = "\(bundlePath)/Contents/Resources/XProtect.plist"
        var sigCount = 0
        if let arr = NSArray(contentsOfFile: plistPath) {
            sigCount = arr.count
        }

        // YARA rule count — parse text file for "^rule " occurrences
        var yaraCount = 0
        if let yaraText = try? String(contentsOfFile: yaraPath, encoding: .utf8) {
            yaraCount = yaraText
                .split(separator: "\n")
                .filter { $0.hasPrefix("rule ") || $0.hasPrefix("private rule ") }
                .count
        }

        // Extension/Plugin blocklist count from meta.plist
        let metaPath = "\(bundlePath)/Contents/Resources/XProtect.meta.plist"
        var extCount = 0
        if let meta = NSDictionary(contentsOfFile: metaPath) {
            if let extBlock = meta["ExtensionBlacklist"] as? [String: Any],
               let exts = extBlock["Extensions"] as? [Any] {
                extCount += exts.count
            }
            if let pluginBlock = meta["PlugInBlacklist"] as? [String: Any] {
                for (_, value) in pluginBlock {
                    if let dict = value as? [String: Any] { extCount += dict.count }
                }
            }
        }

        // MRT version
        let mrtVersion = (NSDictionary(contentsOfFile: "\(mrtPath)/Contents/Info.plist"))?["CFBundleShortVersionString"] as? String

        // XProtect Remediator version (macOS 13+)
        let remVersion = (NSDictionary(contentsOfFile: "\(remediator)/Contents/Info.plist"))?["CFBundleShortVersionString"] as? String

        return AppleSecurityStatus(
            xProtectVersion: version,
            xProtectLastUpdate: mtime,
            xProtectSignatureCount: sigCount,
            xProtectYaraRuleCount: yaraCount,
            extensionBlocklistCount: extCount,
            mrtVersion: mrtVersion,
            remediatorVersion: remVersion,
            isAvailable: true
        )
    }
}
