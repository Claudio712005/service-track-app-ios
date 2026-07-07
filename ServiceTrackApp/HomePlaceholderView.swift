import SwiftUI
import STCore
import STDomain
import STPersistence
import STFeaturePerfil
import STFeatureDashboard

/// Home autenticada: Dashboard (spec §15.3) + acesso ao Perfil.
/// TabBar customizada com Ordens/Garagem/Notificações chega nas próximas fases.
struct HomePlaceholderView: View {
    @Environment(AppEnvironment.self) private var env
    let sessao: Sessao
    var aoIrParaGaragem: (() -> Void)?

    private enum Rota: Hashable {
        case perfil
        case galeriaDS
    }

    var body: some View {
        NavigationStack {
            DashboardView(store: DashboardStore(dashboard: env.dashboard,
                                                notificacoes: env.notificacoes,
                                                ordens: env.ordens,
                                                clienteId: sessao.usuarioId),
                          nomeCliente: sessao.nome,
                          aoCadastrarVeiculo: aoIrParaGaragem)
                .toolbar {
                    ToolbarItem(placement: .primaryAction) {
                        NavigationLink(value: Rota.perfil) {
                            Image(systemName: "person.crop.circle")
                                .foregroundStyle(DSColor.brandPrimary)
                        }
                        .accessibilityLabel("Perfil")
                    }
                    #if DEBUG
                    ToolbarItem(placement: .secondaryAction) {
                        NavigationLink(value: Rota.galeriaDS) {
                            Label("Design System", systemImage: "paintpalette")
                        }
                    }
                    #endif
                }
                .navigationDestination(for: Rota.self) { rota in
                    switch rota {
                    case .perfil:
                        PerfilView(store: perfilStore, biometriaHabilitada: biometriaBinding)
                    case .galeriaDS:
                        FundacaoView()
                    }
                }
        }
    }

    private var perfilStore: PerfilStore {
        PerfilStore(clientes: env.clientes, auth: env.auth, sessao: sessao) { cliente in
            env.atualizarPerfil(cliente)
        } aoSair: {
            env.encerrarSessao()
        }
    }

    private var biometriaBinding: Binding<Bool> {
        Binding(get: { env.preferencias.biometriaHabilitada },
                set: { env.preferencias.biometriaHabilitada = $0 })
    }
}
