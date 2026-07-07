import SwiftUI
import STCore
import STDomain

/// Fluxo não autenticado: onboarding (só 1º acesso) → login ⇄ cadastro.
/// Navegação por estado com `NavigationStack` + rota tipada (spec §10.2).
public struct AuthFlowView: View {
    public struct Dependencias {
        let auth: AuthRepository
        let clientes: ClienteRepository
        let aoAutenticar: (Sessao) throws -> Void

        public init(auth: AuthRepository, clientes: ClienteRepository,
                    aoAutenticar: @escaping (Sessao) throws -> Void) {
            self.auth = auth
            self.clientes = clientes
            self.aoAutenticar = aoAutenticar
        }
    }

    private enum Rota: Hashable {
        case cadastro
    }

    let deps: Dependencias
    let onboardingVisto: Bool
    let aoConcluirOnboarding: () -> Void

    @State private var mostrandoOnboarding: Bool
    @State private var caminho: [Rota] = []

    public init(deps: Dependencias, onboardingVisto: Bool,
                aoConcluirOnboarding: @escaping () -> Void) {
        self.deps = deps
        self.onboardingVisto = onboardingVisto
        self.aoConcluirOnboarding = aoConcluirOnboarding
        self._mostrandoOnboarding = State(initialValue: !onboardingVisto)
    }

    public var body: some View {
        if mostrandoOnboarding {
            OnboardingView { saida in
                aoConcluirOnboarding()
                withAnimation(DSMotion.transicao) {
                    mostrandoOnboarding = false
                }
                if saida == .criarConta {
                    caminho = [.cadastro]
                }
            }
        } else {
            NavigationStack(path: $caminho) {
                LoginView(store: LoginStore(auth: deps.auth, aoAutenticar: deps.aoAutenticar)) {
                    caminho.append(.cadastro)
                }
                .navigationDestination(for: Rota.self) { rota in
                    switch rota {
                    case .cadastro:
                        CadastroView(store: CadastroStore(clientes: deps.clientes,
                                                          auth: deps.auth,
                                                          aoAutenticar: deps.aoAutenticar))
                    }
                }
            }
        }
    }
}
