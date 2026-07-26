import Foundation
import Observation
import STDomain
import STObservability

@MainActor
@Observable
public final class CadastroStore {
    public enum Etapa: Int, CaseIterable {
        case identidade = 0
        case documentos = 1
        case senha = 2
    }

    public struct Estado {
        public var etapa: Etapa = .identidade
        public var nome = ""
        public var email = ""
        public var cpf = ""
        public var telefone = ""
        public var dataNascimento = Calendar.current.date(byAdding: .year, value: -25, to: .now) ?? .now
        public var senha = ""
        public var confirmacaoSenha = ""
        public var carregando = false
        public var erros: [Campo: String] = [:]
        public var erroGeral: String?
        public var segundosBloqueio = 0

        public var podeEnviar: Bool { !carregando && segundosBloqueio == 0 }
        public var progresso: Double { Double(etapa.rawValue + 1) / Double(Etapa.allCases.count) }
    }

    public enum Campo: Hashable {
        case nome, email, cpf, telefone, dataNascimento, senha, confirmacaoSenha
    }

    public enum Acao {
        case campoAlterado(Campo, String)
        case dataNascimentoAlterada(Date)
        case avancar
        case voltar
    }

    public private(set) var estado = Estado()

    private let clientes: ClienteRepository
    private let auth: AuthRepository
    private let aoAutenticar: (Sessao) throws -> Void
    private var contadorTask: Task<Void, Never>?

    public init(clientes: ClienteRepository, auth: AuthRepository,
                aoAutenticar: @escaping (Sessao) throws -> Void) {
        self.clientes = clientes
        self.auth = auth
        self.aoAutenticar = aoAutenticar
    }

    public func send(_ acao: Acao) {
        switch acao {
        case .campoAlterado(let campo, let valor):
            atualizar(campo, valor)
        case .dataNascimentoAlterada(let data):
            estado.dataNascimento = data
            estado.erros[.dataNascimento] = nil
        case .avancar:
            avancar()
        case .voltar:
            if let anterior = Etapa(rawValue: estado.etapa.rawValue - 1) {
                estado.etapa = anterior
                estado.erroGeral = nil
            }
        }
    }

    private func atualizar(_ campo: Campo, _ valor: String) {
        switch campo {
        case .nome: estado.nome = valor
        case .email: estado.email = valor
        case .cpf: estado.cpf = valor
        case .telefone: estado.telefone = valor
        case .senha: estado.senha = valor
        case .confirmacaoSenha: estado.confirmacaoSenha = valor
        case .dataNascimento: break
        }
        estado.erros[campo] = nil
        estado.erroGeral = nil
    }

    private func avancar() {
        guard validar(estado.etapa) else { return }
        switch estado.etapa {
        case .identidade: estado.etapa = .documentos
        case .documentos: estado.etapa = .senha
        case .senha: cadastrar()
        }
    }

    func validar(_ etapa: Etapa) -> Bool {
        var erros: [Campo: String] = [:]
        switch etapa {
        case .identidade:
            if estado.nome.trimmingCharacters(in: .whitespaces).count < 2 {
                erros[.nome] = "Informe seu nome completo."
            }
            if !Validadores.emailValido(estado.email.trimmingCharacters(in: .whitespaces)) {
                erros[.email] = "Informe um e-mail válido."
            }
        case .documentos:
            if !Validadores.cpfValido(estado.cpf) {
                erros[.cpf] = "CPF inválido."
            }
            if !Validadores.telefoneValido(estado.telefone) {
                erros[.telefone] = "Telefone com DDD (10 ou 11 dígitos)."
            }
            if estado.dataNascimento >= Calendar.current.startOfDay(for: .now) {
                erros[.dataNascimento] = "Data de nascimento inválida."
            }
        case .senha:
            if !Validadores.senhaValida(estado.senha) {
                erros[.senha] = "A senha precisa de pelo menos 6 caracteres."
            }
            if estado.confirmacaoSenha != estado.senha {
                erros[.confirmacaoSenha] = "As senhas não coincidem."
            }
        }
        estado.erros = erros
        return erros.isEmpty
    }

    private func cadastrar() {
        guard estado.podeEnviar else { return }
        estado.carregando = true
        estado.erroGeral = nil

        let email = estado.email.trimmingCharacters(in: .whitespaces)
        let cpf = estado.cpf.filter(\.isNumber)
        Task {
            do {
                _ = try await clientes.cadastrar(
                    nome: estado.nome.trimmingCharacters(in: .whitespaces),
                    email: email,
                    senha: estado.senha,
                    dataNascimento: estado.dataNascimento,
                    telefone: estado.telefone.filter(\.isNumber),
                    cpf: cpf)
                Telemetria.registrar("signup_completed")
                let sessao = try await auth.login(cpf: cpf, senha: estado.senha)
                try aoAutenticar(sessao)
            } catch let erro as AppError {
                tratar(erro)
            } catch {
                estado.erroGeral = AppError.rede.mensagemPadrao
            }
            estado.carregando = false
        }
    }

    private func tratar(_ erro: AppError) {
        switch erro {
        case .rateLimited(let retryAfter):
            iniciarBloqueio(segundos: Int((retryAfter ?? 60).rounded()))
        case .validacao(_, let mensagem), .regraNegocio(let mensagem):
            estado.erroGeral = mensagem
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
