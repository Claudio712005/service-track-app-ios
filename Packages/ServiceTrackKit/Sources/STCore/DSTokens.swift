import SwiftUI
import STDomain

// Tokens do Design System (spec §13) — únicos valores de cor/espaço/raio
// permitidos na UI (checklist §22.2: sem cores/spacings mágicos).

extension Color {
    init(hex: UInt32) {
        self.init(.sRGB,
                  red: Double((hex >> 16) & 0xFF) / 255,
                  green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255)
    }

    /// Cor dinâmica light/dark (spec §13.2 — tokens semânticos, não literais).
    init(light: UInt32, dark: UInt32) {
        #if canImport(UIKit)
        self.init(uiColor: UIColor { trait in
            trait.userInterfaceStyle == .dark ? UIColor(Color(hex: dark)) : UIColor(Color(hex: light))
        })
        #elseif canImport(AppKit)
        self.init(nsColor: NSColor(name: nil) { appearance in
            let isDark = appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
            return NSColor(Color(hex: isDark ? dark : light))
        })
        #else
        self.init(hex: light)
        #endif
    }
}

public enum DSColor {
    // brand
    public static let brandPrimary = Color(hex: 0x2F6BFF)
    public static let brandPrimaryStrong = Color(hex: 0x1B4DDB)
    public static let onPrimary = Color(hex: 0xFFFFFF)
    public static let accentSpark = Color(hex: 0x00D3A7)

    // backgrounds
    public static let bgCanvas = Color(light: 0xF6F7FB, dark: 0x0B0D12)
    public static let bgSurface = Color(light: 0xFFFFFF, dark: 0x14171F)
    public static let bgSurfaceElevated = Color(light: 0xFFFFFF, dark: 0x1B1F2A)
    public static let scrim = Color.black.opacity(0.45)

    // text
    public static let textPrimary = Color(light: 0x0B0D12, dark: 0xF4F6FB)
    public static let textSecondary = Color(light: 0x5B6270, dark: 0xA6ADBB)
    public static let textTertiary = Color(light: 0x8A909C, dark: 0x6E7686)
    public static let borderSubtle = Color(light: 0xE7E9F0, dark: 0x232838)

    // feedback
    public static let success = Color(hex: 0x16A36B)
    public static let warning = Color(hex: 0xE4A11B)
    public static let danger = Color(hex: 0xE5484D)
    public static let info = Color(hex: 0x2F6BFF)

    /// Paleta de status da OS — redefinida pela identidade, substitui os hex do backend (§13.2).
    public static func status(_ status: StatusOrdemServico) -> Color {
        switch status {
        case .recebida: Color(hex: 0x6C7BFF)
        case .emDiagnostico: Color(hex: 0xE4A11B)
        case .aguardandoAprovacao: Color(hex: 0x00B4D8)
        case .emExecucao: Color(hex: 0x16A36B)
        case .finalizada: Color(hex: 0x2F6BFF)
        case .entregue: Color(hex: 0x7A8194)
        case .cancelada: Color(hex: 0xE5484D)
        case .desconhecido: Color(light: 0x8A909C, dark: 0x6E7686)
        }
    }

    /// Par `corSuave` — fundo a 12% (§13.2).
    public static func statusSuave(_ status: StatusOrdemServico) -> Color {
        Self.status(status).opacity(0.12)
    }
}

/// Ícone SF Symbol semântico por status (§13.6) — status nunca comunicado só por cor (§16).
public extension StatusOrdemServico {
    var iconeSistema: String {
        switch self {
        case .recebida: "tray.and.arrow.down.fill"
        case .emDiagnostico: "stethoscope"
        case .aguardandoAprovacao: "exclamationmark.bubble.fill"
        case .emExecucao: "wrench.and.screwdriver.fill"
        case .finalizada: "checkmark.seal.fill"
        case .entregue: "car.fill"
        case .cancelada: "xmark.circle.fill"
        case .desconhecido: "questionmark.circle"
        }
    }
}

/// Escala tipográfica Dynamic Type-ready (§13.3) — `relativeTo` garante escala até AX5.
public enum DSFont {
    public static let display = Font.system(size: 34, weight: .bold, design: .rounded)
    public static let title1 = Font.system(size: 28, weight: .bold)
    public static let title2 = Font.system(size: 22, weight: .semibold)
    public static let title3 = Font.system(size: 18, weight: .semibold)
    public static let headline = Font.system(size: 17, weight: .semibold)
    public static let body = Font.system(size: 17, weight: .regular)
    public static let callout = Font.system(size: 16, weight: .regular)
    public static let subhead = Font.system(size: 15, weight: .medium)
    public static let footnote = Font.system(size: 13, weight: .regular)
    public static let caption = Font.system(size: 12, weight: .medium)
    /// Valores monetários: tabular figures para alinhamento (§13.3).
    public static let mono = Font.system(size: 15, weight: .medium).monospacedDigit()
    public static let monoDestaque = Font.system(size: 22, weight: .bold).monospacedDigit()
}

/// Escala 4pt (§13.4).
public enum DSSpacing {
    public static let xxs: CGFloat = 2
    public static let xs: CGFloat = 4
    public static let sm: CGFloat = 8
    public static let md: CGFloat = 12
    public static let lg: CGFloat = 16
    public static let xl: CGFloat = 20
    public static let xxl: CGFloat = 24
    public static let x3l: CGFloat = 32
    public static let x4l: CGFloat = 40
    public static let x5l: CGFloat = 56
    /// Margem de tela padrão (§13.4).
    public static let margemTela: CGFloat = 20
    /// Alvo mínimo de toque (§13.4/§16).
    public static let alvoMinimo: CGFloat = 44
}

public enum DSRadius {
    public static let sm: CGFloat = 10
    public static let md: CGFloat = 16
    public static let lg: CGFloat = 22
    public static let pill: CGFloat = 999
}

/// Elevações e1–e3 (§13.5).
public struct DSShadow {
    public let y: CGFloat
    public let blur: CGFloat
    public let alpha: Double

    public static let e1 = DSShadow(y: 2, blur: 8, alpha: 0.06)
    public static let e2 = DSShadow(y: 8, blur: 24, alpha: 0.12)
    public static let e3 = DSShadow(y: 16, blur: 40, alpha: 0.18)
}

public extension View {
    func dsShadow(_ sombra: DSShadow) -> some View {
        shadow(color: .black.opacity(sombra.alpha), radius: sombra.blur / 2, x: 0, y: sombra.y)
    }
}

/// Curvas de movimento (§13.7). Componentes respeitam Reduce Motion (§16).
public enum DSMotion {
    public static let transicao = Animation.spring(response: 0.4, dampingFraction: 0.85)
    public static let toque = Animation.easeOut(duration: 0.2)
    public static let sucesso = Animation.spring(response: 0.5, dampingFraction: 0.65)
}
