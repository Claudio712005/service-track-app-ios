import Foundation
import Observation
import STDomain
import STNetworking
import STPersistence
import STData
import STObservability

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
    let preferencias = PreferenciasLocais()
    let cache: CacheStore = DiscoCache()

    private let tokenBox = TokenBox()
    private(set) var sessao: Sessao?

    init() {
        let env = ProcessInfo.processInfo.environment
        let baseURL = URL(string: env["SERVICETRACK_API_BASE_URL"] ?? "http://localhost:8080")!

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

        let prefs = preferencias
        Telemetria.configurar(cliente: AnalyticsOSLog(),
                              habilitada: { prefs.analyticsHabilitada })
        Telemetria.registrar("app_open")
    }

    func iniciarSessao(_ sessao: Sessao) throws {
        guard sessao.isCliente else {
            throw AppError.regraNegocio("Este app é exclusivo para clientes.")
        }
        try sessaoStore.salvar(sessao)
        tokenBox.atualizar(sessao.token)
        self.sessao = sessao
    }

    func encerrarSessao() {
        try? sessaoStore.limpar()
        tokenBox.atualizar(nil)
        sessao = nil
        Task { [cache] in
            await cache.invalidar(chaves: [CacheChave.dashboard, CacheChave.veiculos,
                                           CacheChave.catalogo])
        }
    }

    #if DEBUG
    func autologinDebugSeNecessario() async {
        guard sessao == nil,
              ProcessInfo.processInfo.environment["ST_AUTOLOGIN"] == "1",
              let s = try? await auth.login(email: "cliente@servicetrack.dev", senha: "Senha@123")
        else { return }
        try? iniciarSessao(s)
    }
    #endif

    func atualizarPerfil(_ cliente: Cliente) {
        guard let atual = sessao else { return }
        let nova = Sessao(token: atual.token, usuarioId: atual.usuarioId,
                          nome: cliente.nome, email: cliente.email, roles: atual.roles)
        try? sessaoStore.salvar(nova)
        sessao = nova
    }
}
