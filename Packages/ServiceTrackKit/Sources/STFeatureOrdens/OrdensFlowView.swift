import SwiftUI
import STCore
import STDomain

/// Coordinator da aba Ordens: lista → detalhe (rotas tipadas, spec §10.2).
public struct OrdensFlowView: View {
    public struct Dependencias {
        let ordens: OrdemServicoRepository
        let catalogo: CatalogoRepository

        public init(ordens: OrdemServicoRepository, catalogo: CatalogoRepository) {
            self.ordens = ordens
            self.catalogo = catalogo
        }
    }

    enum Rota: Hashable {
        case detalhe(UUID)
    }

    let deps: Dependencias
    @State private var caminho: [Rota] = []
    @State private var store: OrdensStore

    public init(deps: Dependencias) {
        self.deps = deps
        self._store = State(initialValue: OrdensStore(repo: deps.ordens))
        #if DEBUG
        // Atalho de desenvolvimento: ST_OS_DETALHE=<uuid> abre direto o detalhe.
        if let id = ProcessInfo.processInfo.environment["ST_OS_DETALHE"].flatMap(UUID.init(uuidString:)) {
            self._caminho = State(initialValue: [.detalhe(id)])
        }
        #endif
    }

    public var body: some View {
        NavigationStack(path: $caminho) {
            OrdensListaView(store: store) { osId in
                caminho.append(.detalhe(osId))
            }
            .navigationDestination(for: Rota.self) { rota in
                switch rota {
                case .detalhe(let osId):
                    OrdemDetalheView(store: OrdemDetalheStore(osId: osId, ordens: deps.ordens,
                                                              catalogo: deps.catalogo))
                }
            }
        }
    }
}

// MARK: - Lista (spec §15.4)

struct OrdensListaView: View {
    @Bindable var store: OrdensStore
    let abrirDetalhe: (UUID) -> Void

    var body: some View {
        VStack(spacing: 0) {
            STSegmentedFilter(opcoes: OrdensStore.Filtro.allCases,
                              selecao: Binding(get: { store.estado.filtro },
                                               set: { store.send(.filtroAlterado($0)) }),
                              rotulo: \.rotulo)

            ScrollView {
                LazyVStack(spacing: DSSpacing.md) {
                    switch store.estado.fase {
                    case .carregando:
                        ForEach(0..<5, id: \.self) { _ in
                            STSkeleton(altura: 92, raio: DSRadius.md)
                        }
                        .dsEntradaSuave()
                    case .erro(let erro):
                        STErrorState(mensagem: erro.mensagemPadrao) {
                            store.send(.recarregar)
                        }
                        .dsEntradaSuave()
                    case .vazio:
                        STEmptyState(icone: "wrench.and.screwdriver",
                                     titulo: tituloVazio,
                                     subtitulo: "Quando a oficina registrar uma ordem para você, ela aparece aqui.")
                            .dsEntradaSuave()
                    case .conteudo:
                        conteudo
                            .dsEntradaSuave()
                    }
                }
                .padding(DSSpacing.margemTela)
                .dsAnimaFase(store.estado.fase)
            }
        }
        .background(DSColor.bgCanvas)
        .navigationTitle("Ordens")
        .onAppear { store.send(.aparecer) }
        .refreshable { await store.recarregarAguardando() }
    }

    private var tituloVazio: String {
        store.estado.filtro == .todas ? "Nenhuma ordem ainda" : "Nada por aqui"
    }

    @ViewBuilder
    private var conteudo: some View {
        ForEach(store.estado.visiveis) { os in
            Button {
                abrirDetalhe(os.id)
            } label: {
                STOrderRowView(os: os)
            }
            .buttonStyle(.plain)
            .onAppear {
                if os.id == store.estado.visiveis.last?.id {
                    store.send(.chegouAoFim)
                }
            }
        }

        if store.estado.carregandoMais {
            STSkeleton(altura: 92, raio: DSRadius.md)
        }
    }
}

/// Item de OS (spec §14 STOrderRow): motivo, badge de status, chevron.
struct STOrderRowView: View {
    let os: ResumoOrdemServico

    var body: some View {
        HStack(spacing: DSSpacing.md) {
            ZStack {
                RoundedRectangle(cornerRadius: DSRadius.sm)
                    .fill(DSColor.statusSuave(os.status))
                    .frame(width: 44, height: 44)
                Image(systemName: os.status.iconeSistema)
                    .foregroundStyle(DSColor.status(os.status))
            }
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: DSSpacing.xs) {
                Text(os.motivo)
                    .font(DSFont.subhead)
                    .foregroundStyle(DSColor.textPrimary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                STStatusBadge(os.status, tamanho: .sm)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(DSFont.caption)
                .foregroundStyle(DSColor.textTertiary)
        }
        .padding(DSSpacing.lg)
        .background(DSColor.bgSurface, in: .rect(cornerRadius: DSRadius.md))
        .overlay(
            RoundedRectangle(cornerRadius: DSRadius.md)
                .strokeBorder(DSColor.borderSubtle, lineWidth: 1)
        )
        .dsShadow(.e1)
        .contentShape(.rect)
        .accessibilityElement(children: .combine)
    }
}
