import SwiftUI
import AppKit

struct ContentView: View {
    @EnvironmentObject var monitor: SystemMonitor
    @EnvironmentObject var scanner: DiskScanner
    @EnvironmentObject var appManager: AppManager
    @EnvironmentObject var largeFiles: LargeFilesScanner
    @EnvironmentObject var malware: MalwareScanner
    @EnvironmentObject var loc: Localization
    @EnvironmentObject var donation: DonationManager
    @EnvironmentObject var permissions: PermissionsManager
    @EnvironmentObject var updater: UpdaterService

    @State private var selection: AppSection = .dashboard
    @State private var showSettings = false

    var body: some View {
        HStack(spacing: 0) {
            SidebarView(selection: $selection, monitor: monitor, showSettings: $showSettings)
                .frame(width: 188)

            ZStack {
                AppBackground()
                contentForSection
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .ignoresSafeArea()
        .sheet(isPresented: $showSettings) {
            // Re-inject env objects: macOS sheets run on a separate window
            // and don't propagate @EnvironmentObject reliably.
            SettingsView()
                .frame(width: 540, height: 580)
                .environmentObject(loc)
                .environmentObject(donation)
                .environmentObject(permissions)
                .environmentObject(updater)
        }
    }

    @ViewBuilder
    private var contentForSection: some View {
        switch selection {
        case .dashboard:   DashboardView(monitor: monitor, scanner: scanner)
        case .memory:      MemoryCleanerView(monitor: monitor)
        case .disk:        DiskScannerView(monitor: monitor, scanner: scanner)
        case .largeFiles:  LargeFilesView(scanner: largeFiles)
        case .protection:  MalwareView(scanner: malware)
        case .apps:        AppsManagerView(manager: appManager)
        case .performance: PerformanceView(monitor: monitor)
        }
    }
}

// MARK: - Sidebar
struct SidebarView: View {
    @Binding var selection: AppSection
    @ObservedObject var monitor: SystemMonitor
    @Binding var showSettings: Bool
    @EnvironmentObject var loc: Localization

    private var ramPct: Double {
        monitor.ramTotal > 0 ? Double(monitor.ramUsed) / Double(monitor.ramTotal) * 100 : 0
    }
    private var diskPct: Double {
        monitor.diskTotal > 0 ? Double(monitor.diskUsed) / Double(monitor.diskTotal) * 100 : 0
    }
    private var healthIssues: [String] {
        var issues: [String] = []
        if monitor.cpuUsage >= 80  { issues.append("CPU acima de 80%") }
        if ramPct >= 80            { issues.append("RAM acima de 80%") }
        if diskPct >= 90           { issues.append("Disco acima de 90%") }
        return issues
    }
    private var healthOK: Bool { healthIssues.isEmpty }

    var body: some View {
        VStack(spacing: 0) {
            // Logo — with extra top padding to stay below traffic lights
            lumeHeader
                .padding(.top, 38)
                .padding(.bottom, 18)

            // Nav items
            VStack(spacing: 2) {
                ForEach(AppSection.allCases) { section in
                    SidebarRow(section: section, isSelected: selection == section) {
                        withAnimation(.spring(response: 0.22, dampingFraction: 0.75)) {
                            selection = section
                        }
                    }
                }
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 10)

            Spacer()

            // Health footer
            healthFooter
                .padding(.horizontal, 14)
                .padding(.bottom, 12)

            // Settings gear
            Button(action: { showSettings = true }) {
                HStack(spacing: 8) {
                    Image(systemName: "gearshape.fill")
                        .font(.system(size: 13))
                        .foregroundColor(.textSecondary)
                    Text(loc.t("sidebar.settings"))
                        .font(.system(size: 12))
                        .foregroundColor(.textSecondary)
                    Spacer()
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
            }
            .buttonStyle(.plain)
        }
        .frame(width: 188)
        .background(Color.sidebarBg)
    }

    // MARK: - Logo
    private var lumeHeader: some View {
        HStack(spacing: 9) {
            lumeIcon
            VStack(alignment: .leading, spacing: 1) {
                Text("Lume")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white)
                Text("for Mac")
                    .font(.system(size: 10))
                    .foregroundColor(.textSecondary)
            }
            Spacer()
        }
        .padding(.horizontal, 14)
    }

    private var lumeIcon: some View {
        Group {
            if let img = loadLumeIcon() {
                Image(nsImage: img)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 32, height: 32)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            } else {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(LinearGradient(
                            colors: [Color(hex: "8B6BF8"), Color(hex: "4B2BB8")],
                            startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(width: 32, height: 32)
                    Image(systemName: "flame.fill")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                }
            }
        }
    }

    private func loadLumeIcon() -> NSImage? {
        // Priority: bundle Resources > beside .app (DMG/dev layout) > resource URL
        let candidates: [String] = [
            Bundle.main.url(forResource: "Icone", withExtension: "png")?.path ?? "",
            Bundle.main.bundleURL
                .deletingLastPathComponent()
                .appendingPathComponent("Icone.png").path,
            Bundle.main.resourceURL?
                .appendingPathComponent("Icone.png").path ?? "",
        ]
        for path in candidates where !path.isEmpty {
            if let img = NSImage(contentsOfFile: path) { return img }
        }
        return nil
    }

    // MARK: - Health footer
    private var healthFooter: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 5) {
                Circle()
                    .fill(healthOK ? Color.appSuccess : Color.appWarning)
                    .frame(width: 6, height: 6)
                    .shadow(color: (healthOK ? Color.appSuccess : Color.appWarning).opacity(0.8), radius: 3)
                Text("Saúde do Mac")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(.textSecondary)
                Spacer()
                Text(healthOK ? "Boa" : "Atenção")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(healthOK ? .appSuccess : .appWarning)
            }

            // Show specific issues
            if !healthOK {
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(healthIssues, id: \.self) { issue in
                        HStack(spacing: 4) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.system(size: 8))
                                .foregroundColor(.appWarning)
                            Text(issue)
                                .font(.system(size: 9))
                                .foregroundColor(.appWarning.opacity(0.8))
                        }
                    }
                }
            }

            HStack(spacing: 0) {
                miniStat("CPU", String(format: "%.0f%%", monitor.cpuUsage))
                Spacer()
                miniStat("RAM", String(format: "%.0f%%", ramPct))
                Spacer()
                miniStat("Disco", String(format: "%.0f%%", diskPct))
            }
        }
        .padding(10)
        .background(Color.white.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private func miniStat(_ label: String, _ value: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundColor(.white)
            Text(label)
                .font(.system(size: 9))
                .foregroundColor(.textSecondary)
        }
    }
}

// MARK: - Sidebar row
struct SidebarRow: View {
    let section: AppSection
    let isSelected: Bool
    let action: () -> Void
    @State private var isHovered = false
    @EnvironmentObject var loc: Localization

    private var localizedLabel: String {
        let key = "sidebar.\(section.localizationKey)"
        let translated = loc.t(key)
        return translated == key ? section.label : translated
    }
    private var localizedHelp: String {
        let key = "page.\(section.localizationKey).title"
        let translated = loc.t(key)
        return translated == key ? section.pageTitle : translated
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(isSelected
                              ? section.gradient
                              : isHovered
                                ? LinearGradient(colors: [Color.white.opacity(0.09), Color.white.opacity(0.06)],
                                                 startPoint: .top, endPoint: .bottom)
                                : LinearGradient(colors: [Color.clear], startPoint: .top, endPoint: .bottom))
                        .frame(width: 30, height: 30)
                        .shadow(color: isSelected ? section.accentColor.opacity(0.4) : .clear, radius: 6)

                    Image(systemName: sectionIcon)
                        .font(.system(size: 13, weight: isSelected ? .semibold : .regular))
                        .foregroundStyle(isSelected ? .white : Color(white: isHovered ? 0.75 : 0.4))
                        .symbolRenderingMode(isSelected ? .monochrome : .hierarchical)
                }

                Text(localizedLabel)
                    .font(.system(size: 13, weight: isSelected ? .semibold : .regular))
                    .foregroundColor(isSelected ? .white : Color(white: isHovered ? 0.75 : 0.45))
                    .fixedSize(horizontal: true, vertical: false)

                Spacer()
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(isSelected ? Color.white.opacity(0.06) : Color.clear)
            )
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .animation(.easeInOut(duration: 0.13), value: isHovered)
        .help(localizedHelp)
    }

    // Custom icon per section (memory gets a distinct icon)
    private var sectionIcon: String {
        switch section {
        case .memory: return "memorychip"
        default:      return section.icon
        }
    }
}
