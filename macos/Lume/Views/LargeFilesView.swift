import SwiftUI

struct LargeFilesView: View {
    @ObservedObject var scanner: LargeFilesScanner
    @EnvironmentObject var loc: Localization
    @State private var isGridMode = false
    @State private var showDeleteConfirm = false

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 22) {
                PageHeader(
                    title: loc.t("page.spaceLens.title"),
                    subtitle: loc.t("page.spaceLens.subtitle"),
                    section: .largeFiles,
                    trailing: AnyView(headerButtons)
                )

                diskSelector
                filtersRow

                if scanner.isScanning {
                    scanningView
                } else if scanner.items.isEmpty {
                    emptyState
                } else {
                    if isGridMode {
                        fileGrid
                    } else {
                        fileList
                    }
                }
            }
            .padding(28)
        }
        .background(Color.clear)
        .alert(loc.t("common.moveToTrash") + "?", isPresented: $showDeleteConfirm) {
            Button(loc.t("common.cancel"), role: .cancel) {}
            Button(loc.t("common.moveToTrash"), role: .destructive) { scanner.deleteSelected() }
        } message: {
            let count = scanner.items.filter(\.isSelected).count
            Text(String(format: loc.t("spaceLens.confirm"), count))
        }
    }

    // MARK: - Header buttons
    private var headerButtons: some View {
        HStack(spacing: 10) {
            HStack(spacing: 2) {
                viewToggleBtn(icon: "list.bullet", active: !isGridMode) { isGridMode = false }
                viewToggleBtn(icon: "square.grid.3x2.fill", active: isGridMode) { isGridMode = true }
            }
            .padding(3)
            .background(Color.white.opacity(0.07))
            .clipShape(RoundedRectangle(cornerRadius: 9))

            Button(action: { scanner.scan() }) {
                HStack(spacing: 6) {
                    if scanner.isScanning {
                        ProgressView().scaleEffect(0.65).tint(.black)
                    } else {
                        Image(systemName: "magnifyingglass")
                    }
                    Text(scanner.isScanning ? loc.t("common.analyzing") : loc.t("common.analyze"))
                        .font(.system(size: 13, weight: .semibold))
                }
                .foregroundColor(.black)
                .padding(.horizontal, 18)
                .padding(.vertical, 9)
                .background(LinearGradient(colors: [Color(hex: "00C9A7"), Color(hex: "00957A")],
                                           startPoint: .leading, endPoint: .trailing))
                .clipShape(Capsule())
                .shadow(color: Color(hex: "00C9A7").opacity(0.4), radius: 8)
            }
            .buttonStyle(.plain)
            .disabled(scanner.isScanning)
        }
    }

    private func viewToggleBtn(icon: String, active: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(active ? .white : Color(white: 0.45))
                .frame(width: 30, height: 27)
                .background(active ? Color.white.opacity(0.14) : Color.clear)
                .clipShape(RoundedRectangle(cornerRadius: 7))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Disk selector
    private var diskSelector: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                diskChip(name: loc.t("spaceLens.allDisks"), diskName: nil)
                ForEach(scanner.disks) { disk in
                    diskChip(name: disk.name, diskName: disk.name)
                }
            }
        }
    }

    private func diskChip(name: String, diskName: String?) -> some View {
        let isSelected = scanner.selectedDisk == diskName
        return Button(action: { scanner.selectedDisk = diskName }) {
            HStack(spacing: 6) {
                Image(systemName: diskName == nil ? "externaldrive.fill" : "internaldrive.fill")
                    .font(.system(size: 11))
                    .foregroundColor(isSelected ? .black : Color(hex: "00C9A7"))
                Text(name)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(isSelected ? .black : .white)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 7)
            .background(isSelected
                ? LinearGradient(colors: [Color(hex: "00C9A7"), Color(hex: "00957A")],
                                 startPoint: .leading, endPoint: .trailing)
                : LinearGradient(colors: [Color.white.opacity(0.07), Color.white.opacity(0.04)],
                                 startPoint: .leading, endPoint: .trailing))
            .clipShape(Capsule())
            .overlay(Capsule().strokeBorder(Color(hex: "00C9A7").opacity(isSelected ? 0 : 0.3)))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Filters
    private var filtersRow: some View {
        HStack(spacing: 10) {
            HStack(spacing: 8) {
                Text(loc.t("spaceLens.minSize"))
                    .font(.system(size: 12))
                    .foregroundColor(.textSecondary)
                Slider(value: Binding(
                    get: { Double(scanner.minSizeMB) },
                    set: { scanner.minSizeMB = Int($0) }
                ), in: 10...500, step: 10)
                .frame(width: 110)
                .tint(Color(hex: "00C9A7"))
                Text("\(scanner.minSizeMB) MB")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(width: 55)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .glassCard(cornerRadius: 10)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    kindChip(nil, label: loc.t("spaceLens.all"))
                    ForEach(LargeFileItem.FileKind.allCases, id: \.self) { kind in
                        kindChip(kind, label: loc.t(kind.localizationKey))
                    }
                }
            }

            if scanner.items.contains(where: \.isSelected) {
                let count = scanner.items.filter(\.isSelected).count
                Button(action: { showDeleteConfirm = true }) {
                    Label(String(format: loc.t("spaceLens.moveTo"), count), systemImage: "trash.fill")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 7)
                        .background(Color(hex: "FF4D5E").opacity(0.8))
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                .transition(.scale.combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.3), value: scanner.items.filter(\.isSelected).count)
    }

    private func kindChip(_ kind: LargeFileItem.FileKind?, label: String) -> some View {
        let isActive = scanner.selectedKind == kind
        let color = kind?.color ?? Color.appAccent
        return Button(action: { scanner.selectedKind = kind }) {
            HStack(spacing: 4) {
                if let k = kind {
                    Image(systemName: k.icon)
                        .font(.system(size: 10))
                        .foregroundColor(isActive ? .black : color)
                }
                Text(label)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(isActive ? .black : .white)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(isActive ? color : color.opacity(0.14))
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    // MARK: - States
    private var scanningView: some View {
        VStack(spacing: 14) {
            HStack {
                Text(loc.t("spaceLens.scanning"))
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white)
                Spacer()
                Text(String(format: "%.0f%%", scanner.progress * 100))
                    .font(.system(size: 13, weight: .bold, design: .monospaced))
                    .foregroundColor(Color(hex: "00C9A7"))
            }
            ProgressView(value: scanner.progress)
                .progressViewStyle(.linear)
                .tint(Color(hex: "00C9A7"))
                .animation(.spring(response: 0.3), value: scanner.progress)
            Text(scanner.statusMessage)
                .font(.system(size: 12))
                .foregroundColor(.textSecondary)
        }
        .padding(24)
        .glassCard()
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "circle.grid.cross.fill")
                .font(.system(size: 52))
                .foregroundStyle(LinearGradient(
                    colors: [Color(hex: "00C9A7"), Color(hex: "00957A")],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                ))
                .opacity(0.7)
            if scanner.progress > 0 {
                Text(loc.t("spaceLens.noResults"))
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
                Text(String(format: loc.t("spaceLens.minHint"), scanner.minSizeMB))
                    .font(.system(size: 12))
                    .foregroundColor(.textSecondary)
            } else {
                Text(loc.t("spaceLens.empty"))
                    .font(.system(size: 14))
                    .foregroundColor(.textSecondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(40)
        .glassCard()
    }

    // MARK: - File list
    private var fileList: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(scanner.statusMessage)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white)
                Spacer()
                let selected = scanner.filteredItems.filter(\.isSelected)
                if !selected.isEmpty {
                    Text(SystemMonitor.formatInt64(selected.reduce(0) { $0 + $1.size }) + " " + loc.t("spaceLens.selected"))
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(Color(hex: "00C9A7"))
                }
            }
            .padding(.horizontal, 18)
            .padding(.top, 16)
            .padding(.bottom, 10)

            Divider().background(Color.white.opacity(0.07))

            HStack {
                Text(loc.t("spaceLens.name"))
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text(loc.t("spaceLens.type"))
                    .frame(width: 100, alignment: .leading)
                Text(loc.t("spaceLens.disk"))
                    .frame(width: 90, alignment: .leading)
                Text(loc.t("spaceLens.size"))
                    .frame(width: 90, alignment: .trailing)
                Text("")
                    .frame(width: 24)
            }
            .font(.system(size: 11, weight: .semibold))
            .foregroundColor(.textSecondary)
            .padding(.horizontal, 18)
            .padding(.vertical, 8)

            Divider().background(Color.white.opacity(0.05))

            VStack(spacing: 0) {
                ForEach(scanner.filteredItems.prefix(200)) { item in
                    FileRow(item: item) { scanner.toggleSelect(item.id) }
                    Divider().background(Color.white.opacity(0.04))
                }
            }
        }
        .glassCard(cornerRadius: 16)
    }

    // MARK: - File grid
    private var fileGrid: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text(scanner.statusMessage)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white)
                Spacer()
                let sel = scanner.filteredItems.filter(\.isSelected)
                if !sel.isEmpty {
                    Text(SystemMonitor.formatInt64(sel.reduce(0) { $0 + $1.size }) + " selecionados")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(Color(hex: "00C9A7"))
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 110, maximum: 150))], spacing: 10) {
                ForEach(scanner.filteredItems.prefix(120)) { item in
                    FileGridCell(item: item) { scanner.toggleSelect(item.id) }
                }
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 14)
        }
        .glassCard(cornerRadius: 16)
    }
}

// MARK: - Grid cell
struct FileGridCell: View {
    let item: LargeFileItem
    let onToggle: () -> Void
    @State private var isHovered = false

    var body: some View {
        VStack(spacing: 8) {
            ZStack(alignment: .topTrailing) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(item.kind.color.opacity(0.14))
                        .frame(width: 44, height: 44)
                    Image(systemName: item.kind.icon)
                        .font(.system(size: 20))
                        .foregroundColor(item.kind.color)
                }
                Image(systemName: item.isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 14))
                    .foregroundColor(item.isSelected ? Color(hex: "00C9A7") : Color.white.opacity(0.35))
                    .offset(x: 6, y: -6)
            }
            Text(item.name)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(.white)
                .lineLimit(2)
                .multilineTextAlignment(.center)
            Text(SystemMonitor.formatInt64(item.size))
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .foregroundColor(item.kind.color)
        }
        .padding(10)
        .background(item.isSelected
            ? Color(hex: "00C9A7").opacity(0.09)
            : isHovered ? Color.white.opacity(0.05) : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12)
            .strokeBorder(item.isSelected ? Color(hex: "00C9A7").opacity(0.35) : Color.clear))
        .contentShape(Rectangle())
        .onTapGesture { onToggle() }
        .onHover { isHovered = $0 }
        .animation(.easeInOut(duration: 0.1), value: isHovered)
    }
}

// MARK: - File row
struct FileRow: View {
    let item: LargeFileItem
    let onToggle: () -> Void
    @EnvironmentObject var loc: Localization
    @State private var isHovered = false

    var body: some View {
        HStack {
            Image(systemName: item.isSelected ? "checkmark.circle.fill" : "circle")
                .font(.system(size: 16))
                .foregroundColor(item.isSelected ? Color(hex: "00C9A7") : .textSecondary)
                .onTapGesture { onToggle() }

            HStack(spacing: 8) {
                ZStack {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(item.kind.color.opacity(0.14))
                        .frame(width: 26, height: 26)
                    Image(systemName: item.kind.icon)
                        .font(.system(size: 12))
                        .foregroundColor(item.kind.color)
                }
                VStack(alignment: .leading, spacing: 1) {
                    Text(item.name)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.white)
                        .lineLimit(1)
                    Text(item.path.replacingOccurrences(of: FileManager.default.homeDirectoryForCurrentUser.path, with: "~"))
                        .font(.system(size: 9))
                        .foregroundColor(.textSecondary)
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Text(loc.t(item.kind.localizationKey))
                .font(.system(size: 11))
                .foregroundColor(item.kind.color)
                .frame(width: 100, alignment: .leading)

            Text(item.disk)
                .font(.system(size: 11))
                .foregroundColor(.textSecondary)
                .frame(width: 90, alignment: .leading)

            Text(SystemMonitor.formatInt64(item.size))
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundColor(.white)
                .frame(width: 90, alignment: .trailing)

            Button(action: {
                // For folders: open the folder; for files: select in parent
                if item.kind == .folder {
                    NSWorkspace.shared.open(item.url)
                } else {
                    NSWorkspace.shared.activateFileViewerSelecting([item.url])
                }
            }) {
                Image(systemName: "arrow.right.circle")
                    .font(.system(size: 14))
                    .foregroundColor(isHovered ? .textSecondary : .clear)
            }
            .buttonStyle(.plain)
            .frame(width: 24)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 9)
        .background(item.isSelected
            ? Color(hex: "00C9A7").opacity(0.06)
            : isHovered ? Color.white.opacity(0.03) : Color.clear)
        .contentShape(Rectangle())
        .onHover { isHovered = $0 }
        .animation(.easeInOut(duration: 0.1), value: isHovered)
    }
}
