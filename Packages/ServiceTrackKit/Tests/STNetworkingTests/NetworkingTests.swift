import XCTest
import STDomain
@testable import STNetworking

final class ErrorMapperTests: XCTestCase {
    // ADR-iOS-002 D5: as duas formas de corpo de erro.
    func testErroFormatoGeral() {
        let corpo = Data(#"{"mensagem":"Email ou CPF já cadastrado","detalhe":"..."}"#.utf8)
        let erro = ErrorMapper.map(status: 400, data: corpo)
        XCTAssertEqual(erro, .validacao(campo: nil, mensagem: "Email ou CPF já cadastrado"))
    }

    func testErroFormatoDashboard() {
        let corpo = Data(#"{"status_code":403,"mensagem":"Acesso proibido"}"#.utf8)
        let erro = ErrorMapper.map(status: 403, data: corpo)
        XCTAssertEqual(erro, .semPermissao(mensagem: "Acesso proibido"))
    }

    func testMapaHTTPCompleto() {
        let vazio = Data()
        XCTAssertEqual(ErrorMapper.map(status: 401, data: vazio), .naoAutenticado)
        XCTAssertEqual(ErrorMapper.map(status: 404, data: vazio), .naoEncontrado(mensagem: nil))
        XCTAssertEqual(ErrorMapper.map(status: 409, data: vazio), .conflitoEstado(mensagem: nil))
        XCTAssertEqual(ErrorMapper.map(status: 500, data: vazio), .servidor(status: 500))
        XCTAssertEqual(ErrorMapper.map(status: 429, data: vazio, headers: ["Retry-After": "30"]),
                       .rateLimited(retryAfter: 30))
    }
}

final class DateParsingTests: XCTestCase {
    // Spec §11.4 (C5): parser aceita todas as variações da API.
    func testFormatosDeData() {
        XCTAssertNotNil(STJSON.parseDate("2024-11-16T15:45:30Z"))
        XCTAssertNotNil(STJSON.parseDate("2024-06-01T14:30:00"))
        XCTAssertNotNil(STJSON.parseDate("2024-06-01T14:30:00.123"))
        XCTAssertNotNil(STJSON.parseDate("1990-01-15"))
        XCTAssertNil(STJSON.parseDate("ontem"))
    }
}

/// Transport stub que conta chamadas e devolve uma sequência de respostas.
private final class TransportStub: APITransport, @unchecked Sendable {
    var respostas: [(Int, Data)]
    var chamadas = 0

    init(_ respostas: [(Int, Data)]) {
        self.respostas = respostas
    }

    func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        let (status, data) = respostas[min(chamadas, respostas.count - 1)]
        chamadas += 1
        let http = HTTPURLResponse(url: request.url!, statusCode: status,
                                   httpVersion: nil, headerFields: nil)!
        return (data, http)
    }
}

final class APIClientRetryTests: XCTestCase {
    private func client(_ stub: TransportStub) -> APIClient {
        APIClient(baseURL: URL(string: "http://localhost:8080")!,
                  transport: stub,
                  retryDelays: [.milliseconds(1), .milliseconds(1)])
    }

    // Spec §12.2: GET (idempotente) tem retry automático em 5xx.
    func testRetryEmGETApos5xx() async throws {
        let stub = TransportStub([(500, Data()), (200, Data(#"{"total": 1}"#.utf8))])
        struct Resp: Decodable { let total: Int }
        let resp: Resp = try await client(stub).send(Endpoint(method: .get, path: "/x"))
        XCTAssertEqual(resp.total, 1)
        XCTAssertEqual(stub.chamadas, 2)
    }

    // RN-09: POST não tem retry automático (evitar dupla execução).
    func testSemRetryEmPOST() async {
        let stub = TransportStub([(500, Data())])
        do {
            try await client(stub).send(Endpoint(method: .post, path: "/x"))
            XCTFail("Deveria falhar")
        } catch {
            XCTAssertEqual(stub.chamadas, 1)
        }
    }

    // 4xx nunca é retry — o erro é do cliente.
    func testSemRetryEm4xx() async {
        let stub = TransportStub([(404, Data())])
        do {
            try await client(stub).send(Endpoint(method: .get, path: "/x"))
            XCTFail("Deveria falhar")
        } catch let erro as AppError {
            XCTAssertEqual(erro, .naoEncontrado(mensagem: nil))
            XCTAssertEqual(stub.chamadas, 1)
        } catch {
            XCTFail("Erro inesperado: \(error)")
        }
    }

    func testHeadersDeAuthETrace() throws {
        struct Provider: AuthTokenProvider {
            let token: String? = "abc123"
        }
        let client = APIClient(baseURL: URL(string: "http://localhost:8080")!,
                               transport: TransportStub([(200, Data())]),
                               tokenProvider: Provider())
        let request = try client.makeRequest(Endpoint(method: .get, path: "/veiculos"))
        XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer abc123")
        XCTAssertNotNil(request.value(forHTTPHeaderField: "X-Request-Id"))
    }
}
