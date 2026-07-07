import Foundation

// Modelo de domínio do dashboard (spec §7.7). A API responde em snake_case;
// a conversão é isolada nos DTOs de STData (spec §9 C2).

public struct DashboardCliente: Equatable, Sendable {
    public var usuarioId: UUID
    public var usuarioNome: String?
    public var resumo: ResumoDashboard
    public var ordensAtivas: [OrdemAtivaDashboard]
    public var ordensRecentes: [OrdemRecenteDashboard]
    public var veiculos: [VeiculoDashboard]
    public var dataAtualizacao: Date?

    public init(usuarioId: UUID, usuarioNome: String?, resumo: ResumoDashboard,
                ordensAtivas: [OrdemAtivaDashboard], ordensRecentes: [OrdemRecenteDashboard],
                veiculos: [VeiculoDashboard], dataAtualizacao: Date?) {
        self.usuarioId = usuarioId
        self.usuarioNome = usuarioNome
        self.resumo = resumo
        self.ordensAtivas = ordensAtivas
        self.ordensRecentes = ordensRecentes
        self.veiculos = veiculos
        self.dataAtualizacao = dataAtualizacao
    }
}

/// Números do card de resumo — exibidos como o backend envia, sem recálculo (spec §9 C7).
public struct ResumoDashboard: Equatable, Sendable {
    public var ordensAtivas: Int
    public var ordensConcluidas: Int
    public var ordensCanceladas: Int
    public var totalOrdens: Int
    public var veiculosCadastrados: Int

    public init(ordensAtivas: Int, ordensConcluidas: Int, ordensCanceladas: Int,
                totalOrdens: Int, veiculosCadastrados: Int) {
        self.ordensAtivas = ordensAtivas
        self.ordensConcluidas = ordensConcluidas
        self.ordensCanceladas = ordensCanceladas
        self.totalOrdens = totalOrdens
        self.veiculosCadastrados = veiculosCadastrados
    }
}

public struct OrdemAtivaDashboard: Equatable, Identifiable, Sendable {
    public let id: UUID
    public var motivo: String
    public var status: StatusOrdemServico
    public var veiculoId: UUID?
    public var veiculoPlaca: String?
    public var veiculoModelo: String?
    public var mecanicoId: UUID?
    public var mecanicoNome: String?
    public var dataCriacao: Date?
    public var dataAtualizacao: Date?
    public var diasEmAndamento: Int?
    public var valorOrcado: Double?
    public var prazoConclusao: Date?

    public init(id: UUID, motivo: String, status: StatusOrdemServico, veiculoId: UUID?,
                veiculoPlaca: String?, veiculoModelo: String?, mecanicoId: UUID?, mecanicoNome: String?,
                dataCriacao: Date?, dataAtualizacao: Date?, diasEmAndamento: Int?,
                valorOrcado: Double?, prazoConclusao: Date?) {
        self.id = id
        self.motivo = motivo
        self.status = status
        self.veiculoId = veiculoId
        self.veiculoPlaca = veiculoPlaca
        self.veiculoModelo = veiculoModelo
        self.mecanicoId = mecanicoId
        self.mecanicoNome = mecanicoNome
        self.dataCriacao = dataCriacao
        self.dataAtualizacao = dataAtualizacao
        self.diasEmAndamento = diasEmAndamento
        self.valorOrcado = valorOrcado
        self.prazoConclusao = prazoConclusao
    }
}

public struct OrdemRecenteDashboard: Equatable, Identifiable, Sendable {
    public let id: UUID
    public var motivo: String
    public var status: StatusOrdemServico
    public var veiculoId: UUID?
    public var veiculoPlaca: String?
    public var veiculoModelo: String?
    public var dataCriacao: Date?
    public var dataConclusao: Date?
    public var diasParaConclusao: Int?
    public var valorTotal: Double?
    public var mecanicoNome: String?

    public init(id: UUID, motivo: String, status: StatusOrdemServico, veiculoId: UUID?,
                veiculoPlaca: String?, veiculoModelo: String?, dataCriacao: Date?, dataConclusao: Date?,
                diasParaConclusao: Int?, valorTotal: Double?, mecanicoNome: String?) {
        self.id = id
        self.motivo = motivo
        self.status = status
        self.veiculoId = veiculoId
        self.veiculoPlaca = veiculoPlaca
        self.veiculoModelo = veiculoModelo
        self.dataCriacao = dataCriacao
        self.dataConclusao = dataConclusao
        self.diasParaConclusao = diasParaConclusao
        self.valorTotal = valorTotal
        self.mecanicoNome = mecanicoNome
    }
}

public struct VeiculoDashboard: Equatable, Identifiable, Sendable {
    public let id: UUID
    public var placa: String
    public var marca: String
    public var modelo: String
    public var ano: Int
    public var imagemUrl: URL?
    public var codigoFipe: String?
    public var ativo: Bool
    public var totalOrdens: Int?
    public var totalGasto: Double?
    public var dataCriacao: Date?

    public init(id: UUID, placa: String, marca: String, modelo: String, ano: Int,
                imagemUrl: URL?, codigoFipe: String?, ativo: Bool,
                totalOrdens: Int?, totalGasto: Double?, dataCriacao: Date?) {
        self.id = id
        self.placa = placa
        self.marca = marca
        self.modelo = modelo
        self.ano = ano
        self.imagemUrl = imagemUrl
        self.codigoFipe = codigoFipe
        self.ativo = ativo
        self.totalOrdens = totalOrdens
        self.totalGasto = totalGasto
        self.dataCriacao = dataCriacao
    }
}
