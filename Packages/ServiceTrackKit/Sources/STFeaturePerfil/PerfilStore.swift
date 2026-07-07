import Foundation
import Observation
import STDomain

/// Store do Perfil (spec §15.12): ver/editar dados, alterar senha, logout,
/// desativar conta (soft delete RN-08).
@MainActor
@Observable
public final class PerfilStore {
    public struct Estado {
        public var cliente: Cliente?
        public var carregando = false
        public var salvando = false
        public var erroCarga: AppError?
        public var erroFormulario: [Campo: String] = [:]
        public var erroGeral: String?
        public var mensagemSucesso: String?

        // Edição de dados (PUT: apenas nome/email/telefone — CPF e nascimento
        // são somente leitura no contrato).
        public var nome = ""
        public var email = ""
        public var telefone = ""

        // Alterar senha (reset-senha é troca autenticada — spec §9 C6).
        public var senhaAtual = ""
        public var novaSenha = ""
        public var confirmacaoNovaSenha = ""
    }

    public enum Campo: Hashable {
        case nome, email, telefone, senhaAtual, novaSenha, confirmacaoNovaSenha
    }

    public enum Acao {
        case aparecer
        case recarregar
        case campoAlterado(Campo, String)
        case salvarDados
        case alterarSenha
        case sair
        case desativarConta
        case limparFeedback
    }

    public private(set) var estado = Estado()

    private let clientes: ClienteRepository
    private let auth: AuthRepository
    private let sessao: Sessao
    private let aoPerfilAtualizado: (Cliente) -> Void
    private let aoSair: () -> Void

    public init(clientes: ClienteRepository, auth: AuthRepository, sessao: Sessao,
                aoPerfilAtualizado: @escaping (Cliente) -> Void,
                aoSair: @escaping () -> Void) {
        self.clientes = clientes
        self.auth = auth
        self.sessao = sessao
        self.aoPerfilAtualizado = aoPerfilAtualizado
        self.aoSair = aoSair
    }

    public func send(_ acao: Acao) {
        switch acao {
        case .aparecer:
            if estado.cliente == nil { carregar() }
        case .recarregar:
            carregar()
        case .campoAlterado(let campo, let valor):
            atualizar(campo, valor)
        case .salvarDados:
            salvarDados()
        case .alterarSenha:
            alterarSenha()
        case .sair:
            aoSair()
        case .desativarConta:
            desativarConta()
        case .limparFeedback:
            estado.mensagemSucesso = nil
            estado.erroGeral = nil
        }
    }

    private func atualizar(_ campo: Campo, _ valor: String) {
        switch campo {
        case .nome: estado.nome = valor
        case .email: estado.email = valor
        case .telefone: estado.telefone = valor
        case .senhaAtual: estado.senhaAtual = valor
        case .novaSenha: estado.novaSenha = valor
        case .confirmacaoNovaSenha: estado.confirmacaoNovaSenha = valor
        }
        estado.erroFormulario[campo] = nil
        estado.erroGeral = nil
    }

    private func carregar() {
        estado.carregando = true
        estado.erroCarga = nil
        Task {
            do {
                // RN-02: sempre o próprio id da sessão.
                let cliente = try await clientes.buscar(id: sessao.usuarioId)
                estado.cliente = cliente
                estado.nome = cliente.nome
                estado.email = cliente.email
                estado.telefone = cliente.telefone
            } catch let erro as AppError {
                estado.erroCarga = erro
            } catch {
                estado.erroCarga = .rede
            }
            estado.carregando = false
        }
    }

    private func salvarDados() {
        var erros: [Campo: String] = [:]
        if estado.nome.trimmingCharacters(in: .whitespaces).count < 2 {
            erros[.nome] = "Informe seu nome completo."
        }
        if !Validadores.emailValido(estado.email.trimmingCharacters(in: .whitespaces)) {
            erros[.email] = "Informe um e-mail válido."
        }
        if !Validadores.telefoneValido(estado.telefone) {
            erros[.telefone] = "Telefone com DDD (10 ou 11 dígitos)."
        }
        estado.erroFormulario = erros
        guard erros.isEmpty, !estado.salvando else { return }

        estado.salvando = true
        Task {
            do {
                let atualizado = try await clientes.atualizar(
                    id: sessao.usuarioId,
                    nome: estado.nome.trimmingCharacters(in: .whitespaces),
                    email: estado.email.trimmingCharacters(in: .whitespaces),
                    telefone: estado.telefone.filter(\.isNumber))
                estado.cliente = atualizado
                estado.mensagemSucesso = "Dados atualizados."
                aoPerfilAtualizado(atualizado)
            } catch let erro as AppError {
                estado.erroGeral = erro.mensagemPadrao
            } catch {
                estado.erroGeral = AppError.rede.mensagemPadrao
            }
            estado.salvando = false
        }
    }

    private func alterarSenha() {
        var erros: [Campo: String] = [:]
        if estado.senhaAtual.isEmpty {
            erros[.senhaAtual] = "Informe a senha atual."
        }
        if !Validadores.senhaValida(estado.novaSenha) {
            erros[.novaSenha] = "A nova senha precisa de pelo menos 6 caracteres."
        }
        if estado.confirmacaoNovaSenha != estado.novaSenha {
            erros[.confirmacaoNovaSenha] = "As senhas não coincidem."
        }
        estado.erroFormulario = erros
        guard erros.isEmpty, !estado.salvando else { return }

        estado.salvando = true
        Task {
            do {
                try await auth.alterarSenha(senhaAtual: estado.senhaAtual,
                                            novaSenha: estado.novaSenha,
                                            confirmacao: estado.confirmacaoNovaSenha)
                estado.senhaAtual = ""
                estado.novaSenha = ""
                estado.confirmacaoNovaSenha = ""
                estado.mensagemSucesso = "Senha alterada."
            } catch let erro as AppError {
                switch erro {
                case .rateLimited:
                    // Janela do reset é 5/min (spec §8.4).
                    estado.erroGeral = erro.mensagemPadrao
                case .validacao(_, let mensagem), .regraNegocio(let mensagem):
                    estado.erroGeral = mensagem
                case .naoAutenticado:
                    estado.erroFormulario[.senhaAtual] = "Senha atual incorreta."
                default:
                    estado.erroGeral = erro.mensagemPadrao
                }
            } catch {
                estado.erroGeral = AppError.rede.mensagemPadrao
            }
            estado.salvando = false
        }
    }

    /// Soft delete (RN-08) — a view exige dupla confirmação antes de chamar.
    private func desativarConta() {
        guard !estado.salvando else { return }
        estado.salvando = true
        Task {
            do {
                try await clientes.desativar(id: sessao.usuarioId)
                aoSair()
            } catch let erro as AppError {
                estado.erroGeral = erro.mensagemPadrao
            } catch {
                estado.erroGeral = AppError.rede.mensagemPadrao
            }
            estado.salvando = false
        }
    }
}
