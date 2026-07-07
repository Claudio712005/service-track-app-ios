import Foundation
import Security
import STDomain

/// Persistência da sessão no Keychain (spec §8.2): `kSecClassGenericPassword`,
/// acessível apenas com o aparelho desbloqueado e sem migração entre devices.
public struct KeychainSessaoStore: SessaoStore {
    let service: String

    public init(service: String = "br.com.claus.ServiceTrackApp.sessao") {
        self.service = service
    }

    private var queryBase: [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: "sessao",
        ]
    }

    public func carregar() throws -> Sessao? {
        var query = queryBase
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status != errSecItemNotFound else { return nil }
        guard status == errSecSuccess, let data = item as? Data else {
            throw KeychainError.leitura(status)
        }
        return try JSONDecoder().decode(Sessao.self, from: data)
    }

    public func salvar(_ sessao: Sessao) throws {
        let data = try JSONEncoder().encode(sessao)
        try? limpar()

        var query = queryBase
        query[kSecValueData as String] = data
        query[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly

        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else { throw KeychainError.escrita(status) }
    }

    public func limpar() throws {
        let status = SecItemDelete(queryBase as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.escrita(status)
        }
    }

    public enum KeychainError: Error {
        case leitura(OSStatus)
        case escrita(OSStatus)
    }
}

/// Store em memória para previews, testes e mock (nunca em produção).
public final class InMemorySessaoStore: SessaoStore, @unchecked Sendable {
    private let lock = NSLock()
    private var sessao: Sessao?

    public init(sessao: Sessao? = nil) {
        self.sessao = sessao
    }

    public func carregar() throws -> Sessao? {
        lock.withLock { sessao }
    }

    public func salvar(_ sessao: Sessao) throws {
        lock.withLock { self.sessao = sessao }
    }

    public func limpar() throws {
        lock.withLock { sessao = nil }
    }
}
