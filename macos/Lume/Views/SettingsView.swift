import SwiftUI
import ServiceManagement
import AppKit

struct SettingsView: View {
    @AppStorage("lume.launchAtLogin") private var launchAtLogin = false
    @AppStorage("lume.hideFromDock") private var hideFromDock = false
    @AppStorage("lume.language") private var language = "pt"
    @State private var selectedTab: SettingsTab = .general
    @State private var copyFeedback: String? = nil
    @State private var donationKey = ""
    @State private var keyError = false
    @State private var keySuccess = false
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var donationManager: DonationManager
    @EnvironmentObject private var loc: Localization
    @EnvironmentObject private var permissions: PermissionsManager
    @EnvironmentObject private var updater: UpdaterService
    @State private var pendingLanguage: String = ""
    @State private var languageApplied = false

    enum SettingsTab: String, CaseIterable {
        case general, language, updates, donate

        var icon: String {
            switch self {
            case .general:  return "gearshape.fill"
            case .language: return "globe"
            case .updates:  return "arrow.triangle.2.circlepath"
            case .donate:   return "heart.fill"
            }
        }

        var localizationKey: String {
            switch self {
            case .general:  return "settings.general"
            case .language: return "settings.language"
            case .updates:  return "settings.updates"
            case .donate:   return "settings.donate"
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            toolbar
            tabBar
            Divider().background(Color.white.opacity(0.08))
            content
        }
        .background(Color(hex: "0F0F22"))
        .frame(width: 540, height: 580)
        .onAppear {
            // Reconcile @AppStorage with the actual system state — the user may
            // have toggled Launch at Login in System Settings since last open.
            launchAtLogin = currentLaunchAtLoginState()
        }
    }

    // MARK: - Toolbar
    private var toolbar: some View {
        HStack {
            Text(loc.t("settings.title"))
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(.white)
            Spacer()
            Button(action: { dismiss() }) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 18))
                    .foregroundColor(.textSecondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 24)
        .padding(.top, 22)
        .padding(.bottom, 14)
    }

    // MARK: - Tab bar
    private var tabBar: some View {
        HStack(spacing: 4) {
            ForEach(SettingsTab.allCases, id: \.self) { tab in
                tabBtn(tab)
            }
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 12)
    }

    private func tabBtn(_ tab: SettingsTab) -> some View {
        let isActive = selectedTab == tab
        return Button(action: { selectedTab = tab }) {
            HStack(spacing: 6) {
                Image(systemName: tab.icon)
                    .font(.system(size: 11))
                Text(loc.t(tab.localizationKey))
                    .font(.system(size: 12, weight: .medium))
            }
            .foregroundColor(isActive ? .white : .textSecondary)
            .padding(.horizontal, 14)
            .padding(.vertical, 7)
            .background(isActive ? Color.appAccent.opacity(0.2) : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8)
                .strokeBorder(isActive ? Color.appAccent.opacity(0.4) : Color.clear))
        }
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: 0.13), value: isActive)
    }

    // MARK: - Content
    @ViewBuilder
    private var content: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 20) {
                switch selectedTab {
                case .general:  generalSection
                case .language: languageSection
                case .updates:  updatesSection
                case .donate:   donateSection
                }
            }
            .padding(24)
        }
    }

    // MARK: - General
    private var generalSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionHeader(loc.t("settings.behavior"))

            toggleRow(
                icon: "power",
                title: loc.t("settings.launchAtLogin"),
                subtitle: loc.t("settings.launchAtLogin.sub")
            ) {
                Binding(
                    get: { launchAtLogin },
                    set: { val in launchAtLogin = val; applyLaunchAtLogin(val) }
                )
            }

            toggleRow(
                icon: "menubar.dock.rectangle",
                title: loc.t("settings.hideFromDock"),
                subtitle: loc.t("settings.hideFromDock.sub")
            ) {
                Binding(
                    get: { hideFromDock },
                    set: { val in hideFromDock = val; applyDockVisibility(val) }
                )
            }

            infoBox(icon: "info.circle", color: Color(hex: "4D8FFF"),
                    text: loc.t("settings.general.info"))

            permissionsBlock
        }
    }

    private var permissionsBlock: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                sectionHeader(loc.t("settings.permissions"))
                Spacer()
                Button(action: { permissions.refresh() }) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 11))
                        .foregroundColor(.textSecondary)
                }
                .buttonStyle(.plain)
            }

            // Single row for Full Disk Access. It covers every TCC-protected
            // folder so we don't drown the user in per-folder rows that will
            // always mirror this one anyway.
            permissionRow(
                granted: permissions.fullDiskAccess,
                title: loc.t("settings.perm.fda"),
                subtitle: loc.t("settings.perm.fda.full"),
                isCritical: true
            )

            Text(loc.t("settings.perm.fda.coverage"))
                .font(.system(size: 11))
                .foregroundColor(.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            if !permissions.fullDiskAccess {
                Button(action: { permissions.openFullDiskAccessSettings() }) {
                    HStack(spacing: 6) {
                        Image(systemName: "lock.shield.fill")
                            .font(.system(size: 11))
                        Text(loc.t("settings.perm.openPrivacy"))
                            .font(.system(size: 12, weight: .semibold))
                    }
                    .foregroundColor(.black)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(Color(hex: "FFB830"))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)
            }

            // Manual override: lets the user tell the app to trust them when
            // macOS' own detection is fooled by the cdhash-mismatch problem
            // typical of ad-hoc-signed builds.
            HStack(alignment: .top, spacing: 10) {
                Toggle("", isOn: Binding(
                    get: { permissions.manualOverride },
                    set: { permissions.setManualOverride($0) }
                ))
                .toggleStyle(.switch)
                .labelsHidden()
                VStack(alignment: .leading, spacing: 2) {
                    Text(loc.t("settings.perm.manualOverride"))
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.white)
                    Text(loc.t("settings.perm.manualOverride.sub"))
                        .font(.system(size: 11))
                        .foregroundColor(.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(.top, 4)

            maintenanceModeBlock
                .padding(.top, 8)
        }
        .padding(.top, 4)
    }

    @ViewBuilder
    private var maintenanceModeBlock: some View {
        let exec = PrivilegedExecutor.shared
        Divider().background(Color.white.opacity(0.06))
        HStack(alignment: .top, spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill((exec.isUnlocked ? Color.appSuccess : Color(hex: "8B6BF8")).opacity(0.15))
                    .frame(width: 30, height: 30)
                Image(systemName: exec.isUnlocked ? "lock.open.fill" : "lock.fill")
                    .font(.system(size: 13))
                    .foregroundColor(exec.isUnlocked ? .appSuccess : Color(hex: "8B6BF8"))
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(loc.t("settings.maint.title"))
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white)
                Text(exec.isUnlocked
                     ? loc.t("settings.maint.unlocked")
                     : loc.t("settings.maint.locked"))
                    .font(.system(size: 11))
                    .foregroundColor(.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
            if exec.isUnlocked {
                Button(loc.t("settings.maint.lock")) { exec.lock() }
                    .buttonStyle(.plain)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(Color(hex: "FF4D5E"))
                    .padding(.horizontal, 10).padding(.vertical, 5)
                    .background(Color(hex: "FF4D5E").opacity(0.15))
                    .clipShape(Capsule())
            } else {
                Button(loc.t("settings.maint.unlock")) { _ = exec.authorize() }
                    .buttonStyle(.plain)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.appAccent)
                    .padding(.horizontal, 10).padding(.vertical, 5)
                    .background(Color.appAccent.opacity(0.15))
                    .clipShape(Capsule())
            }
        }
        .padding(.vertical, 4)
    }

    private func permissionRow(granted: Bool, title: String, subtitle: String, isCritical: Bool) -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill((granted ? Color.appSuccess : (isCritical ? Color(hex: "FFB830") : Color.textSecondary)).opacity(0.15))
                    .frame(width: 30, height: 30)
                Image(systemName: granted ? "checkmark" : "xmark")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(granted ? .appSuccess : (isCritical ? Color(hex: "FFB830") : .textSecondary))
            }
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.white)
                Text(subtitle)
                    .font(.system(size: 10))
                    .foregroundColor(.textSecondary)
            }
            Spacer()
            Text(granted ? loc.t("settings.perm.granted") : loc.t("settings.perm.pending"))
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(granted ? .appSuccess : (isCritical ? Color(hex: "FFB830") : .textSecondary))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.white.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 9))
    }

    // MARK: - Language
    private var languageSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionHeader(loc.t("settings.language.title"))

            Text(loc.t("settings.language.note"))
                .font(.system(size: 11))
                .foregroundColor(.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            VStack(spacing: 6) {
                ForEach(Localization.availableLanguages, id: \.code) { lang in
                    langRow(code: lang.code, name: lang.name, flag: lang.flag)
                }
            }

            // Apply button
            let chosen = pendingLanguage.isEmpty ? loc.current : pendingLanguage
            let canApply = chosen != loc.current

            HStack(spacing: 10) {
                if languageApplied {
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.appSuccess)
                        Text(loc.t("settings.language.applied"))
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.appSuccess)
                    }
                    .transition(.opacity)
                }
                Spacer()
                Button(action: applyLanguage) {
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark")
                            .font(.system(size: 11, weight: .bold))
                        Text(loc.t("settings.language.apply"))
                            .font(.system(size: 12, weight: .semibold))
                    }
                    .foregroundColor(canApply ? .black : Color(white: 0.45))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 9)
                    .background(canApply ? Color.appAccent : Color.white.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 9))
                }
                .buttonStyle(.plain)
                .disabled(!canApply)
            }
            .animation(.easeInOut(duration: 0.2), value: languageApplied)
        }
    }

    private func langRow(code: String, name: String, flag: String) -> some View {
        let chosen = pendingLanguage.isEmpty ? loc.current : pendingLanguage
        let isSelected = chosen == code
        return Button(action: {
            pendingLanguage = code
            languageApplied = false
        }) {
            HStack(spacing: 12) {
                Text(flag)
                    .font(.system(size: 20))
                Text(name)
                    .font(.system(size: 13, weight: isSelected ? .semibold : .regular))
                    .foregroundColor(isSelected ? .white : .textSecondary)
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundColor(.appAccent)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(isSelected ? Color.appAccent.opacity(0.1) : Color.white.opacity(0.04))
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10)
                .strokeBorder(isSelected ? Color.appAccent.opacity(0.3) : Color.clear))
        }
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: 0.1), value: isSelected)
    }

    private func applyLanguage() {
        let chosen = pendingLanguage.isEmpty ? loc.current : pendingLanguage
        loc.apply(chosen)
        language = chosen
        withAnimation { languageApplied = true }
        Task {
            try? await Task.sleep(nanoseconds: 2_500_000_000)
            await MainActor.run { withAnimation { languageApplied = false } }
        }
    }

    // MARK: - Updates
    private var updatesSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionHeader(loc.t("settings.updates.header"))

            HStack(spacing: 16) {
                appLogoBadge
                    .frame(width: 52, height: 52)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Lume for Mac")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(.white)
                    Text("v\(updater.current)")
                        .font(.system(size: 12))
                        .foregroundColor(.textSecondary)
                    Text(loc.t("settings.updates.compat"))
                        .font(.system(size: 11))
                        .foregroundColor(.textSecondary)
                }
                Spacer()
                VStack(spacing: 6) {
                    Circle()
                        .fill(updater.available ? Color.appWarning : Color.appSuccess)
                        .frame(width: 10, height: 10)
                        .shadow(color: (updater.available ? Color.appWarning : Color.appSuccess).opacity(0.8), radius: 4)
                    Text(updater.available
                         ? "v\(updater.latest ?? "?")"
                         : loc.t("settings.updates.upToDate"))
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(updater.available ? Color.appWarning : Color.appSuccess)
                }
            }
            .padding(16)
            .glassCard()

            // "Get update" CTA appears only when a newer release exists.
            if updater.available {
                Button(action: { updater.openReleasePage() }) {
                    HStack(spacing: 8) {
                        Image(systemName: "arrow.down.circle.fill")
                            .font(.system(size: 14))
                        Text("Baixar v\(updater.latest ?? "")")
                            .font(.system(size: 13, weight: .semibold))
                    }
                    .foregroundColor(.black)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 11)
                    .frame(maxWidth: .infinity)
                    .background(Color.appWarning)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                .buttonStyle(.plain)
            }

            Button(action: { Task { await updater.checkNow() } }) {
                HStack(spacing: 8) {
                    if updater.checking {
                        ProgressView().scaleEffect(0.65).tint(.black)
                    } else {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .font(.system(size: 14))
                    }
                    Text(updater.checking
                         ? loc.t("common.checking")
                         : loc.t("settings.updates.check"))
                        .font(.system(size: 13, weight: .semibold))
                }
                .foregroundColor(.black)
                .padding(.horizontal, 20)
                .padding(.vertical, 11)
                .frame(maxWidth: .infinity)
                .background(LinearGradient(
                    colors: [Color.appAccent, Color(hex: "5B3FD8")],
                    startPoint: .leading, endPoint: .trailing))
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .shadow(color: Color.appAccent.opacity(0.4), radius: 8)
            }
            .buttonStyle(.plain)
            .disabled(updater.checking)

            // Last-check timestamp / error
            if let date = updater.lastCheckDate {
                Text(loc.current == "en"
                     ? "Last checked: \(formatRelative(date))"
                     : loc.current == "es"
                        ? "Última comprobación: \(formatRelative(date))"
                        : "Última verificação: \(formatRelative(date))")
                    .font(.system(size: 10))
                    .foregroundColor(.textSecondary)
            }
            if let err = updater.lastError {
                Text(err)
                    .font(.system(size: 10))
                    .foregroundColor(Color(hex: "FF4D5E"))
            }
        }
    }

    private func formatRelative(_ d: Date) -> String {
        let secs = -d.timeIntervalSinceNow
        if secs < 60 { return loc.current == "en" ? "just now" : "agora" }
        if secs < 3600 { return "\(Int(secs / 60)) min" }
        if secs < 86400 { return "\(Int(secs / 3600))h" }
        return "\(Int(secs / 86400))d"
    }

    // MARK: - Donate
    private var donateSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionHeader(loc.t("settings.donate.header"))

            Text(loc.t("settings.donate.intro"))
                .font(.system(size: 12))
                .foregroundColor(.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            donateCard(
                icon: "qrcode",
                title: "PIX",
                badge: loc.t("settings.donate.pix"),
                badgeColor: Color(hex: "00C9A7"),
                label: loc.t("settings.donate.keyRandom"),
                value: "95c1adaf-d8ee-4498-b7af-3a810ae30b59",
                color: Color(hex: "00C9A7")
            )

            donateCard(
                icon: "creditcard.fill",
                title: "PayPal",
                badge: loc.t("settings.donate.paypal"),
                badgeColor: Color(hex: "4D8FFF"),
                label: loc.t("settings.donate.keyEmail"),
                value: "hasen.borges@gmail.com",
                color: Color(hex: "4D8FFF")
            )

            if let feedback = copyFeedback {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.appSuccess)
                    Text(feedback)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.appSuccess)
                }
                .transition(.opacity.combined(with: .move(edge: .bottom)))
            }

            Text(loc.t("settings.donate.thanks") + " ❤️")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.textSecondary)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.top, 4)

            donationKeySection
        }
        .animation(.easeInOut(duration: 0.25), value: copyFeedback)
    }

    private var donationKeySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(loc.t("settings.donate.keyHeader"))

            if donationManager.hasDonated {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.seal.fill")
                        .foregroundColor(.appSuccess)
                        .font(.system(size: 16))
                    VStack(alignment: .leading, spacing: 2) {
                        Text(loc.t("settings.donate.confirmed"))
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.appSuccess)
                        Text(loc.t("settings.donate.confirmedSub"))
                            .font(.system(size: 11))
                            .foregroundColor(.textSecondary)
                    }
                }
                .padding(14)
                .glassCard(cornerRadius: 12)
            } else {
                Text(loc.t("settings.donate.keyIntro"))
                    .font(.system(size: 11))
                    .foregroundColor(.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                if keySuccess {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.appSuccess)
                        Text(loc.t("settings.donate.keySuccess"))
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.appSuccess)
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.appSuccess.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                } else {
                    HStack(spacing: 8) {
                        TextField(loc.t("settings.donate.placeholder"), text: $donationKey)
                            .textFieldStyle(.plain)
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundColor(.white)
                            .tint(Color.appAccent)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 9)
                            .background(Color.black.opacity(0.5))
                            .clipShape(RoundedRectangle(cornerRadius: 9))
                            .overlay(RoundedRectangle(cornerRadius: 9)
                                .strokeBorder(keyError ? Color(hex: "FF4D5E").opacity(0.6) : Color.white.opacity(0.15)))
                            .environment(\.colorScheme, .dark)
                            .onChange(of: donationKey) { _ in keyError = false }

                        Button(action: validateDonationKey) {
                            Text(loc.t("settings.donate.validate"))
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(.black)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 9)
                                .background(Color.appAccent)
                                .clipShape(RoundedRectangle(cornerRadius: 9))
                        }
                        .buttonStyle(.plain)
                        .disabled(donationKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }

                    if keyError {
                        HStack(spacing: 6) {
                            Image(systemName: "xmark.circle.fill").font(.system(size: 11))
                            Text(loc.t("settings.donate.invalid"))
                                .font(.system(size: 11))
                        }
                        .foregroundColor(Color(hex: "FF4D5E"))
                    }
                }
            }
        }
    }

    private func validateDonationKey() {
        if donationManager.applyKey(donationKey) {
            withAnimation { keySuccess = true }
        } else {
            withAnimation { keyError = true }
        }
    }

    private func donateCard(icon: String, title: String, badge: String, badgeColor: Color,
                             label: String, value: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(color.opacity(0.15))
                        .frame(width: 32, height: 32)
                    Image(systemName: icon)
                        .font(.system(size: 13))
                        .foregroundColor(color)
                }
                Text(title)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white)
                Text(badge)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(badgeColor)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(badgeColor.opacity(0.15))
                    .clipShape(Capsule())
                Spacer()
                Button(action: { copyKey(value) }) {
                    HStack(spacing: 4) {
                        Image(systemName: "doc.on.doc")
                            .font(.system(size: 11))
                        Text(loc.t("settings.donate.copy"))
                            .font(.system(size: 11, weight: .semibold))
                    }
                    .foregroundColor(color)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(color.opacity(0.12))
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
            HStack(spacing: 6) {
                Text(label + ":")
                    .font(.system(size: 11))
                    .foregroundColor(.textSecondary)
                Text(value)
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundColor(Color(white: 0.85))
                    .textSelection(.enabled)
                    .lineLimit(1)
            }
        }
        .padding(14)
        .glassCard(cornerRadius: 12)
    }

    // MARK: - App logo
    @ViewBuilder
    private var appLogoBadge: some View {
        if let img = loadAppIcon() {
            Image(nsImage: img)
                .resizable()
                .scaledToFit()
                .clipShape(RoundedRectangle(cornerRadius: 12))
        } else {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(LinearGradient(
                        colors: [Color(hex: "8B6BF8"), Color(hex: "4B2BB8")],
                        startPoint: .topLeading, endPoint: .bottomTrailing))
                LumeLogoMark(size: 30, color: .white)
            }
        }
    }

    private func loadAppIcon() -> NSImage? {
        let candidates = [
            Bundle.main.url(forResource: "Icone", withExtension: "png")?.path,
            Bundle.main.resourceURL?.appendingPathComponent("Icone.png").path,
        ].compactMap { $0 }
        for p in candidates where FileManager.default.fileExists(atPath: p) {
            if let img = NSImage(contentsOfFile: p) { return img }
        }
        return nil
    }

    // MARK: - Helpers

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 13, weight: .bold))
            .foregroundColor(Color(white: 0.75))
    }

    private func toggleRow(icon: String, title: String, subtitle: String,
                            binding: () -> Binding<Bool>) -> some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.appAccent.opacity(0.15))
                    .frame(width: 34, height: 34)
                Image(systemName: icon)
                    .font(.system(size: 14))
                    .foregroundColor(.appAccent)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white)
                Text(subtitle)
                    .font(.system(size: 11))
                    .foregroundColor(.textSecondary)
            }
            Spacer()
            Toggle("", isOn: binding())
                .toggleStyle(.switch)
                .labelsHidden()
        }
        .padding(14)
        .glassCard(cornerRadius: 12)
    }

    private func infoBox(icon: String, color: Color, text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundColor(color)
                .padding(.top, 1)
            Text(text)
                .font(.system(size: 11))
                .foregroundColor(.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 4)
    }

    private func copyKey(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        copyFeedback = loc.t("settings.donate.copied")
        Task {
            try? await Task.sleep(nanoseconds: 2_500_000_000)
            await MainActor.run { copyFeedback = nil }
        }
    }

    private func applyLaunchAtLogin(_ enabled: Bool) {
        // Try SMAppService first (works for Developer-ID-signed apps).
        // For ad-hoc-signed apps it usually fails silently with "Operation not
        // permitted" — fall back to System Events via osascript, which works
        // without entitlements as long as the user grants Automation access.
        let service = SMAppService.mainApp
        do {
            if enabled {
                if service.status != .enabled { try service.register() }
            } else {
                if service.status == .enabled { try service.unregister() }
            }
            // Verify the call actually took effect.
            let nowEnabled = (service.status == .enabled)
            if nowEnabled == enabled {
                launchAtLogin = nowEnabled
                return
            }
            // Fell through — service didn't reflect the change, try fallback.
            applyLaunchAtLoginViaSystemEvents(enabled)
        } catch {
            // SMAppService refused (typical for ad-hoc apps) — use the fallback.
            applyLaunchAtLoginViaSystemEvents(enabled)
        }
    }

    private func applyLaunchAtLoginViaSystemEvents(_ enabled: Bool) {
        let appPath = Bundle.main.bundlePath
        let appName = (Bundle.main.infoDictionary?["CFBundleName"] as? String) ?? "Lume"
        let script: String
        if enabled {
            script = """
            tell application "System Events"
                if not (exists login item "\(appName)") then
                    make login item at end with properties {path:"\(appPath)", hidden:false, name:"\(appName)"}
                end if
            end tell
            """
        } else {
            script = """
            tell application "System Events"
                if exists login item "\(appName)" then
                    delete login item "\(appName)"
                end if
            end tell
            """
        }
        var error: NSDictionary?
        NSAppleScript(source: script)?.executeAndReturnError(&error)
        if let err = error {
            print("LaunchAtLogin osascript error: \(err)")
            // Roll the toggle back so the UI matches reality.
            launchAtLogin = !enabled
        } else {
            launchAtLogin = enabled
        }
    }

    /// Checks both SMAppService and System Events for the current state, so the
    /// toggle reflects reality on Settings open (e.g. if the user removed Lume
    /// from Login Items manually in System Settings).
    private func currentLaunchAtLoginState() -> Bool {
        if SMAppService.mainApp.status == .enabled { return true }
        let appName = (Bundle.main.infoDictionary?["CFBundleName"] as? String) ?? "Lume"
        let script = """
        tell application "System Events"
            return (exists login item "\(appName)") as text
        end tell
        """
        var error: NSDictionary?
        let result = NSAppleScript(source: script)?.executeAndReturnError(&error)
        if error != nil { return false }
        return result?.stringValue == "true"
    }

    private func applyDockVisibility(_ hidden: Bool) {
        NSApp.setActivationPolicy(hidden ? .accessory : .regular)
        if !hidden {
            NSApp.activate(ignoringOtherApps: true)
        }
    }
}
