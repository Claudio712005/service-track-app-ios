import XCTest
@testable import STObservability

final class AnalyticsSpy: AnalyticsClient, @unchecked Sendable {
    private let lock = NSLock()
    private var _eventos: [EventoAnalytics] = []

    var eventos: [EventoAnalytics] {
        lock.withLock { _eventos }
    }

    func registrar(_ evento: EventoAnalytics) {
        lock.withLock { _eventos.append(evento) }
    }
}

final class TelemetriaTests: XCTestCase {
    override func tearDown() {
        Telemetria.configurar(cliente: AnalyticsOSLog(), habilitada: { true })
        super.tearDown()
    }

    func testRegistraQuandoHabilitada() {
        let spy = AnalyticsSpy()
        Telemetria.configurar(cliente: spy, habilitada: { true })
        Telemetria.registrar("app_open", ["a": "1"])
        XCTAssertEqual(spy.eventos, [EventoAnalytics("app_open", ["a": "1"])])
    }

    func testConsentimentoDesligadoDescartaNaOrigem() {
        let spy = AnalyticsSpy()
        Telemetria.configurar(cliente: spy, habilitada: { false })
        Telemetria.registrar("app_open")
        XCTAssertTrue(spy.eventos.isEmpty)
    }

    func testPseudonimoEstavelEIrreversivel() {
        let id = UUID(uuidString: "4D32C6AE-46D1-403D-8E65-D9527126D093")!
        let hash = Telemetria.pseudonimo(id)
        XCTAssertEqual(hash, Telemetria.pseudonimo(id))
        XCTAssertEqual(hash.count, 12)
        XCTAssertFalse(id.uuidString.lowercased().contains(hash))
        XCTAssertNotEqual(hash, Telemetria.pseudonimo(UUID()))
    }

    func testFaixasDeValor() {
        XCTAssertEqual(Telemetria.faixaDeValor(99), "ate_100")
        XCTAssertEqual(Telemetria.faixaDeValor(100), "100_500")
        XCTAssertEqual(Telemetria.faixaDeValor(560.5), "500_1000")
        XCTAssertEqual(Telemetria.faixaDeValor(4999), "1000_5000")
        XCTAssertEqual(Telemetria.faixaDeValor(10_000), "acima_5000")
    }
}
