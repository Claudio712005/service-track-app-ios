import Foundation
import STDomain

// DTOs derivados campo a campo dos contratos `openApi/**` (spec §7.1 contract-first;
// ADR-iOS-002). Todos em camelCase, exceto dashboard (DashboardDTOs.swift).
// `status` chega como String e é convertido pelo enum tolerante (C1).

// MARK: - Autenticação (`components/schemas/autenticacao`)

struct LoginRequestDTO: Encodable {
    let email: String
    let senha: String
}

struct LoginResponseDTO: Decodable {
    let token: String
    let usuarioId: UUID
    let nome: String
    let email: String
    let roles: [String]

    var domain: Sessao {
        Sessao(token: token, usuarioId: usuarioId, nome: nome, email: email, roles: roles)
    }
}

struct ResetarSenhaRequestDTO: Encodable {
    let senhaAtual: String
    let novaSenha: String
    let confirmacaoNovaSenha: String
}

// MARK: - Cliente (`components/schemas/cliente`)

struct CadastrarClienteRequestDTO: Encodable {
    let nome: String
    let email: String
    let senha: String
    /// `format: date` (yyyy-MM-dd)
    let dataNascimento: String
    let telefone: String
    let cpf: String
}

struct AtualizarClienteRequestDTO: Encodable {
    let nome: String
    let email: String
    let telefone: String
}

struct ClienteResponseDTO: Decodable {
    let id: UUID
    let nome: String
    let email: String
    let cpf: String?
    let telefone: String?
    let roles: [String]?
    let ativo: Bool?

    var domain: Cliente {
        Cliente(id: id, nome: nome, email: email, cpf: cpf ?? "", telefone: telefone ?? "",
                roles: roles ?? [], ativo: ativo ?? true)
    }
}

// MARK: - Veículo (`components/schemas/veiculo`)

struct CadastrarVeiculoRequestDTO: Encodable {
    let placa: String
    let modelo: String
    let marca: String
    let ano: Int
    let proprietarioId: UUID
    let urlImagem: String?
}

struct AtualizarVeiculoRequestDTO: Encodable {
    let placa: String
    let modelo: String
    let marca: String
    let ano: Int
    let urlImagem: String?
}

struct DadosVeiculoResponseDTO: Decodable {
    let id: UUID
    let placa: String
    let modelo: String
    let marca: String
    let ano: Int
    let proprietarioId: UUID?
    let urlImagem: String?
    let codigoFipe: String?

    var domain: Veiculo {
        Veiculo(id: id, placa: placa, marca: marca, modelo: modelo, ano: ano,
                proprietarioId: proprietarioId, urlImagem: urlImagem.flatMap(URL.init(string:)),
                codigoFipe: codigoFipe)
    }
}

struct SugestoesImagensResponseDTO: Decodable {
    let imagens: [String]?
}

// MARK: - Ordem de Serviço (`components/schemas/ordemServico`)

struct OrdemServicoRequestDTO: Encodable {
    let motivo: String
    let clienteId: UUID
    /// Required no contrato, mas RN-01 impede o cliente de escolher — conflito C4 (ADR-iOS-002).
    let mecanicoId: UUID?
    let veiculoId: UUID
    let observacao: String?
}

struct CancelarOsRequestDTO: Encodable {
    let motivo: String?
}

struct ReprovarOrcamentoRequestDTO: Encodable {
    let motivo: String
}

struct ItemServicoDTO: Decodable {
    let id: UUID
    let servicoId: UUID?
    let valor: Double?
    let feito: Bool?
    let mecanicoResponsavelId: UUID?
    let dataRealizacao: Date?
    let observacao: String?

    var domain: ItemServico {
        ItemServico(id: id, servicoId: servicoId, valor: valor, feito: feito ?? false,
                    mecanicoResponsavelId: mecanicoResponsavelId,
                    dataRealizacao: dataRealizacao, observacao: observacao)
    }
}

struct OrcamentoDTO: Decodable {
    let id: UUID?
    let custoMaoDeObra: Double?
    let custoInsumos: Double?
    let valorTotal: Double?
    let aprovado: Bool?
    let observacao: String?
    let dataCriacao: Date?
    let dataAtualizacao: Date?

    var domain: Orcamento {
        Orcamento(id: id, custoMaoDeObra: custoMaoDeObra ?? 0, custoInsumos: custoInsumos ?? 0,
                  valorTotal: valorTotal ?? ((custoMaoDeObra ?? 0) + (custoInsumos ?? 0)),
                  aprovado: aprovado, observacao: observacao,
                  dataCriacao: dataCriacao, dataAtualizacao: dataAtualizacao)
    }
}

struct OrdemServicoResponseDTO: Decodable {
    let id: UUID
    let motivo: String?
    let observacao: String?
    let clienteId: UUID?
    let mecanicoId: UUID?
    let veiculoId: UUID?
    let status: String?
    let dataCriacao: Date?
    let dataAtualizacao: Date?
    let itensServico: [ItemServicoDTO]?
    let insumos: [UUID]?
    let orcamento: OrcamentoDTO?

    var domain: OrdemServico {
        OrdemServico(id: id, motivo: motivo ?? "", observacao: observacao,
                     clienteId: clienteId, mecanicoId: mecanicoId, veiculoId: veiculoId,
                     status: StatusOrdemServico(rawAPI: status ?? ""),
                     dataCriacao: dataCriacao, dataAtualizacao: dataAtualizacao,
                     itensServico: (itensServico ?? []).map(\.domain),
                     insumos: insumos ?? [],
                     orcamento: orcamento?.domain)
    }
}

struct ResumoOrdemServicoResponseDTO: Decodable {
    let id: UUID
    let mecanicoId: UUID?
    let clienteId: UUID?
    let veiculoId: UUID?
    let motivo: String?
    let observacao: String?
    let status: String?

    var domain: ResumoOrdemServico {
        ResumoOrdemServico(id: id, motivo: motivo ?? "", observacao: observacao,
                           clienteId: clienteId, mecanicoId: mecanicoId, veiculoId: veiculoId,
                           status: StatusOrdemServico(rawAPI: status ?? ""))
    }
}

/// Envelope `{content[], page, size, total, totalPages}` (spec §7.2).
struct PageDTO<Item: Decodable>: Decodable {
    let content: [Item]?
    let page: Int?
    let size: Int?
    let total: Int?
    let totalPages: Int?

    func domain<Element: Equatable & Sendable>(_ transform: (Item) -> Element) -> Page<Element> {
        Page(content: (content ?? []).map(transform),
             page: page ?? 0, size: size ?? 20,
             total: total ?? content?.count ?? 0,
             totalPages: totalPages ?? 1)
    }
}

// MARK: - Notificações (`components/schemas/notificacao`)

struct NotificacaoResponseDTO: Decodable {
    let id: UUID
    let titulo: String?
    let assunto: String?
    let descricao: String?
    let tipoNotificacao: String?
    let tipoConteudo: String?
    let statusEnvio: String?
    let visualizada: Bool?
    let dataCriacao: Date?
    let dataEnvio: Date?
    let dataVisualizacao: Date?

    var domain: Notificacao {
        Notificacao(id: id, titulo: titulo ?? "", assunto: assunto ?? "", descricao: descricao ?? "",
                    tipoNotificacao: tipoNotificacao ?? "EMAIL",
                    tipoConteudo: tipoConteudo ?? "",
                    statusEnvio: Notificacao.StatusEnvio(rawValue: statusEnvio ?? "") ?? .desconhecido,
                    visualizada: visualizada ?? false,
                    dataCriacao: dataCriacao, dataEnvio: dataEnvio, dataVisualizacao: dataVisualizacao)
    }
}

struct ContadorNaoLidasResponseDTO: Decodable {
    let total: Int
}

// MARK: - Catálogo (`components/schemas/catalogo`)

struct CatalogoServicoResponseDTO: Decodable {
    let id: UUID
    let nomeServico: String?
    let descricaoServico: String?

    var domain: CatalogoServico {
        CatalogoServico(id: id, nomeServico: nomeServico ?? "", descricaoServico: descricaoServico ?? "")
    }
}

struct CatalogoInsumoResponseDTO: Decodable {
    let id: UUID
    let nome: String?
    let descricao: String?

    var domain: CatalogoInsumo {
        CatalogoInsumo(id: id, nome: nome ?? "", descricao: descricao ?? "")
    }
}
