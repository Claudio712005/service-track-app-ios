import Foundation
import CryptoKit

public struct EventoAnalytics: Equatable, Sendable {
    public let nome: String
    public let propriedades: [String: String]

    public init(_ nome: String, _ propriedades: [String: String] = [:]) {
        self.nome = nome
        self.propriedades = propriedades
    }
}

public protocol AnalyticsClient: Sendable {
    func registrar(_ evento: EventoAnalytics)
}

public struct AnalyticsOSLog: AnalyticsClient {
    public init() {}

    public func registrar(_ evento: EventoAnalytics) {
        #if canImport(os)
        let props = evento.propriedades
            .sorted { $0.key < $1.key }
            .map { "\($0.key)=\($0.value)" }
            .joined(separator: " ")
        STLog.analytics.info("evento=\(evento.nome, privacy: .public) \(props, privacy: .public)")
        #endif
    }
}

public enum Telemetria {
    private static let lock = NSLock()
    nonisolated(unsafe) private static var _cliente: AnalyticsClient = AnalyticsOSLog()
    nonisolated(unsafe) private static var _habilitada: @Sendable () -> Bool = { true }

    public static func configurar(cliente: AnalyticsClient,
                                  habilitada: @escaping @Sendable () -> Bool) {
        lock.withLock {
            _cliente = cliente
            _habilitada = habilitada
        }
    }

    public static func registrar(_ nome: String, _ propriedades: [String: String] = [:]) {
        let (cliente, habilitada) = lock.withLock { (_cliente, _habilitada) }
        guard habilitada() else { return }
        cliente.registrar(EventoAnalytics(nome, propriedades))
    }

    public static func pseudonimo(_ id: UUID) -> String {
        let digest = SHA256.hash(data: Data(id.uuidString.utf8))
        return digest.map { String(format: "%02x", $0) }.joined().prefix(12).description
    }

    public static func faixaDeValor(_ valor: Double) -> String {
        switch valor {
        case ..<100: "ate_100"
        case ..<500: "100_500"
        case ..<1000: "500_1000"
        case ..<5000: "1000_5000"
        default: "acima_5000"
        }
    }
}
