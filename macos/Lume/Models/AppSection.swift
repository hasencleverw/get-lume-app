import SwiftUI

enum AppSection: String, CaseIterable, Identifiable {
    case dashboard   = "Smart"
    case memory      = "Memory"
    case disk        = "Disk"
    case largeFiles  = "Space"
    case protection  = "Protection"
    case apps        = "Applications"
    case performance = "Performance"

    var id: String { rawValue }

    var label: String { rawValue }

    var icon: String {
        switch self {
        case .dashboard:   return "sparkles"
        case .memory:      return "memorychip.fill"
        case .disk:        return "externaldrive.fill"
        case .largeFiles:  return "circle.grid.cross.fill"
        case .protection:  return "shield.lefthalf.filled"
        case .apps:        return "square.stack.3d.up.fill"
        case .performance: return "bolt.fill"
        }
    }

    var gradientColors: [Color] {
        switch self {
        case .dashboard:   return [Color(hex: "8B6BF8"), Color(hex: "5B3FD8")]
        case .memory:      return [Color(hex: "4D8FFF"), Color(hex: "2D5FD0")]
        case .disk:        return [Color(hex: "FF8C38"), Color(hex: "D85C10")]
        case .largeFiles:  return [Color(hex: "00C9A7"), Color(hex: "00957A")]
        case .protection:  return [Color(hex: "FF4D5E"), Color(hex: "CC2035")]
        case .apps:        return [Color(hex: "34C87A"), Color(hex: "1A9A55")]
        case .performance: return [Color(hex: "FFB830"), Color(hex: "D08A0A")]
        }
    }

    var accentColor: Color { gradientColors[0] }

    var gradient: LinearGradient {
        LinearGradient(colors: gradientColors, startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    var pageTitle: String {
        switch self {
        case .dashboard:   return "Smart Scan"
        case .memory:      return "Memory Cleaner"
        case .disk:        return "Disk Cleaner"
        case .largeFiles:  return "Space Lens"
        case .protection:  return "Protection"
        case .apps:        return "Applications"
        case .performance: return "Performance"
        }
    }

    var pageSubtitle: String {
        switch self {
        case .dashboard:   return "Diagnóstico completo do seu Mac"
        case .memory:      return "Libere RAM presa por processos inativos"
        case .disk:        return "Remove caches, logs e arquivos desnecessários"
        case .largeFiles:  return "Arquivos grandes por disco"
        case .protection:  return "Detecta e remove malware, adware e apps indesejados"
        case .apps:        return "Gerencie e desinstale aplicativos"
        case .performance: return "Otimizações e tarefas de manutenção do sistema"
        }
    }

    var localizationKey: String {
        switch self {
        case .dashboard:   return "dashboard"
        case .memory:      return "memory"
        case .disk:        return "disk"
        case .largeFiles:  return "spaceLens"
        case .protection:  return "protection"
        case .apps:        return "apps"
        case .performance: return "performance"
        }
    }
}

// MARK: - Design tokens
extension Color {
    static let appBg1       = Color(hex: "0B0B1E")
    static let appBg2       = Color(hex: "070714")
    static let sidebarBg    = Color(hex: "0F0F22")
    static let cardBg       = Color(white: 1.0, opacity: 0.05)
    static let cardBorder   = Color(white: 1.0, opacity: 0.09)
    static let cardHover    = Color(white: 1.0, opacity: 0.08)

    static let appAccent    = Color(hex: "8B6BF8")
    static let appSuccess   = Color(hex: "00C9A7")
    static let appWarning   = Color(hex: "F59E0B")
    static let appDanger    = Color(hex: "FF4D5E")
    static let textPrimary  = Color(white: 0.96)
    static let textSecondary = Color(white: 0.45)

    init(hex: String) {
        let h = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var n: UInt64 = 0
        Scanner(string: h).scanHexInt64(&n)
        let r = Double((n >> 16) & 0xFF) / 255
        let g = Double((n >>  8) & 0xFF) / 255
        let b = Double( n        & 0xFF) / 255
        self.init(red: r, green: g, blue: b)
    }
}

// MARK: - App background
struct AppBackground: View {
    var body: some View {
        ZStack {
            Color.appBg1.ignoresSafeArea()
            Circle()
                .fill(Color(hex: "5B3FD8").opacity(0.14))
                .blur(radius: 100)
                .frame(width: 500, height: 500)
                .offset(x: -180, y: -160)
            Circle()
                .fill(Color(hex: "2D5FD0").opacity(0.09))
                .blur(radius: 120)
                .frame(width: 400, height: 400)
                .offset(x: 320, y: 80)
        }
        .ignoresSafeArea()
    }
}

// MARK: - Glass card
struct GlassCard: ViewModifier {
    var cornerRadius: CGFloat = 16

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(Color.cardBg)
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .strokeBorder(Color.cardBorder, lineWidth: 1)
            )
    }
}

extension View {
    func glassCard(cornerRadius: CGFloat = 16) -> some View {
        modifier(GlassCard(cornerRadius: cornerRadius))
    }
}

// ProgressBar and LineChart are defined in CircularGauge.swift
