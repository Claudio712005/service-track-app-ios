import XCTest
import STDomain
@testable import STFeatureDashboard

// MARK: - Fakes

private final class DashboardFake: DashboardRepository, @unchecked Sendable {
    var resultado: Result<DashboardCliente, AppError>
    var buscas = 0

    init(_ resultado: Result<DashboardCliente, AppError>) {
        self.resultado = resultado
    }

    func buscar(clienteId: UUID) async throws -> DashboardCliente {
        buscas += 1
        return try resultado.get()
    }
}

private struct NotificacoesFake: NotificacaoRepository {
    var total: Int

    func listar(apenasNaoLidas: Bool?, page: Int, size: Int) async throws -> Page<Notificacao> {
        fatalError("não usado")
    }
    func buscar(id: UUID) async throws -> Notificacao { fatalError("não usado") }
    func contagemNaoLidas() async throws -> Int { total }
    func marcarVisualizada(id: UUID) async throws {}
}

private final class OrdensFake: OrdemServicoRepository, @unchecked Sendable {
    var aprovadas: [UUID] = []
    var reprovadas: [(UUID, String)] = []
    var erroDecisao: AppError?

    func listar(status: StatusOrdemServico?, page: Int, size: Int) async throws -> Page<ResumoOrdemServico> {
        fatalError("não usado")
    }
    func buscar(id: UUID) async throws -> OrdemServico { fatalError("não usado") }
    func abrir(motivo: String, clienteId: UUID, veiculoId: UUID, mecanicoId: UUID?,
               observacao: String?) async throws -> OrdemServico {
        fatalError("não usado")
    }

    func aprovarOrcamento(osId: UUID) async throws -> ResumoOrdemServico {
        if let erroDecisao { throw erroDecisao }
        aprovadas.append(osId)
        return ResumoOrdemServico(id: osId, motivo: "m", observacao: nil, clienteId: nil,
                                  mecanicoId: nil, veiculoId: nil, status: .emExecucao)
    }

    func reprovarOrcamento(osId: UUID, motivo: String) async throws -> ResumoOrdemServico {
        reprovadas.append((osId, motivo))
        return ResumoOrdemServico(id: osId, motivo: "m", observacao: nil, clienteId: nil,
                                  mecanicoId: nil, veiculoId: nil, status: .aguardandoAprovacao)
    }

    func cancelar(osId: UUID, motivo: String?) async throws -> ResumoOrdemServico {
        fatalError("não usado")
    }
}

private func data(_ ano: Int, _ mes: Int, _ dia: Int) -> Date {
    Calendar.current.date(from: DateComponents(year: ano, month: mes, day: dia))!
}

private func dashboardFixture(totalOrdens: Int = 8, veiculos: Int = 2) -> DashboardCliente {
    let osId = UUID()
    return DashboardCliente(
        usuarioId: UUID(),
        usuarioNome: "Cláudio",
        resumo: ResumoDashboard(ordensAtivas: 2, ordensConcluidas: 5, ordensCanceladas: 1,
                                totalOrdens: totalOrdens, veiculosCadastrados: veiculos),
        ordensAtivas: [
            OrdemAtivaDashboard(id: osId, motivo: "Freios", status: .aguardandoAprovacao,
                                veiculoId: nil, veiculoPlaca: "ABC1D23", veiculoModelo: "Corolla",
                                mecanicoId: nil, mecanicoNome: nil, dataCriacao: nil,
                                dataAtualizacao: nil, diasEmAndamento: 3, valorOrcado: 560.5,
                                prazoConclusao: nil),
        ],
        ordensRecentes: [
            OrdemRecenteDashboard(id: UUID(), motivo: "Óleo", status: .finalizada, veiculoId: nil,
                                  veiculoPlaca: nil, veiculoModelo: nil,
                                  dataCriacao: data(2026, 6, 10), dataConclusao: data(2026, 6, 12),
                                  diasParaConclusao: 2, valorTotal: 320, mecanicoNome: nil),
            OrdemRecenteDashboard(id: UUID(), motivo: "Freios", status: .entregue, veiculoId: nil,
                                  veiculoPlaca: nil, veiculoModelo: nil,
                                  dataCriacao: data(2026, 5, 4), dataConclusao: data(2026, 5, 6),
                                  diasParaConclusao: 2, valorTotal: 480, mecanicoNome: nil),
            OrdemRecenteDashboard(id: UUID(), motivo: "Alinhamento", status: .entregue, veiculoId: nil,
                                  veiculoPlaca: nil, veiculoModelo: nil,
                                  dataCriacao: data(2026, 5, 20), dataConclusao: data(2026, 5, 21),
                                  diasParaConclusao: 1, valorTotal: 180, mecanicoNome: nil),
            // Cancelada não entra no gráfico de gastos.
            OrdemRecenteDashboard(id: UUID(), motivo: "Cancelada", status: .cancelada, veiculoId: nil,
                                  veiculoPlaca: nil, veiculoModelo: nil,
                                  dataCriacao: data(2026, 5, 25), dataConclusao: nil,
                                  diasParaConclusao: nil, valorTotal: 999, mecanicoNome: nil),
        ],
        veiculos: [
            VeiculoDashboard(id: UUID(), placa: "ABC1D23", marca: "Toyota", modelo: "Corolla",
                             ano: 2022, imagemUrl: nil, codigoFipe: nil, ativo: true,
                             totalOrdens: 5, totalGasto: 1850.5, dataCriacao: nil),
            VeiculoDashboard(id: UUID(), placa: "XYZ9B76", marca: "VW", modelo: "Gol",
                             ano: 2019, imagemUrl: nil, codigoFipe: nil, ativo: true,
                             totalOrdens: 3, totalGasto: 650, dataCriacao: nil),
            // Sem gasto: fica fora da série.
            VeiculoDashboard(id: UUID(), placa: "NOV0A00", marca: "Fiat", modelo: "Toro",
                             ano: 2024, imagemUrl: nil, codigoFipe: nil, ativo: true,
                             totalOrdens: 0, totalGasto: 0, dataCriacao: nil),
        ],
        dataAtualizacao: nil)
}

@MainActor
private func aguardar(_ condicao: @escaping () -> Bool) async throws {
    for _ in 0..<200 where !condicao() {
        try await Task.sleep(for: .milliseconds(10))
    }
    XCTAssertTrue(condicao(), "condição não satisfeita no tempo limite")
}

// MARK: - Testes

@MainActor
final class DashboardStoreTests: XCTestCase {
    private func store(dash: DashboardFake = DashboardFake(.success(dashboardFixture())),
                       notificacoes: NotificacoesFake = NotificacoesFake(total: 3),
                       ordens: OrdensFake = OrdensFake()) -> DashboardStore {
        DashboardStore(dashboard: dash, notificacoes: notificacoes, ordens: ordens,
                       clienteId: UUID())
    }

    func testCargaParalelaPopulaKPIsEContador() async {
        let s = store()
        await s.carregar()
        XCTAssertEqual(s.estado.fase, .conteudo)
        XCTAssertEqual(s.estado.dashboard?.resumo.ordensConcluidas, 5)
        XCTAssertEqual(s.estado.naoLidas, 3)
        XCTAssertNotNil(s.estado.pendenteDeAprovacao)
    }

    func testClienteNovoCaiEmVazio() async {
        let vazio = DashboardCliente(usuarioId: UUID(), usuarioNome: nil,
                                     resumo: ResumoDashboard(ordensAtivas: 0, ordensConcluidas: 0,
                                                             ordensCanceladas: 0, totalOrdens: 0,
                                                             veiculosCadastrados: 0),
                                     ordensAtivas: [], ordensRecentes: [], veiculos: [],
                                     dataAtualizacao: nil)
        let s = store(dash: DashboardFake(.success(vazio)))
        await s.carregar()
        XCTAssertEqual(s.estado.fase, .vazio)
    }

    func testErroDeCargaViraEstadoErro() async {
        let s = store(dash: DashboardFake(.failure(.servidor(status: 500))))
        await s.carregar()
        XCTAssertEqual(s.estado.fase, .erro(.servidor(status: 500)))
    }

    func testGastoPorVeiculoOrdenaDescEIgnoraZerados() async {
        let s = store()
        await s.carregar()
        let serie = s.gastoPorVeiculo
        XCTAssertEqual(serie.count, 2)
        XCTAssertEqual(serie[0].valor, 1850.5)
        XCTAssertEqual(serie[1].valor, 650)
        XCTAssertEqual(s.totalInvestido, 2500.5, accuracy: 0.001)
    }

    func testGastosPorMesAgrupaEExcluiCanceladas() async {
        let s = store()
        await s.carregar()
        let serie = s.gastosPorMes
        XCTAssertEqual(serie.count, 2)
        // Maio = 480 + 180 (cancelada de 999 fora); junho = 320.
        XCTAssertEqual(serie[0].valor, 660, accuracy: 0.001)
        XCTAssertEqual(serie[1].valor, 320, accuracy: 0.001)
        XCTAssertLessThan(serie[0].mes, serie[1].mes)
    }

    func testAprovarChamaRepoERefaz() async throws {
        let dash = DashboardFake(.success(dashboardFixture()))
        let ordens = OrdensFake()
        let s = store(dash: dash, ordens: ordens)
        await s.carregar()
        let buscasAntes = dash.buscas

        let osId = s.estado.pendenteDeAprovacao!.id
        s.send(.aprovarOrcamento(osId))
        try await aguardar { ordens.aprovadas.contains(osId) }
        try await aguardar { dash.buscas > buscasAntes }
        XCTAssertNotNil(s.estado.sucessoAcao)
    }

    func testConflito409ViraMensagemDeOutroCanal() async throws {
        // RN-07: decisão pode ter acontecido pelo magic link do e-mail.
        let ordens = OrdensFake()
        ordens.erroDecisao = .conflitoEstado(mensagem: nil)
        let s = store(ordens: ordens)
        await s.carregar()
        s.send(.aprovarOrcamento(UUID()))
        try await aguardar { s.estado.erroAcao != nil }
        XCTAssertEqual(s.estado.erroAcao, "Este orçamento já foi decidido por outro canal.")
    }

    func testReprovarPassaMotivo() async throws {
        let ordens = OrdensFake()
        let s = store(ordens: ordens)
        await s.carregar()
        let osId = UUID()
        s.send(.reprovarOrcamento(osId, motivo: "Valor acima do esperado"))
        try await aguardar { !ordens.reprovadas.isEmpty }
        XCTAssertEqual(ordens.reprovadas.first?.1, "Valor acima do esperado")
    }
}
