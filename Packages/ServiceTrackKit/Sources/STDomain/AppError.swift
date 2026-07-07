import Foundation

/// Erro unificado do app — mapa HTTP → AppError → UX (spec §12.1).
public enum AppError: Error, Equatable, Sendable {
    case validacao(campo: String?, mensagem: String)
    case naoAutenticado
    case semPermissao(mensagem: String?)
    case naoEncontrado(mensagem: String?)
    /// 409 — estado mudou fora do app (RN-07): revalidar recurso e explicar.
    case conflitoEstado(mensagem: String?)
    case regraNegocio(String)
    case rateLimited(retryAfter: TimeInterval?)
    case servidor(status: Int)
    case rede
    case decoding(String)

    /// Mensagem amigável padrão (pt-BR) quando a API não fornece uma melhor.
    public var mensagemPadrao: String {
        switch self {
        case .validacao(_, let mensagem): mensagem
        case .naoAutenticado: "Sua sessão expirou. Entre novamente."
        case .semPermissao(let m): m ?? "Você não tem permissão para acessar este conteúdo."
        case .naoEncontrado(let m): m ?? "Conteúdo não encontrado."
        case .conflitoEstado(let m): m ?? "Este item já foi atualizado. Recarregamos o estado atual."
        case .regraNegocio(let m): m
        case .rateLimited(let s):
            if let s { "Muitas tentativas. Tente novamente em \(Int(s.rounded()))s." }
            else { "Muitas tentativas. Aguarde um instante e tente novamente." }
        case .servidor: "Tivemos um problema no servidor. Tente novamente."
        case .rede: "Sem conexão. Verifique sua internet."
        case .decoding: "Não foi possível ler a resposta do servidor."
        }
    }
}
