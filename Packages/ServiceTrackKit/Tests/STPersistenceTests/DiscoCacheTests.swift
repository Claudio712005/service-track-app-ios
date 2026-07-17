import XCTest
import STDomain
@testable import STPersistence

final class DiscoCacheTests: XCTestCase {
    private var pasta: String!
    private var cache: DiscoCache!

    override func setUp() {
        super.setUp()
        pasta = "ServiceTrackCacheTests-\(UUID().uuidString)"
        cache = DiscoCache(pasta: pasta)
    }

    override func tearDown() {
        if let base = FileManager.default.urls(for: .applicationSupportDirectory,
                                               in: .userDomainMask).first {
            try? FileManager.default.removeItem(at: base.appending(path: pasta))
        }
        super.tearDown()
    }

    struct Dado: Codable, Equatable {
        let nome: String
        let valor: Int
    }

    func testRoundTripComCarimbo() async {
        await cache.gravar(Dado(nome: "a", valor: 1), chave: "x")
        let entrada = await cache.ler(Dado.self, chave: "x")
        XCTAssertEqual(entrada?.valor, Dado(nome: "a", valor: 1))
        XCTAssertFalse(entrada!.vencida(ttl: 60))
        XCTAssertTrue(entrada!.vencida(ttl: 60, agora: .now.addingTimeInterval(120)))
    }

    func testChaveInexistente() async {
        let entrada = await cache.ler(Dado.self, chave: "nada")
        XCTAssertNil(entrada)
    }

    func testInvalidar() async {
        await cache.gravar(Dado(nome: "a", valor: 1), chave: "x")
        await cache.invalidar(chaves: ["x"])
        let entrada = await cache.ler(Dado.self, chave: "x")
        XCTAssertNil(entrada)
    }

    func testTipoIncompativelNaoQuebra() async {
        // Decodificação defensiva: mudança de schema entre versões → cache miss.
        await cache.gravar(["array", "de", "strings"], chave: "x")
        let entrada = await cache.ler(Dado.self, chave: "x")
        XCTAssertNil(entrada)
    }

    func testSobrescreveAtualizaCarimbo() async {
        await cache.gravar(Dado(nome: "a", valor: 1), chave: "x")
        await cache.gravar(Dado(nome: "b", valor: 2), chave: "x")
        let entrada = await cache.ler(Dado.self, chave: "x")
        XCTAssertEqual(entrada?.valor.nome, "b")
    }
}

final class StatusCodableTests: XCTestCase {
    func testRoundTripEDecodificacaoTolerante() throws {
        // Cache antigo com sinônimo legado não quebra (ADR-iOS-005).
        let data = Data(#""APROVADO""#.utf8)
        let status = try JSONDecoder().decode(StatusOrdemServico.self, from: data)
        XCTAssertEqual(status, .emExecucao)

        let codificado = try JSONEncoder().encode(StatusOrdemServico.aguardandoAprovacao)
        XCTAssertEqual(String(data: codificado, encoding: .utf8), #""AGUARDANDO_APROVACAO""#)
    }
}
