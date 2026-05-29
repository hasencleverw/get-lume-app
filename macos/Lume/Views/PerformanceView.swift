import SwiftUI
import AppKit

struct PerformanceView: View {
    @ObservedObject var monitor: SystemMonitor
    @EnvironmentObject var loc: Localization
    @StateObject private var perfManager = PerformanceManager()
    @State private var showAllAgents = false

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 22) {
                PageHeader(
                    title: loc.t("page.performance.title"),
                    subtitle: loc.t("page.performance.subtitle"),
                    section: .performance
                )

                HStack(alignment: .top, spacing: 14) {
                    VStack(spacing: 14) {
                        spotlightCard
                        maintenanceCard
                    }
                    .frame(maxWidth: .infinity)

                    VStack(spacing: 14) {
                        loginItemsCard
                        backgroundItemsCard
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .padding(28)
        }
        .onAppear { perfManager.loadLoginItems(); perfManager.loadBackgroundItems() }
    }

    // MARK: - Spotlight Reindex
    private var spotlightCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(LinearGradient(colors: [Color(hex: "FFB830"), Color(hex: "D08A0A")],
                                             startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(width: 38, height: 38)
                        .shadow(color: Color(hex: "FFB830").opacity(0.45), radius: 8)
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundColor(.white)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(loc.t("perf.spotlight.title"))
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white)
                    Text(loc.t("perf.spotlight.desc"))
                        .font(.system(size: 11))
                        .foregroundColor(.textSecondary)
                }
            }

            Text(loc.t("perf.spotlight.help"))
                .font(.system(size: 12))
                .foregroundColor(.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            if let key = perfManager.spotlightMessageKey {
                HStack(spacing: 6) {
                    Image(systemName: perfManager.spotlightSuccess ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                        .foregroundColor(perfManager.spotlightSuccess ? .appSuccess : .appWarning)
                    Text(loc.t(key))
                        .font(.system(size: 12))
                        .foregroundColor(perfManager.spotlightSuccess ? .appSuccess : .appWarning)
                }
                .transition(.opacity)
            }

            Button(action: { perfManager.reindexSpotlight() }) {
                HStack(spacing: 7) {
                    if perfManager.isReindexing {
                        ProgressView().scaleEffect(0.7).tint(.black)
                    } else {
                        Image(systemName: "arrow.clockwise")
                    }
                    Text(perfManager.isReindexing ? loc.t("perf.spotlight.running") : loc.t("perf.spotlight.btn"))
                        .font(.system(size: 13, weight: .semibold))
                }
                .foregroundColor(.black)
                .padding(.horizontal, 18)
                .padding(.vertical, 9)
                .frame(maxWidth: .infinity)
                .background(LinearGradient(colors: [Color(hex: "FFB830"), Color(hex: "D08A0A")],
                                           startPoint: .leading, endPoint: .trailing))
                .clipShape(Capsule())
                .shadow(color: Color(hex: "FFB830").opacity(0.4), radius: 8)
            }
            .buttonStyle(.plain)
            .disabled(perfManager.isReindexing)
        }
        .padding(18)
        .glassCard()
    }

    // MARK: - Maintenance tasks
    private var maintenanceCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(loc.t("perf.tasksHeader"))
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(.white)

            ForEach(perfManager.maintenanceTasks) { task in
                MaintenanceTaskRow(task: task) {
                    perfManager.runTask(task)
                }
            }
        }
        .padding(18)
        .glassCard()
    }

    // MARK: - Login Items (managed via System Settings — no public API to toggle others)
    private var loginItemsCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text(loc.t("perf.loginItems"))
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white)
                Spacer()
                Text("\(perfManager.loginItems.count)")
                    .font(.system(size: 11))
                    .foregroundColor(.textSecondary)
                Button(action: { perfManager.loadLoginItems() }) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 11))
                        .foregroundColor(.textSecondary)
                }
                .buttonStyle(.plain)
            }

            Text(loc.current == "en"
                 ? "Apps that open automatically when you log in. macOS only allows toggling via System Settings."
                 : loc.current == "es"
                    ? "Apps que se abren al iniciar sesión. macOS solo permite alternarlos en Configuración del Sistema."
                    : "Apps que abrem automaticamente ao fazer login. O macOS só permite alternar via Ajustes do Sistema.")
                .font(.system(size: 11))
                .foregroundColor(.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            if perfManager.loginItems.isEmpty {
                Text(loc.t("perf.noItems"))
                    .font(.system(size: 12))
                    .foregroundColor(.textSecondary)
                    .padding(.vertical, 8)
            } else {
                VStack(spacing: 6) {
                    ForEach(perfManager.loginItems.prefix(6), id: \.self) { item in
                        HStack(spacing: 10) {
                            Image(nsImage: NSWorkspace.shared.icon(forFile: item))
                                .resizable()
                                .frame(width: 24, height: 24)
                            Text(URL(fileURLWithPath: item).deletingPathExtension().lastPathComponent)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.white)
                                .lineLimit(1)
                            Spacer()
                        }
                    }
                    if perfManager.loginItems.count > 6 {
                        Text("+ \(perfManager.loginItems.count - 6)")
                            .font(.system(size: 10))
                            .foregroundColor(.textSecondary)
                    }
                }
            }

            Button(action: { perfManager.openLoginItemsSettings() }) {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.up.right.square")
                    Text(loc.t("perf.openSettings"))
                        .font(.system(size: 12, weight: .semibold))
                }
                .foregroundColor(.black)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .frame(maxWidth: .infinity)
                .background(LinearGradient(colors: [Color(hex: "FFB830"), Color(hex: "D08A0A")],
                                           startPoint: .leading, endPoint: .trailing))
                .clipShape(Capsule())
            }
            .buttonStyle(.plain)
        }
        .padding(18)
        .glassCard()
    }

    // MARK: - Background Items (Launch Agents — manageable for user-level)
    private var backgroundItemsCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text(loc.t("perf.launchAgents"))
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white)
                Spacer()
                Text("\(perfManager.launchAgents.count)")
                    .font(.system(size: 11))
                    .foregroundColor(.textSecondary)
                Button(action: { perfManager.loadBackgroundItems() }) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 11))
                        .foregroundColor(.textSecondary)
                }
                .buttonStyle(.plain)
            }

            Text(loc.current == "en"
                 ? "Launch agents and daemons active on the system. User-level can be disabled directly here."
                 : loc.current == "es"
                    ? "Launch agents y daemons activos. Los de nivel de usuario pueden desactivarse aquí."
                    : "Launch agents e daemons ativos. Os de nível de usuário podem ser desativados aqui.")
                .font(.system(size: 11))
                .foregroundColor(.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            if perfManager.launchAgents.isEmpty {
                ProgressView()
                    .scaleEffect(0.8)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
            } else {
                let visible = showAllAgents
                    ? perfManager.launchAgents
                    : Array(perfManager.launchAgents.prefix(8))
                if showAllAgents {
                    // When the list is fully expanded we wrap it in a scroll
                    // view so the card doesn't grow to ~30 rows tall.
                    ScrollView(.vertical, showsIndicators: true) {
                        VStack(spacing: 6) {
                            ForEach(visible) { agent in
                                LaunchAgentRow(agent: agent, loc: loc) {
                                    perfManager.toggle(agent)
                                } onRemove: {
                                    perfManager.remove(agent)
                                }
                            }
                        }
                    }
                    .frame(maxHeight: 320)
                } else {
                    VStack(spacing: 6) {
                        ForEach(visible) { agent in
                            LaunchAgentRow(agent: agent, loc: loc) {
                                perfManager.toggle(agent)
                            } onRemove: {
                                perfManager.remove(agent)
                            }
                        }
                    }
                }
                if perfManager.launchAgents.count > 8 {
                    Button(action: { withAnimation { showAllAgents.toggle() } }) {
                        HStack(spacing: 4) {
                            Image(systemName: showAllAgents ? "chevron.up" : "chevron.down")
                                .font(.system(size: 9))
                            Text(showAllAgents
                                 ? (loc.current == "en" ? "Show less"
                                     : loc.current == "es" ? "Mostrar menos"
                                     : "Mostrar menos")
                                 : "+ \(perfManager.launchAgents.count - 8) "
                                     + (loc.current == "en" ? "more" :
                                        loc.current == "es" ? "más" : "mais"))
                                .font(.system(size: 11, weight: .semibold))
                        }
                        .foregroundColor(Color(hex: "9B6BF8"))
                        .padding(.vertical, 4)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(18)
        .glassCard()
    }
}

// MARK: - Launch agent row
struct LaunchAgentRow: View {
    let agent: PerformanceManager.LaunchAgentItem
    let loc: Localization
    let onToggle: () -> Void
    let onRemove: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(agent.enabled ? Color.appSuccess : Color.textSecondary)
                .frame(width: 6, height: 6)
            VStack(alignment: .leading, spacing: 1) {
                Text(agent.name)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.white)
                    .lineLimit(1)
                Text(agent.scopeLabel)
                    .font(.system(size: 9))
                    .foregroundColor(.textSecondary)
            }
            Spacer()
            if agent.isUserLevel {
                Button(action: onToggle) {
                    Text(agent.enabled ? loc.t("perf.disable") : loc.t("perf.enable"))
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundColor(agent.enabled ? Color(hex: "FFB830") : Color.appSuccess)
                        .padding(.horizontal, 8).padding(.vertical, 3)
                        .background((agent.enabled ? Color(hex: "FFB830") : Color.appSuccess).opacity(0.15))
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                Button(action: onRemove) {
                    Image(systemName: "trash")
                        .font(.system(size: 10))
                        .foregroundColor(Color(hex: "FF4D5E"))
                }
                .buttonStyle(.plain)
            } else {
                Text(loc.current == "en" ? "admin" : "admin")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundColor(Color(hex: "FFB830"))
                    .padding(.horizontal, 6).padding(.vertical, 2)
                    .background(Color(hex: "FFB830").opacity(0.15))
                    .clipShape(Capsule())
            }
        }
    }
}

// MARK: - Maintenance task row
struct MaintenanceTaskRow: View {
    let task: PerformanceManager.MaintenanceTask
    let onRun: () -> Void
    @EnvironmentObject var loc: Localization

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(task.color.opacity(0.15))
                    .frame(width: 32, height: 32)
                Image(systemName: task.icon)
                    .font(.system(size: 13))
                    .foregroundColor(task.color)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(loc.t(task.nameKey))
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.white)
                Text(loc.t(task.descKey))
                    .font(.system(size: 10))
                    .foregroundColor(.textSecondary)
            }
            Spacer()
            if task.isDone {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.appSuccess)
            } else if task.isRunning {
                ProgressView().scaleEffect(0.65).tint(task.color)
            } else {
                Button(action: onRun) {
                    Text(loc.t("common.execute"))
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(task.color)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(task.color.opacity(0.15))
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
    }
}

// MARK: - Performance Manager
@MainActor
final class PerformanceManager: ObservableObject {
    struct MaintenanceTask: Identifiable {
        let id = UUID()
        let nameKey: String
        let descKey: String
        let icon: String
        let color: Color
        let command: String
        var isRunning: Bool = false
        var isDone: Bool = false
    }

    /// Maintenance tasks declared with their localization keys; the view resolves
    /// names/descriptions through Localization so they reflect the chosen language.
    @Published var maintenanceTasks: [MaintenanceTask] = [
        MaintenanceTask(nameKey: "perf.task.dnsCache.name",   descKey: "perf.task.dnsCache.desc",
                        icon: "network", color: Color(hex: "4D8FFF"),
                        command: "dscacheutil -flushcache; killall -HUP mDNSResponder"),
        MaintenanceTask(nameKey: "perf.task.permissions.name",descKey: "perf.task.permissions.desc",
                        icon: "lock.rotation", color: Color(hex: "FFB830"),
                        command: "diskutil resetUserPermissions / `id -u`"),
        MaintenanceTask(nameKey: "perf.task.fontCache.name",  descKey: "perf.task.fontCache.desc",
                        icon: "textformat", color: Color(hex: "9B6BF8"),
                        command: "atsutil databases -remove"),
        MaintenanceTask(nameKey: "perf.task.trash.name",      descKey: "perf.task.trash.desc",
                        icon: "trash.fill", color: Color(hex: "FF4D5E"),
                        command: "rm -rf ~/.Trash/*"),
    ]

    struct LaunchAgentItem: Identifiable, Hashable {
        let id: String     // full path
        let name: String   // bundle id / file name without .plist
        let path: String
        let isUserLevel: Bool
        var enabled: Bool

        var scopeLabel: String {
            isUserLevel ? "~/Library/LaunchAgents" :
                (path.contains("Daemons") ? "/Library/LaunchDaemons" : "/Library/LaunchAgents")
        }
    }

    @Published var loginItems: [String] = []
    @Published var launchAgents: [LaunchAgentItem] = []
    /// Legacy backing store still referenced elsewhere — kept in sync with `launchAgents`.
    @Published var backgroundItems: [String] = []
    @Published var isReindexing = false
    /// Localization key for the last Spotlight result. The view resolves it via
    /// `loc.t(...)` so the message respects the current language.
    @Published var spotlightMessageKey: String? = nil
    @Published var spotlightSuccess = false

    func reindexSpotlight() {
        isReindexing = true
        spotlightMessageKey = nil
        // Use the shared cached authorization so we don't ask for the password
        // again when the user already approved it earlier this session.
        guard PrivilegedExecutor.shared.authorize() else {
            isReindexing = false
            spotlightSuccess = false
            spotlightMessageKey = "perf.spotlight.failure"
            return
        }

        Task.detached(priority: .utility) {
            let home = FileManager.default.homeDirectoryForCurrentUser.path
            let ok = await PrivilegedExecutor.shared.runShell("/usr/bin/mdutil -E '\(home)'")
            await MainActor.run { [weak self] in
                self?.isReindexing = false
                self?.spotlightSuccess = ok
                self?.spotlightMessageKey = ok ? "perf.spotlight.success" : "perf.spotlight.failure"
                if ok { SoundManager.shared.playCompletion() }
            }
        }
    }

    func runTask(_ task: MaintenanceTask) {
        guard let i = maintenanceTasks.firstIndex(where: { $0.id == task.id }) else { return }
        maintenanceTasks[i].isRunning = true

        let needsAdmin = task.command.contains("diskutil") || task.command.contains("atsutil")
        if needsAdmin {
            guard PrivilegedExecutor.shared.authorize() else {
                maintenanceTasks[i].isRunning = false
                return
            }
        }

        Task.detached(priority: .utility) {
            if needsAdmin {
                _ = await PrivilegedExecutor.shared.runShell(task.command)
            } else {
                // No-privilege tasks run via a normal shell.
                let proc = Process()
                proc.launchPath = "/bin/sh"
                proc.arguments = ["-c", task.command]
                try? proc.run()
                proc.waitUntilExit()
            }
            await MainActor.run { [weak self] in
                guard let self, let idx = self.maintenanceTasks.firstIndex(where: { $0.id == task.id })
                else { return }
                self.maintenanceTasks[idx].isRunning = false
                self.maintenanceTasks[idx].isDone = true
                SoundManager.shared.playCompletion()
            }
        }
    }

    func loadLoginItems() {
        Task.detached(priority: .utility) {
            let items = Self.getLoginItems()
            await MainActor.run { [weak self] in self?.loginItems = items }
        }
    }

    func loadBackgroundItems() {
        Task.detached(priority: .utility) {
            let agents = Self.scanLaunchAgents()
            await MainActor.run { [weak self] in
                self?.launchAgents = agents
                self?.backgroundItems = agents.map(\.name)
            }
        }
    }

    func openLoginItemsSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.LoginItems-Settings.extension") {
            NSWorkspace.shared.open(url)
        }
    }

    /// Toggle a user-level launch agent by renaming the .plist to .plist.disabled
    /// (or back). System-level agents are skipped — they require admin and we don't
    /// want to surprise the user.
    func toggle(_ agent: LaunchAgentItem) {
        guard agent.isUserLevel else { return }
        let fm = FileManager.default
        let src = URL(fileURLWithPath: agent.path)
        let dst: URL = agent.enabled
            ? src.appendingPathExtension("disabled")
            : URL(fileURLWithPath: agent.path.replacingOccurrences(of: ".disabled", with: ""))
        do {
            try fm.moveItem(at: src, to: dst)
            // Try to unload / load via launchctl so the change takes effect now.
            let action = agent.enabled ? "unload" : "load"
            let proc = Process()
            proc.launchPath = "/bin/launchctl"
            proc.arguments = [action, "-w", dst.path]
            try? proc.run()
            loadBackgroundItems()
        } catch {
            print("Toggle launch agent failed: \(error.localizedDescription)")
        }
    }

    func remove(_ agent: LaunchAgentItem) {
        guard agent.isUserLevel else { return }
        let url = URL(fileURLWithPath: agent.path)
        try? FileManager.default.trashItem(at: url, resultingItemURL: nil)
        loadBackgroundItems()
    }

    private nonisolated static func getLoginItems() -> [String] {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let launchAgentDir = "\(home)/Library/LaunchAgents"
        guard let files = try? FileManager.default.contentsOfDirectory(atPath: launchAgentDir)
        else { return [] }
        return files
            .filter { $0.hasSuffix(".plist") }
            .compactMap { f -> String? in
                let path = "\(launchAgentDir)/\(f)"
                if let dict = NSDictionary(contentsOfFile: path),
                   let prog = (dict["ProgramArguments"] as? [String])?.first ?? dict["Program"] as? String {
                    return prog
                }
                return nil
            }
            .prefix(10)
            .map { $0 }
    }

    private nonisolated static func scanLaunchAgents() -> [LaunchAgentItem] {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let userDir = "\(home)/Library/LaunchAgents"
        let systemDirs = ["/Library/LaunchAgents", "/Library/LaunchDaemons"]

        var results: [LaunchAgentItem] = []
        let fm = FileManager.default

        for dir in [userDir] + systemDirs {
            guard let files = try? fm.contentsOfDirectory(atPath: dir) else { continue }
            let isUser = (dir == userDir)
            for file in files {
                let isDisabled = file.hasSuffix(".plist.disabled")
                let isPlist    = file.hasSuffix(".plist") || isDisabled
                guard isPlist else { continue }
                let displayName = file
                    .replacingOccurrences(of: ".plist.disabled", with: "")
                    .replacingOccurrences(of: ".plist", with: "")
                let full = "\(dir)/\(file)"
                results.append(LaunchAgentItem(
                    id: full,
                    name: displayName,
                    path: full,
                    isUserLevel: isUser,
                    enabled: !isDisabled
                ))
            }
        }
        return results.sorted { a, b in
            if a.isUserLevel != b.isUserLevel { return a.isUserLevel }
            return a.name < b.name
        }
    }
}
