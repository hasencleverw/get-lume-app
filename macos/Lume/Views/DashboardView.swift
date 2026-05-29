import SwiftUI

struct DashboardView: View {
    @ObservedObject var monitor: SystemMonitor
    @ObservedObject var scanner: DiskScanner
    @EnvironmentObject var loc: Localization

    private var localizedDiskStatus: String {
        let key = scanner.statusKey
        if key == "disk.status.found" || key == "disk.status.freed" {
            return String(format: loc.t(key), SystemMonitor.formatInt64(scanner.statusArg))
        }
        return loc.t(key)
    }

    private var ramPct:  Double { monitor.ramTotal  > 0 ? Double(monitor.ramUsed)  / Double(monitor.ramTotal)  * 100 : 0 }
    private var diskPct: Double { monitor.diskTotal > 0 ? Double(monitor.diskUsed) / Double(monitor.diskTotal) * 100 : 0 }
    private var overallOK: Bool { monitor.cpuUsage < 80 && ramPct < 80 && diskPct < 90 }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 24) {
                pageHeader
                metricsRow
                scanCard
            }
            .padding(28)
        }
    }

    // MARK: - Header
    private var pageHeader: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 5) {
                Text(loc.t("page.dashboard.title"))
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                Text(loc.t("page.dashboard.subtitle"))
                    .font(.system(size: 14))
                    .foregroundColor(.textSecondary)
            }
            Spacer()
            overallStatusBadge
        }
    }

    private var overallStatusBadge: some View {
        HStack(spacing: 7) {
            Circle()
                .fill(overallOK ? Color.appSuccess : Color.appWarning)
                .frame(width: 8, height: 8)
                .shadow(color: (overallOK ? Color.appSuccess : Color.appWarning).opacity(0.9), radius: 5)
            Text(overallOK ? loc.t("sidebar.healthy") : loc.t("sidebar.health.attention"))
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(overallOK ? .appSuccess : .appWarning)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 7)
        .background((overallOK ? Color.appSuccess : Color.appWarning).opacity(0.12))
        .clipShape(Capsule())
        .overlay(Capsule().strokeBorder((overallOK ? Color.appSuccess : Color.appWarning).opacity(0.25)))
    }

    // MARK: - Metrics row
    private var metricsRow: some View {
        HStack(spacing: 14) {
            metricTile(
                title: "CPU", icon: "cpu.fill",
                value: monitor.cpuUsage,
                sub: String(format: "%.1f%% uso", monitor.cpuUsage),
                section: .dashboard
            )
            metricTile(
                title: loc.t("sidebar.memory"), icon: "memorychip.fill",
                value: ramPct,
                sub: "\(SystemMonitor.formatBytes(monitor.ramUsed)) / \(SystemMonitor.formatBytes(monitor.ramTotal))",
                section: .memory
            )
            metricTile(
                title: loc.t("sidebar.disk"), icon: "internaldrive.fill",
                value: diskPct,
                sub: "\(SystemMonitor.formatInt64(monitor.diskFree)) livres",
                section: .disk
            )
        }
    }

    private func metricTile(title: String, icon: String, value: Double,
                             sub: String, section: AppSection) -> some View {
        VStack(spacing: 16) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(section.gradient)
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white)
                Spacer()
                trendDot(value: value)
            }

            ZStack {
                PulsingRings(color: section.accentColor, value: value)
                    .frame(width: 110, height: 110)

                CircularGauge(value: value, size: 84, lineWidth: 9,
                              gradientColors: section.gradientColors)
            }
            .frame(maxWidth: .infinity)

            Text(sub)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.textSecondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .padding(18)
        .glassCard()
    }

    private func trendDot(value: Double) -> some View {
        let color: Color = value < 60 ? .appSuccess : value < 80 ? .appWarning : .appDanger
        return Circle()
            .fill(color)
            .frame(width: 7, height: 7)
            .shadow(color: color.opacity(0.8), radius: 3)
    }

    // MARK: - Scan card
    private var scanCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            scanCardHeader
                .padding(22)

            if scanner.isScanning {
                scanningState.padding(.horizontal, 22).padding(.bottom, 22)
            } else if scanner.hasScanResult {
                Divider().background(Color.white.opacity(0.07))
                scanResults.padding(22)
            } else {
                if scanner.spaceFreed > 0 {
                    freedBanner.padding(.horizontal, 22).padding(.bottom, 22)
                } else {
                    emptyPrompt.padding(.horizontal, 22).padding(.bottom, 22)
                }
            }
        }
        .glassCard()
    }

    private var scanCardHeader: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(LinearGradient(colors: [Color(hex: "9B6BF8"), Color(hex: "6B3FD8")],
                                        startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 42, height: 42)
                    .shadow(color: Color(hex: "9B6BF8").opacity(0.5), radius: 8)
                Image(systemName: "sparkles")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.white)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(loc.t("dash.cleanup.title"))
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)
                Text(localizedDiskStatus)
                    .font(.system(size: 12))
                    .foregroundColor(.textSecondary)
            }
            Spacer()
            if !scanner.isScanning && !scanner.hasScanResult {
                Button(action: { scanner.scan() }) {
                    Text(loc.t("dash.cleanup.startScan"))
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.black)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 9)
                        .background(Color.appAccent)
                        .clipShape(Capsule())
                        .shadow(color: Color.appAccent.opacity(0.4), radius: 8)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var scanningState: some View {
        VStack(spacing: 10) {
            ProgressView(value: scanner.scanProgress)
                .progressViewStyle(.linear)
                .tint(Color.appAccent)
            Text(localizedDiskStatus)
                .font(.system(size: 12))
                .foregroundColor(.textSecondary)
        }
    }

    private var emptyPrompt: some View {
        Text(loc.t("dash.cleanup.intro"))
            .font(.system(size: 12))
            .foregroundColor(.textSecondary)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var freedBanner: some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.appSuccess)
            Text(localizedDiskStatus)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.appSuccess)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.appSuccess.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private var scanResults: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Label(localizedDiskStatus, systemImage: "exclamationmark.circle.fill")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.appWarning)
                Spacer()
                Button(action: { scanner.scan() }) {
                    Label(loc.t("dash.cleanup.newScan"), systemImage: "arrow.clockwise")
                        .font(.system(size: 11))
                        .foregroundColor(.textSecondary)
                }
                .buttonStyle(.plain)
            }

            VStack(spacing: 10) {
                ForEach(scanner.categories) { cat in
                    HStack(spacing: 12) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 9)
                                .fill(cat.color.opacity(0.18))
                                .frame(width: 34, height: 34)
                            Image(systemName: cat.icon)
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(cat.color)
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text(loc.t(cat.nameKey)).font(.system(size: 13, weight: .medium)).foregroundColor(.white)
                            Text("\(cat.files.count)").font(.system(size: 10)).foregroundColor(.textSecondary)
                        }
                        Spacer()
                        Text(SystemMonitor.formatInt64(cat.size))
                            .font(.system(size: 13, weight: .bold)).foregroundColor(cat.color)
                        Toggle("", isOn: Binding(
                            get: { cat.isSelected },
                            set: { _ in scanner.toggle(id: cat.id) }
                        ))
                        .toggleStyle(.checkbox).labelsHidden()
                    }
                }
            }

            Divider().background(Color.white.opacity(0.06))

            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(loc.t("dash.cleanup.selected"))
                        .font(.system(size: 11)).foregroundColor(.textSecondary)
                    Text(SystemMonitor.formatInt64(
                        scanner.categories.filter(\.isSelected).reduce(0) { $0 + $1.size }
                    ))
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundStyle(LinearGradient(colors: [Color(hex: "9B6BF8"), Color(hex: "6B3FD8")],
                                                    startPoint: .leading, endPoint: .trailing))
                }
                Spacer()
                Button(action: { scanner.clean() }) {
                    HStack(spacing: 7) {
                        if scanner.isCleaning {
                            ProgressView().scaleEffect(0.7).tint(.black)
                        } else {
                            Image(systemName: "trash.fill")
                        }
                        Text(scanner.isCleaning ? loc.t("disk.cleaning") : loc.t("dash.cleanup.cleanNow"))
                            .font(.system(size: 14, weight: .bold))
                    }
                    .foregroundColor(.black)
                    .padding(.horizontal, 22)
                    .padding(.vertical, 11)
                    .background(LinearGradient(colors: [Color(hex: "9B6BF8"), Color(hex: "6B3FD8")],
                                               startPoint: .leading, endPoint: .trailing))
                    .clipShape(Capsule())
                    .shadow(color: Color(hex: "9B6BF8").opacity(0.45), radius: 10)
                }
                .buttonStyle(.plain)
                .disabled(scanner.isCleaning)
            }
        }
    }
}

// MARK: - Pulsing rings animation behind gauges
struct PulsingRings: View {
    let color: Color
    let value: Double // 0–100
    @State private var scale: CGFloat = 1.0
    @State private var opacity: Double = 0.55

    var body: some View {
        ZStack {
            ForEach(0..<3, id: \.self) { i in
                Circle()
                    .stroke(color.opacity(opacity * max(0.1, value / 100) / Double(i + 1)),
                            lineWidth: max(0.5, 2.0 - Double(i) * 0.5))
                    .scaleEffect(scale + CGFloat(i) * 0.13)
            }
        }
        .onAppear {
            let speed = max(1.0, 3.5 - value / 40.0)
            withAnimation(.easeInOut(duration: speed).repeatForever(autoreverses: true)) {
                scale = 1.22
                opacity = 0.08
            }
        }
    }
}
