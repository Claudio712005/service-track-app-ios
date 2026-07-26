import Foundation
import Observation
import STDomain
import STObservability

@MainActor
@Observable
public final class LoginStore {
    public struct Estado {
        public var cpf = ""
        public var senha = ""
        public var carregando = false
        public var erroCpf: String?
        public var erroSenha: String?
        public var erroGeral: String?
        public var segundosBloqueio = 0

        public var podeEnviar: Bool { !carregando && segundosBloqueio == 0 }
    }

    public enum Acao {
        case cpfAlterado(String)
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
        case .cpfAlterado(let cpf):
            estado.cpf = cpf
            estado.erroCpf = nil
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
                let sessao = try await auth.login(cpf: estado.cpf.trimmingCharacters(in: .whitespaces),
                                                  senha: estado.senha)
                try aoAutenticar(sessao)
                Telemetria.registrar("login_success")
            } catch let erro as AppError {
                tratar(erro)
            } catch {
                estado.erroGeral = AppError.rede.mensagemPadrao
            }
            estado.carregando = false
        }
    }

    private func validar() -> Bool {
        estado.erroCpf = Validadores.cpfValido(estado.cpf.trimmingCharacters(in: .whitespaces))
            ? nil : "Informe um CPF válido."
        estado.erroSenha = Validadores.senhaValida(estado.senha)
            ? nil : "A senha tem pelo menos 8 caracteres."
        return estado.erroCpf == nil && estado.erroSenha == nil
    }

    private func tratar(_ erro: AppError) {
        Telemetria.registrar("login_fail", ["reason": rotuloDeFalha(erro)])
        switch erro {
        case .naoAutenticado:
            estado.erroGeral = "CPF ou senha incorretos."
        case .rateLimited(let retryAfter):
            iniciarBloqueio(segundos: Int((retryAfter ?? 30).rounded()))
        default:
            estado.erroGeral = erro.mensagemPadrao
        }
    }

    private func rotuloDeFalha(_ erro: AppError) -> String {
        switch erro {
        case .naoAutenticado: "credenciais"
        case .rateLimited: "rate_limit"
        case .rede: "rede"
        default: "outro"
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
