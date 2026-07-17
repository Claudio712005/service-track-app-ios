import Foundation
import STDomain

/// Cache de leitura em disco (ADR-iOS-005): um arquivo JSON por chave em
/// Application Support/`ServiceTrackCache`, com carimbo `fetchedAt`.
/// `actor` serializa o acesso; falha de disco nunca propaga (cache é best-effort).
public actor DiscoCache: CacheStore {
    private struct Envelope<T: Codable>: Codable {
        let valor: T
        let fetchedAt: Date
    }

    private let diretorio: URL
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    public init(pasta: String = "ServiceTrackCache") {
        let base = FileManager.default.urls(for: .applicationSupportDirectory,
                                            in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        diretorio = base.appending(path: pasta)
        try? FileManager.default.createDirectory(at: diretorio, withIntermediateDirectories: true)
    }

    private func url(_ chave: String) -> URL {
        // Chaves são identificadores internos (CacheChave); sanitiza por precaução.
        let nome = chave.replacingOccurrences(of: "/", with: "_")
        return diretorio.appending(path: "\(nome).json")
    }

    public func ler<T: Codable & Sendable>(_ tipo: T.Type, chave: String) async -> CacheEntrada<T>? {
        guard let data = try? Data(contentsOf: url(chave)),
              let envelope = try? decoder.decode(Envelope<T>.self, from: data) else {
            return nil
        }
        return CacheEntrada(valor: envelope.valor, fetchedAt: envelope.fetchedAt)
    }

    public func gravar<T: Codable & Sendable>(_ valor: T, chave: String) async {
        guard let data = try? encoder.encode(Envelope(valor: valor, fetchedAt: .now)) else { return }
        try? data.write(to: url(chave), options: .atomic)
    }

    public func invalidar(chaves: [String]) async {
        for chave in chaves {
            try? FileManager.default.removeItem(at: url(chave))
        }
    }
}

/// Cache em memória para testes e previews.
public final class MemoriaCache: CacheStore, @unchecked Sendable {
    private let lock = NSLock()
    private var dados: [String: (Any, Date)] = [:]

    public init() {}

    public func ler<T: Codable & Sendable>(_ tipo: T.Type, chave: String) async -> CacheEntrada<T>? {
        lock.withLock {
            guard let (valor, data) = dados[chave], let tipado = valor as? T else { return nil }
            return CacheEntrada(valor: tipado, fetchedAt: data)
        }
    }

    public func gravar<T: Codable & Sendable>(_ valor: T, chave: String) async {
        lock.withLock { dados[chave] = (valor, .now) }
    }

    public func invalidar(chaves: [String]) async {
        lock.withLock {
            for chave in chaves { dados[chave] = nil }
        }
    }

    /// Auxiliar de teste: força um carimbo antigo para simular TTL vencido.
    public func envelhecer(chave: String, para data: Date) {
        lock.withLock {
            if let (valor, _) = dados[chave] { dados[chave] = (valor, data) }
        }
    }
}
