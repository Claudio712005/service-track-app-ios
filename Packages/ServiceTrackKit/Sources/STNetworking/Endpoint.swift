import Foundation

public enum HTTPMethod: String, Sendable {
    case get = "GET"
    case post = "POST"
    case put = "PUT"
    case patch = "PATCH"
    case delete = "DELETE"
}

/// Descrição declarativa de uma chamada. Os endpoints concretos vivem em STData
/// (`ServiceTrackAPI`), derivados dos contratos OpenAPI (ADR-iOS-002).
public struct Endpoint: Sendable {
    public var method: HTTPMethod
    public var path: String
    public var query: [URLQueryItem]
    public var body: Data?
    /// GETs são idempotentes e elegíveis a retry automático (spec §12.2).
    public var isIdempotente: Bool { method == .get }

    public init(method: HTTPMethod, path: String, query: [URLQueryItem] = [], body: Data? = nil) {
        self.method = method
        self.path = path
        self.query = query
        self.body = body
    }
}
