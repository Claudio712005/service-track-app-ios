import Foundation
import Observation
import STDomain

/// Store unidirecional do Login (spec §10.2): estado exposto somente leitura,
/// mutação via `send(_:)`. Efetivação da sessão (role gate + Keychain) é do
/// composition root, injetada em `aoAutenticar`.
@MainActor
@Observable
public final class LoginStore {
    public struct Estado {
        public var email = ""
        public var senha = ""
        public var carregando = false
        public var erroEmail: String?
        public var erroSenha: String?
        public var erroGeral: String?
        /// Backoff visível de rate limit (spec §12.3) — CTA bloqueado com contador.
        public var segundosBloqueio = 0

        public var podeEnviar: Bool { !carregando && segundosBloqueio == 0 }
    }

    public enum Acao {
        case emailAlterado(String)
        case senhaAlterada(String)
        case entrar
    }

    public private(set) var estado = Estado()

    private let auth: AuthRepository
    private let aoAutenticar: (Sessao) throws -> Void
    private var contadorTask: Task<Void, Never>?

    public init(auth: AuthRepository, aoAutenticar: @escaping (Sessao) throws -> Void) {
        self.auth = auth
        self.aoAutenticar = aoAutenticar
    }

    public func send(_ acao: Acao) {
        switch acao {
        case .emailAlterado(let email):
            estado.email = email
            estado.erroEmail = nil
            estado.erroGeral = nil
        case .senhaAlterada(let senha):
            estado.senha = senha
            estado.erroSenha = nil
            estado.erroGeral = nil
        case .entrar:
            entrar()
        }
    }

    private func entrar() {
        guard estado.podeEnviar, validar() else { return }
        estado.carregando = true
        estado.erroGeral = nil

        Task {
            do {
                let sessao = try await auth.login(email: estado.email.trimmingCharacters(in: .whitespaces),
                                                  senha: estado.senha)
                try aoAutenticar(sessao)
            } catch let erro as AppError {
                tratar(erro)
            } catch {
                estado.erroGeral = AppError.rede.mensagemPadrao
            }
            estado.carregando = false
        }
    }

    private func validar() -> Bool {
        estado.erroEmail = Validadores.emailValido(estado.email.trimmingCharacters(in: .whitespaces))
            ? nil : "Informe um e-mail válido."
        estado.erroSenha = Validadores.senhaValida(estado.senha)
            ? nil : "A senha tem pelo menos 6 caracteres."
        return estado.erroEmail == nil && estado.erroSenha == nil
    }

    private func tratar(_ erro: AppError) {
        switch erro {
        case .naoAutenticado:
            estado.erroGeral = "E-mail ou senha incorretos."
        case .rateLimited(let retryAfter):
            // Janela do login é 20/min (spec §8.4); sem Retry-After, espera 30s.
            iniciarBloqueio(segundos: Int((retryAfter ?? 30).rounded()))
        default:
            estado.erroGeral = erro.mensagemPadrao
        }
    }

    private func iniciarBloqueio(segundos: Int) {
        estado.segundosBloqueio = max(segundos, 1)
        contadorTask?.cancel()
        contadorTask = Task { [weak self] in
            while let self, self.estado.segundosBloqueio > 0, !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                self.estado.segundosBloqueio -= 1
            }
        }
    }
}
