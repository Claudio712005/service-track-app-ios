import XCTest
import STDomain
@testable import STFeatureAuth

// MARK: - Fakes

private struct AuthFake: AuthRepository {
    var resultado: Result<Sessao, AppError>

    func login(cpf: String, senha: String) async throws -> Sessao {
        try resultado.get()
    }

    func alterarSenha(senhaAtual: String, novaSenha: String, confirmacao: String) async throws {}
}

private struct ClientesFake: ClienteRepository {
    var falhaCadastro: AppError?

    func cadastrar(nome: String, email: String, senha: String, dataNascimento: Date,
                   telefone: String, cpf: String) async throws -> Cliente {
        if let falhaCadastro { throw falhaCadastro }
        return Cliente(id: UUID(), nome: nome, email: email, cpf: cpf,
                       telefone: telefone, roles: ["CLIENTE"], ativo: true)
    }

    func buscar(id: UUID) async throws -> Cliente { fatalError("não usado") }
    func atualizar(id: UUID, nome: String, email: String, telefone: String) async throws -> Cliente {
        fatalError("não usado")
    }
    func desativar(id: UUID) async throws {}
}

private func sessaoFake(roles: [String] = ["CLIENTE"]) -> Sessao {
    Sessao(token: "t", usuarioId: UUID(), cpf: "52998224725", email: "c@s.dev", roles: roles)
}

@MainActor
private func aguardar(_ condicao: @escaping () -> Bool) async throws {
    for _ in 0..<200 where !condicao() {
        try await Task.sleep(for: .milliseconds(10))
    }	
    XCTAssertTrue(condicao(), "condição não satisfeita no tempo limite")
}

// MARK: - Login

@MainActor
final class LoginStoreTests: XCTestCase {
    func testValidacaoLocalAntesDaRede() {
        let store = LoginStore(auth: AuthFake(resultado: .success(sessaoFake()))) { _ in
            XCTFail("não deveria autenticar com formulário inválido")
        }
        store.send(.cpfAlterado("111"))
        store.send(.senhaAlterada("123"))
        store.send(.entrar)
        XCTAssertNotNil(store.estado.erroCpf)
        XCTAssertNotNil(store.estado.erroSenha)
    }

    func testLoginComSucessoChamaAoAutenticar() async throws {
        var autenticado = false
        let store = LoginStore(auth: AuthFake(resultado: .success(sessaoFake()))) { _ in
            autenticado = true
        }
        store.send(.cpfAlterado("52998224725"))
        store.send(.senhaAlterada("Senha@123"))
        store.send(.entrar)
        try await aguardar { autenticado }
        XCTAssertNil(store.estado.erroGeral)
    }

    func testRoleGatePropagaErroDoCallback() async throws {
        // Role gate vive no composition root (spec §8.2 item 4): o callback lança.
        let store = LoginStore(auth: AuthFake(resultado: .success(sessaoFake(roles: ["MECANICO"])))) { sessao in
            guard sessao.isCliente else {
                throw AppError.regraNegocio("Este app é exclusivo para clientes.")
            }
        }
        store.send(.cpfAlterado("52998224725"))
        store.send(.senhaAlterada("Senha@123"))
        store.send(.entrar)
        try await aguardar { store.estado.erroGeral != nil }
        XCTAssertEqual(store.estado.erroGeral, "Este app é exclusivo para clientes.")
    }

    func testCredenciaisInvalidas() async throws {
        let store = LoginStore(auth: AuthFake(resultado: .failure(.naoAutenticado))) { _ in }
        store.send(.cpfAlterado("52998224725"))
        store.send(.senhaAlterada("errada123"))
        store.send(.entrar)
        try await aguardar { store.estado.erroGeral != nil }
        XCTAssertEqual(store.estado.erroGeral, "CPF ou senha incorretos.")
    }

    func testRateLimitBloqueiaCTA() async throws {
        // Spec §12.3: respeitar Retry-After com contador visível.
        let store = LoginStore(auth: AuthFake(resultado: .failure(.rateLimited(retryAfter: 3)))) { _ in }
        store.send(.cpfAlterado("52998224725"))
        store.send(.senhaAlterada("Senha@123"))
        store.send(.entrar)
        try await aguardar { store.estado.segundosBloqueio > 0 }
        XCTAssertFalse(store.estado.podeEnviar)
    }
}

// MARK: - Cadastro

@MainActor
final class CadastroStoreTests: XCTestCase {
    private func store(clientes: ClientesFake = ClientesFake(),
                       auth: AuthRepository = AuthFake(resultado: .success(sessaoFake())),
                       aoAutenticar: @escaping (Sessao) throws -> Void = { _ in }) -> CadastroStore {
        CadastroStore(clientes: clientes, auth: auth, aoAutenticar: aoAutenticar)
    }

    func testEtapaIdentidadeValida() {
        let s = store()
        s.send(.avancar)
        XCTAssertEqual(s.estado.etapa, .identidade)
        XCTAssertNotNil(s.estado.erros[.nome])
        XCTAssertNotNil(s.estado.erros[.email])

        s.send(.campoAlterado(.nome, "Cláudio Araújo"))
        s.send(.campoAlterado(.email, "c@s.dev"))
        s.send(.avancar)
        XCTAssertEqual(s.estado.etapa, .documentos)
    }

    func testEtapaDocumentosValidaCPFETelefone() {
        let s = store()
        s.send(.campoAlterado(.nome, "Cláudio Araújo"))
        s.send(.campoAlterado(.email, "c@s.dev"))
        s.send(.avancar)

        s.send(.campoAlterado(.cpf, "111.111.111-11"))
        s.send(.campoAlterado(.telefone, "123"))
        s.send(.avancar)
        XCTAssertEqual(s.estado.etapa, .documentos)
        XCTAssertNotNil(s.estado.erros[.cpf])
        XCTAssertNotNil(s.estado.erros[.telefone])

        s.send(.campoAlterado(.cpf, "549.271.700-63"))
        s.send(.campoAlterado(.telefone, "(11) 98765-4321"))
        s.send(.avancar)
        XCTAssertEqual(s.estado.etapa, .senha)
    }

    func testFluxoCompletoComAutoLogin() async throws {
        var autenticado = false
        let s = store { _ in autenticado = true }
        s.send(.campoAlterado(.nome, "Cláudio Araújo"))
        s.send(.campoAlterado(.email, "c@s.dev"))
        s.send(.avancar)
        s.send(.campoAlterado(.cpf, "54927170063"))
        s.send(.campoAlterado(.telefone, "11987654321"))
        s.send(.avancar)
        s.send(.campoAlterado(.senha, "Senha@123"))
        s.send(.campoAlterado(.confirmacaoSenha, "Senha@123"))
        s.send(.avancar)
        try await aguardar { autenticado }
    }

    func testSenhasDiferentesBarram() {
        let s = store()
        s.send(.campoAlterado(.nome, "Cláudio Araújo"))
        s.send(.campoAlterado(.email, "c@s.dev"))
        s.send(.avancar)
        s.send(.campoAlterado(.cpf, "54927170063"))
        s.send(.campoAlterado(.telefone, "11987654321"))
        s.send(.avancar)
        s.send(.campoAlterado(.senha, "Senha@123"))
        s.send(.campoAlterado(.confirmacaoSenha, "Outra@123"))
        s.send(.avancar)
        XCTAssertNotNil(s.estado.erros[.confirmacaoSenha])
        XCTAssertEqual(s.estado.etapa, .senha)
    }

    func testEmailJaCadastradoMostraMensagemDaAPI() async throws {
        let s = store(clientes: ClientesFake(
            falhaCadastro: .validacao(campo: nil, mensagem: "Email ou CPF já cadastrado")))
        s.send(.campoAlterado(.nome, "Cláudio Araújo"))
        s.send(.campoAlterado(.email, "c@s.dev"))
        s.send(.avancar)
        s.send(.campoAlterado(.cpf, "54927170063"))
        s.send(.campoAlterado(.telefone, "11987654321"))
        s.send(.avancar)
        s.send(.campoAlterado(.senha, "Senha@123"))
        s.send(.campoAlterado(.confirmacaoSenha, "Senha@123"))
        s.send(.avancar)
        try await aguardar { s.estado.erroGeral != nil }
        XCTAssertEqual(s.estado.erroGeral, "Email ou CPF já cadastrado")
    }
}
