import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// Borda de I/O do APIClient. Produção usa `URLSessionTransport`;
/// o ambiente local usa `MockTransport` (STData) com fixtures do OpenAPI.
public protocol APITransport: Sendable {
    func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse)
}

public struct URLSessionTransport: APITransport {
    let session: URLSession

    public init(session: URLSession = .shared) {
        self.session = session
    }

    public func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        return (data, http)
    }
}
