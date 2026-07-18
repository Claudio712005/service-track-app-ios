import Foundation
import STDomain
import STObservability

public protocol AuthTokenProvider: Sendable {
    var token: String? { get }
}

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

    public func send<Response: Decodable>(_ endpoint: Endpoint) async throws -> Response {
        let data = try await sendRaw(endpoint)
        do {
            return try STJSON.decoder.decode(Response.self, from: data)
        } catch {
            throw AppError.decoding(String(describing: error))
        }
    }

    public func send(_ endpoint: Endpoint) async throws {
        _ = try await sendRaw(endpoint)
    }


    func sendRaw(_ endpoint: Endpoint) async throws -> Data {
        let request = try makeRequest(endpoint)
        let tentativas = endpoint.isIdempotente ? retryDelays.count + 1 : 1
        var ultimoErro: Error = AppError.rede

        for tentativa in 0..<tentativas {
            if tentativa > 0 {
                let jitter = Duration.milliseconds(Int.random(in: 0...100))
                try await Task.sleep(for: retryDelays[tentativa - 1] + jitter)
            }
            let inicio = ContinuousClock.now
            do {
                let (data, response) = try await transport.send(request)
                logar(request, status: response.statusCode, inicio: inicio)
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
                logar(request, status: nil, inicio: inicio)
                ultimoErro = AppError.rede
                if !endpoint.isIdempotente { break }
            }
        }
        throw ultimoErro
    }

    private func logar(_ request: URLRequest, status: Int?, inicio: ContinuousClock.Instant) {
        #if canImport(os)
        let ms = (ContinuousClock.now - inicio).components.attoseconds / 1_000_000_000_000_000
        let metodo = request.httpMethod ?? "?"
        let caminho = request.url?.path ?? "?"
        let requestId = request.value(forHTTPHeaderField: "X-Request-Id") ?? "-"
        if let status {
            STLog.network.info("\(metodo, privacy: .public) \(caminho, privacy: .public) status=\(status) duracao=\(ms)ms rid=\(requestId, privacy: .public)")
        } else {
            STLog.network.error("\(metodo, privacy: .public) \(caminho, privacy: .public) falha=rede duracao=\(ms)ms rid=\(requestId, privacy: .public)")
        }
        #endif
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
        request.setValue(UUID().uuidString, forHTTPHeaderField: "X-Request-Id")
        if let token = tokenProvider?.token {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        return request
    }
}
