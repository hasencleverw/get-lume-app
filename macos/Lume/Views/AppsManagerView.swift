import SwiftUI
import AppKit

struct AppsManagerView: View {
    @ObservedObject var manager: AppManager
    @EnvironmentObject var loc: Localization
    @State private var showConfirm = false

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 22) {
                PageHeader(
                    title: loc.t("page.apps.title"),
                    subtitle: loc.t("page.apps.subtitle"),
                    section: .apps,
                    trailing: AnyView(headerActions)
                )

                controlsBar

                if manager.isLoading {
                    loadingView
                } else if manager.apps.isEmpty {
                    emptyState
                } else {
                    appGrid
                }
            }
            .padding(28)
        }
        .onAppear { if manager.apps.isEmpty { manager.load() } }
        .alert(loc.t("apps.confirmTitle"), isPresented: $showConfirm) {
            Button(loc.t("common.cancel"), role: .cancel) {}
            Button(loc.t("common.moveToTrash"), role: .destructive) { manager.uninstallSelected() }
        } message: {
            let count = manager.selectedApps.count
            let size = SystemMonitor.formatInt64(manager.selectedSize)
            Text(String(format: loc.t("apps.confirmMsg"), count, size))
        }
    }

    // MARK: - Header actions
    private var headerActions: some View {
        HStack(spacing: 10) {
            if !manager.selectedApps.isEmpty {
                Button(action: { showConfirm = true }) {
                    HStack(spacing: 6) {
                        if manager.isUninstalling {
                            ProgressView().scaleEffect(0.65).tint(.white)
                        } else {
                            Image(systemName: "trash.fill")
                        }
                        Text(manager.isUninstalling
                             ? loc.t("apps.removing")
                             : String(format: loc.t("apps.removeCount"), manager.selectedApps.count, SystemMonitor.formatInt64(manager.selectedSize)))
                            .font(.system(size: 12, weight: .semibold))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(LinearGradient(colors: [Color(hex: "FF4D5E"), Color(hex: "CC2035")],
                                               startPoint: .leading, endPoint: .trailing))
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                .disabled(manager.isUninstalling)
                .transition(.scale.combined(with: .opacity))
            }

            Button(action: { manager.load() }) {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 14))
                    .foregroundColor(.textSecondary)
            }
            .buttonStyle(.plain)
        }
        .animation(.spring(response: 0.3), value: manager.selectedApps.isEmpty)
    }

    // MARK: - Controls bar
    private var controlsBar: some View {
        HStack(spacing: 12) {
            // Search
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 13))
                    .foregroundColor(Color(white: 0.65))
                ZStack(alignment: .leading) {
                    if manager.searchText.isEmpty {
                        Text(loc.t("apps.search"))
                            .font(.system(size: 13))
                            .foregroundColor(Color(white: 0.55))
                    }
                    TextField("", text: $manager.searchText)
                        .textFieldStyle(.plain)
                        .font(.system(size: 13))
                        .foregroundColor(.white)
                        .tint(Color.appAccent)
                        .environment(\.colorScheme, .dark)
                }
                if !manager.searchText.isEmpty {
                    Button(action: { manager.searchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.textSecondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .frame(maxWidth: 280)
            .background(Color.black.opacity(0.35))
            .overlay(RoundedRectangle(cornerRadius: 10)
                .strokeBorder(Color.white.opacity(0.12), lineWidth: 1))
            .clipShape(RoundedRectangle(cornerRadius: 10))

            Spacer()

            // Sort
            HStack(spacing: 6) {
                Text(loc.t("apps.sortBy"))
                    .font(.system(size: 12))
                    .foregroundColor(.textSecondary)
                HStack(spacing: 2) {
                    ForEach(AppManager.SortField.allCases, id: \.self) { f in
                        sortBtn(f)
                    }
                }
                .padding(3)
                .background(Color.white.opacity(0.07))
                .clipShape(RoundedRectangle(cornerRadius: 9))
            }

            // Stats
            if !manager.apps.isEmpty {
                Text("\(manager.filteredApps.count) \(loc.t("apps.count"))")
                    .font(.system(size: 12))
                    .foregroundColor(.textSecondary)
            }
        }
    }

    private func sortBtn(_ field: AppManager.SortField) -> some View {
        let active = manager.sortBy == field
        let label: String = {
            switch field {
            case .name:     return loc.t("apps.sort.name")
            case .size:     return loc.t("apps.sort.size")
            case .lastUsed: return loc.t("apps.sort.lastUsed")
            }
        }()
        return Button(action: { manager.sortBy = field }) {
            Text(label)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(active ? .white : Color(white: 0.55))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(active ? Color.white.opacity(0.16) : Color.clear)
                .clipShape(RoundedRectangle(cornerRadius: 7))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Loading
    private var loadingView: some View {
        VStack(spacing: 14) {
            ProgressView().scaleEffect(1.2).tint(Color(hex: "34C87A"))
            Text(loc.t("apps.loading"))
                .font(.system(size: 13))
                .foregroundColor(.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(40)
        .glassCard()
    }

    private var emptyState: some View {
        VStack(spacing: 14) {
            Image(systemName: "square.stack.3d.up.fill")
                .font(.system(size: 48))
                .foregroundStyle(LinearGradient(
                    colors: [Color(hex: "34C87A"), Color(hex: "1A9A55")],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                ))
                .opacity(0.7)
            Text(loc.t("apps.empty"))
                .font(.system(size: 14))
                .foregroundColor(.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(40)
        .glassCard()
    }

    // MARK: - App grid/list
    private var appGrid: some View {
        VStack(spacing: 0) {
            // Table header
            HStack {
                Text("").frame(width: 32)
                Text(loc.t("apps.app"))
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text(loc.t("apps.version"))
                    .frame(width: 90, alignment: .leading)
                Text(loc.t("apps.lastUsed"))
                    .frame(width: 110, alignment: .leading)
                Text(loc.t("apps.size"))
                    .frame(width: 90, alignment: .trailing)
                Text("").frame(width: 60)
            }
            .font(.system(size: 11, weight: .semibold))
            .foregroundColor(.textSecondary)
            .padding(.horizontal, 18)
            .padding(.vertical, 10)

            Divider().background(Color.white.opacity(0.07))

            LazyVStack(spacing: 0) {
                ForEach(manager.filteredApps) { app in
                    AppRow(app: app,
                           onToggle: { manager.toggleSelect(app.id) },
                           onOpen: { manager.openApp(app) },
                           onReveal: { manager.revealInFinder(app) })
                    Divider().background(Color.white.opacity(0.04))
                }
            }
        }
        .glassCard(cornerRadius: 16)
    }
}

// MARK: - App row
struct AppRow: View {
    let app: InstalledApp
    let onToggle: () -> Void
    let onOpen: () -> Void
    let onReveal: () -> Void
    @EnvironmentObject var loc: Localization

    @State private var isHovered = false

    private var lastUsedText: String {
        guard let d = app.lastUsed else { return "—" }
        let days = Calendar.current.dateComponents([.day], from: d, to: Date()).day ?? 0
        if days == 0 { return loc.t("apps.today") }
        if days < 7  { return "\(days)d atrás" }
        if days < 30 { return "\(days / 7)sem atrás" }
        return "\(days / 30)m atrás"
    }

    private var sizeColor: Color {
        if app.size > 1_073_741_824 { return Color(hex: "FF4D5E") }
        if app.size > 500_000_000   { return Color(hex: "FFB830") }
        return .white
    }

    var body: some View {
        HStack(spacing: 0) {
            // Checkbox
            Image(systemName: app.isSelected ? "checkmark.circle.fill" : "circle")
                .font(.system(size: 16))
                .foregroundColor(app.isSelected ? Color(hex: "34C87A") : .textSecondary)
                .frame(width: 32)
                .onTapGesture { onToggle() }

            // App icon + name
            HStack(spacing: 10) {
                Image(nsImage: app.icon)
                    .resizable()
                    .interpolation(.high)
                    .frame(width: 36, height: 36)
                    .shadow(color: .black.opacity(0.3), radius: 4)
                VStack(alignment: .leading, spacing: 1) {
                    Text(app.name)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.white)
                        .lineLimit(1)
                    if let bid = app.bundleID {
                        Text(bid)
                            .font(.system(size: 9))
                            .foregroundColor(.textSecondary)
                            .lineLimit(1)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // Version
            Text(app.version ?? "—")
                .font(.system(size: 11))
                .foregroundColor(.textSecondary)
                .frame(width: 90, alignment: .leading)

            // Last used
            Text(lastUsedText)
                .font(.system(size: 11))
                .foregroundColor(.textSecondary)
                .frame(width: 110, alignment: .leading)

            // Size
            Text(SystemMonitor.formatInt64(app.size))
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundColor(sizeColor)
                .frame(width: 90, alignment: .trailing)

            // Actions
            HStack(spacing: 8) {
                Button(action: onOpen) {
                    Image(systemName: "play.fill")
                        .font(.system(size: 10))
                        .foregroundColor(.textSecondary)
                }
                .buttonStyle(.plain)
                .help(loc.t("common.open"))

                Button(action: onReveal) {
                    Image(systemName: "folder.fill")
                        .font(.system(size: 10))
                        .foregroundColor(.textSecondary)
                }
                .buttonStyle(.plain)
                .help(loc.t("apps.openInFinder"))
            }
            .frame(width: 60)
            .opacity(isHovered ? 1 : 0)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 10)
        .background(app.isSelected
            ? Color(hex: "34C87A").opacity(0.06)
            : isHovered ? Color.white.opacity(0.025) : Color.clear)
        .contentShape(Rectangle())
        .onHover { isHovered = $0 }
        .animation(.easeInOut(duration: 0.1), value: isHovered)
    }
}
