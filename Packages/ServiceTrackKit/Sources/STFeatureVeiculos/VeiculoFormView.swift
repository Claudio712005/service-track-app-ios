import SwiftUI
import STCore
import STDomain

/// Formulário de veículo em passos (spec §15.10): identificação → galeria de
/// sugestões de imagem (Unsplash) → ano+placa.
struct VeiculoFormView: View {
    @Bindable var store: VeiculoFormStore

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DSSpacing.xxl) {
                barraProgresso
                etapaAtual

                if let erro = store.estado.erroGeral {
                    Text(erro)
                        .font(DSFont.footnote)
                        .foregroundStyle(DSColor.danger)
                }

                botoes
            }
            .padding(DSSpacing.margemTela)
            .animation(DSMotion.transicao, value: store.estado.etapa)
        }
        .background(DSColor.bgCanvas)
        .navigationTitle(titulo)
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }

    private var titulo: String {
        if case .editar = store.modo { return "Editar veículo" }
        return "Novo veículo"
    }

    private var barraProgresso: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(DSColor.borderSubtle)
                Capsule()
                    .fill(DSColor.brandPrimary)
                    .frame(width: geo.size.width * store.estado.progresso)
                    .animation(DSMotion.transicao, value: store.estado.progresso)
            }
        }
        .frame(height: 6)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Passo \(store.estado.etapa.rawValue + 1) de 3")
    }

    @ViewBuilder
    private var etapaAtual: some View {
        switch store.estado.etapa {
        case .identificacao:
            VStack(spacing: DSSpacing.lg) {
                subtitulo("Qual é o veículo?")
                STTextField("Marca", texto: campo(.marca), erro: store.estado.erros[.marca])
                STTextField("Modelo", texto: campo(.modelo), erro: store.estado.erros[.modelo])
            }
        case .imagem:
            galeria
        case .dados:
            VStack(spacing: DSSpacing.lg) {
                subtitulo("Para finalizar")
                #if os(iOS)
                STTextField("Ano", texto: campo(.ano), erro: store.estado.erros[.ano], teclado: .numberPad)
                #else
                STTextField("Ano", texto: campo(.ano), erro: store.estado.erros[.ano])
                #endif
                STTextField("Placa", texto: campo(.placa), mascara: .placa,
                            erro: store.estado.erros[.placa])
                Text("Dados como o código FIPE são completados automaticamente pela oficina.")
                    .font(DSFont.footnote)
                    .foregroundStyle(DSColor.textTertiary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    /// Galeria selecionável de sugestões (Unsplash). Best-effort: falha vira
    /// banner e o fluxo segue sem imagem (RN-11).
    private var galeria: some View {
        VStack(alignment: .leading, spacing: DSSpacing.lg) {
            subtitulo("Escolha uma imagem (opcional)")

            if store.estado.buscandoSugestoes {
                LazyVGrid(columns: colunas, spacing: DSSpacing.md) {
                    ForEach(0..<4, id: \.self) { _ in
                        STSkeleton(altura: 100, raio: DSRadius.sm)
                    }
                }
            } else if store.estado.sugestoesFalharam {
                HStack(spacing: DSSpacing.sm) {
                    Image(systemName: "photo.badge.exclamationmark")
                    Text("Sugestões indisponíveis agora. Você pode continuar sem imagem.")
                        .font(DSFont.footnote)
                }
                .foregroundStyle(DSColor.textSecondary)
                .padding(DSSpacing.md)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(DSColor.warning.opacity(0.10), in: .rect(cornerRadius: DSRadius.sm))
            } else if store.estado.sugestoes.isEmpty {
                Text("Nenhuma sugestão para \(store.estado.marca) \(store.estado.modelo).")
                    .font(DSFont.footnote)
                    .foregroundStyle(DSColor.textSecondary)
            } else {
                LazyVGrid(columns: colunas, spacing: DSSpacing.md) {
                    ForEach(store.estado.sugestoes, id: \.self) { url in
                        Button {
                            store.send(.imagemEscolhida(store.estado.imagemSelecionada == url ? nil : url))
                        } label: {
                            VeiculoImagem(url: url, altura: 100)
                                .overlay(
                                    RoundedRectangle(cornerRadius: DSRadius.sm)
                                        .strokeBorder(store.estado.imagemSelecionada == url
                                                      ? DSColor.brandPrimary : .clear, lineWidth: 3)
                                )
                                .overlay(alignment: .topTrailing) {
                                    if store.estado.imagemSelecionada == url {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundStyle(DSColor.brandPrimary)
                                            .background(DSColor.onPrimary, in: .circle)
                                            .padding(DSSpacing.xs)
                                    }
                                }
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Sugestão de imagem")
                        .accessibilityAddTraits(store.estado.imagemSelecionada == url ? .isSelected : [])
                    }
                }
            }
        }
    }

    private var colunas: [GridItem] {
        [GridItem(.flexible(), spacing: DSSpacing.md), GridItem(.flexible())]
    }

    private func subtitulo(_ texto: String) -> some View {
        Text(texto)
            .font(DSFont.title3)
            .foregroundStyle(DSColor.textPrimary)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var botoes: some View {
        VStack(spacing: DSSpacing.md) {
            STPrimaryButton(tituloAvancar, carregando: store.estado.salvando) {
                store.send(.avancar)
            }
            if store.estado.etapa != .identificacao {
                STSecondaryButton("Voltar") {
                    store.send(.voltar)
                }
            }
        }
    }

    private var tituloAvancar: String {
        store.estado.etapa == .dados ? "Salvar veículo" : "Continuar"
    }

    private func campo(_ campo: VeiculoFormStore.Campo) -> Binding<String> {
        Binding(get: {
            switch campo {
            case .marca: store.estado.marca
            case .modelo: store.estado.modelo
            case .ano: store.estado.ano
            case .placa: store.estado.placa
            }
        }, set: { store.send(.campoAlterado(campo, $0)) })
    }
}
