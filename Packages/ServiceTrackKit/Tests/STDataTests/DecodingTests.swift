import XCTest
import STDomain
import STNetworking
@testable import STData

/// Testes de contrato (spec §19): fixtures derivadas dos `example:` do OpenAPI
/// precisam decodificar nos DTOs sem perda.
final class DecodingTests: XCTestCase {
    func testOrdemServicoDetalheCamelCaseSemOffset() throws {
        let dto = try STJSON.decoder.decode(OrdemServicoResponseDTO.self,
                                            from: Data(MockFixtures.ordemServicoDetalhe().utf8))
        let os = dto.domain
        XCTAssertEqual(os.status, .aguardandoAprovacao)
        XCTAssertNotNil(os.dataCriacao)
        XCTAssertEqual(os.itensServico.count, 2)
        XCTAssertEqual(os.insumos.count, 3)
        XCTAssertEqual(os.orcamento?.valorTotal ?? 0, 560.5, accuracy: 0.001)
        XCTAssertTrue(os.status.clientePodeDecidirOrcamento)
    }

    func testDashboardSnakeCaseComZeEnumLegado() throws {
        let dto = try STJSON.decoder.decode(DashboardClienteResponseDTO.self,
                                            from: Data(MockFixtures.dashboard.utf8))
        let dash = dto.domain
        XCTAssertEqual(dash.usuarioNome, "Cláudio da Silva Araújo")
        XCTAssertEqual(dash.resumo.ordensAtivas, 2)
        XCTAssertEqual(dash.ordensAtivas.count, 2)
        // "APROVADO" (legado C1) vira EM_EXECUCAO.
        XCTAssertEqual(dash.ordensAtivas[1].status, .emExecucao)
        XCTAssertNotNil(dash.ordensAtivas[0].dataCriacao)
        XCTAssertEqual(dash.veiculos.count, 2)
        XCTAssertEqual(dash.veiculos[0].totalGasto ?? 0, 1850.50, accuracy: 0.001)
        // Veículo sem imagem/fipe não quebra (decodificação defensiva §11.4).
        XCTAssertNil(dash.veiculos[1].imagemUrl)
    }

    func testPageDeOrdens() throws {
        let dto = try STJSON.decoder.decode(PageDTO<ResumoOrdemServicoResponseDTO>.self,
                                            from: Data(MockFixtures.pageOrdens().utf8))
        let page = dto.domain(\.domain)
        XCTAssertEqual(page.content.count, 3)
        XCTAssertEqual(page.total, 3)
        XCTAssertFalse(page.temProximaPagina)
    }

    func testNotificacoes() throws {
        let dto = try STJSON.decoder.decode(PageDTO<NotificacaoResponseDTO>.self,
                                            from: Data(MockFixtures.pageNotificacoes().utf8))
        let page = dto.domain(\.domain)
        XCTAssertEqual(page.content.count, 4)
        XCTAssertFalse(page.content[0].visualizada)
        XCTAssertEqual(page.content[0].statusEnvio, .enviada)
        XCTAssertNil(page.content[0].dataVisualizacao)

        let naoLidas = try STJSON.decoder.decode(PageDTO<NotificacaoResponseDTO>.self,
                                                 from: Data(MockFixtures.pageNotificacoes(apenasNaoLidas: true).utf8))
        XCTAssertTrue(naoLidas.domain(\.domain).content.allSatisfy { !$0.visualizada })
    }

    func testLoginResponseComTokenDecodavel() throws {
        let dto = try STJSON.decoder.decode(LoginResponseDTO.self,
                                            from: Data(MockFixtures.loginResponse.utf8))
        let sessao = try XCTUnwrap(dto.domain)
        XCTAssertEqual(sessao.usuarioId.uuidString.lowercased(), MockFixtures.clienteId)
        XCTAssertEqual(sessao.cpf, "52998224725")
        XCTAssertTrue(sessao.isCliente)
        XCTAssertFalse(sessao.expirada())
        XCTAssertNotNil(sessao.expiraEm)
    }
}

/// Caminhos/verbos derivados do contrato — guardas contra regressão do ADR-iOS-002.
final class EndpointContractTests: XCTestCase {
    func testListagemUsaRotaDoContrato() {
        let endpoint = ServiceTrackAPI.listarOrdens(status: .emExecucao, page: 1, size: 50)
        XCTAssertEqual(endpoint.path, "/ordem-servico/lista")
        XCTAssertEqual(endpoint.method, .get)
        XCTAssertEqual(endpoint.query.map(\.name), ["status", "page", "size"])
        XCTAssertEqual(endpoint.query.first?.value, "EM_EXECUCAO")
    }

    func testAcoesDoClienteSaoPOST() {
        let id = UUID()
        XCTAssertEqual(ServiceTrackAPI.aprovarOrcamento(id).method, .post)
        XCTAssertEqual(ServiceTrackAPI.reprovarOrcamento(id, Data()).method, .post)
        XCTAssertEqual(ServiceTrackAPI.cancelarOrdemServico(id, Data()).method, .post)
        XCTAssertEqual(ServiceTrackAPI.aprovarOrcamento(id).path,
                       "/ordem-servico/\(id.uuidString)/orcamento/aprovacao")
    }

    func testVisualizarNotificacaoEhPATCH() {
        let id = UUID()
        XCTAssertEqual(ServiceTrackAPI.visualizarNotificacao(id).method, .patch)
        XCTAssertEqual(ServiceTrackAPI.visualizarNotificacao(id).path,
                       "/notificacoes/\(id.uuidString)/visualizar")
    }
}

/// RN-05 e C4 no repositório de OS.
final class OrdemServicoRepositoryRulesTests: XCTestCase {
    private var repo: OrdemServicoRepositoryHTTP {
        OrdemServicoRepositoryHTTP(client: APIClient(
            baseURL: URL(string: "http://localhost:8080")!, transport: MockTransport(latencia: .zero)))
    }

    func testReprovarSemMotivoFalha() async {
        do {
            _ = try await repo.reprovarOrcamento(osId: UUID(), motivo: "   ")
            XCTFail("RN-05: motivo é obrigatório")
        } catch let erro as AppError {
            XCTAssertEqual(erro, .validacao(campo: "motivo", mensagem: "Informe o motivo da reprovação."))
        } catch {
            XCTFail("Erro inesperado: \(error)")
        }
    }

    func testAbrirOSBloqueadaSemMecanico() async {
        do {
            _ = try await repo.abrir(motivo: "x", clienteId: UUID(), veiculoId: UUID(),
                                     mecanicoId: nil, observacao: nil)
            XCTFail("C4: abertura deve estar bloqueada sem mecanicoId")
        } catch let erro as AppError {
            guard case .regraNegocio = erro else {
                return XCTFail("Esperava regraNegocio, veio \(erro)")
            }
        } catch {
            XCTFail("Erro inesperado: \(error)")
        }
    }

    func testFluxoAprovarContraMock() async throws {
        let resumo = try await repo.aprovarOrcamento(osId: UUID())
        XCTAssertEqual(resumo.status, .emExecucao)
    }
}
