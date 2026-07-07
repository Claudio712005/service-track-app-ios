import Foundation
import STNetworking
import STDomain

/// Fonte única de método+caminho, derivada dos contratos `openApi/**`
/// (ADR-iOS-002: divergência futura se corrige aqui).
enum ServiceTrackAPI {
    // Autenticação — spec §7.3 usa `/autenticacao/login`; índice OpenAPI mapeia `/autenticacao` (D4).
    static func login(_ body: Data) -> Endpoint {
        Endpoint(method: .post, path: "/autenticacao/login", body: body)
    }

    static func resetSenha(_ body: Data) -> Endpoint {
        Endpoint(method: .post, path: "/autenticacao/reset-senha", body: body)
    }

    // Clientes
    static func cadastrarCliente(_ body: Data) -> Endpoint {
        Endpoint(method: .post, path: "/clientes", body: body)
    }

    static func cliente(_ id: UUID) -> Endpoint {
        Endpoint(method: .get, path: "/clientes/\(id.uuidString)")
    }

    static func atualizarCliente(_ id: UUID, _ body: Data) -> Endpoint {
        Endpoint(method: .put, path: "/clientes/\(id.uuidString)", body: body)
    }

    static func desativarCliente(_ id: UUID) -> Endpoint {
        Endpoint(method: .delete, path: "/clientes/\(id.uuidString)")
    }

    // Veículos
    static var veiculos: Endpoint {
        Endpoint(method: .get, path: "/veiculos")
    }

    static func veiculo(_ id: UUID) -> Endpoint {
        Endpoint(method: .get, path: "/veiculos/\(id.uuidString)")
    }

    static func cadastrarVeiculo(_ body: Data) -> Endpoint {
        Endpoint(method: .post, path: "/veiculos", body: body)
    }

    static func atualizarVeiculo(_ id: UUID, _ body: Data) -> Endpoint {
        Endpoint(method: .put, path: "/veiculos/\(id.uuidString)", body: body)
    }

    static func removerVeiculo(_ id: UUID) -> Endpoint {
        Endpoint(method: .delete, path: "/veiculos/\(id.uuidString)")
    }

    static func sugestoesImagens(marca: String, modelo: String) -> Endpoint {
        Endpoint(method: .get, path: "/veiculos/imagens/sugestoes",
                 query: [URLQueryItem(name: "marca", value: marca),
                         URLQueryItem(name: "modelo", value: modelo)])
    }

    // Ordens de Serviço
    static func abrirOrdemServico(_ body: Data) -> Endpoint {
        Endpoint(method: .post, path: "/ordem-servico", body: body)
    }

    /// Listagem vive em `/ordem-servico/lista` no contrato (ADR-iOS-002 D1).
    /// `clienteId`/`mecanicoId` não são enviados: ignorados para clientes (spec §2.3).
    static func listarOrdens(status: StatusOrdemServico?, page: Int, size: Int) -> Endpoint {
        var query = [URLQueryItem(name: "page", value: String(page)),
                     URLQueryItem(name: "size", value: String(size))]
        if let status {
            query.insert(URLQueryItem(name: "status", value: status.rawAPI), at: 0)
        }
        return Endpoint(method: .get, path: "/ordem-servico/lista", query: query)
    }

    static func ordemServico(_ id: UUID) -> Endpoint {
        Endpoint(method: .get, path: "/ordem-servico/\(id.uuidString)")
    }

    // Ações do cliente: POST no contrato, não PATCH (ADR-iOS-002 D2).
    static func aprovarOrcamento(_ osId: UUID) -> Endpoint {
        Endpoint(method: .post, path: "/ordem-servico/\(osId.uuidString)/orcamento/aprovacao")
    }

    static func reprovarOrcamento(_ osId: UUID, _ body: Data) -> Endpoint {
        Endpoint(method: .post, path: "/ordem-servico/\(osId.uuidString)/orcamento/reprovacao", body: body)
    }

    static func cancelarOrdemServico(_ osId: UUID, _ body: Data) -> Endpoint {
        Endpoint(method: .post, path: "/ordem-servico/\(osId.uuidString)/cancelamento", body: body)
    }

    // Dashboard
    static func dashboard(clienteId: UUID) -> Endpoint {
        Endpoint(method: .get, path: "/dashboard/clientes/\(clienteId.uuidString)")
    }

    // Notificações
    static func notificacoes(visualizada: Bool?, page: Int, size: Int) -> Endpoint {
        var query = [URLQueryItem(name: "page", value: String(page)),
                     URLQueryItem(name: "size", value: String(size))]
        if let visualizada {
            query.insert(URLQueryItem(name: "visualizada", value: String(visualizada)), at: 0)
        }
        return Endpoint(method: .get, path: "/notificacoes", query: query)
    }

    static func notificacao(_ id: UUID) -> Endpoint {
        Endpoint(method: .get, path: "/notificacoes/\(id.uuidString)")
    }

    static var contagemNaoLidas: Endpoint {
        Endpoint(method: .get, path: "/notificacoes/nao-lidas/contagem")
    }

    static func visualizarNotificacao(_ id: UUID) -> Endpoint {
        Endpoint(method: .patch, path: "/notificacoes/\(id.uuidString)/visualizar")
    }

    // Catálogo (somente leitura — spec §2.1)
    static var catalogoServicos: Endpoint {
        Endpoint(method: .get, path: "/catalogo/servicos")
    }

    static var catalogoInsumos: Endpoint {
        Endpoint(method: .get, path: "/catalogo/insumos")
    }
}
