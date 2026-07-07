import Foundation
import STDomain

// Dashboard responde em snake_case (spec §9 C2): CodingKeys explícitos,
// isolados neste arquivo — nunca aplicar .convertFromSnakeCase global.

struct DashboardClienteResponseDTO: Decodable {
    let usuarioId: UUID
    let usuarioNome: String?
    let resumo: ResumoDashboardDTO
    let ordensAtivas: [OrdemAtivaDashboardDTO]?
    let ordensRecentes: [OrdemRecenteDashboardDTO]?
    let veiculos: [VeiculoDashboardDTO]?
    let dataAtualizacao: Date?

    enum CodingKeys: String, CodingKey {
        case usuarioId = "usuario_id"
        case usuarioNome = "usuario_nome"
        case resumo
        case ordensAtivas = "ordens_ativas"
        case ordensRecentes = "ordens_recentes"
        case veiculos
        case dataAtualizacao = "data_atualizacao"
    }

    var domain: DashboardCliente {
        DashboardCliente(usuarioId: usuarioId, usuarioNome: usuarioNome,
                         resumo: resumo.domain,
                         ordensAtivas: (ordensAtivas ?? []).map(\.domain),
                         ordensRecentes: (ordensRecentes ?? []).map(\.domain),
                         veiculos: (veiculos ?? []).map(\.domain),
                         dataAtualizacao: dataAtualizacao)
    }
}

struct ResumoDashboardDTO: Decodable {
    let ordensAtivas: Int
    let ordensConcluidas: Int
    /// Não requerido no schema (ADR-iOS-002 D6).
    let ordensCanceladas: Int?
    let totalOrdens: Int
    let veiculosCadastrados: Int

    enum CodingKeys: String, CodingKey {
        case ordensAtivas = "ordens_ativas"
        case ordensConcluidas = "ordens_concluidas"
        case ordensCanceladas = "ordens_canceladas"
        case totalOrdens = "total_ordens"
        case veiculosCadastrados = "veiculos_cadastrados"
    }

    var domain: ResumoDashboard {
        ResumoDashboard(ordensAtivas: ordensAtivas, ordensConcluidas: ordensConcluidas,
                        ordensCanceladas: ordensCanceladas ?? 0, totalOrdens: totalOrdens,
                        veiculosCadastrados: veiculosCadastrados)
    }
}

struct OrdemAtivaDashboardDTO: Decodable {
    let id: UUID
    let motivo: String?
    let status: String?
    let veiculoId: UUID?
    let veiculoPlaca: String?
    let veiculoModelo: String?
    let mecanicoId: UUID?
    let mecanicoNome: String?
    let dataCriacao: Date?
    let dataAtualizacao: Date?
    let diasEmAndamento: Int?
    let valorOrcado: Double?
    let prazoConclusao: Date?

    enum CodingKeys: String, CodingKey {
        case id, motivo, status
        case veiculoId = "veiculo_id"
        case veiculoPlaca = "veiculo_placa"
        case veiculoModelo = "veiculo_modelo"
        case mecanicoId = "mecanico_id"
        case mecanicoNome = "mecanico_nome"
        case dataCriacao = "data_criacao"
        case dataAtualizacao = "data_atualizacao"
        case diasEmAndamento = "dias_em_andamento"
        case valorOrcado = "valor_orcado"
        case prazoConclusao = "prazo_conclusao"
    }

    var domain: OrdemAtivaDashboard {
        OrdemAtivaDashboard(id: id, motivo: motivo ?? "",
                            status: StatusOrdemServico(rawAPI: status ?? ""),
                            veiculoId: veiculoId, veiculoPlaca: veiculoPlaca,
                            veiculoModelo: veiculoModelo, mecanicoId: mecanicoId,
                            mecanicoNome: mecanicoNome, dataCriacao: dataCriacao,
                            dataAtualizacao: dataAtualizacao, diasEmAndamento: diasEmAndamento,
                            valorOrcado: valorOrcado, prazoConclusao: prazoConclusao)
    }
}

struct OrdemRecenteDashboardDTO: Decodable {
    let id: UUID
    let motivo: String?
    /// Schema usa enums legados (DIAGNOSTICO, APROVADO…) — o enum tolerante resolve (C1).
    let status: String?
    let veiculoId: UUID?
    let veiculoPlaca: String?
    let veiculoModelo: String?
    let dataCriacao: Date?
    let dataConclusao: Date?
    let diasParaConclusao: Int?
    let valorTotal: Double?
    let mecanicoNome: String?

    enum CodingKeys: String, CodingKey {
        case id, motivo, status
        case veiculoId = "veiculo_id"
        case veiculoPlaca = "veiculo_placa"
        case veiculoModelo = "veiculo_modelo"
        case dataCriacao = "data_criacao"
        case dataConclusao = "data_conclusao"
        case diasParaConclusao = "dias_para_conclusao"
        case valorTotal = "valor_total"
        case mecanicoNome = "mecanico_nome"
    }

    var domain: OrdemRecenteDashboard {
        OrdemRecenteDashboard(id: id, motivo: motivo ?? "",
                              status: StatusOrdemServico(rawAPI: status ?? ""),
                              veiculoId: veiculoId, veiculoPlaca: veiculoPlaca,
                              veiculoModelo: veiculoModelo, dataCriacao: dataCriacao,
                              dataConclusao: dataConclusao, diasParaConclusao: diasParaConclusao,
                              valorTotal: valorTotal, mecanicoNome: mecanicoNome)
    }
}

struct VeiculoDashboardDTO: Decodable {
    let id: UUID
    let placa: String?
    let marca: String?
    let modelo: String?
    let ano: Int?
    let imagemUrl: String?
    let codigoFipe: String?
    let ativo: Bool?
    let totalOrdens: Int?
    let totalGasto: Double?
    let dataCriacao: Date?

    enum CodingKeys: String, CodingKey {
        case id, placa, marca, modelo, ano, ativo
        case imagemUrl = "imagem_url"
        case codigoFipe = "codigo_fipe"
        case totalOrdens = "total_ordens"
        case totalGasto = "total_gasto"
        case dataCriacao = "data_criacao"
    }

    var domain: VeiculoDashboard {
        VeiculoDashboard(id: id, placa: placa ?? "", marca: marca ?? "", modelo: modelo ?? "",
                         ano: ano ?? 0, imagemUrl: imagemUrl.flatMap(URL.init(string:)),
                         codigoFipe: codigoFipe, ativo: ativo ?? true,
                         totalOrdens: totalOrdens, totalGasto: totalGasto, dataCriacao: dataCriacao)
    }
}
