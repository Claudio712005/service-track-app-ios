import SwiftUI
import Charts
import STCore

// Gráficos do dashboard (Swift Charts, spec §1.4/§13.1 "dados como protagonistas").
// Regras aplicadas (skill dataviz): série única = um matiz da marca (validado
// light/dark), sem legenda (o título nomeia a série), marcas finas com ponta
// arredondada ancorada na baseline, grade recessiva, texto sempre em tokens de
// texto, rótulos diretos seletivos, tooltip por seleção no gráfico temporal.

private let formatoBRLCompacto = FloatingPointFormatStyle<Double>.Currency
    .currency(code: "BRL")
    .precision(.fractionLength(0))

/// Magnitude por categoria (poucos itens) → barras horizontais, um matiz.
struct GastoPorVeiculoChart: View {
    let pontos: [DashboardStore.PontoGasto]

    var body: some View {
        Chart(pontos) { ponto in
            BarMark(
                x: .value("Gasto", ponto.valor),
                y: .value("Veículo", ponto.rotulo),
                height: .fixed(18)
            )
            .foregroundStyle(DSColor.brandPrimary)
            .clipShape(RoundedRectangle(cornerRadius: 4))
            // Rótulo direto: poucos itens, valor na ponta — dispensa eixo denso.
            .annotation(position: .trailing, spacing: DSSpacing.xs) {
                Text(ponto.valor, format: formatoBRLCompacto)
                    .font(DSFont.caption)
                    .foregroundStyle(DSColor.textSecondary)
            }
            .accessibilityLabel(ponto.rotulo)
            .accessibilityValue(Text(ponto.valor, format: .currency(code: "BRL")))
        }
        .chartXAxis(.hidden)
        .chartYAxis {
            AxisMarks(preset: .aligned) { _ in
                AxisValueLabel()
                    .font(DSFont.caption)
                    .foregroundStyle(DSColor.textSecondary)
            }
        }
        .chartXScale(domain: 0...(pontos.map(\.valor).max() ?? 1) * 1.25)
        .frame(height: CGFloat(pontos.count) * 44 + 8)
    }
}

/// Mudança no tempo → barras mensais, um matiz, tooltip por toque.
struct GastosMensaisChart: View {
    let pontos: [DashboardStore.PontoMensal]
    @State private var mesSelecionado: Date?

    var body: some View {
        Chart(pontos) { ponto in
            BarMark(
                x: .value("Mês", ponto.mes, unit: .month),
                y: .value("Gasto", ponto.valor),
                width: .ratio(0.55)
            )
            .foregroundStyle(DSColor.brandPrimary.opacity(destaque(ponto) ? 1 : 0.45))
            .clipShape(UnevenRoundedRectangle(topLeadingRadius: 4, topTrailingRadius: 4))
            .accessibilityLabel(Text(ponto.mes, format: .dateTime.month(.wide).year()))
            .accessibilityValue(Text(ponto.valor, format: .currency(code: "BRL")))

            if let selecionado = pontoSelecionado, selecionado.id == ponto.id {
                RuleMark(x: .value("Mês", selecionado.mes, unit: .month))
                    .foregroundStyle(DSColor.borderSubtle)
                    .zIndex(-1)
                    .annotation(position: .top, overflowResolution:
                            .init(x: .fit(to: .chart), y: .disabled)) {
                        tooltip(selecionado)
                    }
            }
        }
        .chartXSelection(value: $mesSelecionado)
        .chartXAxis {
            AxisMarks(values: .stride(by: .month)) { _ in
                AxisValueLabel(format: .dateTime.month(.abbreviated))
                    .font(DSFont.caption)
                    .foregroundStyle(DSColor.textTertiary)
            }
        }
        .chartYAxis {
            AxisMarks(position: .trailing, values: .automatic(desiredCount: 3)) { valor in
                AxisGridLine().foregroundStyle(DSColor.borderSubtle.opacity(0.6))
                if let quantia = valor.as(Double.self) {
                    AxisValueLabel {
                        Text(quantia, format: formatoBRLCompacto)
                            .font(DSFont.caption)
                            .foregroundStyle(DSColor.textTertiary)
                    }
                }
            }
        }
        .frame(height: 180)
    }

    private var pontoSelecionado: DashboardStore.PontoMensal? {
        guard let mesSelecionado else { return nil }
        let calendario = Calendar.current
        return pontos.first {
            calendario.isDate($0.mes, equalTo: mesSelecionado, toGranularity: .month)
        }
    }

    private func destaque(_ ponto: DashboardStore.PontoMensal) -> Bool {
        pontoSelecionado == nil || pontoSelecionado?.id == ponto.id
    }

    private func tooltip(_ ponto: DashboardStore.PontoMensal) -> some View {
        VStack(alignment: .leading, spacing: DSSpacing.xxs) {
            Text(ponto.mes, format: .dateTime.month(.wide).year())
                .font(DSFont.caption)
                .foregroundStyle(DSColor.textSecondary)
            Text(ponto.valor, format: .currency(code: "BRL"))
                .font(DSFont.mono)
                .foregroundStyle(DSColor.textPrimary)
        }
        .padding(DSSpacing.sm)
        .background(DSColor.bgSurfaceElevated, in: .rect(cornerRadius: DSRadius.sm))
        .overlay(
            RoundedRectangle(cornerRadius: DSRadius.sm)
                .strokeBorder(DSColor.borderSubtle, lineWidth: 1)
        )
        .dsShadow(.e2)
    }
}
