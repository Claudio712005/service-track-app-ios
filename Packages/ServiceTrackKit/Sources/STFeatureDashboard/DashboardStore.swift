import Foundation
import Observation
import STDomain
import STObservability

@MainActor
@Observable
public final class DashboardStore {
    public enum Fase: Equatable {
        case carregando
        case conteudo
        case vazio
        case erro(AppError)
    }

    public struct Estado {
        public var fase: Fase = .carregando
        public var dashboard: DashboardCliente?
        public var naoLidas = 0
        public var decidindo = false
        public var erroAcao: String?
        public var sucessoAcao: String?
        public var offline = false

        public var pendenteDeAprovacao: OrdemAtivaDashboard? {
            dashboard?.ordensAtivas.first { $0.status == .aguardandoAprovacao }
        }
    }

    public struct PontoGasto: Equatable, Identifiable {
        public let id: String
        public let rotulo: String
        public let valor: Double

        public init(id: String, rotulo: String, valor: Double) {
            self.id = id
            self.rotulo = rotulo
            self.valor = valor
        }
    }

    public struct PontoMensal: Equatable, Identifiable {
        public let mes: Date
        public let valor: Double
        public var id: Date { mes }

        public init(mes: Date, valor: Double) {
            self.mes = mes
            self.valor = valor
        }
    }

    public enum Acao {
        case aparecer
        case recarregar
        case voltouAoForeground
        case aprovarOrcamento(UUID)
        case reprovarOrcamento(UUID, motivo: String)
        case limparFeedback
    }

    public private(set) var estado = Estado()

    private let dashboard: DashboardRepository
    private let notificacoes: NotificacaoRepository
    private let ordens: OrdemServicoRepository
    private let clienteId: UUID
    private let cache: CacheStore?
    private let ttl: TimeInterval = 60

    public init(dashboard: DashboardRepository, notificacoes: NotificacaoRepository,
                ordens: OrdemServicoRepository, clienteId: UUID, cache: CacheStore? = nil) {
        self.dashboard = dashboard
        self.notificacoes = notificacoes
        self.ordens = ordens
        self.clienteId = clienteId
        self.cache = cache
    }

    public func send(_ acao: Acao) {
        switch acao {
        case .aparecer:
            Telemetria.registrar("dashboard_view")
            if estado.dashboard == nil { Task { await carregar(forcar: false) } }
        case .recarregar:
            Task { await carregar() }
        case .voltouAoForeground:
            if estado.dashboard != nil { Task { await carregar() } }
        case .aprovarOrcamento(let osId):
            decidir(osId: osId, motivo: nil)
        case .reprovarOrcamento(let osId, let motivo):
            decidir(osId: osId, motivo: motivo)
        case .limparFeedback:
            estado.erroAcao = nil
            estado.sucessoAcao = nil
        }
    }

    public func carregar(forcar: Bool = true) async {
        var cacheFresco = false
        if estado.dashboard == nil,
           let cache,
           let entrada = await cache.ler(DashboardCliente.self, chave: CacheChave.dashboard) {
            aplicar(entrada.valor)
            cacheFresco = !entrada.vencida(ttl: ttl)
        }
        if estado.dashboard == nil { estado.fase = .carregando }
        if cacheFresco && !forcar { return }

        do {
            async let dash = dashboard.buscar(clienteId: clienteId)
            async let contagem = notificacoes.contagemNaoLidas()
            let (d, n) = try await (dash, contagem)
            aplicar(d)
            estado.naoLidas = n
            estado.offline = false
            await cache?.gravar(d, chave: CacheChave.dashboard)
        } catch let erro as AppError {
            if estado.dashboard == nil {
                Telemetria.registrar("error_shown", ["tela": "dashboard", "tipo": "\(erro)"])
                estado.fase = .erro(erro)
            } else if case .rede = erro {
                if !estado.offline { Telemetria.registrar("offline_banner_shown", ["tela": "dashboard"]) }
                estado.offline = true
            } else {
                estado.erroAcao = erro.mensagemPadrao
            }
        } catch {
            if estado.dashboard == nil { estado.fase = .erro(.rede) }
            else { estado.offline = true }
        }
    }

    private func aplicar(_ d: DashboardCliente) {
        estado.dashboard = d
        estado.fase = (d.resumo.totalOrdens == 0 && d.resumo.veiculosCadastrados == 0)
            ? .vazio : .conteudo
    }

    private func decidir(osId: UUID, motivo: String?) {
        guard !estado.decidindo else { return }
        estado.decidindo = true
        estado.erroAcao = nil

        Task {
            do {
                if let motivo {
                    _ = try await ordens.reprovarOrcamento(osId: osId, motivo: motivo)
                    estado.sucessoAcao = "Solicitação registrada. O orçamento foi reprovado."
                    Telemetria.registrar("budget_reject", ["os_id_hash": Telemetria.pseudonimo(osId),
                                                           "motivo_len": String(motivo.count)])
                } else {
                    _ = try await ordens.aprovarOrcamento(osId: osId)
                    estado.sucessoAcao = "Orçamento aprovado! Serviço entrando em execução."
                    Telemetria.registrar("budget_approve", ["os_id_hash": Telemetria.pseudonimo(osId)])
                }
            } catch let erro as AppError {
                if case .conflitoEstado = erro {
                    estado.erroAcao = "Este orçamento já foi decidido por outro canal."
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

    public var gastoPorVeiculo: [PontoGasto] {
        (estado.dashboard?.veiculos ?? [])
            .compactMap { veiculo -> PontoGasto? in
                guard let gasto = veiculo.totalGasto, gasto > 0 else { return nil }
                return PontoGasto(id: veiculo.id.uuidString,
                                  rotulo: "\(veiculo.modelo) · \(veiculo.placa)",
                                  valor: gasto)
            }
            .sorted { $0.valor > $1.valor }
    }

    public var gastosPorMes: [PontoMensal] {
        let calendario = Calendar.current
        let porMes = Dictionary(grouping: (estado.dashboard?.ordensRecentes ?? [])
            .filter { $0.status != .cancelada }
            .compactMap { ordem -> (Date, Double)? in
                guard let data = ordem.dataConclusao ?? ordem.dataCriacao,
                      let valor = ordem.valorTotal, valor > 0 else { return nil }
                let mes = calendario.date(from: calendario.dateComponents([.year, .month], from: data)) ?? data
                return (mes, valor)
            }, by: \.0)
        return porMes
            .map { PontoMensal(mes: $0.key, valor: $0.value.reduce(0) { $0 + $1.1 }) }
            .sorted { $0.mes < $1.mes }
    }

    public var totalInvestido: Double {
        gastoPorVeiculo.reduce(0) { $0 + $1.valor }
    }
}
