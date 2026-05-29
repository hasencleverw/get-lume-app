import Foundation
import SwiftUI
import AppKit
import Combine

@MainActor
final class PermissionsManager: ObservableObject {
    /// The only permission we surface to the user. Full Disk Access (FDA)
    /// covers every TCC-protected folder (Desktop, Documents, Downloads,
    /// Pictures, Music, Movies, Safari, Mail, Messages, etc.) in one shot,
    /// so per-folder prompts and checks become noise the user doesn't need.
    @Published var fullDiskAccess = false

    /// Per-folder states — kept around for diagnostics but not surfaced as
    /// individual UI rows anymore (they always follow FDA in practice).
    @Published var documentsAccess = false
    @Published var downloadsAccess = false
    @Published var desktopAccess = false

    var anyCritical: Bool { !fullDiskAccess }

    private var observers: [NSObjectProtocol] = []

    init() {
        refresh()
        // Auto-refresh whenever the user comes back to the app — typical flow
        // is: click "Grant Access" → System Settings opens → user toggles
        // Lume in Full Disk Access → switches back to Lume. We need to detect
        // the new state immediately, not on the next refresh button click.
        let center = NotificationCenter.default
        let active = center.addObserver(forName: NSApplication.didBecomeActiveNotification,
                                        object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        }
        observers.append(active)
    }

    deinit {
        observers.forEach { NotificationCenter.default.removeObserver($0) }
    }

    /// User-controlled override. When the OS-level detection fails because of
    /// the cdhash-mismatch problem common with ad-hoc-signed apps (toggle
    /// appears ON in Settings but TCC doesn't actually apply the permission),
    /// the user can flip this on and we trust their word — silencing all FDA
    /// banners and refresh popups.
    @Published var manualOverride: Bool = UserDefaults.standard.bool(forKey: "lume.fda.manual") {
        didSet { UserDefaults.standard.set(manualOverride, forKey: "lume.fda.manual") }
    }

    func setManualOverride(_ on: Bool) {
        manualOverride = on
        refresh()
    }

    func refresh() {
        let detected = Self.checkFullDiskAccess()
        fullDiskAccess  = detected || manualOverride
        documentsAccess = fullDiskAccess
        downloadsAccess = fullDiskAccess
        desktopAccess   = fullDiskAccess
    }

    /// Full Disk Access detection. We use POSIX `open(2)` directly instead of
    /// `FileHandle` because FileHandle can throw on macOS 14+ for TCC-blocked
    /// paths even when the underlying syscall would have succeeded for an FDA
    /// app — leading to false negatives.
    ///
    /// We try several FDA-gated locations and return true if any one opens.
    private static func checkFullDiskAccess() -> Bool {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        // Broad list of FDA-gated locations — we accept success on any single
        // one. Different macOS versions and user profiles expose different
        // subsets, so the more we try the higher the chance we hit one.
        let probes = [
            // System TCC database (always exists on SIP-enabled Macs)
            "/Library/Application Support/com.apple.TCC/TCC.db",
            "\(home)/Library/Application Support/com.apple.TCC/TCC.db",
            // Safari — present even on a fresh Mac
            "\(home)/Library/Safari/Bookmarks.plist",
            "\(home)/Library/Safari/History.db",
            "\(home)/Library/Safari/CloudTabs.db",
            // Mail / Messages — present if the user uses them
            "\(home)/Library/Mail",
            "\(home)/Library/Messages/chat.db",
            // HomeKit, Suggestions, Cookies — all FDA-gated
            "\(home)/Library/HomeKit",
            "\(home)/Library/Suggestions",
            "\(home)/Library/Cookies/Cookies.binarycookies",
            // Calendar, Reminders, AddressBook databases
            "\(home)/Library/Calendars",
            "\(home)/Library/Reminders",
            "\(home)/Library/Application Support/AddressBook",
        ]
        for path in probes {
            let fd = open(path, O_RDONLY)
            if fd >= 0 { close(fd); return true }
            // Don't fall back to `contentsOfDirectory` — that itself triggers
            // TCC consent dialogs for per-folder rights we don't want to ask
            // about. open() is enough.
        }
        return false
    }

    func openFullDiskAccessSettings() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles")!
        NSWorkspace.shared.open(url)

        // After the user toggles the permission, macOS only applies it to the
        // *next* launch of Lume. Surface an alert on app reactivation telling
        // the user to restart — exactly once per click on "Conceder Acesso".
        promptedToRestart = false
        Task { @MainActor in
            for await _ in NotificationCenter.default
                .notifications(named: NSApplication.didBecomeActiveNotification)
                .prefix(1) {
                self.askToRestartIfNeeded()
            }
        }
    }

    private var promptedToRestart = false

    private func askToRestartIfNeeded() {
        guard !promptedToRestart else { return }
        promptedToRestart = true
        let alert = NSAlert()
        alert.messageText = "Reinicie o Lume para aplicar a permissão"
        alert.informativeText = ""
        alert.icon = NSApp.applicationIconImage
        alert.addButton(withTitle: "Reiniciar agora")
        alert.addButton(withTitle: "Depois")
        if alert.runModal() == .alertFirstButtonReturn { relaunchApp() }
    }

    /// Relaunches Lume cleanly. macOS TCC only applies newly-granted Full Disk
    /// Access to the *next* launch of a process — running apps don't pick it
    /// up. After the user grants FDA we surface a "Reiniciar agora" button
    /// that calls this.
    func relaunchApp() {
        let path = Bundle.main.bundlePath
        let proc = Process()
        proc.launchPath = "/usr/bin/open"
        // -n forces a new instance, --args nothing extra.
        proc.arguments = ["-n", path]
        try? proc.run()
        // Give launchd a moment to spawn the new process before we exit.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            NSApp.terminate(nil)
        }
    }

    func openPrivacySettings() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy")!
        NSWorkspace.shared.open(url)
    }
}
