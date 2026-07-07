import Foundation
import STNetworking

/// Ambiente local com mocks (diretriz do produto): responde às rotas do contrato
/// com as fixtures de `MockFixtures`, sem backend. Usado no scheme Debug.
public struct MockTransport: APITransport {
    let latencia: Duration

    public init(latencia: Duration = .milliseconds(250)) {
        self.latencia = latencia
    }

    public func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        try await Task.sleep(for: latencia)

        guard let url = request.url else { throw URLError(.badURL) }
        let metodo = request.httpMethod ?? "GET"
        let caminho = url.path

        let (status, corpo) = resposta(metodo: metodo, caminho: caminho)
        let http = HTTPURLResponse(url: url, statusCode: status,
                                   httpVersion: "HTTP/1.1",
                                   headerFields: ["Content-Type": "application/json"])!
        return (Data(corpo.utf8), http)
    }

    private func resposta(metodo: String, caminho: String) -> (Int, String) {
        switch (metodo, caminho) {
        // login: rota da spec e rota do índice OpenAPI (ADR-iOS-002 D4)
        case ("POST", "/autenticacao/login"), ("POST", "/autenticacao"):
            return (200, MockFixtures.loginResponse)
        case ("POST", "/autenticacao/reset-senha"):
            return (204, "")

        case ("POST", "/clientes"):
            return (201, MockFixtures.cliente)
        case ("GET", let p) where p.hasPrefix("/clientes/"):
            return (200, MockFixtures.cliente)
        case ("PUT", let p) where p.hasPrefix("/clientes/"):
            return (200, MockFixtures.cliente)
        case ("DELETE", let p) where p.hasPrefix("/clientes/"):
            return (204, "")

        case ("GET", "/veiculos"):
            return (200, MockFixtures.veiculos)
        case ("GET", "/veiculos/imagens/sugestoes"):
            return (200, MockFixtures.sugestoesImagens)
        case ("POST", "/veiculos"):
            return (201, MockFixtures.veiculo)
        case ("GET", let p) where p.hasPrefix("/veiculos/"):
            return (200, MockFixtures.veiculo)
        case ("PUT", let p) where p.hasPrefix("/veiculos/"):
            return (200, MockFixtures.veiculo)
        case ("DELETE", let p) where p.hasPrefix("/veiculos/"):
            return (204, "")

        case ("GET", "/ordem-servico/lista"):
            return (200, MockFixtures.pageOrdens)
        case ("POST", "/ordem-servico"):
            return (201, MockFixtures.ordemServicoRecebida)
        case ("POST", let p) where p.hasSuffix("/orcamento/aprovacao"):
            return (200, MockFixtures.resumoOrdem(status: "EM_EXECUCAO"))
        case ("POST", let p) where p.hasSuffix("/orcamento/reprovacao"):
            return (200, MockFixtures.resumoOrdem(status: "AGUARDANDO_APROVACAO"))
        case ("POST", let p) where p.hasSuffix("/cancelamento"):
            return (200, MockFixtures.resumoOrdem(status: "CANCELADA"))
        case ("GET", let p) where p.hasPrefix("/ordem-servico/"):
            return (200, MockFixtures.ordemServicoDetalhe)

        case ("GET", let p) where p.hasPrefix("/dashboard/clientes/"):
            return (200, MockFixtures.dashboard)

        case ("GET", "/notificacoes/nao-lidas/contagem"):
            return (200, #"{"total": 3}"#)
        case ("GET", "/notificacoes"):
            return (200, MockFixtures.pageNotificacoes)
        case ("PATCH", let p) where p.hasSuffix("/visualizar"):
            return (204, "")
        case ("GET", let p) where p.hasPrefix("/notificacoes/"):
            return (200, MockFixtures.notificacao)

        case ("GET", "/catalogo/servicos"):
            return (200, MockFixtures.catalogoServicos)
        case ("GET", "/catalogo/insumos"):
            return (200, MockFixtures.catalogoInsumos)

        default:
            return (404, #"{"mensagem": "Rota não mapeada no mock: \#(metodo) \#(caminho)"}"#)
        }
    }
}
