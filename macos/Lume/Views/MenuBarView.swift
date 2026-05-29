import SwiftUI

struct MenuBarQuickView: View {
    @EnvironmentObject var monitor: SystemMonitor
    @EnvironmentObject var scanner: DiskScanner
    @EnvironmentObject var loc: Localization
    @Environment(\.openWindow) private var openWindow

    @State private var isCleaning = false
    @State private var cleanMsg: String? = nil

    private var ramPct: Double {
        monitor.ramTotal > 0 ? Double(monitor.ramUsed) / Double(monitor.ramTotal) * 100 : 0
    }
    private var diskPct: Double {
        monitor.diskTotal > 0 ? Double(monitor.diskUsed) / Double(monitor.diskTotal) * 100 : 0
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider().background(Color.white.opacity(0.08))
            metricsSection
            Divider().background(Color.white.opacity(0.08))
            actionsSection
            Divider().background(Color.white.opacity(0.08))
            footer
        }
        .frame(width: 300)
        .background(Color(hex: "0D0520"))
    }

    // MARK: - Header
    private func loadLogoImage() -> NSImage? {
        if let url = Bundle.main.url(forResource: "Icone", withExtension: "png"),
           let img = NSImage(contentsOf: url) { return img }
        return nil
    }

    private var header: some View {
        HStack(spacing: 10) {
            Group {
                if let img = loadLogoImage() {
                    Image(nsImage: img)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 32, height: 32)
                        .clipShape(RoundedRectangle(cornerRadius: 9))
                } else {
                    ZStack {
                        RoundedRectangle(cornerRadius: 9)
                            .fill(LinearGradient(
                                colors: [Color(hex: "9B6BF8"), Color(hex: "6B3FD8")],
                                startPoint: .topLeading, endPoint: .bottomTrailing
                            ))
                            .frame(width: 32, height: 32)
                        Image(systemName: "sparkles")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(.white)
                    }
                }
            }
            VStack(alignment: .leading, spacing: 1) {
                Text(loc.t("menu.appName"))
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.white)
                HStack(spacing: 5) {
                    Circle()
                        .fill(Color.appSuccess)
                        .frame(width: 6, height: 6)
                        .shadow(color: Color.appSuccess.opacity(0.8), radius: 3)
                    Text(loc.t("menu.healthy"))
                        .font(.system(size: 11))
                        .foregroundColor(Color.appSuccess)
                }
            }
            Spacer()
            Button(action: openMainWindow) {
                Image(systemName: "arrow.up.left.and.arrow.down.right")
                    .font(.system(size: 11))
                    .foregroundColor(.textSecondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }

    // MARK: - Metrics
    private var metricsSection: some View {
        HStack(spacing: 10) {
            miniGauge(label: "CPU", value: monitor.cpuUsage,
                      colors: [Color(hex: "9B6BF8"), Color(hex: "6B3FD8")])
            miniGauge(label: "RAM", value: ramPct,
                      colors: [Color(hex: "4D8FFF"), Color(hex: "2D5FD0")])
            miniGauge(label: loc.t("sidebar.disk"), value: diskPct,
                      colors: [Color(hex: "FF8C38"), Color(hex: "D85C10")])
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 14)
    }

    private func miniGauge(label: String, value: Double, colors: [Color]) -> some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.07), lineWidth: 6)
                    .frame(width: 54, height: 54)
                Circle()
                    .trim(from: 0, to: CGFloat(value / 100))
                    .stroke(
                        LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing),
                        style: StrokeStyle(lineWidth: 6, lineCap: .round)
                    )
                    .frame(width: 54, height: 54)
                    .rotationEffect(.degrees(-90))
                    .shadow(color: colors[0].opacity(0.6), radius: 4)
                    .animation(.spring(response: 0.5), value: value)
                Text(String(format: "%.0f%%", value))
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
            }
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.textSecondary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Actions
    private var actionsSection: some View {
        VStack(spacing: 8) {
            quickActionButton(
                icon: "memorychip.fill",
                title: loc.t("menu.cleanRAM"),
                subtitle: "\(SystemMonitor.formatBytes(monitor.ramFree))",
                color: Color(hex: "4D8FFF"),
                isLoading: isCleaning
            ) {
                cleanMemoryAction()
            }

            quickActionButton(
                icon: "sparkles",
                title: loc.t("menu.quickScan"),
                subtitle: scanner.hasScanResult
                    ? SystemMonitor.formatInt64(scanner.totalJunk) + " " + loc.t("disk.junkFound")
                    : loc.t("menu.findJunk"),
                color: Color(hex: "9B6BF8"),
                isLoading: scanner.isScanning
            ) {
                scanner.scan()
            }

            if let msg = cleanMsg {
                Text(msg)
                    .font(.system(size: 11))
                    .foregroundColor(Color.appSuccess)
                    .transition(.opacity)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 12)
    }

    private func quickActionButton(icon: String, title: String, subtitle: String,
                                   color: Color, isLoading: Bool,
                                   action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(color.opacity(0.18))
                        .frame(width: 34, height: 34)
                    if isLoading {
                        ProgressView().scaleEffect(0.7).tint(color)
                    } else {
                        Image(systemName: icon)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(color)
                    }
                }
                VStack(alignment: .leading, spacing: 1) {
                    Text(title)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.white)
                    Text(subtitle)
                        .font(.system(size: 10))
                        .foregroundColor(.textSecondary)
                        .lineLimit(1)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 10))
                    .foregroundColor(.textSecondary)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(Color.white.opacity(0.04))
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
        .disabled(isLoading)
    }

    // MARK: - Footer
    private var footer: some View {
        VStack(spacing: 6) {
            HStack {
                Text(SystemMonitor.formatInt64(monitor.diskFree) + " " + loc.t("menu.diskFree"))
                    .font(.system(size: 10))
                    .foregroundColor(.textSecondary)
                Spacer()
            }
            HStack(spacing: 14) {
                Button(action: { openMainWindow() }) {
                    Text(loc.t("menu.openLume"))
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(Color(white: 0.7))
                }
                .buttonStyle(.plain)

                Spacer()

                Button(action: { NSApp.terminate(nil) }) {
                    Text(loc.t("menu.quitLume"))
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(Color(white: 0.45))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    // MARK: - Actions
    private func cleanMemoryAction() {
        isCleaning = true
        Task {
            try? await Task.sleep(nanoseconds: 900_000_000)
            await MainActor.run {
                monitor.cleanMemory()
                isCleaning = false
                cleanMsg = "✓ " + loc.t("memory.success")
                SoundManager.shared.playCompletion()
            }
            try? await Task.sleep(nanoseconds: 2_500_000_000)
            await MainActor.run { cleanMsg = nil }
        }
    }

    private func openMainWindow() {
        // Restore Dock presence so the window can come to the front. If the user
        // had toggled "Remove from Dock" earlier the policy is .accessory, which
        // both hides the Dock icon AND prevents the window from being shown
        // normally — flipping back to .regular fixes both.
        if NSApp.activationPolicy() != .regular {
            NSApp.setActivationPolicy(.regular)
        }
        NSApp.activate(ignoringOtherApps: true)

        // Find the WindowGroup's main window by its identifier. SwiftUI tags
        // the NSWindow with the WindowGroup id, so filtering on that avoids
        // accidentally targeting the MenuBarExtra's hosting window.
        let mainWindow = NSApp.windows.first { window in
            (window.identifier?.rawValue ?? "").contains("main")
        }

        if let window = mainWindow {
            if window.isMiniaturized { window.deminiaturize(nil) }
            window.makeKeyAndOrderFront(nil)
            window.orderFrontRegardless()
        } else {
            openWindow(id: "main")
        }

        // Belt-and-suspenders: re-activate after the window is up so the new
        // window steals focus from whatever the user was on (Finder, etc.).
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            NSApp.activate(ignoringOtherApps: true)
            if let w = NSApp.windows.first(where: { ($0.identifier?.rawValue ?? "").contains("main") }) {
                w.makeKeyAndOrderFront(nil)
                w.orderFrontRegardless()
            }
        }
    }
}
