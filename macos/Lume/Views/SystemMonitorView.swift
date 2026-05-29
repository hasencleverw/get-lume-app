import SwiftUI

struct SystemMonitorView: View {
    @ObservedObject var monitor: SystemMonitor

    private var ramPct: Double {
        monitor.ramTotal > 0 ? Double(monitor.ramUsed) / Double(monitor.ramTotal) * 100 : 0
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 22) {
                PageHeader(title: "System Monitor",
                           subtitle: "Monitoramento em tempo real de CPU, RAM e processos",
                           section: .performance)

                HStack(alignment: .top, spacing: 14) {
                    cpuChart
                    ramChart
                }

                processesCard
            }
            .padding(28)
        }
    }

    // MARK: - CPU chart
    private var cpuChart: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                HStack(spacing: 7) {
                    Image(systemName: "cpu.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(LinearGradient(colors: [Color(hex: "9B6BF8"), Color(hex: "6B3FD8")],
                                                        startPoint: .top, endPoint: .bottom))
                    Text("CPU")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white)
                }
                Spacer()
                Text(String(format: "%.1f%%", monitor.cpuUsage))
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundStyle(LinearGradient(colors: [Color(hex: "9B6BF8"), Color(hex: "6B3FD8")],
                                                    startPoint: .leading, endPoint: .trailing))
            }
            LineChart(values: monitor.cpuHistory, color: Color(hex: "9B6BF8"))
                .frame(height: 80)
            HStack(spacing: 20) {
                miniStat("Mín",   String(format: "%.0f%%", monitor.cpuHistory.min() ?? 0))
                miniStat("Máx",   String(format: "%.0f%%", monitor.cpuHistory.max() ?? 0))
                miniStat("Média", String(format: "%.0f%%",
                    monitor.cpuHistory.isEmpty ? 0 : monitor.cpuHistory.reduce(0, +) / Double(monitor.cpuHistory.count)))
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity)
        .glassCard()
    }

    // MARK: - RAM chart
    private var ramChart: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                HStack(spacing: 7) {
                    Image(systemName: "memorychip.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(LinearGradient(colors: [Color(hex: "4D8FFF"), Color(hex: "2D5FD0")],
                                                        startPoint: .top, endPoint: .bottom))
                    Text("RAM")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white)
                }
                Spacer()
                Text(String(format: "%.1f%%", ramPct))
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundStyle(LinearGradient(colors: [Color(hex: "4D8FFF"), Color(hex: "2D5FD0")],
                                                    startPoint: .leading, endPoint: .trailing))
            }
            LineChart(values: monitor.ramHistory, color: Color(hex: "4D8FFF"))
                .frame(height: 80)
            HStack(spacing: 20) {
                miniStat("Usada", SystemMonitor.formatBytes(monitor.ramUsed))
                miniStat("Livre", SystemMonitor.formatBytes(monitor.ramFree))
                miniStat("Total", SystemMonitor.formatBytes(monitor.ramTotal))
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity)
        .glassCard()
    }

    // MARK: - Processes
    private var processesCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(LinearGradient(colors: [Color(hex: "9B6BF8"), Color(hex: "6B3FD8")],
                                             startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(width: 28, height: 28)
                    Image(systemName: "list.bullet.rectangle.fill")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.white)
                }
                Text("Processos por Memória")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white)
                Spacer()
                Text("\(monitor.topProcesses.count) processos")
                    .font(.system(size: 11))
                    .foregroundColor(.textSecondary)
            }

            Divider().background(Color.white.opacity(0.07))

            HStack {
                Text("Processo").frame(maxWidth: .infinity, alignment: .leading)
                Text("PID").frame(width: 60, alignment: .trailing)
                Text("RAM").frame(width: 80, alignment: .trailing)
            }
            .font(.system(size: 11, weight: .semibold))
            .foregroundColor(.textSecondary)
            .padding(.horizontal, 4)

            if monitor.topProcesses.isEmpty {
                HStack { Spacer(); ProgressView().scaleEffect(0.8); Spacer() }.padding(.vertical, 16)
            } else {
                ForEach(Array(monitor.topProcesses.enumerated()), id: \.element.id) { idx, proc in
                    processRow(proc, rank: idx + 1)
                    if idx < monitor.topProcesses.count - 1 {
                        Divider().background(Color.white.opacity(0.04))
                    }
                }
            }
        }
        .padding(20)
        .glassCard()
    }

    private func processRow(_ proc: SystemMonitor.ProcessInfo2, rank: Int) -> some View {
        let maxRAM = monitor.topProcesses.first?.ram ?? 1
        let fraction = Double(proc.ram) / Double(maxRAM)
        return HStack(spacing: 10) {
            Text("\(rank)")
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundColor(.textSecondary)
                .frame(width: 16)
            VStack(alignment: .leading, spacing: 3) {
                Text(proc.name)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.white).lineLimit(1)
                ProgressBar(value: fraction, color: Color(hex: "9B6BF8"), height: 3)
            }
            Text("\(proc.id)")
                .font(.system(size: 11, design: .monospaced))
                .foregroundColor(.textSecondary)
                .frame(width: 60, alignment: .trailing)
            Text(SystemMonitor.formatBytes(proc.ram))
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.white)
                .frame(width: 80, alignment: .trailing)
        }
        .padding(.horizontal, 4)
    }

    private func miniStat(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label).font(.system(size: 10)).foregroundColor(.textSecondary)
            Text(value).font(.system(size: 12, weight: .semibold)).foregroundColor(.white)
        }
    }
}
