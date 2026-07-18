import Foundation
import Observation
import STDomain
import STObservability

@MainActor
@Observable
public final class OrdensStore {
    public enum Filtro: CaseIterable, Hashable {
        case todas, ativas, aguardandoAprovacao, concluidas, canceladas

        public var rotulo: String {
            switch self {
            case .todas: "Todas"
            case .ativas: "Ativas"
            case .aguardandoAprovacao: "Aguardando aprovação"
            case .concluidas: "Concluídas"
            case .canceladas: "Canceladas"
            }
        }

        var statusQuery: StatusOrdemServico? {
            switch self {
            case .aguardandoAprovacao: .aguardandoAprovacao
            case .canceladas: .cancelada
            case .todas, .ativas, .concluidas: nil
            }
        }

        func inclui(_ status: StatusOrdemServico) -> Bool {
            switch self {
            case .todas: true
            case .ativas: [.recebida, .emDiagnostico, .aguardandoAprovacao, .emExecucao].contains(status)
            case .concluidas: status == .finalizada || status == .entregue
            case .aguardandoAprovacao: status == .aguardandoAprovacao
            case .canceladas: status == .cancelada
            }
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
        public var ordens: [ResumoOrdemServico] = []
        public var carregandoMais = false
        public var temMais = false

        public var visiveis: [ResumoOrdemServico] {
            ordens.filter { filtro.inclui($0.status) }
        }
    }

    public enum Acao {
        case aparecer
        case recarregar
        case filtroAlterado(Filtro)
        case chegouAoFim
    }

    public private(set) var estado = Estado()

    private let repo: OrdemServicoRepository
    private var pagina = 0
    private let tamanhoPagina = 20
    private var tarefaAtual: Task<Void, Never>?

    public init(repo: OrdemServicoRepository) {
        self.repo = repo
    }

    public func send(_ acao: Acao) {
        switch acao {
        case .aparecer:
            Telemetria.registrar("order_list_view", ["filter": "todas"])
            if estado.ordens.isEmpty { recomecar() }
        case .recarregar:
            recomecar()
        case .filtroAlterado(let filtro):
            guard filtro != estado.filtro else { return }
            estado.filtro = filtro
            Telemetria.registrar("order_list_view", ["filter": "\(filtro)"])
            recomecar()
        case .chegouAoFim:
            carregarMais()
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
            let resultado = try await repo.listar(status: estado.filtro.statusQuery,
                                                  page: pagina, size: tamanhoPagina)
            guard !Task.isCancelled else { return }
            estado.ordens = reset ? resultado.content : estado.ordens + resultado.content
            estado.temMais = resultado.temProximaPagina
            pagina += 1
            estado.fase = estado.visiveis.isEmpty ? .vazio : .conteudo
        } catch let erro as AppError {
            guard !Task.isCancelled else { return }
            if reset { estado.fase = .erro(erro) }
        } catch {
            if reset { estado.fase = .erro(.rede) }
        }
        estado.carregandoMais = false
    }
}
