import XCTest
import STDomain
@testable import STFeaturePerfil

private final class ClientesFake: ClienteRepository, @unchecked Sendable {
    var cliente = Cliente(id: UUID(), nome: "Cláudio", email: "c@s.dev",
                          cpf: "54927170063", telefone: "11987654321",
                          roles: ["CLIENTE"], ativo: true)
    var desativado = false
    var idsBuscados: [UUID] = []

    func cadastrar(nome: String, email: String, senha: String, dataNascimento: Date,
                   telefone: String, cpf: String) async throws -> Cliente {
        fatalError("não usado")
    }

    func buscar(id: UUID) async throws -> Cliente {
        idsBuscados.append(id)
        return cliente
    }

    func atualizar(id: UUID, nome: String, email: String, telefone: String) async throws -> Cliente {
        cliente = Cliente(id: cliente.id, nome: nome, email: email, cpf: cliente.cpf,
                          telefone: telefone, roles: cliente.roles, ativo: cliente.ativo)
        return cliente
    }

    func desativar(id: UUID) async throws {
        desativado = true
    }
}

private struct AuthFake: AuthRepository {
    var erroTroca: AppError?

    func login(email: String, senha: String) async throws -> Sessao { fatalError("não usado") }

    func alterarSenha(senhaAtual: String, novaSenha: String, confirmacao: String) async throws {
        if let erroTroca { throw erroTroca }
    }
}

@MainActor
private func aguardar(_ condicao: @escaping () -> Bool) async throws {
    for _ in 0..<200 where !condicao() {
        try await Task.sleep(for: .milliseconds(10))
    }
    XCTAssertTrue(condicao(), "condição não satisfeita no tempo limite")
}

@MainActor
final class PerfilStoreTests: XCTestCase {
    private let sessao = Sessao(token: "t", usuarioId: UUID(), nome: "Cláudio",
                                email: "c@s.dev", roles: ["CLIENTE"])

    private func store(clientes: ClientesFake = ClientesFake(),
                       auth: AuthFake = AuthFake(),
                       aoPerfilAtualizado: @escaping (Cliente) -> Void = { _ in },
                       aoSair: @escaping () -> Void = {}) -> PerfilStore {
        PerfilStore(clientes: clientes, auth: auth, sessao: sessao,
                    aoPerfilAtualizado: aoPerfilAtualizado, aoSair: aoSair)
    }

    func testCargaUsaIdDaSessao() async throws {
        // RN-02: nunca outro id além do da sessão.
        let clientes = ClientesFake()
        let s = store(clientes: clientes)
        s.send(.aparecer)
        try await aguardar { s.estado.cliente != nil }
        XCTAssertEqual(clientes.idsBuscados, [sessao.usuarioId])
        XCTAssertEqual(s.estado.nome, "Cláudio")
    }

    func testSalvarDadosValidaENotifica() async throws {
        var notificado: Cliente?
        let s = store(aoPerfilAtualizado: { notificado = $0 })
        s.send(.aparecer)
        try await aguardar { s.estado.cliente != nil }

        s.send(.campoAlterado(.email, "invalido"))
        s.send(.salvarDados)
        XCTAssertNotNil(s.estado.erroFormulario[.email])

        s.send(.campoAlterado(.nome, "Cláudio Araújo"))
        s.send(.campoAlterado(.email, "novo@s.dev"))
        s.send(.campoAlterado(.telefone, "11912345678"))
        s.send(.salvarDados)
        try await aguardar { notificado != nil }
        XCTAssertEqual(notificado?.email, "novo@s.dev")
        XCTAssertEqual(s.estado.mensagemSucesso, "Dados atualizados.")
    }

    func testAlterarSenhaExigeConfirmacaoIgual() {
        let s = store()
        s.send(.campoAlterado(.senhaAtual, "Senha@123"))
        s.send(.campoAlterado(.novaSenha, "Nova@456"))
        s.send(.campoAlterado(.confirmacaoNovaSenha, "Diferente"))
        s.send(.alterarSenha)
        XCTAssertNotNil(s.estado.erroFormulario[.confirmacaoNovaSenha])
    }

    func testSenhaAtualIncorretaViraErroDeCampo() async throws {
        let s = store(auth: AuthFake(erroTroca: .naoAutenticado))
        s.send(.campoAlterado(.senhaAtual, "Errada@1"))
        s.send(.campoAlterado(.novaSenha, "Nova@456"))
        s.send(.campoAlterado(.confirmacaoNovaSenha, "Nova@456"))
        s.send(.alterarSenha)
        try await aguardar { s.estado.erroFormulario[.senhaAtual] != nil }
        XCTAssertEqual(s.estado.erroFormulario[.senhaAtual], "Senha atual incorreta.")
    }

    func testAlterarSenhaComSucessoLimpaCampos() async throws {
        let s = store()
        s.send(.campoAlterado(.senhaAtual, "Senha@123"))
        s.send(.campoAlterado(.novaSenha, "Nova@456"))
        s.send(.campoAlterado(.confirmacaoNovaSenha, "Nova@456"))
        s.send(.alterarSenha)
        try await aguardar { s.estado.mensagemSucesso != nil }
        XCTAssertTrue(s.estado.senhaAtual.isEmpty)
        XCTAssertTrue(s.estado.novaSenha.isEmpty)
    }

    func testDesativarContaChamaRepositorioESai() async throws {
        // RN-08: soft delete + logout.
        var saiu = false
        let clientes = ClientesFake()
        let s = store(clientes: clientes, aoSair: { saiu = true })
        s.send(.desativarConta)
        try await aguardar { saiu }
        XCTAssertTrue(clientes.desativado)
    }
}
