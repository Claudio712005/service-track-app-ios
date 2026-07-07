import Foundation

// Entidades de domínio (spec §4). Campos espelham os contratos OpenAPI,
// já convertidos para tipos Swift; DTOs e mapeamento vivem em STData.

public struct Cliente: Equatable, Identifiable, Sendable {
    public let id: UUID
    public var nome: String
    public var email: String
    public var cpf: String
    public var telefone: String
    public var roles: [String]
    public var ativo: Bool

    public init(id: UUID, nome: String, email: String, cpf: String, telefone: String, roles: [String], ativo: Bool) {
        self.id = id
        self.nome = nome
        self.email = email
        self.cpf = cpf
        self.telefone = telefone
        self.roles = roles
        self.ativo = ativo
    }
}

public struct Veiculo: Equatable, Identifiable, Sendable {
    public let id: UUID
    public var placa: String
    public var marca: String
    public var modelo: String
    public var ano: Int
    public var proprietarioId: UUID?
    public var urlImagem: URL?
    public var codigoFipe: String?

    public init(id: UUID, placa: String, marca: String, modelo: String, ano: Int,
                proprietarioId: UUID?, urlImagem: URL?, codigoFipe: String?) {
        self.id = id
        self.placa = placa
        self.marca = marca
        self.modelo = modelo
        self.ano = ano
        self.proprietarioId = proprietarioId
        self.urlImagem = urlImagem
        self.codigoFipe = codigoFipe
    }
}

public struct ItemServico: Equatable, Identifiable, Sendable {
    public let id: UUID
    public var servicoId: UUID?
    public var valor: Double?
    public var feito: Bool
    public var mecanicoResponsavelId: UUID?
    public var dataRealizacao: Date?
    public var observacao: String?

    public init(id: UUID, servicoId: UUID?, valor: Double?, feito: Bool,
                mecanicoResponsavelId: UUID?, dataRealizacao: Date?, observacao: String?) {
        self.id = id
        self.servicoId = servicoId
        self.valor = valor
        self.feito = feito
        self.mecanicoResponsavelId = mecanicoResponsavelId
        self.dataRealizacao = dataRealizacao
        self.observacao = observacao
    }
}

/// Orçamento embutido na OS (spec §4.4) — somente leitura no app (RN-03).
public struct Orcamento: Equatable, Sendable {
    public let id: UUID?
    public var custoMaoDeObra: Double
    public var custoInsumos: Double
    public var valorTotal: Double
    public var aprovado: Bool?
    public var observacao: String?
    public var dataCriacao: Date?
    public var dataAtualizacao: Date?

    public init(id: UUID?, custoMaoDeObra: Double, custoInsumos: Double, valorTotal: Double,
                aprovado: Bool?, observacao: String?, dataCriacao: Date?, dataAtualizacao: Date?) {
        self.id = id
        self.custoMaoDeObra = custoMaoDeObra
        self.custoInsumos = custoInsumos
        self.valorTotal = valorTotal
        self.aprovado = aprovado
        self.observacao = observacao
        self.dataCriacao = dataCriacao
        self.dataAtualizacao = dataAtualizacao
    }
}

public struct OrdemServico: Equatable, Identifiable, Sendable {
    public let id: UUID
    public var motivo: String
    public var observacao: String?
    public var clienteId: UUID?
    public var mecanicoId: UUID?
    public var veiculoId: UUID?
    public var status: StatusOrdemServico
    public var dataCriacao: Date?
    public var dataAtualizacao: Date?
    public var itensServico: [ItemServico]
    public var insumos: [UUID]
    public var orcamento: Orcamento?

    public init(id: UUID, motivo: String, observacao: String?, clienteId: UUID?, mecanicoId: UUID?,
                veiculoId: UUID?, status: StatusOrdemServico, dataCriacao: Date?, dataAtualizacao: Date?,
                itensServico: [ItemServico], insumos: [UUID], orcamento: Orcamento?) {
        self.id = id
        self.motivo = motivo
        self.observacao = observacao
        self.clienteId = clienteId
        self.mecanicoId = mecanicoId
        self.veiculoId = veiculoId
        self.status = status
        self.dataCriacao = dataCriacao
        self.dataAtualizacao = dataAtualizacao
        self.itensServico = itensServico
        self.insumos = insumos
        self.orcamento = orcamento
    }
}

/// Retorno das ações de aprovação/reprovação/cancelamento e itens da listagem
/// (`ResumoOrdemServicoResponse` — ADR-iOS-002 D3).
public struct ResumoOrdemServico: Equatable, Identifiable, Sendable {
    public let id: UUID
    public var motivo: String
    public var observacao: String?
    public var clienteId: UUID?
    public var mecanicoId: UUID?
    public var veiculoId: UUID?
    public var status: StatusOrdemServico

    public init(id: UUID, motivo: String, observacao: String?, clienteId: UUID?,
                mecanicoId: UUID?, veiculoId: UUID?, status: StatusOrdemServico) {
        self.id = id
        self.motivo = motivo
        self.observacao = observacao
        self.clienteId = clienteId
        self.mecanicoId = mecanicoId
        self.veiculoId = veiculoId
        self.status = status
    }
}

/// Envelope de paginação (spec §7.2).
public struct Page<Element: Equatable & Sendable>: Equatable, Sendable {
    public var content: [Element]
    public var page: Int
    public var size: Int
    public var total: Int
    public var totalPages: Int

    public init(content: [Element], page: Int, size: Int, total: Int, totalPages: Int) {
        self.content = content
        self.page = page
        self.size = size
        self.total = total
        self.totalPages = totalPages
    }

    public var temProximaPagina: Bool { page + 1 < totalPages }
}

public struct Notificacao: Equatable, Identifiable, Sendable {
    public enum StatusEnvio: String, Sendable {
        case pendente = "PENDENTE"
        case enviada = "ENVIADA"
        case falhaEnvio = "FALHA_ENVIO"
        case desconhecido = ""
    }

    public let id: UUID
    public var titulo: String
    public var assunto: String
    public var descricao: String
    public var tipoNotificacao: String
    public var tipoConteudo: String
    public var statusEnvio: StatusEnvio
    public var visualizada: Bool
    public var dataCriacao: Date?
    public var dataEnvio: Date?
    public var dataVisualizacao: Date?

    public init(id: UUID, titulo: String, assunto: String, descricao: String,
                tipoNotificacao: String, tipoConteudo: String, statusEnvio: StatusEnvio,
                visualizada: Bool, dataCriacao: Date?, dataEnvio: Date?, dataVisualizacao: Date?) {
        self.id = id
        self.titulo = titulo
        self.assunto = assunto
        self.descricao = descricao
        self.tipoNotificacao = tipoNotificacao
        self.tipoConteudo = tipoConteudo
        self.statusEnvio = statusEnvio
        self.visualizada = visualizada
        self.dataCriacao = dataCriacao
        self.dataEnvio = dataEnvio
        self.dataVisualizacao = dataVisualizacao
    }
}

public struct CatalogoServico: Equatable, Identifiable, Sendable {
    public let id: UUID
    public var nomeServico: String
    public var descricaoServico: String

    public init(id: UUID, nomeServico: String, descricaoServico: String) {
        self.id = id
        self.nomeServico = nomeServico
        self.descricaoServico = descricaoServico
    }
}

public struct CatalogoInsumo: Equatable, Identifiable, Sendable {
    public let id: UUID
    public var nome: String
    public var descricao: String

    public init(id: UUID, nome: String, descricao: String) {
        self.id = id
        self.nome = nome
        self.descricao = descricao
    }
}
