import SwiftUI
import STCore
import STDomain
import STPersistence
import STFeatureAuth

/// Raiz do app: onboarding (1º acesso) → autenticação → home.
/// Sessão persistida + biometria habilitada → gate de desbloqueio (spec §8.4).
struct RootView: View {
    @Environment(AppEnvironment.self) private var env
    @Environment(\.scenePhase) private var scenePhase
    @State private var desbloqueado = false

    var body: some View {
        ZStack {
            conteudo

            // Proteção de tela no app switcher (spec §8.4).
            if scenePhase != .active {
                overlayPrivacidade
            }
        }
        .animation(DSMotion.toque, value: scenePhase == .active)
        .task {
            #if DEBUG
            await env.autologinDebugSeNecessario()
            #endif
        }
    }

    @ViewBuilder
    private var conteudo: some View {
        if let sessao = env.sessao {
            if env.preferencias.biometriaHabilitada && !desbloqueado {
                BiometriaGateView(nome: sessao.nome) {
                    desbloqueado = true
                } aoSair: {
                    env.encerrarSessao()
                }
            } else {
                MainTabView(sessao: sessao)
            }
        } else {
            AuthFlowView(
                deps: .init(auth: env.auth, clientes: env.clientes) { sessao in
                    try env.iniciarSessao(sessao)
                    desbloqueado = true
                },
                onboardingVisto: env.preferencias.onboardingVisto
            ) {
                env.preferencias.onboardingVisto = true
            }
        }
    }

    private var overlayPrivacidade: some View {
        ZStack {
            DSColor.bgCanvas.ignoresSafeArea()
            Image(systemName: "wrench.and.screwdriver.fill")
                .font(.system(size: 44, weight: .medium))
                .foregroundStyle(DSColor.brandPrimary)
        }
        .transition(.opacity)
        .accessibilityHidden(true)
    }
}

/// Desbloqueio por Face ID/Touch ID da sessão persistida (spec §8.4).
private struct BiometriaGateView: View {
    let nome: String
    let aoDesbloquear: () -> Void
    let aoSair: () -> Void
    @State private var falhou = false

    var body: some View {
        VStack(spacing: DSSpacing.xxl) {
            Spacer()
            Image(systemName: "faceid")
                .font(.system(size: 56, weight: .medium))
                .foregroundStyle(DSColor.brandPrimary)
                .accessibilityHidden(true)
            VStack(spacing: DSSpacing.xs) {
                Text("Olá, \(nome.split(separator: " ").first.map(String.init) ?? nome)")
                    .font(DSFont.title2)
                    .foregroundStyle(DSColor.textPrimary)
                Text("Desbloqueie para continuar")
                    .font(DSFont.callout)
                    .foregroundStyle(DSColor.textSecondary)
            }
            Spacer()
            VStack(spacing: DSSpacing.md) {
                if falhou {
                    STPrimaryButton("Tentar novamente") {
                        Task { await autenticar() }
                    }
                }
                STSecondaryButton("Entrar com outra conta", acao: aoSair)
            }
            .padding(.horizontal, DSSpacing.margemTela)
            .padding(.bottom, DSSpacing.x3l)
        }
        .background(DSColor.bgCanvas)
        .task { await autenticar() }
    }

    private func autenticar() async {
        if await Biometria.autenticar(motivo: "Desbloquear o ServiceTrack") {
            aoDesbloquear()
        } else {
            falhou = true
        }
    }
}
