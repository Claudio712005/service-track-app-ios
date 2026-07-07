import SwiftUI
import STCore
import STDomain

/// Aba Avisos (spec §15.11): lista com filtro e contador → detalhe.
/// Deep-link para a OS relacionada fica para quando o contrato expuser o
/// `osId` na notificação (hoje `NotificacaoResponse` não o tem).
public struct NotificacoesFlowView: View {
    enum Rota: Hashable {
        case detalhe(Notificacao)
    }

    let repo: NotificacaoRepository
    @State private var caminho: [Rota] = []
    @State private var store: NotificacoesStore

    public init(repo: NotificacaoRepository) {
        self.repo = repo
        self._store = State(initialValue: NotificacoesStore(repo: repo))
    }

    public var body: some View {
        NavigationStack(path: $caminho) {
            NotificacoesListaView(store: store) { notificacao in
                store.send(.abrir(notificacao))
                caminho.append(.detalhe(notificacao))
            }
            .navigationDestination(for: Rota.self) { rota in
                switch rota {
                case .detalhe(let notificacao):
                    NotificacaoDetalheView(notificacao: notificacao)
                }
            }
        }
    }
}

// MARK: - Lista

struct NotificacoesListaView: View {
    @Bindable var store: NotificacoesStore
    let abrir: (Notificacao) -> Void

    var body: some View {
        VStack(spacing: 0) {
            cabecalhoContador

            STSegmentedFilter(opcoes: NotificacoesStore.Filtro.allCases,
                              selecao: Binding(get: { store.estado.filtro },
                                               set: { store.send(.filtroAlterado($0)) }),
                              rotulo: \.rotulo)

            ScrollView {
                LazyVStack(spacing: DSSpacing.md) {
                    switch store.estado.fase {
                    case .carregando:
                        ForEach(0..<5, id: \.self) { _ in
                            STSkeleton(altura: 84, raio: DSRadius.md)
                        }
                        .dsEntradaSuave()
                    case .erro(let erro):
                        STErrorState(mensagem: erro.mensagemPadrao) {
                            store.send(.recarregar)
                        }
                        .dsEntradaSuave()
                    case .vazio:
                        STEmptyState(icone: "bell.slash",
                                     titulo: tituloVazio,
                                     subtitulo: "Os avisos da oficina sobre suas ordens aparecem aqui.")
                            .dsEntradaSuave()
                    case .conteudo:
                        conteudo.dsEntradaSuave()
                    }
                }
                .padding(DSSpacing.margemTela)
                .dsAnimaFase(store.estado.fase)
            }
        }
        .background(DSColor.bgCanvas)
        .navigationTitle("Avisos")
        .toolbar {
            if store.estado.naoLidas > 0 {
                ToolbarItem(placement: .primaryAction) {
                    Button("Marcar todas") {
                        store.send(.marcarTodasComoLidas)
                    }
                    .font(DSFont.subhead)
                    .disabled(store.estado.marcandoTodas)
                }
            }
        }
        .onAppear { store.send(.aparecer) }
        .refreshable { await store.recarregarAguardando() }
    }

    private var tituloVazio: String {
        store.estado.filtro == .naoLidas ? "Tudo lido" : "Nenhum aviso ainda"
    }

    private var cabecalhoContador: some View {
        HStack {
            Text(store.estado.naoLidas > 0
                 ? "\(store.estado.naoLidas) não lida\(store.estado.naoLidas == 1 ? "" : "s")"
                 : "Você está em dia")
                .font(DSFont.footnote)
                .foregroundStyle(DSColor.textSecondary)
                .contentTransition(.numericText())
            Spacer()
            if let erro = store.estado.erroAcao {
                Text(erro)
                    .font(DSFont.caption)
                    .foregroundStyle(DSColor.danger)
                    .task {
                        try? await Task.sleep(for: .seconds(4))
                        store.send(.limparFeedback)
                    }
            }
        }
        .padding(.horizontal, DSSpacing.margemTela)
        .padding(.bottom, DSSpacing.xs)
        .animation(DSMotion.toque, value: store.estado.naoLidas)
    }

    @ViewBuilder
    private var conteudo: some View {
        ForEach(store.estado.notificacoes) { notificacao in
            Button {
                abrir(notificacao)
            } label: {
                STNotificationRowView(notificacao: notificacao)
            }
            .buttonStyle(.plain)
            .onAppear {
                if notificacao.id == store.estado.notificacoes.last?.id {
                    store.send(.chegouAoFim)
                }
            }
        }

        if store.estado.carregandoMais {
            STSkeleton(altura: 84, raio: DSRadius.md)
        }
    }
}

/// STNotificationRow (spec §14): indicador de não lida, título, assunto,
/// tempo relativo.
struct STNotificationRowView: View {
    let notificacao: Notificacao

    var body: some View {
        HStack(alignment: .top, spacing: DSSpacing.md) {
            Circle()
                .fill(notificacao.visualizada ? Color.clear : DSColor.brandPrimary)
                .frame(width: 10, height: 10)
                .padding(.top, 6)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: DSSpacing.xxs) {
                Text(notificacao.titulo)
                    .font(notificacao.visualizada ? DSFont.subhead : DSFont.headline)
                    .foregroundStyle(DSColor.textPrimary)
                    .lineLimit(1)
                Text(notificacao.assunto)
                    .font(DSFont.footnote)
                    .foregroundStyle(DSColor.textSecondary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                if let data = notificacao.dataCriacao {
                    Text(data.formatted(.relative(presentation: .named).locale(.ptBR)))
                        .font(DSFont.caption)
                        .foregroundStyle(DSColor.textTertiary)
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(DSFont.caption)
                .foregroundStyle(DSColor.textTertiary)
                .padding(.top, 6)
        }
        .padding(DSSpacing.lg)
        .background(DSColor.bgSurface, in: .rect(cornerRadius: DSRadius.md))
        .overlay(
            RoundedRectangle(cornerRadius: DSRadius.md)
                .strokeBorder(notificacao.visualizada
                              ? DSColor.borderSubtle
                              : DSColor.brandPrimary.opacity(0.35), lineWidth: 1)
        )
        .dsShadow(.e1)
        .contentShape(.rect)
        .accessibilityElement(children: .combine)
        .accessibilityValue(notificacao.visualizada ? "lida" : "não lida")
    }
}

// MARK: - Detalhe

struct NotificacaoDetalheView: View {
    let notificacao: Notificacao

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DSSpacing.xl) {
                VStack(alignment: .leading, spacing: DSSpacing.sm) {
                    Text(notificacao.titulo)
                        .font(DSFont.title2)
                        .foregroundStyle(DSColor.textPrimary)
                    if let data = notificacao.dataCriacao {
                        Text(data.formatted(.dateTime.weekday(.wide).day().month(.wide).hour().minute().locale(.ptBR)))
                            .font(DSFont.footnote)
                            .foregroundStyle(DSColor.textTertiary)
                    }
                }

                STCard {
                    VStack(alignment: .leading, spacing: DSSpacing.md) {
                        Text(notificacao.assunto)
                            .font(DSFont.headline)
                            .foregroundStyle(DSColor.textPrimary)
                        Text(notificacao.descricao)
                            .font(DSFont.body)
                            .foregroundStyle(DSColor.textSecondary)
                    }
                }

                Label("Enviada também por e-mail", systemImage: "envelope")
                    .font(DSFont.caption)
                    .foregroundStyle(DSColor.textTertiary)
            }
            .padding(DSSpacing.margemTela)
        }
        .background(DSColor.bgCanvas)
        .navigationTitle("Aviso")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }
}
