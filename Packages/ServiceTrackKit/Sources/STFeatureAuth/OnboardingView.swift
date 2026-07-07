import SwiftUI
import STCore

/// Carrossel de valor do primeiro acesso (spec §15.1). A flag "visto" é do
/// dispositivo (ADR-iOS-004); quem persiste é o chamador via `aoConcluir`.
public struct OnboardingView: View {
    public enum Saida {
        case criarConta
        case entrar
    }

    let aoConcluir: (Saida) -> Void
    @State private var pagina = 0

    public init(aoConcluir: @escaping (Saida) -> Void) {
        self.aoConcluir = aoConcluir
    }

    private struct Pagina {
        let icone: String
        let titulo: String
        let subtitulo: String
    }

    private let paginas: [Pagina] = [
        Pagina(icone: "gauge.with.needle",
               titulo: "Acompanhe em tempo real",
               subtitulo: "Veja cada etapa do serviço do seu veículo, do diagnóstico à entrega."),
        Pagina(icone: "hand.tap",
               titulo: "Aprove com um toque",
               subtitulo: "Recebeu o orçamento? Aprove ou recuse direto do app, sem telefonema."),
        Pagina(icone: "car.2",
               titulo: "Sua garagem organizada",
               subtitulo: "Todos os seus veículos, históricos e gastos em um só lugar."),
    ]

    public var body: some View {
        VStack(spacing: DSSpacing.xxl) {
            carrossel

            indicador

            VStack(spacing: DSSpacing.md) {
                STPrimaryButton("Criar conta") {
                    aoConcluir(.criarConta)
                }
                STSecondaryButton("Já tenho conta") {
                    aoConcluir(.entrar)
                }
            }
            .padding(.horizontal, DSSpacing.margemTela)
            .padding(.bottom, DSSpacing.x3l)
        }
        .background(DSColor.bgCanvas)
    }

    private var carrossel: some View {
        TabView(selection: $pagina) {
            ForEach(paginas.indices, id: \.self) { indice in
                let p = paginas[indice]
                VStack(spacing: DSSpacing.xxl) {
                    ZStack {
                        Circle()
                            .fill(DSColor.brandPrimary.opacity(0.10))
                            .frame(width: 180, height: 180)
                        Circle()
                            .fill(DSColor.brandPrimary.opacity(0.16))
                            .frame(width: 132, height: 132)
                        Image(systemName: p.icone)
                            .font(.system(size: 56, weight: .medium))
                            .foregroundStyle(DSColor.brandPrimary)
                    }
                    .accessibilityHidden(true)

                    VStack(spacing: DSSpacing.md) {
                        Text(p.titulo)
                            .font(DSFont.title1)
                            .foregroundStyle(DSColor.textPrimary)
                            .multilineTextAlignment(.center)
                        Text(p.subtitulo)
                            .font(DSFont.body)
                            .foregroundStyle(DSColor.textSecondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.horizontal, DSSpacing.x3l)
                }
                .tag(indice)
            }
        }
        #if os(iOS)
        .tabViewStyle(.page(indexDisplayMode: .never))
        #endif
    }

    private var indicador: some View {
        HStack(spacing: DSSpacing.sm) {
            ForEach(paginas.indices, id: \.self) { indice in
                Capsule()
                    .fill(indice == pagina ? DSColor.brandPrimary : DSColor.borderSubtle)
                    .frame(width: indice == pagina ? 24 : 8, height: 8)
                    .animation(DSMotion.transicao, value: pagina)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Página \(pagina + 1) de \(paginas.count)")
        .accessibilityAdjustableAction { direcao in
            switch direcao {
            case .increment: pagina = min(pagina + 1, paginas.count - 1)
            case .decrement: pagina = max(pagina - 1, 0)
            @unknown default: break
            }
        }
    }
}

#Preview {
    OnboardingView { _ in }
}
