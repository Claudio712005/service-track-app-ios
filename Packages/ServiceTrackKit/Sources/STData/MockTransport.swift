import Foundation
import STNetworking

/// Ambiente local com mocks (diretriz do produto): responde às rotas do contrato
/// com as fixtures de `MockFixtures`, sem backend. Usado no scheme Debug.
/// Stateful no ciclo da OS em destaque: aprovar/cancelar no app muda o status
/// devolvido pelos GETs seguintes — demo espelha a máquina de estados real.
public final class MockTransport: APITransport, @unchecked Sendable {
    let latencia: Duration
    private let lock = NSLock()
    private var statusOSDestaque = "AGUARDANDO_APROVACAO"

    public init(latencia: Duration = .milliseconds(250)) {
        self.latencia = latencia
    }

    private var statusAtual: String {
        lock.withLock { statusOSDestaque }
    }

    private func transicionar(para status: String) {
        lock.withLock { statusOSDestaque = status }
    }

    public func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        // Simulação de queda de rede p/ testar SWR/offline: ST_OFFLINE=1.
        if ProcessInfo.processInfo.environment["ST_OFFLINE"] == "1" {
            throw URLError(.notConnectedToInternet)
        }
        try await Task.sleep(for: latencia)

        guard let url = request.url else { throw URLError(.badURL) }
        let metodo = request.httpMethod ?? "GET"
        let caminho = url.path

        let (status, corpo) = resposta(metodo: metodo, caminho: caminho, query: url.query ?? "")
        let http = HTTPURLResponse(url: url, statusCode: status,
                                   httpVersion: "HTTP/1.1",
                                   headerFields: ["Content-Type": "application/json"])!
        return (Data(corpo.utf8), http)
    }

    private func resposta(metodo: String, caminho: String, query: String) -> (Int, String) {
        switch (metodo, caminho) {
        case ("POST", "/autenticacao"):
            return (200, MockFixtures.loginResponse)
        case ("PUT", "/usuarios/senha"):
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
            return (200, MockFixtures.pageOrdens(statusDestaque: statusAtual))
        case ("POST", "/ordem-servico"):
            return (201, MockFixtures.ordemServicoRecebida)
        case ("POST", let p) where p.hasSuffix("/orcamento/aprovacao"):
            // 409 se já decidida por outro canal (RN-07) — espelha o backend.
            guard statusAtual == "AGUARDANDO_APROVACAO" else {
                return (409, #"{"mensagem": "Status inválido para aprovação"}"#)
            }
            transicionar(para: "EM_EXECUCAO")
            return (200, MockFixtures.resumoOrdem(status: "EM_EXECUCAO"))
        case ("POST", let p) where p.hasSuffix("/orcamento/reprovacao"):
            guard statusAtual == "AGUARDANDO_APROVACAO" else {
                return (409, #"{"mensagem": "Status inválido para reprovação"}"#)
            }
            return (200, MockFixtures.resumoOrdem(status: "AGUARDANDO_APROVACAO"))
        case ("POST", let p) where p.hasSuffix("/cancelamento"):
            guard ["RECEBIDA", "EM_DIAGNOSTICO", "AGUARDANDO_APROVACAO", "EM_EXECUCAO"]
                .contains(statusAtual) else {
                return (409, #"{"mensagem": "Status inválido para cancelamento"}"#)
            }
            transicionar(para: "CANCELADA")
            return (200, MockFixtures.resumoOrdem(status: "CANCELADA"))
        case ("GET", let p) where p.hasPrefix("/ordem-servico/"):
            return (200, MockFixtures.ordemServicoDetalhe(status: statusAtual))

        case ("GET", let p) where p.hasPrefix("/dashboard/clientes/"):
            return (200, MockFixtures.dashboard)

        case ("GET", "/notificacoes/nao-lidas/contagem"):
            return (200, #"{"total": 3}"#)
        case ("GET", "/notificacoes"):
            let apenasNaoLidas = query.contains("visualizada=false")
            return (200, MockFixtures.pageNotificacoes(apenasNaoLidas: apenasNaoLidas))
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
