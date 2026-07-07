import Foundation
import STDomain

/// Corpo de erro da API. Tolerante às duas formas observadas (ADR-iOS-002 D5):
/// `{mensagem, detalhe}` (contratos gerais) e `{status_code, mensagem}` (dashboard).
struct ErroResponseDTO: Decodable {
    let mensagem: String?
    let detalhe: String?
    let statusCode: Int?

    enum CodingKeys: String, CodingKey {
        case mensagem
        case detalhe
        case statusCode = "status_code"
    }
}

/// HTTP → `AppError` (spec §12.1).
public enum ErrorMapper {
    public static func map(status: Int, data: Data, headers: [AnyHashable: Any] = [:]) -> AppError {
        let corpo = try? JSONDecoder().decode(ErroResponseDTO.self, from: data)
        let mensagem = corpo?.mensagem

        switch status {
        case 400:
            return .validacao(campo: nil, mensagem: mensagem ?? "Dados inválidos.")
        case 401:
            return .naoAutenticado
        case 403:
            return .semPermissao(mensagem: mensagem)
        case 404:
            return .naoEncontrado(mensagem: mensagem)
        case 409:
            return .conflitoEstado(mensagem: mensagem)
        case 422:
            return .regraNegocio(mensagem ?? "Operação não permitida.")
        case 429:
            let retryAfter = (headers["Retry-After"] as? String).flatMap(TimeInterval.init)
            return .rateLimited(retryAfter: retryAfter)
        case 500...:
            return .servidor(status: status)
        default:
            return .servidor(status: status)
        }
    }
}
