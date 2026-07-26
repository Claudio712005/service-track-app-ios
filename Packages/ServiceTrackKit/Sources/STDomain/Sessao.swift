import Foundation

/// Sessão autenticada (spec §8.2) — derivada do JWT emitido pela Lambda de autenticação,
/// persistida no Keychain. A resposta do login traz apenas o token; a identidade vem
/// das claims (GLOBAL-ADR-004).
public struct Sessao: Equatable, Codable, Sendable {
    public let token: String
    public let usuarioId: UUID
    public let cpf: String
    public let email: String
    public let roles: [String]

    public init(token: String, usuarioId: UUID, cpf: String, email: String, roles: [String]) {
        self.token = token
        self.usuarioId = usuarioId
        self.cpf = cpf
        self.email = email
        self.roles = roles
    }

    /// Constrói a sessão a partir das claims do token. Falha quando o JWT não traz
    /// `sub` utilizável como identificador do usuário.
    public init?(token: String) {
        guard let claims = JWTClaims(token: token),
              let sub = claims.sub,
              let id = UUID(uuidString: sub) else {
            return nil
        }
        self.init(token: token,
                  usuarioId: id,
                  cpf: claims.cpf ?? "",
                  email: claims.upn ?? "",
                  roles: claims.groups)
    }

    /// Gate de role (spec §8.2 item 4): este app é exclusivo do perfil CLIENTE.
    public var isCliente: Bool { roles.contains("CLIENTE") }

    /// Expiração decodificada do payload do JWT (claim `exp`), sem validar assinatura
    /// — o app trata o token como opaco (spec §8.1).
    public var expiraEm: Date? { JWTClaims(token: token)?.exp }

    public func expirada(agora: Date = .now) -> Bool {
        guard let expiraEm else { return false }
        return expiraEm <= agora
    }
}

/// Parse local do payload de um JWT (base64url), somente leitura de claims.
public struct JWTClaims: Sendable {
    public let sub: String?
    public let upn: String?
    public let cpf: String?
    public let exp: Date?
    public let groups: [String]

    public init?(token: String) {
        let partes = token.split(separator: ".")
        guard partes.count >= 2 else { return nil }
        var base64 = String(partes[1])
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        while base64.count % 4 != 0 { base64.append("=") }
        guard let data = Data(base64Encoded: base64),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }
        sub = json["sub"] as? String
        upn = json["upn"] as? String
        cpf = json["cpf"] as? String
        groups = json["groups"] as? [String] ?? []
        if let segundos = json["exp"] as? TimeInterval {
            exp = Date(timeIntervalSince1970: segundos)
        } else {
            exp = nil
        }
    }
}
