import XCTest
@testable import STDomain

final class StatusOrdemServicoTests: XCTestCase {
    // Spec §5.2 — todas as transições válidas.
    func testTransicoesValidas() {
        XCTAssertTrue(StatusOrdemServico.recebida.podeTransitarPara(.emDiagnostico))
        XCTAssertTrue(StatusOrdemServico.recebida.podeTransitarPara(.cancelada))
        XCTAssertTrue(StatusOrdemServico.emDiagnostico.podeTransitarPara(.aguardandoAprovacao))
        XCTAssertTrue(StatusOrdemServico.emDiagnostico.podeTransitarPara(.cancelada))
        XCTAssertTrue(StatusOrdemServico.aguardandoAprovacao.podeTransitarPara(.emExecucao))
        XCTAssertTrue(StatusOrdemServico.aguardandoAprovacao.podeTransitarPara(.cancelada))
        XCTAssertTrue(StatusOrdemServico.emExecucao.podeTransitarPara(.finalizada))
        XCTAssertTrue(StatusOrdemServico.emExecucao.podeTransitarPara(.cancelada))
        XCTAssertTrue(StatusOrdemServico.finalizada.podeTransitarPara(.entregue))
    }

    func testTransicoesInvalidas() {
        // FINALIZADA não cancela (spec §9 C3 — código prevalece sobre o SRS).
        XCTAssertFalse(StatusOrdemServico.finalizada.podeTransitarPara(.cancelada))
        // Terminais não transitam.
        for destino in StatusOrdemServico.allCases {
            XCTAssertFalse(StatusOrdemServico.entregue.podeTransitarPara(destino))
            XCTAssertFalse(StatusOrdemServico.cancelada.podeTransitarPara(destino))
        }
        // Sem saltos na jornada.
        XCTAssertFalse(StatusOrdemServico.recebida.podeTransitarPara(.emExecucao))
        XCTAssertFalse(StatusOrdemServico.emDiagnostico.podeTransitarPara(.finalizada))
        XCTAssertFalse(StatusOrdemServico.aguardandoAprovacao.podeTransitarPara(.finalizada))
    }

    // RN-06 / spec §5.3.
    func testCancelamentoPeloCliente() {
        XCTAssertTrue(StatusOrdemServico.recebida.clientePodeCancelar)
        XCTAssertTrue(StatusOrdemServico.emDiagnostico.clientePodeCancelar)
        XCTAssertTrue(StatusOrdemServico.aguardandoAprovacao.clientePodeCancelar)
        XCTAssertTrue(StatusOrdemServico.emExecucao.clientePodeCancelar)
        XCTAssertFalse(StatusOrdemServico.finalizada.clientePodeCancelar)
        XCTAssertFalse(StatusOrdemServico.entregue.clientePodeCancelar)
        XCTAssertFalse(StatusOrdemServico.cancelada.clientePodeCancelar)
    }

    func testDecisaoDeOrcamentoSoEmAguardandoAprovacao() {
        for status in StatusOrdemServico.allCases {
            XCTAssertEqual(status.clientePodeDecidirOrcamento, status == .aguardandoAprovacao)
        }
    }

    // Spec §9 C1 — sinônimos legados do dashboard.
    func testMapeamentoDeSinonimosLegados() {
        XCTAssertEqual(StatusOrdemServico(rawAPI: "DIAGNOSTICO"), .emDiagnostico)
        XCTAssertEqual(StatusOrdemServico(rawAPI: "ORCAMENTO_GERADO"), .aguardandoAprovacao)
        XCTAssertEqual(StatusOrdemServico(rawAPI: "APROVADO"), .emExecucao)
    }

    func testValorDesconhecidoCaiEmDesconhecido() {
        XCTAssertEqual(StatusOrdemServico(rawAPI: "NOVO_STATUS_FUTURO"),
                       .desconhecido("NOVO_STATUS_FUTURO"))
    }

    func testRoundTripCanonico() {
        for status in StatusOrdemServico.allCases {
            XCTAssertEqual(StatusOrdemServico(rawAPI: status.rawAPI), status)
        }
    }
}
