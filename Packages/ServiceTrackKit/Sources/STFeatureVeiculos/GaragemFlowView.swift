import SwiftUI
import STCore
import STDomain

/// Coordinator da aba Garagem (spec §10.2: um router por aba): lista → detalhe
/// → formulário, com rotas tipadas.
public struct GaragemFlowView: View {
    public struct Dependencias {
        let veiculos: VeiculoRepository
        let ordens: OrdemServicoRepository
        let proprietarioId: UUID

        public init(veiculos: VeiculoRepository, ordens: OrdemServicoRepository,
                    proprietarioId: UUID) {
            self.veiculos = veiculos
            self.ordens = ordens
            self.proprietarioId = proprietarioId
        }
    }

    enum Rota: Hashable {
        case detalhe(Veiculo)
        case novo
        case editar(Veiculo)
    }

    let deps: Dependencias
    @State private var caminho: [Rota] = []
    @State private var store: GaragemStore

    public init(deps: Dependencias) {
        self.deps = deps
        self._store = State(initialValue: GaragemStore(veiculos: deps.veiculos))
    }

    public var body: some View {
        NavigationStack(path: $caminho) {
            GaragemView(store: store) { rota in
                caminho.append(rota)
            }
            .navigationDestination(for: Rota.self) { rota in
                switch rota {
                case .detalhe(let veiculo):
                    VeiculoDetalheView(
                        store: VeiculoDetalheStore(veiculo: veiculo, veiculos: deps.veiculos,
                                                   ordens: deps.ordens) {
                            caminho = []
                        },
                        aoEditar: { caminho.append(.editar(veiculo)) })
                case .novo:
                    VeiculoFormView(store: VeiculoFormStore(modo: .criar, veiculos: deps.veiculos,
                                                            proprietarioId: deps.proprietarioId) { _ in
                        caminho = []
                    })
                case .editar(let veiculo):
                    VeiculoFormView(store: VeiculoFormStore(modo: .editar(veiculo),
                                                            veiculos: deps.veiculos,
                                                            proprietarioId: deps.proprietarioId) { _ in
                        caminho = []
                    })
                }
            }
        }
    }
}

// MARK: - Lista (spec §15.8)

struct GaragemView: View {
    @Bindable var store: GaragemStore
    let navegar: (GaragemFlowView.Rota) -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DSSpacing.xl) {
                switch store.fase {
                case .carregando:
                    grade {
                        ForEach(0..<4, id: \.self) { _ in
                            STSkeleton(altura: 190, raio: DSRadius.md)
                        }
                    }
                    .dsEntradaSuave()
                case .erro(let erro):
                    STErrorState(mensagem: erro.mensagemPadrao) {
                        store.send(.recarregar)
                    }
                    .dsEntradaSuave()
                case .vazio:
                    STEmptyState(icone: "car",
                                 titulo: "Garagem vazia",
                                 subtitulo: "Cadastre seu veículo para abrir ordens de serviço e acompanhar o histórico.",
                                 tituloCTA: "Adicionar veículo") {
                        navegar(.novo)
                    }
                    .dsEntradaSuave()
                case .conteudo(let veiculos):
                    grade {
                        ForEach(veiculos) { veiculo in
                            Button {
                                navegar(.detalhe(veiculo))
                            } label: {
                                STVehicleCardView(veiculo: veiculo)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .dsEntradaSuave()
                }
            }
            .padding(DSSpacing.margemTela)
            .dsAnimaFase(store.fase)
        }
        .safeAreaInset(edge: .bottom) {
            if case .conteudo = store.fase {
                HStack {
                    Spacer()
                    botaoFlutuante
                }
                .padding(.horizontal, DSSpacing.margemTela)
                .padding(.bottom, DSSpacing.sm)
            }
        }
        .background(DSColor.bgCanvas)
        .navigationTitle("Garagem")
        .onAppear { store.send(.aparecer) }
        .refreshable { await store.carregar(silencioso: true) }
    }

    private func grade(@ViewBuilder conteudo: () -> some View) -> some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: DSSpacing.md),
                            GridItem(.flexible())], spacing: DSSpacing.md, content: conteudo)
    }

    private var botaoFlutuante: some View {
        Button {
            navegar(.novo)
        } label: {
            Label("Adicionar veículo", systemImage: "plus")
                .font(DSFont.headline)
                .foregroundStyle(DSColor.onPrimary)
                .padding(.horizontal, DSSpacing.xl)
                .frame(minHeight: 52)
                .background(DSColor.brandPrimary, in: .capsule)
                .dsShadow(.e2)
        }
        .padding(DSSpacing.margemTela)
        .accessibilityLabel("Adicionar veículo")
    }
}

/// Card do veículo (spec §14 STVehicleCard): imagem, placa em chip, marca/modelo/ano.
struct STVehicleCardView: View {
    let veiculo: Veiculo

    var body: some View {
        VStack(alignment: .leading, spacing: DSSpacing.sm) {
            VeiculoImagem(url: veiculo.urlImagem, altura: 96)

            VStack(alignment: .leading, spacing: DSSpacing.xxs) {
                Text("\(veiculo.marca) \(veiculo.modelo)")
                    .font(DSFont.subhead)
                    .foregroundStyle(DSColor.textPrimary)
                    .lineLimit(1)
                Text(String(veiculo.ano))
                    .font(DSFont.caption)
                    .foregroundStyle(DSColor.textSecondary)
            }

            Text(veiculo.placa)
                .font(DSFont.caption)
                .foregroundStyle(DSColor.textSecondary)
                .padding(.horizontal, DSSpacing.sm)
                .padding(.vertical, DSSpacing.xxs)
                .background(DSColor.borderSubtle.opacity(0.5), in: .capsule)
        }
        .padding(DSSpacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(DSColor.bgSurface, in: .rect(cornerRadius: DSRadius.md))
        .overlay(
            RoundedRectangle(cornerRadius: DSRadius.md)
                .strokeBorder(DSColor.borderSubtle, lineWidth: 1)
        )
        .dsShadow(.e1)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(veiculo.marca) \(veiculo.modelo), \(veiculo.ano), placa \(veiculo.placa)")
    }
}

struct VeiculoImagem: View {
    let url: URL?
    var altura: CGFloat = 120

    var body: some View {
        AsyncImage(url: url) { fase in
            switch fase {
            case .success(let imagem):
                imagem.resizable().aspectRatio(contentMode: .fill)
            default:
                ZStack {
                    DSColor.brandPrimary.opacity(0.08)
                    Image(systemName: "car.fill")
                        .font(.system(size: altura / 3))
                        .foregroundStyle(DSColor.brandPrimary.opacity(0.5))
                }
            }
        }
        .frame(height: altura)
        .frame(maxWidth: .infinity)
        .clipShape(RoundedRectangle(cornerRadius: DSRadius.sm))
        .accessibilityHidden(true)
    }
}
