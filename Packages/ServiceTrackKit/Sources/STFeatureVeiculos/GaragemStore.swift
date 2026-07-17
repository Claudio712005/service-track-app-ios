import Foundation
import Observation
import STDomain

/// Lista da Garagem (spec §15.8) — `GET /veiculos` retorna só os do cliente
/// autenticado (RN-02).
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
    /// Rede indisponível, exibindo cache (spec §11.3).
    public private(set) var offline = false

    private let veiculos: VeiculoRepository
    private let cache: CacheStore?
    /// TTL de veículos: 10min (spec §11.2) — CRUD invalida antes disso.
    private let ttl: TimeInterval = 600
    private var carregou = false

    public init(veiculos: VeiculoRepository, cache: CacheStore? = nil) {
        self.veiculos = veiculos
        self.cache = cache
    }

    public func send(_ acao: Acao) {
        switch acao {
        case .aparecer:
            // Recarrega ao voltar (CRUD invalida — spec §11.2), mas só mostra
            // skeleton na primeira carga.
            Task { await carregar(silencioso: carregou) }
        case .recarregar:
            Task { await carregar(silencioso: false) }
        }
    }

    public func carregar(silencioso: Bool = false) async {
        // SWR: cache primeiro (revisita sem skeleton — spec §11.2).
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
                if case .rede = erro { offline = true }
                return
            }
            fase = .erro(erro)
        } catch {
            if case .conteudo = fase { offline = true; return }
            fase = .erro(.rede)
        }
    }
}

/// Detalhe do veículo (spec §15.9): dados + histórico de OS do veículo
/// (RF08 — filtro client-side por `veiculoId` sobre a listagem, o contrato
/// não expõe esse filtro) + remoção (soft delete RN-08).
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
                // Uma página larga cobre o histórico típico; paginação dedicada
                // por veículo é evolução do backend (spec §15.9).
                let pagina = try await ordens.listar(status: nil, page: 0, size: 100)
                estado.historico = pagina.content.filter { $0.veiculoId == estado.veiculo.id }
            } catch {
                // Histórico é secundário: falha não derruba o detalhe.
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
