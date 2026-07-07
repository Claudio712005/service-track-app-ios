import SwiftUI
import STCore
import STDomain

/// Detalhe do veículo (spec §15.9): hero, dados, histórico de OS (RF08),
/// ações Editar/Remover/Nova OS (esta bloqueada por C4).
struct VeiculoDetalheView: View {
    @Bindable var store: VeiculoDetalheStore
    let aoEditar: () -> Void
    @State private var confirmandoRemocao = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DSSpacing.xl) {
                VeiculoImagem(url: store.estado.veiculo.urlImagem, altura: 200)

                cabecalho
                dados
                historico

                if let erro = store.estado.erro {
                    Text(erro)
                        .font(DSFont.footnote)
                        .foregroundStyle(DSColor.danger)
                }

                acoes
            }
            .padding(DSSpacing.margemTela)
        }
        .background(DSColor.bgCanvas)
        .navigationTitle("\(store.estado.veiculo.marca) \(store.estado.veiculo.modelo)")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .onAppear { store.send(.aparecer) }
        .confirmationDialog("Remover veículo?", isPresented: $confirmandoRemocao, titleVisibility: .visible) {
            Button("Remover \(store.estado.veiculo.modelo)", role: .destructive) {
                store.send(.remover)
            }
            Button("Manter", role: .cancel) {}
        } message: {
            Text("O veículo sai da sua garagem. O histórico de serviços é preservado pela oficina.")
        }
    }

    private var cabecalho: some View {
        VStack(alignment: .leading, spacing: DSSpacing.sm) {
            Text("\(store.estado.veiculo.marca) \(store.estado.veiculo.modelo)")
                .font(DSFont.title1)
                .foregroundStyle(DSColor.textPrimary)
            HStack(spacing: DSSpacing.sm) {
                chip(store.estado.veiculo.placa)
                chip(String(store.estado.veiculo.ano))
                if let fipe = store.estado.veiculo.codigoFipe {
                    chip("FIPE \(fipe)")
                }
            }
        }
    }

    private func chip(_ texto: String) -> some View {
        Text(texto)
            .font(DSFont.caption)
            .foregroundStyle(DSColor.textSecondary)
            .padding(.horizontal, DSSpacing.sm)
            .padding(.vertical, DSSpacing.xs)
            .background(DSColor.bgSurface, in: .capsule)
            .overlay(Capsule().strokeBorder(DSColor.borderSubtle, lineWidth: 1))
    }

    private var dados: some View {
        STCard {
            VStack(spacing: DSSpacing.md) {
                linha("Marca", store.estado.veiculo.marca)
                Divider()
                linha("Modelo", store.estado.veiculo.modelo)
                Divider()
                linha("Ano", String(store.estado.veiculo.ano))
                Divider()
                linha("Placa", store.estado.veiculo.placa)
                if let fipe = store.estado.veiculo.codigoFipe {
                    Divider()
                    linha("Código FIPE", fipe)
                }
            }
        }
    }

    private func linha(_ titulo: String, _ valor: String) -> some View {
        HStack {
            Text(titulo)
                .font(DSFont.subhead)
                .foregroundStyle(DSColor.textSecondary)
            Spacer()
            Text(valor)
                .font(DSFont.body)
                .foregroundStyle(DSColor.textPrimary)
        }
    }

    @ViewBuilder
    private var historico: some View {
        VStack(alignment: .leading, spacing: DSSpacing.sm) {
            Text("Histórico de serviços")
                .font(DSFont.title3)
                .foregroundStyle(DSColor.textPrimary)

            if store.estado.carregandoHistorico {
                STSkeleton(altura: 72, raio: DSRadius.md)
            } else if store.estado.historico.isEmpty {
                STCard {
                    Text("Nenhuma ordem de serviço para este veículo ainda.")
                        .font(DSFont.callout)
                        .foregroundStyle(DSColor.textSecondary)
                }
            } else {
                STCard {
                    VStack(spacing: DSSpacing.md) {
                        ForEach(Array(store.estado.historico.enumerated()), id: \.element.id) { indice, os in
                            if indice > 0 { Divider() }
                            HStack(spacing: DSSpacing.md) {
                                VStack(alignment: .leading, spacing: DSSpacing.xxs) {
                                    Text(os.motivo)
                                        .font(DSFont.subhead)
                                        .foregroundStyle(DSColor.textPrimary)
                                        .lineLimit(1)
                                }
                                Spacer()
                                STStatusBadge(os.status, tamanho: .sm)
                            }
                        }
                    }
                }
            }
        }
    }

    private var acoes: some View {
        VStack(spacing: DSSpacing.md) {
            // C4 (ADR-iOS-002): abertura de OS pelo cliente bloqueada até o
            // contrato aceitar mecanicoId opcional. Botão presente e desabilitado
            // com explicação — não simular fluxo inexistente.
            VStack(spacing: DSSpacing.xs) {
                STPrimaryButton("Nova ordem de serviço") {}
                    .disabled(true)
                Text("Abertura pelo app em breve — em alinhamento com a oficina.")
                    .font(DSFont.caption)
                    .foregroundStyle(DSColor.textTertiary)
            }

            STSecondaryButton("Editar veículo", acao: aoEditar)
            STDestructiveButton("Remover da garagem", carregando: store.estado.removendo) {
                confirmandoRemocao = true
            }
        }
    }
}
