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

    private let veiculos: VeiculoRepository
    private var carregou = false

    public init(veiculos: VeiculoRepository) {
        self.veiculos = veiculos
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
        if !silencioso { fase = .carregando }
        do {
            let lista = try await veiculos.listar()
            fase = lista.isEmpty ? .vazio : .conteudo(lista)
            carregou = true
        } catch let erro as AppError {
            if case .conteudo = fase { return }
            fase = .erro(erro)
        } catch {
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
    private let aoRemover: () -> Void

    public init(veiculo: Veiculo, veiculos: VeiculoRepository,
                ordens: OrdemServicoRepository, aoRemover: @escaping () -> Void) {
        self.estado = Estado(veiculo: veiculo)
        self.veiculos = veiculos
        self.ordens = ordens
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
