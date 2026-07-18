import Foundation
import Observation
import STDomain
import STObservability

@MainActor
@Observable
public final class GaragemStore {
    public enum Fase: Equatable {
        case carregando
        case conteudo([Veiculo])
        case vazio
        case erro(AppError)
    }

    public enum Acao {
        case aparecer
        case recarregar
    }

    public private(set) var fase: Fase = .carregando
    public private(set) var offline = false

    private let veiculos: VeiculoRepository
    private let cache: CacheStore?
    private let ttl: TimeInterval = 600
    private var carregou = false

    public init(veiculos: VeiculoRepository, cache: CacheStore? = nil) {
        self.veiculos = veiculos
        self.cache = cache
    }

    public func send(_ acao: Acao) {
        switch acao {
        case .aparecer:
            Task { await carregar(silencioso: carregou) }
        case .recarregar:
            Task { await carregar(silencioso: false) }
        }
    }

    public func carregar(silencioso: Bool = false) async {
        if !carregou, let cache,
           let entrada = await cache.ler([Veiculo].self, chave: CacheChave.veiculos) {
            fase = entrada.valor.isEmpty ? .vazio : .conteudo(entrada.valor)
            carregou = true
        } else if !silencioso && !carregou {
            fase = .carregando
        }

        do {
            let lista = try await veiculos.listar()
            fase = lista.isEmpty ? .vazio : .conteudo(lista)
            offline = false
            carregou = true
            await cache?.gravar(lista, chave: CacheChave.veiculos)
        } catch let erro as AppError {
            if case .conteudo = fase {
                if case .rede = erro {
                    if !offline { Telemetria.registrar("offline_banner_shown", ["tela": "garagem"]) }
                    offline = true
                }
                return
            }
            fase = .erro(erro)
        } catch {
            if case .conteudo = fase { offline = true; return }
            fase = .erro(.rede)
        }
    }
}

@MainActor
@Observable
public final class VeiculoDetalheStore {
    public struct Estado {
        public var veiculo: Veiculo
        public var historico: [ResumoOrdemServico] = []
        public var carregandoHistorico = false
        public var removendo = false
        public var erro: String?
    }

    public enum Acao {
        case aparecer
        case remover
    }

    public private(set) var estado: Estado

    private let veiculos: VeiculoRepository
    private let ordens: OrdemServicoRepository
    private let cache: CacheStore?
    private let aoRemover: () -> Void

    public init(veiculo: Veiculo, veiculos: VeiculoRepository, ordens: OrdemServicoRepository,
                cache: CacheStore? = nil, aoRemover: @escaping () -> Void) {
        self.estado = Estado(veiculo: veiculo)
        self.veiculos = veiculos
        self.ordens = ordens
        self.cache = cache
        self.aoRemover = aoRemover
    }

    public func send(_ acao: Acao) {
        switch acao {
        case .aparecer:
            if estado.historico.isEmpty { carregarHistorico() }
        case .remover:
            remover()
        }
    }

    private func carregarHistorico() {
        estado.carregandoHistorico = true
        Task {
            do {
                let pagina = try await ordens.listar(status: nil, page: 0, size: 100)
                estado.historico = pagina.content.filter { $0.veiculoId == estado.veiculo.id }
            } catch {
                estado.historico = []
            }
            estado.carregandoHistorico = false
        }
    }

    private func remover() {
        guard !estado.removendo else { return }
        estado.removendo = true
        Task {
            do {
                try await veiculos.remover(id: estado.veiculo.id)
                Telemetria.registrar("vehicle_delete")
                await cache?.invalidar(chaves: [CacheChave.veiculos, CacheChave.dashboard])
                aoRemover()
            } catch let erro as AppError {
                estado.erro = erro.mensagemPadrao
            } catch {
                estado.erro = AppError.rede.mensagemPadrao
            }
            estado.removendo = false
        }
    }
}
