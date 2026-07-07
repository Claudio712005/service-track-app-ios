import SwiftUI

/// Número-herói + rótulo + ícone (spec §14 STMetricTile) — faixa de KPIs do
/// dashboard. Não é gráfico: um valor único pede stat tile, não plot.
public struct STMetricTile: View {
    let valor: String
    let rotulo: String
    let icone: String
    let cor: Color

    public init(valor: String, rotulo: String, icone: String, cor: Color = DSColor.brandPrimary) {
        self.valor = valor
        self.rotulo = rotulo
        self.icone = icone
        self.cor = cor
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: DSSpacing.sm) {
            ZStack {
                RoundedRectangle(cornerRadius: DSRadius.sm)
                    .fill(cor.opacity(0.12))
                    .frame(width: 34, height: 34)
                Image(systemName: icone)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(cor)
            }
            .accessibilityHidden(true)

            // Valor em tinta de texto, nunca na cor da série (dataviz: text wears text tokens).
            Text(valor)
                .font(DSFont.display)
                .foregroundStyle(DSColor.textPrimary)
                .contentTransition(.numericText())
                .lineLimit(1)
                .minimumScaleFactor(0.6)

            Text(rotulo)
                .font(DSFont.footnote)
                .foregroundStyle(DSColor.textSecondary)
        }
        .padding(DSSpacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(DSColor.bgSurface, in: .rect(cornerRadius: DSRadius.md))
        .overlay(
            RoundedRectangle(cornerRadius: DSRadius.md)
                .strokeBorder(DSColor.borderSubtle, lineWidth: 1)
        )
        .dsShadow(.e1)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(rotulo): \(valor)")
    }
}
