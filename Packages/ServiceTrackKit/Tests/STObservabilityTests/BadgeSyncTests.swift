import XCTest
@testable import STObservability

final class BadgeSyncTests: XCTestCase {
    func testAvisaQuandoContagemSobe() {
        XCTAssertTrue(BadgeSync.deveAvisar(anterior: 1, atual: 3))
        XCTAssertTrue(BadgeSync.deveAvisar(anterior: 0, atual: 1))
    }

    func testNaoAvisaEmEmpateOuQueda() {
        XCTAssertFalse(BadgeSync.deveAvisar(anterior: 3, atual: 3))
        XCTAssertFalse(BadgeSync.deveAvisar(anterior: 3, atual: 1))
        XCTAssertFalse(BadgeSync.deveAvisar(anterior: 3, atual: 0))
    }

    func testNaoAvisaSeAtualForZero() {
        // Marcar todas como lidas não deve gerar aviso (mesmo que "suba" de negativo hipotético).
        XCTAssertFalse(BadgeSync.deveAvisar(anterior: 0, atual: 0))
    }

    func testCorpoDoAvisoSingularEPlural() {
        XCTAssertEqual(BadgeSync.corpoDoAviso(quantidade: 1), "Você tem 1 novo aviso da oficina.")
        XCTAssertEqual(BadgeSync.corpoDoAviso(quantidade: 3), "Você tem 3 novos avisos da oficina.")
    }
}
