import XCTest
import STDomain
@testable import STFeatureCatalogo

private struct CatalogoRepoFake: CatalogoRepository {
    var servicosResultado: Result<[CatalogoServico], AppError> = .success([])
    var insumosResultado: Result<[CatalogoInsumo], AppError> = .success([])

    func servicos() async throws -> [CatalogoServico] { try servicosResultado.get() }
    func insumos() async throws -> [CatalogoInsumo] { try insumosResultado.get() }
}

@MainActor
final class CatalogoStoreTests: XCTestCase {
    func testCargaParalelaDeServicosEInsumos() async {
        var repo = CatalogoRepoFake()
        repo.servicosResultado = .success([CatalogoServico(id: UUID(), nomeServico: "Troca de Óleo",
                                                           descricaoServico: "d")])
        repo.insumosResultado = .success([CatalogoInsumo(id: UUID(), nome: "Óleo 5W30", descricao: "d")])
        let s = CatalogoStore(repo: repo)
        await s.carregar()

        guard case .conteudo(let servicos, let insumos) = s.fase else {
            return XCTFail("esperava conteúdo")
        }
        XCTAssertEqual(servicos.first?.nomeServico, "Troca de Óleo")
        XCTAssertEqual(insumos.first?.nome, "Óleo 5W30")
    }

    func testErroViraEstadoErro() async {
        var repo = CatalogoRepoFake()
        repo.servicosResultado = .failure(.servidor(status: 500))
        let s = CatalogoStore(repo: repo)
        await s.carregar()
        XCTAssertEqual(s.fase, .erro(.servidor(status: 500)))
    }
}
