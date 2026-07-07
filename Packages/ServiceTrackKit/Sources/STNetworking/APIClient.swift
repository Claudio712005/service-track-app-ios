import Foundation
import STDomain

/// Fornece o Bearer token da sessão ativa (spec §8.2). Implementado pelo SessionManager do app.
public protocol AuthTokenProvider: Sendable {
    var token: String? { get }
}

/// Cliente HTTP contract-first (spec §11.1): injeta auth + trace-id,
/// retry idempotente com backoff (spec §12.2) e mapeia erros para `AppError`.
public struct APIClient: Sendable {
    public let baseURL: URL
    let transport: APITransport
    let tokenProvider: AuthTokenProvider?
    let retryDelays: [Duration]

    public init(baseURL: URL,
                transport: APITransport = URLSessionTransport(),
                tokenProvider: AuthTokenProvider? = nil,
                retryDelays: [Duration] = [.milliseconds(250), .seconds(1)]) {
        self.baseURL = baseURL
        self.transport = transport
        self.tokenProvider = tokenProvider
        self.retryDelays = retryDelays
    }

    // MARK: chamadas

    public func send<Response: Decodable>(_ endpoint: Endpoint) async throws -> Response {
        let data = try await sendRaw(endpoint)
        do {
            return try STJSON.decoder.decode(Response.self, from: data)
        } catch {
            throw AppError.decoding(String(describing: error))
        }
    }

    /// Para respostas 204 (sem corpo).
    public func send(_ endpoint: Endpoint) async throws {
        _ = try await sendRaw(endpoint)
    }

    // MARK: pipeline

    func sendRaw(_ endpoint: Endpoint) async throws -> Data {
        let request = try makeRequest(endpoint)
        // Não idempotentes: sem retry automático para evitar dupla execução (RN-09).
        let tentativas = endpoint.isIdempotente ? retryDelays.count + 1 : 1
        var ultimoErro: Error = AppError.rede

        for tentativa in 0..<tentativas {
            if tentativa > 0 {
                let jitter = Duration.milliseconds(Int.random(in: 0...100))
                try await Task.sleep(for: retryDelays[tentativa - 1] + jitter)
            }
            do {
                let (data, response) = try await transport.send(request)
                guard (200..<300).contains(response.statusCode) else {
                    let erro = ErrorMapper.map(status: response.statusCode, data: data,
                                               headers: response.allHeaderFields)
                    // 5xx em GET ainda é elegível a retry; erros de cliente não.
                    if response.statusCode >= 500, endpoint.isIdempotente, tentativa < tentativas - 1 {
                        ultimoErro = erro
                        continue
                    }
                    throw erro
                }
                return data
            } catch let erro as AppError {
                throw erro
            } catch {
                ultimoErro = AppError.rede
                if !endpoint.isIdempotente { break }
            }
        }
        throw ultimoErro
    }

    func makeRequest(_ endpoint: Endpoint) throws -> URLRequest {
        guard var components = URLComponents(url: baseURL.appending(path: endpoint.path),
                                             resolvingAgainstBaseURL: false) else {
            throw AppError.rede
        }
        if !endpoint.query.isEmpty {
            components.queryItems = endpoint.query
        }
        guard let url = components.url else { throw AppError.rede }

        var request = URLRequest(url: url)
        request.httpMethod = endpoint.method.rawValue
        request.httpBody = endpoint.body
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if endpoint.body != nil {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        // Trace-id por request para correlação com o backend (spec §11.1/§17.1).
        request.setValue(UUID().uuidString, forHTTPHeaderField: "X-Request-Id")
        if let token = tokenProvider?.token {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        return request
    }
}
