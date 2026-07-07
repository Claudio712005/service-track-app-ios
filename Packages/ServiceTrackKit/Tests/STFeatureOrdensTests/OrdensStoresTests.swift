import XCTest
import STDomain
@testable import STFeatureOrdens

// MARK: - Fakes

private final class OrdensRepoFake: OrdemServicoRepository, @unchecked Sendable {
    var paginas: [Page<ResumoOrdemServico>] = []
    var statusRecebidos: [StatusOrdemServico?] = []
    var detalhe: OrdemServico?
    var erroLista: AppError?
    var erroDecisao: AppError?
    var aprovadas = 0
    var canceladas: [String?] = []
    var buscas = 0

    func listar(status: StatusOrdemServico?, page: Int, size: Int) async throws -> Page<ResumoOrdemServico> {
        if let erroLista { throw erroLista }
        statusRecebidos.append(status)
        let indice = min(page, paginas.count - 1)
        return paginas[indice]
    }

    func buscar(id: UUID) async throws -> OrdemServico {
        buscas += 1
        return detalhe!
    }

    func abrir(motivo: String, clienteId: UUID, veiculoId: UUID, mecanicoId: UUID?,
               observacao: String?) async throws -> OrdemServico { fatalError("não usado") }

    func aprovarOrcamento(osId: UUID) async throws -> ResumoOrdemServico {
        if let erroDecisao { throw erroDecisao }
        aprovadas += 1
        detalhe?.status = .emExecucao
        return resumo(status: .emExecucao)
    }

    func reprovarOrcamento(osId: UUID, motivo: String) async throws -> ResumoOrdemServico {
        resumo(status: .aguardandoAprovacao)
    }

    func cancelar(osId: UUID, motivo: String?) async throws -> ResumoOrdemServico {
        canceladas.append(motivo)
        detalhe?.status = .cancelada
        return resumo(status: .cancelada)
    }

    private func resumo(status: StatusOrdemServico) -> ResumoOrdemServico {
        ResumoOrdemServico(id: UUID(), motivo: "m", observacao: nil, clienteId: nil,
                           mecanicoId: nil, veiculoId: nil, status: status)
    }
}

private struct CatalogoFake: CatalogoRepository {
    var itens: [CatalogoInsumo] = []

    func servicos() async throws -> [CatalogoServico] { [] }
    func insumos() async throws -> [CatalogoInsumo] { itens }
}

private func resumo(_ status: StatusOrdemServico) -> ResumoOrdemServico {
    ResumoOrdemServico(id: UUID(), motivo: "m", observacao: nil, clienteId: nil,
                       mecanicoId: nil, veiculoId: nil, status: status)
}

private func pagina(_ conteudo: [ResumoOrdemServico], page: Int = 0, totalPages: Int = 1) -> Page<ResumoOrdemServico> {
    Page(content: conteudo, page: page, size: 20, total: conteudo.count, totalPages: totalPages)
}

private func osFixture(status: StatusOrdemServico, insumos: [UUID] = []) -> OrdemServico {
    OrdemServico(id: UUID(), motivo: "Freios", observacao: nil, clienteId: nil, mecanicoId: nil,
                 veiculoId: nil, status: status, dataCriacao: .now, dataAtualizacao: .now,
                 itensServico: [], insumos: insumos,
                 orcamento: Orcamento(id: UUID(), custoMaoDeObra: 300, custoInsumos: 260.5,
                                      valorTotal: 560.5, aprovado: false, observacao: nil,
                                      dataCriacao: nil, dataAtualizacao: nil))
}

@MainActor
private func aguardar(_ condicao: @escaping () -> Bool) async throws {
    for _ in 0..<200 where !condicao() {
        try await Task.sleep(for: .milliseconds(10))
    }
    XCTAssertTrue(condicao(), "condição não satisfeita no tempo limite")
}

// MARK: - Lista

@MainActor
final class OrdensStoreTests: XCTestCase {
    func testFiltrosDiretosViramQuery() async throws {
        let repo = OrdensRepoFake()
        repo.paginas = [pagina([resumo(.cancelada)])]
        let s = OrdensStore(repo: repo)
        s.send(.filtroAlterado(.canceladas))
        try await aguardar { !repo.statusRecebidos.isEmpty }
        XCTAssertEqual(repo.statusRecebidos.last, .cancelada)
    }

    func testFiltroAtivasFiltraClientSide() async throws {
        // Spec §15.4: "Ativas" agrega estados — sem status na query.
        let repo = OrdensRepoFake()
        repo.paginas = [pagina([resumo(.recebida), resumo(.entregue),
                                resumo(.emExecucao), resumo(.cancelada)])]
        let s = OrdensStore(repo: repo)
        s.send(.filtroAlterado(.ativas))
        try await aguardar { s.estado.fase == .conteudo }
        XCTAssertEqual(repo.statusRecebidos.last!, nil)
        XCTAssertEqual(s.estado.visiveis.map(\.status), [.recebida, .emExecucao])
    }

    func testFiltroConcluidasIncluiFinalizadaEEntregue() async throws {
        let repo = OrdensRepoFake()
        repo.paginas = [pagina([resumo(.finalizada), resumo(.entregue), resumo(.recebida)])]
        let s = OrdensStore(repo: repo)
        s.send(.filtroAlterado(.concluidas))
        try await aguardar { s.estado.fase == .conteudo }
        XCTAssertEqual(s.estado.visiveis.count, 2)
    }

    func testPaginacaoInfinitaAcumula() async throws {
        let repo = OrdensRepoFake()
        repo.paginas = [pagina([resumo(.recebida)], page: 0, totalPages: 2),
                        pagina([resumo(.entregue)], page: 1, totalPages: 2)]
        let s = OrdensStore(repo: repo)
        s.send(.aparecer)
        try await aguardar { s.estado.fase == .conteudo }
        XCTAssertTrue(s.estado.temMais)

        s.send(.chegouAoFim)
        try await aguardar { s.estado.ordens.count == 2 }
        XCTAssertFalse(s.estado.temMais)
    }

    func testErroInicialViraEstadoErro() async throws {
        let repo = OrdensRepoFake()
        repo.erroLista = .servidor(status: 500)
        let s = OrdensStore(repo: repo)
        s.send(.aparecer)
        try await aguardar { s.estado.fase == .erro(.servidor(status: 500)) }
    }
}

// MARK: - Detalhe

@MainActor
final class OrdemDetalheStoreTests: XCTestCase {
    private func store(repo: OrdensRepoFake, catalogo: CatalogoFake = CatalogoFake()) -> OrdemDetalheStore {
        OrdemDetalheStore(osId: UUID(), ordens: repo, catalogo: catalogo)
    }

    func testCargaAgregaInsumosENomes() async {
        let idOleo = UUID()
        let idPastilha = UUID()
        let repo = OrdensRepoFake()
        repo.detalhe = osFixture(status: .aguardandoAprovacao,
                                 insumos: [idOleo, idOleo, idPastilha])
        let catalogo = CatalogoFake(itens: [CatalogoInsumo(id: idOleo, nome: "Óleo 5W30", descricao: "")])
        let s = store(repo: repo, catalogo: catalogo)
        await s.carregar()

        XCTAssertEqual(s.estado.fase, .conteudo)
        XCTAssertEqual(s.estado.insumosAgregados.first?.quantidade, 2)
        XCTAssertEqual(s.estado.nomesInsumos[idOleo], "Óleo 5W30")
    }

    func testAprovarRefazOFetchEMostraNovoStatus() async throws {
        let repo = OrdensRepoFake()
        repo.detalhe = osFixture(status: .aguardandoAprovacao)
        let s = store(repo: repo)
        await s.carregar()
        let buscasAntes = repo.buscas

        s.send(.aprovar)
        try await aguardar { s.estado.ordem?.status == .emExecucao }
        XCTAssertEqual(repo.aprovadas, 1)
        XCTAssertGreaterThan(repo.buscas, buscasAntes)
        XCTAssertNotNil(s.estado.sucessoAcao)
    }

    func testConflito409RecarregaEExplica() async throws {
        // RN-07: decidido pelo magic link do e-mail.
        let repo = OrdensRepoFake()
        repo.detalhe = osFixture(status: .emExecucao)
        repo.erroDecisao = .conflitoEstado(mensagem: nil)
        let s = store(repo: repo)
        await s.carregar()

        s.send(.aprovar)
        try await aguardar { s.estado.erroAcao != nil }
        XCTAssertTrue(s.estado.erroAcao!.contains("outro canal"))
    }

    func testCancelarComMotivoOpcional() async throws {
        // RN-06: motivo é opcional no cancelamento.
        let repo = OrdensRepoFake()
        repo.detalhe = osFixture(status: .recebida)
        let s = store(repo: repo)
        await s.carregar()

        s.send(.cancelar(motivo: nil))
        try await aguardar { s.estado.ordem?.status == .cancelada }
        XCTAssertEqual(repo.canceladas, [nil])
    }
}

// MARK: - Ações por estado (spec §5.3, garantia extra sobre a state machine)

final class AcoesPorEstadoTests: XCTestCase {
    func testTimelineJornadaNaoIncluiCancelada() {
        XCTAssertEqual(StatusOrdemServico.jornada.count, 6)
        XCTAssertFalse(StatusOrdemServico.jornada.contains(.cancelada))
    }
}
