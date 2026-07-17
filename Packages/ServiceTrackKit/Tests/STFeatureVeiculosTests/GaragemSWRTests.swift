import XCTest
import STDomain
@testable import STFeatureVeiculos

/// Fake de cache local ao teste (evita dependência de STPersistence no target).
private final class CacheFake: CacheStore, @unchecked Sendable {
    private let lock = NSLock()
    var dados: [String: (Any, Date)] = [:]
    var invalidadas: [String] = []

    func ler<T: Codable & Sendable>(_ tipo: T.Type, chave: String) async -> CacheEntrada<T>? {
        lock.withLock {
            guard let (valor, data) = dados[chave], let tipado = valor as? T else { return nil }
            return CacheEntrada(valor: tipado, fetchedAt: data)
        }
    }

    func gravar<T: Codable & Sendable>(_ valor: T, chave: String) async {
        lock.withLock { dados[chave] = (valor, .now) }
    }

    func invalidar(chaves: [String]) async {
        lock.withLock { invalidadas.append(contentsOf: chaves) }
    }
}

private final class VeiculosLento: VeiculoRepository, @unchecked Sendable {
    var lista: Result<[Veiculo], AppError> = .success([])

    func listar() async throws -> [Veiculo] { try lista.get() }
    func buscar(id: UUID) async throws -> Veiculo { fatalError() }
    func cadastrar(placa: String, modelo: String, marca: String, ano: Int,
                   proprietarioId: UUID, urlImagem: URL?) async throws -> Veiculo { fatalError() }
    func atualizar(id: UUID, placa: String, modelo: String, marca: String, ano: Int,
                   urlImagem: URL?) async throws -> Veiculo { fatalError() }
    func remover(id: UUID) async throws {}
    func sugestoesDeImagem(marca: String, modelo: String) async throws -> [URL] { [] }
}

private func veiculo(_ modelo: String) -> Veiculo {
    Veiculo(id: UUID(), placa: "ABC1D23", marca: "Toyota", modelo: modelo, ano: 2022,
            proprietarioId: nil, urlImagem: nil, codigoFipe: nil)
}

@MainActor
final class GaragemSWRTests: XCTestCase {
    func testRedeGravaNoCache() async {
        let cache = CacheFake()
        let repo = VeiculosLento()
        repo.lista = .success([veiculo("Corolla")])
        let s = GaragemStore(veiculos: repo, cache: cache)
        await s.carregar()
        let entrada = await cache.ler([Veiculo].self, chave: CacheChave.veiculos)
        XCTAssertEqual(entrada?.valor.first?.modelo, "Corolla")
    }

    func testOfflineComCacheMostraDadosSalvos() async {
        // Spec §11.3: leitura offline a partir do cache + banner.
        let cache = CacheFake()
        await cache.gravar([veiculo("Gol")], chave: CacheChave.veiculos)
        let repo = VeiculosLento()
        repo.lista = .failure(.rede)
        let s = GaragemStore(veiculos: repo, cache: cache)
        await s.carregar()

        guard case .conteudo(let lista) = s.fase else { return XCTFail("esperava cache") }
        XCTAssertEqual(lista.first?.modelo, "Gol")
        XCTAssertTrue(s.offline)
    }

    func testOfflineSemCacheViraErro() async {
        let repo = VeiculosLento()
        repo.lista = .failure(.rede)
        let s = GaragemStore(veiculos: repo, cache: CacheFake())
        await s.carregar()
        XCTAssertEqual(s.fase, .erro(.rede))
    }

    func testRedeDeVoltaLimpaOffline() async {
        let cache = CacheFake()
        await cache.gravar([veiculo("Gol")], chave: CacheChave.veiculos)
        let repo = VeiculosLento()
        repo.lista = .failure(.rede)
        let s = GaragemStore(veiculos: repo, cache: cache)
        await s.carregar()
        XCTAssertTrue(s.offline)

        repo.lista = .success([veiculo("Corolla")])
        await s.carregar(silencioso: true)
        XCTAssertFalse(s.offline)
        guard case .conteudo(let lista) = s.fase else { return XCTFail() }
        XCTAssertEqual(lista.first?.modelo, "Corolla")
    }

    func testRemoverInvalidaVeiculosEDashboard() async throws {
        let cache = CacheFake()
        var removido = false
        let s = VeiculoDetalheStore(veiculo: veiculo("Gol"), veiculos: VeiculosLento(),
                                    ordens: OrdensVazio(), cache: cache) { removido = true }
        s.send(.remover)
        for _ in 0..<200 where !removido {
            try await Task.sleep(for: .milliseconds(10))
        }
        XCTAssertEqual(Set(cache.invalidadas), Set([CacheChave.veiculos, CacheChave.dashboard]))
    }
}

private final class OrdensVazio: OrdemServicoRepository, @unchecked Sendable {
    func listar(status: StatusOrdemServico?, page: Int, size: Int) async throws -> Page<ResumoOrdemServico> {
        Page(content: [], page: 0, size: 100, total: 0, totalPages: 1)
    }
    func buscar(id: UUID) async throws -> OrdemServico { fatalError() }
    func abrir(motivo: String, clienteId: UUID, veiculoId: UUID, mecanicoId: UUID?,
               observacao: String?) async throws -> OrdemServico { fatalError() }
    func aprovarOrcamento(osId: UUID) async throws -> ResumoOrdemServico { fatalError() }
    func reprovarOrcamento(osId: UUID, motivo: String) async throws -> ResumoOrdemServico { fatalError() }
    func cancelar(osId: UUID, motivo: String?) async throws -> ResumoOrdemServico { fatalError() }
}
