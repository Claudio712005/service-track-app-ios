import SwiftUI

/// Banner sutil de estado (spec §14 STBanner) — uso principal: leitura offline
/// "mostrando dados salvos" (spec §11.3).
public struct STBanner: View {
    public enum Estilo {
        case offline
        case aviso

        var cor: Color {
            switch self {
            case .offline: DSColor.textSecondary
            case .aviso: DSColor.warning
            }
        }

        var icone: String {
            switch self {
            case .offline: "wifi.slash"
            case .aviso: "exclamationmark.triangle.fill"
            }
        }
    }

    let texto: String
    let estilo: Estilo

    public init(_ texto: String, estilo: Estilo = .offline) {
        self.texto = texto
        self.estilo = estilo
    }

    public var body: some View {
        HStack(spacing: DSSpacing.sm) {
            Image(systemName: estilo.icone)
                .font(DSFont.caption)
            Text(texto)
                .font(DSFont.footnote)
        }
        .foregroundStyle(estilo.cor)
        .padding(.horizontal, DSSpacing.md)
        .padding(.vertical, DSSpacing.sm)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(estilo.cor.opacity(0.10), in: .rect(cornerRadius: DSRadius.sm))
        .accessibilityElement(children: .combine)
    }
}
