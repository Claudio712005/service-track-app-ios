import SwiftUI
import STCore
import STDomain
import STPersistence
import STFeaturePerfil

/// Home provisória da Fase 1: saudação + acesso ao Perfil.
/// Substituída pelo Dashboard + TabBar customizada na Fase 3 (spec §15.3).
struct HomePlaceholderView: View {
    @Environment(AppEnvironment.self) private var env
    let sessao: Sessao

    private enum Rota: Hashable {
        case perfil
        case galeriaDS
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: DSSpacing.xl) {
                    cabecalho

                    STCard {
                        VStack(alignment: .leading, spacing: DSSpacing.sm) {
                            Label("Dashboard em construção", systemImage: "hammer")
                                .font(DSFont.headline)
                                .foregroundStyle(DSColor.textPrimary)
                            Text("As ordens de serviço, a garagem e o painel completo chegam na Fase 3 do roadmap.")
                                .font(DSFont.callout)
                                .foregroundStyle(DSColor.textSecondary)
                        }
                    }

                    #if DEBUG
                    NavigationLink(value: Rota.galeriaDS) {
                        STCard {
                            Label("Design System (galeria de fundação)", systemImage: "paintpalette")
                                .font(DSFont.body)
                                .foregroundStyle(DSColor.textPrimary)
                        }
                    }
                    .buttonStyle(.plain)
                    #endif
                }
                .padding(DSSpacing.margemTela)
            }
            .background(DSColor.bgCanvas)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    NavigationLink(value: Rota.perfil) {
                        Image(systemName: "person.crop.circle")
                            .foregroundStyle(DSColor.brandPrimary)
                    }
                    .accessibilityLabel("Perfil")
                }
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

    private var cabecalho: some View {
        VStack(alignment: .leading, spacing: DSSpacing.xxs) {
            Text("Olá, \(primeiroNome)")
                .font(DSFont.display)
                .foregroundStyle(DSColor.textPrimary)
            Text("Bem-vindo ao ServiceTrack")
                .font(DSFont.callout)
                .foregroundStyle(DSColor.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var primeiroNome: String {
        sessao.nome.split(separator: " ").first.map(String.init) ?? sessao.nome
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
