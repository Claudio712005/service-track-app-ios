import XCTest
import STDomain
@testable import STFeatureVeiculos

// MARK: - Fakes

private final class VeiculosFake: VeiculoRepository, @unchecked Sendable {
    var lista: [Veiculo] = []
    var erroLista: AppError?
    var sugestoes: Result<[URL], AppError> = .success([])
    var cadastrados: [(placa: String, proprietarioId: UUID, urlImagem: URL?)] = []
    var atualizados: [UUID] = []
    var removidos: [UUID] = []

    func listar() async throws -> [Veiculo] {
        if let erroLista { throw erroLista }
        return lista
    }

    func buscar(id: UUID) async throws -> Veiculo { fatalError("não usado") }

    func cadastrar(placa: String, modelo: String, marca: String, ano: Int,
                   proprietarioId: UUID, urlImagem: URL?) async throws -> Veiculo {
        cadastrados.append((placa, proprietarioId, urlImagem))
        return Veiculo(id: UUID(), placa: placa, marca: marca, modelo: modelo, ano: ano,
                       proprietarioId: proprietarioId, urlImagem: urlImagem, codigoFipe: nil)
    }

    func atualizar(id: UUID, placa: String, modelo: String, marca: String, ano: Int,
                   urlImagem: URL?) async throws -> Veiculo {
        atualizados.append(id)
        return Veiculo(id: id, placa: placa, marca: marca, modelo: modelo, ano: ano,
                       proprietarioId: nil, urlImagem: urlImagem, codigoFipe: nil)
    }

    func remover(id: UUID) async throws {
        removidos.append(id)
    }

    func sugestoesDeImagem(marca: String, modelo: String) async throws -> [URL] {
        try sugestoes.get()
    }
}

private final class OrdensFake: OrdemServicoRepository, @unchecked Sendable {
    var pagina: Page<ResumoOrdemServico> = Page(content: [], page: 0, size: 100, total: 0, totalPages: 1)

    func listar(status: StatusOrdemServico?, page: Int, size: Int) async throws -> Page<ResumoOrdemServico> {
        pagina
    }
    func buscar(id: UUID) async throws -> OrdemServico { fatalError("não usado") }
    func abrir(motivo: String, clienteId: UUID, veiculoId: UUID, mecanicoId: UUID?,
               observacao: String?) async throws -> OrdemServico { fatalError("não usado") }
    func aprovarOrcamento(osId: UUID) async throws -> ResumoOrdemServico { fatalError("não usado") }
    func reprovarOrcamento(osId: UUID, motivo: String) async throws -> ResumoOrdemServico { fatalError("não usado") }
    func cancelar(osId: UUID, motivo: String?) async throws -> ResumoOrdemServico { fatalError("não usado") }
}

private func veiculoFixture(id: UUID = UUID()) -> Veiculo {
    Veiculo(id: id, placa: "ABC1D23", marca: "Toyota", modelo: "Corolla", ano: 2022,
            proprietarioId: nil, urlImagem: nil, codigoFipe: nil)
}

private func resumoOS(veiculoId: UUID?, status: StatusOrdemServico = .entregue) -> ResumoOrdemServico {
    ResumoOrdemServico(id: UUID(), motivo: "m", observacao: nil, clienteId: nil,
                       mecanicoId: nil, veiculoId: veiculoId, status: status)
}

@MainActor
private func aguardar(_ condicao: @escaping () -> Bool) async throws {
    for _ in 0..<200 where !condicao() {
        try await Task.sleep(for: .milliseconds(10))
    }
    XCTAssertTrue(condicao(), "condição não satisfeita no tempo limite")
}

// MARK: - Garagem

@MainActor
final class GaragemStoreTests: XCTestCase {
    func testListaViraConteudo() async {
        let repo = VeiculosFake()
        repo.lista = [veiculoFixture()]
        let s = GaragemStore(veiculos: repo)
        await s.carregar()
        guard case .conteudo(let lista) = s.fase else { return XCTFail("esperava conteúdo") }
        XCTAssertEqual(lista.count, 1)
    }

    func testListaVaziaViraVazio() async {
        let s = GaragemStore(veiculos: VeiculosFake())
        await s.carregar()
        XCTAssertEqual(s.fase, .vazio)
    }

    func testErroViraEstadoErro() async {
        let repo = VeiculosFake()
        repo.erroLista = .servidor(status: 500)
        let s = GaragemStore(veiculos: repo)
        await s.carregar()
        XCTAssertEqual(s.fase, .erro(.servidor(status: 500)))
    }
}

// MARK: - Detalhe

@MainActor
final class VeiculoDetalheStoreTests: XCTestCase {
    func testHistoricoFiltraPorVeiculo() async throws {
        // RF08: histórico por veículo é filtro client-side (spec §15.9).
        let veiculo = veiculoFixture()
        let ordens = OrdensFake()
        ordens.pagina = Page(content: [resumoOS(veiculoId: veiculo.id),
                                       resumoOS(veiculoId: UUID()),
                                       resumoOS(veiculoId: veiculo.id)],
                             page: 0, size: 100, total: 3, totalPages: 1)
        let s = VeiculoDetalheStore(veiculo: veiculo, veiculos: VeiculosFake(), ordens: ordens) {}
        s.send(.aparecer)
        try await aguardar { !s.estado.carregandoHistorico && !s.estado.historico.isEmpty }
        XCTAssertEqual(s.estado.historico.count, 2)
    }

    func testRemoverChamaRepoENotifica() async throws {
        let veiculo = veiculoFixture()
        let repo = VeiculosFake()
        var removido = false
        let s = VeiculoDetalheStore(veiculo: veiculo, veiculos: repo, ordens: OrdensFake()) {
            removido = true
        }
        s.send(.remover)
        try await aguardar { removido }
        XCTAssertEqual(repo.removidos, [veiculo.id])
    }
}

// MARK: - Formulário

@MainActor
final class VeiculoFormStoreTests: XCTestCase {
    private func store(repo: VeiculosFake = VeiculosFake(),
                       proprietarioId: UUID = UUID(),
                       aoSalvar: @escaping (Veiculo) -> Void = { _ in }) -> VeiculoFormStore {
        VeiculoFormStore(modo: .criar, veiculos: repo, proprietarioId: proprietarioId, aoSalvar: aoSalvar)
    }

    func testIdentificacaoObrigatoria() {
        let s = store()
        s.send(.avancar)
        XCTAssertEqual(s.estado.etapa, .identificacao)
        XCTAssertNotNil(s.estado.erros[.marca])
        XCTAssertNotNil(s.estado.erros[.modelo])
    }

    func testValidacaoDeAnoEPlaca() {
        let s = store()
        s.send(.campoAlterado(.marca, "Toyota"))
        s.send(.campoAlterado(.modelo, "Corolla"))
        s.send(.avancar) // → imagem
        s.send(.avancar) // → dados (imagem opcional)

        s.send(.campoAlterado(.ano, "1800"))
        s.send(.campoAlterado(.placa, "AB123"))
        s.send(.avancar)
        XCTAssertNotNil(s.estado.erros[.ano])
        XCTAssertNotNil(s.estado.erros[.placa])
        XCTAssertEqual(s.estado.etapa, .dados)
    }

    func testSugestoesFalhamSemBloquear() async throws {
        // RN-11: Unsplash é best-effort.
        let repo = VeiculosFake()
        repo.sugestoes = .failure(.servidor(status: 503))
        var salvo: Veiculo?
        let s = store(repo: repo) { salvo = $0 }

        s.send(.campoAlterado(.marca, "Toyota"))
        s.send(.campoAlterado(.modelo, "Corolla"))
        s.send(.avancar)
        try await aguardar { s.estado.sugestoesFalharam }

        s.send(.avancar)
        s.send(.campoAlterado(.ano, "2022"))
        s.send(.campoAlterado(.placa, "abc-1d23"))
        s.send(.avancar)
        try await aguardar { salvo != nil }
        XCTAssertNil(salvo?.urlImagem)
    }

    func testSalvarNormalizaPlacaEUsaProprietarioDaSessao() async throws {
        let repo = VeiculosFake()
        let dono = UUID()
        var salvo: Veiculo?
        let s = store(repo: repo, proprietarioId: dono) { salvo = $0 }

        s.send(.campoAlterado(.marca, "Toyota"))
        s.send(.campoAlterado(.modelo, "Corolla"))
        s.send(.avancar)
        s.send(.avancar)
        s.send(.campoAlterado(.ano, "2022"))
        s.send(.campoAlterado(.placa, "abc1d23"))
        s.send(.avancar)
        try await aguardar { salvo != nil }

        XCTAssertEqual(repo.cadastrados.first?.placa, "ABC1D23")
        // RN-02: proprietário é sempre o cliente autenticado.
        XCTAssertEqual(repo.cadastrados.first?.proprietarioId, dono)
    }

    func testEditarPreencheEChamaAtualizar() async throws {
        let original = veiculoFixture()
        let repo = VeiculosFake()
        var salvo: Veiculo?
        let s = VeiculoFormStore(modo: .editar(original), veiculos: repo,
                                 proprietarioId: UUID()) { salvo = $0 }
        XCTAssertEqual(s.estado.marca, "Toyota")
        XCTAssertEqual(s.estado.placa, "ABC1D23")

        s.send(.avancar)
        s.send(.avancar)
        s.send(.avancar)
        try await aguardar { salvo != nil }
        XCTAssertEqual(repo.atualizados, [original.id])
    }
}
