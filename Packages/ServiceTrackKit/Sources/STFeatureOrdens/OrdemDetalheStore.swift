import Foundation
import Observation
import STDomain

/// Detalhe da OS (spec §15.6/§15.7): timeline, orçamento, itens, ações por
/// estado (§5.3). Ações devolvem resumo → refetch do detalhe (ADR-iOS-002 D3).
@MainActor
@Observable
public final class OrdemDetalheStore {
    public enum Fase: Equatable {
        case carregando
        case conteudo
        case erro(AppError)
    }

    public struct Estado {
        public var fase: Fase = .carregando
        public var ordem: OrdemServico?
        public var nomesInsumos: [UUID: String] = [:]
        public var decidindo = false
        public var erroAcao: String?
        public var sucessoAcao: String?

        /// Contagem agregada de insumos (IDs repetidos por quantidade — spec §15.6).
        public var insumosAgregados: [(id: UUID, quantidade: Int)] {
            guard let ordem else { return [] }
            return Dictionary(grouping: ordem.insumos, by: \.self)
                .map { (id: $0.key, quantidade: $0.value.count) }
                .sorted { $0.quantidade > $1.quantidade }
        }
    }

    public enum Acao {
        case aparecer
        case recarregar
        case aprovar
        case reprovar(motivo: String)
        /// RN-06: motivo opcional.
        case cancelar(motivo: String?)
        case limparFeedback
    }

    public private(set) var estado = Estado()

    private let osId: UUID
    private let ordens: OrdemServicoRepository
    private let catalogo: CatalogoRepository
    private let cache: CacheStore?

    public init(osId: UUID, ordens: OrdemServicoRepository, catalogo: CatalogoRepository,
                cache: CacheStore? = nil) {
        self.osId = osId
        self.ordens = ordens
        self.catalogo = catalogo
        self.cache = cache
    }

    public func send(_ acao: Acao) {
        switch acao {
        case .aparecer:
            if estado.ordem == nil { Task { await carregar() } }
        case .recarregar:
            Task { await carregar() }
        case .aprovar:
            executar { [ordens, osId] in
                _ = try await ordens.aprovarOrcamento(osId: osId)
                return "Orçamento aprovado! Serviço entrando em execução."
            }
        case .reprovar(let motivo):
            executar { [ordens, osId] in
                _ = try await ordens.reprovarOrcamento(osId: osId, motivo: motivo)
                return "Solicitação registrada. O orçamento foi reprovado."
            }
        case .cancelar(let motivo):
            executar { [ordens, osId] in
                _ = try await ordens.cancelar(osId: osId, motivo: motivo)
                return "Ordem de serviço cancelada."
            }
        case .limparFeedback:
            estado.erroAcao = nil
            estado.sucessoAcao = nil
        }
    }

    public func carregar() async {
        if estado.ordem == nil { estado.fase = .carregando }
        do {
            let ordem = try await ordens.buscar(id: osId)
            estado.ordem = ordem
            estado.fase = .conteudo
            await carregarNomesInsumos(ordem)
        } catch let erro as AppError {
            if estado.ordem == nil { estado.fase = .erro(erro) }
            else { estado.erroAcao = erro.mensagemPadrao }
        } catch {
            if estado.ordem == nil { estado.fase = .erro(.rede) }
        }
    }

    /// Nomes via catálogo (cache-first nas fases futuras); falha não quebra a tela.
    private func carregarNomesInsumos(_ ordem: OrdemServico) async {
        guard !ordem.insumos.isEmpty, estado.nomesInsumos.isEmpty else { return }
        if let insumos = try? await catalogo.insumos() {
            estado.nomesInsumos = Dictionary(uniqueKeysWithValues: insumos.map { ($0.id, $0.nome) })
        }
    }

    /// Sem retry automático em ação (RN-09); 409 = decidido por outro canal
    /// (RN-07) → mensagem + refetch mostrando o estado atual.
    private func executar(_ operacao: @escaping () async throws -> String) {
        guard !estado.decidindo else { return }
        estado.decidindo = true
        estado.erroAcao = nil

        Task {
            do {
                estado.sucessoAcao = try await operacao()
            } catch let erro as AppError {
                if case .conflitoEstado = erro {
                    estado.erroAcao = "Esta ordem já foi atualizada por outro canal. Estado recarregado."
                } else {
                    estado.erroAcao = erro.mensagemPadrao
                }
            } catch {
                estado.erroAcao = AppError.rede.mensagemPadrao
            }
            // Ação em OS invalida o dashboard cacheado (spec §11.2).
            await cache?.invalidar(chaves: [CacheChave.dashboard])
            await carregar()
            estado.decidindo = false
        }
    }
}
