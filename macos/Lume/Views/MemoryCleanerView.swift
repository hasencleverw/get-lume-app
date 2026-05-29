import SwiftUI

struct MemoryCleanerView: View {
    @ObservedObject var monitor: SystemMonitor
    @EnvironmentObject var loc: Localization
    @State private var isCleaning = false
    @State private var showSuccess = false
    @State private var freedMB: Int64 = 0
    @State private var ramBefore: UInt64 = 0

    private var used:  UInt64 { monitor.ramUsed }
    private var free:  UInt64 { monitor.ramFree }
    private var total: UInt64 { monitor.ramTotal }
    private var usedPct: Double { total > 0 ? Double(used) / Double(total) * 100 : 0 }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 22) {
                PageHeader(title: loc.t("page.memory.title"),
                           subtitle: loc.t("page.memory.subtitle"),
                           section: .memory)

                HStack(alignment: .top, spacing: 14) {
                    gaugePanel
                    breakdownPanel
                }

                chartPanel
            }
            .padding(28)
        }
    }

    // MARK: - Gauge panel
    private var gaugePanel: some View {
        VStack(spacing: 20) {
            CircularGauge(
                value: usedPct, size: 150, lineWidth: 13,
                gradientColors: [Color(hex: "4D8FFF"), Color(hex: "2D5FD0")]
            )

            VStack(spacing: 3) {
                Text(SystemMonitor.formatBytes(used))
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                Text(String(format: loc.t("memory.usedOf"), SystemMonitor.formatBytes(total)))
                    .font(.system(size: 12))
                    .foregroundColor(.textSecondary)
            }

            cleanButton
        }
        .padding(22)
        .frame(minWidth: 240, maxWidth: 270)
        .glassCard()
    }

    private var cleanButton: some View {
        Group {
            if showSuccess {
                VStack(spacing: 6) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 28))
                        .foregroundColor(.appSuccess)
                    Text(freedMB > 0 ? "+\(SystemMonitor.formatInt64(freedMB)) \(loc.t("disk.freed"))" : loc.t("memory.success"))
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.appSuccess)
                }
                .transition(.scale.combined(with: .opacity))
            } else {
                Button(action: cleanMemory) {
                    HStack(spacing: 7) {
                        if isCleaning {
                            ProgressView().scaleEffect(0.75).tint(.black)
                        } else {
                            Image(systemName: "bolt.fill")
                        }
                        Text(isCleaning ? loc.t("memory.cleaning") : loc.t("memory.cleanBtn"))
                            .font(.system(size: 14, weight: .bold))
                    }
                    .foregroundColor(.black)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .frame(maxWidth: .infinity)
                    .background(LinearGradient(colors: [Color(hex: "4D8FFF"), Color(hex: "2D5FD0")],
                                               startPoint: .leading, endPoint: .trailing))
                    .clipShape(Capsule())
                    .shadow(color: Color(hex: "4D8FFF").opacity(0.4), radius: 10)
                }
                .buttonStyle(.plain)
                .disabled(isCleaning)
            }
        }
        .animation(.spring(response: 0.4), value: showSuccess)
    }

    // MARK: - Breakdown panel
    private var breakdownPanel: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(loc.t("memory.detail"))
                .font(.system(size: 15, weight: .bold))
                .foregroundColor(.white)

            ramBar("App Memory",   value: Double(monitor.ramActive),     color: Color(hex: "4D8FFF"))
            ramBar("Wired Memory", value: Double(monitor.ramWired),      color: Color(hex: "FFB830"))
            ramBar("Compressed",   value: Double(monitor.ramCompressed), color: Color(hex: "9B6BF8"))
            ramBar("Cached Files", value: Double(monitor.ramInactive),   color: Color(hex: "8B6BF8"))
            ramBar("Livre",        value: Double(free),                  color: Color(hex: "00C9A7"))

            Divider().background(Color.white.opacity(0.07))

            HStack {
                statBlock("Usada",  SystemMonitor.formatBytes(used),  Color(hex: "FFB830"))
                Spacer()
                statBlock("Livre",  SystemMonitor.formatBytes(free),  Color(hex: "00C9A7"))
                Spacer()
                statBlock("Total",  SystemMonitor.formatBytes(total), .white)
            }
        }
        .padding(22)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard()
    }

    private func ramBar(_ label: String, value: Double, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                HStack(spacing: 5) {
                    Circle().fill(color).frame(width: 7, height: 7)
                    Text(label).font(.system(size: 12)).foregroundColor(.textSecondary)
                }
                Spacer()
                Text(SystemMonitor.formatBytes(UInt64(max(0, value))))
                    .font(.system(size: 12, weight: .semibold)).foregroundColor(.white)
            }
            ProgressBar(value: total > 0 ? value / Double(total) : 0, color: color)
        }
    }

    private func statBlock(_ label: String, _ value: String, _ color: Color) -> some View {
        VStack(spacing: 3) {
            Text(value).font(.system(size: 15, weight: .bold, design: .rounded)).foregroundColor(color)
            Text(label).font(.system(size: 11)).foregroundColor(.textSecondary)
        }
    }

    // MARK: - History chart
    private var chartPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(loc.t("memory.history"))
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white)
                Spacer()
                Text(String(format: "%.0f%%", usedPct))
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(Color(hex: "4D8FFF"))
            }
            LineChart(values: monitor.ramHistory, color: Color(hex: "4D8FFF"))
                .frame(height: 88)
        }
        .padding(20)
        .glassCard()
    }

    private func cleanMemory() {
        isCleaning = true
        // SystemMonitor.cleanMemory() now runs `/usr/sbin/purge` via osascript
        // with admin privileges and waits ~800ms for the VM to settle before
        // re-reading host_statistics. It also writes `lastFreedBytes` so we
        // can show the real reclaimed amount.
        monitor.cleanMemory()

        // Poll briefly until the monitor reports back, then surface the result.
        Task {
            // 1500ms is enough to cover the osascript prompt + 800ms settle.
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            await MainActor.run {
                isCleaning = false
                freedMB = monitor.lastFreedBytes
                showSuccess = true
                SoundManager.shared.playCompletion()
            }
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            await MainActor.run { showSuccess = false }
        }
    }
}
