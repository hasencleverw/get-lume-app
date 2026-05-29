import SwiftUI

struct MetricCard<Content: View>: View {
    let title: String
    let icon: String
    let iconGradient: [Color]
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 9) {
                ZStack {
                    RoundedRectangle(cornerRadius: 9)
                        .fill(LinearGradient(colors: iconGradient,
                                             startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(width: 30, height: 30)
                        .shadow(color: iconGradient[0].opacity(0.4), radius: 6)
                    Image(systemName: icon)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.white)
                }
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white)
            }
            content()
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard()
    }
}

struct StatRow: View {
    let label: String
    let value: String
    var valueColor: Color = .white

    var body: some View {
        HStack {
            Text(label)
                .font(.system(size: 12))
                .foregroundColor(.textSecondary)
            Spacer()
            Text(value)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(valueColor)
        }
    }
}

struct SectionHeader: View {
    let title: String
    var action: String? = nil
    var onAction: (() -> Void)? = nil

    var body: some View {
        HStack {
            Text(title)
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundColor(.white)
            Spacer()
            if let label = action {
                Button(action: { onAction?() }) {
                    Text(label)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.appAccent)
                }
                .buttonStyle(.plain)
            }
        }
    }
}

struct PageHeader: View {
    let title: String
    let subtitle: String
    let section: AppSection
    var trailing: AnyView? = nil
    @EnvironmentObject var loc: Localization

    private var displayTitle: String {
        let key = "page.\(section.localizationKey).title"
        let translated = loc.t(key)
        return translated == key ? title : translated
    }
    private var displaySubtitle: String {
        let key = "page.\(section.localizationKey).subtitle"
        let translated = loc.t(key)
        return translated == key ? subtitle : translated
    }

    var body: some View {
        HStack(alignment: .center) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 13)
                        .fill(section.gradient)
                        .frame(width: 46, height: 46)
                        .shadow(color: section.accentColor.opacity(0.45), radius: 10)
                    Image(systemName: section.icon)
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.white)
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text(displayTitle)
                        .font(.system(size: 26, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    Text(displaySubtitle)
                        .font(.system(size: 13))
                        .foregroundColor(.textSecondary)
                }
            }
            Spacer()
            trailing
        }
    }
}
