import XCTest
import STDomain
@testable import STFeatureNotificacoes

private final class NotificacoesRepoFake: NotificacaoRepository, @unchecked Sendable {
    var pagina = Page<Notificacao>(content: [], page: 0, size: 20, total: 0, totalPages: 1)
    var contagem = 0
    var filtrosRecebidos: [Bool?] = []
    var visualizadas: [UUID] = []
    var erroVisualizar: AppError?

    func listar(apenasNaoLidas: Bool?, page: Int, size: Int) async throws -> Page<Notificacao> {
        filtrosRecebidos.append(apenasNaoLidas)
        return pagina
    }

    func buscar(id: UUID) async throws -> Notificacao { fatalError("não usado") }
    func contagemNaoLidas() async throws -> Int { contagem }

    func marcarVisualizada(id: UUID) async throws {
        if let erroVisualizar { throw erroVisualizar }
        visualizadas.append(id)
    }
}

private func notificacao(visualizada: Bool) -> Notificacao {
    Notificacao(id: UUID(), titulo: "t", assunto: "a", descricao: "d",
                tipoNotificacao: "EMAIL", tipoConteudo: "MUDANCA_STATUS_OS",
                statusEnvio: .enviada, visualizada: visualizada,
                dataCriacao: .now, dataEnvio: nil, dataVisualizacao: nil)
}

@MainActor
private func aguardar(_ condicao: @escaping () -> Bool) async throws {
    for _ in 0..<200 where !condicao() {
        try await Task.sleep(for: .milliseconds(10))
    }
    XCTAssertTrue(condicao(), "condição não satisfeita no tempo limite")
}

@MainActor
final class NotificacoesStoreTests: XCTestCase {
    func testCargaTrazListaEContadorDoBackend() async {
        let repo = NotificacoesRepoFake()
        repo.pagina = Page(content: [notificacao(visualizada: false)], page: 0, size: 20,
                           total: 1, totalPages: 1)
        repo.contagem = 7
        let s = NotificacoesStore(repo: repo)
        await s.recarregarAguardando()
        XCTAssertEqual(s.estado.fase, .conteudo)
        // Contador vem do endpoint dedicado, não é recalculado da página.
        XCTAssertEqual(s.estado.naoLidas, 7)
    }

    func testFiltroNaoLidasViraQuery() async throws {
        let repo = NotificacoesRepoFake()
        repo.pagina = Page(content: [notificacao(visualizada: false)], page: 0, size: 20,
                           total: 1, totalPages: 1)
        let s = NotificacoesStore(repo: repo)
        s.send(.filtroAlterado(.naoLidas))
        try await aguardar { !repo.filtrosRecebidos.isEmpty }
        XCTAssertEqual(repo.filtrosRecebidos.last, true)

        s.send(.filtroAlterado(.todas))
        try await aguardar { repo.filtrosRecebidos.count >= 2 }
        XCTAssertEqual(repo.filtrosRecebidos.last!, nil)
    }

    func testAbrirMarcaLidaOtimistaEDecrementa() async throws {
        let repo = NotificacoesRepoFake()
        let alvo = notificacao(visualizada: false)
        repo.pagina = Page(content: [alvo], page: 0, size: 20, total: 1, totalPages: 1)
        repo.contagem = 3
        let s = NotificacoesStore(repo: repo)
        await s.recarregarAguardando()

        s.send(.abrir(alvo))
        // Otimista: efeito imediato, antes do PATCH voltar.
        XCTAssertTrue(s.estado.notificacoes[0].visualizada)
        XCTAssertEqual(s.estado.naoLidas, 2)
        try await aguardar { repo.visualizadas == [alvo.id] }
    }

    func testFalhaNoPatchReverte() async throws {
        let repo = NotificacoesRepoFake()
        let alvo = notificacao(visualizada: false)
        repo.pagina = Page(content: [alvo], page: 0, size: 20, total: 1, totalPages: 1)
        repo.contagem = 3
        repo.erroVisualizar = .servidor(status: 500)
        let s = NotificacoesStore(repo: repo)
        await s.recarregarAguardando()

        s.send(.abrir(alvo))
        try await aguardar { s.estado.erroAcao != nil }
        XCTAssertFalse(s.estado.notificacoes[0].visualizada)
        XCTAssertEqual(s.estado.naoLidas, 3)
    }

    func testAbrirJaLidaNaoChamaPatch() async throws {
        let repo = NotificacoesRepoFake()
        let lida = notificacao(visualizada: true)
        repo.pagina = Page(content: [lida], page: 0, size: 20, total: 1, totalPages: 1)
        let s = NotificacoesStore(repo: repo)
        await s.recarregarAguardando()

        s.send(.abrir(lida))
        try await Task.sleep(for: .milliseconds(50))
        XCTAssertTrue(repo.visualizadas.isEmpty)
    }

    func testMarcarTodasIteraApenasNaoLidas() async throws {
        let repo = NotificacoesRepoFake()
        let a = notificacao(visualizada: false)
        let b = notificacao(visualizada: true)
        let c = notificacao(visualizada: false)
        repo.pagina = Page(content: [a, b, c], page: 0, size: 20, total: 3, totalPages: 1)
        repo.contagem = 2
        let s = NotificacoesStore(repo: repo)
        await s.recarregarAguardando()

        s.send(.marcarTodasComoLidas)
        try await aguardar { repo.visualizadas.count == 2 }
        XCTAssertEqual(Set(repo.visualizadas), Set([a.id, c.id]))
        XCTAssertEqual(s.estado.naoLidas, 0)
        XCTAssertTrue(s.estado.notificacoes.allSatisfy(\.visualizada))
    }
}
