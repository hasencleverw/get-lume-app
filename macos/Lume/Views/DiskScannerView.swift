import SwiftUI

struct DiskScannerView: View {
    @ObservedObject var monitor: SystemMonitor
    @ObservedObject var scanner: DiskScanner
    @EnvironmentObject var loc: Localization
    @State private var showDetails = false

    private var diskPct: Double {
        monitor.diskTotal > 0 ? Double(monitor.diskUsed) / Double(monitor.diskTotal) * 100 : 0
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 22) {
                PageHeader(
                    title: loc.t("page.disk.title"),
                    subtitle: loc.t("page.disk.subtitle"),
                    section: .disk,
                    trailing: AnyView(analyzeButton)
                )

                HStack(alignment: .top, spacing: 16) {
                    diskOverviewCard
                    categoriesCard
                }

                if scanner.hasScanResult && scanner.totalJunk > 0 {
                    recommendCard
                }
            }
            .padding(28)
        }
        .sheet(isPresented: $showDetails) {
            CategoryDetailsSheet(categories: scanner.categories)
                .environmentObject(loc)
        }
        .onAppear { scanner.ensureLoaded() }
    }

    // MARK: - Analyze button
    private var analyzeButton: some View {
        Button(action: { scanner.scan() }) {
            HStack(spacing: 6) {
                if scanner.isScanning {
                    ProgressView().scaleEffect(0.65).tint(.white)
                } else {
                    Image(systemName: "magnifyingglass")
                }
                Text(scanner.isScanning ? "Analisando…" : "Analisar")
                    .font(.system(size: 13, weight: .semibold))
            }
            .foregroundColor(.white)
            .padding(.horizontal, 20)
            .padding(.vertical, 9)
            .background(LinearGradient(
                colors: [Color(hex: "8B6BF8"), Color(hex: "5B3FD8")],
                startPoint: .leading, endPoint: .trailing))
            .clipShape(Capsule())
            .shadow(color: Color(hex: "8B6BF8").opacity(0.4), radius: 8)
        }
        .buttonStyle(.plain)
        .disabled(scanner.isScanning)
    }

    // MARK: - Disk overview
    private var diskOverviewCard: some View {
        VStack(spacing: 18) {
            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.07), style: StrokeStyle(lineWidth: 13))
                    .frame(width: 130, height: 130)
                Circle()
                    .trim(from: 0, to: CGFloat(diskPct / 100))
                    .stroke(
                        LinearGradient(colors: gaugeColors(diskPct),
                                       startPoint: .topLeading, endPoint: .bottomTrailing),
                        style: StrokeStyle(lineWidth: 13, lineCap: .round))
                    .frame(width: 130, height: 130)
                    .rotationEffect(.degrees(-90))
                    .animation(.spring(response: 0.5), value: diskPct)

                VStack(spacing: 2) {
                    Text(String(format: "%.0f", diskPct))
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    Text("%")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.textSecondary)
                }
            }

            VStack(spacing: 8) {
                diskRow("Usado", SystemMonitor.formatInt64(monitor.diskUsed), Color(hex: "FF8C38"))
                diskRow("Livre",  SystemMonitor.formatInt64(monitor.diskFree), Color(hex: "00C9A7"))
                Divider().background(Color.white.opacity(0.07))
                HStack {
                    Text(loc.t("disk.total")).font(.system(size: 12)).foregroundColor(.textSecondary)
                    Spacer()
                    Text(SystemMonitor.formatInt64(monitor.diskTotal))
                        .font(.system(size: 12, weight: .bold)).foregroundColor(.white)
                }
            }
        }
        .padding(20)
        .frame(minWidth: 220, maxWidth: 240)
        .glassCard()
    }

    private func gaugeColors(_ pct: Double) -> [Color] {
        if pct > 85 { return [Color(hex: "FF4D5E"), Color(hex: "CC2035")] }
        if pct > 70 { return [Color(hex: "FFB830"), Color(hex: "D08A0A")] }
        return [Color(hex: "FF8C38"), Color(hex: "D85C10")]
    }

    private func diskRow(_ label: String, _ value: String, _ color: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                HStack(spacing: 5) {
                    Circle().fill(color).frame(width: 7, height: 7)
                    Text(label).font(.system(size: 12)).foregroundColor(.textSecondary)
                }
                Spacer()
                Text(value).font(.system(size: 12, weight: .semibold)).foregroundColor(.white)
            }
            ProgressBar(
                value: label == "Usado" ? diskPct / 100 : Double(monitor.diskFree) / Double(max(monitor.diskTotal, 1)),
                color: color)
        }
    }

    /// Resolves the scanner's localized status text (used in scanning / result rows).
    private var localizedStatus: String {
        let key = scanner.statusKey
        if key == "disk.status.found" || key == "disk.status.freed" {
            return String(format: loc.t(key), SystemMonitor.formatInt64(scanner.statusArg))
        }
        return loc.t(key)
    }

    // MARK: - Categories
    private var categoriesCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(loc.t("disk.categories"))
                .font(.system(size: 15, weight: .bold))
                .foregroundColor(.white)

            if scanner.isScanning {
                scanningProgress
            } else if scanner.categories.isEmpty {
                emptyState
            } else {
                categoryList
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard()
    }

    private var scanningProgress: some View {
        VStack(alignment: .leading, spacing: 10) {
            ProgressView(value: scanner.scanProgress)
                .progressViewStyle(.linear)
                .tint(Color(hex: "8B6BF8"))
                .animation(.spring(response: 0.3), value: scanner.scanProgress)
            Text(localizedStatus)
                .font(.system(size: 12))
                .foregroundColor(.textSecondary)
            Text(String(format: "%.0f%%", scanner.scanProgress * 100))
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundColor(Color(hex: "8B6BF8"))
        }
        .padding(.vertical, 12)
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "externaldrive.fill")
                .font(.system(size: 38))
                .foregroundStyle(LinearGradient(
                    colors: [Color(hex: "8B6BF8"), Color(hex: "5B3FD8")],
                    startPoint: .topLeading, endPoint: .bottomTrailing))
                .opacity(0.6)
            Text(loc.t("disk.empty.click"))
                .font(.system(size: 13))
                .foregroundColor(.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
    }

    private var categoryList: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(scanner.categories) { cat in
                categoryRow(cat)
                if cat.id != scanner.categories.last?.id {
                    Divider().background(Color.white.opacity(0.05)).padding(.vertical, 2)
                }
            }

            Divider().background(Color.white.opacity(0.08)).padding(.vertical, 8)

            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(loc.t("disk.selected"))
                        .font(.system(size: 11)).foregroundColor(.textSecondary)
                    Text(SystemMonitor.formatInt64(
                        scanner.categories.filter(\.isSelected).reduce(0) { $0 + $1.size }
                    ))
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundStyle(LinearGradient(
                        colors: [Color(hex: "8B6BF8"), Color(hex: "5B3FD8")],
                        startPoint: .leading, endPoint: .trailing))
                }
                Spacer()
                Button(action: { scanner.clean() }) {
                    HStack(spacing: 6) {
                        if scanner.isCleaning {
                            ProgressView().scaleEffect(0.65).tint(.white)
                        } else {
                            Image(systemName: "trash.fill")
                        }
                        Text(scanner.isCleaning ? loc.t("disk.cleaning") : loc.t("common.clean"))
                            .font(.system(size: 13, weight: .bold))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 20).padding(.vertical, 9)
                    .background(LinearGradient(
                        colors: [Color(hex: "8B6BF8"), Color(hex: "5B3FD8")],
                        startPoint: .leading, endPoint: .trailing))
                    .clipShape(Capsule())
                    .shadow(color: Color(hex: "8B6BF8").opacity(0.4), radius: 8)
                }
                .buttonStyle(.plain).disabled(scanner.isCleaning)
            }
        }
    }

    private func categoryRow(_ cat: JunkCategory) -> some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 9)
                    .fill(cat.color.opacity(0.15))
                    .frame(width: 36, height: 36)
                Image(systemName: cat.icon)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(cat.color)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(loc.t(cat.nameKey))
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.white)
                ProgressBar(
                    value: scanner.totalJunk > 0 ? Double(cat.size) / Double(scanner.totalJunk) : 0,
                    color: cat.color, height: 3)
            }
            Spacer()
            Text(SystemMonitor.formatInt64(cat.size))
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(cat.color)
                .frame(minWidth: 56, alignment: .trailing)
            Toggle("", isOn: Binding(
                get: { cat.isSelected },
                set: { _ in scanner.toggle(id: cat.id) }
            )).toggleStyle(.checkbox).labelsHidden()
        }
        .padding(.vertical, 4)
    }

    // MARK: - Recommend card
    private var recommendCard: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(Color(hex: "8B6BF8").opacity(0.15))
                    .frame(width: 42, height: 42)
                Image(systemName: "sparkles")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(Color(hex: "8B6BF8"))
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(loc.t("disk.recommended"))
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.white)
                Text(String(format: loc.t("disk.recommendedDesc"), SystemMonitor.formatInt64(scanner.totalJunk)))
                    .font(.system(size: 12))
                    .foregroundColor(.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
            Button(loc.t("disk.details")) { showDetails = true }
                .buttonStyle(.plain)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(Color(hex: "8B6BF8"))
        }
        .padding(18)
        .glassCard()
    }
}

// MARK: - Category details sheet
struct CategoryDetailsSheet: View {
    let categories: [JunkCategory]
    @EnvironmentObject var loc: Localization
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(loc.t("disk.details.title"))
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                    Text(loc.t("disk.details.sub"))
                        .font(.system(size: 11))
                        .foregroundColor(.textSecondary)
                }
                Spacer()
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 18))
                        .foregroundColor(.textSecondary)
                }
                .buttonStyle(.plain)
            }
            .padding(20)

            Divider().background(Color.white.opacity(0.08))

            ScrollView(showsIndicators: false) {
                LazyVStack(alignment: .leading, spacing: 12) {
                    ForEach(categories.filter { !$0.files.isEmpty }) { cat in
                        categoryBlock(cat)
                    }
                }
                .padding(20)
            }
        }
        .background(Color(hex: "0F0F22"))
        .frame(width: 580, height: 500)
    }

    private func categoryBlock(_ cat: JunkCategory) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Image(systemName: cat.icon)
                    .font(.system(size: 13))
                    .foregroundColor(cat.color)
                Text(loc.t(cat.nameKey))
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.white)
                Spacer()
                Text(SystemMonitor.formatInt64(cat.size))
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(cat.color)
                Text("· \(cat.files.count) arquivos")
                    .font(.system(size: 11))
                    .foregroundColor(.textSecondary)
            }

            VStack(alignment: .leading, spacing: 4) {
                ForEach(cat.files.prefix(15), id: \.path) { url in
                    HStack(spacing: 6) {
                        Image(systemName: "doc.fill")
                            .font(.system(size: 9))
                            .foregroundColor(.textSecondary)
                            .frame(width: 14)
                        Text(url.lastPathComponent)
                            .font(.system(size: 11))
                            .foregroundColor(Color(white: 0.7))
                            .lineLimit(1)
                        Spacer()
                        if let size = try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize {
                            Text(SystemMonitor.formatInt64(Int64(size)))
                                .font(.system(size: 10))
                                .foregroundColor(.textSecondary)
                        }
                    }
                }
                if cat.files.count > 15 {
                    Text("  + \(cat.files.count - 15) arquivos…")
                        .font(.system(size: 10))
                        .foregroundColor(Color(white: 0.35))
                        .padding(.top, 2)
                }
            }
            .padding(.leading, 4)
        }
        .padding(14)
        .glassCard(cornerRadius: 12)
    }
}
