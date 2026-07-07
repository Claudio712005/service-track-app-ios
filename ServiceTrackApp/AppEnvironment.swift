import Foundation
import Observation
import STDomain
import STNetworking
import STPersistence
import STData

/// Fornece o token da sessão ao APIClient fora do MainActor.
final class TokenBox: AuthTokenProvider, @unchecked Sendable {
    private let lock = NSLock()
    private var valor: String?

    var token: String? {
        lock.withLock { valor }
    }

    func atualizar(_ token: String?) {
        lock.withLock { valor = token }
    }
}

/// Composition root (spec §10.2 DI): protocolos injetados por inicializador;
/// previews e testes usam fakes.
@Observable
final class AppEnvironment {
    let auth: AuthRepository
    let clientes: ClienteRepository
    let veiculos: VeiculoRepository
    let ordens: OrdemServicoRepository
    let dashboard: DashboardRepository
    let notificacoes: NotificacaoRepository
    let catalogo: CatalogoRepository
    let sessaoStore: SessaoStore
    /// Preferências por instalação (onboarding, biometria) — ADR-iOS-004.
    let preferencias = PreferenciasLocais()

    private let tokenBox = TokenBox()
    private(set) var sessao: Sessao?

    init() {
        // Base URL sobrescrevível por env (paridade com SERVICETRACK_API_BASE_URL — spec §20).
        let env = ProcessInfo.processInfo.environment
        let baseURL = URL(string: env["SERVICETRACK_API_BASE_URL"] ?? "http://localhost:8080")!

        // Ambiente local com mocks (fixtures do OpenAPI). Backend real: rodar o
        // scheme com SERVICETRACK_MOCK=0 (exceção ATS restrita a localhost).
        let transport: APITransport
        #if DEBUG
        transport = env["SERVICETRACK_MOCK"] == "0" ? URLSessionTransport() : MockTransport()
        #else
        transport = URLSessionTransport()
        #endif

        let client = APIClient(baseURL: baseURL, transport: transport, tokenProvider: tokenBox)

        auth = AuthRepositoryHTTP(client: client)
        clientes = ClienteRepositoryHTTP(client: client)
        veiculos = VeiculoRepositoryHTTP(client: client)
        ordens = OrdemServicoRepositoryHTTP(client: client)
        dashboard = DashboardRepositoryHTTP(client: client)
        notificacoes = NotificacaoRepositoryHTTP(client: client)
        catalogo = CatalogoRepositoryHTTP(client: client)
        sessaoStore = KeychainSessaoStore()

        if let salva = try? sessaoStore.carregar(), !salva.expirada() {
            sessao = salva
            tokenBox.atualizar(salva.token)
        }
    }

    /// Efetiva o login: role gate CLIENTE (spec §8.2 item 4) + persistência no Keychain.
    func iniciarSessao(_ sessao: Sessao) throws {
        guard sessao.isCliente else {
            throw AppError.regraNegocio("Este app é exclusivo para clientes.")
        }
        try sessaoStore.salvar(sessao)
        tokenBox.atualizar(sessao.token)
        self.sessao = sessao
    }

    /// Logout (spec §8.2 item 6): apaga o Keychain e limpa o estado.
    func encerrarSessao() {
        try? sessaoStore.limpar()
        tokenBox.atualizar(nil)
        sessao = nil
    }

    /// Após `PUT /clientes/{id}`, espelha nome/e-mail na sessão persistida.
    func atualizarPerfil(_ cliente: Cliente) {
        guard let atual = sessao else { return }
        let nova = Sessao(token: atual.token, usuarioId: atual.usuarioId,
                          nome: cliente.nome, email: cliente.email, roles: atual.roles)
        try? sessaoStore.salvar(nova)
        sessao = nova
    }
}
