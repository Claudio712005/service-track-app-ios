import SwiftUI
import STCore
import STDomain
import STFeatureVeiculos
import STFeatureOrdens
import STFeatureNotificacoes

/// Navegação raiz autenticada (spec §15): TabBar **customizada** com
/// Início / Ordens / Garagem / Notificações. Ordens e Notificações chegam nas
/// Fases 3 e 4 — placeholders honestos até lá.
struct MainTabView: View {
    enum Aba: CaseIterable {
        case inicio, ordens, garagem, notificacoes

        var titulo: String {
            switch self {
            case .inicio: "Início"
            case .ordens: "Ordens"
            case .garagem: "Garagem"
            case .notificacoes: "Avisos"
            }
        }

        var icone: String {
            switch self {
            case .inicio: "house"
            case .ordens: "wrench.and.screwdriver"
            case .garagem: "car"
            case .notificacoes: "bell"
            }
        }
    }

    @Environment(AppEnvironment.self) private var env
    let sessao: Sessao
    @State private var aba: Aba = {
        // Atalho de desenvolvimento p/ screenshots e debug: ST_TAB=garagem etc.
        #if DEBUG
        switch ProcessInfo.processInfo.environment["ST_TAB"] {
        case "ordens": return .ordens
        case "garagem": return .garagem
        case "notificacoes": return .notificacoes
        default: return .inicio
        }
        #else
        return .inicio
        #endif
    }()

    var body: some View {
        // VStack (não overlay): a barra ocupa espaço real de layout, então o
        // conteúdo dos NavigationStacks nunca fica escondido atrás dela.
        VStack(spacing: 0) {
            conteudo
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            barra
        }
        .background(DSColor.bgCanvas)
    }

    @ViewBuilder
    private var conteudo: some View {
        switch aba {
        case .inicio:
            HomePlaceholderView(sessao: sessao) {
                aba = .garagem
            }
        case .ordens:
            OrdensFlowView(deps: .init(ordens: env.ordens, catalogo: env.catalogo))
        case .garagem:
            GaragemFlowView(deps: .init(veiculos: env.veiculos, ordens: env.ordens,
                                        proprietarioId: sessao.usuarioId))
        case .notificacoes:
            NotificacoesFlowView(repo: env.notificacoes)
        }
    }

    private var barra: some View {
        HStack(spacing: DSSpacing.xs) {
            ForEach(Aba.allCases, id: \.self) { item in
                Button {
                    withAnimation(DSMotion.transicao) { aba = item }
                } label: {
                    VStack(spacing: DSSpacing.xxs) {
                        Image(systemName: aba == item ? item.icone + ".fill" : item.icone)
                            .font(.system(size: 18, weight: .semibold))
                            .symbolRenderingMode(.monochrome)
                        Text(item.titulo)
                            .font(DSFont.caption)
                    }
                    .foregroundStyle(aba == item ? DSColor.brandPrimary : DSColor.textTertiary)
                    .frame(maxWidth: .infinity, minHeight: DSSpacing.alvoMinimo + 8)
                    .background(
                        aba == item ? DSColor.brandPrimary.opacity(0.12) : .clear,
                        in: .rect(cornerRadius: DSRadius.md)
                    )
                    .contentShape(.rect)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(item.titulo)
                .accessibilityAddTraits(aba == item ? [.isSelected] : [])
            }
        }
        .padding(DSSpacing.sm)
        .background(.ultraThinMaterial, in: .rect(cornerRadius: DSRadius.lg))
        .overlay(
            RoundedRectangle(cornerRadius: DSRadius.lg)
                .strokeBorder(DSColor.borderSubtle, lineWidth: 1)
        )
        .dsShadow(.e2)
        .padding(.horizontal, DSSpacing.margemTela)
        .padding(.bottom, DSSpacing.sm)
    }
}
