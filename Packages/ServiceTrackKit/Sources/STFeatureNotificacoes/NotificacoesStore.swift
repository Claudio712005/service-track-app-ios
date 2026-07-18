import Foundation
import Observation
import STDomain
import STObservability

@MainActor
@Observable
public final class NotificacoesStore {
    public enum Filtro: CaseIterable, Hashable {
        case todas, naoLidas

        public var rotulo: String {
            switch self {
            case .todas: "Todas"
            case .naoLidas: "Não lidas"
            }
        }

        var apenasNaoLidas: Bool? {
            self == .naoLidas ? true : nil
        }
    }

    public enum Fase: Equatable {
        case carregando
        case conteudo
        case vazio
        case erro(AppError)
    }

    public struct Estado {
        public var fase: Fase = .carregando
        public var filtro: Filtro = .todas
        public var notificacoes: [Notificacao] = []
        public var naoLidas = 0
        public var carregandoMais = false
        public var temMais = false
        public var marcandoTodas = false
        public var erroAcao: String?
    }

    public enum Acao {
        case aparecer
        case recarregar
        case filtroAlterado(Filtro)
        case chegouAoFim
        case abrir(Notificacao)
        case marcarTodasComoLidas
        case limparFeedback
    }

    public private(set) var estado = Estado()

    private let repo: NotificacaoRepository
    private var pagina = 0
    private let tamanhoPagina = 20
    private var tarefaAtual: Task<Void, Never>?

    public init(repo: NotificacaoRepository) {
        self.repo = repo
    }

    public func send(_ acao: Acao) {
        switch acao {
        case .aparecer:
            if estado.notificacoes.isEmpty { recomecar() }
        case .recarregar:
            recomecar()
        case .filtroAlterado(let filtro):
            guard filtro != estado.filtro else { return }
            estado.filtro = filtro
            recomecar()
        case .chegouAoFim:
            carregarMais()
        case .abrir(let notificacao):
            marcarVisualizada(notificacao)
        case .marcarTodasComoLidas:
            marcarTodas()
        case .limparFeedback:
            estado.erroAcao = nil
        }
    }

    public func recarregarAguardando() async {
        await carregarPagina(reset: true)
    }

    private func recomecar() {
        tarefaAtual?.cancel()
        estado.fase = .carregando
        tarefaAtual = Task { await carregarPagina(reset: true) }
    }

    private func carregarMais() {
        guard estado.temMais, !estado.carregandoMais, case .conteudo = estado.fase else { return }
        estado.carregandoMais = true
        tarefaAtual = Task { await carregarPagina(reset: false) }
    }

    private func carregarPagina(reset: Bool) async {
        if reset { pagina = 0 }
        do {
            async let paginaAsync = repo.listar(apenasNaoLidas: estado.filtro.apenasNaoLidas,
                                                page: pagina, size: tamanhoPagina)
            async let contagemAsync = repo.contagemNaoLidas()
            let (resultado, contagem) = try await (paginaAsync, contagemAsync)
            guard !Task.isCancelled else { return }

            estado.notificacoes = reset ? resultado.content : estado.notificacoes + resultado.content
            estado.naoLidas = contagem
            estado.temMais = resultado.temProximaPagina
            pagina += 1
            estado.fase = estado.notificacoes.isEmpty ? .vazio : .conteudo
        } catch let erro as AppError {
            guard !Task.isCancelled else { return }
            if reset { estado.fase = .erro(erro) }
        } catch {
            if reset { estado.fase = .erro(.rede) }
        }
        estado.carregandoMais = false
    }

    private func marcarVisualizada(_ notificacao: Notificacao) {
        Telemetria.registrar("notification_open", ["id_hash": Telemetria.pseudonimo(notificacao.id)])
        guard !notificacao.visualizada,
              let indice = estado.notificacoes.firstIndex(where: { $0.id == notificacao.id }) else {
            return
        }
        estado.notificacoes[indice].visualizada = true
        estado.notificacoes[indice].dataVisualizacao = .now
        estado.naoLidas = max(0, estado.naoLidas - 1)

        Task {
            do {
                try await repo.marcarVisualizada(id: notificacao.id)
            } catch {
                if let indice = estado.notificacoes.firstIndex(where: { $0.id == notificacao.id }) {
                    estado.notificacoes[indice].visualizada = false
                    estado.notificacoes[indice].dataVisualizacao = nil
                }
                estado.naoLidas += 1
                estado.erroAcao = "Não foi possível marcar como lida. Tente novamente."
            }
        }
    }

    private func marcarTodas() {
        let pendentes = estado.notificacoes.filter { !$0.visualizada }
        guard !pendentes.isEmpty, !estado.marcandoTodas else { return }
        estado.marcandoTodas = true

        Task {
            var falhas = 0
            for notificacao in pendentes {
                do {
                    try await repo.marcarVisualizada(id: notificacao.id)
                    if let indice = estado.notificacoes.firstIndex(where: { $0.id == notificacao.id }) {
                        estado.notificacoes[indice].visualizada = true
                        estado.notificacoes[indice].dataVisualizacao = .now
                    }
                    estado.naoLidas = max(0, estado.naoLidas - 1)
                } catch {
                    falhas += 1
                }
            }
            if falhas > 0 {
                estado.erroAcao = "\(falhas) notificação(ões) não puderam ser marcadas."
            }
            estado.marcandoTodas = false
        }
    }
}
