import Foundation

/// Máquina de estados da Ordem de Serviço (spec §5).
/// Fonte canônica: `StatusOrdemServicoEnum.kt` / `StatusOrdemServico.podeTransitarPara`.
public enum StatusOrdemServico: Hashable, Sendable, CaseIterable {
    case recebida
    case emDiagnostico
    case aguardandoAprovacao
    case emExecucao
    case finalizada
    case entregue
    case cancelada
    /// Valor não reconhecido vindo da API — UI neutra (spec §9 C1).
    case desconhecido(String)

    public static var allCases: [StatusOrdemServico] {
        [.recebida, .emDiagnostico, .aguardandoAprovacao, .emExecucao, .finalizada, .entregue, .cancelada]
    }

    /// Jornada "feliz" exibida na timeline (spec §5.4), sem o desvio de cancelamento.
    public static var jornada: [StatusOrdemServico] {
        [.recebida, .emDiagnostico, .aguardandoAprovacao, .emExecucao, .finalizada, .entregue]
    }

    /// Decodificação tolerante: aceita os 7 estados canônicos e os sinônimos
    /// legados dos schemas do dashboard (spec §9 C1).
    public init(rawAPI valor: String) {
        switch valor.uppercased() {
        case "RECEBIDA": self = .recebida
        case "EM_DIAGNOSTICO", "DIAGNOSTICO": self = .emDiagnostico
        case "AGUARDANDO_APROVACAO", "ORCAMENTO_GERADO": self = .aguardandoAprovacao
        case "EM_EXECUCAO", "APROVADO": self = .emExecucao
        case "FINALIZADA": self = .finalizada
        case "ENTREGUE": self = .entregue
        case "CANCELADA": self = .cancelada
        default: self = .desconhecido(valor)
        }
    }

    /// Valor canônico enviado à API (filtros de listagem).
    public var rawAPI: String {
        switch self {
        case .recebida: "RECEBIDA"
        case .emDiagnostico: "EM_DIAGNOSTICO"
        case .aguardandoAprovacao: "AGUARDANDO_APROVACAO"
        case .emExecucao: "EM_EXECUCAO"
        case .finalizada: "FINALIZADA"
        case .entregue: "ENTREGUE"
        case .cancelada: "CANCELADA"
        case .desconhecido(let valor): valor
        }
    }

    /// Posição na jornada (`ordem` do backend; CANCELADA = 0).
    public var ordem: Int {
        switch self {
        case .cancelada: 0
        case .recebida: 1
        case .emDiagnostico: 2
        case .aguardandoAprovacao: 3
        case .emExecucao: 4
        case .finalizada: 5
        case .entregue: 6
        case .desconhecido: -1
        }
    }

    /// Rótulo PT exibido ao cliente (spec §5.1).
    public var rotulo: String {
        switch self {
        case .recebida: "Recebida"
        case .emDiagnostico: "Em Diagnóstico"
        case .aguardandoAprovacao: "Aguardando Aprovação"
        case .emExecucao: "Em Execução"
        case .finalizada: "Finalizada"
        case .entregue: "Entregue"
        case .cancelada: "Cancelada"
        case .desconhecido: "Status desconhecido"
        }
    }

    /// Anúncio por extenso para VoiceOver (spec §16).
    public var descricaoAcessivel: String {
        switch self {
        case .aguardandoAprovacao: "Aguardando sua aprovação"
        case .finalizada: "Finalizada, aguardando retirada"
        default: rotulo
        }
    }

    /// Transições válidas — espelho de `podeTransitarPara` (spec §5.2).
    public func podeTransitarPara(_ destino: StatusOrdemServico) -> Bool {
        switch self {
        case .recebida: destino == .emDiagnostico || destino == .cancelada
        case .emDiagnostico: destino == .aguardandoAprovacao || destino == .cancelada
        case .aguardandoAprovacao: destino == .emExecucao || destino == .cancelada
        case .emExecucao: destino == .finalizada || destino == .cancelada
        case .finalizada: destino == .entregue
        case .entregue, .cancelada, .desconhecido: false
        }
    }

    /// RN-06: cliente cancela apenas destes 4 estados (spec §9 C3 — código prevalece sobre o SRS).
    public var clientePodeCancelar: Bool {
        podeTransitarPara(.cancelada)
    }

    /// RN-04/RN-05: aprovar/reprovar só aparecem em AGUARDANDO_APROVACAO (spec §5.3).
    public var clientePodeDecidirOrcamento: Bool {
        self == .aguardandoAprovacao
    }

    /// Estado terminal (somente histórico).
    public var isTerminal: Bool {
        self == .entregue || self == .cancelada
    }
}
