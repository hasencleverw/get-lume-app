import SwiftUI

struct DonationPopupView: View {
    @ObservedObject var manager: DonationManager
    @EnvironmentObject var loc: Localization
    @State private var showKeyField = false
    @State private var keyInput = ""
    @State private var keyError = false
    @State private var keySuccess = false
    @State private var copiedPIX = false
    @State private var copiedPayPal = false

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider().background(Color.white.opacity(0.08))
            ScrollView(showsIndicators: false) {
                VStack(spacing: 18) {
                    description
                    donateOptions
                    if showKeyField {
                        keySection
                    }
                }
                .padding(24)
            }
            Divider().background(Color.white.opacity(0.08))
            footerButtons
        }
        .frame(width: 460)
        .background(Color(hex: "0D0520"))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16)
            .strokeBorder(Color.white.opacity(0.1), lineWidth: 1))
        .shadow(color: .black.opacity(0.6), radius: 40)
    }

    // MARK: - Header
    private var header: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(LinearGradient(
                        colors: [Color(hex: "FF6B9D"), Color(hex: "C84B72")],
                        startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 38, height: 38)
                Image(systemName: "heart.fill")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.white)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(loc.t("donate.popup.title"))
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(.white)
                Text(loc.t("donate.popup.tagline"))
                    .font(.system(size: 11))
                    .foregroundColor(.textSecondary)
            }
            Spacer()
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 16)
    }

    // MARK: - Description
    private var description: some View {
        Text(loc.t("donate.popup.intro"))
            .font(.system(size: 12))
            .foregroundColor(.textSecondary)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Donate options
    private var donateOptions: some View {
        VStack(spacing: 10) {
            donateRow(
                icon: "qrcode",
                title: "PIX",
                badge: loc.t("settings.donate.pix"),
                badgeColor: Color(hex: "00C9A7"),
                value: "95c1adaf-d8ee-4498-b7af-3a810ae30b59",
                copied: $copiedPIX,
                color: Color(hex: "00C9A7")
            )
            donateRow(
                icon: "creditcard.fill",
                title: "PayPal",
                badge: loc.t("settings.donate.paypal"),
                badgeColor: Color(hex: "4D8FFF"),
                value: "hasen.borges@gmail.com",
                copied: $copiedPayPal,
                color: Color(hex: "4D8FFF")
            )
        }
    }

    private func donateRow(icon: String, title: String, badge: String, badgeColor: Color,
                            value: String, copied: Binding<Bool>, color: Color) -> some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(color.opacity(0.15))
                    .frame(width: 32, height: 32)
                Image(systemName: icon)
                    .font(.system(size: 13))
                    .foregroundColor(color)
            }
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(title)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.white)
                    Text(badge)
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundColor(badgeColor)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(badgeColor.opacity(0.15))
                        .clipShape(Capsule())
                }
                Text(value)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(Color(white: 0.75))
            }
            Spacer()
            Button(action: { copy(value, flag: copied) }) {
                HStack(spacing: 4) {
                    Image(systemName: copied.wrappedValue ? "checkmark" : "doc.on.doc")
                        .font(.system(size: 10))
                    Text(copied.wrappedValue ? loc.t("donate.popup.copied") : loc.t("donate.popup.copy"))
                        .font(.system(size: 11, weight: .semibold))
                }
                .foregroundColor(copied.wrappedValue ? .appSuccess : color)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background((copied.wrappedValue ? Color.appSuccess : color).opacity(0.12))
                .clipShape(Capsule())
            }
            .buttonStyle(.plain)
            .animation(.easeInOut(duration: 0.15), value: copied.wrappedValue)
        }
        .padding(12)
        .glassCard(cornerRadius: 12)
    }

    // MARK: - Key section
    private var keySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(loc.t("donate.popup.keyTitle"))
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(Color(white: 0.7))

            Text(loc.t("donate.popup.keyIntro"))
                .font(.system(size: 11))
                .foregroundColor(.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            if keySuccess {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.appSuccess)
                    Text(loc.t("donate.popup.keySuccess") + " ❤️")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.appSuccess)
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.appSuccess.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 10))
            } else {
                HStack(spacing: 8) {
                    TextField(loc.t("donate.popup.placeholder"), text: $keyInput)
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
                        .onChange(of: keyInput) { _ in keyError = false }

                    Button(action: submitKey) {
                        Text(loc.t("donate.popup.validate"))
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.black)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 9)
                            .background(Color.appAccent)
                            .clipShape(RoundedRectangle(cornerRadius: 9))
                    }
                    .buttonStyle(.plain)
                    .disabled(keyInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }

                if keyError {
                    HStack(spacing: 6) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 11))
                        Text(loc.t("donate.popup.invalid"))
                            .font(.system(size: 11))
                    }
                    .foregroundColor(Color(hex: "FF4D5E"))
                }
            }
        }
        .padding(14)
        .glassCard(cornerRadius: 12)
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }

    // MARK: - Footer
    private var footerButtons: some View {
        HStack(spacing: 10) {
            Button(action: {
                withAnimation(.spring(response: 0.35)) { showKeyField.toggle() }
            }) {
                HStack(spacing: 5) {
                    Image(systemName: showKeyField ? "chevron.up" : "key.fill")
                        .font(.system(size: 11))
                    Text(showKeyField ? loc.t("donate.popup.hide") : loc.t("donate.popup.alreadyDonated"))
                        .font(.system(size: 12, weight: .semibold))
                }
                .foregroundColor(.textSecondary)
                .padding(.horizontal, 14)
                .padding(.vertical, 9)
                .background(Color.white.opacity(0.05))
                .clipShape(RoundedRectangle(cornerRadius: 9))
            }
            .buttonStyle(.plain)

            Spacer()

            Button(loc.t("donate.popup.remindLater")) {
                manager.dismissRemindLater()
            }
            .font(.system(size: 12, weight: .semibold))
            .foregroundColor(.textSecondary)
            .buttonStyle(.plain)
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
            .background(Color.white.opacity(0.05))
            .clipShape(RoundedRectangle(cornerRadius: 9))

            Button(action: openDonateEmail) {
                HStack(spacing: 6) {
                    Image(systemName: "heart.fill")
                        .font(.system(size: 11))
                    Text(loc.t("donate.popup.support"))
                        .font(.system(size: 12, weight: .bold))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 18)
                .padding(.vertical, 9)
                .background(LinearGradient(
                    colors: [Color(hex: "FF6B9D"), Color(hex: "C84B72")],
                    startPoint: .leading, endPoint: .trailing))
                .clipShape(RoundedRectangle(cornerRadius: 9))
                .shadow(color: Color(hex: "FF6B9D").opacity(0.4), radius: 6)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 14)
    }

    // MARK: - Actions
    private func submitKey() {
        if manager.applyKey(keyInput) {
            withAnimation { keySuccess = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                manager.showPopup = false
            }
        } else {
            withAnimation { keyError = true }
        }
    }

    private func copy(_ text: String, flag: Binding<Bool>) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        flag.wrappedValue = true
        Task {
            try? await Task.sleep(nanoseconds: 2_500_000_000)
            await MainActor.run { flag.wrappedValue = false }
        }
    }

    private func openDonateEmail() {
        let subject = "Comprovante de Doação - Lume for Mac"
        let body = "Olá Hasen, estou enviando meu comprovante de doação para o Lume for Mac."
        let encoded = "mailto:hasen.borges@gmail.com?subject=\(subject.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")&body=\(body.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")"
        if let url = URL(string: encoded) { NSWorkspace.shared.open(url) }
    }
}
